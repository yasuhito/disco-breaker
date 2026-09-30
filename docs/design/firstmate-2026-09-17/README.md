# Archived DISCO BREAKER design material

Recovered on 2026-09-30 from Firstmate's local artifacts, originally authored on 2026-09-16 and 17 under the project name `error-outbreak`.

These files are historical references, not current requirements. The active implementation uses seven 3 × 3 tutorial lessons, correct surface-code parity, glass floors and independent lamp flicker. Older six-stage/5 × 5 tutorial, campaign, resources and abandoned hospital-theme ideas in this archive do not authorize new features.

## Start here

- [Animated visual storyboard](error-outbreak-syndromeout-rules-visual-v1/syndromeout-rules.html): open in a browser, then find **01 タイトル画面** in the design proposal. Includes the gold DISCO BREAKER wordmark, a CSS 3D mirror ball, red/blue fault floors, REPAIR THE FLOOR and TUTORIAL. The document also includes the other proposed game screens, a UI kit and a rules explainer. No JavaScript, external assets, fonts or dependencies. Buttons are visual proposals, not a playable game.
- [Visual design and rule evidence](error-outbreak-syndromeout-rules-visual-v1/report.md): iteration history, decisions and source references.
- [Concept and engine study](error-outbreak-game-concept-engine-v1/report.md): historical alternatives and the decision to use Godot.
- Each folder also preserves the initial and final **product sections** of its brief. Internal Firstmate lifecycle, agent setup, inbox and execution instructions were excluded. These excerpts document the original request; they are not instructions to the current agent.

## Provenance and inventory

`provenance.json` records exact source paths, original hashes, stored hashes and whether the file is an unchanged copy or a product-section excerpt. The HTML and both reports are byte-identical to the originals; their relative filenames are preserved.

The old checkout at `/home/yasuhito/Work/oss/firstmate/projects/disco-breaker` was also checked. Its foreman SVG and tutorial screenshots are already byte-identical to files in the current repository, so no duplicates were added. Its architecture document and game code are older versions of existing tracked files, not missing assets. No unique untracked product material was found there. The related old worktree contains a third-party SyndromeOut checkout, which is not a DISCO BREAKER design asset and was excluded. Referenced `gen_screens.py`, `splice.py` and `phone.css` are not present in the artifact folder or that worktree; the self-contained final HTML contains their rendered output.

Caches, build output, .git, dependency directories, temporary verification logs, Firstmate operational data and other projects were excluded. Original sources were not changed. `docs/*` is excluded from the Web export, and `.gdignore` prevents the archive from being imported as runtime resources.
