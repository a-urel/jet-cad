# Task 9 — `InteractionLayer`, and the exports — implementation report

## What I implemented

### `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` (new)

`const double kPickRadiusPixels = 6.0;` — moved here from `select_tool.dart`,
which never used it. This file is the one place that performs the per-event
conversion (`kPickRadiusPixels / cam.scale`), so the constant lives beside the
conversion; `select_tool_test.dart` and `selection_overlay_test.dart` import
it back with `show kPickRadiusPixels` for their own `ev(...)` helpers.

`class InteractionLayer extends StatefulWidget` — `{tools, child}`, exactly
the brief's interface. `_InteractionLayerState` is the brief's code, with the
routing table implemented as written:

| event | what the layer does |
|---|---|
| any mask containing `kMiddleMouseButton` | ignored (`_cameraOwned`), checked **first** in `_onDown` and `_onMove` |
| `PointerDownEvent`, primary set, no active pointer | `requestFocus`, claim the pointer, `onPointerDown` |
| `PointerMoveEvent` from the active pointer, primary still set | `onPointerMove` |
| move from the active pointer in which primary disappears, or `PointerUpEvent` from it | `onPointerUp`, active pointer cleared |
| move in which primary appears on a non-active pointer, none active | treated as a down |
| `PointerHoverEvent` | `onPointerMove` with `buttons == 0` |
| `PointerCancelEvent` from the active pointer | `tool.cancel`, active pointer cleared |
| `MouseRegion.onExit` | `tool.onPointerExit` |
| `PointerPanZoom*`, `PointerSignal` | never wired, so ignored |

`_wrap` resolves the event into both spaces from `e.localPosition` (never
`e.position`) and snapshots `HardwareKeyboard.instance`'s four modifiers.
`Focus(focusNode:, autofocus: true, onKeyEvent: (_, e) => _tool.onKey(e, _ctx))`
→ `MouseRegion(onExit:)` → `Listener(behavior: HitTestBehavior.opaque, ...)`.

### `packages/jet_cad_2d_flutter/test/support/selection_fixture.dart` (modified)

`kInteractionSize`, `final class InteractionRig`, and
`Future<InteractionRig> pumpInteraction(tester, {document, camera})`. The rig
constructs `SelectionController` **before** `OutlineCache` (the ledger's
ordering, so the controller prunes a dead key on a `DocChange` before the
cache walks for it). `pumpInteraction` pumps the real view under a
`Directionality`: a centred 400 × 300 `SizedBox` → `InteractionLayer` →
`Stack([RepaintBoundary(DraftCanvas), Positioned.fill(RepaintBoundary(CustomPaint(SelectionOverlayPainter)))])`,
pumps a second frame so `autofocus` lands, and asserts
`tester.getSize(find.byType(InteractionLayer)) == Size(400, 300)`.

Teardown order is fixed inside the helper: `addTearDown(rig.dispose)` first
and `addTearDown(() => tester.pumpWidget(const SizedBox.shrink()))` second, so
(tear-downs being LIFO) the empty pump runs first and the layer's
`State.dispose` reaches live controllers rather than disposed ones.

### `packages/jet_cad_2d_flutter/test/interaction_layer_test.dart` (new)

The brief's eight widget tests. Shared fixtures at the top of the file, all
off the identity and off the origin:

- `lineCamera()` — scale **2.0**, translation **(−1850, 1120)**. The world
  line (990, 500)–(1010, 500) lands on local y = 120, x = 130…170 — off the
  layer's centre.
- `bandCamera()` — scale **2.0**, translation **(−120, 2120)**. The M-02a
  fixture (`inside` 100…120, `straddling` 190…230, `outside` 300…320, all at
  world y = 1000) puts the band's world corners (90, 1010) and (210, 990) at
  local (60, 100) and (300, 140).
- M-02l's own camera — scale **0.25**, translation **(−100, 245)**.
- `at(tester, local)` reads the layer's top-left back from
  `tester.getTopLeft(find.byType(InteractionLayer))` rather than assuming the
  centred (200, 150).

### `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (modified)

