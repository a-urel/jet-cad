# 3a final fix wave: report

The wave started at `945502cb` on `feat/architecture-kit` and ends at
`81950ac3`, 15 commits later. It was resumed once after an API rate-limit
cut-off at `53743d55`. The A1, A2 and B mutation evidence below was run and
recorded before the cut-off, in this same session. Nothing was re-run from
memory.

Every mutation below was run on committed code. Each went red and was
reverted with `git checkout -- <file>`, and `git diff --quiet` was confirmed
after each one (`REVERTED` printed). No ported assertion was weakened or
dropped. Scratch files were never committed.

## Status

DONE. 22 of 23 items are done. C8 is skipped, as an equivalent mutant (see
below).

## Items

### A. Code (behaviour)

**A1: one RoomInputs liveness pass per pointer event.** Done in `ddc44e76`
(fix(architecture)).

*Design.* `RoomInputs` gains a `beginEvent()`/`endEvent()` bracket and a
`debugLivenessPasses` counter. Inside a bracket, `_dropFrozen` runs at most
once, at the event's first read. `_dropFrozenAround` is skipped after that
pass, since the pass checked every held handle. `_refresh` counts as checked
because it rebuilds from live objects only. Outside a bracket every read
checks, as before.

*Why not the opening tool's tool-side `_bandsFresh` flag.* The liveness pass
runs inside RoomInputs' own readers, so a tool-side flag cannot skip it.
RoomInputs is also shared by the Room tool, the Separator tool and the
separator grips. A token that each event resets but nothing closes would
leave the grips (which open no event) skipping checks after the last tool
event. The explicit bracket is safe by default: a reader that opens none
pays the old cost.

*Where.* The Room tool brackets `hovered`, `accept` (via `_accept`) and
`_onDocumentChange`. The Separator tool brackets the trim in `hovered` and
in `accept`. All use `try`/`finally`.

*New pins.*
- RT-one-pass (kit `room_tool_test`): four steady-state hovers each make
  exactly one pass:
  - the same face, reused;
  - the right face, traced;
  - the band, traced;
  - the band, reused.
  Two reads outside an event make two passes.
- ST-one-pass (kit `separator_tool_test`): three hovers with a start
  pending and an end in the east wall's band, one pass each.

*Mutations.*
- **M-A1-reset**: `beginEvent` without `_checked = false`. The existing
  freeze test RT-frozen-wall goes red: `the first hover after the freeze:
  the whole box: corner 1 (7900.0, 100.0) off by 4949.999999998027`. Also
  red: RT-one-pass `Expected: <1> Actual: <0>` and ST-one-pass `Expected:
  <1> Actual: <0>`.
- **M-RT-14 / M-ST-1**: `_dropFrozen`'s skip removed (`if (_stale)
  return;`).
  - RT-one-pass: `Expected: <1> Actual: <2>`, reason `the same face,
    reused: one liveness pass for the hover`.
  - ST-one-pass: `Expected: <1> Actual: <3>`, reason `one liveness pass for
    the hover at [4506384.992848335,1205535.348827239]`.
- **M-RT-15**: `endEvent` leaves `_inEvent` true. RT-one-pass: `Expected:
  <2> Actual: <0>`, reason `two reads outside an event: two passes`.

**A2: a failing build or prepare is reported again on a later plan.** Done
in `017480eb` (fix(plan)).

*Choice.* Clear the entries rather than make the subjects plan-scoped.
`DiagnosticsLog.planScoped` is keyed by code, and `hookFailed` is the kit
set's code for every other hook, so making it plan-scoped would wrongly
drop those too. The log already has `removeWhere`, which exists "for a
problem that went away".

*Change.* A new `PlanController._forgetPreparesAndBuild()` removes
`hookFailed` entries with subject `prepare`, or kit `plan` and subject
`build`. `newPlan` runs it before `_prepare`, and `load` runs it after a
successful decode, before `_replace`. Load was included because a loaded
plan runs neither hook, so a stale entry would describe the replaced plan.

*New pin.* PB12 (`prepare_build_test`):
- A failing prepare and build in the constructor's plan.
- `newPlan(build: failing('second'))` gives one entry each, and they are
  the second plan's: the build's message is `'second'`, and the prepare's
  error is a new instance.
- A succeeding build and prepare leave none.
- A load after failing ones leaves none.

*Mutations.*
- **M-PB-17**: newPlan without the clear. `Expected: 'second' Actual:
  'first'`, reason `the current plan's build`.
