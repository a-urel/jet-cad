# Review 3 (spot check): spec 12a, the document lifecycle (revision 3)

**Spec:** `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md` at `026e1ef`
(revision 3; `git diff HEAD~1 -- docs/` is the change under review). The re-review of revision 2
is `spec-12a-review-2.md` (T-1 to T-13).
**Reviewer:** independent and read-only. Nothing in the worktree was committed or edited except
this file.
**Scope:** a spot check, as review 2 asked:
- whether each T-n is resolved by the text, not only listed in the map;
- whether revision 3 introduced contradictions elsewhere;
- four source claims: `TextFieldTapRegion`, `applyFocusChangesIfNeeded`, `PlacementTool.isPending`
  coverage, and D2's settle order against D10 and D11.

**Probes.** They ran against a scratch copy of the worktree:
- the copy is `…/scratchpad/s12r3-/repo`, with `flutter pub get --offline` run in the copy only;
- the probe file is `apps/floor_planner/test/zz_review3_probe_test.dart` in that copy;
- the log is `…/scratchpad/s12r3-/probe-run1.log`.

The outputs quoted below are copied verbatim from that log. The run ended `00:05 +9: All tests passed!`.

## Verdict: **Ready with amendments**

All thirteen T-findings are resolved in the text. Revision 3 is sound on the points the brief
asked about:
- **`TextFieldTapRegion` works as the spec says.**
- **`applyFocusChangesIfNeeded` is public.**
- **D2's settle order agrees with D10 and D11.**

Revision 3 did introduce one real inconsistency, and it has consequences (U-1). D6 offers
`PlacementTool.isPending` as the mid-shape signal. But `TextTool.isPending` is true while the text
entry is open, so under that option an open entry *is* mid-shape. Every command would then be
disabled, and the T-1 flow could not run. The T-1 tests would go red, so the plan would find this
out. The spec should still name the exclusion.

The other findings are local:
- three minor findings (U-2 to U-4);
- four nits (U-5 to U-8).

None of them reopens a decision, and no fourth review is needed.

## Source claims checked

**1. `TextFieldTapRegion` around the toolbar: confirmed.**
- `TextFieldTapRegion` defaults `groupId` to `EditableText` (`widgets/tap_region.dart:845-856`), and
  `EditableText` wraps itself in a `TextFieldTapRegion(groupId: widget.groupId, onTapOutside: …)`
  (`editable_text.dart:5849-5854`), also with the `EditableText` default (`:874`).
- `RenderTapRegionSurface._classifyRegions` treats every region of a hit group as inside
  (`tap_region.dart:323-339`), and `onTapOutside` is called only for the regions outside
  (`:373-378`).
- The overlay's `TextField` sets no `groupId` (`text_entry_overlay.dart:105-119`).
- The default tap-outside action unfocuses in the cases D2 names (`editable_text.dart:6876-6906`).
  That action is also skipped for touch on iOS and Fuchsia off the web, not only on Android (U-8).
- Probe Q1 repeats review 2's P1, with and without a `TextFieldTapRegion` around the stand-in
  toolbar. `pendingAtPress` is read inside `onPressed`:
  ```
  Q1 tapRegion=false TargetPlatform.android PointerDeviceKind.touch: presses=1 pendingAtPress=true active=Text active.isPending with entry open=true atPress=true
  Q1 tapRegion=false TargetPlatform.android PointerDeviceKind.mouse: presses=1 pendingAtPress=false active=Text active.isPending with entry open=true atPress=false
  Q1 tapRegion=false TargetPlatform.macOS PointerDeviceKind.touch: presses=1 pendingAtPress=false active=Text active.isPending with entry open=true atPress=false
  Q1 tapRegion=false TargetPlatform.macOS PointerDeviceKind.mouse: presses=1 pendingAtPress=false active=Text active.isPending with entry open=true atPress=false
  Q1 tapRegion=true TargetPlatform.android PointerDeviceKind.touch: presses=1 pendingAtPress=true active=Text active.isPending with entry open=true atPress=true
  Q1 tapRegion=true TargetPlatform.android PointerDeviceKind.mouse: presses=1 pendingAtPress=true active=Text active.isPending with entry open=true atPress=true
  Q1 tapRegion=true TargetPlatform.macOS PointerDeviceKind.touch: presses=1 pendingAtPress=true active=Text active.isPending with entry open=true atPress=true
  Q1 tapRegion=true TargetPlatform.macOS PointerDeviceKind.mouse: presses=1 pendingAtPress=true active=Text active.isPending with entry open=true atPress=true
  ```
  So the region keeps the entry alive for every platform and pointer kind. M-12a-22 is live: without
  the region, macOS with a mouse gives `pendingAtPress=false`. The same lines are the evidence for U-1.

