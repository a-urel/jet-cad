# Slice 1, Task 4 — interactive overlays: the input marker (G-5's pointers): report

**Commit:** `89e29b2` on `claude/exciting-pasteur-9m22jv` (parent `31db289`), not pushed.

## Files

| File | What |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/input_claim.dart` (new) | Public: `InputClaim` (a `SingleChildRenderObjectWidget`) with `static bool claimed(PointerEvent)`; `RenderInputClaim` (a `RenderProxyBox`) with the same static `claimed`, `handleEvent` recording, and `@visibleForTesting debugClaimedPointers`. |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | `export 'src/input_claim.dart';` (the render barrel exports whole files; no barrel test there pins names). |
| `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` | `_onDown`, `_onMove`, `_onUp`, `_onCancel` return first for a claimed pointer; `_onHover` turns a hover over a claim into one `onPointerExit` (`_overClaim`); class dartdoc "Claims". |
| `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart` | `_onDown`: a claimed finger never joins `_fingers`; `_onMove`: a pan-button drag of a claimed pointer does not pan; `_onSignal`: a signal over a claim registers with `GestureBinding.instance.pointerSignalResolver` (the old body is now `_signal`, its tear-off cached in a `late final`); class dartdoc "Claims". |
| `packages/jet_cad_2d_flutter/test/input_claim_test.dart` (new) | IC1–IC9, beside `interaction_layer_test` / `interaction_layer_touch_test`. |
| `packages/jet_cad_floor_plan/lib/src/host/table_overlay.dart` | `interactive: true`: no `IgnorePointer`, each child `RepaintBoundary(InputClaim(<host widget>))`; `false`: exactly the Task 3 tree. `interactive`'s dartdoc rewritten (what a claim takes, wheel, trackpad, a switch remounts); `TableOverlayLayer`'s dartdoc. |
| `packages/jet_cad_floor_plan/lib/src/host/service_view.dart` | `_onSecondaryDown` returns for a claimed pointer. |
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart` | One dartdoc sentence on `tableOverlayBuilder` (pointers unless `interactive`). |
| `packages/jet_cad_floor_plan/test/host/table_overlay_test.dart` | TO28–TO31 appended with their helpers (`InteractiveHost`, `mountInteractive`, `centerOf`, `onTableOffBadge`, `probeSlot`, `probeData`); the `gestures` import gains `kSecondaryButton`. No existing test edited. |

No other existing test changed. `jet_cad_2d`, both allocation invariants and every golden are untouched.

## The mechanism, and why

**How an ancestor's `Listener` can know.** A `Listener`'s callbacks get the event, never the `HitTestResult`, and `GestureBinding` keeps its per-pointer results private (`_hitTests`). What the framework does guarantee (`GestureBinding._handlePointerEventImmediately` / `dispatchEvent`, Flutter 3.47.6):

1. A down (and a hover, a signal) is hit-tested once; the path lists the **deepest entry first**, and `dispatchEvent` calls `handleEvent` along it in that order. Move, up and cancel reuse the down's path.
2. The binding's own entry is **last** on every path; its `handleEvent` runs `pointerRouter.route(event)` — so a per-pointer route runs after every render object on the path has heard the event.
3. Each entry gets `event.transformed(entry.transform)`, whose `original` is the root event (or the event itself when untransformed), so `event.original ?? event` identifies one dispatch across all listeners.

So the marker is a `RenderProxyBox` (`RenderInputClaim`) whose `handleEvent`:
- on a `PointerDownEvent` records `_downs[pointer] = root event` and adds one pointer route (`_release`, a static tear-off, so add/remove match);
- on a hover or a signal records `_passed = root event`.

`_release` forgets the pointer on its up or cancel. Because the route runs after the path, every ancestor's `onPointerUp`/`onPointerCancel` still sees the pointer as claimed; the next sequence starts clean.

