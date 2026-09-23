# Task 7 report: the palette, shortcuts, the guard, the text field, `_activate`

**Status:** DONE_WITH_CONCERNS
**Commit:** `b06e908` feat(app): the tool palette, shortcuts and the inline text field
**Implementer:** Claude Opus 5.5

## What was implemented

- `apps/floor_planner/lib/shortcut_guard.dart`: `kShellLetterKeys` and
  `ShellShortcutGuard`, as in the brief.
- `apps/floor_planner/lib/tool_palette.dart`: `PaletteEntry` and
  `ToolPalette`, as in the brief, plus a transparent `Material` (deviation 1).
- `apps/floor_planner/lib/text_entry_overlay.dart`: `kTextEntrySize` and
  `TextEntryOverlay`, as in the brief, plus two focus fixes (deviations 2
  and 3).
- `apps/floor_planner/lib/planner_view.dart`: adds `required TextTool
  textTool`. The field goes outside the InteractionLayer in a `Flow`, not a
  `Stack` (deviation 4).
- `apps/floor_planner/lib/main.dart`, as in the brief:
  - the seven tools and `_fill`, `_entries`, `_geometryAllowed`,
    `_activate` and `_escape`;
  - `ToolController(initial: _select)`;
  - the V L P R C A T bindings, then F and Escape;
  - the palette in `chrome-left`, and the guard around `PagePanel`;
  - `textTool: _text`;
  - disposal: all seven tools and `_fill`, after `_tools.dispose()`;
  - the class doc line.
- `apps/floor_planner/test/planner_draw_test.dart`: A1 to A12 from the
  brief, with the amendments listed under deviations 5 to 8.

## TDD evidence

**RED.** `cd apps/floor_planner && CI=true flutter test test/planner_draw_test.dart`,
with only the test file added:

```
00:02 +1 -11: A12 under runtime permissions the drawing tools are disabled [E]
00:02 +1 -11: Some tests failed.
exit=1
```

- **Why it compiled.** The test references nothing new: the tools come from
  the package barrel.
- **The 11 failures** were the expected missing keys (`tool-line`,
  `text-entry`, `tool-fill` …) and statuses that never changed.
- **The one pass is A4, and it passed vacuously.** Without the shortcuts, L
  does nothing and the status stays `Select`. It has a live kill under
  M-05m (below).

**GREEN.** The same command, after the implementation and the deviations
below:

```
00:02 +12: All tests passed!
exit=0
```

## Gate: the `floor_planner` line

```
CI=true flutter test          -> 00:02 +38: All tests passed!   exit=0   (26 existing + 12 new = 38)
flutter analyze               -> No issues found! (ran in 1.2s) exit=0
dart format --output=none --set-exit-if-changed . -> Formatted 12 files (0 changed)  exit=0
flutter build macos --release -> ✓ Built build/macos/Build/Products/Release/floor_planner.app (51.3MB)  exit=0
flutter build web --release   -> ✓ Built build/web  exit=0
```

- **Invariant 4.** `git diff main -- packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart | wc -l`
  prints `0`.
- **Trailer.** `git log -1 --format=%B | grep -c "Opus 5.5"` prints `1`.
- **The other lines.** No file outside `apps/floor_planner` changed, so the
  engine, render-layer and harness lines were not re-run.
- **`analysis_options.yaml`.** No rewrite was left staged; `git status
  --short` was clean apart from the six task files.

## Deviations from the brief's code, and why

**1. `ToolPalette` wraps its list in `Material(color: Colors.transparent)`.**
- **Observed.** Every tile raised this on every frame: "ListTile background
  color or ink splashes may be invisible … The ListTile is wrapped in a
  ColoredBox". The `chrome-left` `Container` paints a colour.
- **Precedent.** `page_panel.dart:71-77` fixes the same problem the same
  way.

**2. The overlay requests focus itself when a placement starts** (in
`_onPending`: `if (pending != null) _focus.requestFocus()`).
- **Observed.** In a scratch test, after T and a canvas click, the primary
  focus was `FocusNode(InteractionLayer [PRIMARY FOCUS])`.
- **Consequence.** L went to the canvas, and the pending `TextTool`
  swallowed it (`sendKeyDownEvent` returned `true`, status `Text`).
- **Why `autofocus` never fires.** The layer's `requestFocus` on that same
  pointer-down puts focus on the canvas. `FocusScopeNode.autofocus` only
  acts when nothing in the scope is focused.
- **Why an unbuilt field still works.** A request on an unattached node
  sets `_requestFocusWhenReparented`
  (`focus_manager.dart:1184-1190`), so the field takes focus as soon as its
  `Focus` attaches.
