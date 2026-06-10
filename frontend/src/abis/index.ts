// ABIs from `make sync-abis`. We export the `.abi` array from each artifact.
import IndemnifiHookArtifact from "./IndemnifiHook.json";
import InsuranceVaultArtifact from "./InsuranceVault.json";
import MockYieldVaultArtifact from "./MockYieldVault.json";
import DemoScenarioRunnerArtifact from "./DemoScenarioRunner.json";
import type { Abi } from "viem";

export const indemnifiHookAbi = IndemnifiHookArtifact.abi as Abi;
export const insuranceVaultAbi = InsuranceVaultArtifact.abi as Abi;
export const mockYieldVaultAbi = MockYieldVaultArtifact.abi as Abi;
export const demoScenarioRunnerAbi = DemoScenarioRunnerArtifact.abi as Abi;

// Minimal ERC-20 ABI for approvals and balances.
export const erc20Abi = [
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "decimals",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
  {
    type: "function",
    name: "symbol",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "string" }],
  },
] as const satisfies Abi;
