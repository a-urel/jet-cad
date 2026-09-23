# Drawing tools spec — review round 1

**Spec:** [2026-09-23-drawing-tools-design.md](../specs/2026-09-23-drawing-tools-design.md),
revision 1 at `f71f469`.

**Reviewers.** Two ran on 2026-09-23, independently and read-only, from
the same prompt:
- **Codex CLI** (`gpt-5.5`, `--sandbox read-only`): "Not ready". 9
  findings: 2 BLOCKER, 6 MAJOR and 1 MINOR.
- **Copilot CLI** (`--allow-all-tools`): "Ready with fixes". 5 findings: 1
  BLOCKER, 1 MAJOR and 3 MINOR. It ran to the end with no usage-limit
  message. `git status --short` on the main checkout was clean afterwards.

Every finding was re-checked against the tree, or against the Flutter SDK
at `/opt/homebrew/Caskroom/flutter/3.27.3/flutter`, before it was ruled on.
The two reviewers overlap on three findings, which leaves 13 distinct ones.
**All 13 are applied in revision 2, and none was rejected.** The raw
reports follow the table verbatim.

| # | finding (source) | verified | ruling in revision 2 |
|---|---|---|---|
| 1 | **Shell shortcuts take letters from the focused `TextField`.** Typing "late" switches tools. (Codex B2, Copilot B1) | yes: `editable_text.dart:726-737` "Shortcuts prevent text input fields from receiving their keystrokes"; the shell's `CallbackShortcuts` is an ancestor (`main.dart:136`) | D9: a `Shortcuts` guard on the field maps every shell letter to `DoNothingAndStopPropagationTextIntent`. The widget test must use real key events, not `enterText`. M-05v |
| 2 | **The field sits inside the `InteractionLayer`.** A click on it is a canvas click that requests canvas focus. (Codex B2) | yes: `interaction_layer.dart:129-131`; `planner_view.dart:96-134` | D9 and Files: the planner view's root is a `Stack`, and `TextEntryOverlay` sits outside the layer |
| 3 | **A self-intersecting polyline triangulates to an empty list, not null**, so the fill fallback could never trigger. (Codex B1) | yes: `triangulate.dart:10-13, 39`; `commands.dart:602, 652-669` | D11: `addDraftedRegion` returns null for an empty **polyline** triangulation. A circle's empty triangulation is normal. M-05q rewritten |
| 4 | **A canvas click commits, but blur cancels**, and focus moves before the tool sees the click. (Codex M1) | yes: `interaction_layer.dart:131` | D9: the tool owns the `TextEditingController` and a canvas click commits synchronously. One rule: Enter or a canvas click commits; Escape, a tool switch or another blur cancels. M-05y |
| 5 | **Snap precedence was stated two ways**, and `selfSnap` was ordered against object snap only implicitly. (Codex M2) | yes: the spec's summary against D4; `drag_snap.dart:33-93` | summary reworded. D4 now reads `selfSnap` first, beating object snap, then `resolveDragPoint` unchanged. M-05w |
| 6 | **Finish rules and zero-length refusal clashed** (a line's first-point double-click; a polyline with one vertex). (Codex M3) | yes: the spec's D6 | D6: a line only finishes on its start after at least one committed segment. A polyline's `selfSnap` gives first (3+ vertices), then last (2+), then null. M-05x |
| 7 | **`SweepTracker`'s tie cases** (`τ == 0`, a full circle) were undefined as decisions. (Codex M4, Copilot m3) | yes: the spec's D8 | D8: `τ == 0` is counter-clockwise, the sign comes from the cumulative `τ`, and a full circle is refused. Deterministic tests. M-05z |
| 8 | **Selection and grips are painted under any active tool.** Clearing them was left to the shell's discipline. (Codex M5) | yes: `selection_overlay.dart` paints the selection and grips for the active tool | D5: one shell `_activate` for every activation, with a widget test that it clears the selection |
| 9 | **`paint_allocation_test` does not exercise the overlay**, so D12's claim was ungated. (Codex M6) | yes: the test builds only `DraftPainter` and `VerticesDrawSink` (140, 147) | D12: the claim is narrowed, and a structural overlay test is added (same calls at 10 and 1,000 entities; one rubber-band `drawPath`). M-05s |
| 10 | **Scalars 2 and 3 of a text are inert** with `textAttrs: 0`, so a test cannot see them. (Codex m1, Copilot M1) | yes: `text_geometry.dart:191-196` | D2 and D9: they are documented as padding, and the width factor and oblique angle inherit from the style. A test with the style's `widthFactor` at 0.8. M-05t |
| 11 | **M-05d's redo scenario cannot tell the mutant apart.** A baked handle replays either way. (Copilot m1) | yes: `AddEntityCommand` stores the record | M-05d keeps only "draw, undo, draw again". Redo stability stays with exit criterion 2 |
| 12 | **The field could remount on every camera notification** and lose focus mid-typing. (Copilot m2) | yes, as a design gap: D9 did not say | D9: a stable `Positioned` whose element is never rebuilt by the camera. A pan and zoom test mid-typing. M-05u |
| 13 | **Evidence gaps**: the empty-versus-null triangulation, the override bits, Flutter shortcut routing, overlay painting and allocation coverage. (both) | yes | added to "Evidence of record" |

**No finding contradicted the brainstormed product decisions.** Every
ruling tightens how they are built.

---

## Raw report — Codex CLI (`gpt-5.5`)

Not ready.

### B1 BLOCKER — Self-intersecting filled polyline fallback is unreachable
Spec section: D6/D13, M-05q.

Evidence: The spec treats a self-intersecting closed polyline as `triangulationFor == null` and says to commit a plain boundary instead ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:551)). Actual code distinguishes `null` from empty triangulation: `triangulateSimplePolygon` returns an empty list for self-intersections ([triangulate.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/geometry/triangulate.dart:10), [triangulate.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/geometry/triangulate.dart:39)); `triangulationFor` returns that list for closed polylines ([commands.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/document/commands.dart:652)); `AddRegionCommand.refusalReason` only refuses `null` ([commands.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/document/commands.dart:602)).

