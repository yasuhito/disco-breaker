# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Use Godot 4.7.2 and the Compatibility renderer; run the complete local validation with `./scripts/check.sh` and browser validation with `./scripts/browser_e2e.sh`.
- Keep inspection decisions in `src/inspection_semantics.gd`; rendered witness paths explain an already-computed parity result and must never determine it.
- `docs/architecture.md` documents the tutorial's three intentionally narrow interfaces and stable semantic-state boundary.
- CI (`.github/workflows/ci.yml`) can't use `chrome-devtools-axi` (local-only); it runs `scripts/ci_e2e.mjs`, a Playwright port of `scripts/browser_e2e.sh`'s canvas input-injection surface. Keep both in sync when tutorial controls change. `.github/workflows/pages.yml` deploys the same `scripts/check.sh` Web export to GitHub Pages from `main`.
- `export_presets.cfg`'s Web preset uses `export_filter="all_resources"`, so any new top-level dependency directory (e.g. `node_modules/`) must be added to its `exclude_filter` or it leaks into `index.pck`.
- Godot editor/export-template versions in CI are pinned by SHA-256 in `scripts/setup_godot_ci.sh`; bump both the version and the checksums together when upgrading Godot.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
