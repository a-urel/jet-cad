# Slice 1, Task 4 — interactive overlays (the input claim): independent review

**Commit reviewed:** `89e29b2` (parent `31db289`), branch `claude/exciting-pasteur-9m22jv`.
**Where:** my own clones, `/tmp/s1t4-review/repo` for the gates and `/tmp/s1t4-review/mut` for the mutants and probes, both checked out at `89e29b2`. Nothing in `/home/user/jet-cad` was edited apart from this file.
**Flutter:** the SDK at `/root/sdk/flutter` (`5fc3468`), `CI=true`.

## Verdict

**Approve with fixes.** The mechanism is sound against Flutter's event model, and I checked it in the framework source, not from memory. The `jet_cad_2d_flutter` suite and every other gate are green, and the standing sets are exact. Both allocation invariants pass. M-H16 and M-H17 are killed. 11 of my 14 mutants are killed by the committed suite. The fixes are R-1 and R-2, which are small missing tests, and R-3, a dartdoc sentence on a public widget. None of them blocks Task 5. R-1 and R-2 should land before the slice's final review.

## The mechanism, checked against the framework source

The source read is `packages/flutter/lib/src/gestures/binding.dart` and `pointer_signal_resolver.dart`, plus `rendering/binding.dart` and the web engine's `pointer_converter.dart` in the SDK tree.

- **Order on the path.** `RendererBinding.hitTestInView` hit-tests the render view first and only then calls `super.hitTestInView`, which adds the `GestureBinding` entry. The binding is therefore **last** on every path. `dispatchEvent` iterates `hitTestResult.path` in order, deepest entry first. `RenderInputClaim` is a descendant of all three listeners:
  - the `InteractionLayer` `Listener`;
  - the `CameraGestureDetector` `Listener`;
  - `ServiceView`'s `Listener` (`service_view.dart:419`). This one wraps the whole `PlannerView`, and the overlays sit in its `tableOverlays` slot inside the Stack.

  So the claim's `handleEvent` runs before any of these listeners hears the same event.
- **Route after every listener.** The binding's own `handleEvent` is the first thing to call `pointerRouter.route(event)`, and it runs last. The claim adds `_release` during the down's dispatch. The router iterates a `Map.of` copy, so adding a route during a dispatch is safe, and so is removing one inside `_release`. The badge's own recognizers register their routes earlier, in deeper `handleEvent`s, and hear the up before `_release` does. Arena sweep and `onTap` come after that, once the record is gone. That is harmless, because nothing asks `claimed` from a sweep.
- **Identity across entries.** Each entry gets `event.transformed(entry.transform)`, and `original` is the root event. `event.original ?? event` is therefore one key per dispatch. RV9 and RV6 confirm this. Recording or comparing the transformed event instead kills IC1–IC5, IC9 and IC6/IC7. The rig sits at (200, 150) and its claims are offset again, so the transforms are not the identity.
- **Signals.** `PointerSignalResolver.resolve` calls the first registrant with the event that was **registered**, which is the camera's transformed event. It does not pass the root event. So `_onResolvedSignal` zooms about the local point. IC7 asserts this, at 1e-9, with the world point under the pointer.
- **Pointer ids.** `GestureBinding._hitTests` is keyed by `pointer` alone, across views. The framework itself therefore assumes ids are unique among live pointers, process-wide. The web converter (`_PointerDeviceState.startNewPointer`) increments a static counter on every down, and the native converter behaves the same way. A static, process-wide record is no weaker than the framework's own map:
  - Multiple `FloorPlanView`s: a record only matters on the path of its own pointer.
  - Multiple windows: the same id rule holds across them.
  - Hot restart: the statics and the binding are recreated.
  - Hot reload: the record is kept, which is correct.
  - Tests: the purge in `claimed` covers a record left behind by `resetGestureBinding` (IC9 and R8).
