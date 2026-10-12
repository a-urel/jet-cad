# Report: plan colours Slice 1, Task 1 (PC-3a)

Status: DONE. Commit `78df3dbc` "feat(2d): the planner stamps colour and transparency on a matched child".

## Implemented

- `SetEntityStyleCommand.restore(entity, color, transparency)` in `lib/src/document/layer_commands.dart` (after `SetEntityLayerCommand`), exactly as the brief; already exported (`layer_commands.dart` is in `jet_cad_2d.dart`).
- `_stampStyle` in `lib/src/parametric/regeneration.dart`, called after each `_stampLayer` for a matched fill, its boundary, and a matched plain child (TEXT included); `_plan`'s doc and the "fixed at creation" comment updated.
- `Generated`'s doc (`parametric_system.dart`): "Three columns are the planner's" (layer, colour, transparency); the add-only list is now flags, boundary flags, linetype, lineweight, text attributes; the constructor doc drops `transparency`.
- Test client `Dye`/`DyeType` (+ `dyeLoop`, `dyeLine`) in `test/parametric/support/clients.dart`, registered in `testCatalog()` after `Swatch`.
- `test/parametric/style_stamp_test.dart` (ST0-ST4), new.
- AT1 re-pinned (header, name, assert after `Swatch(-210.75, 95.5, 100, 50)`): see deviations.

Files: layer_commands.dart, regeneration.dart, parametric_system.dart, test/parametric/{attributes_test.dart, style_stamp_test.dart, support/clients.dart}. No `analysis_options.yaml` touched (`flutter pub get` this run left none modified; `git status` clean before commit).

## TDD

RED (`dart test test/parametric/style_stamp_test.dart` in `packages/jet_cad_2d`, before any engine code):
```
Failed to load "test/parametric/style_stamp_test.dart":
test/parametric/style_stamp_test.dart:25:10: Error: Type 'SetEntityStyleCommand' not found.
...
00:00 +0 -1: Some tests failed.
```
Expected: the command did not exist.

GREEN (same command, after the command and the stamp):
```
00:00 +4: ST4 SetEntityStyleCommand: ...
00:00 +5: All tests passed!
```
AT1 was run red before re-pinning: `AT1 ... [E] Expected: EntityRecord:<EntityRecord(fill 3E9)> Actual: ... 3E9 as added` (transparency 229 -> 100 now moves), then green after: `+2: All tests passed!`.

## Gates

- Engine, `cd packages/jet_cad_2d && dart test --file-reporter json:/tmp/pc-s1-t1.json`: `+1286 -2`, the two standing failures only (`generate_document_test.dart`: "both text fractions default to zero and change nothing", "the default document is the one Plan 2 measured, byte for byte").
  `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d /tmp/pc-s1-t1.json` -> `packages/jet_cad_2d: 1288 tests; the standing failures and skips, exactly`, exit=0.
- `dart analyze --fatal-infos`: `No issues found!`. `dart format --output=none --set-exit-if-changed .`: `Formatted 173 files (0 changed)`.
- `jet_cad_2d_flutter` (`flutter test --file-reporter json:...` + expect_failures): exit 1 with exactly `standing failure passed or did not run: test/golden/text_lod_ladder_golden_test.dart :: text lod ladder rung 1 (RenderBackend.canvas)` and `... rung 2 ...`: the recorded macOS standing difference; nothing else reported. (This is in `jet_cad_2d_flutter`, not a separate render package.)
- `jet_cad_2d_gpu`: `20 tests; the standing failures and skips, exactly`, exit=0.
- `jet_cad_floor_plan` (`flutter test --enable-vmservice`): `+1931: All tests passed!`; analyze `No issues found!`; format 0 changed.
- `apps/floor_planner` (`--enable-vmservice`): `+212: All tests passed!`; analyze clean; format 0 changed.
- `apps/restaurant_demo`: `+68: All tests passed!`; analyze clean; format 0 changed.
- `jet_cad_restaurant_symbols`: `+97: All tests passed!`; analyze clean; format 0 changed.
- No planner test outside AT1 changed (brief Step 9): none to report.

## Mutants (each applied, run, seen red, reverted by `cp` from a scratch copy of the pristine file; reverted file diffed identical / re-tested green)

Command for all: `dart test test/parametric/style_stamp_test.dart` in `packages/jet_cad_2d`.

- **M-C17** (`_stampStyle` unguarded: `if (true) {`): RED, killer ST2: `Expected: empty  Actual: [Instance of 'SetEntityStyleCommand' x3]  a move plans none`. ST1, ST3, ST4 stayed green.
- **M-PC3a-1** (boundary's `_stampStyle` call removed): RED, killers ST1 (`3EA: colour and transparency only`, the boundary polyline record `3EA`), ST2's premise (`has length of <2>`, "a recolour plans one per child"), ST3 (`Expected: <51> Actual: <204>`).
- **M-PC3a-2** (transparency dropped from the guard in `_stampStyle` and from the command's `copyWith`): RED, killers ST1 (`3E9: colour and transparency only`, fill record), ST3 (`Expected: <51> Actual: <204>`), ST4 (`Expected: <204> Actual: <-1>`).
- **M-PC3a-3** (inverse restores the new values `.restore(entity, color, transparency)`): RED, killers ST1 (undo: `canon` bytes differ, `"color":26092714` vs `16812411`) and ST4 (`Expected: ByLayerColor() Actual: TrueColor(0x00897b)`).
- After all four: `dart test test/parametric` `+142: All tests passed!`, analyze and format clean.

## Deviations from the brief

1. **AT1's re-pin is wider than the brief's loop.** The brief's loop after `s1` was applied; the same test's later block (the `s2` step, `records[text1]`, `records[k]` for fill/boundary/line) also compared against the 229 records and failed. I defined `restyled` once after `s1` (fill, boundary, LINE take `s1.alpha`, derived from `Swatch`'s code; the TEXTs, which carry no alpha, stay as added) and used it in the `s2` block too. The brief's `r.transparency == 229 ? 100 : ...` ternary was replaced by that explicit rule (same effect, derived from the generator, not read back). Added the brief's `lineweight == 35` assert.
2. The brief's `plannedStyles`, `create`, `kids`, `canon`, `enc`, `reload`, `atB`, `catalog`, `paramDoc`, `ClipRect` all matched the real helpers; no change needed. `dart format` re-wrapped a few lines of the brief's test and `Dye` code only.
3. Commit trailer is `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (the harness's attribution instruction for this session), not the brief's `Claude Opus 5.5`. Amend the trailer if the plan's wording must win.
4. `dart test` first failed with "restaurant_demo requires the Flutter SDK" until `flutter pub get` was run at the worktree root (a fresh worktree); nothing tracked changed.

## Self-review

- The guard compares stored encodings exactly (`colorAt` against `encodeColor(g.color)`; `transparencyAt` against `g.transparency`), per the exact-`==` rule.
- Existing clients all generate ByLayer colour and their own fixed transparency, so a file's children already match: no existing stamp fires (the suite proves it, except AT1, where `Swatch` changes its alpha between `s0` and `s1`).
- `SetEntityStyleCommand` mirrors `SetEntityLayerCommand` (capability `geometry`, capabilities `{components}`, `touched: {entity}`, `invalidateDerived`).

## Concerns

None blocking. Note for later tasks: the `text_ladder_golden_test.dart` rungs 1-5 fail in `jet_cad_2d_flutter` on this machine; `expect_failures` treats them as standing (not flagged).
