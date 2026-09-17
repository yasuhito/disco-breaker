# Tutorial architecture

The vertical slice intentionally has three small interfaces.

`TutorialState` owns the deterministic six-stage state machine. UI input becomes one of five commands (`confirm`, `tap`, `inspect`, `next`, `skip`), making the same flow usable from touch, headless scripts, and tests. `semantic_state()` is the stable machine-readable boundary; the Web view publishes it as `window.discoBreakerState`.

`InspectionSemantics.inspect()` receives residual red and blue supports plus one boundary cut for each family. Each class is computed independently as intersection parity modulo two. Only after that classification does it select a witness for visual explanation. The 3 × 3 trap therefore fails because its red support has odd crossing parity, not because a red path happened to be drawable.

`tutorial_view.gd` renders into a fixed 390 × 844 design space and letterboxes uniformly at other aspect ratios. Dialogue confirmation removes the coach layer before connection boxes accept taps. The view knows presentation and hit coordinates but never decides whether a floor is safe.
