# Task 6 report — the exit

Implementer, 2026-10-04, from `9c09121`.

- Gates at `9c09121` (CI=true, logs scratchpad tg-task6/gates/): render `01:08 +1304 ~1 -7` (standing 7 text-ladder goldens); planner `03:52 +1278`; symbols `+94`; app `+201`; demo `00:17 +23`; harness `+82`; engine `00:22 +1241 -2` (standing pair). analyze "No issues found!" and format "0 changed" everywhere. `git diff 4490cd9 -- packages/jet_cad_2d_flutter packages/jet_cad_2d` = 0 bytes.
- Web: floor_planner `83.1s / ✓ Built build/web`; restaurant_demo `61.0s / ✓ Built build/web`; nocdn `62.5s / ✓ Built build/web_nocdn`.
- Smoke: 10 PNGs in docs/superpowers/notes/2026-10-04-table-groups/ (light: merge, grow, bill, mid-drag, released, split; dark: merge, bill; Blueprint bill; light at the default fit). Driver tg-task6/drive.js + mk.py.
- Found in the smoke: at the default fit the chip covers the members' upper chair lines (margin ~6 px, chip keeps screen size). Recorded as debt.
- Spec: "## Amended at execution" before the Revision log. Results note written. STATUS top block replaced.
