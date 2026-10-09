# Slice 2, Task 4 — view events (E-1 to E-4): implementer's report

Branch `claude/exciting-pasteur-9m22jv`, from `890656d`. Commit: `cb62b8b` (pushed);
this report is in the git-ignored ledger.

## What was built

### `jet_cad_2d_flutter` (the only edit to this package in Slice 2)

- `lib/src/tool.dart:32, 55-62`: `ToolPointerEvent({…, this.timeStamp =
  Duration.zero})`, documented as the raw pointer event's time
  (`PointerEvent.timeStamp`), not the time the tool hears it; a held-back
  finger keeps its raw down's stamp. Not in any `==`/`toString` (the class
  has none).
- `lib/src/interaction_layer.dart:168-174, 189, 276, 308-315`: `_event`
  takes the stamp; `_wrap(e)` passes `e.timeStamp` (so every route of a
  held finger — the hold-back timer, the slop exit, the press-mode lift —
  is `_wrap(held)`, the raw down's stamp); the lift-mode aiming hover passes
  the move's; the lift-mode tap's down (at the lift's position) passes
  `held.timeStamp`.

### `jet_cad_floor_plan`

- `lib/src/service/table_select_tool.dart`
  - `:52-74`: `typedef ServiceEvents<M>` (internal, not exported): the four
    callbacks, `onTablesMoved: void Function(List<M>)?`. `M` is `Handle` at
    the tool (handles stay in the package) and `FloorPlanTableDetail` at the
    view; `kNoServiceEvents` (all `null`, so a `ServiceEvents` of either `M`)
    is the default. `ServiceCallbacks` is untouched (five fields).
  - `:103-104, 124-141`: the new optional `events` parameter (read at each
    call), `_pressTime`, `_lastTap` (instance, down stamp, down screen
    point), `_hovered`.
  - `:195`: the down's stamp kept.
  - `:223-225, 329-340` hover: a move with `buttons == 0` and not touch
    reads `events().onTableHover`; null → return (no pick); else
    `picker.pick(e.world)` (no reach), reported only when the number differs
    from the last reported. `:519-526` `onPointerExit` reports null when
    the last was not.
  - `:234-235` (leaving the slop: drag, pan, spent drag), `:496-497` (long
    press), `:543-544` (cancel): the double-tap chain resets.
  - `:346-359` floor tap: after the selection logic, the chain reset, then
    `onFloorTap(Offset(_pressWorld.x, _pressWorld.y))`, modifier or not.
  - `:376-401` double tap: an unnumbered hit resets; a numbered hit with no
    modifier completes when the kept tap is the **same instance**, `0 ≤
    gap ≤ kDoubleTapTimeout` between the two downs' stamps and the two downs'
    screen points are `≤ kDoubleTapSlop` apart (both inclusive, S-6); the
    decision and the new chain state are settled first, then `onTableTap`,
    `onGroupTap`, `onTableDoubleTap` in that order. A modifier tap or a
    completed double tap leaves no kept tap (a third tap starts anew);
    otherwise this tap becomes the kept one.
  - `:477-483` moved: after `onLayoutChanged`, the `_moving` handles still
    live (ascending, as `_moving` is sorted), unmodifiable, only when the
    callback is given. A zero drag returns earlier, as before.
- `lib/src/host/service_view.dart:47-48, 79-85`: the optional `events`
  parameter (`ServiceEvents<FloorPlanTableDetail> Function()`, default none).
  `:108-146`: the tool gets `_toolEvents`, which rebuilds its record only
  when the host's record is a new object (so a hover allocates nothing) and
  routes moves through `_moved`: the controller's fresh `tableDetails`
  mapped by `tableDetailInstances`, in the tool's (ascending handle) order,
  numbered or not, unmodifiable; nothing when this copy is no longer the
  active plan (a host whose `onLayoutChanged` reset or replaced it).
- `lib/src/host/floor_plan_view.dart:47-50, 136-170`: `onTablesMoved`,
  `onTableDoubleTap`, `onFloorTap`, `onTableHover`, documented with E-1 to
  E-4 (R-3's "a tap action runs on each tap of a double tap" in
  `onTableDoubleTap`'s doc; S-5's "no null on a remount" in
  `onTableHover`'s). `:259-277` `_serviceEvents`: the current widget's four
  callbacks, the record rebuilt only when `widget` is a new object (read at
  each call, R-5, without a per-move allocation). `:355-356` passed to
  `ServiceView`.

No new public name (the four are parameters of an exported class), so the
barrel and `barrel_test` are unchanged; the CHANGELOG is Task 5's.

## Tests

- `packages/jet_cad_2d_flutter/test/interaction_layer_time_stamp_test.dart`
  (new, 5 tests): TS0 default `Duration.zero`; TS1 mouse down/move/up/hover
  each carry their raw stamp; TS2 a finger held past `kTouchHoldBack`
  reaches the tool with its raw down's stamp; TS3 a finger lifted before
  it, and one leaving the slop, likewise; TS4 lift mode: the aiming hover
  carries the move's stamp, the tap's down (at the lift's position) the held
  down's. Stamps are never the fake clock's time.
- `packages/jet_cad_floor_plan/test/service/service_events_test.dart`
  (new, 13 tests, at the tool with explicit `ToolPointerEvent`s, the fixture
  decoded as a runtime copy under `embeddingCamera()`, a `CountingPicker`):
  SE1 two taps then the double tap, a third tap anew; SE2 the inclusive
  bounds (exactly 300 ms and exactly 100 px fire; 301 ms, 101 px do not;
  whole-pixel points so the differences are exact); SE3 the downs' stamps,
  not the ups' nor the clock's; SE4 Shift on either tap; SE5 the two 7s at
  0.025 px/mm (premise: within the slop, each picked as its own instance),
  the unnumbered table, the floor, a drag and a long press each reset, the
  other instance's tap is kept; SE6 cancel resets; SE7 locked `L`
  double-taps and stays unselected; SE8 floor: the down's world point
  (camera inverse written out, the up elsewhere), the selection already
  empty in the callback, a Shift miss reports and keeps it; SE9 the
  unnumbered table reports nothing; SE10 moved handles ascending, once,
  after `onLayoutChanged`, unmodifiable, a zero drag nothing; SE11 hover on
  change only, unnumbered null, exit null once; SE12 stylus and inverted
  stylus hover, a finger not; SE13 no callback → zero picks; a pressed move
  is no hover.
- `packages/jet_cad_floor_plan/test/host/view_events_test.dart` (new, 13
  tests, through `FloorPlanView` on `embeddingPlanJson`, mouse gestures
  with explicit stamps; `embeddingCamera()` or the same 0.37 px/mm panned
  over the table needed, `cameraOver`): VE1 order log `tap 1, tap 1, double
  1`, first tap not delayed and selecting; VE2 M-H20; VE3 M-H20b; VE4
  M-H20c (premise: 296 × 222 px box); VE5 locked `L` double-taps; Shift on
  either tap prevents it; VE6 `onFloorTap` = the camera's inverse of the
  canvas point and the fixture's world point (1e-12 relative), selection
  empty in the callback, a Shift miss reports and keeps; VE7 the unnumbered
  table: neither tap nor floor; VE8 M-H21 (and the moved detail equals the
  controller's fresh one, its centre the forward centre plus the drag's
  world delta); VE9 M-H21b, and an unnumbered table's move is reported
  (number null); VE10 M-H29(hover per move) and the exit onto the service
  bar → null; VE11 S-5: `resetLayout` and a mode switch send no null; VE12
  M-H29(hover for touch) through the view, and a stylus hover; VE13 a
  finger's double tap timed from the raw downs (first held past
  `kTouchHoldBack`, second lifted before it).

Every existing test passes unedited.

## Named mutants (each applied, seen red, reverted from a copy)

| Mutant | Applied | Red killers |
|---|---|---|
| M-H20 | `_completesDoubleTap` without the instance check | VE2 `two instances sharing a number: no double tap (M-H20)`; SE5 |
| M-H20b | the `gap <= kDoubleTapTimeout` term dropped | VE3 `timed from the downs' stamps: + 301 ms none, + 299 ms one, whatever the clock (M-H20b)`; SE2, SE5, VE5 |
| M-H20b (clock-timed variant) | `_pressTime` from `clock.now()` | VE3; SE2, SE3, SE5, VE5 |
| M-H20c | the slop term dropped | VE4 `measured between the downs on the screen: 101 px none, 99 px one (M-H20c)`; SE2 |
| M-H21 | the bar's Undo also calls `onTablesMoved` (the drag still reports once) | VE8 `a drag reports the moved table once … (M-H21)` |
| M-H21 (broad variant) | `onTablesMoved` fed from the copy's `changes` stream (every move, undo, redo) | VE8, VE9 |
| M-H21b | `_moved` collects a map by number | VE9 `two moved tables sharing a number are both reported … (M-H21b)` |
| M-H29(hover per move) | the `number == _hovered` check dropped | VE10 `a mouse reports on change only … (M-H29 hover per move)`; SE11 |
| M-H29(hover for touch) | `!e.isTouch` dropped | SE12 `a stylus hovers; a finger never does (M-H29 hover for touch)` |

**M-H29(hover for touch) through the view (VE12) stays green under the
mutant**, as it must: `InteractionLayer._onHover` drops a touch hover
before the tool (`interaction_layer.dart:420`), so no touch move with
`buttons == 0` reaches the tool through a view. The tool-level SE12 is the
killer; VE12 pins the view's behaviour.

Further mutants for the unnamed behaviour, each red:

| Mutant | Red |
|---|---|
| floor reported before the selection logic | SE8, VE6 |
| no chain reset on leaving the slop (drag/pan) | SE5 |
| no chain reset on a long press | SE5 (first green: see Findings 2) |
| no chain reset on cancel | SE6 |
| the modifier ignored for the double tap | SE4, VE5 |
| the pick before the null check | SE13 |
| the tool's `dispose` reports null (S-5) | VE11 |
| `onPointerExit` silent | SE11, VE10 |
| an unnumbered tap keeps the chain | SE5 |
| a floor tap keeps the chain | SE5 |
| `onLayoutChanged` not called before the move | SE10, VE8 |
| render: `_wrap` drops the stamp | TS1, TS2, TS3, TS4 |
| render: the lift-mode tap's down stamped by the lift | TS4 |
| render: the aiming hover unstamped | TS4 |
| render: a held finger re-stamped by the event that routes it (slop) | TS3 |

## Gates

Run here (Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`), on the
working tree that is committed:

- `packages/jet_cad_floor_plan`: `flutter test` **+1582, all passed**
  (26 of them new); `flutter analyze` no issues; format 257 files, 0
  changed.
- `apps/restaurant_demo`: `flutter test` +47 all passed; analyze no
  issues; format 0 changed.
- `apps/floor_planner`: `flutter test` +212 all passed; analyze no issues;
  format 0 changed.
- `packages/jet_cad_2d_flutter` **in full**: `flutter test --file-reporter
  json:…` (runner +1371 ~1 -7, exit 1 as by design), then `dart run
  tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root
  packages/jet_cad_2d_flutter <run.json>`: "1379 tests; the standing
  failures and skips, exactly", exit 0 (the paint allocation invariant
  among them, green). `flutter analyze` no issues; format 224 files, 0
  changed.
- `packages/jet_cad_2d_gpu`: `flutter test` +20 all passed; the comparison
  "20 tests; the standing failures and skips, exactly", exit 0; `flutter
  analyze` no issues.
- `packages/jet_cad_2d` (engine, untouched): `dart test` through the
  comparison: "1258 tests; the standing failures and skips, exactly", exit
  0 (the query allocation invariant among them, green).
- `git status`: only the eight files of this task; no
  `analysis_options.yaml`.

## Findings and deviations

1. **`ServiceEvents` is generic** (`ServiceEvents<M>`), so one internal
   typedef serves the tool (moves as handles) and the view (moves as
   details) while the service view does the mapping, as the plan says. The
   plan's text reads as one non-generic record; the alternative was a second
   typedef or a second tool parameter.
2. **SE5's long-press case** first passed under its mutant: a real long
   press lasts 500 ms, so with monotonic stamps the next down is past the
   300 ms timeout anyway and the reset is unobservable. The test now stamps
   the long press within the timeout while the fake clock runs it (the
   plan's "stamps differ from the clock"), so only the reset prevents a
   double tap. The reset is defensive in practice.
3. **SE5's two-7s case** first used `embeddingCamera()`, where the two 7s'
   centres are 841 px apart: the slop, not the instance, kept it green
   under M-H20. It now runs at 0.025 px/mm with premises (within the slop,
   each picked as its own instance).
4. **The view tests pan the fixture's camera** (`cameraOver`, same 0.37
   px/mm) for tables `embeddingCamera()` puts off the 1440 × 900 canvas: it
   shows only the first row's `1` (x 188 px); `4`, `L`, the 7s and the
   unnumbered table are beyond the canvas, where a pointer hits nothing
   (VE4 first failed for that reason). The plan's "table 4's box is about
   296 × 222 px under `embeddingCamera()`" holds at that scale (pinned).
   The plan's "two 7s 75 px apart at 0.025 px/mm" is the base points'
   distance; their box centres, where VE2 taps, are 57 px apart (asserted
   `< 100`).
5. **No per-move allocation from the events:** a hover reads
   `events().onTableHover` through two identity-cached records
   (`FloorPlanView._serviceEvents`, `ServiceView._toolEvents`); with the
   callback null it returns before any pick (SE13 counts zero picks). With
   it, the work is one `pick` (today's per-candidate `transformPoint`).
6. **Hover over an interactive overlay** reads as null: the layer turns a
   hover onto an `InputClaim` into `onPointerExit` (G-5), so a host with
   interactive overlays hears null while the mouse is on its own badge. A
   consequence of G-5, not changed here; worth a line in the guide (Task 5).
7. **`onTablesMoved` after a host-replaced copy:** if the host's
   `onLayoutChanged` calls `resetLayout` (or anything that replaces the
   active copy), `onTablesMoved` is not called for that drag (the moved
   tables are gone). Not specified by E-1; documented in code only.
8. A touch session's end calls `onPointerExit` (`_endSession`): a mouse
   hover state left non-null is cleared to null by a later finger tap. No
   hover is reported for touch itself.
9. The double-tap chain is not reset by `onPointerExit` (a touch tap's
   session end sends one after every lift, which would break a finger's
   double tap — VE13), nor by a secondary click (the view's, not the
   tool's).

No existing test changed; no `analysis_options.yaml` touched.

## Fixes

This section covers the review (`s2-task-4-review.md`) R-1 to R-5, all accepted by the controller. The fixes are in commit `ec4956b` (parent `c276271`), pushed. Six files changed. No existing test was edited, and no `analysis_options.yaml` was committed.

### Changes

- **R-1.** New test `view_events_test.dart` VE14. Host A's four events are read (a hover through both identity caches, then the first tap of a double tap). The view is then rebuilt with host B's callbacks. A double tap, a hover, a drag and a floor tap follow, and only B hears them: `[A hover 1, A hover null, B double 1, B hover 1, B hover null, B moved [1], B floor]`.
- **R-2.** New test `service_events_test.dart` SE14, at the tool with group `g` = {1, 2}, at 0.025 px/mm. The two tables are within the slop, and each is picked as itself (premises).
  - Two taps on `1` log `tap 1, group g 1, tap 1, group g 1, double 1`.
  - Two taps on `2` end in `double 2`, the member's own number.
  - Taps on `1`, `2`, `1` produce no double tap.
- **R-3.**
  - New test VE15. With `onLayoutChanged: resetLayout`, a drag of `1` logs `layout` only. `tester.takeException()` is null. Table 1's centre is back at the design's (premise).
  - The dartdoc of `onTablesMoved` now says it is not called when `onLayoutChanged` replaced the plan shown, and that the list is unmodifiable.
  - The dartdoc of `onTableHover` now says it reads null on an interactive overlay (`interactive: true`), and that a table is under the pointer on its top or in its box, with no reach.
  - Task 5's guide already had both of the review's sentences. To match the dartdoc, I added two things to its prose: "in an unmodifiable list" and "A table is under the pointer on its top or in its box, with no reach". No code block was touched, and `check_guide` passes unchanged.
- **R-4.**
  - New test VE16: a hover 3 px (3 / 0.37 mm in local units) beyond table 1's right box edge reports nothing. The point 3 px inside reports `1`, and going back out reports `null`. The premises are pinned by `tableAt`.
  - New test VE17: `add` and `removeLast` on the host's moved list both throw `UnsupportedError`.
- **R-5.**
  - `TablePicker.pick` now computes each candidate's local point inline from `c.inverse`'s `a..f`. It uses the same products in the same order as `Transform2.transformPoint`, so the doubles are identical. The pick allocates no `Vector2` per candidate in any of the three passes.
  - The candidate list was already cached on the state id and the tables revision, and the new tests pin that it is not rebuilt per move.
  - New seam: `TablePicker(…, {@visibleForTesting Transform2 Function(Transform2)? invert})`, defaulting to `Transform2.invert`. Through it a test hands in a `CountingTransform`, which overrides each `Transform2` member that returns a new object and counts the calls into a shared `Tally`.
  - The VM allocation profiler that `query_allocation_test` uses is not reachable under `flutter test`: `Service.controlWebServer` returned a null URI in a throwaway probe, which I deleted. So the count is taken at the inverse.
  - New test SE15 (tool, with `onTableHover` set, `rowOfTables(60)`):
    - Each table gets three hovers: a top point, a box point off the top (the second pass), and a floor point 1.77 m from every base point (both passes in full).
    - The premise is that the hovers report `k, null` per table.
    - After a warm-up, 900 hovers leave the tally at 0, the inverse count at 60, and `picker.candidates` identical.
  - New test TP14 (picker, `rowOfTables(20)`): a top, a box off its top, 100 mm beyond the box (null), the same point with reach 150 (hit), and a floor miss with reach. The expected instances come from the forward transform. After 1000 picks the tally is still 0, nothing has been rebuilt, and the list is identical.
  - Every existing picker and tool test passes unedited.

### Mutants: each applied by an exact single-anchor script, run, restored from a copy and checked with `cmp`

| Mutant | Applied | Red |
|---|---|---|
| O11 | `FloorPlanView._serviceEvents`: `if (_eventsOf == null)` | VE14 |
| O11b | `ServiceView._toolEvents`: `if (_hostEvents == null)` | VE14 |
| O13 | double tap before `onGroupTap` | SE14 |
| O17 | `_moved` without the active-plan guard | VE15 |
| O18 | hover picked with `reach: e.pickRadiusWorld` | VE16 |
| O26 | `report(List.of([...]))` | VE17 |
| M-R5 | `c.inverse.transformPoint(world)` back in all three passes | SE15, TP14 |
| M-R5 (top pass only) | as above, first loop | SE15, TP14 |
| M-R5 (box pass only) | as above, second loop | SE15, TP14 |
| M-R5 (reach pass only) | as above, third loop | TP14 (SE15 stays green as it should: a hover has no reach) |
| M-R5c | candidates rebuilt per pick (`if (true)` for the cache check) | SE15, TP14 |

Each mutant was run against the test file or files named in its row. Each was red only in the test listed.

### Limits

- The counting test sees every new object a pick asks an inverse for, plus every rebuild of the candidates.
- It does not see a bare `Vector2(...)` written into `pick`, or boxed doubles in the JIT. That would need the VM profiler, which `flutter test` does not expose.

### Gates (Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`, on the committed tree)

- `packages/jet_cad_floor_plan`:
  - `flutter test`: **+1592: All tests passed!** (7 new: SE14, SE15, TP14, VE14 to VE17);
  - `flutter analyze`: No issues found;
  - format: 257 files, 0 changed.
- `apps/restaurant_demo`: +55 All tests passed; No issues found; format 6 files, 0 changed.
- `apps/floor_planner`: +212 All tests passed; No issues found; format 47 files, 0 changed.
- `packages/jet_cad_2d_flutter` (full, json run, exit 1 by design): `expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter` gives "1379 tests; the standing failures and skips, exactly", exit 0.
- `packages/jet_cad_2d_gpu`: +20 All tests passed; the comparison gives "20 tests; the standing failures and skips, exactly", exit 0.
- `packages/jet_cad_2d` (engine, `dart test`, json run): the comparison gives "1258 tests; the standing failures and skips, exactly", exit 0.
- `tool/ci`: `dart test` +62 All tests passed. `dart run tool/ci/check_guide.dart` gives "all 32 code blocks are in the host probe", exit 0. The probe and the code blocks are untouched.
