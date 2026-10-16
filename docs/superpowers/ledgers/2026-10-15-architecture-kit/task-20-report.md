# Task 20 report: dimension geometry, attachment and parameters (3a C3.6, C1.5, C7)

Status: DONE. Commit `83d84672 feat(kit-architecture): dimension geometry, attachment and parameters (3a C3.6)` on `feat/architecture-kit` (parent `0d8a72c5`).

## Implementation summary

- `lib/src/dimension/dimension_geometry.dart`: lines 21-494 of today's file copied byte for byte. The only changes are the brief's header and the two relative imports (`../wall/wall.dart show wallJoin`, `../wall/wall_geometry.dart`).
- `lib/src/dimension/dimension_attach.dart`: ported with exactly the brief's changes:
  - the header lines and the imports;
  - `thickestWall(doc, LiveTypeOf live)` walks `withComponent<WallParams>()` and filters on `live(h) != ArchitectureTypes.wall`;
  - the `[live]` doc paragraph;
  - `attachCandidates(..., {required LiveTypeOf live, ...})` answers its three liveness questions through `live`;
  - `_wallPointsOf(doc, h, live)` calls `wallsInDocument(doc, h, live)`.
  - Everything else is unchanged. `diff` against the source shows only these hunks.
- `lib/src/dimension/dimension.dart`: ported with the header line, the brief's import block (`visibleForTesting` now from `package:flutter/foundation.dart` instead of `package:meta`) and `componentTypeId = ArchitectureTypes.dimension`. Everything else is unchanged.
- Barrel: `export 'src/dimension/dimension.dart' show AttachedEnd, DimEnd, DimKind, DimensionParams, FixedEnd, WallSide;` goes after the room's export.
- `test/support/catalog.dart` and `lib/src/type_naming.dart`: the dimension's registration is appended last in each, with its import.
- `test/support/dimension_fixture.dart`: ported with the header, the imports and the two `wallsInDocument(..., liveOf(doc))` lines (277, 452). `diff` shows nothing else.
- Eight test files ported to `test/dimension/`. The new `dimension_live_test.dart` holds DG-frozen and DG-id, verbatim from the brief, then `dart format`.
- TT10 is inserted into `test/room/room_tool_test.dart` after TT9 with three line changes: `.notice.value` becomes `.occupied.value` twice (source :996 and :1005), and `isLiveObject<DimensionParams>(doc, h)` becomes `testCatalog().names<DimensionParams>(doc, h)`.

### FREEZE RULE assessment

`dimension_attach.dart` keeps no cache or memo of its own:
- `thickestWall` and both rect queries call `live` on every read.
- `wallsInDocument` is the live-checked entry point.

Its only memo is the caller-owned `points` map (`Map<Handle, WallPoints>?`). In this task's code nothing passes one: only tests call it, and none passes `points`.
- A frozen wall still cannot be a candidate even with a stale memo, because the `walls` set is rebuilt through `live` on each call before the memo is consulted.
- However, a memoised six-points entry for a still-live wall was laid out among the neighbours live at memo time. If a neighbour freezes later, the memo would keep the old joined points, and freezing emits no document change.
- The memo owners are the Dimension tool's hover memo and `DimensionGrips`' per-drag memo (Tasks 21 and 22). They must drop the memo on a liveness change, not only on a document change. This is flagged for those tasks below.

## TDD evidence

Tests were written first (fixture, eight ports, live test, TT10). RED, `flutter test test/dimension/` (excerpt):
```
test/dimension/dimension_live_test.dart:18:8: Error: Error when reading 'lib/src/dimension/dimension.dart': No such file or directory
test/dimension/dimension_live_test.dart:19:8: Error: Error when reading 'lib/src/dimension/dimension_attach.dart': No such file or directory
test/support/dimension_fixture.dart:21:8: Error: Error when reading 'lib/src/dimension/dimension.dart': No such file or directory
```
RED, `flutter test test/room/room_tool_test.dart` (TT10 before the barrel export):
```
test/room/room_tool_test.dart:837:31: Error: 'DimensionParams' isn't a type.
test/room/room_tool_test.dart:839:31: Error: Method not found: 'FixedEnd'.
```
GREEN after the lib files: `flutter test test/dimension/ test/room/room_tool_test.dart` gives `00:09 +98: All tests passed!`.

## Gates (kit, `packages/jet_cad_2d_kit_architecture`)