`InputClaim.claimed(event)`:
- down / move / up / cancel: the pointer is in `_downs` (for a down: the recorded down **is** this dispatch's root event, so a record whose up never arrived — a test that left a pointer down, then `resetGestureBinding` — cannot claim a later unclaimed down on the same id; that stale record is purged on the spot);
- hover / signal: `identical(_passed, root)`;
- anything else (pan/zoom): false.

**Cost on the unclaimed path:** a couple of type checks, `_downs.isEmpty` (or one `Map<int,…>` lookup while some pointer is claimed) and one `identical`. Nothing is created per event, whether a claim exists or not; with no claim in the tree the map is empty forever. A claimed down costs one map entry and one router route, both removed at its up. The marker itself adds one proxy render object per interactive overlay and nothing to layout or paint.

**Why not record in `hitTest`:** a hit test knows no pointer id (and runs for hovers on every mouse move); the dispatch is where the id is. **Why not per-consumer bookkeeping only:** three listeners (layer, camera, secondary click) would each need the claim's verdict at the down anyway, and none knows which is last at the up; the router route ends the record once, after all of them.

## Gesture by gesture

| Input | On an interactive overlay (claimed) | Off every overlay | Why this choice |
|---|---|---|---|
| Tap (mouse, touch, stylus) | The overlay's own `GestureDetector` only: no tool event, no selection, no `onTableTap` | As before | G-5. |
| Drag (primary) | Nothing under it: no table drag, no pan | Pans / moves as before, **even when it crosses or ends on an overlay** (the claim is decided at the down) | G-5: "pan and zoom still start anywhere off a badge". |
| Middle / pan-button drag | Does not pan | Pans, across overlays too | A claim takes the whole pointer, whatever the button: simplest rule, matches G-5's "a pointer whose down carried the marker". |
| Long press | Neither the tool's long-press toggle nor the context menu; the overlay's own recognizers decide (a held `GestureDetector(onTap)` reports a tap) | As before | Same pointer rule. |
| Secondary click | No `onTableContextMenu` (the service view's `Listener` honours the claim) | As before | G-5 names this listener. |
| Pinch | A finger on an overlay is no finger of a pinch: the camera pairs the unclaimed fingers, the layer's touch session ignores it (it neither makes the session multi nor ends it). One finger on a badge + one on the floor = a one-finger gesture of the floor finger (in the service view: a pan) | Pinch as before | Plan: "a pinch with one finger on a badge does not start on that finger". |
| Wheel / scale signal | **Zooms (or pans, per policy) as off it**, about the pointer — unless something inside the overlay registers for the signal with `PointerSignalResolver` first (a `Scrollable` does), then the overlay alone has it | Acted on at once, exactly as before (no resolver registration, so a host's outer scrollable behaves as in 0.3.0) | Least surprising: a badge is part of the plan under the cursor, so the user's zoom does not "stick" when the cursor crosses one; a badge that scrolls keeps its wheel, by Flutter's own contract. Registering only over a claim keeps P-1 off the badges. |
| Trackpad pan / zoom (`PointerPanZoom*`) | Never claimed: the camera's | As before | Not a contact on the badge; a badge has no use for it. Documented. |
| Hover (mouse) | The tool hears **one** `onPointerExit` when the pointer moves onto an overlay (a design-mode select tool drops its hover highlight), nothing more while it stays | Routed as a move again | The overlay is not the canvas; highlighting the table under a badge whose tap does not select it would mislead. The service tool ignores hovers anyway. Cursor: the overlay's own `MouseRegion` wins if it has one, else the canvas's. |

`interactive: false` (the default) builds exactly Task 3's tree (`IgnorePointer`, no `InputClaim`): TO8 and TO31 pin it. Switching `interactive` changes the tree shape, so every overlay is built afresh (documented on `interactive`, pinned by TO31). The claim is hit only where its child is: a transparent gap is the canvas's (IC8).

## Tests

**Render package, `test/input_claim_test.dart`** (rig: `CameraGestureDetector(InteractionLayer(Stack))`, the canvas's real nesting; camera 0.1 px/mm, y up, translated; four claims: a tappable badge, one whose child registers for signals, one around a box that hits nothing, a plain coloured one; a recording tool):

- IC1 mouse tap on a claim: the badge's tap, at its own local point (40, 20); tool heard nothing; camera identical; record released; a tap off it is the tool's.
- IC2 the claim does not leak: tap on the claim with pointer 5, then a drag off it with pointer 5 is the tool's from down to up; no record left.
- IC3 a primary drag and a middle drag starting on claims move nothing; a middle drag from the floor across a claim pans by the whole drag; a primary drag from the floor ending on the badge is the tool's to its up, and no badge tap.
- IC4 a finger tap on a claim and a 1 s finger hold: the tool's log is **empty** (no down, no up, no exit); a finger off the claims: down, up, exit as before.
- IC5 a finger on a claim + a finger on the floor moving away: camera identical; the floor finger is a one-finger session (down + moves routed). The reverse order: the floor finger stays the tool's. Premise: two floor fingers pinch by the span's ratio.
- IC6 hover: floor → claim → claim → another claim → floor → claim logs `move, exit, move, exit` exactly.
- IC7 wheel notch up: on the floor ×1.1; over a plain claim ×1.1 again, about the pointer (the world point under it stays within 1e-9); over the registering claim: camera identical, the claim's callback ran once.
- IC8 a tap on a claim's transparent gap is the tool's.
- IC9 a claimed pointer's up lost (`resetGestureBinding`, as flutter_test does between tests): the next down on its id off every claim is the tool's from down to up, and the stale record is gone.

**Planner, `test/host/table_overlay_test.dart`** (the shared fixture: off-base box, 30°/mirrored/scaled tables 40 m off the origin, camera 0.37 px/mm panned; the host's overlays are 40 × 20 `GestureDetector` probes recording taps and tap-down local points):

- TO28 interactive: a mouse tap and a finger tap on badge 1 → the badge's two taps, `onTableTap` empty, no selection; a 120 × 75 px mouse drag from the badge → table 1's centre and the camera unchanged; a finger hold (long press = context menu here) and a secondary click on the badge → no menu, no tap, no selection. Premise: on table 1 a quarter box-width from its centre (off the badge, `tableAt` says `1`), a tap and a secondary click are the table's (`onTableTap ['1']`, menu `['1']`, selected).
- TO29 interactive: a mouse drag from empty floor (world (41,600, −26,900), checked empty and on the canvas) ending on badge 2 pans by exactly the drag; a finger on badge 1 plus a finger on the floor moving (70, 45): the scale is unchanged and the camera pans by exactly (70, 45) (the floor finger alone); the badge got that finger's tap (premise); a wheel notch over badge 1 zooms by `wheelZoomStep`.
- TO30 interactive, M-H17: for each of 1–3 shown, under the fixture camera and again after `panBy(-130, 85)` + `zoomBy(1.37)`: the probe's `localToGlobal` rect equals the hand-computed `badgeWanted` (1e-6), its composited `OffsetLayer` offset too, and a mouse tap at the wanted rect's top left + (31, 4) reaches **that** probe at local (31, 4) (1e-6); nothing reaches the table.
- TO31 the default has no `InputClaim` in the tree; switching to interactive puts 7 in and builds every overlay afresh (7 new states), switching back removes them (7 more).

## Mutants (applied, seen red, restored)

A runner (`scratchpad/t4/mut.py`) copied the file aside, replaced exactly one occurrence, ran `flutter test --no-pub <suite>`, restored the file from the copy and compared it byte for byte: `restored: True` every time; `git status` afterwards shows only this task's files. No `git checkout`. Red lines are copied from the run logs.

| Mutant | Edit | Killer | Red line |
|---|---|---|---|
| **M-H16** (an interactive overlay's tap also reaches the table tool) | `table_overlay.dart`: `? InputClaim(child: built.widget)` → `? built.widget` | **TO28** (also TO29, TO30, TO31) | TO28 `Expected: empty` / `Actual: ['1', '1']` (`M-H16: the table tool heard it`); TO29 `Expected: <0.37>` / `Actual: <0.44376678149765236>` (the badge finger joined a pinch); TO30 `Expected: empty` / `Actual: ['1', '2', '1']` |
| **M-H17** (an interactive overlay's `localToGlobal` off by the pan, non-identity camera): the transform the badge's pointer events carry | `RenderFloorPlanOverlays.hitTestChildren`: `offset: Offset(data.dx, data.dy)` → `Offset(data.dx - camera.e, data.dy - camera.f)` | **TO30** (also TO28, TO29) | TO30 `Expected: ['1']` / `Actual: MappedListIterable<(String, Offset), String>:[]` (`fixture camera 1: hit`); TO28 `Expected: ['1', '1']` / `Actual: []` (`the badge's own tap`) |
| M-H17b (the paint transform, i.e. `RenderBox.localToGlobal`, off by the pan) | `applyPaintTransform`: `translateByDouble(data.dx, data.dy, 0, 1)` → `(data.dx - camera.e, data.dy - camera.f, 0, 1)` | **TO30** (also TO1, TO11–TO13 and others of Task 3) | TO30 `Expected: a numeric value within <0.000001> of <373.55057958016914>` / `Actual: <14985.80057958017>` |
| R1 claim ignored by `CameraGestureDetector` (finger) | `_onDown`: `|| InputClaim.claimed(event)` dropped | **IC5** | `Expected: true` / `Actual: <false>` (`the claimed finger was one of a pinch`) |
| R2 the claim leaks to the next pointer (never released) | `_release`: `if (event is PointerUpEvent \|\| event is PointerCancelEvent)` → `if (false)` | **IC1, IC2** (also IC5) | IC1, IC2 `Expected: <0>` / `Actual: <1>`; IC5 `Expected: <0>` / `Actual: <4>` |
| R3 the claim released in `handleEvent` (before the ancestors hear the up) | `handleEvent`: `else if (event is PointerUpEvent) { _forget(event.pointer); }` inserted | **IC4** | `Expected: empty` / `Actual: ['exit', 'exit']` (the layer saw an untracked finger's up and ended a session) |
| R4 `InteractionLayer` ignores the claim on the down | the `_onDown` check removed | **IC1** (also IC2, IC3, IC4) | IC1 `Expected: empty` / `Actual: ['down 1 80,50']`; IC2 `Expected: ['down 5 180,160', …]` / `Actual: ['down 5 80,50', …]` (the claimed down routed, its up dropped) |
| R5 a hover over a claim routed as a move | `_onHover`: `if (InputClaim.claimed(e)) {` → `if (false) {` | **IC6** | `Which: at location [1] is 'move 6 80,50' instead of 'exit'` |
| R6 the camera acts on a signal over a claim at once | `_onSignal`: `if (InputClaim.claimed(event)) {` → `if (false) {` | **IC7** | `Expected: true` / `Actual: <false>` (`the camera zoomed under a claim that took the wheel`) |
| R7 a pan-button drag from a claim pans | `_onMove`: `&& !InputClaim.claimed(event)` dropped | **IC3** | `Expected: true` / `Actual: <false>` (`a drag that started on a claim moved the camera`) |
| R8 a stale record is not purged by an unclaimed down | `claimed`: `_forget(event.pointer);` removed before `return false` | **IC9** | `Expected: ['down 41 180,160', 'move 41 200,170', 'up 41 200,170']` / `Actual: ['down 41 180,160']` |
| F1 the secondary-click listener ignores the claim | `_onSecondaryDown`: `InputClaim.claimed(e) \|\|` dropped | **TO28** | `Expected: empty` / `Actual: ['1']` (`a menu from a claimed pointer`) |
| F2 the layer keeps `IgnorePointer` when interactive | `return interactive ? layer : IgnorePointer(child: layer);` → `return IgnorePointer(child: layer);` | **TO28** (also TO29, TO30) | `Expected: ['1', '1']` / `Actual: []` (`the badge's own tap`) |

R2's behaviour is masked for the next *down* by R8's purge (a later unclaimed down on the same id is never claimed); the record's lifetime itself is the invariant IC1/IC2 pin through `debugClaimedPointers`.

## Gates

Real tails, `export PATH=/root/sdk/flutter/bin:$PATH CI=true`, scratchpad `<s>` = `scratchpad/t4`. The first run (`gates.sh`) covered the whole tree. Its render `flutter analyze` then reported one issue in the new test (`invalid_use_of_protected_member` on `resetGestureBinding`, IC9). The fix was an `// ignore:` with its reason, a comment-only test change. After it, the render suite, the comparison, analyze and format were run again on the final tree; those reruns are the second block. The committed tree is that final tree.

```
### packages/jet_cad_floor_plan :: flutter test
test-exit 0
04:28 +1510: All tests passed!
### packages/jet_cad_floor_plan :: flutter analyze
No issues found! (ran in 4.8s)
### packages/jet_cad_floor_plan :: format
Formatted 250 files (0 changed) in 1.31 seconds.
format-exit 0
### apps/restaurant_demo :: flutter test
test-exit 0
00:23 +39: All tests passed!
### apps/restaurant_demo :: flutter analyze
No issues found! (ran in 4.0s)
### apps/restaurant_demo :: format
Formatted 4 files (0 changed) in 0.06 seconds.
format-exit 0
### apps/floor_planner :: flutter test
test-exit 0
01:32 +212: All tests passed!
### apps/floor_planner :: flutter analyze
No issues found! (ran in 4.3s)
### apps/floor_planner :: format
Formatted 47 files (0 changed) in 0.22 seconds.
format-exit 0
### packages/jet_cad_2d :: dart test --file-reporter json:<s>/e.json
engine test-exit 1
### dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d <s>/e.json
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
compare-exit 0
```

The render package on the final tree:

```
### packages/jet_cad_2d_flutter :: flutter test --file-reporter json:<s>/r2.json
render test-exit 1
### dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter <s>/r2.json
packages/jet_cad_2d_flutter: 1372 tests; the standing failures and skips, exactly
compare-exit 0
### flutter analyze
No issues found! (ran in 4.2s)
### format
Formatted 223 files (0 changed) in 0.87 seconds.
format-exit 0
```

Counts:
- The planner went from 1506 to 1510 (TO28 to TO31).
- The render package went from 1363 to 1372 (IC1 to IC9). The run before the comment fix also counted 1372 tests with `compare-exit 0`.
- The standing sets are exact: the engine has 2, and the render package has 7 failures plus 1 skip.

`paint_allocation_test` and `query_allocation_test` are untouched and green inside these runs. `git status` before the commit showed only this task's files. No `analysis_options.yaml` changed or was committed.

## Findings

- **F-1. Choice: the wheel over an overlay.** It zooms, or pans under the wheel-pans policy, as it does anywhere else on the plan. A host widget can take it through Flutter's `PointerSignalResolver`, which a `Scrollable` inside the badge does. The camera registers with the resolver only for a signal that passed over a claim. Off the claims it acts at once, as in 0.3.0, so a host's outer page scroller behaves as before (P-1). Over a badge, the camera now wins against such an outer scroller, because the camera is deeper. That is Flutter's own rule and only applies where a badge is.
- **F-2. Choice: a claim takes the whole pointer, every button.** A middle-button pan that starts on a badge does not pan. G-5 says "a pointer whose down carried the marker", and this applies it literally. A pan that starts off a badge pans even when it crosses or ends on one.
- **F-3. Choice: a hover onto an interactive overlay is one `onPointerExit` for the tool.** In the design mode, the select tool's hover highlight under a badge goes away. The service tool ignores hovers, so nothing changes in the selection mode. A trackpad's pan and zoom is never claimed.
- **F-4. Switching `interactive` remounts every overlay.** The tree shape changes: the `IgnorePointer` and one `InputClaim` per child come and go. This is documented on `interactive` and pinned by TO31. The other way to keep `State` across a switch would put an inert claim in the default tree. I did not do that, because the brief says the default must not change.
- **F-5. The claim is static, per process.** The record lives in a static map on `RenderInputClaim`. It is not attached to a render object, so a claimed pointer is released at its up even when the overlay was unmounted mid-gesture. Pointer ids are unique among live pointers. A record whose up never came can only happen in tests, after `resetGestureBinding` between tests. `claimed` purges such a record on the next unclaimed down on that id (IC9, R8). A test that fails mid-gesture leaves a record. IC9 counts relative to that, not absolute.
- **F-6. The long press on a badge.** The overlay's own recognizers decide what a long hold is. A plain `GestureDetector(onTap)` reports the hold as a tap (TO28 records a third tap). A host that wants a long press on its badge adds `onLongPress`. The table's long-press menu is never opened from a badge.
- **F-7. IC9 uses a protected member.** It calls `resetGestureBinding`, which is protected, with an `// ignore: invalid_use_of_protected_member` and the reason. It is the call flutter_test itself makes between tests, and the only way I found to reproduce a lost up without a private API.
- **F-8. No allocation measurement for the claim check.** I measured no VM-level allocation for the claim check. The unclaimed path creates nothing by construction (see Cost above), and no test measures it with the VM service. The pointer path is not one of the two frame-path invariants.