Why it matters: The described helper will create a region with empty triangles, not a plain boundary, so M-05q is testing behavior the design cannot produce.

Proposed fix: Decide whether empty polyline triangulation is a valid no-fill region or a fallback trigger. If fallback is intended, make `addDraftedRegion` treat `triangles.isEmpty` as refusal for polylines only, while preserving circles, whose `triangulationFor` also returns empty by design.

### B2 BLOCKER — TextField shortcut and focus assumptions are false
Spec section: D5/D9 text entry and shortcut routing.

Evidence: The spec says tool shortcuts “never fire while text field has focus” because `TextField` consumes character keys first ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:314)). Flutter says the opposite: “Shortcuts prevent text input fields from receiving their keystrokes” ([editable_text.dart](/opt/homebrew/Caskroom/flutter/3.27.3/flutter/packages/flutter/lib/src/widgets/editable_text.dart:726)). The app-level `CallbackShortcuts` wraps the planner body ([main.dart](/Users/ahmeturel/Projects/oss/jet-cad/apps/floor_planner/lib/main.dart:136)), and `CallbackShortcuts` handles matched activators ([shortcuts.dart](/opt/homebrew/Caskroom/flutter/3.27.3/flutter/packages/flutter/lib/src/widgets/shortcuts.dart:1220)). Also, the planned overlay is inside `PlannerView`’s `InteractionLayer` child stack ([planner_view.dart](/Users/ahmeturel/Projects/oss/jet-cad/apps/floor_planner/lib/planner_view.dart:93)); `InteractionLayer` requests focus on pointer down before forwarding to the tool ([interaction_layer.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart:129)).

Why it matters: Typing `l`, `p`, `r`, `c`, `a`, or `t` in the text field can activate tools instead of inserting text. Clicking the field can also route a canvas pointer event and steal focus back to the interaction layer.

