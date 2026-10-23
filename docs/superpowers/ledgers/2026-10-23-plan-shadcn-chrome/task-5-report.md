# Task 5 report: the editor, its bar and the tool palette

Status: NEEDS_CONTEXT (everything migrated and every ruled test rewritten; 14 tests stay red for one reason that is not a widget type, see "Open").

## Red (before migration), packages/jet_cad_2d_plan: flutter test test/editor/editor_chrome_test.dart
Full output: task-5-red.txt. Last line: `00:12 +8 -3: Some tests failed.` Failing: ED1 (Undo was an IconButton), ED2 (left-tabs was a SegmentedButton), ED3 (bar colour was surfaceContainer). ED4-ED6 pass before and after (regression guards).

## What changed
- plan_editor.dart: every bar IconButton -> PlanIconButton through ONE helper `_barButton` (file/edit toolbar, phone/tablet drawer buttons, the symbols strip button; a new bar action is one more `_barButton` call). Tools/Symbols -> PlanSegmented<_LeftTab> (segments keep keys tab-tools / tab-symbols, now on the PlanSegment button; left-tabs stays on the PlanSegmented). Damaged warning: ShadTooltip + Semantics(container, label planDamaged) + destructive colour. Bar surface = shad background + bottom border; columns/strip = shad card + inner border. Toolbar's transparent Material removed. All PlanHostSlot wraps kept. Scaffold STAYED (layout, host slot Material infrastructure; host_slot_test green).
- plan_tool_palette.dart: rows -> PlanListRow (selected, onTap null when disabled, letter after the title), compact -> PlanIconButton(selected), Divider -> ShadSeparator.horizontal (group separators keep key tool-group-<kit>), Fill -> PlanCheckRow (+ the F letter) / compact PlanIconButton. The palette's own Material removed.
- editor_layout.dart: drawer Material(elevation) -> DecoratedBox (card, border, shadow) around PlanHostSlot (keeps ink for the Material panels until Task 6); keys chrome-left-drawer / chrome-right-drawer now on the DecoratedBox. Scrim stays Material `colorScheme.scrim` (a black token; shadcn has none) - concern.
- Parts touched (additive, found by ED6 at large text): PlanListRow content and PlanSegmented label wrapped in Flexible (the ShadButton row does not constrain its child; overflow at 1.5x/2.0x).
- test/l10n/shadcn_words_test.dart: kAllowedShad += ShadSeparator.

## Icon table (old -> new)
note_add_outlined -> LucideIcons.filePlus; folder_open_outlined -> folderOpen; save_outlined -> save; save_as_outlined -> saveAll; ios_share_outlined -> share; print_outlined -> printer; undo -> undo; redo -> redo; menu -> menu; tune -> slidersHorizontal; category_outlined -> shapes; warning_amber -> triangleAlert; format_color_fill -> paintBucket. (Tool icons `e.icon` come from generic_tools.dart/kits, outside the three files: still Material IconData.)

## Rulings
See rulings.md (R-IconButton, R-Tooltip, R-ListTile, R-CheckboxListTile, R-allow, apps). Each rewritten finder keeps its key.
- R-IconButton: editor_words_test.dart:62-68, editor_options_test.dart:341, plan_editor_test.dart:39-40 (used 367-469).
- R-Tooltip: plan_editor_test.dart ED-5 ~225: Tooltip.message -> bySemanticsLabel(planDamaged) under ensureSemantics.
- R-ListTile: plan_tool_palette_test.dart:21-29, palette_draw_test.dart:222-262, integration architecture_palette_test.dart:88-96, restaurant_demo editor_profiles_test.dart:65, host_chrome_test.dart:99.
- R-CheckboxListTile: plan_tool_palette_test.dart:128-131, palette_draw_test.dart:55-57.
- apps: architecture_demo toolbar-* IconButton -> PlanIconButton (open-sample stays Material).

