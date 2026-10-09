# Slice 2, Task 4 review: view events (E-1 to E-4)

Commit under review: `cb62b8b` (parent `890656d`) on `claude/exciting-pasteur-9m22jv`.
My clones are `/home/user/review-s2t4` (gates) and `/home/user/review-s2t4-mut` (mutants, plus one probe test, `test/zz_review/r5_probe_test.dart`, that is not for commit). I edited, committed and pushed nothing in `/home/user/jet-cad` except this file.
Flutter `/root/sdk/flutter/bin` (3.47.6), `CI=true`.

## Verdict: **Approve with fixes**

- The diff is Task 4 and nothing else.
  - `jet_cad_2d_flutter` changes only the `ToolPointerEvent.timeStamp` plumbing.
  - `ServiceCallbacks` is not widened, no existing test is edited, and the barrel is unchanged.
- Every gate is green, and every standing set matches exactly. I reran each one with real counts (§4).
- All 7 named mutants are red, plus the clock-timed M-H20b variant.
- 26 of my own 33 mutants are red against the committed suite (30 planner, 3 render).
  - Seven survive the whole `test/host` and `test/service` suites (+394):
    - O11 and O11b (R-1), O13 (R-2), O17 (R-3), O18 and O26 (R-4);
    - O25, which is equivalent.
- I found no defect in the committed code on any path I traced, touch included.
  - The probe I wrote for R-1 passes on `cb62b8b` and goes red under both capture mutants.

**What needs fixing:**
- **R-1 (Important):** a test gap on R-5 through the view.
- **R-2 and R-4 (Minor):** two more test gaps.
- **R-3 (Minor):** one doc sentence plus a test.
- **R-5 (Minor):** the hover's per-move allocation, which the brief asked me to reason about. Fix it now or record it as a follow-up.

## 1. Scope and P-1

`git diff --name-status 890656d cb62b8b` shows 8 files:
- `M` `jet_cad_2d_flutter/lib/src/{tool,interaction_layer}.dart`
- `A` `jet_cad_2d_flutter/test/interaction_layer_time_stamp_test.dart`
- `M` `jet_cad_floor_plan/lib/src/host/{floor_plan_view,service_view}.dart`
- `M` `jet_cad_floor_plan/lib/src/service/table_select_tool.dart`
- `A` the two new planner tests

No existing test is modified. No `analysis_options.yaml` and no CHANGELOG is in the commit.

**`jet_cad_2d_flutter`**
- `ToolPointerEvent` gains one named optional `this.timeStamp = Duration.zero`. The constructor stays `const`, and `Duration.zero` is const.
- The class is `final` and has no `==`, `hashCode` or `toString`, so none of them change.
- The only other edit is the private `_event`, which gains a positional `Duration`.
- No other library code builds a `ToolPointerEvent`. `grep -rn "ToolPointerEvent("` outside the tests finds only `_event`.

**`ServiceCallbacks`**
- It still has five fields (checked against `git show 890656d`).
- `table_select_tool_test.dart:68-75`'s literal still compiles and passes.
- The events travel in the internal `ServiceEvents<M>`, behind a new optional `events` on both `TableSelectTool` and `ServiceView`. Each defaults to `kNoServiceEvents`, which is all `null`.

**Barrel**
- The barrel is unchanged.
- The four callbacks' types need no new public name:
  - `void Function(List<FloorPlanTableDetail>)?` (`FloorPlanTableDetail` is already exported, `lib/jet_cad_floor_plan.dart:34`)
  - `void Function(String)?`
  - `void Function(Offset)?`
  - `void Function(String?)?`
- `table_select_tool.dart` and `service_view.dart` are not exported.
- No handle crosses the barrel (invariant 5): `ServiceView._moved` maps handles to details inside the package.

## 2. Correctness

### Stamps and touch

**Plumbing.**
- `_wrap(e)` passes `e.timeStamp`. Every route of a held finger is `_wrap(held)`, so it carries the raw down's stamp. The routes are:
  - the hold-back timer (`_routeHeld`);
  - leaving the slop (`_touchMove` → `_routeHeld`);
  - the press-mode lift (`_touchUp`).
- The lift-mode tap's down passes `held.timeStamp`, and the aiming hover passes the move's stamp.
- Mouse down, move, up and hover each carry their own stamp (TS1–TS4).

