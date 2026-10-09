# Host embedding API, Slice 2: results

**Asked by the human:** *"tamam, Dilim 2 ile devam et"* (2026-10-09),
after Slice 1 merged; the merge on *"evet, main'e merge et"*.

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
revision 3, as amended during the slice: S-1 to S-6 (the plan's points,
ruled as it recommended), Task 4's four rulings in E-1 and E-4, the final
review's F-1 (nothing after `dispose`) and F-3 (an ambiguous number reads
no id); O-10 and O-11 recorded. The Review section lists them.

**Plan:** [2026-10-09-embedding-slice-2.md](../plans/2026-10-09-embedding-slice-2.md).

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `672ae52`
(Slice 1 merged). **Merged** into `main` on the human's *"evet, main'e
merge et"*.

**Process.** Each of Tasks 1–4 had a fresh implementer, then an
independent reviewer in its own clone, then its fixes. Task 5 (the demo,
the guide, the probe, the CHANGELOG, the gates) was delegated by the
controller and gated by it. An independent review of the whole range
closes the slice.

## What a host gets

- **Host data on a table** (E-6): `setTableData(number, data)` and
  `setTablesData(byNumber)` (one undo step, all or nothing) write a
  `Map<String, String>` to the table's instance, stored in the plan as
  `jetcad.table_data` with its keys sorted; `FloorPlanTableDetail.data`
  reads it. Limits on write (`ArgumentError`): 32 keys, keys
  `[a-z0-9_.-]{1,64}`, values up to 1024 UTF-16 units without a control
  character. `StateError` in the selection mode; false, nothing changed,
  for a number that names no table or more than one. A payload outside
  the limits on read is kept as read (re-encoded), reads as empty data,
  and raises `table.invalid_data` for editor code. Delete drops the data
  and undo restores it; renumbering keeps it; the service copy carries it
  read only. Q-Z4 is answered: a host stores its database id there.
- **`designChanges`** (E-5): a broadcast stream of
  `FloorPlanTableAdded`, `FloorPlanTableRemoved`,
  `FloorPlanTableChanged(before, after)` and `FloorPlanPlanReplaced`, by
  instance, in ascending order, after every design edit, undo or redo;
  asynchronous, one report per synchronous step; nothing on listen;
  nothing after `dispose`; service moves never reach it; a `load` or
  `newPlan` in either mode reports the old design's pending changes, then
  `FloorPlanPlanReplaced`. Computed only while listened to.
- **The view's events** (E-1 to E-4): `onTablesMoved` (every moved table's
  fresh detail, once per drag, after `onLayoutChanged`; not for undo,
  redo, reset or restore), `onTableDoubleTap` (same instance, within
  `kDoubleTapTimeout` and `kDoubleTapSlop` of the first down; **the
  single tap is not delayed**: both taps report `onTableTap` first),
  `onFloorTap(world)` (a miss, after the selection logic, modifier or
  not), `onTableHover` (mouse and stylus, on change only; nothing on a
  remount). `jet_cad_2d_flutter`'s `ToolPointerEvent` gains `timeStamp`,
  the raw pointer event's time, a held-back finger's included.
- **Schema 9** (E-9): every plan saved from now on declares 9; 0.3.0 and
  earlier refuse it; an 8 or 7 plan opens unchanged and saves as 9. The
  four committed encodings (two symbol libraries, two demo plans) were
  re-encoded, the version line only. The service layout is unchanged.
- **The demo:** in Design, *Link tables* writes `id = salon-7` and the like
  to every table whose number is its own, with *Unlinked: n* beside it
  (the guide's recipe by id); in Service, a double tap logs the table and
  its id, a drag logs the moved numbers, hover and a floor tap feed a
  pointer line, and the design's changes are logged.
- **The guide:** "Events and host data", § 7's recipe by id, § 8's list,
  § 11's schema 9 bullet in bold; every block in the host probe.

## The tasks

| Task | Commit | Review | Fixes |
|---|---|---|---|
| 1, schema 9 (E-9) | `14e6c7f` | **Approve with fixes**: the 8 → 9 fixture left stored fields at their defaults (4 survivors) | `a148b51`: a non-degenerate 8 fixture (header, translucent hidden and locked layers, raw data, text, an unknown component, an unknown key), all 6 mutants red |
| 2, host data (E-6, E-9 gates 2 and 3) | `2193fca` | **Approve with fixes**: a value's limit unpinned against characters; `~` unpinned; HD12 relaxed (O-10) accepted | `890656d`: UTF-16 units against characters, one shared `isControlCodeUnit`, M-H27's killer as pinned |
| 3, `designChanges` (E-5) | `69d56fc` | **Approve with fixes**: a selection-mode baseline, an edit before a mode switch and a failed load unpinned; the doc on listen and dispose | `49ad576`: DC15–DC17, the doc |
| 4, view events (E-1–E-4) | `cb62b8b` | **Approve with fixes**: read-at-each-call untested through the view; a group's double tap; a replaced copy; a hover allocated per table | `ec4956b`: VE14–VE17, SE14, the docs, a pick without a `Vector2` per table |
| 5, demo, guide, probe, CHANGELOG, O-10/O-11 | `ae34b19`, `7729ad5`, `c276271` | gated by the controller | — |
| the range `672ae52..ec4956b` | — | **Independent review: Approve with fixes**; no defect where the tasks meet; 10,314 gestures through `FloorPlanView` with 0.3.0's callbacks only, logs byte-identical on v0.3.0, `672ae52` and the tip; saved plans differ only in `schemaVersion` | `8f813b2` F-1 (nothing after `dispose`), `a78b728` F-2 (a pick allocates nothing per table, measured), `2f252ca` F-3 (an ambiguous number reads no id), `4016316` F-4–F-6 tests, `e6a1d06` F-7 the spec |

Per-task reports, reviews and fixes are archived in
[docs/superpowers/ledgers/2026-10-09-embedding-slice-2/](../ledgers/2026-10-09-embedding-slice-2/).

## Named mutants

Every named mutant of the plan went red, each with its killer recorded in
the task's report: Task 1's two (M-H26a, M-H26b), Task 2's seven (M-H22,
M-H23, M-H24, M-H24b, M-H27, M-H28, M-H29(setTablesData)), Task 3's three
(M-H25, M-H29(service moves), M-H29(PlanReplaced in the selection mode)),
Task 4's seven (M-H20, M-H20b, M-H20c, M-H21, M-H21b, M-H29(hover per
move), M-H29(hover for touch)), Task 5's probe mutant (`check_guide` exits
1). The reviews ran over 120 mutants of their own; every survivor is now
red or recorded as equivalent in the reviews, but two: the final review's
R17 (the slop from the first down's position, unobservable: a completed
tap's last point is its down's) and MF2a (doubles handed back to
`contains`, which the JIT inlines today; `containsAt` keeps the property
by structure), both in `s2-final-fixes.md`.