## Mutation M-ED1
Compact palette button wrapped in `ShadTheme(data: planShadThemeFrom(Theme.of(context)), child: ...)` (the selected tool reads the Material scheme's secondaryContainer): ED1 `Expected: true  Actual: <false>` (`00:01 +0 -1: ... ED1 ... [E]`). Reverted; ED1 green.

## Gates (real last lines)
- plan: flutter test `+1661 ~7 -3: Some tests failed` (TF8, TF9, V10); analyze `No issues found!`; format `Formatted 83 files (0 changed)`.
- integration: `+104 -1` (colour_row_test CP1 only); analyze clean; format 0 changed.
- restaurant_demo: `All tests passed!` (112). architecture_demo: last full run `+167 -9` (EX2, EX3, DH3, DH4, EX6, RP1, DO6, RN1, RN3).
- tool/ci: `00:59 +122: All tests passed!`; check_api_boundary: clean.

## Open (needs a ruling): 14 tests that depend on a lingering frame
Plan TF8, TF9 (unit_fill_test, "the change asks for a frame"), V10 (editor_service_view_test:561-563, second Print tap), integration CP1 (colour_row_test:272), architecture_demo EX2 EX3 DH3 DH4 EX6 RP1 DO6 RN1 RN3 (dirty bullet / replace-dialog one pump late).
Cause (verified): with the old Material palette (reverting only plan_tool_palette.dart makes CP1 green; debugPrintScheduleFrameStacks showed `Ticker.scheduleTick` in the old tree, `hasScheduledFrame` true before the change), an unfinished finite animation never completed under zero-duration `pump()`, so each pump drew one more frame. The shadcn palette has none, so a change delivered by the dispatcher's async stream needs one more `await tester.pump()` before it shows. Product behaviour is unchanged (a real frame always follows). Proposed fix, not applied (not an allowed mapping): one extra `await tester.pump()` at those points (and in `nextFrame` relax/replace the hasScheduledFrame premise).

## Concerns
- The 14 above. Drawer scrim still reads Material `colorScheme.scrim`. Tool icons from generic_tools/kits remain Material IconData. The damaged-warning word is no longer in a Tooltip, so the leak collector sees it only through the semantics label (its text still comes from PlanStrings).

## Fix round 1 (R-FRAME)
`await tester.idle();` inserted before the pump that should show the change (no extra pump, no assertion touched); nextFrame's first pump replaced by idle, doc comment updated. Sites in rulings.md R-FRAME. Also fixed a missed type read in architecture_demo document_replace_test `enabled` (open-sample is a Material IconButton).
Premise mutation: removing nextFrame's idle -> TF8 `Expected: true Actual: <false> the change asks for a frame`, `+0 -1 ... TF8 ... [E]`; restored.
Gates (real last lines): plan `03:59 +1696 ~7: All tests passed!`, analyze `No issues found!`, format `Formatted 83 files (0 changed)`; integration `03:01 +240: All tests passed!`, analyze clean, format 0 changed; restaurant_demo `01:49 +112: All tests passed!`; architecture_demo `00:37 +176: All tests passed!`, analyze clean; tool/ci `00:59 +122: All tests passed!` (one parallel run printed only a stack-trace hint; the solo rerun is green).

## Fix round 2
PlanTooltip (icon_button.dart): ShadTooltip + Semantics(container, label) + PlanWordsCarrier(visibleWords [message]); PlanIconButton reuses it (one tooltip construction); the damaged warning uses it (key plan-damaged on the Icon). Tests: SW5 (ShadTooltip only under lib/src/chrome/), LK1x damaged warning (PlanTooltip word is collected).
Mutations: raw ShadTooltip back in plan_editor.dart -> SW5 red (`+2 -1: SW5 ... [E]`); visibleWords emptied -> LK1x damaged warning red (`+0 -1 ... [E]`); both restored.
Gates: plan `04:35 +1698 ~7: All tests passed!`, analyze clean, format 0 changed; integration `03:27 +240`; restaurant_demo `02:15 +112`; architecture_demo `02:37 +176`; tool/ci `01:13 +122`; api boundary clean.
