# Slice 2: the final review's fixes (F-1 to F-7)

Range `ec4956b..e6a1d06` on `claude/exciting-pasteur-9m22jv`, pushed.
Flutter `/root/sdk/flutter/bin` (3.47.6), `CI=true`. No existing test was
edited: `git diff ec4956b e6a1d06 -- '**/test/**'` has no removed line in
the five touched test files, and the other two test files are new. No
`analysis_options.yaml` was committed, and STATUS, the results note and
the roadmap were not touched.

| SHA | Commit |
|---|---|
| `8f813b2` | F-1: `designChanges` delivers nothing after `dispose()` |
| `a78b728` | F-2: a pick allocates nothing per table, measured by the VM's allocation profiler |
| `2f252ca` | F-3: `idOf` and the demo's double tap read no id for a duplicated number |
| `4016316` | F-4, F-5, F-6: VE18, DE9, SE16 |
| `e6a1d06` | F-7: the spec's E-1, E-4 and Review section |

## F-1: dispose (fixed in code)

**The change.** `designChanges` now returns
`_designChanges.stream.where((_) => !_disposed)`, cached in a `late final`.
The filter reads the disposed flag at delivery time, for each event and each
listener. A change already added, whether an edit's or the
`FloorPlanPlanReplaced` that a `load` or `newPlan` flushed in the same
synchronous step, is not passed on once `dispose()` has run, and then the
stream is done.

**What stays the same.** `where` forwards synchronously inside the source's
own delivery, so delivery is otherwise unchanged:
- still the non-sync broadcast controller;
- asynchronous;
- one report per synchronous step;
- `onListen` and `onCancel` still run on the first listener and on the last
  cancel;
- every DC test passes unedited.

I chose this over the sync controller fed from a microtask, which the
ruling offered as an example. It meets the ruling's condition (the flag is
checked at delivery) without touching the delivery path.

**Docs.** The `designChanges` dartdoc, the guide's last bullet and the
CHANGELOG now read: "nothing reaches it after `dispose()`, not even a change
reported before it and not yet delivered (a `load` in the same step)".

**Tests:**
- DC18: an edit, a `load` and `dispose()` in one step deliver nothing, then
  done. A second controller does `newPlan()` then `dispose()`, with the same
  result.
- DC19: a listener that disposes the controller on the first change of a
  two-change report (`setTablesData` on 1 and 2) hears no second change,
  then done.

**Mutant MF1** (`where((_) => true)`): red in DC18 and DC19.

## F-2: hover allocation (fixed in code, measured)

**The cause.** Two calls passed doubles to code the JIT may leave out of
line, and a double passed that way is boxed:
- the `x` and `y` getters of the picked point, two per pick;
- the dynamic `TableTop.contains(x, y, tol)`, two per table.

**The fix** (`table_picker.dart`):
- `pick` reads `world.storage[0]` and `[1]` instead of the getters.
- Each top gets its local point through a `Float64List(2)` the picker keeps,
  via a new `TableTop.containsAt(Float64List point, Tolerance)`.
- `contains(x, y, tol)` is kept for its existing callers, built on
  `containsAt`.
- The arithmetic is the same, with the same products in the same order, so
  pick results are identical. The full planner suite and every picker and
  tool test pass unedited.
- `_boxDistance` and `_segmentDistance` remain static calls with double
  arguments. The JIT inlines them: the measurements show no per-table cost
  in the box pass or the reach pass.

**The test.** `packages/jet_cad_floor_plan/test/invariants/pick_allocation_test.dart`
holds PA1, PA2 and PA3.
- **Meter:** `test/invariants/vm_allocation_meter.dart` is a copy of the
  engine's `AllocationMeter`. Only its skip reason differs. A test file
  cannot be imported across packages, and the engine's `testing.dart` cannot
  carry the meter without making `vm_service` a dependency of every host.
- **Dependency:** `vm_service: ^15.2.0` becomes a dev dependency of the
  planner. The root lock is unchanged, and the host probe's lock still has
  40 packages.
- **Fixture:** 60 tables 40 m off the origin, each turned 37° and mirrored.
  Stools (circle tops) and trapezoids (polygon tops) alternate, so both
  `containsAt` implementations run.
- **Cases:**
  - PA1: a floor point with a reach of 150, so all three passes visit every
    table;
  - PA2: the lowest table's top, so every top is visited;
  - PA3: inside the lowest table's box but off its top, so every top and
    then every box is visited.
- **Method:** 20,000 warm-up picks, then `reset`, then 1,000 measured picks.
  The budget is under 0.5 `_Double` and 0.5 `Vector2` per pick, the engine's
  `_perCallBudget`. The test checks two premises: the pick returns the
  expected candidate, and the candidates are not rebuilt.