## Gates (at `e6a1d06`)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | 1258 tests; the standing failures and skips, exactly (the two fingerprints shift at 9 and stay standing, S-1). Analyze and format clean. |
| render `packages/jet_cad_2d_flutter` | 1379 tests (1374 at `672ae52`); the standing set exactly. Both allocation invariants green. |
| gpu `packages/jet_cad_2d_gpu` | 20 tests; the standing set exactly. |
| planner `packages/jet_cad_floor_plan` | **1599 passed** (1518 at `672ae52`), run with `--enable-vmservice` as CI now runs it, so the pick's allocation test (PA1–PA3) runs; analyze and format clean. |
| restaurant symbols | 97 passed. |
| demo `apps/restaurant_demo` | **57 passed** (47). |
| app `apps/floor_planner` | 212 passed. |
| `tool/ci` | **63 passed**; `check_guide`: all 32 code blocks are in the host probe. |
| host probe | exit 0 at `e6a1d06` by `file://`; v0.3.0's probe analyses against the tip (`old_host_probe.sh`). |
| web builds | both 42M from a clean `build/`, no `flutter_scene` assets. |
| CI on GitHub | green on every pushed commit through `e6a1d06`. |

**Smoke check** (Chromium, Playwright, `en-US`, the demo's web build):
*Link tables* took *Unlinked* from 11 to 0; a hover scan found all 11
tables on the pointer line, "over no table" over the floor; a floor click
showed its point in metres, not logged; a single click on 3 selected and
logged no "opened"; a double click on 7 logged "table 7 opened (id
salon-7)" after both "tapped 7"; a drag of 7 logged "moved {7}" after
"layout changed"; no console error.

**The pick's allocation** (F-2; the engine's `AllocationMeter`, 60 tables,
per 1,000 picks): about 120,000 boxed doubles before, in most JIT runs;
55–60 after, in every run, whatever the table count.

## Changed for a host or a contributor

- **CI** runs the planner's tests with `--enable-vmservice` (a
  `test_flags` matrix field, pinned by SC20); a plain local `flutter
  test` there shows the allocation test's three skips.
- **The demo's Revert in the service** restores the kept layout when
  `designChanges` reports the replaced plan, a microtask later than before.
- **`editor.dart`** gains `isControlCodeUnit` and
  `TableDiagnosticCodes.invalidData`.

## Found, not fixed

- **O-10:** an undone node removal re-appends the node at its parent's
  end, so `designJson()` after Delete then Undo differs in children order
  while `dirty` is false (engine, pre-existing; nothing draws differently).
- **O-11:** selecting a table whose corners are not finite trips a
  NaN-offset debug assertion in `SelectionOverlayPainter._paintGrips`;
  only a hand-edited or foreign file can reach it.
- **An engine timing test** (`draft_document_test`, extents cost) went
  red once on a loaded machine and green on its re-run; the engine had no
  diff.
- **The delete expander runs where a view is mounted** (the views install
  `TableLabelSystem`); every delete today is the editor's, so it holds.

## Owed

- **To the human:** a look at the demo's double tap, pointer line and
  *Link tables* on a tablet and a terminal; the German and Turkish read
  of the demo's new strings; the macOS re-baseline of the engine's two
  fingerprints (owed since 7, shifted again at 9).
- **To Monépro:** D21 can name `FloorPlanTableDetail.data` and
  `setTableData` (Q-Z4 is answered); Q-H3's `data["id"]`; **schema 9
  moves every terminal that shares stored plans at once** (R-6).
- **A release** carrying Slices 1 and 2 is the human's call; until then
  it is CHANGELOG *Unreleased*.