Proposed fix: Put text entry outside the `InteractionLayer` hit/focus subtree or explicitly filter those events. Add a lower `Shortcuts`/`CallbackShortcuts` guard around the field that stops all tool shortcut activators while preserving text input, and test every tool-letter key with the field focused.

### M1 MAJOR — Canvas-click commit contradicts blur-cancels-text
Spec section: D9 TextTool.

Evidence: The spec says a canvas click while text is pending commits the current non-empty string ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:448)), but also says losing focus by any route other than submitting cancels text ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:470)). Current canvas pointer handling requests interaction focus on down ([interaction_layer.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart:129)).

Why it matters: An implementation can reasonably cancel before the tool sees the canvas click, or commit on click and suppress blur cancellation. Those are different user-visible behaviors.

Proposed fix: Pick one rule. If canvas click submits text, the blur handler needs a guarded “commit in progress” path. If blur always cancels, remove canvas-click commit from D9 and tests.

### M2 MAJOR — Snap precedence is internally inconsistent
Spec section: “What this delivers” and D4.

Evidence: The summary says `resolveDragPoint` applies object snap, then shift-ortho, then grid ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:132)). Actual code and the earlier evidence section say ortho first, object snap queried at raw point and winning, grid fallback with re-pin ([drag_snap.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/index/drag_snap.dart:33), [drag_snap.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/index/drag_snap.dart:53), [drag_snap.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/index/drag_snap.dart:68), [drag_snap.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/index/drag_snap.dart:80)). D4 also runs `selfSnap` before `resolveDragPoint` ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:267)).

Why it matters: Near a current endpoint and an existing entity endpoint, implementers can choose different winners. Shift-ortho tests can also assert the wrong priority.

Proposed fix: State the exact order once: self-snap priority, then existing `resolveDragPoint` behavior. Add a test where self-snap and object snap are both within aperture.

### M3 MAJOR — Finish-vs-zero-length rules conflict
Spec section: D6 line and polyline behavior.

Evidence: The line tool says clicking the current start again finishes the chain ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:344)), then says zero-length candidate segments are refused and the tool keeps waiting ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:349)). The polyline section likewise says receiving the last vertex again finishes open, but also says a click coincident with the previous vertex is ignored ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:365)).

Why it matters: A first-point double click can either exit the line tool or be ignored. A last-vertex polyline click can either finish or be treated as duplicate input.

Proposed fix: Define phase-specific precedence: for example, current-start finish only after at least one committed line segment, and previous-vertex duplicate handling either before or after “finish open,” with tests for both edge cases.

### M4 MAJOR — SweepTracker has undefined tie cases
Spec section: D8 ArcTool.

Evidence: `sweepTo` uses `tau >= 0` to choose CCW, while `delta == 0` refuses the arc ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:407), [drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:416)). The spec also claims moving back past start reverses direction ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:424)).

Why it matters: With no hover, exact cancellation back to `tau == 0`, or an intended full circle ending exactly at the start angle, the sign and refusal behavior are ambiguous. The random differential test explicitly skips near multiples of `2π`, so it will not pin this down.

Proposed fix: Specify the `tau == 0` tie-breaker, whether exact full-circle arcs are allowed, and whether sign comes from cumulative tau or last nonzero movement. Add deterministic tests for those cases.

### M5 MAJOR — Active drawing tools still receive selection/grip overlay unless shell clears it
Spec section: D5/D12 invariants.

Evidence: The spec keeps `ToolController` unchanged and makes selection clearing a shell activation step ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:319), [tool.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/tool.dart:114)). But `SelectionOverlayPainter` always paints selected/hovered outlines before invoking the active tool’s world overlay, then paints grips and the active tool’s screen overlay ([selection_overlay.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart:153), [selection_overlay.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart:201)).

Why it matters: Tests or future UI paths that call `ToolController.activate` directly will leave selection outlines/grips visible while a drawing tool is active. Non-Select tools do get both overlay callbacks, plus the selection overlay.