- **M-PB-18**: load without the clear. `Expected: empty Actual: [`.
- **M-PB-19**: the clear drops the build entry only. `Expected: not same
  instance as BoomFailure:<BoomFailure(prepare)>`, reason `the current
  plan's prepare`.

**A3: room area memo doc.** Done in `53743d55` (docs). `room_plan.dart`'s
`roomAreaText` doc now states the limit. `notifyLoaded`/`notifyPurged` keep
`stateId`, so after an E3 rebuild a rewritten label can show stale until the
next command. It is display-only and rare. The memo is unchanged.
Comment-only, so there is no mutation.

### B. Docs and comments

All in `53743d55` (docs). Comment-only, so there are no mutations.

- **B1**: `docs/kits.md` §10.8, the prepare row now reads "the plan opens;
  what it added before the throw stays".
- **B2**: in `wall_bands.dart`, "Un-freezing comes with a document change
  (a reload or an undo)…" becomes "A frozen object stays frozen for its
  document's life; a new document resets the cache."
- **B3**: the kit's `test/support/catalog.dart` header lists today's order
  of registrations: box, wall, opening, separator, room, dimension.
- **B4**: the `planner_box_test.dart` header says the grid keeps the clicks
  on today's exact corners, but BX1-BX6 do not need it to pass. Probe, run
  this session: `snapToGrid: false` gives `00:02 +6: All tests passed!`,
  then reverted.
- **B5**: `separator_dashed_test.dart` names M-SP-8b for the open half
  (constructor json, `made: true`) and M-SP-8 for the load half.
- **B6**: `object_view_test.dart`'s M-PO-cov comment reads
  `LengthProperty<Object>`.
- **B7**: the PN2 comment in `dimension_panel_test.dart` now says the row
  is a DropdownButton and the panel issues nothing for an equal value.
- **B8**: `_referencesOf`'s filter is marked defensive. The engine refuses
  a reference to a non-live object first (DanglingReferenceError, spec 08
  D5).
- **B9**: the liveness-cost docs now read "O(cached objects)
  `liveTypeIdOf` calls, each over the catalog's types" in:
  - `wall_bands.dart` (two places)
  - `wall_faces.dart`
  - `room_inputs.dart`
  - `opening_tool.dart`
  - `dimension_grips.dart`

  `wall_tool.dart:190` and `dimension_tool.dart:138` were left alone: they
  speak of band-scan and layout costs, not liveness.

### C. Tests

**C1: TT7.** Done in `a1114f4c` (test(integration)). The test reads the Room
tool's own notice through `c.toolFor('architecture.room')! as ToolNotice`,
with a line-level ignore. A premise checks the notice is set before Esc,
and the test asserts it is null after Esc.
- **M-TT7**: `RoomTool.cancel` without `_setOccupied(null)`. Red: `Expected:
  null Actual: KitText:<KitText(text:architecture.room-occupied, {name:
  Kitchen})>`, reason `the tool's own notice cleared on deactivation`. The
  status `'Select'` line and the controller's `toolNotice` line stayed
  green, which confirms the old line was vacuous.

**C2: OT-frozen-host's delete half.** Done in `a1114f4c`.
- *Deviation, with evidence.* `deleteSelection()` alone does not set the
  hint. With the reset followed by `deleteSelection()` and the hint
  assertion, the test went red: `Expected: true Actual: <false>`, reason
  `the delete shows the hint`. The selection's gate refuses a locked object
  before any command runs.
