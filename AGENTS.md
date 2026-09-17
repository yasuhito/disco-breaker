# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Use Godot 4.7.2 and the Compatibility renderer; run the complete local validation with `./scripts/check.sh` and browser validation with `./scripts/browser_e2e.sh`.
- Keep inspection decisions in `src/inspection_semantics.gd`; rendered witness paths explain an already-computed parity result and must never determine it.
- `docs/architecture.md` documents the tutorial's three intentionally narrow interfaces and stable semantic-state boundary.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
