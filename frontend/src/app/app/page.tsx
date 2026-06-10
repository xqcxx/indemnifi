import { CreatePolicyForm } from "@/components/CreatePolicyForm";
import { RiskMeter } from "@/components/RiskMeter";
import { PolicyList } from "@/components/PolicyList";
import { Faucet } from "@/components/Faucet";

export default function ProtectPage() {
  return (
    <div className="mx-auto max-w-7xl px-7 py-12">
      <header className="mb-10">
        <h1
          className="text-white"
          style={{ fontSize: 44, fontWeight: 900, letterSpacing: "-0.03em" }}
        >
          Protect
        </h1>
        <p className="mt-2 text-text-2" style={{ fontSize: 16, fontWeight: 500 }}>
          Buy impermanent-loss coverage for your Uniswap v4 liquidity. Premiums
          are priced live by pool risk and pool into the yield-bearing vault.
        </p>
      </header>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="flex flex-col gap-6">
          <RiskMeter />
          <CreatePolicyForm />
        </div>
        <div className="flex flex-col gap-6">
          <Faucet />
          <PolicyList />
        </div>
      </div>
    </div>
  );
}