**2. `FocusManager.applyFocusChangesIfNeeded`: public in 3.47.2 (`/root/flutter/version`).**
- It is declared `void applyFocusChangesIfNeeded()` at `widgets/focus_manager.dart:1967`, with a
  dartdoc that names the use ("ensure that no focus changes are pending before executing an action").
- The citation is `material/menu_anchor.dart:1312`. It is correct, but the call there sits inside a
  post-frame callback.
- One constraint to carry into the plan: the method asserts that it is not called during the build
  phase (`:1968-1971`). Flows start from key callbacks, `onPressed` and the exit request, and none of
  those is a build, so the spec is fine.

**3. Does `PlacementTool.isPending` cover every drawing tool?** Mostly, but not safely for Text (U-1).
- The shell's tools are `Select`, then `PlacementTool` subclasses only (`main.dart:108-139`).
- `isPending` is `points.isNotEmpty` (`placement_tool.dart:70`).
- It is correct for these tools, whose pending shape lives in `points`:
  - Wall (`wall_tool.dart:144-176`);
  - Separator (`separator_tool.dart:80-122`);
  - Dimension, up to two points, with the third committing (`dimension_tool.dart:260-276, 493-500`);
  - Box, through Rectangle (`box_tool.dart:17-43`);
  - Line, Polyline, Rectangle, Circle and Arc (`packages/jet_cad_2d_flutter/lib/src/draw/*.dart`).
- Door, Window and Gap (`opening_tool.dart:233`) and Room (`room_tool.dart:190`) are single-click and
  never add a point. They are never mid-shape, which is correct.
- Every change of pending state notifies: `onPointerDown`, Enter, `cancel` and `activate`. The
  `ToolController` forwards those notifications (`tool.dart:104-133`), so a listenable-driven
  `enabled` updates.
- **Text is the exception.** `TextTool` overrides `isPending => _pending.value != null`
  (`text_tool.dart:37`), which is true exactly while the entry is open. Q1 prints `active=Text
  active.isPending with entry open=true`.

**4. D2's settle, against D10 and D11: consistent.**
- D10 settles, then checks dirty, then asks.
- D11 is busy → cancel; else settle; clean → exit; else dialog.
- D6 says the command wrappers set busy before the first await. Settle is synchronous, so it runs
  inside the busy span.
- Nested Save steps (T-8) settle again, which is harmless.

**D6 idle against D11 busy.** No contradiction, but D11 leaves one point implicit (U-7). The exit
flow checks *busy*, not *idle*, so a pending shape does not block a quit.

## T-1 to T-13

| # | Resolved | Note |
|---|---|---|
| T-1 | yes | D2's toolbar paragraph, D7, R-9, the Testing preamble (macOS, mouse), the toolbar test and M-12a-22. The mechanism is confirmed by Q1. Its effect depends on U-1: the Save button must be enabled while the entry is open. R-9's settle for Redo has a gap (U-2). |
| T-2 | yes, with U-1 | D6 now defines "idle" as not busy and not mid-shape, and every command uses it. Also the render-layer getter in D1, R-8, D14, the test and M-12a-23. The first mechanism the spec offers misreads Text (U-1). D1's Undo/Redo parenthesis still says "not busy" (U-6). |
| T-3 | yes | D6 "Bound above the dialogs", the exit gate, the test and M-12a-24. Running the commands from above the Navigator has two side effects (U-3, U-4). |
| T-4 | yes | The settle is synchronous through `applyFocusChangesIfNeeded`. The preamble keeps the house `press()`, and M-12a-11 is reworded. No `Future.delayed` or turn-await is left in the flows (grep: its only mention is the rationale at line 182). |
| T-5 | yes | D6 is reworded to "never reach the document", and the text-undo mapping is left to a later slice. D14's wording "do nothing at all" overstates this on web (U-5). |
| T-6 | yes | The preamble ends the shape and requires a redo stack. The busy test uses two edits and one undo and presses Cmd+Shift+Z. The text-field test has a redo stack and presses all three chords. With `canRedo` true and the guard removed, the shell's Redo is enabled and acts, so M-12a-15 is no longer equivalent. |
| T-7 | yes | D11 states the order, and the test and M-12a-25 are there. |
| T-8 | yes | D6 gives busy to the outermost flow. D10 and D11 re-check clean after a nested Save and ask again. The test and M-12a-26 are there. |
| T-9 | yes | The facts are corrected in D4, D8 and D14. The `scaleDenominator: 0` fixture is added. The count "the four failures" is stale (U-8). |
| T-10 | yes | The preamble now says every object sits at the identity (`startup_plan.dart:305-371`). The New round trip rotates the wall's group through the rotation grip; walls are movable and rotatable, `wall_grips.dart:40`, spec 08 D16. It asserts that the group transform matches. |
| T-11 | yes | The literal `PageComponent(originX: -7425, originY: -5250)` is in D4 and the launch test, with M-12a-27. The arithmetic holds: 297 × 50 / 2 = 7425 and 210 × 50 / 2 = 5250 (`startup_plan.dart:244-250`). |
| T-12 | yes | The host supplies a `Future<String?> Function(String)` at construction, and an empty name is a cancel. |
| T-13 | yes | `@objc` is in D11. `savedState` recomputes dirty (D5). The tab title goes through `onGenerateTitle` (D5); where the host's state comes from there is U-4. The name is `Flexible` (D7). The scale re-sync is in D2, with a test. |

