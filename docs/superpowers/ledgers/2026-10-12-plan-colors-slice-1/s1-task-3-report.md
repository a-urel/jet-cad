# Report: plan colours Slice 1, Task 3 (palette and the room's colour)

Commit: `a4da2909` feat(floor-plan): FloorPlanColor and a room's colour (on `spec/plan-colors`, parent `9ab3297`).

## Implemented

- `FloorPlanColor` (eight hues, brief's values verbatim) and `floorPlanColorNamed` in a Flutter-free file.
- `FloorPlanColor` exported from the host barrel (`export 'src/colors/plan_color.dart' show FloorPlanColor;`) and added to B1's set (controller ruling: in this task).
- `RoomParams.color` (`String?`), `colorValue`, `copyWith(color: _keep)`, `==`, `hashCode`, `toString`, JSON: four keys `seed, name, label, color`, all always written; a missing `color` reads null; a wrong type throws `TypeError`.
- `kRoomColorTransparency = 204`; `RoomType.generate` takes `tintColor`/`tintAlpha` from `p.colorValue`: `TrueColor(hue.rgb)` at 204 for a known hue; unknown or no name: today's `kRoomTintColor` at 229 (the `Generated`s are exactly today's). Step 3 (outline polyline) takes the hue, keeps its flags and transparency. `generate`'s doc updated.

## Files

- Created: `packages/jet_cad_floor_plan/lib/src/colors/plan_color.dart`, `packages/jet_cad_floor_plan/test/room_color_test.dart`
- Modified: `lib/jet_cad_floor_plan.dart`, `lib/src/parametric/room.dart`, `test/host/barrel_test.dart` (B1 gains `'FloorPlanColor'`), `test/room_object_test.dart` (RP1 only)

## TDD evidence