- Precondition (HEAD 0d8a72c5): `00:19 +269: All tests passed!`, `No issues found!`.
- `flutter test`: `00:25 +353: All tests passed!`. That is 269 + 83 dimension tests (the cases expand over their placements) + TT10. AM5 printed `AM5 attach search per click, 612 walls: median 2509.0 us of [...] (JIT); candidates [EA/0/left, 5B2/0/right], 3 walls past the line test; thickestWall 785 us` (nothing is asserted on it).
- `flutter analyze`: `No issues found! (ran in 4.8s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 101 files (0 changed)`, exit 0.
- `dart pub publish --dry-run` (after the commit): `Package has 0 warnings.`
- Repository root, `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0.
- `git status --short` after the commit and after every mutation: empty.

## Mutation results

All mutations were run on committed files, each reverted with `git checkout --`, and each `git diff --quiet` exited 0.

| Mutation | Test | Red line |
|---|---|---|
| M-DG1 delete `if (live(h) != ArchitectureTypes.wall) continue;` in `thickestWall` | DG-frozen | `Expected: <100>  Actual: <200.0>  C frozen: S only` |
| M-DG2 first query `live(owner) == wall` → `get<WallParams>(owner) != null` | DG-frozen | `Null check operator used on a null value` (from `_wallPointsOf`'s `wallsInDocument(...)!`; the brief accepts either form) |
| M-DG3 `live(host) != wall` → `get<WallParams>(host) == null` | DG-frozen | `Null check operator used on a null value` (at the `S frozen` step: S is added, then `wallsInDocument` answers null for the frozen S; red, but as a throw, not the `S frozen` reason) |
| M-DG4 `live(owner) != opening` → `get<OpeningParams>(owner) == null` | DG-frozen; AM7 | `Expected: not contains <22>  Actual: [22]  the door frozen: no host query through it`; AM7 `[E]` at origin, corpus far origin 23 deg, own groups, and +1e9 mm |
| M-DG5 `componentTypeId = 'floor_planner.dimension'` | DG-id | `Expected: 'architecture.dimension'  Actual: 'floor_planner.dimension'`. The other dimension tests stayed green, as the brief predicts. |
| M-DG6 centimetre arm `${decimalSeparator.char}` → `.` | Q0-DF1 | `Expected: '345,7'  Actual: '345.7'` |
| M-DG7 `references` returns a list | DP1 | `Expected: [18]  Actual: [18, 18]` (at origin and at corpus far origin) |
| M-RT-7 `live: liveTypesOf(s)` → `live: (h) => ArchitectureTypes.room` (room_plan.dart:112) | TT10 | `Expected: null  Actual: RoomOccupied:<RoomOccupied(Den)>` (RT-frozen-room red too) |
| M-RT-10 (intended equivalent, see Deviations) `_liveRooms` without the live filter | TT10 | `Expected: null  Actual: RoomOccupied:<RoomOccupied(Den)>` (RT-frozen-room red too) |

## Ported-test accounting

Every case goes to the kit, with assertions unchanged. The change classes used are imports and fixture adaptation (the brief's `liveOf(doc)` argument); no C7 id, tag or widget class applies.

| Source file (jet_cad_floor_plan/test) | Cases → kit `test/dimension/` | Adaptations |
|---|---|---|
| dimension_params_test | DP1 | imports |
| dimension_format_test | DF1, DF2, DF3, Q0-DF1 | imports; `:234-235` `wallsInDocument(doc, eN.wall, liveOf(doc))` |
| dimension_layout_test | DL1, DL2, DL2b, DL3, DL4, DL5 | imports |
| dimension_attach_test | AM3, AM1, AM2, AM2 (scaled group), AM4, AM5, AM6, AM6b, AM7 | imports (catalog import dropped; separator split into `separator.dart show SeparatorParams` and `separator_linetype.dart show ensureDashedLinetype`); 5 `wallsInDocument`, 10 `thickestWall`, 12 `attachCandidates` call sites (counts match the brief's line lists); `dart format` reflowed 4 of these calls |
| dimension_attach_points_test | AP1, AP2, AP3 | imports |
| dimension_follow_test | DN1, DN2, DN3, DN4 | imports |
| dimension_rotate_test | DR1, DR2, DR3, DR4, DR5 | imports |
| dimension_fuzz_test | DZ1 | imports |
| room_tool_test | TT10 → `test/room/room_tool_test.dart` | `.notice` → `.occupied` (×2), `isLiveObject<DimensionParams>` → `testCatalog().names<DimensionParams>` |

That makes 33 dimension cases plus TT10. New tests: DG-frozen and DG-id.

Further checks:
- Non-ASCII line counts match source and port for every file: params 0/0, format 53/53, layout 52/52, attach 53/53, attach_points 54/54, follow 29/29, rotate 63/63, fuzz 1/1, fixture 18/18. The non-ASCII lines themselves are identical.
- `grep` for the case ids in `jet_cad_2d_plan/test` and `jet_cad_2d_kit/test` found no hits.
- The `diff` of every ported file against its source shows only the listed hunks.

## Files changed

All under `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit_architecture/`:
- `lib/src/dimension/{dimension_geometry,dimension_attach,dimension}.dart` (new)
- `lib/jet_cad_2d_kit_architecture.dart`, `lib/src/type_naming.dart`
- `test/support/catalog.dart`, `test/support/dimension_fixture.dart` (new)
- `test/dimension/` (nine new test files)
- `test/room/room_tool_test.dart`

## Deviations

1. **M-RT-10 as written does not match the code.** It names `if (live(h) == ArchitectureTypes.room) h` → `h` in `_liveRooms`, but Task 19's review fix (df16d97a) made `_liveRooms` call `liveObjectsOf<RoomParams>(doc, live, ArchitectureTypes.room)`. I ran the intended equivalent: the body becomes `[for (final h in doc.components.withComponent<RoomParams>()) h]`, the same list with the live filter removed. It went red (above).
2. **M-DG3 is red as a null-check throw, not with the `S frozen` reason.** The brief named the reason only for M-DG3; for M-DG2 it accepted either form. It is red at the same step.

## Concerns

- For Tasks 21 and 22: `attachCandidates`' caller-owned `points` memo holds each wall's six points as laid out among the walls live at memo time. Freezing a neighbour emits no document change. If the Dimension tool's hover memo or the grips' per-drag memo are cleared only on document changes, they keep stale joined points after a freeze. This breaks no frozen-candidate rule, because candidates are re-filtered through `live` on every call; only the points of still-live walls can go stale. Per the FREEZE RULE, those tasks should drop or re-check the memo on liveness and add a first-reader test plus a mutation for it.
