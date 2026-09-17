# DISCO BREAKER tutorial

A narrow, playable six-stage tutorial vertical slice for Godot 4.7.2. It contains only the tutorial: no title flow, campaign, score, lives, progression, inventory, or live service code.

The portrait UI teaches one-tap red wiring, two-tap blue wiring, three-tap combined wiring, foreman inspection, the cleared-looking crossing trap, and an optional 5 × 5 graduation floor. Tap a connection box to cycle `empty → red → blue → combined → empty`. Child-facing copy deliberately avoids developer operator labels.

## Run and export

Use Godot 4.7.2 with the Compatibility renderer:

```sh
godot --path .
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8877 --directory build/web
```

The Web export is static and requires no application backend. A basic static host is enough.

## Deterministic validation

```sh
./scripts/check.sh
./scripts/browser_e2e.sh
```

`check.sh` runs focused unit/integration tests, executes the full tutorial through scripted model input, writes machine-readable final state to `artifacts/headless-state.json`, writes an ordered JSONL action trace to `artifacts/action-trace.jsonl`, and builds the Web export.

`browser_e2e.sh` uses `chrome-devtools-axi` against that export at 390 × 844, plays every stage through canvas input, verifies `window.discoBreakerState`, and saves representative screenshots. On failure it saves `artifacts/browser-failure.png`, browser console output, and server output.

Set `DISCO_BREAKER_REDUCED_MOTION=1` for deterministic native captures without animation. The Web build also honors the browser's `prefers-reduced-motion` setting.

## Code seams

- `src/tutorial_state.gd`: the six fixed tutorial definitions, deterministic tap cycling, dialogue gates, semantic state, and action trace.
- `src/inspection_semantics.gd`: independent red/blue mod-2 boundary-crossing classification. Witness paths are generated only after an odd logical class is computed, so artwork cannot decide the verdict.
- `src/tutorial_view.gd`: stable 390 × 844 portrait drawing, touch hit testing, the separable-feature foreman SVG and mouth animation, reduced motion, and Web semantic-state publication.
- `tests/run_tests.gd`: tap cycle, guided lessons, independent crossing classes, trap, graduation, and semantic contract.
