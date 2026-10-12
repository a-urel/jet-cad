# Slice 1 final-review fixes

Commits: `3aadfe7a` (docs), `971565a0` (tests and tidy-ups). Base `f3157903`.

## Per finding

1. **CHANGELOG / guide, the strings break.** `CHANGELOG.md` Unreleased: a
   "Breaking for a host's own strings" bullet naming `color`, `colorNone`,
   `colorRefused`, `colorName(FloorPlanColor)` (the 0.2.0 precedent's
   wording). `docs/host-guide.md` section 3, the "Your own words" bullet:
   one sentence, "Since 0.6.0 ... must add ...; a subclass of a built-in
   language gets them". No code block added; `check_guide` unchanged (48 blocks).
2. **RC8**, `packages/jet_cad_floor_plan/test/room_color_test.dart` (end of
   file). Added.
3. **STATUS.md.** (a) "Resume here" rewritten: Slice 1 implemented and
   reviewed on `spec/plan-colors` (worktree `.claude/worktrees/plan-colors`),
   awaiting the human's merge word, then Slice 2 (tables, no plan yet), with
   the note on pinning the Colour row's tool-mode visibility through
   `controller.select` while the Wall tool is active (the surviving mutant on
   `!_toolMode && _openingToolMode == null`); the old 0.5.1 text kept below it
   as "The released line". The in-flight plan-colours entry (~line 306) now
   says "each task and the whole branch reviewed. Next: the human's merge
   word". (b) the macOS re-baseline item lists schema 10. (c) "Where the project
   stands" names `v0.5.1` beside the other two probes (and the "More gates"
   line at the file's end names `old_host_probe.sh v0.5.1`, which CI already
   runs, `.github/workflows/ci.yml:173`). (d) the owed native read names
   `colorRefused` with both strings (checked against `strings_de.dart:356` and
   `strings_tr.dart:352`).
4. **Guide section 11.** The schema 10 sentence is now its own
   "**Schema 10** *(since 0.6.0)*" bullet after the Schema 9 one (also says
   `load` throws a `FormatException` and the terminals move together).
5. **Tidy-ups.** `schema_version.dart:51` "as 6's to 9's did". `schema_10_test.dart`
   S10-2 gains `expect(nine, isNot(ten));` before the decode.

## RC8's design

Driven through `exportBytes` (`lib/src/export/export_bytes.dart`) with
`ExportChoice(png, d96)`, the planner's own export path; the PNG decoded
under `tester.runAsync` to rawRgba. The fixture's two rooms; a page
(`PageComponent(originX: plan origin x - 3000, originY: plan origin y - 2000,
gridVisible: false)`) attached so the plan at the corpus far origin turned 23
deg fits; no grid line can fall on a sampled pixel.

Pixel position from the page's numbers, not `pageCamera` (the formula of
`export_png_test.dart`): `x = (wx - ox)/den*u`, `y = (oy + effH*den - wy)/den*u`,
`u = 96/25.4`, `wx, wy = plan.at(px, py)`.

- Sample in room A: plan (2400, 3300), 0.4 m inside A's east wall, 1.4 m from
  its label seed (1500, 2000). In room B: plan (7000, 3000), 0.9 m inside B's
  east wall, far from its label.
- Expected, from literals (alpha 51 and 26, not the constants, so a constant
  mutant is caught by pixels, not by an assertion about itself): per channel
  `round(a/255*s + (1-a/255)*255)`. Teal 0x00897B at 51 gives (204, 231, 229)
  (also asserted by hand); ACI 7 drawn black at 26 gives (229, 229, 229). Alpha
  255 required; each channel within +-2.
- Control, same room and pixel: first export with nothing coloured: A and B both
  grey (229). Then `recolor(A, 'teal')` and export again: A's pixel is teal,
  B's (uncoloured, in the same image) is still grey. So the test is not vacuous
  and a colour that leaks to the other room is caught.

## Mutant

`kRoomColorTransparency` 204 -> 229 (`room.dart:129`): RC8 red at the "A teal"
check (`room_color_test.dart:489`): `Expected: a numeric value within <2> of
<204>, Actual: <229>` (channel 0). Reverted (`git diff` of `lib/` empty);
RC1-RC8 green again. (A first version used the constants in the expected
value; the mutant then tripped the hand-arithmetic assertion, not the pixel,
so the expected value was changed to literals.)

## Gates

- `packages/jet_cad_floor_plan`: `flutter test test/room_color_test.dart` ->
  `00:00 +9: All tests passed!`; `flutter analyze` -> `No issues found! (ran in
  3.8s)`; `dart format --output=none --set-exit-if-changed .` -> `Formatted 288
  files (0 changed)`.
- `packages/jet_cad_2d`: `dart test test/codec` -> `00:00 +43: All tests
  passed!`; `dart analyze --fatal-infos` -> `No issues found!`; format ->
  `Formatted 175 files (0 changed)`.
- Root: `dart run tool/ci/check_guide.dart` -> `docs/host-guide.md: all 48 code
  blocks are in the host probe`.

The other packages' suites (`jet_cad_2d` whole, `jet_cad_2d_flutter`, `_gpu`)
were not rerun: only a comment, a test premise, a test and docs changed.
