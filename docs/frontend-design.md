# Indemnifi — Frontend Design System & Build Guide

Authoritative design + build reference for the Indemnifi web app. The visual language is **Unichain.org-inspired — DM Sans Bold, magenta accent (`#fb27ce`) on near-black**. Read `contract-implementation.md` for the ABIs/events this UI consumes. **Everything is real-time from the contracts** (wagmi reads + `useWatchContractEvent`); the only fallback is `useSimulatedScenario` for the demo before deployment.

Stack (installed in `frontend/`): **Next.js 16 (App Router)** · **Tailwind v4** · **wagmi v2** · **RainbowKit v2** · **viem** · **@tanstack/react-query** · **recharts** · **zustand** · **sonner** · **lucide-react**.

---

## 1. Brand & Tone

**Indemnifi** = *indemnify* + *DeFi*. Explicit, priced IL protection for Uniswap v4 LPs. The UI feel: **bold, confident, Unichain-native** — heavy DM Sans, soft rounded surfaces, a single magenta accent for brand moments, flat (no gradients, no shadows), generous borders as the structural device.

---

## 2. Typography — DM Sans, Bold by default

Import in `globals.css`:
```css
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700;800;900&display=swap');
```
(or via `next/font/google` `DM_Sans` with weights `[500,700,800,900]`).

**Default weight 700. Never below 500 anywhere.**

| Role | Size | Weight | Tracking |
|---|---|---|---|
| Hero H1 | 60–72px | 900 | -0.04em, line-height 1.05 |
| Section heading | 40–48px | 900 | -0.03em |
| Card heading | 22–26px | 800 | -0.02em |
| Label / eyebrow | 12–13px | 700 | 0.08em, UPPERCASE |
| Body | 16px | 500 | line-height 1.7 |
| Stat value | 36–48px | 900 | -0.04em |
| Button | 14–16px | 800 | 0.01em |

Stat values, bps, %, addresses, tx hashes use `tabular-nums`.

---

## 3. Color System (single accent: magenta)

| Token | Value | Use |
|---|---|---|
| `--bg` | `#0a0a0a` | Page background |
| `--surface` | `#111111` | Card |
| `--elevated` | `#1a1a1a` | Elevated surface |
| `--border` | `rgba(255,255,255,0.08)` | Default border / dividers |
| `--border-hover` | `rgba(255,255,255,0.15)` | Hover border |
| `--accent` | `#fb27ce` | Primary — CTAs, highlights, brand |
| `--accent-hover` | `#e020b8` | Primary hover |
| `--success` | `#22c55e` | Live / healthy / CALM tier |
| `--info` | `#60a5fa` | Interop / Reactive / VOLATILE-adjacent |
| `--warning` | `#f59e0b` | Pending / VOLATILE tier |
| `--text` | `#ffffff` | Primary text |
| `--text-2` | `rgba(255,255,255,0.5)` | Secondary |
| `--text-muted` | `rgba(255,255,255,0.35)` | Muted |

**Risk-tier → color:** CALM → `--success`, VOLATILE → `--warning`, SHOCK → `--accent` (magenta reads as "highest attention" here). Coverage paused → magenta badge + disabled CTA. Solvency bar: ≥85% success, 70–85% warning, <70% accent/red.

**DO NOT:** gradients, mesh, drop shadows, sharp 0px corners, any accent other than `#fb27ce`, font-weight <500, label text <13px.

---

## 4. Texture, Radius, Spacing

- **Noise overlay** on hero only, opacity 0.04–0.06 (SVG fractalNoise data-URI — see globals.css `.noise`).
- **Radius:** cards/sections 20px · pill buttons 24px · badges 20px · feature cells 16px. No sharp corners.
- **Spacing:** page padding 28–32px · section vertical 64–80px · card padding 28–36px · section separators are `border-top: 1px solid var(--border)`.
- **Grid gap trick:** feature/stat grids use a 1px gap created by the parent's background showing through (parent `--border` bg, children `--bg`).

---

## 5. Component Inventory

### UI primitives (`components/ui/`)
- `Button` — `primary` (magenta pill, weight 800, active `scale(0.97)`), `ghost` (`rgba(255,255,255,0.08)` + `--border-hover`), `white` (white bg / magenta text, for CTA band). Radius 24px.
- `Card` — surface `#111`, radius 20px, 1px border; hover lightens `#0a0a0a→#111`. Optional eyebrow tag, title (800), body.
- `Stat` — uppercase label (11–12px/700) + huge value (36–44px/900), accent number option.
- `Tag` / `Badge` — pink/green/blue tinted eyebrow tags; status badges (Live/Soon/Future, ACTIVE/PAID…).
- `StatusDot` — 8px dot with ring: live=green, soon=magenta, future=white/20.
- `SolvencyBar`, `Input`, `Slider`, `Field`, `Modal`, `Skeleton`, `Spinner`, `Toast` (sonner themed: success=green, error=magenta, info=blue).

### Feature components (`components/`)
- `AnnouncementBanner` — full-width magenta strip above nav, pulse dot + message.
- `Nav` — `#0a0a0a`, bottom border; logo DM Sans 900 with magenta accent letter; links 13/700 muted → white pill on hover; primary `Connect` button magenta pill, ghost secondary.
- `Footer` — top border, muted logo + links.
- `StatsBar` — full-width 3-col grid, border-separated cells, accent numbers.
- `FeatureGrid` — 2×2, 1px-gap-via-bg, tinted tags per card.
- `Roadmap`/`StatusList` — vertical rows with StatusDot + right-side status badge.
- `CTABand` — magenta band, white button.
- `ConnectButton` (RainbowKit restyled), `NetworkBadge`, `RiskMeter`, `VaultHealthPanel`, `CreatePolicyForm`, `PolicyCard`/`PolicyList`, `ScenarioRunner` (11-step timeline), `ComparisonChart` (recharts), `EventFeed`, `ReactiveStatus`.