- **After the fix,** the primary focus was `FocusNode(text-entry)`, and L
  reported `down=false up=false`.
- **So Ruling 05-9 holds as written.** A8 asserts `false` unchanged, and the
  Step 8 fallback was not needed.

**3. `TextField(onEditingComplete: () {})`.**
- **Observed.** A5 failed with `Expected: 'Line' Actual: 'Text'`: focus did
  not come back after Enter.
- **The cause.** With no `onEditingComplete`, `EditableText` unfocuses on
  `done` with the default `UnfocusDisposition.scope`. That clears the
  scope's `_focusedChildren` history before `onSubmitted` runs. Ruling
  05-7's `previouslyFocusedChild` then has no canvas to return to, and
  focus parks on the route scope, above the shell's `CallbackShortcuts`.
- **The fix.** The no-op callback suppresses the default unfocus. `_submit`
  commits, `_onPending` hands focus back, and A5 passes.

**4. `PlannerView` puts the field in a `Flow`, not a `Stack`.** The
`_FieldAboveCanvas` delegate paints child 1 (the canvas), then child 0 (the
field).
- **Observed.** With the brief's `Stack[canvas, overlay]`, the bodies of A7
  and A8 passed, but the tree teardown raised errors. flutter_test tears the
  tree down between tests, and the Flutter framework reported:

  ```
  setState() or markNeedsBuild() called during build.
  This ValueListenableBuilder<TextPlacement?> widget cannot be marked ...
  #6 TextTool.clearShape (text_tool.dart:73)  #9 _InteractionLayerState.deactivate (interaction_layer.dart:204)
  ```

  The same error follows for `EditableText` and `AnimatedBuilder`, via
  `controller.clear()`.
- **The cause.**
  - Deactivation is pre-order, and siblings go in list order
    (`framework.dart:2135-2143`).
  - `deactivateChild` nulls the `_parent` of the removed subtree's root, so
    no element in that subtree is "in scope" of the current build target.
  - The layer's `deactivate` cancels the active tool. With a text pending,
    that notifies the overlay's `ValueListenableBuilder` and the
    `EditableText`, and in a `Stack` both come after the canvas, so they are
    still active.
- **The fix.** In a `Flow` the field is child 0, so it is deactivated first.
  A notification to an inactive element returns early
  (`framework.dart:5353`).
  - Paint order and hit order are unchanged. `RenderFlow` hit-tests in
    reverse paint order (`flow.dart:428-435`), and an empty overlay region
    falls through to the canvas.
  - `RenderFlow` is a repaint boundary, and it clips to its bounds, like
    `Stack`'s default.
- **Why not the app layer.** Cancelling from the shell's or the view's
  `deactivate` hits the same assertion, because those elements are inside
  the removed subtree too. The fix cannot live in `InteractionLayer`
  (invariant 4).
- **Real-app impact without it:** a debug-only assertion whenever the view
  leaves the tree with a text pending.

**5. A6: the committing canvas click moved from (7180, 3020) to (7180, 3120).**
- **Why.** Under the fixture camera, (7180, 3020) projects 171 px right of
  and 1.5 px above the anchor at (7100, 3050). That is inside the 240 × 32
  field, so it clicked the field, and A6 failed with `Expected: an object
  with length of <1> Actual: []`.
- **The new point** is 102 px right of and 186 px below the anchor.
- **Added to A6:** a tap on the field itself, then
  `expect(ofKind(view.document, EntityKind.text), isEmpty)`. This covers D9's
  "a click on the field is not a canvas click". Without it the paint-order
  mutant survived (see the mutation table).

**6. A7: the `EditableText` finder is scoped to the field** (`find.descendant(of:
text-entry, matching: EditableText)`).
- **Why.** The page panel's scale field also has an `EditableText`. The
  brief's `find.byType(EditableText)` threw `Bad state: Too many elements`.

**7. A11 compares the snapshot less `handleSeed`, through `withoutSeed(view)`.**
- **Observed.** The two snapshots differed only in the seed: `Expected: ...
  dleSeed":18} Actual: ... dleSeed":19}`.
- **Why.** The engine never lowers the seed on undo: `raiseTo` only, and
  handles are never reused. So byte identity after a commit and its undo
  is impossible, and the engine's behaviour was left alone.
- **What still holds.** Every other key of the snapshot must match. The
  idle-Z-swallowed mutant still leaves the rectangle in, and fails.