## New findings

### U-1 (minor): `PlacementTool.isPending` counts an open text entry as mid-shape, which D6 says it is not

**Evidence**
- D6: "The plan decides how to ask a tool: an existing per-tool pending getter
  (`PlacementTool.isPending`, `placement_tool.dart:70`) where every such tool has one, or a new
  `Tool.isMidShape` … An open text entry is **not** mid-shape: a flow commits it (D2)."
- Every drawing tool has the getter. But `TextTool.isPending` is `_pending.value != null`
  (`text_tool.dart:37`), which is true exactly while the entry is open. Q1 shows `active=Text
  active.isPending with entry open=true`.
- If the plan takes the first option, every command is disabled during an open entry:
  - the toolbar's Save cannot be pressed;
  - Cmd+S in the entry matches the shell's disabled binding and does nothing.

  T-1 and R-5 then never happen.
- The pending-input tests (the Cmd+S and the toolbar text-entry cases) would go red, so the plan
  would discover this, but only after choosing.

**Fix**
- D6: define mid-shape as `Tool.isMidShape`: false by default, `isPending` in `PlacementTool`, and
  **false in `TextTool`**, whose pending state is the open entry that D2 settles. Alternatively the app
  can compute `active is PlacementTool && active is! TextTool && active.isPending`.
- Either way, D6 must name the Text exclusion.
- Mutant: mid-shape read from `isPending` for Text too → the toolbar text-entry test goes red.

### U-2 (minor): R-9's settle before Redo clears the redo stack, and Redo then calls the dispatcher with nothing to redo

**Evidence**
- R-9 and D2 say Undo and Redo settle pending input. A typed Selection panel value commits through
  `execute` (`selection_panel.dart:468-485`), which pushes and clears the redo stack
  (`undo.dart:23-26`).
- So a click on an **enabled** Redo, with a value typed and not submitted:
  - loses the whole redo branch;
  - then calls `redo()` on an empty stack. `redo()` fires `onBeforeMutate` and returns
    (`undo.dart:163-166`).
- That is the pattern the Invariants rule out: "The UI never relies on the dispatcher refusing".
- The outcome matches "Enter, then Redo", but the Redo button then acts although, after the settle,
  it no longer has anything to act on.

**Fix**
- D6/R-9: Undo and Redo re-read `canUndo`/`canRedo` after the settle and return if false. Say that a
  typed value cuts the redo branch, as Enter would.
- Test: two edits, one undo, a wall selected, its thickness typed without Enter, a tap on Redo → the
  typed value is committed, `canRedo` is false, and no redo ran (the `CommandRedone` count on
  `changes` is unchanged).

### U-3 (minor): the file chords bound above the Navigator *run* their commands over any route, not only over the flows' dialogs

**Evidence**
- D6 binds the file chords in `MaterialApp.builder`, "calling the same table's `run`; disabled or
  busy, they match and do nothing".
- The flows' own dialogs (D10, the web name prompt) are inside a busy span, so there they are no-ops.
  But the page panel opens `DropdownButton` routes (`page_panel.dart:125, 185`), which are neither
  busy nor mid-shape.
- Probe Q3: a `CallbackShortcuts` in `builder`, one in `home`, and a `DropdownButton` in `home`:
  ```
  Q3 home focused: handled=true inner=1 outer=0
  Q3 dropdown open=true: handled=true inner=1 outer=1 primaryFocus=FocusNode#4865d([PRIMARY FOCUS])(context: Focus, PRIMARY FOCUS)
  ```