- **Overlay removed mid-gesture.** The binding dispatches move, up and cancel to the stored path, detached render objects included. The record and the route are static, so the claim holds until the up whatever happens to the overlay: a table deleted, a mode switch that remounts the keyed `ServiceView`, an `interactive` switch, or a cull. A culled child is skipped by `hitTestChildren` (`data.shown`), so a culled badge claims nothing new. Probe P1 shows this: a middle drag from a claim, the claim removed by a rebuild, then moves and an up. The camera does not move, the tool hears nothing, and the record is released.
- **Cancel.** `_release` handles `PointerCancelEvent`, and probe P2 shows the claim is released. The committed suite never cancels a claimed pointer. See R-1.
- **Hover.** The claim records the last hover that passed through it. `InteractionLayer` turns that hover into one `onPointerExit` (`_overClaim`). Moving back to the floor routes moves again (IC6, and RV3 and RV5 are killed). The layer's `MouseRegion.onExit` does not reset `_overClaim`. I traced the sequences that matter (leaving the canvas from a badge, re-entering onto a badge, re-entering onto the floor): none of them produces a wrong event, at worst a duplicate exit, which tools treat as idempotent.
- **Wheel and trackpad.** See R-4. The behaviour matches the documentation, and G-5 says nothing on signals. A trackpad's pan and zoom is never claimed, and that is documented too.

## Integration

- **`InteractionLayer`, the touch hold-back.** A claimed finger returns in `_onDown` **before** `_touchDown`. No `_held` is set, no `Timer` starts, and the finger does not enter `_touches`, so nothing leaks and nothing fires. RV4 lets a claimed finger through on touch only. It is killed by IC4, which logs `['down 3 80,50', 'cancel', 'exit']`: the held-back down reached the tool after `kTouchHoldBack`. The guard is load-bearing, and IC4 pins it.
- **`CameraGestureDetector`.**
  - A claimed finger never enters `_fingers`/`_at`. Its moves fail the `_at.containsKey` check and its lift is a no-op, so a pinch pairs the unclaimed fingers only (IC5, TO29; R1 is killed).
  - A middle-button drag from a claim does not pan, and one from the floor pans across a claim (IC3; R7 is killed).
- **`ServiceView`, the secondary click.**
  - `_onSecondaryDown` returns for a claimed pointer, so neither `_secondary` nor the up acts (TO28; RV11 and F1 are killed).
  - A secondary press that starts off a badge and ends on one, within the slop, still opens the table's menu. That is consistent with "decided at the down".
- **No other listener needs the claim.** No other raw listener or `GestureDetector` is an ancestor of the overlay layer in the service tree. `RulerFrame`'s translucent `Listener` follows the cursor over a badge, but the service view turns the rulers off.
- **`interactive: false` is exactly Task 3.** The default builds `IgnorePointer(RepaintBoundary(_OverlayStack(...)))` with each child `RepaintBoundary(built.widget)`, the same tree as before (the diff and TO31).
- **Toggling `interactive`** remounts every overlay. This is documented on `interactive` and pinned by TO31. I accept it (R-8).

## Cost

I read every new line on the unclaimed path:

- `InputClaim.claimed`: type tests, then `_downs.isEmpty` (or one `int` lookup while some pointer is claimed), then one `identical`.
- `_onSignal`: one `claimed` call. The resolver callback is a `late final` cached once.
- `_onHover`: one `claimed` and one bool.

No closure, list, map entry or event is created per event. With no claim in the tree, `_downs` stays empty for good. A claimed down costs one map entry and one router route, both removed at the up.

Both frame-path invariants are green in my runs:

| Invariant | Package | Tests | Result |
|---|---|---|---|
| `paint_allocation_test` | render package | 2 | both success |
| `query_allocation_test` | engine | 6 | all success |

The pointer path is not one of the measured invariants. R-5 notes the one per-event allocation that `interactive: true` newly exposes; it is in Task 3's hit test, not in the claim.

## Findings

### R-1 (Minor): the cancel half of the claim is untested

G-5 and the dartdoc say a claim lasts "from that down through its up or cancel". Two mutants survive the committed suite:

- **RV2** releases the record on the up only.
- **RV12** has `InteractionLayer._onCancel` ignore the claim.