**A finger's double tap works**, whichever way each tap is routed. Trace for two quick taps on `1`:
- Each down is held, then routed as `_wrap(held)` at the lift (or at the hold-back), then comes the up, then `_tap`.
- `_pressTime` and `_pressScreen` are the raw down's.
- `_endSession` sends `onPointerExit` after each lift. It does not touch the chain, which is correct: see ruling 4 below.
- VE13 covers one tap held past `kTouchHoldBack` and one lifted before it.
- My R02 (the lift route stamped with the up's time) is red in VE13 and TS3.
- My R01 (the hold-back route stamped with the routing time, `held.timeStamp + kTouchHoldBack`) survives VE13 (the gap becomes 190 ms). It is red in TS2 and TS3, so the render test is the killer, as designed.

**14t interplay.**
- **Long press.** A finger's timer runs `kLongPressTimeout − kTouchHoldBack` from the routed down. `_longPress` resets the chain (O23 is red in SE5).
- **Slop.** A finger leaving the slop is routed, then moved past `kTouchSlop` in the tool, and `_lastTap = null` (O04 is red in SE5). The tool-level test drives it with a mouse event, but the tool code is the same.
- **Touch reach.** A finger within 24 px of a table hits it, so it counts toward the chain on that instance.
- **Pinch.**
  - If the first finger was already routed, `_goMulti` cancels the tool and the chain resets.
  - If it was still held, the tool never hears it and the chain survives. A tap, then a pinch, then another tap would all have to fit inside 300 ms and 100 px, so I record this as unreachable.

### Double tap rules

**Rules.**
- The same instance is required (M-H20).
- The bounds are inclusive and measured between the two downs (S-6; SE2, O15 and O16 are red).
- A negative gap never completes (O22 is red, through SE5's reused stamps).
- A modifier on either tap prevents it, and a modifier tap breaks the chain (O02 and O03 are red).
- A third tap starts anew (SE1).
- The decision and the new chain state are settled before any callback, so a re-entrant host cannot corrupt the chain.

**Order.** The order is `onTableTap`, then `onGroupTap`, then `onTableDoubleTap` (O12 is red in 11 tests). With a group it is not tested (R-2).

**Group member.** A double tap on a group member reports that member's number with the group, by code reading (`_tap:362-390`). It is untested (R-2).

**Locked `L`.** It double-taps and stays unselected (SE7, VE5).

### Floor tap

- It is reported after the selection logic (O05 is red).
- It fires with or without a modifier (O19 is red).
- It reports the down's world point, not the up's (O06 is red in SE8).
- VE6 pins the point exactly under the panned 0.37 px/mm camera: the inverse is written out, and the result matches the fixture's mm at 1e-12.
- A tap on the unnumbered table is a hit, so it reports neither a tap nor the floor (SE9, VE7). It also resets the chain (O14 and O28 are red).

### Hover

- A mouse or stylus reports only on a change (M-H29 per move).
- It reports null over the floor or an unnumbered table (O07 is red).
- On exit it reports null once, and resets the state (O08 and O08b are red).
- With no callback it does no pick at all (SE13).
- A pressed move is no hover (O27 is red).
- Touch never reports a hover:
  - The layer drops touch hovers at `interaction_layer.dart:420`.
  - At the tool, `!e.isTouch` gates it (M-H29 for touch is red in SE12).
  - VE12 pins the view.
- Nothing is sent on a remount (S-5, VE11).

### `onTablesMoved`

**When it fires.**
- It fires after `onLayoutChanged` (O09 is red), once per drag, not on a zero drag (SE10).
- Undo, Redo, reset and restore never reach `_move` (M-H21 is red in VE8).

**What it reports.**
- The live moved instances in `_moving` order, which is sorted by handle value, so ascending (O10, selection order, is red in SE10).
- Multi-select drags work (SE10: `4`, then Shift `1`).
- Duplicates are both present (M-H21b is red in VE9).
- An unnumbered table is reported (VE9).
- The details are `c.tableDetails`, read after the command, so they are fresh. VE8 checks the moved centre against the forward centre plus the drag's world delta.

**Edge cases.**
- A moved handle is missing from `tableDetailInstances` only if it is not live. The tool already filters those out, so O25 is equivalent.
- `tableDetails` lists hidden-layer tables too (with no geometry), so a host-selected hidden table that moves with a drag is still reported.

### R-5 (callbacks read at each call)

**Tool.** `events()` and `callbacks()` are read at each call. SE8 and SE13 swap the record mid-test.

**View.** The two identity caches are correct:
- `FloorPlanView._serviceEvents` rebuilds when `widget` is a new object.
- `ServiceView._toolEvents` rebuilds when the host's record is a new object.

My probe confirms it: the host rebuilds with a new `onTableDoubleTap` and `onTableHover` after the events have been read, and the next calls reach the new closures. It passes on `cb62b8b`. The suite does not test this (R-1).

### Rulings on the implementer's findings

1. **Generic `ServiceEvents<M>`: accepted.** It is internal and not exported, `ServiceCallbacks` is untouched, and the plan's "typedef `ServiceEvents` (internal)" does not forbid a type parameter. A second typedef would duplicate the three shared fields.
2. **Hover over an interactive overlay reads null: accepted, as a consequence of G-5.** The layer turns a hover onto an `InputClaim` into an exit. A host that highlights the hovered table and draws interactive badges on it will see `n → null → n` as the pointer crosses its own badge. Task 5's guide must say so. `onTableHover`'s doc should also say "or over an interactive overlay" next to "leaves the canvas" (folded into R-3's doc edit).
3. **`onTablesMoved` skipped when the host's `onLayoutChanged` replaces the copy: accepted.** Reporting the new copy's details for those handles would describe positions the drag did not produce. The guard is untested, though, and the public doc does not mention it (R-3).
4. **Double-tap chain not reset by `onPointerExit`: accepted, and required.** The layer sends an exit at every touch session's end, and on a mouse `removePointer`. My O21 (exit resets the chain) is red in VE1, VE3, VE4, VE5 and VE13. On a mouse, the chain could survive leaving the canvas and coming back within 300 ms and 100 px, which is harmless.

## 3. Frame path

**Measured invariants.**
- `paint_allocation_test` is green in the full render run (all 3 tests), and so is `query_allocation_test` in the engine run (all its tests).
- Neither file nor any counter test was touched.
- `TableSelectTool` is not on either measured path.

**Per hover move, without the callback.** The work is two closure calls and two identity checks, with no allocation and no pick (SE13 counts zero picks).

**Per hover move, with the callback.**
- The event reads allocate nothing: both records are identity-cached.
- The pick allocates. `TablePicker.pick` (`table_picker.dart:278-305`) calls `c.inverse.transformPoint(world)` once per candidate it visits, and each call returns a new `Vector2`.
- On a floor hover that is two full passes: about 2·N `Vector2`s and an O(N) linear scan per mouse move, at mouse rate.
- This is what the plan specified ("picks at the point"), and the implementer disclosed it (finding 5). It is still per-entity allocation in a steady state at pointer rate, which goes against CLAUDE.md's first non-negotiable (R-5 below).

## 4. Gates (rerun in my clone at `cb62b8b`)

| Package | Result |
|---|---|
| `packages/jet_cad_floor_plan` | `flutter test` **+1582: All tests passed!**; analyze: No issues found; format: 257 files, 0 changed |
| `apps/restaurant_demo` | +47 All tests passed; No issues; 5 files, 0 changed |
| `apps/floor_planner` | +212 All tests passed; No issues; 47 files, 0 changed |
| `packages/jet_cad_2d_flutter` (full) | json run: 1371 success, 7 error (`text ladder rung 1–5`, `text lod ladder rung 1–2`), 1 skipped; `expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter`: "1379 tests; the standing failures and skips, exactly", exit 0; analyze: No issues; format: 224 files, 0 changed |
| `packages/jet_cad_2d_gpu` | +20 All tests passed; comparison "20 tests; the standing failures and skips, exactly", exit 0; analyze: No issues |
| `packages/jet_cad_2d` (engine) | json run: 1256 success, 2 failure (`the default document is the one Plan 2 measured, byte for byte`, `both text fractions default to zero and change nothing`); comparison "1258 tests; the standing failures and skips, exactly", exit 0 |

These agree with the implementer's report.

## 5. Mutants

Each mutant was applied in `/home/user/review-s2t4-mut`, run, and restored from a copy, by `scratchpad/mut/mut.py` with exact single-anchor replacement. The first pass ran against `test/service/service_events_test.dart` and `test/host/view_events_test.dart`. Survivors were then rerun against all of `test/host` and `test/service` (+394).

### Named

| Mutant | Applied as | Result |
|---|---|---|
| M-H20 | instance check dropped in `_completesDoubleTap` | **red**: SE5, VE2 |
| M-H20b | `gap <= kDoubleTapTimeout` term dropped | **red**: SE2, SE5, VE3, VE5 |
| M-H20b (clock) | `_pressTime` from `DateTime.now()` | **red**: SE2, SE5, VE3, VE5 |
| M-H20c | slop term dropped | **red**: SE2, VE4 |
| M-H21 | the bar's Undo also calls `_moved(all instances)` | **red**: VE8 |
| M-H21b | `_moved` collects a map by number | **red**: VE9 |
| M-H29 (hover per move) | `number == _hovered` check dropped | **red**: SE11, VE10 |
| M-H29 (hover for touch) | `!e.isTouch` dropped | **red**: SE12 (the view cannot carry a touch hover to the tool, so VE12 stays green, as the report says) |

### Mine (33)

| # | Mutant | Result |
|---|---|---|
| O01 | slop measured in world units (world point kept, world distance compared) | **red**: SE2, VE4 |
| O02 | a modifier tap kept as the chain (modifier checked on the second tap only) | **red**: SE4, VE5 |
| O03 | the modifier ignored on the completing tap | **red**: SE4, VE5 |
| O04 | chain not reset on leaving the slop (drag/pan) | **red**: SE5 |
| O05 | floor tap before the selection logic | **red**: SE8, VE6 |
| O06 | floor tap with the up's world point | **red**: SE8 |
| O07 | an unnumbered table leaves the hover unchanged (no null) | **red**: SE11 |
| O08 | exit not reporting null | **red**: SE11, VE10 |
| O08b | exit reports null but keeps `_hovered` | **red**: SE11 |
| O09 | `onTablesMoved` before `onLayoutChanged` | **red**: SE10, VE8 |
| O10 | moved list in selection order instead of handle order | **red**: SE10 |
| O11 | `FloorPlanView._serviceEvents` captured at first read (`_eventsOf == null`) | **SURVIVED** (+394), see R-1 |
| O11b | `ServiceView._toolEvents` captured at first read | **SURVIVED** (+394), see R-1 |
| O12 | double tap before `onTableTap` | **red**: SE1–SE5, SE7, VE1, VE3, VE4, VE5, VE13 |
| O13 | double tap before `onGroupTap` | **SURVIVED** (+394), see R-2 |
| O14 | an unnumbered tap keeps the chain | **red**: SE5 |
| O15 | timeout exclusive | **red**: SE2 |
| O16 | slop exclusive | **red**: SE2 |
| O17 | `_moved` without the active-plan guard | **SURVIVED** (+394), see R-3 |
| O18 | hover picked with the pointer's reach (6 px) | **SURVIVED** (+394), see R-4 |
| O19 | floor tap only without a modifier | **red**: SE8, VE6 |
| O20 | `_pressTime` from the up's stamp | **red**: SE3 |
| O21 | `onPointerExit` resets the chain | **red**: VE1, VE3, VE4, VE5, VE13 |
| O22 | negative gap allowed | **red**: SE5 |
| O23 | long press does not reset the chain | **red**: SE5 |
| O24 | cancel does not reset the chain | **red**: SE6 |
| O25 | the tool reports dead handles too | **SURVIVED**: equivalent (nothing is deleted mid-drag in the selection mode, and `_moved` drops handles absent from `tableDetailInstances`) |
| O26 | host-facing moved list modifiable | **SURVIVED** (+394), see R-4 |
| O27 | hover also on pressed moves | **red**: SE13 |
| O28 | floor tap keeps the chain | **red**: SE5 |
| R01 (render) | hold-back route stamped with the routing time (`held.timeStamp + kTouchHoldBack`) | **red**: TS2, TS3 (survives the planner's VE13: gap 190 ms) |
| R02 (render) | press-mode lift route stamped with the up's time | **red**: TS3; planner VE13 |
| R03 (render) | slop route stamped with the move's time | **red**: TS3 |
| (probe) | O11, O11b against my R-5 probe | **red** both; the probe is green on `cb62b8b` |

## 6. Findings

### R-1 (Important): R-5 through the view is untested for the four events

**Evidence.**
- `FloorPlanView._serviceEvents` (`floor_plan_view.dart:259-277`) and `ServiceView._toolEvents` (`service_view.dart:115-128`) are new identity caches. This task added them specifically so that the events are read at each call without allocating.
- Mutating either cache to "capture at first read" survives every test under `test/host` and `test/service` (O11, O11b; +394).
- P-3 says a view parameter is "never captured (R-5)", and the plan says "read at each call".
- The code is correct today. My probe passes on `cb62b8b`:
  1. A mouse hover with host `A` makes the caches read the events.
  2. The host rebuilds `FloorPlanView` with new closures `B`.
  3. A double tap and a hover then log `['A hover 1', 'A hover null', 'B double 1', 'B hover 1']`.

  Both mutants turn the probe red.

**Fix.** Land a VE14 in `view_events_test.dart` shaped like the probe (`/home/user/review-s2t4-mut/packages/jet_cad_floor_plan/test/zz_review/r5_probe_test.dart`):
- Read the events with host A first (a hover), then `pumpWidget` host B.
- Then a double tap, a hover, and ideally a drag (`onTablesMoved` goes through `_moved`'s own re-read) and a floor tap, each heard only by B.
- Name O11 and O11b as its mutants.

### R-2 (Minor): the double tap with a group is untested (order and member report)

**Evidence.**
- The plan fixes the order: "`onTableDoubleTap(number)` after its own `onTableTap` (and `onGroupTap`)".
- Every event test runs with `groups: ValueNotifier(const {})` and no `onGroupTap`, so O13 (double before group) survives.
- Nothing tests that a double tap on a member reports the member's number.

**Fix.** Add one tool-level test, SE14:
- Set groups to `{'g': TableGroup(['1', '2'])}` (or the planner's group shape) and log `onGroupTap`.
- Two taps on `1` → `['tap 1', 'group g 1', 'tap 1', 'group g 1', 'double 1']`.
- A tap on `1`, then on `2` (same group, other instance) → no double tap.

### R-3 (Minor): the active-plan guard in `_moved` is untested, and its behaviour is undocumented in the public API

**Evidence.**
- O17 survives.
- `FloorPlanView.onTablesMoved`'s doc says "once per drag, after `onLayoutChanged`". It does not say that nothing is reported when the host's `onLayoutChanged` replaces the plan (`resetLayout`, `restoreServiceLayout`, `load`, a mode switch). The ruling on finding 3 accepts that behaviour.
- Without the guard, a host that resets in `onLayoutChanged` would be told the reset copy's positions as "moved".

**Fix.**
- Add a view test: `onLayoutChanged: () => c.resetLayout()`, then a drag of `1` → no `onTablesMoved` and no exception.
- Add one sentence to `onTablesMoved`'s doc: "not called when `onLayoutChanged` itself replaced the plan shown".
- Also add, in `onTableHover`'s doc, "or moves onto an interactive overlay" beside "leaves the canvas" (ruling 2).
- Task 5's guide should carry both.

### R-4 (Nit): two host-visible details are not pinned

**Evidence.**
- **Hover without reach.** The plan says "picks at the point (no reach)". O18 picks with the mouse's 6 px reach and survives, because no hover test sits just outside a table's box.
- **The host's moved list is unmodifiable.** SE10 pins the tool's list. Nothing pins the host's list (O26 survives), although the code makes it unmodifiable as `tableDetails` is.

**Fix.**
- In SE11 or VE10, a hover 3 px outside `1`'s box (screen, by the forward transform) → no report.
- In VE8, `expect(() => heard.moved.single.add(moved), throwsUnsupportedError)`. Or state in the doc that the list is unmodifiable and pin that.

### R-5 (Minor): a hover with the callback set allocates per table per mouse move

**Evidence (§3).**
- `TablePicker.pick` allocates one `Vector2` per candidate visited (`c.inverse.transformPoint(world)`, `table_picker.dart:282, 287, 295`).
- A floor hover is two full passes, so about 2·N allocations and an O(N) scan per mouse move while the host listens.
- It is outside the measured invariants and follows the plan's "picks at the point", but it breaks the spirit of "allocates nothing per entity in steady state" on a pointer-rate path.

**Fix.** Choose one of these two paths:
- **Fix now.** It is planner-only and a few lines. Compute the local point inline from `c.inverse`'s `a..f` (the tests already do this arithmetic) instead of `transformPoint`, in all three loops. Then add a counting test: hover N moves over the floor of the fixture and count `Vector2` allocations, or compare `pick`'s allocation against a 1-table and a 10-table plan. Taps benefit too.
- **Record it.** Put it in the ledger as a follow-up beside Task 5's notes, with these numbers.

### Observations (no action)

- **The hover is refreshed only on a pointer move.** A table that moves under a still pointer (Undo, wheel zoom, a pan, a drag's end) keeps the last reported number until the next move. This matches E-4's wording ("entering … or leaving"). Worth one guide line.
- **A held finger's world point uses the camera at routing time** (R-9d, pre-existing). This applies to the floor tap's point and the pick. Nothing pans between a held finger's down and its routing, so it is unobservable today.
- **The touch session end calls `onPointerExit`** (implementer finding 8). A mouse hover left non-null is cleared by a later finger tap. This is consistent with E-4 ("never for touch" concerns reports, not the clearing).