Seven exports added in the barrel's alphabetical-ish order:
`interaction_layer.dart`, `outline_cache.dart`, `select_tool.dart`,
`selection.dart`, `selection_overlay.dart`, `selection_style.dart`,
`tool.dart`. `flutter analyze` over the whole package is clean, so the Task 8
rename to `SelectionOverlayPainter` did prevent the collision with Flutter's
own `SelectionOverlay` that this export would otherwise have surfaced.

### `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` (modified)

The stale `SelectionOverlay` in the `kWindowBandColor` doc comment is now
`SelectionOverlayPainter` (the carried minor from Task 8).

## Departures

1. **`pumpInteraction`'s signature.** The brief writes
   `pumpInteraction(tester, {camera, selection, tools, doc, index})`, but the
   ordering constraint ("construct `SelectionController` before
   `OutlineCache`") only holds if the helper owns the construction. So the
   helper takes `{document, camera}` and builds `index`, `selection`,
   `outlines`, `tool`, `context` and `tools` itself, in the fixed order,
   returning them on an `InteractionRig` (the shape `selection_overlay_test.dart`
   already uses for the same reason). Every field the brief listed is reachable
   on the returned rig.

2. **Test 8's expectation, per the controller's ruling.** The plan's test 8
   text says the tool reaches phase `idle` after a middle-only move from the
   active pointer. The spec's **first** routing row wins over the
   primary-disappeared row: a mask containing the pan button is camera-owned
   and the move is ignored outright, so the press is untouched. The test
   therefore asserts: after the hand-built middle-only move the tool is still
   `dragging` **and the band has not moved**
   (`bandScreen == Rect.fromPoints(kBandA, kBandB)`); after the pointer's own
   `PointerUpEvent` it is `idle` and the band completed exactly as though the
   middle move had never arrived. The test is renamed to say so:
   `'a middle-only move from the active pointer is camera-owned'`.

3. **The stray-up half of test 8 is covered by test 7 instead.** The brief
   asks for "a later `PointerUpEvent` with `buttons == 0` is ignored without
   throwing". Dispatched by hand after the gesture's own up, that event is
   dropped by `GestureBinding` itself (`_hitTests.remove` already returned
   null, so `dispatchEvent` is never called) and the assertion would be
   vacuous. Test 7's middle-button drag ends with a real `gesture.up()` whose
   mask is empty and whose pointer is not the active one — the hit test *does*
   exist there, the event *does* reach `_onUp`, and it is dropped by the
   layer's own guard. That is the assertion the brief wanted.

4. **`tester.sendEventToBinding(...)` in place of
   `GestureBinding.instance.handlePointerEvent(...)`.** Identical
   (`sendEventToBinding` is `binding.handlePointerEvent` inside
   `TestAsyncUtils.guard`), but it keeps the hand-built event inside the test
   framework's async guard like every other event in the file.

5. **`deactivate()` releases too.** The task context says
   "`dispose`/`deactivate` clear hover and call `cancel`"; the brief's code
   block only shows `dispose`. Both halves are idempotent — `setHover(null)`
   on a null hover and `cancel` on an idle tool each return before notifying —
   so a private `_release()` is called from both, which costs two early
   returns and covers the reparent case where `deactivate` runs and `dispose`
   never does.

6. **Two extra assertions, both one line.** Test 4 (M-02l) adds a negative
   control (a click 25 screen px out, 100 world units at scale 0.25, well past
   the 24-unit radius, selects nothing) so the test also fails on a radius
   that grew without bound rather than only on one that failed to grow. Test 7
   adds a `kPrimaryButton | kMiddleMouseButton` gesture, because the spec's
   first row says the rule is on the mask, not on the absence of the primary
   bit.

7. **`_onMove`'s "move treated as a down" branch does not call
   `requestFocus`.** I wrote it in, then removed it to keep the brief's code
   block literal. Noted as a deliberate choice, not an oversight: the spec
   line is "a pointer down calls `requestFocus`", and whether a synthesised
   down should too is a question the brief does not answer.

8. **`import 'package:flutter/gestures.dart' show PointerHoverEvent, ...`.**
   `package:flutter/widgets.dart` does not re-export `PointerHoverEvent` (it
   does re-export `PointerDownEvent`, `PointerMoveEvent`, `PointerUpEvent` and
   `PointerCancelEvent`), so the compiler rejected `_onHover`'s parameter type
   until the name was added to the `show` clause. A local obvious fix; see the
   RED transcript below, which records it.

## TDD evidence

### RED — the tests before `interaction_layer.dart` existed

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/interaction_layer_test.dart
00:00 +0: loading .../test/interaction_layer_test.dart
test/interaction_layer_test.dart:9:8: Error: Error when reading 'lib/src/interaction_layer.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
       ^
test/support/selection_fixture.dart:21:8: Error: Error when reading 'lib/src/interaction_layer.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
       ^
test/interaction_layer_test.dart:39:1: Error: Type 'CameraController' not found.
CameraController lineCamera() => cameraAt(2.0, const Offset(-1850, 1120));
^^^^^^^^^^^^^^^^
test/interaction_layer_test.dart:46:1: Error: Type 'CameraController' not found.
CameraController bandCamera() => cameraAt(2.0, const Offset(-120, 2120));
^^^^^^^^^^^^^^^^
test/interaction_layer_test.dart:26:35: Error: Undefined name 'InteractionLayer'.
    tester.getTopLeft(find.byType(InteractionLayer)) + local;
                                  ^^^^^^^^^^^^^^^^
test/interaction_layer_test.dart:32:29: Error: Undefined name 'InteractionLayer'.
            of: find.byType(InteractionLayer), matching: find.byType(Focus))
                            ^^^^^^^^^^^^^^^^
