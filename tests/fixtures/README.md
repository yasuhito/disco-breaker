# Tutorial flow fixtures

`flow_pairs.json` and `flow_followup.json` are copied unchanged from the
evidence of the approved seven-lesson proposal (branch `disco-pixel-design`
at `0768655`, `docs/design/pixel-system-2026-10-31/README.md`, "作者向けの注と確かめたこと").
They were produced by Godot 4.7.2 from the then-current `src/tutorial_state.gd`
and `src/inspection_semantics.gd` (`verify_pairs.gd`, `verify_followup.gd`,
kept outside the checkout in `/tmp/disco-tutorial-flow-evidence/`).

`tests/run_tests.gd` replays every board through the real model and the
lesson flow: each board must keep the recorded floors, leftovers and
inspection verdict, and the lesson may continue exactly when the floor is
dark and the inspection is safe.
