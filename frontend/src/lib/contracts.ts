import {
  type Address,
  type Hex,
  encodeAbiParameters,
  keccak256,
  zeroAddress,
} from "viem";
import {
  indemnifiHookAbi,
  insuranceVaultAbi,
  mockYieldVaultAbi,
  demoScenarioRunnerAbi,
} from "@/abis";

// IMPORTANT: each NEXT_PUBLIC_* var MUST be referenced by a static literal
// (process.env.NEXT_PUBLIC_FOO), not a computed key (process.env[k]). Next.js
// only inlines env vars into the CLIENT bundle when it can see the literal at
// build time. A dynamic key works on the server but becomes undefined in the
// browser — which previously made every address fall back to the zero address.
const toAddr = (v: string | undefined): Address =>
  v && v.startsWith("0x") ? (v as Address) : zeroAddress;

export const CHAIN_ID = Number(process.env.NEXT_PUBLIC_CHAIN_ID || "1301");

export const addresses = {
  hook: toAddr(process.env.NEXT_PUBLIC_HOOK_ADDRESS),
  vault: toAddr(process.env.NEXT_PUBLIC_VAULT_ADDRESS),
  yieldVault: toAddr(process.env.NEXT_PUBLIC_YIELD_VAULT_ADDRESS),
  scenarioRunner: toAddr(process.env.NEXT_PUBLIC_SCENARIO_RUNNER_ADDRESS),
  weth: toAddr(process.env.NEXT_PUBLIC_WETH_ADDRESS),
  usdc: toAddr(process.env.NEXT_PUBLIC_USDC_ADDRESS),
} as const;

export const POOL_FEE = Number(process.env.NEXT_PUBLIC_POOL_FEE || "3000");
export const POOL_TICK_SPACING = Number(
  process.env.NEXT_PUBLIC_POOL_TICK_SPACING || "60",
);

export const WALLETCONNECT_PROJECT_ID =
  process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "indemnifi-dev";

export const abis = {
  hook: indemnifiHookAbi,
  vault: insuranceVaultAbi,
  yieldVault: mockYieldVaultAbi,
  scenarioRunner: demoScenarioRunnerAbi,
} as const;

// True when contract addresses are present in env.
export function isConfigured(): boolean {
  return (
    addresses.hook !== zeroAddress &&
    addresses.vault !== zeroAddress &&
    addresses.weth !== zeroAddress &&
    addresses.usdc !== zeroAddress
  );
}

export function isRunnerConfigured(): boolean {
  return (
    addresses.scenarioRunner !== zeroAddress && addresses.vault !== zeroAddress
  );
}

export interface PoolKey {
  currency0: Address;
  currency1: Address;
  fee: number;
  tickSpacing: number;
  hooks: Address;
}

// currency0 = lower address (v4 convention) = premium/claim token.
export function sortedCurrencies(a: Address, b: Address): [Address, Address] {
  return a.toLowerCase() < b.toLowerCase() ? [a, b] : [b, a];
}

export function getPoolKey(): PoolKey {
  const [c0, c1] = sortedCurrencies(addresses.weth, addresses.usdc);
  return {
    currency0: c0,
    currency1: c1,
    fee: POOL_FEE,
    tickSpacing: POOL_TICK_SPACING,
    hooks: addresses.hook,
  };
}

export function premiumToken(): Address {
  return getPoolKey().currency0;
}

// PoolId = keccak256(abi.encode(PoolKey)), matching v4 PoolIdLibrary.
export function getPoolId(key: PoolKey = getPoolKey()): Hex {
  return keccak256(
    encodeAbiParameters(
      [
        {
          type: "tuple",
          components: [
            { name: "currency0", type: "address" },
            { name: "currency1", type: "address" },
            { name: "fee", type: "uint24" },
            { name: "tickSpacing", type: "int24" },
            { name: "hooks", type: "address" },
          ],
        },
      ],
      [
        {
          currency0: key.currency0,
          currency1: key.currency1,
          fee: key.fee,
          tickSpacing: key.tickSpacing,
          hooks: key.hooks,
        },
      ],
    ),
  );
}