No IC or TO test cancels a claimed pointer. My probe P2 kills both. It puts a finger on a claim and calls `gesture.cancel()`, then checks two things: the tool log is empty, and `debugClaimedPointers` is back to its baseline. Under RV12 the tool logs `['exit']`; under RV2 the record leaks, 1 instead of 0.

**Fix:** add an IC10 along the lines of P2, with a touch cancel and a mouse cancel, each asserting the tool log is empty and the record is released. Then check that RV2 and RV12 go red.

### R-2 (Minor): nested claims, the `fresh` branch, are untested

`handleEvent`'s `fresh` check exists so that "a claim inside a claim hears the same down twice: one record, one route". **RV1** (`if (fresh)` → `if (true)`) survives the suite. My probe P3 nests an `InputClaim` inside another, and it kills RV1: `PointerRouter.addRoute` fails its duplicate-route assertion while the down is dispatched. A host that wraps its own badge in `InputClaim` would hit this path.

**Fix:** add a nested claim to the IC rig, or a dedicated test: a tap on it reaches the badge and not the tool, and the record returns to its baseline.

### R-3 (Minor): a claim placed above a listener gives that listener a broken sequence

`InputClaim` is public and exported from the render barrel. If one sits **above** a listener that asks `claimed`, for example a host that wraps a canvas in it, that listener hears the down before the claim records it, so the down is unclaimed. The moves and the up then read as claimed. Probe P4 puts an `InputClaim` around an `InteractionLayer` and drags with a mouse: the tool hears `[down 4 180,160]` and **no move and no up**, so the tool is left pressed. Only `InputClaim.claimed`'s dartdoc says it is "meaningful in a handler of an ancestor". The class dartdoc does not warn of the failure mode.

**Fix (documentation):** add one sentence to `InputClaim`'s class dartdoc. A claim must lie strictly below every listener that consults it, and a listener inside or below a claim sees a down that is not claimed followed by moves and an up that are.

Optional hardening: the layer could decide move, up and cancel from its own state at the down. That is a larger change, and I do not ask for it in this task.

### R-4 (Info, accepted): the wheel over a badge

Over a claim the camera registers with `PointerSignalResolver`; off every claim it acts at once, as in 0.3.0. This was the implementer's choice (F-1); G-5 and the plan say nothing about signals. Two consequences follow, both pre-existing in kind and both only where a badge is:

- **An outer host scrollable.** Off a badge, both the camera and the scrollable act, as in 0.3.0. Over a badge, the camera is deeper and wins.
- **On the web.** `resolve` calls `event.respond(allowPlatformDefault: true)` when nobody registered. Off a badge the browser default therefore stays allowed, as before. Over a badge the camera's registration suppresses it.

**Ask:** the Task 5 guide section on interactive overlays should state the wheel rule in one line, as the `interactive` dartdoc already does. No code change.

### R-5 (Info): `interactive: true` newly exposes the overlay hit test to every hover

Task 3's `RenderFloorPlanOverlays.hitTestChildren` allocates per shown child, until something is hit:

- a closure;
- an `Offset`;
- the transform push in `addWithPaintOffset`.

This is the same pattern as Flutter's `RenderStack`. Behind `IgnorePointer` it never ran. Interactive, it runs on every mouse hover and every down over the canvas. It is not the frame path, so the non-negotiable is not touched.

**Ask:** Task 5's cost measurement, which puts badges on 100+ tables, should include a mouse sweep with `interactive: true`, not only panning.

### R-6 (Nit): a failed test can leave the record behind and turn later tests red

IC1, IC2 and IC5 assert `debugClaimedPointers` equals **0**, an absolute count. IC9 compares against its own baseline. A failing test that leaves a claimed pointer down would also turn those three red, which hides the first failure. The report's F-5 says as much.

**Fix (optional):** compare against a baseline taken at the start of each test, as IC9 does.

### R-7 (accepted): the `// ignore: invalid_use_of_protected_member` in IC9

This is acceptable:

- It is test-only and one line, with its reason stated next to it.
- `resetGestureBinding` is exactly what `TestWidgetsFlutterBinding.reset()` calls between tests, and flutter_test's own `binding.dart` carries an analogous `// ignore: invalid_use_of_visible_for_testing_member`.
- No public API reproduces a lost up. The only alternative would split the scenario across two tests that depend on each other's order, which is worse.

### R-8 (accepted): toggling `interactive` remounts the overlays

The tree shape changes, because `IgnorePointer` and the `InputClaim` wrappers come and go. The alternative would put an inert claim in the default tree, which the plan forbids ("`false`: exactly the Task 3 tree"). G-5's lifetime contract already tells hosts to keep state outside an overlay's `State`. This is documented on `interactive` and pinned by TO31.

## Mutants

Each mutant was applied in `/tmp/s1t4-review/mut` by a runner (`scratchpad/rv/mut.py`). The runner copied the file aside, replaced exactly one occurrence, ran `flutter test --no-pub` on the named files, restored the file from the copy and compared it byte for byte. It printed `restored: True` for every mutant. I never ran `git checkout`. The red lines below are copied from the run logs (`scratchpad/rv/mut_<id>.log`).

"The suite" means the committed `test/input_claim_test.dart` for the render package and `test/host/table_overlay_test.dart` (filtered to the TO test named) for the planner.