**CI.** `flutter_tester` is started with the VM service disabled, so
`Service.controlWebServer` returns no URI. Measured: `serverUri` is null
before and after the call. The profiler is therefore reachable only with
`flutter test --enable-vmservice`.
- Following the engine's idiom, the test skips with a reason that starts
  with `vmServiceSkipMarker`.
- CI now passes the flag to this package only, through a matrix field
  `test_flags: --enable-vmservice` in `.github/workflows/ci.yml`. The test
  step is now `${{ matrix.tool }} test ${{ matrix.test_flags }} …`.
- New test SC20 in `tool/ci/test/scripts_test.dart` pins the flag and the
  step.
- A flagless run of the file through `expect_failures.dart` exits 1 with
  "skipped for want of the VM service" for PA1 to PA3. So a lost flag cannot
  pass silently.
- A plain local `flutter test` in the planner shows `~3` skips and still
  exits 0. Run the planner with `--enable-vmservice` to measure.

**AllocationMeter numbers, per 1,000 picks.** All runs used
`flutter test --enable-vmservice`.

| Measure | `_Double` | `Vector2` |
|---|---|---|
| Before, the review's probe (`rowOfTables`, 60 trapezoids), 3 runs | 120,055 in most cases. JIT-dependent variants: 100,009; 26,314; 59 | 3 |
| Before, the same probe with 1 table | 2,055 or 55 | 3 |
| Before, `ec4956b`'s picker under PA1/PA2/PA3, 3 runs | (16,470, 63, 62,058), (12,180, 62,058, 66), (62,060, 62,058, 66). Two of the three tests red in every run | 5 |
| After, the review's probe, 3 runs | 55 in every case, for both 1 and 60 tables | 3 |
| After, PA1/PA2/PA3, 3 printed runs | 60 / 59 / 59 in each run. About 10 more unprinted runs passed | 5 |

**Mutants:**
- **The pre-fix picker** (`git show ec4956b:…/table_picker.dart`): red, as in
  the table above.
- **MF2b**, the getters read again (`world.x`, `world.y`) with `containsAt`
  kept: red in all three runs, at 2,058 to 2,060 `_Double`, about 2 per pick.
  One run had PA2 at 58.
- **MF2a**, the point handed back to `contains` as two doubles, with the
  storage read kept: **survives** in 5 of 5 runs, at 59 or 60. It also reads
  55 under the review's probe.
  - With the getter call gone, the JIT inlines the call to the top, for both
    classes at this site, and an inlined call boxes nothing.
  - So in this JIT the measured cause was the getters' out-of-line calls,
    and their side effects on inlining.
  - `containsAt` makes "no doubles through the dynamic call" a matter of
    structure, not of the inliner's choices. The test file's comment says
    this survivor exists.

## F-3: the read rule (fixed)

**Guide and probe.** The guide's `idOf`, kept in step with
`tool/ci/host_probe/lib/main.dart`, now collects the details that carry the
number and returns an id only when exactly one does. Its doc reads "null
when no table carries the number, or when two do (it names neither)".

**New guide bullet, "Read a link the same way".** It explains:
- how a number comes to name two tables after a link: a renumbering that
  `numberingWarnings` reports but allows;
- why the first table's id would be wrong: it would open the other table's
  bill.

`check_guide` reports "all 32 code blocks are in the host probe".

**Demo.** `_opened` does the same and logs "(no id)", so no new strings are
needed.

**Test DE10.**
- Setup: Link tables, then `2` renumbered to `1`, so two linked tables carry
  `1`.
- A double tap on either `1` logs "table 1 opened (no id)".
- `7` still logs "(id salon-7)".

**Mutant MF3** (the demo reads the first match): red in DE10.

## F-4: VE18 (test added)

- **Setup:** in the design, `1` gets
  `{zeta: z, id: pos-1, alpha: Masa 1.ğ}` and `2` gets `{id: pos-2}`.
  Then the test enters the service and drags `1`.
- **Checks:**
  - the log reads `['layout', 'moved [1]']`;
  - the moved detail's `data` equals the map, with keys
    `['alpha', 'id', 'zeta']`;
  - the detail equals the controller's fresh detail;
  - back in the design, the data is unchanged.
- **R19** (the moved details lose their data): red in VE18.

## F-5: DE9 (test added)

- **Setup:** the reviewer's P5. Service, drag `1`, design (a layout is
  kept), Revert.
- **Checks:**
  - `takeException()` is null;
  - the log reads "plan replaced", then "reloaded";
  - the view is still in design (`link-tables` shown);
  - entering the service logs "layout restored, 1 moved, 0 dropped", and
    `serviceEdited` is true.
- **D01** (restore on `PlanReplaced` whatever the mode): red in DE9. The
  whole demo suite was run.

## F-6: SE16 (test added; R17 is equivalent)

**The test.** It uses table `4`, on whole pixels.
- A first tap drifts 15 px before its up. That is within `kTouchSlop`: it is
  still logged as a tap.
- A second down 99 px from the first down, which is 114 px from its up,
  gives a double tap.