Proposed fix: Either centralize drawing-tool activation in one app helper and require tests to use it, or make the render layer suppress selection/grips whenever the active tool is not `SelectTool`.

### M6 MAJOR — Frame-path allocation gate does not exercise drawing overlays
Spec section: D12 and exit gates.

Evidence: The spec says the drawing-tool frame path is covered by keeping `paint_allocation_test.dart` green ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:526)). That test constructs `DraftPainter` and `VerticesDrawSink` only ([paint_allocation_test.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart:135)); drawing tool overlays are called from `SelectionOverlayPainter`, outside that path ([selection_overlay.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart:163), [selection_overlay.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart:203)).

Why it matters: A rubber-band implementation that allocates per vertex or per selected entity can pass the stated allocation gate unchanged.

Proposed fix: Add a dedicated overlay allocation invariant, or narrow D12 to DraftPainter only and add a named mutant/gate for drawing-tool overlay allocation.

### m1 MINOR — Text widthFactor/oblique scalars are ignored with `textAttrs: 0`
Spec section: D9 text payload.

Evidence: The spec stores `[heightMm, 0, 1, 0]` with `textAttrs: 0` ([drawing-tools-design.md](/Users/ahmeturel/Projects/oss/jet-cad/docs/superpowers/specs/2026-09-23-drawing-tools-design.md:451)). Existing text attributes only read width factor and oblique from scalars when override bits are set ([entity_store.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/document/entity_store.dart:64), [text_geometry.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/geometry/text_geometry.dart:191)). The current Standard style happens to default to width `1.0` and oblique `0.0` ([tables.dart](/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d/lib/src/document/tables.dart:300)).

Why it matters: A default-style fixture passes, but a document with modified Standard style will not render the stored scalar width/oblique values.

Proposed fix: Say these two scalars are padding and style-inherited, or set the override bits if placed text must always use width `1` and oblique `0`.
---

## Raw report — Copilot CLI

Now let me read the remaining spec sections (Architecture, mutants, gates) and start verifying
against actual code.

Good, matches. Now let's check InteractionLayer key routing claims and the Escape bubbling story
(critical to D5/D10/M-05m).

Confirmed. I have enough evidence now to compile the review.

Confirmed exactly as roadmap/spec cite. I now have sufficient verified evidence to write the review.

Verdict: Ready with fixes

B1 BLOCKER — D5's shortcut/TextField interaction claim is backwards; typing text will fire tool
shortcuts and corrupt/abort text entry

Spec section: D5 ("They never fire while the text field has focus, because the TextField consumes
the character keys first"); D9; Testing → Widget tests ("the shortcuts don't fire while the field
has focus").

Evidence: EditableText's own doc comment, packages/.../editable_text.dart:728-737 (Flutter SDK
3.27.3):

 "Shortcuts prevent text input fields from receiving their keystrokes as text input... When a
keystroke is received in Flutter's engine, it first gives the framework the opportunity to handle it
as a raw key event... This is what Shortcuts listens to indirectly through its FocusNode. If it is
not handled, then it will proceed to try handling it as text input..."

