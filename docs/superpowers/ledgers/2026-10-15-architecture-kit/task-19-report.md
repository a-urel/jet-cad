# Task 19 report: the Room tool and its notice

Status: DONE_WITH_CONCERNS (all gates green; concerns are TT6's cost and a cascade in the integration harness that predates this task, below).

Commit: `0d8a72c5 feat(kit-architecture): the Room tool and its notice` (on 3746c3ed).

## Implementation summary

- `packages/jet_cad_2d_kit_architecture/lib/src/room/room_tool.dart` (new). This is a port of `jet_cad_floor_plan/lib/src/parametric/room_tool.dart:1-443` with the brief's Step 5 changes:
  - header and imports;
  - `kRoomNameText`, `kRoomOccupiedText`, `RoomOccupied.text`;
  - `RoomTool(inputs, {words, live}) implements ToolNotice`;
  - `occupied` (today's `notice`, renamed) and `notice` (`ValueListenable<KitText?>`), set together by `_setOccupied`;
  - `_nextName` over `numberedNameIndex`, with `_namePatterns`: the words of the moment first, then each of the kit's locales;
  - `_liveRooms`;
  - `cancel` and `dispose` changed as the brief says. Both notifiers are disposed with the tool.
- Beyond the brief (FREEZE RULE): the tool memoises the room that occupies the cached face. Rooms are not `RoomInputs` inputs, so freezing a room does not move `inputs.generation`.
  - New field `Handle? _occupiedBy`, set in `_cacheFace` and cleared with the other caches.
  - Each time the cached face is reused, `_verdictAt` re-checks `live(_occupiedBy) == ArchitectureTypes.room`. If the room is no longer live, it re-runs `_cacheFace(face)`. The cost is one `live` call per reuse.
  - The class doc says so.
  - Wall and separator freezes were already covered: the tool reads `inputs.generation` once per pointer event, and that read re-checks liveness (Task 16's `_dropFrozen`).
- `room_plan.dart`: adds `roomPlanTool` (M, `Icons.meeting_room_outlined`, structure + components + geometry). The header's last sentence now ends "The Room tool is [roomPlanTool]."
- `kit.dart`: `roomPlanTool` is placed right before `separatorPlanTool`.

## TDD evidence

RED, kit (tests written first, no lib file), from `flutter test test/room/room_tool_test.dart`:

```
test/room/room_tool_test.dart:28:8: Error: Error when reading 'lib/src/room/room_tool.dart': No such file or directory
test/room/room_tool_test.dart:37:17: Error: Type 'RoomTool' not found.
test/room/room_tool_test.dart:59:16: Error: Undefined name 'roomPlanTool'.
```

GREEN, kit: `00:07 +14: All tests passed!`. That is 14 cases: TT1 (the tool), TT2-TT6, TT8, TT9, RT-notice, RT-words, RT-tool, RT-frozen-wall, RT-frozen-room.

Integration: `00:02 +4: All tests passed!` (TT1 (the editor), TT7, SG1, RT-notice-locale).
- **Deviation:** I wrote the integration file after the lib, so it passed on its first run and has no real RED run of its own.
- Its RED evidence comes from mutations M-RT-1, M-RT-2, M-RT-3, M-RT-8 and M-RT-11 below. Each one turns integration cases red against committed code.

## TT6 (cost test, ported as written, not asserted)

Both runs on this machine, same session.

| | median per Unbounded hover | first hover (builds contours) |
|---|---|---|
| Old line (`jet_cad_floor_plan`, `--plain-name TT6`), 600 free walls | 19.2 us | 28192 us |
| Old line, connected 636-wall plan | 12.3 us | 8007 us |
| Kit, 600 free walls | 137.5 us | 30570 us |
| Kit, connected 636-wall plan | 147.5 us | 8084 us |

In the full-file kit run the same lines printed 126.2 us / 5750 us and 136.6 us / 6666 us.

**Concern:**
- A steady Unbounded hover costs about 7-12x what it did. The reason is `RoomInputs`' O(n) liveness re-check from Task 16: each hover reads `inputs.generation` and then `inputs.bounds`, and each read runs `_dropFrozen`, so that is two O(n) passes of `liveTypeIdOf` at n ≈ 600.
- It is still far under a frame, and no budget was loosened.
- An option for the controller: let `bounds` skip its `_dropFrozen` when `generation` already ran it in the same event. That is Task 16's file, so I left it alone.

## Gates (after the commit)

- **Kit** (`packages/jet_cad_2d_kit_architecture`):
  - `flutter test`: `00:18 +269: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - `dart format --output=none --set-exit-if-changed .`: `Formatted 88 files (0 changed)`, exit 0
  - `dart pub publish --dry-run`: `Package has 0 warnings.` Before the commit it showed 1 warning, "2 checked-in files are modified in git".
- **Integration** (`packages/jet_cad_2d_integration`):
  - `flutter test --enable-vmservice`: `00:11 +77: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - format: `Formatted 27 files (0 changed)`, exit 0
- **Repo root:** `dart run tool/ci/check_kit_deps.dart` printed `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0.
- `git status --short`: clean after the commit. No `analysis_options.yaml` was touched.

## Mutation results

All run on committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet` confirmed the revert every time.

- **M-RT-1** (`RoomOccupied.text`: `{'name': name}` → `{'n': name}`)
  - Kit, RT-notice red: `Expected: KitText:<KitText(text:architecture.room-occupied, {name: Pantry})>`
  - Integration: TT1 (the editor), TT7 and RT-notice-locale are red, with `Actual: 'Room — Already a room: {name}'`. SG1 also goes red, as a cascade (see concerns).
- **M-RT-2** (delete `_notice.value = room?.text;`)
  - Kit, RT-notice red (same Expected).
  - Integration: TT1 (the editor) red, `Actual: 'Room'`. TT7 and RT-notice-locale are also red; SG1 cascades.
- **M-RT-3** (the notice built as `KitText(words.text(...))`, so its words are fixed when the notice is set)
  - Kit, RT-notice red.
  - Integration: RT-notice-locale red, but at its id check (`Expected: 'text:architecture.room-occupied'`, `Actual: 'Already a room: Kitchen'`), not at the German line the brief predicted. The case fails before it reaches the locale loop.
- **M-RT-4** (delete the first `_namePatterns` element): RT-words red, `Expected: 'Space 3'` / `Actual: 'Space 1'`.
- **M-RT-5** (delete `_namePatterns`' `for` element): RT-words red (`'Space 3'` / `'Space 2'`) and TT4b red (`'Raum 3'` / `'Raum 1'`).
- **M-RT-6** (`room_inputs.dart` `_refresh`: walls taken from `withComponent<WallParams>()`, so the frozen partition counts): RT-frozen-wall red, `the preview: the whole box: corner 1 (7900.0, 100.0) off by 4949.999999998027`. The preview is the left face.
- **M-RT-8** (`letter: 'M'` → `'Q'`):
  - Kit, RT-tool red: `Expected: 'M'` / `Actual: 'Q'`.
  - Integration: TT1 (the editor), TT7 and RT-notice-locale are red, with `Actual: 'Select'` (M activates nothing).
- **M-RT-9** (`roomPlanTool` moved after `separatorPlanTool`): RT-tool red, `Expected: <4>` / `Actual: <6>`.
- **M-RT-11** (delete `_setOccupied(null);` in `cancel`):
  - Kit, RT-notice red: `Expected: null` / `Actual: KitText:<KitText(text:architecture.room-occupied, {name: Pantry})>`.
  - Integration: TT7 red, `Actual: 'Room — Already a room: Kitchen'` after M again. SG1 and RT-notice-locale cascade.
- **M-RT-12 (new, FREEZE RULE, wall memo)** (`room_inputs.dart`: delete `_dropFrozen();` from the `generation` getter, which is the per-event liveness check the tool's memos rely on)
  - RT-frozen-wall red at its first-reader step: `the first hover after the freeze: the whole box: corner 1 (7900.0, 100.0) off by 4949.999999998027`.
  - With the face step temporarily cut from the test (uncommitted, reverted), the band-memo step alone is also red: `Bad state: No element` (an empty preview).
- **M-RT-13 (new, FREEZE RULE, occupied-room memo)** (delete the `_occupiedBy` re-check line in `_verdictAt`): RT-frozen-room red, `Expected: null` / `Actual: RoomOccupied:<RoomOccupied(Pantry)>`.
- M-RT-7 and M-RT-10 belong to Task 20 (TT10).

## Ported-test accounting (`jet_cad_floor_plan/test/room_tool_test.dart`)

| Old case | New case | Where | Change class |
|---|---|---|---|
| TT1 tool half (:225-260) | TT1 ... (the tool) | kit | `test` (not `testWidgets`), name gains " (the tool)"; `.notice` → `.occupied` (rename); rig over FakePlanServices (fixture) |
| TT1 shell half (:262-288) | TT1 ... (the editor) | integration | PlannerShell → PlanEditor (`pumpEditor` with centre/scale: fixture), `Key('tool-room')` → `Key('tool-architecture.room')` (id) |
| TT2, TT3, TT4, TT4b, TT5, TT6, TT8, TT9 | same names | kit | `.notice` → `.occupied`; TT4b `strings:` → `locale:`; rig and `rooms` per the brief (fixture) |
| TT7 | TT7 | integration | `shellSamplePlan` + `addRoom` → `sampleRoomPlan(rooms:)`; `screenOf` → `globalAt`; `shellRoomTool(tester).notice.value` → `plan.c.toolNotice.value` (widget form) |
| SG1 | SG1 | integration | `buildPlan`/`pumpPlan` → `roomPlan`/`pumpEditor`; the tap through `globalAt` (fixture) |
| TT10 | (Task 20) | — | moved, needs the dimension |

No assertion was changed. `grep -c "m²"` gives 11 in the kit file: 10 in the ported cases' source ranges plus the header's 1. `grep -c "—"` in the integration file gives 9, as the brief expects.

## New cases

- RT-notice, RT-words, RT-tool: as in the brief.
- RT-frozen-wall: the brief's case, plus a first-reader part.
  - On a plan with an empty, mutable frozen set, the tool hovers the left face and memoises it.
  - The partition then freezes (the undo depth is checked unchanged: no document change).
  - The very next hover at the same point previews the whole box, and the click makes "Room 1 / 29.64 m²" whose tint is that preview.
  - A second plan does the same through the band memo: the hover in the partition's band is memoised with the trace count unchanged, then the freeze, then the next hover in that band shows the whole box.
- RT-frozen-room (new, not in the brief): the occupied-room memo.
  - The tool hovers the face that Pantry occupies.
  - Pantry freezes (no document change), and the next hover reads `occupied` null with the whole-box preview.
  - The click makes Room 1 (29.64 m²), and the control `occupied == RoomOccupied('Room 1')` holds.
  - M-RT-13 pins it.

## Deviations

1. `_liveRooms` is `liveObjectsOf<RoomParams>(doc, live, ArchitectureTypes.room)`, not the brief's hand-written comprehension. The dispatch notes say "Use `liveObjectsOf` (live.dart), never re-write it". The behaviour is identical.
2. I added the `_occupiedBy` re-check, RT-frozen-room and M-RT-12/M-RT-13 for the FREEZE RULE, as the dispatch asked. The brief did not cover the occupied-room memo.
3. I added the first-reader steps to RT-frozen-wall. The brief's version had only the frozen-from-start premise.
4. The integration file had no standalone RED run (see TDD evidence).
5. I re-wrapped the two doc lines the brief's text substitution made longer than 80 characters.

## Concerns

- **TT6's cost** (above): a steady hover is about 7-12x slower because of two O(n) liveness passes per hover.
- **Cascade in the integration harness:**
  - When TT1 (the editor) or TT7 fails, later widget tests in the same file (SG1, RT-notice-locale) fail with `A DiagnosticsLog was used after being disposed`. The stack runs from `GuardedTool._cancelInner` through `_InteractionLayerState.deactivate`.
  - The cause is that the failed test's controller is disposed at tear-down while its widget tree is still mounted.
  - SG1 passes alone under the same mutation. This affects only failure output and comes from the shared rig's `addTearDown(c.dispose)` order, not from this task's code.
- **Locale switch:** RT-notice-locale re-pumps `planEditorApp` with the new locale, then pumps one more frame. Two frames were enough in every run, and nothing asserts on the same frame.
