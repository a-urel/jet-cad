# Task 6 review (export, print, busy wrappers)

Verdicts: spec compliance PASS; quality PASS WITH FINDINGS. 0 Critical, 1 Important, 3 Minor.

## Verified
- Gates, re-run by me (apps/architecture_demo): `flutter test` last line `00:31 +140: All tests passed!`; `flutter analyze` last line `No issues found! (ran in 3.5s)`; `dart format --output=none --set-exit-if-changed .` -> `Formatted 36 files (0 changed)`.
- Decision 6: lib/document_host.dart exportFlow catch -> `exportFailed`; `onPageFlowError` -> `pageFlowFailed` (document_host.dart ~L410). Kind from extension (pdf/png, else ArgumentError -> exportFailed); cancel (`place == null`) returns before writing; a throw shows exportFailed. Matches the brief. Wrappers refuse while busy, finally clears, made once as `late final` (document_host.dart L90-96). Matches the controller ruling (refusal, 144 px name, DC12c 800 px), not the brief's nesting code, as ruled.
- Audit rows: every SPLIT row (EX1, EX3, EX5, EX10, EX13, EX14, PR1, PR3, PR5, PR10, EF9) has an -open case plus a cited intent; every DROPPED row (EF3) is recorded in the file header. I opened all 22 cited covering tests in packages/jet_cad_2d_plan/test at the cited lines: each exists and matches the intent (X-4, X-7, X-8, PF2/3/5/6/7/9/11/12/13/14/17/21, ED-3, ED-X1, KB-6, SW1, EF4, W-F1). PORT rows EX6-8, EX9b, EX12, PR6, PR8, E2E, EF11, EF12 present.
- Mutations run by me, reverted with `git checkout --`, `git diff --quiet` printed CLEAN after each:
  - `onPageFlowError` titled exportFailed -> `test/export` red: PR3-open (+32 -1).
  - `'png' => FileKind.pdf` in exportFlow -> red: EX3-open, E2E (+31 -2).
- DC1/DC12/DC12c edits: bar order gains `export`; the step measured Export->Print instead of Save As->Print (still the same adjacent-button gap); 160 -> 144 and 776 -> 800 per ruling. Not a weakening beyond the ruling (DC12c's range shrinks 1000..776 to 1000..800, as ruled).
- Roboto pubspec entry: justified (EF12 port; same entry and comment as apps/floor_planner/pubspec.yaml:45-50, path now under jet_cad_2d_plan/lib/fonts which exists and is that package's declared asset).

## Important
1. test/export/export_flow_test.dart EX12 (L~ "T-10 chords" group): the old assertion `chordHandled(...) isTrue` (the key-down was handled, i.e. consumed) for Cmd/Ctrl+P and +E under the open dialog is gone; `chord()` returns void. What remains (dialog still one, no print, nothing written) is the observable effect, but a library regression that lets the key through while another handler swallows it would no longer fail on "consumed". The audit row says PORT "chord consumption above a route". Fix: add a `chordHandled` helper to test/support/app_rig.dart (as floor_planner/test/support/export_flat.dart:188) and assert `isTrue` for the four chords, as the old test did. (Same for PR10-open's old `chordHandled` use, though that case now asserts the stronger "no second print".)

## Minor
1. test/export/print_flow_test.dart PR1-open and export_flow_test.dart EX1-open: the old exact `textRuns == [labelText]` is `isNotEmpty` now (and the old `fontLoads == 1` and instance-colour/lineweight checks are gone). The audit sends placement/overrides/separator to covering tests, so this is within the audit, but the exact-text check had no covering row; pin the sample's known label text if one is stable.
2. test/export/export_font_test.dart EF12: the old test compared the library font bytes to the vendored copy (`orderedEquals(vendoredFont())`); the port checks only `existsSync()`. W-F1 (plan_assets_test.dart:55) covers byte equality for lib/fonts/Roboto-Regular.ttf, so the pubspec path pointing at it is the only remaining link; acceptable, noted.
3. test/document_commands_test.dart ~L871-880 and L9-13: comment lines exceed 80 columns (formatter does not wrap comments). test/export/busy_test.dart imports `dart:ui` between package imports (L18-20, directive order). Cosmetic.

## Noted, not re-litigated
- The dialog -> onExport gap (N6-gap pins it); N6-dialog calls the editor's `onNew` rather than tapping the New button because the barrier blocks the tap (comment says so).