---

## 6. Pages / Routes

```
src/app/
  layout.tsx     ← DM Sans, providers, AnnouncementBanner, Nav, Footer, <Toaster/>
  page.tsx       ← Landing: hero (noise) → StatsBar → FeatureGrid → Roadmap → CTABand
  app/page.tsx   ← Protect: CreatePolicyForm + RiskMeter (left) · PolicyList (right)
  demo/page.tsx  ← ScenarioRunner timeline + ComparisonChart + result table
  vault/page.tsx ← VaultHealthPanel + capital-allocation + yield chart + claims
```

**Nav:** logo · `Dashboard · Protect · Demo · Vault` · NetworkBadge + ConnectButton.

---

## 7. State & Data Layer (real-time from contracts)

- **`src/providers.tsx`:** `WagmiProvider` + `QueryClientProvider` + `RainbowKitProvider` (dark, accent `#fb27ce`). Chains: Unichain Sepolia (1301) primary; Reactive Lasna (5318007) status-only.
- **`src/lib/contracts.ts`:** addresses from `NEXT_PUBLIC_*`, ABIs from `src/abis/*.json` (`make sync-abis`).
- **Hooks (`src/hooks/`):**
  - Reads (wagmi `useReadContract`/`useReadContracts`): `usePolicy`, `usePoliciesForOwner`, `useVaultState`, `usePoolRiskState`, `useCurrentPremiumBps`, `usePremiumQuote`.
  - Writes: `useCreatePolicy`, `useRunScenario`, `useSettleClaim`.
  - Events (`useWatchContractEvent`): `useWatchIndemnifiEvents` → drives `EventFeed`, live solvency, premium, tier, paused state. **All panels subscribe so the UI updates the instant a chain event lands.**
  - `useSimulatedScenario` (zustand) — demo fallback only; same IL/premium constants as contracts.
- **`src/lib/format.ts`:** `fmtUsd, fmtBps, fmtPct, fmtAddr, tierColor/tierLabel, statusColor, solvencyColor`.

### Env (`frontend/.env.local`)
```
NEXT_PUBLIC_CHAIN_ID=1301
NEXT_PUBLIC_HOOK_ADDRESS=
NEXT_PUBLIC_VAULT_ADDRESS=
NEXT_PUBLIC_YIELD_VAULT_ADDRESS=
NEXT_PUBLIC_SCENARIO_RUNNER_ADDRESS=
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=
```

---

## 8. Contract Binding Cheatsheet (all live)

| UI element | Source | Live via |
|---|---|---|
| Solvency bar | `vault.solvencyRatioBps()` | `VaultHealthUpdated` |
| Vault stats | `totalAssets/totalPremiums/totalClaimsPaid/totalYieldEarned` | `VaultHealthUpdated`, `ClaimPaid` |
| Premium quote | `hook.getPremiumForNotional(poolId, notional)` | refetch on input |
| Risk meter | `hook.getRiskTier / getCurrentPremiumBps` | `RiskTierChanged`, `PremiumRateUpdated` |
| Coverage paused | `hook.isCoveragePaused(poolId)` | `CoveragePaused`/`CoverageResumed` |
| Policy list | `hook.getPoliciesForOwner(addr)` → `getPolicy(id)` | `PolicyCreated`, `ClaimPaid` |
| Create policy | `hook.createPolicy(key, notional, thresholdBps, maxPayout, expiry)` (approve currency0 first) | tx receipt |
| Demo run | `runner.runScenario(0|1|2)` | `StepComplete`×11 + `ScenarioRan` |
| Comparison result | `runner.getLastResult()` → `RunResult` | after `ScenarioRan` |
| Event feed | `PolicyCreated, ClaimPaid, RiskTierChanged, PremiumRateUpdated, CoveragePaused, SwapObserved` | `useWatchContractEvent` |

```ts
export const tierColor = (t:0|1|2) => t===0?"var(--success)":t===1?"var(--warning)":"var(--accent)";
export const tierLabel = (t:0|1|2) => (["CALM","VOLATILE","SHOCK"] as const)[t];
```

---

## 9. Micro-interactions

`transition: all .15s ease` on hover. Buttons `active:scale(0.97)`. Nav links fade bg on hover. Cards lighten `#0a0a0a→#111`. Live dots pulse opacity 0.4→1, 1s alternate. CTA primary darkens `#fb27ce→#e020b8`. Respect `prefers-reduced-motion` (kill pulses/count-ups).

---

## 10. Accessibility

Never state-by-color-alone — tier/status badges include label text. Visible focus ring in `--accent`. Numbers mono-tabular. Addresses `0x1234…abcd`, copy-on-click. Skeletons, no layout shift. Designed empty states: connect-wallet, wrong-network, no-policies, coverage-paused.

---

## 11. Build Order

1. `globals.css` tokens + DM Sans + noise + radii (done).
2. `providers.tsx` + wire into `layout.tsx`; AnnouncementBanner + Nav + Footer.
3. `lib/{contracts,format,chains,cn}.ts`.
4. UI primitives (Button, Card, Stat, Tag, StatusDot, SolvencyBar).
5. Landing page sections (hero, StatsBar, FeatureGrid, Roadmap, CTABand).
6. `useSimulatedScenario` + Demo page (demo-ready before deploy).
7. Read hooks + VaultHealthPanel + Dashboard live data.
8. CreatePolicyForm + PolicyList (writes).
9. EventFeed + ReactiveStatus live layer.
10. Vault charts; `make sync-abis`; fill `.env.local`; demo → on-chain.