test/support/selection_fixture.dart:201:16: Error: Method not found: 'InteractionLayer'.
        child: InteractionLayer(
               ^^^^^^^^^^^^^^^^
test/support/selection_fixture.dart:234:37: Error: Undefined name 'InteractionLayer'.
  expect(tester.getSize(find.byType(InteractionLayer)), kInteractionSize,
                                    ^^^^^^^^^^^^^^^^
```

(That run also told me the test file was missing its own
`camera_controller.dart` import, which the two `CameraController` errors
name; added before the next run.)

### Still RED after the first draft of the widget — a real compile error

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/interaction_layer_test.dart
00:00 +0: loading .../test/interaction_layer_test.dart
lib/src/interaction_layer.dart:136:17: Error: Type 'PointerHoverEvent' not found.
  void _onHover(PointerHoverEvent e) {
                ^^^^^^^^^^^^^^^^^
lib/src/interaction_layer.dart:136:17: Error: 'PointerHoverEvent' isn't a type.
  void _onHover(PointerHoverEvent e) {
                ^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

This is departure 8: `widgets.dart` alone does not carry `PointerHoverEvent`.

### GREEN — after adding it to the `gestures.dart` show clause

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/interaction_layer_test.dart
00:00 +0: a click selects; the layer took focus
00:00 +1: drag direction selects the mode; a vertical drag is a window
00:00 +2: exiting the layer clears hover
00:00 +3: the pick radius is converted by the camera scale
00:00 +4: one Delete press is one remove
00:00 +5: a pointer cancel ends the band
00:00 +6: a middle-button drag never reaches the tool
00:00 +7: a middle-only move from the active pointer is camera-owned
00:00 +8: All tests passed!
```

### GREEN — the three files this task touched, together

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/interaction_layer_test.dart test/select_tool_test.dart test/selection_overlay_test.dart
...
00:00 +36: All tests passed!
```

(`select_tool_test.dart` and `selection_overlay_test.dart` are in the list
because both now import `kPickRadiusPixels` from its new home.)

### Mutation evidence

I began a mutation sweep of `interaction_layer.dart` before the controller
stopped it (Task 11 owns the whole-branch sweep). The runs that completed are
recorded here as fact; each mutation was applied to a scratchpad-backed copy,
run, and the file restored — `diff` against the backup confirms the file in
the commit is the unmutated one.

| # | Mutation | Test that went red |
|---|---|---|
| 1 | `_focus.requestFocus()` deleted from `_onDown` | `a click selects; the layer took focus` |
| 2 | `pickRadiusWorld: kPickRadiusPixels` (the `/ cam.scale` dropped) | `the pick radius is converted by the camera scale` |
| 3 | `_cameraOwned(buttons) => false` | `a middle-button drag never reaches the tool` **and** `a middle-only move from the active pointer is camera-owned` |
| 4 | `onPointerHover: _onHover` unwired from the `Listener` | `exiting the layer clears hover` |
| 5 | `onExit: (_) {}` — the exit no longer reaches the tool | `exiting the layer clears hover` |

Mutations 6 onwards were not run. See **Concerns** for the one routing row
I know of that no test in this file pins.

## Gate line

`cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`

**`CI=true flutter test`** — `00:13 +763 ~1 -5: Some tests failed.`, non-zero
exit, failing on exactly the five pre-existing `text_ladder_golden_test.dart`
goldens and nothing else:

```
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

763 passed, 1 skipped, 5 failed — the five known goldens. (755 passed at the
end of Task 8's fix round; +8 is this task's eight widget tests.)

**`flutter analyze`**

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.8s)
ANALYZE_EXIT=0
```

**`dart format --output=none --set-exit-if-changed .`** — first run reported
`Changed test/interaction_layer_test.dart`; after `dart format` on that file:

```
Formatted 136 files (0 changed) in 0.28 seconds.
FORMAT_EXIT=0
```

`test/interaction_layer_test.dart` was re-run after the reformat and is still
`+8: All tests passed!`.

## Trailer check

```
$ git log -1 --format=%B | grep -c "Fable 5.1"
1
```

Commit: `dd60158 feat(interaction): InteractionLayer routes pointer transitions and keys to the active tool`.

`git status --short` before the commit listed only the eight files below — no
`analysis_options.yaml` was rewritten by any of the `flutter pub get` runs
that `flutter test` / `flutter analyze` triggered — and is empty after it.

## Files changed

- **Created** `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart`
- **Created** `packages/jet_cad_2d_flutter/test/interaction_layer_test.dart`
- **Modified** `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` — seven exports
- **Modified** `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` — `kPickRadiusPixels` removed (it was unused in that file)
- **Modified** `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` — stale `SelectionOverlay` doc reference
- **Modified** `packages/jet_cad_2d_flutter/test/select_tool_test.dart` — imports `kPickRadiusPixels` from its new home
- **Modified** `packages/jet_cad_2d_flutter/test/selection_overlay_test.dart` — same
- **Modified** `packages/jet_cad_2d_flutter/test/support/selection_fixture.dart` — `kInteractionSize`, `InteractionRig`, `pumpInteraction`

## Self-review

- **No fixture is degenerate.** Three cameras, none at the identity: scale
  2.0 with translation (−1850, 1120), scale 2.0 with translation
  (−120, 2120), and scale 0.25 with translation (−100, 245). A layer that
  used `e.position` instead of `e.localPosition` would fail (the box's origin
  is (200, 150), not (0, 0)); one that used a world-space pick radius would
  fail M-02l; one that dropped the camera's scale from the conversion would
  fail M-02l in the other direction. No entity sits at the origin and no
  camera is at scale 1 or translation zero.
- **The band tests have a genuine straddler.** `straddling` (world x 190…230)
  crosses the band's right edge at world x 210, so window and crossing give
  *different* answers (1 key vs 2) rather than the same answer twice.
- **"Selection untouched" is a real statement in M-02y.** The pre-selected
  key is `outside`, the one line the band never covers, so the assertion
  cannot be satisfied by a band that silently ran.
- **M-02x's `canUndo` assertions are anchored.** `doc.commands.clearHistory()`
  drops the fixture's own `AddEntityCommand`s and the test asserts
  `canUndo == false` *before* the Delete, so the final `canUndo == false`
  after one `undo()` means one command, not "the stack happened to bottom
  out".
- **Focus is surrendered before the click in test 1.** With `autofocus: true`
  the layer already holds focus after the pump; without the `unfocus()` the
  test would pass with `requestFocus` deleted — mutation 1 above confirms it
  now fails.
- **The layer's size is asserted in the fixture**, so a zero-sized layout
  (which would swallow every gesture) cannot make the file pass.
- **Nothing allocates per frame here.** The layer builds no `Paint`, `Path`
  or matrix; `_wrap` allocates one `ToolPointerEvent` and one `Vector2` per
  *pointer event*, which is pointer rate, not frame rate, and is the shape
  `tool.dart` already fixed in Task 3.

## Concerns

1. **One routing row is unpinned by this file's tests.** "A move from the
   active pointer in which the primary disappears is an up" — the
   `hadPrimary && !hasPrimary` branch of `_onMove` — is not reached by any of
   the eight tests. The brief's test 8 looks like it was meant to cover it,
   but the controller's ruling (departure 2) moved that scenario onto the
   camera-owned row instead, and a mask that loses the primary *without*
   gaining the middle button is not something `TestGesture` produces on its
   own. A ninth test dispatching a hand-built `PointerMoveEvent` with
   `buttons: 0` from the active pointer would pin it in about six lines; I did
   not add it because the brief fixes the file at eight tests. Worth a review
   decision.
2. **`_onMove`'s synthesised-down branch does not take focus** (departure 7).
   If a review decides a synthesised down should behave like a real one, the
   fix is one line.
3. **The mutation sweep is partial** (five of the mutations I had planned).
   Task 11 owns the whole-branch sweep; the five recorded above are facts from
   completed runs, not projections.
4. **The barrel now exports seven more files.** `flutter analyze` over the
   whole package is clean, so nothing in this repo collides — but
   `selection.dart`'s `SelectionKey` / `SelectionController` and `tool.dart`'s
   `Tool` are generic names in a package an app imports next to
   `flutter/material.dart`. Task 10's view is the first consumer that will
   feel it if any of them does collide downstream.

---

# Fix round 1

Review came back **Needs fixes**: two Important findings, two minors folded in
by the controller. All four are addressed. Commit `9722287` on top of
`dd60158`.

## What changed

### 1. Important — the `hadPrimary && !hasPrimary` row had no test

The controller's test-8 ruling moved the only test aimed at that row onto the
camera-owned row, leaving it unexercised. This was concern 1 of the original
report; it is now closed by a ninth test,
**`'the primary disappearing from a move is an up'`**:

- primary down on empty space at local (60, 100), real move to local
  (300, 140) → `dragging`;
- a hand-built `PointerMoveEvent` from the same pointer with
  `buttons: kSecondaryButton` — **not** camera-owned, so the row under test
  is the one that runs — at local **(350, 140)**, i.e. world (235, 990);
- asserts `phase == idle` and that the band completed over the world box
  **[90, 235] × [990, 1010]**, which holds `inside` *and* `straddling`
  (2 keys). Local (300, 140) would have given 1 key, so the assertion also
  pins that the synthesised up used the **synthesised move's** position, not
  the last real move's.
- then the gesture's own real `up()`: the active pointer is already cleared,
  so it is dropped without throwing and the selection is still the same 2.

No production change was needed for this finding; the row was already correct,
it was only untested.

### 2. Important — `MouseRegion.onExit` was unguarded

`lib/src/interaction_layer.dart`: the inline
`onExit: (_) => _tool.onPointerExit(_ctx)` is now a named `_onExit` carrying
the controller's binding guard:

```dart
void _onExit(PointerExitEvent e) {
  if (_activePointer != -1) return;
  _tool.onPointerExit(_ctx);
}
```

with a doc comment on the method and a sentence added to the class doc
("`MouseRegion.onExit` reaches the tool only while no pointer is active — a
captured pointer's drag is allowed to leave the box and come back, and ends
on its own up"). `SelectTool.onPointerExit` is unchanged and still cancels a
live drag, for a future caller that means it. `PointerExitEvent` added to the
`gestures.dart` show clause.

Covered by a tenth test,
**`'a drag that leaves the box keeps its captured pointer'`**: band started at
local (60, 100), moved to (300, 140), then `moveTo(const Offset(700, 300))` —
global, past the centred box's right edge at global x = 600, so local
(500, 150) = world (310, 985). Asserts `phase == dragging` and
`bandScreen == Rect.fromPoints((60,100), (500,150))` (the end followed the
pointer out), then `up()` out there and asserts the window band over
**[90, 310] × [985, 1010]** took `inside` and `straddling` and left `outside`
(world x 300…320, cut by the edge) out, with `phase == idle`.

**This finding was real in this Flutter version, and the test is covering.**
I confirmed it with one targeted check (not a sweep — Task 11 owns that):
with the guard line removed and nothing else changed, the run reported exactly

```
Failing tests:
  .../test/interaction_layer_test.dart: a drag that leaves the box keeps its captured pointer
```

so `MouseRegion.onExit` *does* fire while a captured pointer is down, and
without the guard `SelectTool.onPointerExit` did drop the live band. The file
was restored from a scratchpad copy immediately afterwards and the guard is
present in the commit.

### 3. Minor — the synthesised down now takes focus

`_onMove`'s `_activePointer == -1 && hasPrimary` branch calls
`_focus.requestFocus()` before claiming the pointer, matching `_onDown`. This
reverses departure 7 of the original report. It is **not** covered by a test:
reaching that branch requires a `PointerMoveEvent` for a pointer that has no
entry in `GestureBinding._hitTests`, and such an event is dropped by the
binding before it reaches any `Listener`, so the row is not reachable from a
widget test at all. See Concerns below.

### 4. Minor — the vertical drag's selection is now asserted

`expect(rig.selection.isEmpty, isTrue, ...)` after `vertical.up()`, with the
geometry spelled out: the vertical band is the world box
**[90, 90] × [990, 1010]** — zero width — so a window band encloses nothing.
The mode assertion above it is what M-02g is really about; this makes the
consequence explicit rather than silent.

## Commands and output

**`CI=true flutter test test/interaction_layer_test.dart`**

```
00:00 +0: a click selects; the layer took focus
00:00 +1: drag direction selects the mode; a vertical drag is a window
00:00 +2: exiting the layer clears hover
00:00 +3: the pick radius is converted by the camera scale
00:00 +4: one Delete press is one remove
00:00 +5: a pointer cancel ends the band
00:00 +6: a middle-button drag never reaches the tool
00:00 +7: a middle-only move from the active pointer is camera-owned
00:00 +8: the primary disappearing from a move is an up
00:00 +9: a drag that leaves the box keeps its captured pointer
00:00 +10: All tests passed!
```

(Re-run after the reformat below; same output.)

**Gate line** — `CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`

`CI=true flutter test`: `00:11 +765 ~1 -5: Some tests failed.`, non-zero exit,
failing on exactly the five pre-existing goldens and nothing else:

```
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

765 passed (763 + the two new tests), 1 skipped, 5 failed.

`flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.5s)
ANALYZE_EXIT=0
```

`dart format --output=none --set-exit-if-changed .`: first run reported
`Changed lib/src/interaction_layer.dart` and
`Changed test/interaction_layer_test.dart`; after `dart format` on both:

```
Formatted 136 files (0 changed) in 0.26 seconds.
FORMAT_EXIT=0
```

## Trailer check

```
$ git log -1 --format=%B | grep -c "Fable 5.1"
1
```

`git status --short` before the commit listed only the two files below; no
`analysis_options.yaml`.

## Files changed in this round

- **Modified** `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` — `_onExit` with the active-pointer guard, `requestFocus` on the synthesised down, `PointerExitEvent` import, two doc comments
- **Modified** `packages/jet_cad_2d_flutter/test/interaction_layer_test.dart` — two new tests, one new assertion, `kSecondaryButton` import

## Concerns after this round

1. **The synthesised-down row (`_onMove`'s second branch) is unreachable from
   a widget test** and therefore still untested, `requestFocus` included. A
   `PointerMoveEvent` for a pointer with no recorded down is dropped by
   `GestureBinding._handlePointerEventImmediately` (`_hitTests[pointer]` is
   null, so `dispatchEvent` is never called), and a pointer *with* a recorded
   down is by definition already the active one. Pinning it would need a unit
   test against the state object rather than a widget test, which the file's
   shape does not currently allow. Flagging rather than fixing.
2. Everything else from the original report's concerns list is unchanged
   except concern 1, which this round closes.