- The brief's reference, the plan's FL-delete
  (`frozen_references_test:117-119`), asserts the hint after
  `deleteSelection()` **and** `c.execute(deleteOf(...))`. The case mirrors
  that: reset, then `deleteSelection()` false, then
  `c.execute(deleteLikeSelectTool(doc, a))` false, then the hint true.
- **M-OT-hint**: in `PlanController.execute`, `if (error is PlanLocked &&
  command is CompoundCommand) return false;` before `_refusal`. The edit's
  hint is still set, but the delete's is not. Red: `Expected: true Actual:
  <false>`, reason `the delete shows the hint`.
- Recorded for the human: should a refused `deleteSelection` of a locked
  object show the lock hint? It does not today, in the plan library.

**C3: DT-freeze split.** Done in `946b4cac` (test(kit)). The test is now
four tests: DT-freeze-wall, -neighbour, -click and -opening, with a shared
top-level `freezeRigOf`. `grep -c "expect("` is 30 before and after.
- **M-DT8**: the `_memoStillLive()` re-check in `DimensionTool._refresh`
  removed. `+3 -4`, all four red independently:
  - DT-freeze-wall: `A frozen: the hover`
  - DT-freeze-neighbour: `A frozen: B's points afresh`
  - DT-freeze-click: `A frozen: the click`
  - DT-freeze-opening: `the door frozen: no host`

**C4: DG-frozen.** Done in `81f9e247` (test(kit)). Before the points step,
the test fills a points memo with every wall's live points. It then asks
with C frozen at C's corner, and with S frozen at S's butt end, passing a
copy of that memo. A frozen wall in the candidate set would come back from
the memo instead of reaching the `!` in `_wallPointsOf`.
- **M-DG2**: red on `C frozen: no candidate, its points memoised`, with no
  null-check throw.
- **M-DG3**: red on `S frozen: no candidate through its door, its points
  memoised`.

**C5: P-choice-focus.** Done in `c39b9d57` (test(integration), plan and
integration files).
- *Esc step* (plan `property_panel_test`): inserted between the first and
  second choice. At the test's end it cannot work: the letter B arms the
  box tool, which clears the selection, so the row is gone (`Bad state: No
  element` when tried there).
  - Steps: open the menu, then Esc. The focus is the row's own
    `focusNode`, finish is still gloss, the undo depth is unchanged and the
    status is still `Select`. The later ported steps are unchanged and
    green.
  - **M-P-choice-esc**: the choice row's focus node hands back whenever it
    gains the focus (a listener at creation). Red: `Expected: same instance
    as PanelFieldFocusNode#…(property-finish) Actual:
    FocusNode#…(InteractionLayer [PRIMARY FOCUS])`, reason `Esc keeps the
    focus on the row: nothing handed back`.
- *Tool-settings scope* (integration `wall_section_test`,
  P-choice-focus-settings):
  - W, then `setting-justification`, then left. The menu shows left, there
    is no undo step, and the focus is back on the canvas. M switches to
    Room. W and two clicks draw a wall whose `WallParams.justification` is
    left.
  - `WallSettings` is not exported, so the integration package reads the
    row and the drawn wall instead.
  - **M-P-choice-focus**: `onChanged` without `_handBackAfterChoice`. Both
    tests go red on `the choice hands the focus back`: the plan's with
    Actual `PanelFieldFocusNode…(property-finish…)`, the integration one
    with `…(setting-justification…)`.

**C6: WR9.** Done in `2424d954` (test(kit)). It adds
`testCatalog().objectsOf<WallParams>(sample)` `hasLength(10)`: nine walls
and the column, per `sample_flat.dart`'s header. A first guess of 36 went
red with the actual list, which gave the count.
- **M-WR9**: `buildSampleFlat` returns at once. Red: `Expected: an object
  with length of <10> Actual: []`, reason `premise: the sample holds its
  live walls`. The diagnostics-empty line alone would have passed.

