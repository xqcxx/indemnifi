// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {BaseHook} from "./BaseHook.sol";
import {InsuranceVault} from "../vault/InsuranceVault.sol";
import {IIndemnifiHook} from "../interfaces/IIndemnifiHook.sol";
import {ILMath} from "../libraries/ILMath.sol";
import {PremiumMath} from "../libraries/PremiumMath.sol";
import {Constants} from "../libraries/Constants.sol";

// Core Indemnifi hook. Deployed on Unichain Sepolia.
//
// LPs call createPolicy() alongside addLiquidity to buy IL coverage.
// afterRemoveLiquidity emits PolicyExitRequested — ReactiveRiskMonitor picks
// this up and calls back settleClaim() through the Reactive callback proxy.
// afterSwap emits SwapObserved so the RSC can track price divergence.
contract IndemnifiHook is IIndemnifiHook, BaseHook, Ownable {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using SafeERC20 for IERC20;

    InsuranceVault public immutable vault;

    // The Reactive callback proxy is the authorized caller for risk management functions.
    // Set after RSC deployment via setCallbackProxy().
    address public callbackProxy;

    mapping(uint256 => Policy) private _policies;
    mapping(bytes32 => RiskTier)  private _riskTier;
    mapping(bytes32 => uint256)   private _premiumBps;
    mapping(bytes32 => bool)      private _paused;
    mapping(address => uint256[]) private _ownerPolicies;

    uint256 public nextPolicyId;

    error CoveragePausedForPool();
    error InvalidThreshold();
    error ZeroNotional();
    error PolicyNotFound();
    error PolicyNotPending();
    error Unauthorized();
    error ExpiredPolicy();

    modifier onlyProxy() {
        if (msg.sender != callbackProxy && msg.sender != owner()) revert Unauthorized();
        _;
    }

    constructor(IPoolManager _poolManager, InsuranceVault _vault, address initialOwner)
        BaseHook(_poolManager)
        Ownable(initialOwner)
    {
        vault = _vault;
    }

    // Called after RSC is deployed so the hook knows which address to trust.
    function setCallbackProxy(address proxy) external onlyOwner {
        callbackProxy = proxy;
    }

    // ── Hook permissions ──────────────────────────────────────────────────

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize:                false,
            afterInitialize:                 false,
            beforeAddLiquidity:              false,
            afterAddLiquidity:               false,
            beforeRemoveLiquidity:           false,
            afterRemoveLiquidity:            true,
            beforeSwap:                      false,
            afterSwap:                       true,
            beforeDonate:                    false,
            afterDonate:                     false,
            beforeSwapReturnDelta:           false,
            afterSwapReturnDelta:            false,
            afterAddLiquidityReturnDelta:    false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // ── Policy creation ───────────────────────────────────────────────────

    // LP calls this after or alongside addLiquidity.
    // Premiums are paid in currency0 of the pool key.
    // hookData passed to removeLiquidity must encode the policyId (uint256).
    function createPolicy(
        PoolKey calldata key,
        uint256 notional,
        uint256 thresholdBps,
        uint256 maxPayout,
        uint256 expiry
    ) external override returns (uint256 policyId) {
        bytes32 pid = PoolId.unwrap(key.toId());

        if (_paused[pid])            revert CoveragePausedForPool();
        if (notional == 0)           revert ZeroNotional();
        if (thresholdBps >= 10_000)  revert InvalidThreshold();

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());

        uint256 bps     = _getCurrentPremiumBps(pid);
        uint256 premium = PremiumMath.calculatePremium(notional, bps);
        address token   = Currency.unwrap(key.currency0);

        policyId = nextPolicyId++;

        _policies[policyId] = Policy({
            owner:        msg.sender,
            poolId:       key.toId(),
            token:        token,
            notional:     notional,
            entryPrice:   sqrtPriceX96,
            thresholdBps: thresholdBps,
            maxPayout:    maxPayout == 0 ? notional : maxPayout,
            premiumPaid:  premium,
            createdAt:    block.timestamp,
            expiry:       expiry,
            status:       PolicyStatus.ACTIVE
        });

        _ownerPolicies[msg.sender].push(policyId);

        // Pull premium from LP, forward to vault.
        IERC20(token).safeTransferFrom(msg.sender, address(vault), premium);
        vault.depositPremium(token, premium);

        emit PolicyCreated(policyId, msg.sender, pid, notional, thresholdBps, premium);
    }

    // ── Hook callbacks ────────────────────────────────────────────────────

    // Emits PolicyExitRequested if hookData encodes a valid active policyId.
    // ReactiveRiskMonitor subscribes to this event and calls back settleClaim().
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        if (hookData.length >= 32) {
            uint256 policyId = abi.decode(hookData, (uint256));
            Policy storage p = _policies[policyId];

            if (p.owner == sender && p.status == PolicyStatus.ACTIVE) {
                (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());
                p.status = PolicyStatus.PENDING_CLAIM;

                emit PolicyExitRequested(
                    policyId,
                    sender,
                    PoolId.unwrap(key.toId()),
                    sqrtPriceX96
                );
            }
        }
        return (IHooks.afterRemoveLiquidity.selector, _zeroDelta());
    }

    // Emits SwapObserved so the RSC can detect price divergence and update risk tiers.
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        (uint160 sqrtPriceX96, int24 tick,,) = poolManager.getSlot0(key.toId());
        emit SwapObserved(PoolId.unwrap(key.toId()), sqrtPriceX96, tick, block.timestamp);
        return (IHooks.afterSwap.selector, 0);
    }

    // ── Claim settlement (called by ReactiveRiskMonitor via callback proxy) ──

    function settleClaim(uint256 policyId, uint160 exitSqrtPriceX96)
        external override onlyProxy
    {
        Policy storage p = _policies[policyId];
        if (p.owner == address(0))  revert PolicyNotFound();
        if (p.status != PolicyStatus.PENDING_CLAIM && p.status != PolicyStatus.ACTIVE)
            revert PolicyNotPending();

        // forge-lint: disable-next-line(block-timestamp)
        if (p.expiry > 0 && block.timestamp > p.expiry) {
            p.status = PolicyStatus.EXPIRED;
            emit ClaimExpired(policyId);
            return;
        }

        uint256 ilBps   = ILMath.calculateILBps(p.entryPrice, exitSqrtPriceX96);
        uint256 ilAmount = ILMath.calculateILAmount(ilBps, p.notional);

        emit ClaimRequested(policyId, p.owner, ilBps);

        (,, uint256 payout) = ILMath.calculatePayout(
            ilAmount,
            p.thresholdBps,
            p.notional,
            p.maxPayout,
            vault.availableForClaims()
        );

        p.status = PolicyStatus.PAID;

        if (payout > 0) {
            vault.payClaim(p.owner, p.token, payout);
            emit ClaimPaid(policyId, p.owner, payout, vault.totalAssets());
        }
    }

    // ── Risk management (called by ReactiveRiskMonitor via callback proxy) ──

    function updateRiskTier(bytes32 poolId, RiskTier newTier) external override onlyProxy {
        RiskTier old = _riskTier[poolId];
        if (old == newTier) return;

        _riskTier[poolId]   = newTier;
        uint256 oldBps      = _premiumBps[poolId] == 0 ? Constants.CALM_PREMIUM_BPS : _premiumBps[poolId];
        uint256 newBps      = PremiumMath.premiumBpsForTier(uint8(newTier));
        _premiumBps[poolId] = newBps;

        emit PremiumRateUpdated(poolId, oldBps, newBps);
        emit RiskTierChanged(poolId, old, newTier, vault.solvencyRatioBps());

        // Auto-pause on shock if vault solvency is already low.
        if (newTier == RiskTier.SHOCK && vault.solvencyRatioBps() < Constants.SOLVENCY_PAUSE_BPS) {
            _paused[poolId] = true;
            emit CoveragePaused(poolId, "shock + low solvency");
        }
    }

    function pauseCoverage(bytes32 poolId) external override onlyProxy {
        _paused[poolId] = true;
        emit CoveragePaused(poolId, "vault health");
    }

    function resumeCoverage(bytes32 poolId) external override onlyProxy {
        require(vault.solvencyRatioBps() >= Constants.SOLVENCY_RESUME_BPS, "vault not recovered");
        _paused[poolId] = false;
        emit CoverageResumed(poolId);
    }

    // ── Views ─────────────────────────────────────────────────────────────

    function getPolicy(uint256 policyId) external view override returns (Policy memory) {
        return _policies[policyId];
    }

    function getPoliciesForOwner(address owner_) external view override returns (uint256[] memory) {
        return _ownerPolicies[owner_];
    }

    function getPremiumForNotional(bytes32 poolId, uint256 notional)
        external view override returns (uint256)
    {
        return PremiumMath.calculatePremium(notional, _getCurrentPremiumBps(poolId));
    }

    function isCoveragePaused(bytes32 poolId) external view override returns (bool) {
        return _paused[poolId];
    }

    function getRiskTier(bytes32 poolId) external view override returns (RiskTier) {
        return _riskTier[poolId];
    }

    function getCurrentPremiumBps(bytes32 poolId) external view override returns (uint256) {
        return _getCurrentPremiumBps(poolId);
    }

    // ── Internal ──────────────────────────────────────────────────────────

    function _getCurrentPremiumBps(bytes32 poolId) internal view returns (uint256) {
        uint256 bps = _premiumBps[poolId];
        return bps == 0 ? Constants.CALM_PREMIUM_BPS : bps;
    }

    // Returns a zero BalanceDelta — used by afterRemoveLiquidity return value.
    function _zeroDelta() internal pure returns (BalanceDelta) {
        return BalanceDelta.wrap(0);
    }
}
