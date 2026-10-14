# Audit: 2a deferrals to 2b versus the 2b plan

Sources: 2a briefs (`docs/superpowers/ledgers/2026-10-14-plan-library-2a/task-*-brief.md`, grep `2b`), the 2a results note
(line 262: "the table, service-bar and selection-mode halves to 2b"; no itemised list), progress.md/final-review.md (parked items).
Source paths are under `packages/jet_cad_floor_plan/test/`. Plan = `docs/superpowers/plans/2026-10-14-plan-library-2b.md` (line numbers).
Lines for some MISSING rows are approximate (start of the test to the next test).

| # | id | source file:lines | what | status | 2b task / plan line |
|---|----|---|---|---|---|
| 1 | SW1 table half | symbols/symbol_section_test.dart:398-422 | table shows a number field / table half of SW1 | MISSING | belongs in Task 10 |
| 2 | SW4 table half | symbols/symbol_section_test.dart:473-498 (assertions :484-487, last table selection) | a table turns under runtime, in design only | MISSING | Task 10 |
| 3 | SW6 | symbols/symbol_section_test.dart:519-561 | corner unit turned 37 then mirrored, number kept | PLACED | Task 10, L10935 |
| 4 | SW9 | symbols/symbol_section_test.dart:598-626 | rotation typed under runtime commits to pinned target | PLACED | Task 10, L10935 |
| 5-10 | CP7-CP12 | colors/color_picker_test.dart:640-end | colour row over tables | PLACED | Task 10, L10934 |
| 11 | HR2 | hover_removal_test.dart:58-end | hovered table, view removed | PLACED | Task 10, L10936 |
| 12 | SE1 | l10n/stale_error_test.dart:70-88 | table number error re-worded on language switch | PLACED (as SE1L) | Task 10, L10933 |
| 13 | VW2 | l10n/value_words_test.dart:64-75 | table-number problems in 3 languages | PLACED | Task 10, L10932 |
| 14 | VW3 | l10n/value_words_test.dart:76-92 | numbering warnings | PLACED | Task 10, L10932 |
| 15 | VW4 | l10n/value_words_test.dart:93-114 | controller numbering warnings | PLACED | Task 9, L9642 |
| 16 | SW2 service half | l10n/shell_words_test.dart:55-64 | German/English tooltips on service-undo, service-print | MISSING | Task 16 (service bar) |
| 17 | LK1 service-bar lines | l10n/leak_test.dart:108-183 | Turkish service bar bypasses no strings | MISSING (plan L10939 covers only LK2) | Task 16 |
| 18 | G-5 overlay tests | host/floor_plan_theme_test.dart:833-880 | overlays rebuild only at a host rebuild | PLACED | Task 16, L17327 |
| 19 | T1-a | host/floor_plan_theme_test.dart:374-400 | text styles merge | PLACED | Task 15, L17243 |
| 20 | R-3 | host/floor_plan_theme_test.dart:457-505 | style lerp | PLACED | Task 15, L17243 |
| 21 | TH4 overshoot (4 assertions) + edgeA/edgeB | host/floor_plan_theme_test.dart:253-, :432-436 | lerp past ends clamps statusFillOpacity, tableColorOpacity, groupChipPadding, statusCaptionStyle | MISSING (17243 names neither R-1 nor edge themes) | Task 15 |
| 22 | NS5 | host/new_plan_separator_test.dart:348-~375 | plan shown first in selection mode settles design to comma | MISSING | Task 11 (mode) |
| 23 | NS1 serviceLayoutChanges assertion | host/new_plan_separator_test.dart:191-201 (NS5 :356) | nothing fires on serviceLayoutChanges | MISSING | Task 13 (serviceChanges) |
| 24 | C8 service half (+C3,C4,C5,CD1) | host/controller_test.dart:143-233, :304-328 | mode tests | PLACED | Task 11, L12339 |
| 25 | DC1-6, DC14 table detail | host/design_changes_test.dart | unitChanges | PLACED | Task 9, L9637 |
| 26 | DC7 | host/design_changes_test.dart:315-366 | service drag in selection mode | MISSING (L9637 says Tasks 11/14 but neither names it) | Task 11 or 14 |
| 27 | DC10 | host/design_changes_test.dart:404-420 | PlanReplaced in selection mode | MISSING | Task 11 |
| 28 | DC15 | host/design_changes_test.dart:607-637 | listen after a service move | MISSING | Task 11 |
| 29 | DC16 | host/design_changes_test.dart:638-653 | trigger alone, service moves | MISSING | Task 11 |
| 30 | CM7 fitToTables half | host/camera_test.dart:230-239 | fit to tables | PLACED | Task 9, L9640 |
| 31 | dark_canvas selection-mode run | dark_canvas_test.dart:81-223 (selection iteration) | dark canvas in selection mode | MISSING (no dark_canvas in plan) | Task 16 |
| 32 | theme_canvas selection-mode runs | host/theme_canvas_test.dart:217-262, :310, :457-474 (P-6, M-H33 x2, selectionOnDark, only selectionOnLight, R-1) | theme on canvas in selection mode | MISSING | Task 16 |
| 33 | PF2 selection half | host/page_flows_test.dart:217-226 | exportPlan PNG in selection mode | MISSING (no PF ids in plan) | Task 15/16 |
| 34 | PF17 | host/page_flows_test.dart:719-737 | export settles pending table number first | MISSING | Task 10/16 |
| 35 | PF23 last block (S-22) | host/page_flows_test.dart:~920-936 | selection mode never refused on export | MISSING | Task 16 |
| 36 | floor_plan_theme resolution selection runs, ServiceView tests | host/floor_plan_theme_test.dart:673-783, :832-1020 | | PLACED | Task 16, L16312 |
| 37 | TF6, TF7 tail | table_fill_test.dart:650-673, :735-755 | | PLACED (TF7b) | Task 16, L16312 |
| 38 | export table colours (PC-7) | export_bytes.dart:35-51 | fills under the drawing | PLACED | Task 15, L16946, L17294 |
| 39 | keyboard_focus service cases | host/keyboard_focus_test.dart:301-340, 341-363, 494-517, 629-658, 768-786, 787-851 | | PLACED | Task 16, L19290 |
| 40 | KB T6-c | host/keyboard_focus_test.dart:467-493 | tablesOnly: Delete/Backspace reach host | MISSING | Task 8 (unitsOnly) |
| 41 | KB RP1 tablesOnly variant | host/keyboard_focus_test.dart:854-885 | tablesOnly letters/keys | MISSING | Task 8 |
| 42 | KB RP12 | host/keyboard_focus_test.dart:886-909 | tablesOnly, table armed | MISSING | Task 8 |
| 43 | service bar tests, mergeCandidate | host/bars_test.dart:73-159 | | PLACED | Task 16, L20080, L12971 |
| 44 | canvas re-measured group | host/bars_test.dart:998-1090 | | PLACED | Task 16, L19288 |
| 45 | editor_theme non-generic field cases | host/floor_plan_theme_test.dart:573-671 | | PLACED | Task 15, L17243 |
| 46 | readOnly (V-5) table part | host/editor_panels_test.dart:282-329 | no command reaches the document, table parts | MISSING (no match in plan) | Task 8 or 10 |
| 47 | selectTablesOnly, renumber, stale-drag rule | planner_shell.dart:1077-1084 | code/permissions | PLACED | Task 8, L7315, L7325 |
| 48 | table section words, table inspector | selection_panel.dart:1201-1242, planner_shell.dart:1555-1566 | | PLACED | Task 10, L10654 |
| 49 | parked: old controller's snappingAllowed after a swap | 2a final-review.md:225 | | MISSING (not in plan) | Task 16 |
| 50 | parked: remounting PlanShortcuts reopens idleKeys | 2a progress.md:180 | | UNCLEAR (ServiceHost.idleKeys exists, no test names the remount) | Task 16 |

Counts (rows 5-10 count as six items): 50 deferred items; PLACED 28, MISSING 21, UNCLEAR 1.