**C7: contract words.** Done in `d80ff0fa` (test(kit), contract package).
- KW-conf-foreign: an English-only `text:other.greeting` merged into the
  sample's names gives no problem. The control is the same text under
  `sample.`, which gives `[wordMissing, wordMissing]`.
- KW-fill-once: `fillText('{name} seats {n}', {'name': 'Table {n}', 'n':
  4})` gives `'Table {n} seats 4'`, and `{a}{b}` swapped gives `'{b}{a}'`.
- **M-KW-conf-foreign**: conformance's `if (id.startsWith('text:'))`
  without the kit test. Red: `Expected: empty Actual: [`.
- **M-KW-fill-once**: `fillText` as a fold of `replaceAll` per argument.
  Red: `Expected: 'Table {n} seats 4' Actual: 'Table 4 seats 4'`.

**C8: build words order.** SKIPPED, an equivalent mutant.
- A scratch test (`test/controller/zz_scratch_c8_test.dart`, deleted, never
  committed) built `PlanController(kits: [testKit(), PlanKit(id: 'prep',
  names: {'en': {'tool:test.slab': …}})])`.
- It printed `caught: KitSetError: Invalid argument(s) (kits): the kit set
  has 1 problem(s):` / `foreignWordId: prep: en: "tool:test.slab" is not
  under the kit "prep"`.
- Every word id is namespaced under its own kit (`category:<kit>/`,
  `tool|type|property|text:<kit>.`), and `validateKitSet` refuses a foreign
  one. So no two loaded kits' words can conflict, and `kits.reversed` in
  `_buildWords` cannot be observed. The host-first order is already pinned
  by M-PB-9.

**C9: FakePlanServices.dispose.** Done in `8c8599eb` (test(kit), contract
package). LS-fake-dispose checks that the camera and the symbols state
accept a listener before dispose, and `throwsFlutterError` after it.
- An index probe was tried and dropped: a second `SpatialIndex(doc)`
  constructs while the services' index lives, so it gave no premise.
- **M-LS-fake-dispose-camera** (drop `camera.dispose()`): red, `the camera
  disposed`.
- **M-LS-fake-dispose-state** (drop `_symbolsState.dispose()`): red, `the
  symbols state disposed`.

**C10: `_GuardedNotice` listen hooks.** Done in `5d27b59b` (test(plan)).
- `boomHooks` gains `noticeAdd` and `noticeRemove`, and `BoomNotice`'s
  `addListener`/`removeListener` check them. TK3, which iterates every
  hook, stays green.
- TN-guard-listen: a throwing add, called twice, is caught. After it the
  value is null and there is one `hookFailed` diagnostic. A throwing remove
  (after a working add), called twice, is caught. After it the value is
  null and there is one diagnostic.
