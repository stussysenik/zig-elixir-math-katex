# Progress

## 2026-03-10

### Checkpoint 1

- Scaffolded a fresh Phoenix 1.8 LiveView app in-place with `--no-ecto`.
- Switched the repo to Bun-managed frontend dependencies.
- Added `flake.nix`, `.env.example`, and repo hygiene updates.

### Checkpoint 2

- Implemented the CLI-first pipeline in Elixir.
- Added explicit object-state structs for query, symbol, proof, graph, and result aggregation.
- Added dual `N -> S` adapters:
  - deterministic stub
  - NVIDIA NIM HTTP adapter
- Added the mock verifier gate and graph payload builder.
- Added `mix math.prove`.

### Checkpoint 3

- Replaced the default Phoenix landing page with `MathOrchestratorLive`.
- Added server-owned LiveView state for:
  - query input
  - status
  - verification gate
  - symbolic payload
  - proof state
  - graph config
  - layer toggles
- Added KaTeX, Desmos, and GeoGebra hooks.
- Moved third-party graph script loading into the JS layer so LiveView still boots cleanly.

### Checkpoint 4

- Added ExUnit tests for the pipeline and LiveView.
- Added Playwright E2E coverage for:
  - prompt submission
  - KaTeX rendering
  - proof output
  - Desmos layer toggle
- Fixed the Playwright harness by:
  - moving test traffic to `localhost`
  - forcing `PHX_SERVER=true`
  - fixing runtime port handling

### Verification performed

- `mix test`
- `mix assets.build`
- `mix math.prove "derivative of sin(x)"`
- `bun run test:e2e`

### Open next slices

- Replace the mock verifier with a real Lean worker boundary.
- Add the SymPy/Python bridge.
- Add notebook persistence and export formats.
- Add vision ingestion and human-in-the-loop correction.