RED (before `room.dart` was touched; `plan_color.dart` and the test existed):
`cd packages/jet_cad_floor_plan && flutter test test/room_color_test.dart` ->
`test/room_color_test.dart:256:49: Error: The getter 'color' isn't defined for the type 'RoomParams'.` (and `colorValue`, `copyWith`'s `color`...), ending
`00:00 +0 -1: Some tests failed. ... room_color_test.dart: loading .../room_color_test.dart`.

GREEN after Steps 4-6 (first run also exposed two defects in my own tests, fixed: RC7 asserted a child order that is not the generated order (polyline first), RC6 compared the fill's flags to the boundary's; both are test errors, not product defects):
`flutter test test/room_color_test.dart` -> `00:00 +8: All tests passed!` (the fixture test, RC1-RC7).
`flutter test test/room_color_test.dart test/room_object_test.dart test/host/barrel_test.dart` -> all pass (B1, B2... included).

## RP1's re-pin (room_object_test.dart, the named exception)

- name: `RP1 RoomParams round-trips with key order seed, name, label; label null is written; == differs on each field` -> `RP1 RoomParams round-trips with key order seed, name, label, color; label and color null are written; == differs on each field`
- keys: `['seed','name','label']` -> `['seed','name','label','color']`
- `auto`: `{"seed":[1234.5,-987.25],"name":"Room 1","label":null}` -> `...,"label":null,"color":null}`
- `offset`: `{...,"label":[12.75,-3.5]}` -> `{...,"label":[12.75,-3.5],"color":null}`
- the `==` list gains `RoomParams(1234.5, -987.25, 'Room 1', label: (12.75, -3.5), color: 'teal')` (fifth case, differing from `offset` only in colour).
No other existing test was edited. (Round-trip, copyWith asserts there pass unchanged.)

## Tests in room_color_test.dart

Fixture: `buildPlan(twoRoomWalls, place: corpusGroups, measurer: FlutterTextMeasurer())`, page attached, room A (Kitchen, seed (1500.25, 2000.5)) in a group turned 0.61 rad off the origin, room B (Room 2) at the identity; system left installed, history cleared. Plus a fixture sanity test (A off identity, uncoloured, tints ACI 7 / 229, drift empty). RC1-RC7 as the brief. Hues: teal, purple, `magenta`.

- RC1 JSON (exact encodings, v9 three-key read, unknown kept, `7` throws TypeError, copyWith clears/keeps/keeps-on-rename).
- RC2 recolour existing room: `undoDepth + 1`, both tint records TrueColor(0x00897B) / 204, same child handles, labels' snapshots equal, room B's children equal, undo -> `canon` equal to before, redo -> `canon` equal to the recoloured bytes, last leg a rename keeps the colour (M-C22's killer).
- RC3 purple, then `copyWith(color: null)`: every child of A bit for bit the original (ACI 7 / 229); B untouched throughout.
- RC4 `magenta`: tint children equal to today's, `"color":"magenta"` in the file, round-trips byte for byte, drift empty.
- RC5 the eight names and `rgb` literals in order; `colorValue`; `'Teal'` and `null` give null.
- RC6 0.5.1 plan by bytes (schemaVersion 9, each room's `"color":null` removed; the test asserts the key was present and the v9 text no longer holds `"color":null`); loads via `reloadWithPage`; tints equal the originals; drift empty; rename of A: A's tint whole equal, B's equal, `debugRoomGenerates` rose; wall 0 moved 0.5 mm: `debugRoomGenerates` +2, every tint record ACI 7 / 229 with flags as before, A's tint geometry did move (so the regeneration is real); drift empty; the saved file is schema 10 with `"color":null` on the rooms.
- RC7 step 3: a coloured room whose tint is the outline: outline takes teal, same handle, same flags (invisible), same transparency, same children.

## Mutants (each applied by `scratchpad/mut.py`, run with `scratchpad/run_mut.sh <mutant> <tests>`, reverted by copying the pre-mutation `room.dart` back and `cmp`-ing it; "reverted exactly" printed each time). In the diffs `<` is the good line, `>` the mutant.

| Mutant | Change | Command | Red |
|---|---|---|---|
| M-C1 (rooms) | `fromJson`: `color: floorPlanColorNamed(json['color'] as String?)!.name` | `flutter test test/room_color_test.dart test/room_object_test.dart` | `00:00 +12 -6: Some tests failed.` RC1, RC4, RC6, plus room_object RG5 |
| M-C3 | `tintColor` always `kRoomTintColor` | `flutter test test/room_color_test.dart` | `Expected: TrueColor:<TrueColor(0x00897b)> Actual: IndexedColor:<IndexedColor(7)>` (also purple); `+5 -3`: RC2, RC3, RC7 |
| M-C4 | `if (color != null) 'color': color` | `... room_color_test.dart room_object_test.dart` | `Expected: ['seed','name','label','color'] Actual: ...['seed','name','label']`; `Expected: '{...,"color":null}' Actual: '{...,"label":null}'`; `+15 -3`: RC1, RC6, RP1 |
| M-C16 | `tintAlpha` always `kRoomColorTransparency` | `flutter test test/room_color_test.dart` | `Expected: <229> Actual: <204>`; `+3 -5`: RC2, RC3, RC4, RC6, fixture test |
| M-C22 | `copyWith` left-out `color` -> `null` | `flutter test test/room_color_test.dart` | `Expected: RoomParams:<...null, teal)> Actual: ...null, null)>`; `Expected: 'teal' Actual: <null>`; `+6 -2`: RC1 and RC2 (the rename leg) |
| M-PC3-a | `fromJson`: `color: null` | `flutter test test/room_color_test.dart` | `Expected: 'magenta' Actual: <null>`; `+6 -2`: RC1, RC4 |
| M-PC3-b | step 3 outline `color: kRoomTintColor` | `flutter test test/room_color_test.dart` | `Expected: TrueColor:<TrueColor(0x00897b)> Actual: IndexedColor:<IndexedColor(7)>`; `+7 -1`: RC7 |

Killers match the brief's (M-C1: RC1/RC4; M-C3: RC2; M-C4: RC1/RP1; M-C16: RC6/RC3; M-C22: RC1/RC2; M-PC3-a: RC1; M-PC3-b: RC7), with extra kills noted.

## Gates (all after the last source change)

- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice` -> `01:57 +1939: All tests passed!`; `flutter analyze` -> `No issues found!`; `dart format --output=none --set-exit-if-changed .` -> `Formatted 286 files (0 changed)`, exit 0. (One interim analyze warning: unused `vector_math` import in my new test; removed before the final runs.)
- `apps/floor_planner`: `flutter test` -> `+212: All tests passed!`; analyze `No issues found!`; format 0 changed.
- `apps/restaurant_demo`: `flutter test` -> `+68: All tests passed!`; analyze `No issues found!`; format 0 changed.
- `packages/jet_cad_restaurant_symbols`: `flutter test` -> `+97: All tests passed!`; analyze `No issues found!`; format 0 changed.
- The engine and the render packages are not touched by this task (no `jet_cad_2d` / `jet_cad_2d_flutter` / `_gpu` change), so I did not rerun them. The planner's standing sets were not touched; the planner suite passes outright, so no `expect_failures` comparison was needed.
- `git status` before commit: only the six task paths; no `analysis_options.yaml`.

## Deviations from the brief

1. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (the controller's instruction: name the model that is running), where the brief's text says Opus 5.5.
2. RC7 builds its step-3 room with `debugTintFailedSteps = {1, 2}` on `boxWalls` (the seam `room_diagnostics_test.dart`'s DG3 uses for `room.tint`), in a group turned 0.61 rad, not by importing a pinched plan; the brief's pointer (`grep "room.tint"`) led to DG3, which has no pinched geometry, only the seam. The seam is reset in `addTearDown`.
3. Helper names: all of `kids, kindOf, recordOf, payloadOf, buildPlan, attachPage, addRoom, corpusGroups, driftOf, moveWall, labelsOf` exist as the brief uses them (`kindOf`, `payloadOf`, `kids`, `driftOf` through `wall_fixture.dart` re-exports). Extra helpers I used: `renameRoom`, `labelStrings`, `kindsOf`, `canon`, `enc`, `reloadWithPage`. `moveWall(plan, 0, W(0, 0.5, 8000, 0.5, 200), doc: loaded)`: the 0.5 mm move is wall 0's centreline to y = 0.5.
4. RC2/RC3/RC6 compare "records whole" through a `snapOf` helper: the record's `toJson()` (EntityRecord has no `==`) plus the payload's coords and scalars. In RC6, after the wall move the tints' geometry legitimately changes, so there the colour, transparency and flags are compared (and the geometry is asserted to have moved), while the rename leg compares whole.
5. B2 (the "every name is usable" test) was not edited; `FloorPlanColor` is in B1 only, as the brief says.

## Self-review

- Spec/brief fidelity: palette values, constants and `RoomParams` API verbatim. `plan_color.dart` and `room.dart` import no Flutter.
- Review Focus 1 (0.5.1 plan) and 5 (`magenta`: opens, today's tint, saved back) are pinned by RC6 and RC4 here; the picker part of 5 is Task 4's.
- RoomParams' `==`/`hashCode`/`toString` changed only as the brief says; no other signature moved. The allocation invariants, painters and goldens untouched; the full suite incl. allocation tests passes.
- Fixtures are not degenerate: A in a turned group at a far origin, B at the identity, fractional seeds, unknown name, two non-first hues; RC6 includes a regenerating edit proven by `debugRoomGenerates`.

## Concerns

- None blocking. Note for Task 4: unknown colour names make `colorValue` null, so the picker must mark no swatch from `colorValue`, not from `color != null`.
- `dart format` rewrote the lines I touched in `room_object_test.dart` (the `offset` expectation wraps as `expect(\n jsonEncode(...),\n ...`), within the named RP1 exception.

---

## Fix round 1

Finding (Important): RC6's wall-move leg compared only colour, transparency and flags of the regenerated tints, on the false premise that the record changes with the geometry. `EntityRecord.toJson()` carries no geometry (a fill's boundary handle is in its payload), so the records can and must be compared whole.

Changed (`packages/jet_cad_floor_plan/test/room_color_test.dart`, RC6 only, no library change):
- Before the rename leg, snapshot `records0[r] = [for (final t in tintRecords(doc, r)) jsonEncode(t.toJson())]` for room A and room B (replacing the old `flags0`).
- After the wall move (both rooms regenerated, `debugRoomGenerates` +2), each room's tint records, `jsonEncode(t.toJson())`, must equal `records0[r]`; the colour 7 / transparency 229 asserts stay.
- The "geometry moved" assertion is kept for A and added for B (`tintSnaps(doc, f.b)` is not `b0`), so the regeneration is proven to move the payloads while the records stay equal.

Covering command, in `packages/jet_cad_floor_plan`: `flutter test test/room_color_test.dart` ->
`00:00 +6: RC6 a plan saved by 0.5.1 with rooms: edits that regenerate its rooms leave the tints ACI 7 at 229, and drift() stays empty`
`00:00 +7: RC7 step 3: ...`
`00:00 +8: All tests passed!`
`flutter analyze` -> `No issues found!`; `dart format` -> 0 changed.

M-C16 re-check (`tintAlpha` always `kRoomColorTransparency`; `run_mut.sh C16 test/room_color_test.dart`): `Expected: <229> Actual: <204>`, `00:00 +3 -5: Some tests failed.`, failing: RC2, RC3, RC4, RC6, the fixture test; `--- reverted exactly` (cmp against the pre-mutation copy).
Note: with the mutant, the first failing assert inside RC6 may be an earlier leg (the opened-as-saved or rename leg compare tints too); RC6 dies either way. I did not isolate the wall-move leg's kill separately.