- **M-TN-guard-add** (addListener's try/catch removed): red, `BoomFailure
  (noticeAdd)` thrown out of the test.
- **M-TN-guard-remove**: red, `BoomFailure(noticeRemove)` thrown.

### D. Integration hygiene

**D1: rig teardown order.** Done in `55aa1bb3` (test(integration)).
`pumpEditor` registers `addTearDown(() =>
tester.pumpWidget(const SizedBox.shrink()))` after the caller's
`addTearDown(c.dispose)`. Tear-downs run last-added first, so the editor
unmounts before the controller is disposed.
- *Proof* (scratch `test/zz_scratch/cascade_test.dart`, deleted, never
  committed). S1 fails on purpose (status `'Not the status'`). S2 presses M
  and expects `Room`. S3 presses S and expects `Separator`. All three use
  `roomPlan(boxWalls)` and `pumpEditor`.
  - Before the fix: `00:01 +0 -3: Some tests failed.` with `A
    DiagnosticsLog was used after being disposed.`, and S2 and S3 `[E]`.
  - After the fix: `00:01 +2 -1: Some tests failed.`, with only S1 red.
- Full integration suite after it: `00:53 +227: All tests passed!`

**D2: line-level ignores.** Done in `2bb541ee` (test(integration)).
- *Method.* I removed all 19 file-level `ignore_for_file:
  invalid_use_of_internal_member` and ran `flutter analyze test`. That gave
  51 warnings over 17 files.
- Two files had no internal read at all (`opening_paint_test`,
  `opening_tool_test`), and their ignore was dropped.
- 15 files with 1-5 reads took a line-level ignore on each read line: 30
  new.
- The two grip tests (`room_grips_test` 7, `opening_grips_test` 14) keep
  the file-level form.

| Count | At `945502cb` | After D2 | After D3 (final) |
|---|---|---|---|
| File-level ignores | 19 | 2 | 2 |
| Line-level ignores | 1 | 32 | 31 |

The 32 includes C1's. D3 removed `opening_support`'s `select`, which was a
read. `flutter analyze test`: `No issues found!`

**D3: helper duplicates.** Done in `bc8abbc6` (test(integration)).
- `editor_rig.dart` now holds the one copy of each:
  - `clickAt(tester, c, p, [dx, dy])`
  - `dragWorld(…, {pumps = 1})`
  - `undoKey(tester, {pumps = 2})`
  - `select` (`c.activeSelection`)
  - `centreCamera(…, yUp:)`

  `pumpEditor` and canvas_rig's `frameOn` both call `centreCamera`, with
  `yUp` false and true respectively.
- `wall_shell`, `room_plans` and `opening_support` lose their copies.
  `room_plans` and `opening_support` re-export the shared ones, and the
  wall tests import the rig directly.
- Call sites that differed only in pump count now pass it:
  - `room_grips_test`'s seven drags: `pumps: 2`
  - the two opening undos: `pumps: 1`
- `addSeparator` has one copy, `separator/separator_plans.dart`'s.
  `dimension_plans.dart` imports it and re-exports it for `plans.dart`.
- No `expect(` line changed: `git diff | grep -E "^[-+].*expect\("` printed
  nothing.
- Notes:
  - `wall_shell`'s undoKey used to pump between Z and meta-up. It now pumps
    twice after meta-up, and every wall test is green.
  - `opening_support`'s `select` read `c.selection` (@internal). The shared
    one reads the public `c.activeSelection`, which is the same object
    outside service.
  - `dimension_shell_test`'s own ctrl+Z `undoKey` is a different key and
    not in the brief, so it was left.
- Full integration suite: `00:54 +227: All tests passed!`

## Final gates (this run, at `bc8abbc6`, real last lines)

`git status --short`: empty before and after.
`git log --name-only --format= 945502cb..HEAD | grep -c analysis_options`:
`0`.

```
packages/jet_cad_2d_kit$ flutter test                       -> exit 0
00:06 +403: All tests passed!
$ flutter analyze                                           -> exit 0
No issues found! (ran in 3.0s)
$ dart format --output=none --set-exit-if-changed .         -> exit 0
Formatted 92 files (0 changed) in 0.10 seconds.

packages/jet_cad_2d_plan$ flutter test --enable-vmservice   -> exit 0
01:55 +1551: All tests passed!
$ flutter analyze                                           -> exit 0
No issues found! (ran in 3.5s)
$ dart format --output=none --set-exit-if-changed .         -> exit 0
Formatted 299 files (0 changed) in 0.73 seconds.
$ flutter test --enable-vmservice test/invariants
00:09 +15: All tests passed!

packages/jet_cad_2d_kit_architecture$ flutter test          -> exit 0
00:19 +655: All tests passed!
$ flutter analyze                                           -> exit 0
No issues found! (ran in 3.1s)
$ dart format --output=none --set-exit-if-changed .         -> exit 0
Formatted 136 files (0 changed) in 0.42 seconds.

packages/jet_cad_2d_integration$ flutter test --enable-vmservice -> exit 0
00:55 +227: All tests passed!
$ flutter analyze                                           -> exit 0
No issues found! (ran in 3.1s)
$ dart format --output=none --set-exit-if-changed .         -> exit 0
Formatted 79 files (0 changed) in 0.21 seconds.
$ flutter test --enable-vmservice test/invariants/paint_allocation_test.dart
00:00 +0: IA-alloc a rebuilt steady-state PlanCanvas frame over the sample flat allocates O(1) per flush, the kit loaded (M-IA-alloc)
00:00 +1: All tests passed!

repo root$ dart run tool/ci/check_kit_deps.dart             -> exit 0
kit dependencies: 2 package(s) checked, none names the plan library or another kit

packages/jet_cad_2d_kit$ dart pub publish --dry-run         -> exit 0
Total compressed archive size: 121 KB.
Package has 0 warnings.
packages/jet_cad_2d_plan$ dart pub publish --dry-run        -> exit 0
Total compressed archive size: 940 KB.
Package has 0 warnings.
packages/jet_cad_2d_kit_architecture$ dart pub publish --dry-run -> exit 0
Total compressed archive size: 539 KB.
Package has 0 warnings.
```

Count deltas against the results note's figures (400 / 1549 / 650 / 226):

| Package | Count | Added this wave |
|---|---|---|
| contract | 403 | +3: KW-fill-once, KW-conf-foreign, LS-fake-dispose |
| plan | 1551 | +2: PB12, TN-guard-listen |
| kit | 655 | +5: RT-one-pass, ST-one-pass, and DT-freeze going from 1 test to 4 |
| integration | 227 | +1: P-choice-focus-settings |

## Commits

- `ddc44e76` fix(architecture): one RoomInputs liveness pass per Room and
  Separator tool event
- `017480eb` fix(plan): a failed build or prepare is reported again on a
  later plan
- `53743d55` docs: comment and doc accuracy (3a final wave A3, B1-B9)
- `a1114f4c` test(integration): TT7 reads the Room tool's own notice;
  OT-frozen-host's delete half resets the hint
- `946b4cac` test(kit): DT-freeze split into four tests, one per freeze step
- `81f9e247` test(kit): DG-frozen probes the candidate set before any wall
  is laid out
- `c39b9d57` test(integration): P-choice-focus gains an Esc step and a
  tool-settings choice row
- `2424d954` test(kit): WR9's empty sample diagnostics paired with its ten
  live walls
- `d80ff0fa` test(kit): contract words: a foreign kit's text is not held to
  the locales; fillText fills once
- `8c8599eb` test(kit): FakePlanServices.dispose releases the camera and the
  symbols state
- `5d27b59b` test(plan): the notice guard catches a throwing addListener and
  removeListener
- `55aa1bb3` test(integration): the rig unmounts the editor before the
  controller is disposed
- `2bb541ee` test(integration): line-level internal-member ignores where a
  file has few reads
- `bc8abbc6` test(integration): one copy each of the rig's click, drag, undo
  and select helpers
- `81950ac3` docs: 3a results note, the final fix wave

## Results-note section appended

`docs/superpowers/notes/2026-10-15-architecture-kit-results.md` gained the
section `## Final fix wave`, committed in `81950ac3`. It lists:
- the items closed and C8's skip with its evidence;
- the gate table and the last lines above (contract 403, plan 1551, kit
  655, integration 227; plan invariants +15; IA-alloc +1;
  `check_kit_deps`; the three dry runs at 121 / 940 / 539 KB, 0 warnings);
- the 14 code and test commits.

No earlier figure in the note was changed.

## Concerns

1. C2: a refused `deleteSelection()` of a locked object does not set the
   lock hint, because the gate refuses before any command. The edit path
   and the delete command both do set it. This is existing plan-library
   behaviour, recorded rather than changed.
2. The commit kinds `test(plan)` (C10) and `test(integration)` for C5 are
   approximate:
   - C10 touches only the plan package's tests, and `test(plan)` is not in
     the brief's list.
   - C5's commit also carries the plan package's test.