I verified EditableText's own Focus wrapper (editable_text.dart:5903-5904) has no onKeyEvent, so a
plain letter key is left ignored at the field and bubbles to ancestors exactly like the existing,
already-working undo pattern (apps/floor_planner/lib/main.dart:94-98, confirmed: "the tool ignores
Z, so the event keeps bubbling and arrives here"). The shell's CallbackShortcuts sits above the
field (wraps the whole Scaffold body per main.dart), so it is exactly such an ancestor and gets
first crack at raw V/L/P/R/C/A/T/F, consuming them before they ever reach the IME/text-input channel
— the opposite of the spec's claim.

Why it matters: typing an ordinary word like "Living room" contains l, v, r — each keystroke would
switch tools (and, per D5, clear the selection and hand focus back to the canvas) instead of
inserting the character. Text placement, as specified, is effectively unusable the moment the user
types a common English word. The planned widget test would actually fail if it's written honestly
(or falsely pass if it uses tester.enterText(), which bypasses key dispatch entirely and would hide
the bug — a degenerate-fixture risk in the plan's own test suite).

Fix: gate the shell's callbacks (e.g. skip when FocusManager.instance.primaryFocus?.context?.widget
is EditableText), or — Flutter's own documented remedy — wrap the inline TextField in a local
Shortcuts binding the same activators to DoNothingAndStopPropagationIntent so they never reach
CallbackShortcuts. Either must be specified before a plan is written, and the widget test must
exercise it via sendKeyEvent, not enterText.

M1 MAJOR — D9/D11's stored widthFactor/oblique scalars are dead unless textAttrs sets the override
bits; a "renders correctly" test cannot tell them from garbage

Spec section: D9 ("scalars [heightMm, 0, 1, 0]"), D2 ("textAttrs: 0"), Exit criterion 6.

Evidence: packages/jet_cad_2d/lib/src/document/text_geometry.dart:191-196:

 widthFactor = (textAttrs & _kOverrideWidthFactor) != 0 ? scalarOr(payload, 2, style.widthFactor) :
style.widthFactor;
 obliqueAngle = (textAttrs & _kOverrideOblique) != 0 ? scalarOr(payload, 3, style.obliqueAngle) :
style.obliqueAngle;

_kOverrideWidthFactor = 1<<8, _kOverrideOblique = 1<<9 (text_geometry.dart:20-21). With textAttrs =
0 (D9), payload scalars[2] and [3] are never read; rendering uses
style.widthFactor/style.obliqueAngle from ReservedHandles.standardTextStyle, whose TextStyleRecord
defaults happen to be 1.0/0.0 (tables.dart:300-309). The spec's stored values coincide with the
style defaults by luck, not by causation.

Why it matters: this is exactly the "degenerate fixture" CLAUDE.md warns about — a test asserting
"placed text renders at requested cap height/width factor" will pass whether the tool writes 1,0 or
garbage into scalars[2]/[3], because those bytes are inert. A future change to the style's
widthFactor (or a mutant flipping scalars[2]/[3]) would go undetected by any test the spec
describes.

Fix: either have commitText set the override bits (so the payload values are load-bearing and
testable), or explicitly document that scalars[2]/[3] are placeholders and add a differential test
that perturbs the style's widthFactor/oblique (not the payload) to prove the rendered transform
tracks the style, not the entity.

m1 MINOR — M-05d's second prescribed test cannot kill the described mutant

Spec section: Named mutants table, M-05d.

Evidence: mutant is "addDrafted derives the handle from doc.entities.length + firstFree instead of
handleSeed.next()" — a bug in the builder, evaluated once per shape, before the command exists.
AddEntityCommand (commands.dart:35) stores a fixed record (with the already-baked handle); undo/redo
just replay the same object (CommandDispatcher semantics implied by AddRegionCommand's and
AddEntityCommand's doc comments — nothing re-derives the handle at apply() time). Walking the second
bullet ("draw A and B, undo both, redo both: each comes back with its original handle") under the
mutant: A and B still get distinct handles at construction (entities.length differs at each draw),
and redo trivially replays whatever handle got baked in — identical outcome to the correct
implementation. This scenario is green under both the mutant and correct code; it does not
discriminate.

The first bullet ("draw A, undo, draw B: B's handle is not A's") does kill it (undo shrinks
entities.length back to what it was before A, so B collides with A's handle under the mutant, and
doesn't under handleSeed.next(), which never rewinds). So M-05d is still killable overall, but the
mutation log/plan should not credit the redo-scenario as evidence — it's testing the general "redo
preserves handle" invariant (already exit-criterion 2), not this specific mutant.

Fix: drop or relabel the second bullet under M-05d; keep only the "draw, undo, draw again" scenario
as the kill test for this mutant.

m2 MINOR — text-field remount risk not specified, could silently drop focus/typed text on every
camera notification

Spec section: D9 ("The field... follows a pan or zoom").

Evidence: TextEntryOverlay "listens to the text tool's pending and to the camera," repositioning the
field's "baseline-left" on every camera change. The spec never states whether the TextField/its
State (and hence its internally-created FocusNode, since none is passed explicitly) is kept mounted
across these repositions or rebuilt. If the widget subtree is torn down and recreated (e.g. built
inline from a ValueListenableBuilder keyed by pending's value rather than positioned via a stable
Positioned wrapper), every pan/zoom during typing would unmount/remount the field, dropping focus,
cursor position and potentially in-flight composing state.

Why it matters: this is easy to get wrong and the existing test list ("The text flow end to end: T,
click, type, Enter") won't catch it unless a pan/zoom happens mid-type — another degenerate-fixture
gap (a look/test that never moves the camera while typing).

Fix: state explicitly that the field is a stable Positioned child whose left/top are recomputed on
camera change without rebuilding the TextField's Element, and add a widget test that pans/zooms
mid-type and asserts the field keeps focus and the composed string.

m3 MINOR — SweepTracker.sweepTo's τ==0 tie-break is undocumented as a decision, not just an edge
case

Spec section: D8.

τ starts at 0 in begin, and sweepTo uses τ >= 0 → CCW. If the end click lands before any hover
track() call (e.g., start-then-immediately-click-end with no mouse movement recorded, or the
accumulated travel exactly cancels to 0 after an out-and-back move), the arc is silently forced
counter-clockwise regardless of the pointer's last approach direction. The spec states the rule but
never flags it as a deliberate tie-break the differential test must special-case (its own skip rule
only excludes travel "within 1e-6 of a multiple of 2π," not exact-zero accumulated travel). Worth an
explicit sentence and a targeted case in the differential seed set, or it's easy for an implementer
to "fix" this in a way that silently changes the tie-break and still passes the stated tests.

Checked and found sound (no defect)

 - ToolPointerEvent/ToolContext/Tool/ToolController line numbers and members
(tool.dart:18,43,77,84-99,114) — match exactly.
 - InteractionLayer's Focus(onKeyEvent: …) at interaction_layer.dart:225-228, and the
ignored-key-bubbles-to-shell mechanism — real and already relied on for undo.
 - resolveDragPoint signature and SelectTool._resolve's call shape (drag_snap.dart:39,
select_tool.dart:347-360) — match D4 verbatim.
 - AddEntityCommand, AddRegionCommand.allocate, triangulationFor, isClosedPolyline
(commands.dart:35,505-624; grips.dart:50-55) — all match the roadmap/spec's descriptions, including
the fill-gets-lower-handle rule and the circle-vs-closed-simple-polyline refusal logic.
 - SelectionOverlayPainter.paint (selection_overlay.dart) calls tool.paintWorldOverlay then later
tool.paintOverlay on the same active tool every frame — a drawing tool gets both calls, consistent
with PlacementTool's split; selection clearing on tool activation correctly suppresses the
selected-outline pass.
 - startup_plan.dart furniture math (30 entities → 8 regions of 2, -14) is internally consistent;
planner_grips_test.dart builds its own fixture (unaffected); planner_shell_test.dart's pick/tap
coordinates target wall geometry, not furniture, so D14's reorder doesn't collide with existing
hard-coded test points; FillIndex.fillsOf supports the new "fill above every finish" assertion.
 - kCapHeightRatio, kNominalTextPixels, TextStyleRecord defaults, kByLayer, ByLayerColor,
Capability.geometry, DraftPermissions.runtime — all real, at the cited or equivalent locations.

Uncertain / not independently run: the widget-test behavior of tester.sendKeyEvent vs. real
desktop/web embedder key routing for B1 was reasoned from Flutter's own framework documentation
rather than an executed test (sandbox denied writes/execution outside the repo and I could not
create files inside it); I'm confident in the citation but recommend the implementer confirm with an
actual flutter test run per the plan's own testing bar.

