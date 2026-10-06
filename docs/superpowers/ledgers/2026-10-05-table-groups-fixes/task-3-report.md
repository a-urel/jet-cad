# Task 3 report — the exit

Status: done. Commit `402a775` "docs(table-groups): fixes Task 3 — results, STATUS" (on `7a96dc5`; not pushed).

## Files
- docs/superpowers/notes/2026-10-05-table-groups-fixes-results.md (new)
- docs/superpowers/notes/2026-10-05-table-groups-fixes/ (6 PNGs: demo_fit_1_merge, demo_fit_2_grow, demo_fit_3_bill, demo_fit_dark_3_bill, demo_zoom_3_bill, demo_fit_before_after_crop)
- STATUS.md (top block replaced; table groups Debt line annotated)

## Gates (at 7a96dc5, CI=true, Flutter 3.47.6; logs scratchpad/tgf-task3/gates/)
| Package | test | analyze | format |
|---|---|---|---|
| jet_cad_floor_plan | `05:59 +1283: All tests passed!` (+5 on +1278) | No issues found! | 208 (0 changed) |
| apps/floor_planner | `02:32 +201: All tests passed!` | No issues found! | 44 (0 changed) |
| apps/restaurant_demo | `00:27 +28: All tests passed!` (+4 on +24) | No issues found! | 3 (0 changed) |
| jet_cad_restaurant_symbols | `00:03 +94: All tests passed!` | No issues found! | 13 (0 changed) |
| apps/dev_harness_2d | `00:54 +82: All tests passed!` | No issues found! | 22 (0 changed) |
| jet_cad_2d_flutter | `01:52 +1304 ~1 -7: Some tests failed.` (standing 7 text ladder goldens) | No issues found! | 218 (0 changed) |
`git diff 3753ca4 -- packages/jet_cad_2d_flutter packages/jet_cad_2d` = 0 bytes.

## Web builds (apps/restaurant_demo)
- release: `Compiling lib/main.dart for the Web...  116.7s` / `✓ Built build/web`
- no-CDN: `104.0s` / `✓ Built build/web_nocdn`

## Smoke
drive.js reused (port 8713); fit light, fit dark, zoom 7 steps. No page errors, no external requests. Descriptions in the results note.
