# DISCO BREAKER tutorial

A narrow, playable six-stage tutorial vertical slice for Godot 4.7.2. It contains only the tutorial: no title flow, campaign, score, lives, progression, inventory, live services, or analytics.

The portrait UI teaches one-tap red wiring, two-tap blue wiring, three-tap combined wiring, foreman inspection, the cleared-looking crossing trap, and an optional 5 × 5 graduation floor. Tap a connection box to cycle `empty → red → blue → combined → empty`. Child-facing copy deliberately avoids developer operator labels. There is no keyboard or gamepad path: every control is a tap/click on the portrait canvas, including dialogue confirmation and the foreman call button.

## Play it

The tutorial deploys to GitHub Pages from `main` on every push (see `.github/workflows/pages.yml`), at:

```
https://yasuhito.github.io/disco-breaker/
```

It is the same deterministic Web export that `scripts/check.sh` builds and `.github/workflows/ci.yml` tests on every pull request — a static bundle with no custom server or backend required, playable directly in a mobile or desktop browser.

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

`scripts/browser_e2e.sh` is the local-development E2E loop and depends on `chrome-devtools-axi`, which is not available on GitHub-hosted runners. CI instead runs `scripts/ci_e2e.mjs`, a Playwright port of the same canvas input-injection surface and `window.discoBreakerState` assertions (`npm ci`, `npx playwright install --with-deps chromium`); both drive every tutorial control, and CI rejects console errors.

## Scope

This is a tutorial-only vertical slice. It does not and will not include a title flow, campaign, score, lives, progression, inventory, live services, or analytics — and no material copied from SyndromeOut. `docs/architecture.md` documents the three narrow interfaces and the stable semantic-state boundary that keep it that way.

## Code seams

- `src/tutorial_state.gd`: the six fixed tutorial definitions, deterministic tap cycling, dialogue gates, semantic state, and action trace.
- `src/inspection_semantics.gd`: independent red/blue mod-2 boundary-crossing classification. Witness paths are generated only after an odd logical class is computed, so artwork cannot decide the verdict.
- `src/tutorial_view.gd`: stable 390 × 844 portrait drawing, touch hit testing, the separable-feature foreman SVG and mouth animation, reduced motion, and Web semantic-state publication.
- `tests/run_tests.gd`: tap cycle, guided lessons, independent crossing classes, trap, graduation, and semantic contract.
