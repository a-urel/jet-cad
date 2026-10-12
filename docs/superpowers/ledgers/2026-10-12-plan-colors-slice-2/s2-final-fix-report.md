# Slice 2 final-review fixes (commit 20558f9c)

1. EX3c (table_color_export_test.dart, after EX3b): controller.exportPlan(PDF choice, tableColorOpacity: 0.6)
   -> fileName plan.pdf, alphas(text(bytes)) contains 0.6, not 0.34902; same call with no opacity contains
   0.34902, not 0.6. M-PC7-c = drop `tableColorOpacity: tableColorOpacity` from exportBytes' PDF branch
   (export_bytes.dart:43-44). Result: EX3c RED ("Which: does not contain '0.6'", at the themed leg), the
   other tests green; reverted (file restored byte for byte), 8/8 green again. EX4 chord leg not extended.
2. CHANGELOG.md Unreleased: recolor bullet reworded ("tablesOnly leaves it true", and after this release a
   tablesOnly/readOnly embed shows the Colour row for a selected table; read only under recolor:false, never
   hidden); new bullet table.invalid_color (TableDiagnosticCodes.invalidColor, editor.dart); new bullet
   exportBytes/exportPdfBytes tableColorOpacity (default 0.35) for bare-shell hosts.
3. theme_canvas_test.dart: fullTheme gains tableColorOpacity: 0.6; invariant 4 gets the comment (plan has no
   coloured table; field reaches only a table colour's fill, pinned by EX4). File green.
4. table_color_underlay.dart: ArgumentError.value(opacity, 'opacity', 'must be in [0, 1]') for non-finite or
   outside [0,1], documented; EX1 gains a leg for 1.5, -0.1, NaN, infinity (throwsArgumentError).
5. table_color_underlay.dart doc: paragraph on the non-triangulating top (export skips, canvas fills the Path).
6. Comments corrected: jet_cad_2d_flutter/test/export/page_underlay_test.dart (withoutId doc) and
   table_color_export_test.dart (`text` doc): blanking shortens /ID, same way on both sides, rest byte for byte.
7. color_picker_test.dart: header says rooms and tables (rewrapped), duplicated CP7-CP11 paragraph removed,
   blank line before CP7.

## Gates
- floor_plan: `flutter test test/colors test/host/theme_canvas_test.dart` -> "00:06 +46: All tests passed!"
- floor_plan full, --enable-vmservice -> "02:01 +1984: All tests passed!" (run before the final dart format
  whitespace pass on table_color_export_test.dart; that file re-run afterwards: "+8: All tests passed!")
- flutter analyze -> "No issues found!"
- dart format --output=none --set-exit-if-changed . -> "Formatted 293 files (0 changed)" (after formatting once)
- jet_cad_2d_flutter: page_underlay_test.dart "+10: All tests passed!"; format "230 files (0 changed)"
- root: `dart run tool/ci/check_guide.dart` -> "docs/host-guide.md: all 53 code blocks are in the host probe"