- With the drift towards it, a second down 101 px from the first down, which
  is 86 px from its up, gives two taps.

**R17 cannot be killed: it is equivalent.** It is the reviewer's mutant,
`screen: _lastScreen` in `_tap`.
- `_lastScreen` is written only in `onPointerDown`, as the down's point, and
  in `_drag`.
- A move within the slop returns before `_drag`
  (`table_select_tool.dart:231`), and a move past it ends the tap.
- So whenever `_tap` runs, `_lastScreen == _pressScreen`. R17 survives
  SE16, as expected, along with the host and service suites.

**What SE16 does kill:**
- **R17b**, which measures from the up: `_pressScreen = e.screen` in
  `onPointerUp`'s pressed case, before `_tap`. Red in SE16.
- **R17c**, which is R17 plus `_lastScreen` following moves within the slop,
  so that it is the last point before the up. Red in SE16.

## F-7: the spec (recorded)

**E-1** gains an "Amended during Slice 2's implementation" note, from
`s2-task-4-review.md`:
- `onTablesMoved` is not called when the host's `onLayoutChanged` replaced
  the service copy (ruling 3);
- the moved list is unmodifiable (R-4).

**E-4** gains the same kind of note:
- a hover has no reach (R-4);
- it reads null over an interactive overlay (ruling 2).

**Review section.** A new line, "Amended by Slice 2's reviews", follows the
S-1 to S-6 paragraph. It lists these four rulings plus F-1's dispose rule
(E-5) and F-3's read rule (E-6).

## Gates at `e6a1d06`, rerun by me

| Package | Result |
|---|---|
| `jet_cad_floor_plan` | `flutter test --enable-vmservice`, as CI now runs it: `05:35 +1599: All tests passed!`. That is 1,592 plus PA1–3, DC18, DC19, VE18 and SE16. PA1–3 ran rather than skipping (JSON `skipped: false`). Comparison: "1599 tests; the standing failures and skips, exactly", exit 0. `flutter analyze`: No issues. Format: 259 files, 0 changed |
| `jet_cad_2d` | `+1256 -2` (exit 1, by design). Comparison: "1258 tests; the standing failures and skips, exactly", exit 0. `dart analyze --fatal-infos`: No issues. Format: 170 files, 0 changed |
| `jet_cad_2d_flutter` | `+1371 ~1 -7`. Comparison: "1379 tests; … exactly", exit 0. Analyze: No issues. Format: 224 files, 0 changed |
| `jet_cad_2d_gpu` | `+20: All tests passed!`. Comparison: "20 tests; … exactly", exit 0. Analyze: No issues. Format: 10 files, 0 changed |
| `jet_cad_restaurant_symbols` | `+97: All tests passed!` (comparison exact). Analyze: No issues. Format: 15 files, 0 changed |
| `apps/restaurant_demo` | `+57: All tests passed!` (55 plus DE9 and DE10; comparison exact). Analyze: No issues. Format: 6 files, 0 changed |
| `apps/floor_planner` | `01:49 +212: All tests passed!` (comparison exact). Analyze: No issues. Format: 47 files, 0 changed |
| `tool/ci` | `dart test` `+63: All tests passed!` (62 plus SC20). CI's analyze list: No issues. CI's format list: 11 files, 0 changed. `check_guide`: "all 32 code blocks are in the host probe", exit 0 |
| Host probe | `tool/ci/host_probe.sh file:///home/user/jet-cad e6a1d0671672ec8b16ecd93e61a58b4eb2724343` exits 0, with "40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu", No issues, and "build/web is 42M" |
| Old host probe | `tool/ci/old_host_probe.sh v0.3.0` exits 0: "v0.3.0's main.dart analyses against e6a1d06…" |

## Mutants, in one table

| # | Mutant | Result |
|---|---|---|
| MF1 | `designChanges` without the disposed check | **red**: DC18, DC19 |
| (pre-fix) | `ec4956b`'s picker | **red**: PA1–3, two of three in each of 3 runs |
| MF2a | doubles through `contains`, storage read kept | **survived**: JIT inlining, as explained in F-2 |
| MF2b | `world.x`/`world.y` getters | **red**: PA1–3 |
| SC20-m | `test_flags` line dropped from `ci.yml` | **red**: SC20 |
| (CI) | the planner file run without the flag | **red**: `expect_failures` exit 1, "skipped for want of the VM service" |
| MF3 | the demo reads the first match | **red**: DE10 |
| R19 | the moved details lose their data | **red**: VE18 |
| D01 | the demo restores on `PlanReplaced` whatever the mode | **red**: DE9 |
| R17 | `screen: _lastScreen` | **survived**: equivalent, as explained in F-6 |
| R17b | slop measured from the up | **red**: SE16 |
| R17c | R17, with `_lastScreen` following moves within the slop | **red**: SE16 |

Each mutant was applied to the source file, run, then restored from a copy
and checked with `cmp`.
