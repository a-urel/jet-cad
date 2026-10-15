# 2a deferrals the 2b plan missed — assignment (controller ruling, 2026-10-14)

Source: audit-2a-deferrals.md (same folder): 50 items deferred by 2a's briefs, 28 placed by the 2b plan, 21 missing, 1 unclear. Each missing item is ported in the task below, from `packages/jet_cad_floor_plan/test/…` (line ranges approximate unless stated — find the test by its id/title in the oracle). A12: assertions unchanged; fixtures, names, imports adapt (R-13: a renamed name inside an expected text follows the rename). If a premise is impossible under the 2b spec, do not port it: report it with the spec line, for a ledger ruling.

## Task 10 (fix round)
- SW1 table half — symbols/symbol_section_test.dart:398-422 (the table number shown in the panel) → test/panels/symbol_section_test.dart (2a's file).
- SW4 table half — same file :473-498, table assertions :484-487 and its last table selection ("a table turns in the design mode only") → same file.
- keyboard_focus_test.dart T6-c (:467-493), RP1's tablesOnly variant (:854-885), RP12 (:886-909) — the units-only key cases → the 2a keyboard/focus test file in jet_cad_2d_plan (tablesOnly → unitsOnly / selectUnitsOnly).
- editor_panels_test.dart readOnly (V-5) table part (:282-329) → 2a's editor panels test file.

## Task 11
- design_changes_test.dart DC7 (:315-366), DC10 (:404-420), DC15 (:607-637), DC16 (:638-653) — the service-mode change stream (plan line ~9637 says "Tasks 11 and 14" but neither names them).
- new_plan_separator_test.dart NS5 (:348-) — a plan first shown in the selection mode settles to the comma.
- (also carried from Task 9) TD8's setMode tail, HD6's and TC7's service-copy blocks.

## Task 13
- new_plan_separator_test.dart NS1's serviceLayoutChanges assertion (:191-201).

## Task 15
- floor_plan_theme_test.dart TH4's overshoot (:253- and :432-436) — lerp clamps the four 2b fields (edgeA/edgeB themes).

## Task 16
- shell_words_test.dart SW2's service half (:55-64) — German/English tooltips on service undo and service print.
- leak_test.dart LK1's service-bar lines (:108-183) — the Turkish service bar bypasses no strings.
- dark_canvas_test.dart selection-mode run (:81-223).
- theme_canvas_test.dart selection-mode runs (:217-262, :310, :457-474; P-6, M-H33, R-1).
- page_flows_test.dart PF2's selection half (:217-226), PF17 (:719-737, export settles a pending table number), PF23's last block S-22 (~:920-936, the selection mode never refused).
- 2a's parked final-review item (docs/superpowers/ledgers/2026-10-14-plan-library-2a/final-review.md:225): the old controller's snappingAllowed after a swap.
- UNCLEAR (2a progress.md:180): a PlanShortcuts remount reopening idleKeys — ServiceHost.idleKeys exists in the plan; add a test that pins it if PlanServiceView/PlanEditor's mode switch remounts PlanShortcuts.

## Moved by Task 11 (controller ruling)
- Task 13: DC15 (design_changes_test.dart :607-637) and NS5 (new_plan_separator_test.dart :348-) — they need serviceEdited / serviceChanges / the record / reset.
- Task 14: DC7 (design_changes_test.dart :315-366) — it drags with the service tool.