**8. A10 switches through the palette, and asserts that L mid-shape is swallowed.**
- **Observed.** `Expected: 'Line' Actual: 'Polyline'`.
- **The cause.** Spec 05 D3 says mid-shape "every other key-down or repeat:
  `handled`". `PlacementTool.onKey` does exactly that
  (`placement_tool.dart:183-185`), and render-layer B5 pins it for a bare Z.
  So the shell's L can never arrive mid-shape, whatever the app does.
- **What I did.** I followed the spec. A10 now asserts, citing D3 in a
  comment, that L leaves the status at `Polyline`. It then taps
  `tool-line`: status `Line`, and the document is byte-identical. That keeps
  Review Focus 2's real risk under test: a switch that commits instead of
  cancelling.
- **See concern 1.**

## Mutation results

Each mutant was applied from a `cp` backup and run against its target test,
then restored. Every restore compared byte-identical (`filecmp` or `cmp`).

| Mutant | Target | Result |
|---|---|---|
| M-05m: an idle Escape returns `handled` (`placement_tool.dart`) | A4 | **killed**: `Expected: 'Select' Actual: 'Line'` |
| M-05n: `s = placed.point`, with no camera | A7 | **killed**: distance `7258.2`, not `< 0.5` |
| M-05u: the field keyed by the camera (`KeyedSubtree(key: ValueKey(s.x))`) | A7 | **killed**: `identical` `Expected: true Actual: <false>` |
| M-05v: the field's guard removed | A8 | **killed**: `Expected: false Actual: <true>` |
| The guard removed from the page panel (Review Focus 1) | A9 | **killed**: `Expected: false Actual: <true>` |
| The meta+Z guard entry broken (it needs alt too) | A9 | **killed**: `undoDepth` `Expected: <1> Actual: <0>` |
| `_activate` does not clear the selection | A3 | **killed** |
| `_activate` drops the permission check | A12 | **killed**: `Expected: 'Select' Actual: 'Line'` |
| The field's Escape binding removed | A6 | **killed** |
| No `requestFocus` in `_onPending` (deviation 2) | A8 | **killed**: `Expected: false Actual: <true>` |
| No `onEditingComplete` no-op (deviation 3) | A5 | **killed**: `Expected: 'Line' Actual: 'Text'` |
| `unfocus()` with the scope disposition, not `previouslyFocusedChild` | A5 | **killed** |
| Paint order swapped, so the field is under the canvas | A6 | **killed**, after the added field tap: `Expected: empty Actual: [19]` |
| Element order: the canvas first and the field painted on top (the `Stack` equivalent) | full file | **killed**: A7 and A8 raise "markNeedsBuild() called during build" |
| Ruling 05-7's explicit `unfocus` removed entirely | A5 | **survives, as an equivalent mutant**: see below |

**Why the last mutant is equivalent.** When the field leaves the tree,
`FocusAttachment.detach` itself calls `unfocus(disposition:
previouslyFocusedChild)` on a node with primary focus. So focus returns to
the canvas either way. I kept the brief's explicit call. It makes Ruling
05-7 visible in the code, and it runs synchronously rather than at the
next build.

## Self-review

- Names, doc comments and the file layout follow the brief. The
  `PlannerView` class doc says the field is "painted above" the canvas.
- `autofocus: true` stays on the field, as the brief has it. It is inert
  now that `_onPending` requests focus; it is harmless, and it matches the
  spec's wording.
- `dispose` loops over `_entries`, which holds exactly the seven tools,
  then disposes `_fill`, after `_tools.dispose()`.
- Only the six task files were committed. The scratch test used in
  deviation 2 was deleted before the commit.

## Concerns

1. **Review Focus 2 contradicts spec D3 and B5.** A drawing tool's shortcut
   typed mid-shape cannot switch tools: `PlacementTool` handles every
   key-down while pending, to keep undo off a half-placed shape. I followed
   the spec (deviation 8).
   - **If the intended behaviour is "L mid-polyline switches to Line",** the
     change belongs in the render layer. For example, `onKey` would return
     `ignored` mid-shape for a bare letter without modifiers, with only the
     undo and redo chords swallowed.
   - **That change is out of this task's scope.** It would change B5 (a
     bare Z is pinned as `handled`) and it needs a spec amendment. A10's
     `Polyline` assertion would then flip to `Line`.
   - **The controller should rule on it.**
2. **Deviation 4 changes the view's structure** from the spec's
   `Stack[CameraGestureDetector(…), TextEntryOverlay]` to a `Flow` with the
   same paint and hit order. The spec's D9 wording ("The planner view's
   root becomes `Stack[…]`") may want an "amended at execution" note in
   Task 11.
3. **A11 cannot be byte-identical,** because the handle seed is never
   lowered. If "byte-identical after undo" is a spec claim anywhere, it
   needs the same caveat.

