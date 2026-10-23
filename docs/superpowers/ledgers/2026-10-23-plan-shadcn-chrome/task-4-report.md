# Task 4 report
Commit: 160ea980 test(plan): the leak collectors read the chrome parts
Gates: plan "02:51 +1685 ~7: All tests passed!", analyze "No issues found!", format 0 changed; integration "01:34 +240: All tests passed!", analyze "No issues found!", format 0 changed.
Collector removal (plan test, LK1x with the PlanWordsCarrier lines removed):
 LK1x tooltip: Expected: contains 'Raw' Actual: []  [E]
 LK1x menu entry: Expected: contains 'Raw' Actual: []  [E]
 LK1x field error: stayed green (PlanTextField draws its error as a visible Text, so the old collector saw it; the test is still a regression guard for the part's visibleWords).
Collectors restored afterwards.
R-LK: collectors extended with PlanWordsCarrier.visibleWords; no assertion or allowlist changed.
 - packages/jet_cad_2d_plan/test/editor/editor_words_test.dart: imports (:22-:25 area, chrome icon_button/menu_button/text_field/words_carrier, plan_editor_bar), visibleTexts :95-98, new LK1x tests :385-440
 - packages/jet_cad_2d_integration/test/l10n/leak_test.dart: import :23, visibleTexts :62-65 (src import; no analyzer complaint). panel_words_test.dart does not collect, untouched.
