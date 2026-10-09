# Plan — host embedding API, Slice 2: events and host data (schema 9)

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
revision 3 (`4f5c8fc`) as amended during Slice 1 (last at `98c0c1d`):
the principles P-1 to P-9 and **Slice 2** (E-1 to E-9), the Invariants,
the named mutants M-H20 to M-H29, the Risks R-3, R-5, R-6. The human
answered Q-H1 (**schema 9**) and Q-H2 (**double tap without delay**).
The points this plan found the code to contradict, or to leave open,
are under [Spec points to settle](#spec-points-to-settle); none changes
the design silently.

**Started** on the human's *"tamam, Dilim 2 ile devam et"* (2026-10-09),
after Slice 1 merged into `main` at `1b32e0a`. Slice 2 closes the zone
spec's Q-Z4: D21's "component carrying the table's id" becomes real.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `672ae52`
(`1b32e0a` plus its docs commit), plus this plan's commit.

**Ledger:** `.superpowers/sdd/2026-10-09-host-embedding-api/`: this
slice's briefs, reports and reviews as `s2-task-<n>-report.md` /
`s2-task-<n>-review.md`, beside Slice 1's archived ones.

## Global constraints

- `CLAUDE.md`'s non-negotiables. **The two allocation invariants**
  (`query_allocation_test`, `paint_allocation_test`), the floor-plan
  painters' counter tests, `RenderFloorPlanOverlays`' counter test **and
  every image golden stay untouched** (invariant 7). The engine
  (`jet_cad_2d`) is edited **only** in Task 1 (`kSchemaVersion`);
  `jet_cad_2d_flutter` **only** in Task 4 (`ToolPointerEvent.timeStamp`).
- **P-1 and P-6:** no existing signature, `==`, `hashCode` or `toString`
  changes; every new parameter is named and optional with today's
  behaviour as its default. **Existing tests pass unedited**, with these
  named exceptions and nothing else:
  - **Task 1, what schema 9 forces**, exactly:
    - `packages/jet_cad_2d/test/codec/json_codec_test.dart`: the test at
      `:513-528` ("the schema version is 8, …": its name, its comment,
      `expect(kSchemaVersion, 8)` at `:517`) and QF3's closing pins at
      `:585-589` (comment, `expect(kSchemaVersion, 8)`, the encoded
      `'schemaVersion'` 8);
    - `test/codec/instance_style_codec_test.dart:79-83` ("the schema this
      build writes is 8");
    - `test/codec/page_component_roundtrip_test.dart:83-89` (Q0-C1 "this
      build writes schema 8", both pins);
    - `test/document/layer_header_test.dart:98-106` ("this build writes
      schema 8, reads 7, …": name, comment, both pins; its literal-7 read
      stays a v7 read);
    - `test/testing/generate_document_test.dart`: **comments only**, at
      `:66-68` and `:255-257` ("kSchemaVersion 8 to 9; owed on macOS");
      the expected values at `:69-72` and `:257-260` are not touched;
    - the four committed v8 encodings, re-encoded by their own
      generators (below), whose byte-pin tests then pass unedited.

    Each re-pinned test keeps its wording but for the number; Q0's Task 1
    did the same at 7 → 8 (`docs/superpowers/ledgers/2026-10-07-decimal-separator/task-1-report.md`).
  - **Task 3:** `test/host/barrel_test.dart`'s B1 gains the five new
    names, as Slice 1's tasks did.

  Any other test that has to change is a finding for the task's report.
- **No widened record.** `ServiceCallbacks`
  (`service/table_select_tool.dart:24-30`) is built as a five-field
  literal by `test/service/table_select_tool_test.dart:68-75`; a sixth
  field would force that test to change. Slice 2's view events travel in
  a **new** internal record (`ServiceEvents`, Task 4) behind a new
  optional constructor parameter, as `options` and `userCamera` were
  added. `ToolPointerEvent.timeStamp` is optional for the same reason:
  about twenty test sites construct the event
  (`grep -rn "ToolPointerEvent(" packages apps`).
- **The standing sets stay exactly as they are:** engine 2, render 7 plus
  1 skip (`tool/ci/standing_failures.txt`, `standing_skips.txt`), compared
  by the path form, as CI does (`.github/workflows/ci.yml:64-68`):
  `dart run tool/ci/expect_failures.dart --package packages/<pkg> --root packages/<pkg> <run.json>`,
  the run from `test --file-reporter json:<run.json>`. Task 1 says why
  schema 9 leaves the engine's pair standing.
- **Every task ends green** in every package it touches and every package
  whose tests read what it changed:
  - `packages/jet_cad_floor_plan`, `apps/restaurant_demo`,
    `apps/floor_planner`: `flutter test`, `flutter analyze`, format;
  - `packages/jet_cad_2d` (`dart test`, `dart analyze --fatal-infos`,
    format) and `packages/jet_cad_2d_flutter` (`flutter test`): through
    the standing comparison; `flutter analyze` and format where edited;
  - `packages/jet_cad_restaurant_symbols` and `packages/jet_cad_2d_gpu`
    where named (Tasks 1 and 4);
  - `tool/ci`: `dart test`, analyze, format and `check_guide` whenever the
    guide or the probe moves (Task 5).
- **Flutter** is `/root/sdk/flutter/bin` (not on `PATH`), run with
  `CI=true`.
- **Fixtures** (spec's testing rule; CLAUDE.md's testing bar). Reuse
  Slice 1's `test/host/embedding_fixture.dart` (`embeddingPlanJson`,
  `embeddingTables`, `embeddingCamera`, `canvasOf`): the off-base box,
  tables turned 30°, mirrored at exactly 90°, scaled (1.5, 0.8), turned
  180°, all 40 m off the origin; `5` on the hidden layer, `L` on the
  locked one; `7` and ` 7 ` sharing a number 3 m apart; an unnumbered
  table; `9` with no finite corner; the camera at 0.37 px/mm, panned.
  Data written in tests is **not** the default shape: several keys
  inserted out of order (`zeta`, `id`, `alpha`), a value with a space, a
  dot and a non-ASCII letter, a key of exactly 64 characters, a value of
  exactly 1024 units. Event tests compute their expected world points and
  centres by the forward transform (`canvasOf`, the placement), never from
  the code under test; doubles `closeTo` 1e-12 relative (world) or 1e-6
  px (screen). **Timestamps are explicit:** `flutter_test` stamps every
  synthetic pointer event `Duration.zero` unless told otherwise
  (`flutter_test/lib/src/test_pointer.dart:126, 160, 194`), so two
  `tester.tap`s on one table are a double tap whatever is pumped between
  them; every double-tap test drives a `TestGesture` with `timeStamp:`
  and pumps the fake clock **differently** from the stamps.
- **Each named mutant is applied, seen red and reverted**, its killer
  named in the report (Ruling 49/50). Every mutant below belongs to
  exactly one task.
- **Never `git checkout` a file to revert it.** Copy it aside, or use
  `git show HEAD:path > path`.
- **Never commit an `analysis_options.yaml`.** Check `git status` before
  each commit.
- New public names enter `lib/jet_cad_floor_plan.dart`'s `show` lists and
  `test/host/barrel_test.dart` in the task that adds them; P-9's prefix
  and `final class` with `==`/`hashCode`/`toString` for value types. The
  table-data component stays internal: no handle and no component type
  crosses the host barrel (invariant 5).

## Tasks

### Task 1 — schema 9 (E-9)

**Verified:**
- `kSchemaVersion = 8` at `packages/jet_cad_2d/lib/src/codec/schema_version.dart:38`,
  its history at `:1-37`; `SchemaVersionError.toString` names the found
  version and the build's (`:40-49`).
- The codec writes it first (`codec/json_codec.dart:38`) and refuses
  anything not an `int` in `1..kSchemaVersion` (`:105-108`). **There is no
  migration function:** an older document is read by the same code, each
  field defaulting when absent (the history's 4, 6, 7, 8). The empty
  8 → 9 migration is therefore the constant alone.
- `load` and the constructor already turn any decode error into
  `FormatException('Not a floor plan: $e')`
  (`host/floor_plan_controller.dart:208-215`, `:894-903`), so a 10 plan
  reads "Not a floor plan: SchemaVersionError: unsupported schemaVersion
  10 (this build writes 9)". Nothing to build; Task 1 pins it.
- The committed v8 encodings (`git grep -lE '"schemaVersion": ?8'`):
  `packages/jet_cad_floor_plan/assets/library/furniture.jetlib`,
  `packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib`,
  `apps/restaurant_demo/assets/plans/salon.json`, `teras.json`. Their
  byte pins: `test/symbols/furniture_library_test.dart:32-34`,
  `restaurant_library_test.dart:360-362` (RL1),
  `apps/restaurant_demo/test/sample_plans_test.dart:70-77`. The two
  `furniture_pre_09c.jetlib` fixtures declare 7 and stay v7 reads.
- `apps/floor_planner/test/document_open_test.dart:325` (`kSchemaVersion +
  1`) and `controller_test.dart:224` (9999) follow the constant; no test
  uses a literal 9 as "the future".
- **The standing pair moves with the bump but stays standing.** The
  engine's two standing failures are `generate_document_test.dart`'s
  fingerprints (`:39-72`, `:237-260`), an FNV-1a over the whole encoding
  (`:11-18`), which starts with `schemaVersion`: their true values move at
  9. They already fail on Linux: macOS values (Ruling 07-7, trig-dependent
  output) not re-baselined since schema 7 (comments `:61-68`, `:252-257`).
  So they keep failing and the standing set is unchanged; a comment
  records the shift and the macOS re-baseline stays owed, as at 7 and 8.
  None of the render package's standing entries (text ladders, the
  paint rig's skip) reads a document.

**Builds:**
- `kSchemaVersion = 9`, with a history entry in the style of 6–8 saying
  what E-9 says: no new field and nothing to default; the bump exists so
  that no terminal silently carries host links it cannot see or keep
  consistent (the `jetcad.table_data` component, Slice 2): a 0.3.0 build
  would keep the payload as preserve-unknown data but leave a deleted
  table's data orphaned (F-14). A schema-8 (and 7) plan opens unchanged.
- The forced pins above, re-pinned to 9, nothing else in those tests.
- The four encodings re-encoded at 9: `dart run
  tool/generate_furniture_library.dart` (in `packages/jet_cad_floor_plan`),
  `dart run tool/generate_restaurant_library.dart` (in
  `packages/jet_cad_restaurant_symbols`), `UPDATE_SAMPLES=1 flutter test
  test/sample_plans_test.dart` (in `apps/restaurant_demo`). The report
  shows each diff is the version line only (for the libraries:
  `git show HEAD:<f> | sed 's/"schemaVersion":8/"schemaVersion":9/' | cmp - <f>`).

**Tests** (engine: `test/codec/schema_9_test.dart`; planner:
`controller_test`, a new group): **M-H26a**, **M-H26b** (below); plain:
a 10 document is refused by the engine (`SchemaVersionError` whose
`found` is 10) and by `load` (`FormatException` whose message contains
`unsupported schemaVersion 10` and `this build writes 9`), the plan left
as it was; the service layout's format is untouched (its own version,
`host/service_layout.dart`).

**Gates:** engine (standing comparison, analyze, format); render and
`jet_cad_2d_gpu` through the standing comparison; planner, restaurant
symbols, demo, floor planner.

### Task 2 — host data on a table (E-6, E-7, E-9 gates 2 and 3)

**Verified:**
- Components register per type (`jet_cad_2d` `document/component.dart:106-116`);
  `registerAppComponents` (`parametric/catalog.dart:51-56`) is the one
  registration New, Open, the libraries and the controller use
  (`host/floor_plan_controller.dart:1005-1011`). `SeatingComponent`
  (`symbols/seating_component.dart`) is the pattern: `componentTypeId`,
  `register`, a validating constructor, `fromJson`, value `==`.
- A registered type's payload is **always** decoded by its factory and
  stored typed (`component.dart:273-292`, `:289`); preserve-unknown
  (`:207-210`, `:283-287`) holds only types with no factory, and
  `loadJson` takes no diagnostics. A factory that throws fails the whole
  decode (`load` → `FormatException`).
- The controller and the floor planner discard decode's diagnostics
  (`floor_plan_controller.dart:1011`; `apps/floor_planner/lib/document_host.dart:488-492`).
  The planner's table diagnostics are `TableSurvey.diagnostics()`
  (`tables/table_index.dart:120-165`, codes `:168-173`), exported to
  editor code by `lib/editor.dart:71`.
- **Delete keeps components** (`commands.dart:410-434`: the inverse is
  `AddNodeCommand(node)`, the same handle). The editor's Delete is one
  `CompoundCommand` of the instance's owned leaves and its
  `RemoveNodeCommand` (`jet_cad_2d_flutter` `select_tool.dart:705-714`,
  `:733`), executed through the dispatcher, whose one `expander` wraps
  `execute` only, never `undo`/`redo` (`undo.dart:144-151`, `:190`).
- `TableLabelSystem` holds that slot over the parametric system
  (`tables/table_label_system.dart:25-50`); `TableLabelEdit.apply`
  (`:80-110`) applies the inner edit, then derived commands, rolls all
  back on a throw, and returns one replay of their inverses. It is
  installed **by the views**, not the controller: the editor's shell
  (`planner_shell.dart:739-740`) and the service view
  (`host/service_view.dart:165-167`). Every delete path is in the editor,
  so every delete passes it; the controller itself deletes nothing.
- `tableDetails` is cached by (active document, `stateId`, layers'
  `mutationRevision`) (`floor_plan_controller.dart:1100-1116`), so a data
  edit (a command) refreshes it; the details come from `_detailsOf`
  (`:1133-1155`) through `tableDetailOf` / `tableDetailWithoutGeometry`
  (`host/table_detail.dart:118-165`), whose `data` is the constructor's
  `const {}` default today (`:34`).
- The service copy is the design re-decoded with `registerAppComponents`
  (`_copyOf`, `:997-1003`), so it carries the data typed.
- "No control character" already has one meaning in the planner: a code
  unit below U+0020 or in U+007F–U+009F (`tables/table_numbers.dart:31-35`).

**Builds:**
- `lib/src/tables/table_data_component.dart`: `FloorPlanTableData
  implements Component`, `componentTypeId = 'jetcad.table_data'`,
  `register`, attached to the **instance** node. Payload
  `{"data": {key: value}}`, keys written sorted (`toJson`), immutable,
  value-equal. The limits as one function the constructor and the
  controller share: at most 32 keys; a key `^[a-z0-9_.-]{1,64}$`; a value
  at most 1024 UTF-16 units with no control character (the table
  numbers' rule above). The constructor throws `ArgumentError` outside
  them, and for an empty map (an empty map is no component).
  **`fromJson` never throws:** a payload of exactly that shape within the
  limits is the data (re-sorted on write: a hand-edited unsorted file is
  canonicalised); any other payload (over a limit, a non-string value,
  `data` missing or not a map, an extra key) is **kept verbatim**,
  written back as read, and reads as empty data (see
  [S-2](#spec-points-to-settle)).
- `registerAppComponents` registers it, after `SeatingComponent`.
- `TableSurvey.diagnostics()` gains `TableDiagnosticCodes.invalidData =
  'table.invalid_data'` (warning) per table whose payload is kept
  (see [S-3](#spec-points-to-settle)).
- **The delete expander:** `TableLabelEdit.apply`, after the inner edit,
  appends `SetComponentCommand<FloorPlanTableData>(h, null)` for every
  touched handle that no longer names a node and carries the component
  (a nested instance in a deleted group included), its inverse in the
  replay, so undo restores the data; the stamps' rollback covers it.
  The cheap path (`:46-48`) is unchanged: a plan with no servable
  definition has no table data.
- **The controller:**
  - `tableDetails` fills `data` from the instance's component (unmodifiable;
    empty when absent or kept); hidden, locked and non-candidate tables
    too. `tableDetailOf` and `tableDetailWithoutGeometry` take an optional
    `data`.
  - `bool setTableData(String number, Map<String, String> data)`: one
    design edit (label "Table data"), undoable. `StateError` in the
    selection mode (P-5). `ArgumentError` for data outside the limits,
    nothing changed. False, nothing changed, when the trimmed number names
    no table or more than one (an ambiguous link is refused). An empty map
    removes the component. Data equal to the current: true, no step. A
    hidden or locked table takes data (a link is not a drawing edit).
    `dirty` and `canUndo` read true on return (`_refreshFlags`);
    `revision` and `designChanges` move as for any edit.
  - `bool setTablesData(Map<String, Map<String, String>> byNumber)`: the
    same, **all or nothing**, one undo step (`CompoundCommand`): any
    invalid map throws first; any number unresolved, ambiguous, or two
    keys trimming to one number returns false; entries equal to the
    current are skipped; nothing to change is true with no step.
  - Renumbering keeps the data (it is the instance's); the service copy
    carries it read only (`setTableData` throws there).

**Tests** (`test/tables/table_data_test.dart` for the component, the
limits, the lenient read and the expander; `test/host/table_data_test.dart`
for the controller, on `embeddingPlanJson`): **M-H22, M-H23, M-H24,
M-H24b, M-H27, M-H28, M-H29(setTablesData)**. Plain: **E-9 gate 2** — a
9 plan with data on `1` (30°), `2` (mirrored) and `L` (locked) round-trips
through `designJson`/`load` byte for byte and `tableDetails` reads it back
on the same tables; the limits' boundaries (32 keys, a 64-character key, a
1024-unit value accepted; 33, 65, 1025, a `\u0085` refused); renumbering
`1` to `21` keeps its data; the service copy's `tableDetails` carries it;
undo and redo of `setTableData`; `dirty` after the call and after
`markSaved`. **E-9 gate 3** is M-H27's killer.

**Gates:** planner, demo, floor planner, restaurant symbols; engine and
render through the standing comparison.

### Task 3 — `designChanges` (E-5)

**Verified:**
- The controller hears each plan's edits, undos and redos on the
  dispatcher's `changes` stream (`_attach`, `floor_plan_controller.dart:1478-1491`),
  an **asynchronous** broadcast stream (`jet_cad_2d` `undo.dart:104-105`,
  `:112-116`); `onAfterMutate`, the synchronous hook, is the spatial
  index's one slot (`:110-133`) and is not for this.
- Layer edits are commands (`layers/layer_panel.dart:176-199`,
  `SetLayerCommand`), so a lock or a hide reaches the stream.
- A design replacement is `_replaceDesign` (`:925-948`, from `load` and
  `newPlan` only, in either mode); it detaches the old plan's
  subscription at once (`_drop` → `_Plan.detach`, `:1505-1514`, `:66-72`),
  so a change event still queued for the old design is never delivered.
- Service edits arrive on the service plan's own subscription; the
  design's never moves in the selection mode but by a replacement
  (`setTableData` throws there, Task 2).
- `_detailsOf` reads `_tables`, **the active plan's** survey (`:1142`),
  whatever document it is given; `tableDetailInstances` (`:1122-1126`)
  lists the instances index for index.
- `RemoveNodeCommand`'s inverse re-adds the same handle (`commands.dart:430`).

**Builds:**
- `lib/src/host/design_changes.dart`: `sealed class FloorPlanDesignChange`
  (const constructor) and the four `final class`es of E-5:
  `FloorPlanTableAdded(table)`, `FloorPlanTableRemoved(table)`,
  `FloorPlanTableChanged(before, after)` (each a `FloorPlanTableDetail`),
  `FloorPlanPlanReplaced()`; `const`, `==`, `hashCode`, `toString`.
  Exported; B1 gains the five names.
- `Stream<FloorPlanDesignChange> get designChanges`: a broadcast
  controller, closed in `dispose`. While it has a listener (`onListen` /
  `onCancel`) the controller keeps the design's last detail list and its
  instances as a baseline; each event on the **design** plan's
  subscription builds the design's list (the cached `tableDetails` when
  the design is active; `_detailsOf` gains the survey it reads, so the
  design's list is built from the design's own survey otherwise) and
  emits, in ascending instance order, `Added` / `Removed` for an instance
  only in one list and `Changed` where the details differ by `==`; then
  the new list is the baseline. Nothing is computed with no listener (a
  `@visibleForTesting` scan counter proves it).
- `_replaceDesign`: with a listener, first **flushes** the old design
  (its pending diff, synchronously, so an edit made just before a `load`
  is not lost), then emits `FloorPlanPlanReplaced` and takes the new
  design as the baseline, in either mode. Service plans never feed the
  diff.

**Tests** (`test/host/design_changes_test.dart`, on `embeddingPlanJson`;
a widget group with the design view mounted, so the shell's
`TableLabelSystem` runs): **M-H25, M-H29(service moves),
M-H29(PlanReplaced in the selection mode)**. Plain: one edit emitting
several changes in ascending instance order (a `setTablesData` on `1` and
` 7 `); a layer locked → one `Changed` per table on it (`locked` only); a
renumber → one `Changed` (number; data kept); `setTableData` → one
`Changed` (data only); `newPlan` → `FloorPlanPlanReplaced` only, no
`Removed` per table; an edit then `load` in one synchronous block →
the edit's change, then `FloorPlanPlanReplaced`; no scan with no listener
and none after the last cancel; the four classes' `==`, `hashCode`,
`toString`; a barrel test using them through the barrel alone.

**Gates:** planner, demo, floor planner; engine and render through the
standing comparison.

### Task 4 — view events (E-1 to E-4)

**Verified:**
- `ToolPointerEvent` carries no time (`jet_cad_2d_flutter`
  `lib/src/tool.dart:19-54`). `InteractionLayer` builds it in one place,
  `_event` (`interaction_layer.dart:171-190`), from `_wrap(e)`
  (`:167-168`) and from two explicit calls: a lift-mode finger's aiming
  hover (`:273-274`) and its tap's down at the lift's position
  (`:308-310`).
- A finger's down reaches a press tool late (`kTouchHoldBack`, `:34`):
  routed at the hold-back (`_routeHeld`, `:236-244`), on leaving the slop
  (`:266-268`) or at the lift (`:300-313`), always as `_wrap(held)`, the
  **raw down's** event. `TableSelectTool` is a press tool
  (`service/table_select_tool.dart:133`).
- Hover reaches the tool as `onPointerMove` with `buttons == 0` for every
  kind but touch (`_onHover`, `:418-430`; a touch hover is dropped at
  `:420`); `onPointerExit` on leaving the layer while nothing is pressed
  (`:439-442`), over an `InputClaim` (`:422-427`) and at a touch
  session's end (`_endSession`, `:340-346`). `TableSelectTool` ignores
  both today (`table_select_tool.dart:178-179`, `:418`).
- The tool's tap is `_tap` (`table_select_tool.dart:285-308`): a miss
  clears the selection unless a modifier is held (`:286-289`); a hit
  selects (not a locked one) and reports `onTableTap` for a numbered one, locked included,
  then `onGroupTap`. A modifier is Shift, Ctrl or Meta (`:157`). The drag
  is `_move` (`:373-384`): one `CompoundCommand` of the live moved
  instances (`_moving`, ascending, `:240-246`), then `onLayoutChanged`; a
  zero drag executes nothing. A long press, a pan and a locked drag spend
  the gesture: no tap.
- The view passes the callbacks and options as records read at each call
  (`host/floor_plan_view.dart:280-292`; R-5); `ServiceView` hands them to
  the tool (`host/service_view.dart:93-99`). Service Undo, Redo, reset and
  restore go through the controller (`service_view.dart:366-367, 383-386`;
  `floor_plan_controller.dart:982-993`, `:834-866`), never through `_move`.
- `kDoubleTapTimeout` is 300 ms and `kDoubleTapSlop` 100 logical px
  (`flutter/lib/src/gestures/constants.dart:35, 49`).

**Builds:**
- `jet_cad_2d_flutter`: `ToolPointerEvent({…, this.timeStamp =
  Duration.zero})` (`PointerEvent`'s own default), documented as the raw
  pointer event's time. `_event` takes it; `_wrap(e)` passes
  `e.timeStamp`; the lift-mode tap's down passes the held down's, the
  aiming hover the move's. A held finger keeps its raw down's stamp
  whenever it is routed. The CHANGELOG names it (Task 5).
- The planner's tool: `typedef ServiceEvents` (internal), read at each
  call (R-5), through a new optional `events` parameter on
  `TableSelectTool` and `ServiceView` (default: none):
  - **moved:** `_move`, after `onLayoutChanged`, reports the moved live
    instances; the service view maps them to the controller's fresh
    `tableDetails` through `tableDetailInstances` (handles stay inside)
    and calls `onTablesMoved` once, ascending by handle, numbered or not.
    Undo, Redo, reset and restore never reach `_move`.
  - **double tap:** on a tap that reports `onTableTap` (a numbered table,
    locked included) with no modifier, the tool keeps (instance, the
    down's `timeStamp`, the down's screen point). The next such tap on
    the **same instance** whose down is **at most** `kDoubleTapTimeout`
    after the kept one and **at most** `kDoubleTapSlop` from it fires
    `onTableDoubleTap(number)` after its own `onTableTap` (and
    `onGroupTap`), and the chain resets (a third tap starts anew). A
    modifier tap, a floor tap, a drag, a pan, a long press, a cancel, or
    a tap on another instance resets it (the last one becomes the kept
    tap). Nothing is delayed (Q-H2).
  - **floor tap:** a tap that misses every table calls
    `onFloorTap(Offset world)` (the down's world point, mm, y up)
    **after** the selection logic, modifier or not (see
    [S-4](#spec-points-to-settle)).
  - **hover:** with `onTableHover` given, a button-less move of any kind
    but touch picks at the point (no reach) and reports the number, or
    null over the floor or an unnumbered table, **only when it differs
    from the last reported**; `onPointerExit` reports null when the last
    was not. No pick without the callback. Nothing on unmount (see
    [S-5](#spec-points-to-settle)).
- `FloorPlanView`: `onTablesMoved`, `onTableDoubleTap`, `onFloorTap`,
  `onTableHover`, documented with E-1 to E-4's sentences, read at each
  call.

**Tests** (render: beside `interaction_layer_test.dart` and
`interaction_layer_touch_test.dart`; planner:
`test/service/service_events_test.dart` at the tool, with explicit
`ToolPointerEvent`s, and `test/host/view_events_test.dart` through
`FloorPlanView` on `embeddingPlanJson` under `embeddingCamera()`):
**M-H20, M-H20b, M-H20c, M-H21, M-H21b, M-H29(hover per move),
M-H29(hover for touch)**. Plain (render): a mouse down's event carries the
`PointerDownEvent`'s stamp; a finger held past `kTouchHoldBack` and one
lifted before it both reach the tool with the raw down's stamp, not the
routing time; a lift-mode tap's down carries the held down's. Plain
(planner): both taps report `onTableTap` before `onTableDoubleTap`
(order log); a locked `L` reports a double tap; Shift on either tap
prevents it; `onFloorTap`'s world point equals the forward inverse of the
canvas point and the selection is already empty in the callback; a tap on
the unnumbered table reports neither tap nor floor; a stylus hover
reports; no callback given → today's behaviour, every existing
`view_test` reading as before.

**Gates:** planner, demo, floor planner; **`jet_cad_2d_flutter` in full**
(`flutter test` through the standing comparison, `flutter analyze`,
format); `jet_cad_2d_gpu` (`flutter test` through the standing
comparison, analyze); engine through the standing comparison.

### Task 5 — the demo, docs, CI and the exit (the controller's)

- **Demo** (`apps/restaurant_demo`), a proposal of the smallest real use
  of every addition (P-7); strings in en, de, tr (`lib/demo_strings.dart`):
  - Edit mode: **"Link tables"** (`setTablesData`): each numbered table
    without `data['id']`, its number not duplicated (a duplicate is
    refused, `numberingWarnings`), gets `id = <area>-<number>`, one undo
    step; beside it **"Unlinked: n"**, E-8's recipe by id.
  - Service: `onTableDoubleTap` logs "table 7 opened (id salon-7)" or
    "(no id)"; `onTablesMoved` logs the moved numbers; `onTableHover` and
    `onFloorTap` feed one status line ("over table 7", "floor at 41.2,
    −27.0 m"), not the log, so the existing tests' `demo.log.first`
    expectations (`test/demo_test.dart:99-116, 160, 288`) stay as they
    are; `designChanges` logs added and removed tables and a replaced
    plan.
  - Demo tests for each, double taps with explicit stamps; a saved plan
    declares schema 9 and keeps its ids across Save and Revert.
- **Host guide** (`docs/host-guide.md`), marked *Unreleased*:
  - a new section "Events and host data" after "Your own widgets on the
    tables" (`:497`): the four view callbacks (E-1 to E-4) with **R-3's
    warning** (a tap action runs on each tap of a double tap); host data
    (E-6: limits, the shape, delete, renumber, the selection mode's
    `StateError`, the lenient read); `designChanges` (E-5);
  - § 7's unplaced-tables recipe (`:470-495`) gains the id form (E-8);
  - **R-5:** data is the host's to validate (a plan loaded at another
    location carries the first one's ids);
  - **R-6:** a bullet beside § 11's schema 8 (`:950-954`), in bold:
    schema 9, refused by 0.3.0 and earlier, every terminal that shares
    stored plans moves together;
  - § 8's list (`:887-911`) names the four callbacks.
- **Host probe:** the guide's new snippets (a `designChanges` listener, a
  `setTableData`, the four callbacks, the id recipe) in
  `tool/ci/host_probe/lib/main.dart`; `check_guide` green; one mutant: an
  edited probe snippet makes `check_guide` exit 1.
- **CI, invariant 1:** unchanged: the host-probe job analyses v0.3.0's
  probe against the commit under test (`.github/workflows/ci.yml:160-161`,
  `tool/ci/old_host_probe.sh`). Schema 9 does not touch it: invariant 1
  is the API, and the probe is analysed, never run. Both probes analyse
  locally at the tip.
- **CHANGELOG** *Unreleased*: the intro's "Nothing is stored: plans and
  service layouts are the same as 0.3.0's (schema 8)"
  (`CHANGELOG.md:11-15`) rewritten for Slice 2; a heading **Breaking for
  stored plans: schema 9** in 0.2.0's form (`:155-159`); the new names;
  `ToolPointerEvent.timeStamp` for `jet_cad_2d_flutter`; the service
  layout format unchanged.
- **Results note** `docs/superpowers/notes/2026-10-09-embedding-slice-2-results.md`;
  **STATUS**; **the roadmap's row 14** (`roadmap/00-README.md:267`).
- **Every gate**, `tool/ci` included, with the standing comparison; both
  web builds; the host probe locally at the full SHA.
- **Web smoke check** in Chromium (Playwright, `locale: 'en-US'`): the
  demo's Salon; Link tables; Service; a double click on table 7 logs its
  id; a drag logs the moved numbers; the mouse over a table and over the
  floor updates the status line; a single click still selects; no
  console error.

Then an independent code review of the whole range, its fixes, and the
merge on the human's word.

## Mutants per task

| Task | Mutants | Count |
|---|---|---|
| 1 | M-H26a, M-H26b | 2 |
| 2 | M-H22, M-H23, M-H24, M-H24b, M-H27, M-H28, M-H29(setTablesData) | 7 |
| 3 | M-H25, M-H29(service moves), M-H29(PlanReplaced in the selection mode) | 3 |
| 4 | M-H20, M-H20b, M-H20c, M-H21, M-H21b, M-H29(hover per move), M-H29(hover for touch) | 7 |
| 5 | the probe snippet (check_guide) | 1 |

Each mutant and its killer:

- **M-H26a** (E-9 gate 1): the codec still writes 8 (`kSchemaVersion`
  left at 8). Killers: the re-pinned engine tests; the four byte pins of
  the re-encoded files; a planner test that `designJson()` of the
  fixture declares 9.
- **M-H26b** (the migration gate): an 8 plan refused (the guard tightened
  to `version != kSchemaVersion`). Killers: an 8 document derived from
  this build's encoding of the fixture (version set to 8, through bytes)
  loads in the engine and through `FloorPlanController.load`, and saves to
  the original 9 bytes, drawing and all; the existing literal-7 reads
  (`layer_header_test`, Q0-C3) go red too.
- **M-H22:** `setTableData` on a duplicated number writes the first.
  Killer: `setTableData('7', …)` on the fixture (`7`, ` 7 `) returns false,
  neither carries data, `designJson()` unchanged, `canUndo` false.
- **M-H23:** `setTableData` allowed in the selection mode. Killer:
  `throwsStateError` there, `designJson()` and the copy's `tableDetails`
  unchanged.
- **M-H24:** keys written unsorted. Killer: data inserted as `zeta`, `id`,
  `alpha` reads in `designJson()` as the exact text
  `{"data":{"alpha":…,"id":…,"zeta":…}}` under `jetcad.table_data`.
- **M-H24b:** an empty map leaves an empty component. Killer:
  `setTableData('1', {})` after data → `designJson()` has no
  `jetcad.table_data` key at all.
- **M-H27** (E-9 gate 3): the expander does not detach on delete.
  Killer: the design view mounted, table `1` with data selected and
  deleted with the Delete key → `designJson()` has no `jetcad.table_data`
  for its handle; Undo → the `jetcad.table_data` section byte-equal to
  before the delete, the restored instance last among the root's
  children, and the whole encoding equal to before once every group's
  children are sorted (HD12); when the deleted table is its parent's last
  child, Undo → `designJson()` byte-equal to before, and so again after
  Redo and Undo (TD7). *Amended in Task 2's review (R-3):* strict byte
  equality cannot hold for a table that is not its parent's last child,
  because the engine re-appends an undeleted node (`AddNodeCommand`
  through `DocumentTree._link`, `jet_cad_2d/lib/src/document/tree.dart:557-570`),
  which predates Slice 2, changes nothing drawn (draw order is by handle),
  and is recorded as an engine follow-up beside the spec's O-8
  (`AddNodeCommand` restores the child's index).
- **M-H28:** an over-limit payload throws on load. Killer: a plan whose
  `1` carries 33 keys, `2` a key `Bad Key`, `3` a 1025-unit value, `4` a
  number value, `L` `data` as a list → `load` succeeds, each reads empty
  data, `designJson()` writes each payload back byte for byte,
  `tableDiagnostics` reports `table.invalid_data` on exactly those five.
- **M-H29(setTablesData):** writes part of a batch with one bad entry.
  Killers: `{'1': …, '7': …}` → false; `{'1': …, '2': {'Bad': 'x'}}` →
  `ArgumentError`; after each, `1` has no data and `canUndo` is false.
- **M-H25:** an undone delete reported as remove + add (a diff keyed by
  list index, number or value instead of instance). Killers: deleting `3`
  emits exactly `[Removed(3)]` and its undo exactly `[Added(3)]` equal to
  it, data included (an index diff reports `Changed` for every later
  table); a move of ` 7 ` is exactly one `Changed` whose `before` and
  `after` are that table's (a number or value diff reports remove + add,
  or mixes the two 7s).
- **M-H29(service moves):** the diff fed by the active plan. Killer: in
  the selection mode, a service drag of `1`, its Undo and a
  `resetLayout` emit nothing.
- **M-H29(PlanReplaced in the selection mode):** emitted only in the
  design mode. Killer: in the selection mode, `load(embeddingPlanJson())`
  emits exactly `[FloorPlanPlanReplaced()]`.
- **M-H20:** double tap on two different instances. Killer: at 0.025
  px/mm the two 7s (3 m apart) are 75 px apart; taps on `7` then ` 7 `,
  100 ms apart → two `onTableTap('7')`, no double tap (a mutant keyed by
  number fires).
- **M-H20b:** after `kDoubleTapTimeout`. Killer: second down stamped first
  + 301 ms → none; + 299 ms → one; the fake clock pumped 1 s between taps
  in the second case and 0 in the first (a clock-timed mutant inverts
  both).
- **M-H20c:** beyond `kDoubleTapSlop`. Killer: under `embeddingCamera()`
  table `4`'s box is about 296 × 222 px; a second down on it 101 px from
  the first → none; 99 px → one.
- **M-H21:** `onTablesMoved` fires on Undo. Killer: a drag → one call;
  then the bar's Undo, Redo, `resetLayout` and
  `restoreServiceLayout` → still one, while `serviceLayoutChanges` fires.
- **M-H21b:** two moved tables sharing a number, one lost (a map by
  number). Killer: `select({'7'})` selects both, a drag of one → a list
  of two details, both number `7`, ascending, each centre moved by the
  drag's world delta (forward transform).
- **M-H29(hover per move):** Killer: three button-less mouse moves inside
  `1` → `['1']`; on to the floor → `[…, null]`; back over `1` twice →
  one more `'1'`.
- **M-H29(hover for touch):** Killer: at the tool, a button-less move of
  kind touch over `1` reports nothing; through the view, a touch tap on
  `1` reports no hover.

## Exit gate

- Task 5 green: every gate, the standing sets exact, both web builds, the
  smoke check, the probe and v0.3.0's probe locally and in CI.
- Every named mutant above seen red and recorded.
- The independent review applied.
- **Owed to the human:** a look at the demo's double tap, hover line and
  Link tables on a tablet and a terminal; the German and Turkish read of
  the demo's new strings; the macOS re-baseline of the engine's two
  fingerprints (owed since schema 7, shifted again at 9).
- **Owed to Monépro:** D21 should name `FloorPlanTableDetail.data` and
  `setTableData` (Q-Z4 is answered); Q-H3's `data["id"]`; schema 9 moves
  every terminal at once (R-6).
- **The merge into `main` happens on the human's word**; a release is the
  human's call (P-8).

## Spec points to settle

Found while verifying the spec against the code at `672ae52`. Each has a
recommended resolution. **The controller ruled each as recommended**;
the spec records them (E-3, E-4, E-6, E-9 and its Review section).

- **S-1. E-9 gate 1's "the fingerprints' standing values moved and
  recorded" cannot be done here.** The fingerprints are standing failures
  because their expected values are macOS values (Ruling 07-7), not
  re-baselined since schema 7 (`generate_document_test.dart:61-68`,
  `:252-257`); a Linux container cannot compute them. *Recommended:* the
  standing set stays as it is (they keep failing, for the same reason); a
  comment records the 8 → 9 shift; the macOS re-baseline stays owed.
- **S-2. E-6's "kept as unknown data" cannot use the engine's
  preserve-unknown store.** A registered type's payload always goes
  through its factory (`component.dart:289`); only a type with no factory
  is kept as unknown, and a throwing factory refuses the whole plan
  (M-H28). *Recommended:* the planner's component keeps a payload outside
  the limits verbatim itself (written back as read, empty `data`); no
  engine change (the engine is touched only for the constant).
- **S-3. E-6's "reported as a `Diagnostic`" has no channel a host sees.**
  `loadJson` takes no diagnostics; the controller and the floor planner
  discard decode's (`floor_plan_controller.dart:1011`,
  `document_host.dart:488-492`); a new `NumberingWarning` subclass would
  break a host's exhaustive `switch` on that sealed class (P-1).
  *Recommended:* `TableSurvey.diagnostics()` raises
  `table.invalid_data` (editor code reads it through `tableDiagnostics`);
  no host API in Slice 2; the guide says such a table reads empty data.
- **S-4. E-3 with a modifier.** "After today's behaviour (the selection
  clears)", but a miss with Shift/Ctrl/Meta clears nothing
  (`table_select_tool.dart:288`). *Recommended:* `onFloorTap` fires on
  every tap that misses, modifier or not; the selection rule is today's.
- **S-5. E-4 when the view goes.** A mode switch, reset, restore or load
  remounts the service view (F-9) with the pointer still over a table;
  calling a host back during unmount is unsafe. *Recommended:* no null
  is sent then; the guide says a host clears its hover state when the
  mode or the plan changes.
- **S-6. Readings the plan pins with tests** (no design change, stated
  so a review can object): E-6's control characters are the table
  numbers' (U+0000–U+001F, U+007F–U+009F); a value may be empty; a valid
  but unsorted stored payload is re-sorted on the next save;
  `setTableData` with the current data is true with no undo step;
  `setTablesData` with two keys trimming to one number is false; a hidden
  or locked table takes data; E-2's timeout and slop are inclusive and
  measured between the two downs (screen pixels for the slop).
