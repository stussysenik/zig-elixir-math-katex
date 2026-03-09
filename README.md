# MathViz

Verified-first math orchestration built on Phoenix LiveView.

The current app ships a greenfield Phoenix 1.8 LiveView surface with:

- a shared CLI and web pipeline
- a dual `N -> S` morphism (`stub` fallback plus NVIDIA NIM adapter)
- a mocked Lean-shaped verifier gate
- KaTeX rendering
- Desmos and GeoGebra layer hooks
- Playwright and ExUnit coverage for the shipped flow

The design goal is simple: do not render graph layers until verification passes.

## What Ships Today

### Core pipeline

- `MathViz.Pipeline.run/2` is the single entrypoint for web and CLI flows.
- `mix math.prove "derivative of sin(x)"` runs the same orchestration as the LiveView.
- `MathViz.Morphisms.NlpRouter.Stub` handles deterministic local parsing.
- `MathViz.Morphisms.NlpRouter.Nim` calls NVIDIA NIM with an OpenAI-compatible `chat/completions` request.
- `MathViz.Morphisms.Verifier.Mock` simulates the Lean verification boundary and hard-gates graph rendering.
- `MathViz.Morphisms.GraphBuilder.Default` produces Desmos and GeoGebra payloads from the verified symbolic state.

### Web UI

- `MathOrchestratorLive` owns the pipeline state, toggles, and render gating.
- KaTeX output is rendered via a LiveView hook.
- Desmos and GeoGebra are loaded lazily from the browser and only receive payloads after verification succeeds.
- Layer toggles are server-driven, not client-owned React state.

## Setup

### Local prerequisites

- Elixir / Erlang
- Bun
- Node-compatible browser tooling for Playwright
- Optional: `nix develop` via `flake.nix`

### Install

```bash
mix setup
```

### Environment

Create `.env.local` from `.env.example`.

```bash
cp .env.example .env.local
```

Supported variables:

- `MATH_VIZ_NLP_MODE=stub|nim|dual`
- `NVIDIA_NIM_API_KEY`
- `NVIDIA_NIM_BASE_URL`
- `NVIDIA_NIM_MODEL`
- `NVIDIA_NIM_TIMEOUT_MS`

Behavior:

- `stub`: always uses the deterministic parser
- `nim`: always uses NVIDIA NIM and errors if the key is missing
- `dual`: tries NVIDIA NIM first, then falls back to the stub adapter

## Run

### Web

```bash
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000).

### CLI

```bash
mix math.prove "derivative of sin(x)"
```

## Test And Build

### Elixir tests

```bash
mix test
```

### Assets

```bash
mix assets.build
```

### Browser tests

```bash
bun run playwright:install
bun run test:e2e
```

## Repo Notes

- `PROGRESS.md` tracks the implementation checkpoints and verification steps.
- `flake.nix` provides a reproducible shell for Elixir, Bun, Python, and `elan`.
- The current verifier is intentionally mocked; the real Lean and SymPy bridges are next-phase integrations.
- Vision ingest, persistence, and exports are not in this version yet.
