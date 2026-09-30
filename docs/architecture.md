# Tutorial architecture

The vertical slice intentionally has three small interfaces.

`TutorialState` owns the deterministic seven-stage state machine. UI input becomes one of five commands (`confirm`, `tap`, `inspect`, `next`, `skip`), making the same flow usable from touch, headless scripts, and tests. `semantic_state()` is the stable machine-readable boundary; the Web view publishes it as `window.discoBreakerState`.

`InspectionSemantics.inspect()` receives residual red and blue supports plus one boundary cut for each family. Each class is computed independently as intersection parity modulo two. Only after that classification does it select a witness for visual explanation. The 3 × 3 trap therefore fails because its red support has odd crossing parity, not because a red path happened to be drawable.

`tutorial_view.gd` renders into a fixed 390 × 844 design space and letterboxes uniformly at other aspect ratios. Dialogue confirmation removes the coach layer before connection boxes accept taps. The view knows presentation and hit coordinates but never decides whether a floor is safe.

## Surface-code rules

The rules follow SyndromeOut's rotated surface code; the implementation here is independent. Connection boxes are data qubits. Red wiring is X correction and flips incident Z-check floors (drawn red); blue wiring is Z correction and flips incident X-check floors (drawn blue). Both wiring contains both components. Each interior check is the parity of the four surrounding residual components, with two-qubit checks at the corresponding boundaries. A move toggles every incident check, including previously dark floors.

The generated face geometry is shared by syndrome computation and floor illumination. Boundary checks appear as half floors. A syndrome-free residual is safe precisely when its X intersection with the top row and its Z intersection with the left column are both even, matching the opposing logical operators. The trap's residual is a full vertical X string, not a diagonal drawing.

Reference: https://github.com/stn/SyndromeOut (rules inspected at a1a3c53cdc07f15e472b204eba478ec0420c1a92).

All seven tutorial floors are now 3 × 3. Final practice uses an X error at the center and a Z error at the upper-right corner, repaired by one red placement and one blue placement (three taps). The earlier 5 × 5 rules regression is retained only as a test fixture; no extra game mode is exposed.

Fault-floor animation is a stateless failing-lamp envelope, keyed independently by stage, color and face. Each lamp has a separate phase/period and deterministic per-cycle short dropout bursts, a weak recovery and long bright intervals. Each floor's under-glass illumination follows the envelope; a faint colored perimeter remains visible during dropouts and disappears when repaired. No lamp object is drawn at the floor center. Reduced-motion mode uses steady light. No animation randomness enters syndrome state or logical inspection.

Boundary lesson (sixth dot): on a 3 × 3 floor, clear the single red edge syndrome by tapping the upper-left box once, then clear the single blue edge syndrome by tapping the upper-right box twice. Interior placements flip two incident checks; these edge placements flip one. Each exercise uses the same syndrome and logical inspection as final practice, accepting stabilizer-equivalent corrections. The final optional review is the seventh lesson.


## Visual direction and input

The presentation uses a compact disco lighting console: smoked glass checks inside a beveled housing, raised sockets with inset contacts, warm metallic progress dots, and a consistent foreman/CTA treatment. The flush glass panels use a shared diagonal surface reflection, a thin bevel and diffused light beneath the surface, with the existing independent flicker envelope. Lit panels leak a narrow, soft glow from all four edges under the glass; the glow follows that same envelope and is drawn below neighboring panels and tap targets. The round wiring sockets remain the tap targets, distinct from the flat check floors. Brief socket depression and a local success outline are presentation-only; reduced motion disables these animations. Static background, housing and sockets are reused as SVG textures; cached styles avoid allocating identical surfaces every frame. Semantic state is published when input changes it, not recomputed for every animation frame. Body and bold Roboto fonts are bundled with their SIL Open Font License in `assets/fonts/OFL.txt`.

The view handles native touch and mouse input directly. Mouse emulation from touch is disabled so one physical tap advances exactly one wire state. CI includes a native-touch cycle regression alongside the seven-stage mouse-driven flow. `scripts/check.sh` also parses the view explicitly, because an editor import alone may report a script error without returning a failing process status.


## Reward feedback

`RewardFeedback` observes input-driven state transitions, not frames. Extinguishing the last syndrome produces a neutral, silent glass sweep; only a dark floor with an explicitly safe inspection receives a success sting, warm sparks and the foreman's approval. Guided lessons use the same residual inspection before showing success. Failed repairs remain editable through TRY AGAIN; the deliberate crossing-trap demonstration still advances. Boundary red and blue are separate substeps, final practice has a slightly longer reward, and skip/replay/duplicate observations never create success.

The original synth stings are generated once as bounded 16-bit PCM (0.44/0.72 seconds). The speaker button persists mute, stops an active sound immediately, and never replays a missed sound on unmute. Master audio mute is respected. Reduced motion uses the static approval badge and normal result copy without sweeps, particles or portrait motion. Effects do not block input and are cleared when leaving their floor. `window.discoBreakerFeedback` exposes event and playback-start counts for browser verification, separately from game state.