| Mutant | Edit | Result | Killer: red line |
|---|---|---|---|
| **M-H16** | `? InputClaim(child: built.widget)` → `? built.widget` | **killed** | TO28: `Expected: empty` / `Actual: ['1', '1']` |
| **M-H17** | `hitTestChildren`: `Offset(data.dx, data.dy)` → minus the camera's `e`/`f` | **killed** | TO30: `Expected: ['1']` / `Actual: MappedListIterable<(String, Offset), String>:[]` |
| M-H17b | `applyPaintTransform`: the same offset applied to the paint transform | **killed** | TO30: `Expected: … within <0.000001> of <373.55057958016914>` / `Actual: <14985.80057958017>` |
| R3 (implementer's) | `handleEvent` forgets the record on the up, before the ancestors hear it | **killed** | IC4: `Expected: empty` / `Actual: ['exit', 'exit']` |
| R8 (implementer's) | `claimed`: the stale-record purge removed | **killed** | IC9: `Expected: ['down 41 180,160', 'move 41 200,170', 'up 41 200,170']` / `Actual: ['down 41 180,160']` |
| RV1 | `if (fresh)` → `if (true)` (a route registered again on a nested claim) | **survived** the suite; killed by probe P3 | P3: `PointerRouter` duplicate-route assertion (`pointer_router.dart` line 33). **R-2.** |
| RV2 | `_release`: `PointerUpEvent \|\| PointerCancelEvent` → `PointerUpEvent` (the record not cleared on cancel) | **survived** the suite; killed by probe P2 | P2: `Expected: <0>` / `Actual: <1>`. **R-1.** |
| RV3 | the claimed hover does not exit (`_tool.onPointerExit` removed) | **killed** | IC6: `at location [1] is 'move 6 180,160' instead of 'exit'` |
| RV4 | `_onDown`: `claimed(e)` → `claimed(e) && !_isTouch(e)` (a claimed finger held back, then routed) | **killed** | IC4: `Expected: empty` / `Actual: ['down 3 80,50', 'cancel', 'exit']`; IC5 also red |
| RV5 | `_overClaim` not reset by a hover back on the floor | **killed** | IC6: the second `exit` missing |
| RV6 | hover/signal identity on `event`, not `event.original ?? event` | **killed** | IC6: `at location [1] is 'move 6 80,50' instead of 'exit'`; IC7 also red |
| RV7 | a signal over a claim dropped (no resolver registration) | **killed** | IC7: `Expected: … of <1.21>` / `Actual: <1.1>` |
| RV8 | move, up and cancel never claimed (only the down) | **killed** | IC3: `Actual: ['down 3 100,90', …]`; IC4: `Actual: ['exit', 'exit']` |
| RV9 | the record keeps the transformed down, not the root event | **killed** | IC1: `Expected: empty` / `Actual: ['down 1 80,50', 'up 1 80,50']`; IC2–IC5 and IC9 also red |
| RV10 | a signal over a claim acted on at once **and** registered (a double zoom) | **killed** | IC7: `Expected: … of <1.21>` / `Actual: <1.3310000000000002>` |
| RV11 | the service view's secondary click ignores the claim | **killed** | TO28: `Expected: empty` / `Actual: ['1']` |
| RV12 | `InteractionLayer._onCancel` ignores the claim | **survived** the suite; killed by probe P2 | P2: `Expected: empty` / `Actual: ['exit']`. **R-1.** |

**Totals:**

- The two named mutants (M-H16, M-H17) and two of the implementer's own (R3, R8) are killed.
- I ran 14 of my own:
  - M-H17b and RV1–RV12;
  - RV12 twice, once against the suite and once against probe P2.
- 11 of them are killed by the committed suite.
- RV1, RV2 and RV12 survive the suite and are killed by my probes. They are R-1 and R-2.

The probes are in `/tmp/s1t4-review/mut/packages/jet_cad_2d_flutter/test/zz_review_probe_test.dart`, which is not committed. On the unmutated tree all four pass: P1 removal mid-gesture, P2 cancel, P3 nested, P4 the misuse print, `P4 routed: [down 4 180,160]`.

## Gates (real tails, my clone at `89e29b2`)

```
### packages/jet_cad_floor_plan :: flutter test
test-exit 0
05:55 +1510: All tests passed!
### packages/jet_cad_floor_plan :: flutter analyze
No issues found! (ran in 8.9s)
### packages/jet_cad_floor_plan :: format
Formatted 250 files (0 changed) in 1.30 seconds.
format-exit 0
### apps/restaurant_demo :: flutter test
test-exit 0
00:26 +39: All tests passed!
### apps/restaurant_demo :: flutter analyze
No issues found! (ran in 4.5s)
### apps/restaurant_demo :: format
Formatted 4 files (0 changed) in 0.06 seconds.
format-exit 0
### apps/floor_planner :: flutter test
test-exit 0
01:35 +212: All tests passed!
### apps/floor_planner :: flutter analyze
No issues found! (ran in 5.8s)
### apps/floor_planner :: format
Formatted 47 files (0 changed) in 0.20 seconds.
format-exit 0
```

```
### packages/jet_cad_2d_flutter :: flutter test --file-reporter json
render test-exit 1
### expect_failures render
packages/jet_cad_2d_flutter: 1372 tests; the standing failures and skips, exactly
compare-exit 0
### flutter analyze
No issues found! (ran in 12.7s)
### format
Formatted 223 files (0 changed) in 0.94 seconds.
format-exit 0
### packages/jet_cad_2d :: dart test --file-reporter json
engine test-exit 1
### expect_failures engine
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
compare-exit 0
```

The standing sets, read from the JSON runs:

| Package | Standing failures | What they are |
|---|---|---|
| Render | 7, plus 1 skip | the text ladder rungs 1–5 and text-lod rungs 1–2 |
| Engine | 2 | the two `generate_document_test` cases |

The implementer's counts match:

| Package | Tests | Change |
|---|---|---|
| Planner | 1510 | +4 (TO28–TO31) |
| Render | 1372 | +9 (IC1–IC9) |

`git status` in the gate clone was clean after `pub get` and every run. The commit touches no `analysis_options.yaml`.

## Fixes (controller's)

**Commit:** `84ee8e9` on `claude/exciting-pasteur-9m22jv` (parent `59eb206`), not pushed. It changes two files: `packages/jet_cad_2d_flutter/lib/src/input_claim.dart` (dartdoc only) and `packages/jet_cad_2d_flutter/test/input_claim_test.dart`.

| Finding | Change |
|---|---|
| **R-1** | **IC10** (new): a finger on the badge (pointer 21) is cancelled after 50 ms. The record goes to `before + 1` at the down and back to `before` after the cancel, and `tool.log` is empty, exits included. A mouse on the plain claim (pointer 22) is dragged and then cancelled, with the same two assertions. The badge gets no tap and the camera is identical. `before` is read at the test's start. |
| **R-2** | The IC rig gains `kNested` (330, 110, 60 x 40): `InputClaim(InputClaim(GestureDetector(onTap)))`, clear of every point the other tests touch. **IC11** (new) presses a mouse on it. The record is `before + 1` at the down (one record), the up gives the inner widget one tap, the tool routes nothing, and the record returns to `before`. There is no duplicate-route assertion in the test: under RV1 the router's own assertion fires during the down's dispatch. |
| **R-3** | One paragraph in `InputClaim`'s class dartdoc. A claim must sit below (deeper than) every listener that consults it. A listener inside or below a claim hears a down before the claim records it, so the down reads as unclaimed and its moves and up as claimed, which leaves that listener's tool pressed. |
| **R-6** | IC1, IC2 and IC5 read `before = RenderInputClaim.debugClaimedPointers` at their start and compare against it, as IC9 does. No absolute `0` is left in the file. |
| R-4, R-5, R-7, R-8 | No action, as directed. R-4 is already in the guide, and R-5 is measured in Task 5. |

### Mutants (applied, seen red, restored)

A runner (`scratchpad/fix/mut.py`) did the following for each mutant:

1. It copied the file aside and asserted that the pattern occurs exactly once.
2. It replaced that one occurrence.
3. It ran `flutter test --no-pub test/input_claim_test.dart`.
4. It restored the file from the copy and compared it byte for byte.

It printed `restored: True` for all three. I never ran `git checkout`. The red lines below are copied from `scratchpad/fix/mut_<id>.log`.

| Mutant | Edit | Result | Killer: red line |
|---|---|---|---|
| RV1 | `input_claim.dart`: `if (fresh) {` → `if (true) {` | exit 1, **killed** | IC11 `[E]`: `'package:flutter/src/gestures/pointer_router.dart': Failed assertion: line 33 pos 12: '!routes.containsKey(route)': is not true.` (thrown while dispatching a pointer event) |
| RV2 | `_release`: `if (event is PointerUpEvent \|\| event is PointerCancelEvent) {` → `if (event is PointerUpEvent) {` | exit 1, **killed** | IC10 `[E]`: `Expected: <0>` / `Actual: <1>` / `a cancelled finger left its claim behind` |
| RV12 | `InteractionLayer._onCancel`: the `if (InputClaim.claimed(e)) return;` line removed | exit 1, **killed** | IC10 `[E]`: `Expected: empty` / `Actual: ['exit']` / `the layer acted on a claimed finger's cancel` |

The unmutated file passes, 11 tests (`00:00 +11: All tests passed!`). RV12 is killed by the finger half of IC10. A claimed mouse never sets `_activePointer`, so the mouse cancel returns early even under RV12. The mouse half of IC10 still pins RV2 for a mouse.

### Gates (real tails, `export PATH=/root/sdk/flutter/bin:$PATH CI=true`, `<s>` = `scratchpad/fix`)

```
### packages/jet_cad_2d_flutter :: flutter test --file-reporter json:<s>/r.json
render test-exit 1
  /home/user/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  ... and 3 more
### dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter <s>/r.json
packages/jet_cad_2d_flutter: 1374 tests; the standing failures and skips, exactly
compare-exit 0
### flutter analyze
No issues found! (ran in 4.7s)
### format
Formatted 223 files (0 changed) in 0.75 seconds.
format-exit 0
### packages/jet_cad_floor_plan :: flutter test
test-exit 0
04:49 +1510: All tests passed!
```

The render package went from 1372 to 1374 tests (IC10 and IC11), and its standing set is exact. The planner still has 1510. No `analysis_options.yaml` was touched.

There is one untracked file in the tree, `docs/superpowers/notes/2026-10-09-embedding-slice-1-results.md`. It appeared during this work and is not mine. I did not stage it.
