# Report: plan colours Slice 1, Task 4

Commit: `dd35caf0` feat(floor-plan): the Colour picker and the recolor capability
(branch `spec/plan-colors`, on top of `e048e120`). Implementer: Claude Sonnet 5.5.

## Implemented

- `FloorPlanEditorCapabilities.recolor` (default true; off in `readOnly`; in
  the constructor after `changeLayer`, the field, `copyWith`, `_flags` so `==`,
  `hashCode`, `toString` carry it; class doc bullet).
- `lib/src/colors/color_picker.dart`: `pickedColors`, `recolorCommand`
  (CompoundCommand labelled 'Colour', null when nothing changes),
  `colorPickerBlocked`, `swatchColor`, `ColorPicker`. Code is the brief's,
  unchanged but for `dart format`.
- Strings `color`, `colorNone`, `colorRefused`, `colorName(FloorPlanColor)` in
  `strings.dart` + en/de/tr with the brief's exact words; `recording_strings.dart`.
- `SelectionPanel` gains `darkCanvasPaper`, the `colors` flag, the mount before
  the Layer picker (spacer `sections || colors`), class doc Colour bullet;
  `planner_shell.dart` passes `darkCanvasPaper: _darkCanvas ? _paperArgb() : null`.
- Allow-list entry in `theme_colours_test.dart` for `color_picker.dart`.

## Files

Modified: `lib/src/host/editor_capabilities.dart`, `lib/src/l10n/strings.dart`,
`strings_en.dart`, `strings_de.dart`, `strings_tr.dart`,
`lib/src/planner_shell.dart`, `lib/src/selection_panel.dart`,
`test/host/editor_capabilities_test.dart`, `test/invariants/theme_colours_test.dart`,
`test/l10n/recording_strings.dart` (all under `packages/jet_cad_floor_plan/`).
Created: `lib/src/colors/color_picker.dart`, `test/colors/color_picker_test.dart`.
No barrel change (`ColorPicker` and the functions are not host API; `FloorPlanColor`
was added in Task 3).

## TDD evidence (honest account)

I wrote the capability change and the picker before running their tests, so
there was no compile-error RED for step 5; I did not run the new tests against
a missing implementation. The tests' ability to fail is shown by the mutants
below, each seen red, and the files then restored. First GREEN runs (real output):

- `flutter test test/host/editor_capabilities_test.dart` -> `00:00 +11: All tests passed!`
- `flutter test test/l10n` -> `00:06 +34: All tests passed!`
- `flutter test --enable-vmservice test/colors/color_picker_test.dart` ->
  `00:02 +7: All tests passed!` (CP6b added afterwards: `+8: All tests passed!`)

## Changed existing tests (named exceptions only)

- `test/host/editor_capabilities_test.dart` EC5, the `Caps.readOnly.toString()`
  pin (was `:273-277`, last line): `'changeLayer: false, undo: false)'` ->
  `'changeLayer: false, recolor: false, undo: false)'`. New test PC8 appended.
- `test/l10n/recording_strings.dart`: the three getters, `colorName`, an import
  of `plan_color.dart`.
- `test/invariants/theme_colours_test.dart` `kAllowedLiterals`: one entry plus comment.
- `test/host/barrel_test.dart`: not touched (as ruled).

No other existing test changed.

## Gates

All run from the worktree.

- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice` (whole suite,
  before the final unused-import cleanup of the new test file) ->
  `01:46 +1948: All tests passed!`. After the cleanup, `flutter test --enable-vmservice
  test/colors test/host test/l10n test/invariants test/room_panel_test.dart
  test/selection_panel_test.dart` -> `00:58 +688: All tests passed!`.
  `flutter analyze` -> `No issues found!` (it found two unused imports in my new
  test first; fixed). `dart format --output=none --set-exit-if-changed .` -> exit 0.
  No standing failures arose in this package.
- `apps/floor_planner`: `flutter test --enable-vmservice` -> `+212: All tests passed!`;
  analyze -> `No issues found!`; format exit 0.
- `apps/restaurant_demo`: `+68: All tests passed!`; analyze `No issues found!`; format exit 0.
- Not re-run: `jet_cad_restaurant_symbols` (nothing it reads changed), engine and
  `jet_cad_2d_flutter`/`_gpu` (not edited in this task).
- `git status` before the commit: no `analysis_options.yaml`.

## Mutants (each applied, killer run, seen red, reverted exactly; diff against a saved copy printed `reverted`)

| Mutant | Change | Killer run | Red output |
|---|---|---|---|
| M-C12 | `recolorCommand` loop over `_rooms(doc, keys).take(1)` | `flutter test --enable-vmservice test/colors/color_picker_test.dart` | CP2 `Expected: 'teal'` at the `roomOf(doc, r.b).color` assert; CP3 `Null check operator used on a null value` (`recolorCommand(...)!`); `-2` failures |
| M-C13 | `if (!capabilities.recolor) return strings.colorRefused;` removed | same | CP4 fails on `a tap changes nothing` (`canon` before vs after differs: Kitchen `"color":"teal"` vs `null`) |
| M-PC9-a | `when p.color != name` -> `when true` | same | CP3 `Expected: <1>  Actual: <3>` at `no new step` (`undoDepth`) |
| M-PC9-b | the permissions `if` in `colorPickerBlocked` removed | same | CP4 `PermissionDeniedError ... while handling a gesture`; `Expected: 'Read-only document'  Actual: 'Purple'` |
| M-PC9-c | `swatchColor` returns `0xFF000000 \| rgb` always | same | CP6 `Expected: <4279931780>  Actual: <4278225275>`; CP6b (shell wiring, dark theme) same pair |
| M-PC8 | `recolor: false` removed from `readOnly` | `flutter test test/host/editor_capabilities_test.dart` | EC5 `Expected: ... recolor: f ...  Actual: ... undo: fals ...`; PC8 `Expected: false  Actual: <true>` |

Source restored each time with `cp` from a copy saved in the scratchpad (never `git checkout`).

## Deviations from the brief (the code disagreed; intent kept)

1. **Swatch marking helper.** The brief's `find.descendant(of: swatch(n), matching: find.byType(Semantics))`
   cannot work: the swatch key is on the `InkWell`, which sits inside the `Semantics`.
   The test finds the nearest ancestor `Semantics` with a label (`semanticsOf`). The picker code
   (key on the InkWell, as in the brief) is unchanged.
2. **CP2 "canvas repainted".** `room_panel_test`'s undo tests assert document state only; there is no
   repaint witness in the codebase for this. I used a real pixel witness: the shell is wrapped in a
   `RepaintBoundary`, read back with `toImage` (as `room_paint_test` does) at a point inside room A
   (rotated group) and inside room B, off the labels. Before: grey; after the tap: bare floor blended
   with teal at alpha 51 (both rooms, within 3 per channel); after `Ctrl+Z` and exactly one `pump`: the
   pixels equal the grey ones, the document `canon` equals the pre-tap one, tints are ACI 7 at 229, and
   the picker marks `none` again. The page grid is hidden in this fixture so a sample is bare floor.
3. **Undo label.** `undo.dart` has no "top label" accessor. The test reads the label from
   `doc.commands.changes` (`CommandApplied.label`) and gets `['Colour']`.
4. **CP4's "permissions" legs** also cover the `components` allowed / `geometry` denied case, which the
   brief mentions only as `RoomType().editCapability`.
5. **Added tests beyond the brief:** CP6b (the shell's dark theme reaches the swatches; kills a wiring
   mutant the pure-function CP6 cannot), and in CP3 `None` tapped twice, the `children` count of
   `recolorCommand` (one `SetComponentCommand`, for B) and `recolorCommand` -> null for A alone and for a wall.
6. The Wall tool check in CP1 uses `W` then `Esc` (as `selection_panel_test` does) rather than a controller call.
7. Commit trailer is `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (the model that did the
   work), not the brief's Opus line.

## Self-review

- Review Focus 2 (chosen twice): CP3 (same swatch twice, then a selection already all teal: depth and `stateId`
  unchanged). Focus 3 (Ctrl+Z): CP2 pixel leg. Focus 4: CP2 selects A, B, a wall and a separator; the wall's and
  the separator's component and every child record are compared whole. Focus 5: CP1 (`"magenta"` marks nothing
  and is still stored).
- Fixtures: rooms at `corpusGroups` (far, turned 23 degrees), room A in a group turned 0.61 rad, B at the identity;
  hues `teal`, `purple`, `magenta`, never only `red`.
- `'\u0000'` sentinel for "mixed" kept as the brief says; a stored unknown name equals no swatch.
- `colors` row hidden while the Wall or an opening tool's settings show (`_toolMode || _openingToolMode`), as the
  Layer picker is; verified for the Wall tool only (CP1).

## Concerns

- No compile-error RED was recorded (see TDD evidence); mutants are the proof of bite.
- The picker is shown even with `selectionPanel`-related capabilities such as `changeLayer: false`; it follows
  `recolor` only, per the brief. A `tablesOnly` host keeps `recolor: true` (Slice 2 extends the picker to tables).
- The Colour row has no `reshape`-style gating beyond `recolor` and permissions; a host with `reshape: false`
  but `recolor: true` can still recolour a room. That follows the spec's separate flag.
- The pixel witness in CP2 depends on the surround being bare at the sample point and on the rasteriser
  blending within 3 per channel; it passed on this macOS host.
