# DISCO BREAKER

A narrow, playable seven-stage tutorial vertical slice for Godot 4.7.2. It opens on an animated title screen and contains the tutorial; campaign, score, lives, progression, inventory, live services and analytics are not implemented.

The portrait UI teaches one-tap red wiring, two-tap blue wiring, three-tap combined wiring, foreman inspection, the cleared-looking crossing trap, and an optional 3 × 3 practice floor. Tap a connection box to cycle `empty → red → blue → combined → empty`. Child-facing copy deliberately avoids developer operator labels. There is no keyboard or gamepad path: every control is a tap/click on the portrait canvas, including dialogue confirmation and the foreman call button.

## Play it

The tutorial deploys to GitHub Pages from `main` on every push (see `.github/workflows/pages.yml`), at:

```
https://yasuhito.github.io/disco-breaker/
```

It is the same deterministic Web export that `scripts/check.sh` builds and `.github/workflows/ci.yml` tests on every pull request - a static bundle with no custom server or backend required, playable directly in a mobile or desktop browser.

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

This is a title-and-tutorial vertical slice. REPAIR THE FLOOR is visibly unavailable (COMING SOON); TUTORIAL is the playable entry. There is no campaign implementation and no code or art copied from SyndromeOut. `docs/architecture.md` documents the three narrow interfaces and the stable semantic-state boundary that keep it that way.

## Code seams

- `src/tutorial_state.gd`: the seven fixed tutorial definitions, deterministic tap cycling, dialogue gates, semantic state, and action trace.
- `src/inspection_semantics.gd`: independent red/blue mod-2 boundary-crossing classification. Witness paths are generated only after an odd logical class is computed, so artwork cannot decide the verdict.
- `src/tutorial_view.gd`: stable 390 × 844 portrait drawing, touch hit testing, the foreman SVG and tactile console presentation, reduced motion, and Web semantic-state publication.
- `tests/run_tests.gd`: tap cycle, guided lessons, independent crossing classes, trap, graduation, and semantic contract.

The final practice needs only three taps from an empty board: red at row 2, column 2, then blue at row 1, column 3 (two taps). Coordinates count from the top left. Calling the foreman passes with no logical error. The optional skip remains available. Campaign gameplay is not implemented in this tutorial-only repository.

Boundary lesson (sixth dot): on a 3 × 3 floor, clear the single red edge syndrome by tapping the upper-left box once, then clear the single blue edge syndrome by tapping the upper-right box twice. Interior placements flip two incident checks; these edge placements flip one. Each exercise uses the same syndrome and logical inspection as final practice, accepting stabilizer-equivalent corrections. The final optional review is the seventh lesson.

The UI uses a tactile disco lighting-console direction. Roboto Regular/Bold are bundled under the SIL Open Font License (see `assets/fonts/OFL.txt`); no external font request is needed. Native mobile touches and mouse clicks share the same one-step input behavior.

## Title and design references

The title borrows the mirror ball, metallic wordmark, perspective floor and two-entry composition from the [archived original mock](docs/design/firstmate-2026-09-17/README.md). Its artwork is independently drawn in Godot with the current glass/console palette and bundled OFL font. The title floor is decorative, not a playable check lattice. No dependencies or remote asset requests are added.

Choose TUTORIAL to begin. The home button in the upper left returns to the title, preserving the current tutorial floor for CONTINUE TUTORIAL. The completion screen offers REPLAY and BACK TO TITLE; replay starts all seven lessons again. Mute is shared and persists, and reduced motion freezes title rotation, light beams and floor flicker. The title is silent. Campaign entry remains disabled until a playable campaign exists.

`node scripts/ci_e2e.mjs` includes the title/navigation browser regressions in `scripts/title_e2e.mjs`. Future ideas, explicitly separate from implemented features, are recorded in [the roadmap](docs/roadmap.md).