- So with a dropdown open, Cmd+O or Cmd+S *runs* the flow: a native panel or the D10 dialog appears
  over the open menu. A New then swaps the shell underneath it. The route does close then, since
  `DropdownButton` dismisses its route on dispose (`material/dropdown.dart:1386-1388`), so this is
  benign today.
- The error dialog of D8 is in the same position if it is shown outside the busy span. The spec does
  not say which.
- Running the table from above the Navigator also needs the table to exist above `home` (see U-4).

**Fix**
- Make the above-Navigator binding **consume-only**: the file chords map to a no-op that returns
  handled.
- The shell's own `CallbackShortcuts` already runs them whenever the home route has focus.
- That keeps T-3's guarantee (no browser Save Page), needs no table above `home`, and makes the
  error-dialog question moot.
- M-12a-24's test ("Cmd+S is handled and makes no write" with the D10 dialog up) is unchanged. Add a
  case: a dropdown open, then Cmd+S → handled, and no write.

### U-4 (minor): `onGenerateTitle` sits above `home`; the spec does not say how the host's name and dirty state reach it

**Evidence**
- D1: "`FloorPlannerApp` builds the host; the host builds the shell". Today `FloorPlannerApp` is a
  `StatelessWidget` returning `MaterialApp(home: …)` (`main.dart:27-36`), and the host needs a
  Navigator below it for its dialogs.
- `onGenerateTitle` runs in a `Builder` inside `WidgetsApp` (`widgets/app.dart:1795-1803`). It
  re-runs only when `WidgetsApp` rebuilds or a dependency of that context changes. A `setState` in a
  host under `home` does neither, so the tab title would keep its first value.
- The "Dirty" test ("the tab title follows") would catch it, but the spec leaves the structure open.

**Fix**
- D1/D5: `FloorPlannerApp` becomes stateful and owns the document session's app-level state (the name
  and the dirty notifier, or the host's controller) above `MaterialApp`, rebuilding `MaterialApp` from
  a `ListenableBuilder` over it. The `DocumentHost` widget in `home` drives that state.
- Test: edit, then read the `Title` widget's `title` → it carries `•`.

### U-5 (nit): D14's "The chords in a guarded text field do nothing at all" is not true on web

- Review 2's P6 showed a guarded field returning `handled=false`. On web an unhandled key is not
  `preventDefault`ed (`keyboard_binding.dart:596-599`), so the browser's native input undo acts
  (T-5's evidence).
- Reword D14: "reach neither the document nor the framework's text undo; on web the browser's own
  input undo may act on them."

### U-6 (nit): D1 still says Undo/Redo are "enabled = `canUndo`/`canRedo` and not busy"

- D6 now uses *idle*, which is not busy and not mid-shape, and the mid-shape rule must hold for a
  shell pumped bare too.
- Reword D1: "and idle (D6)".

### U-7 (nit): D11 and mid-shape; Cmd+Q is swallowed by a pending tool

- D11 checks busy, not idle, so a quit request with a shape pending goes ahead: settle, then
  clean → exit, else the dialog. The pending shape is dropped. That is reasonable, but D11 should say
  it, so a plan does not reuse `idle` and refuse to quit mid-chain.
- Separately, D11 says that Cmd+Q reaches `onExitRequested` "with no native code". Mid-shape it
  reaches nothing:
  - the macOS embedder sends key equivalents to the framework first when the Flutter view is first
    responder (`FlutterViewController.mm:233-245`);
  - it redispatches only unhandled events (`FlutterKeyboardManager.mm:257-265, 274-300`);
  - `PlacementTool.onKey` returns `handled` for every modified key-down mid-shape
    (`placement_tool.dart:199-204`).

  So Cmd+Q, Cmd+H and Cmd+M are inert until Escape, while the menu's Quit, clicked, and the close
  button still ask. This is pre-existing since spec 05. It was reasoned from the engine sources, not
  run.
- Record it in D14 next to "Mid-shape, every command waits for Escape", and in the human's macOS look.

### U-8 (nit): small text slips

- The Open-failure test says "the four failures show the dialog". There are now six (not UTF-8, not
  JSON, `[]`, `{"schemaVersion": 1}`, scale 0, a refused schema version); only the cancel shows none.
  "Four" was already stale in revision 2.
- The header says review 2 had "2 major and 11 minor" findings. It had 2 major, 10 minor and 1 nit
  (T-13).
- The Testing preamble says Android touch is "the one combination where a tap outside a field does not
  unfocus it". Touch on iOS and Fuchsia off the web behaves the same (`editable_text.dart:6881-6889`).
  What matters is that it is `flutter test`'s default.