---

# Fix round 1

**Commit:** `1445f9e` fix(app): keep a pending text across a window switch; guard Escape

## What changed

**1. The lifecycle guard in `_onFocus`** (`text_entry_overlay.dart`, Ruling
T7-b). The first lines are now:

```dart
final lifecycle = WidgetsBinding.instance.lifecycleState;
if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
```

- **What I changed from the coordinator's line.** It was `if (lifecycleState
  != resumed) return;`. I added the null check.
- **Why.** `SchedulerBinding.lifecycleState` is `null` until the first
  lifecycle message arrives, and flutter_test resets it to `null` before
  every test (`resetInternalState`, `scheduler/binding.dart:398-403`).
- **What the literal line would do.** It would switch off D9's "any other
  loss of focus cancels" whenever the state is `null`. A15 shows the
  difference: see the `literalGuard` mutant below.

**2. `ShellShortcutGuard` maps Escape** to
`DoNothingAndStopPropagationTextIntent`. The text-entry field's own Escape
binding (`CallbackShortcuts` → `_cancel`) sits nearer, so it still wins
there; A6's Escape-cancel stays green. The class doc now names Escape.

**3. A10 is renamed** "A10 a shortcut mid-polyline is swallowed; a palette
switch cancels byte-identically (Review Focus 2, Ruling T7-a)". After the
swallowed L it now also asserts
`(view.tools.active as PolylineTool).isPending` is true.

## New tests

- **A13, a window switch with the text pending (Ruling T7-b).** It runs
  under `TargetPlatformVariant.only(TargetPlatform.macOS)`, after
  `FocusManager.instance.listenToApplicationLifecycleChangesIfSupported()`.
  - **Steps.** T, a canvas click, `enterText 'x'`, then `inactive` and a
    pump.
  - **It first pins the mechanism.** The primary focus is the root scope.
  - **Then** `resumed` and a pump. The field exists, the controller reads
    'x', and the field has focus. After Escape, L makes the status 'Line'.
- **A14, Escape in `page-scale` (the guard gap).**
  - **Steps.** P and two canvas clicks, so the polyline is pending. Then a
    tap on `page-scale` and Escape.
  - **Asserts.** The status stays 'Polyline', and the same `PolylineTool`
    instance `isPending`.
- **A15, D9's in-app blur still cancels** (it covers the null-state
  change).
  - **Steps.** T, a canvas click, `enterText 'x'`, then a tap on
    `page-scale`.
  - **Asserts.** The field is gone, `pending` is null, and the snapshot is
    byte-identical.

## Mutant RED runs

Each mutant was applied from a `cp` backup. Afterwards each backup was
compared with `cmp` against the restored file, and they were identical:
"diff: both lib files identical to their backups".

```
noLifecycleGuard  (the guard line removed)                -> A13: exit=1, 00:01 +0 -1: Some tests failed.
    Expected: exactly one matching candidate
    Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'text-entry'>]: []>
    restored identical: True
noEscapeGuard     (the Escape entry removed from the guard) -> A14: exit=1, 00:01 +0 -1: Some tests failed.
    Expected: 'Polyline'
    Actual: 'Select'
    restored identical: True
literalGuard      (`lifecycle != resumed`, no null check)   -> A15: exit=1, 00:01 +0 -1: Some tests failed.
    Expected: no matching candidates
    Actual: _KeyWidgetFinder:<Found 1 widget with key [<'text-entry'>]: [
    restored identical: True
```

## Tests and gate

```
CI=true flutter test test/planner_draw_test.dart  -> 00:02 +15: All tests passed!  exit=0
CI=true flutter test          -> 00:03 +41: All tests passed!   exit=0   (26 + 15)
flutter analyze               -> No issues found! (ran in 1.2s)  exit=0
dart format --output=none --set-exit-if-changed . -> Formatted 12 files (0 changed)  exit=0
flutter build macos --release -> ✓ Built build/macos/Build/Products/Release/floor_planner.app (51.3MB)  exit=0
flutter build web --release   -> ✓ Built build/web  exit=0
```

- **The trailer check** prints `1`.
- **The app count** is now 41, not the plan's 38: A13, A14 and A15 were
  added in this round.

## Concerns

- **The null-state change** departs from the coordinator's literal line
  (see item 1). It is pinned by A15.
- **A13's lifecycle listener stays registered.**
  `listenToApplicationLifecycleChangesIfSupported` registers it on the
  binding's `FocusManager` for the rest of this file's run. No later test
  changes the lifecycle, and the state is reset to `null` between tests
  without notifying observers, so it has no effect elsewhere.
