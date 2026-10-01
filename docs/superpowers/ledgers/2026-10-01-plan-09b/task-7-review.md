# Task 7 review (independent) — 67688a1
Status: in progress
- Diff c975d1d..67688a1: only apps/floor_planner/lib/symbols/symbol_place_tool.dart and its test.
- onKey (symbol_place_tool.dart:205-236) read against spec D6 Keys (spec :266-277): inert -> ignored; key-up -> ignored; R/M without Ctrl/Meta/Alt -> handled, KeyDown steps (R +1, Shift+R -1, `% 4` is non-negative in Dart; M toggles) + notify, repeat no effect; not pressed -> ignored (Esc reaches the shell's _escape); pressed: Esc KeyDown -> cancel, F/F3 KeyDown without modifier -> ignored, else handled. Matches the spec and PlacementTool's pattern (placement_tool.dart:177-215).
- Commit (:260-264): needs.every(permissions.allows) before placeSymbol; matches spec :306-309 / Ruling 05-3.
- App gate (real): `03:32 +857: All tests passed!`; `No issues found!`; `Formatted 149 files (0 changed)` fmt=0; `✓ Built build/web`.
- M-09b3 R wrong way (:215): RED x2 (Expected 1 Actual 3). Shift+R as R (:215 `? 1 : 1`): RED x2. M no mirror (:218): RED x2. M-09b5 (:227): RED (Expected false Actual true). restored diff=0 each
- M-09b20 (:211): RED (Expected ignored Actual handled). M-09b21 (:213): RED (Expected 1 Actual 3). M-09w geometry (:82): RED "a denied geometry". restored diff=0 each (my first structure mutant `;` did not compile; re-fired below)
- M-09w structure (:81): RED. components (:83): RED. M-09b2 placeSymbol before the check (:261): RED x3 (Expected seed 18 Actual 23). restored diff=0 each
- HUNT key-up of R/M consumed (:206): RED. Esc consumed armed-idle (:224): RED. turns not normalised (:216): RED (Expected 3 Actual -1). Ctrl+F bubbles mid-press (:231): RED. restored diff=0 each
- HardwareKeyboard leak check: the file run with --test-randomize-ordering-seed 1, 2, 3: `+28: All tests passed!` each; `holding` releases in finally.
- Expectations: placementTransform (09a's placer function, as the plan asks) plus hand literals for R ([0,1,-1,0]) and Shift+R ([0,-1,1,0]); the mirror has no hand literal here (Task 5's test hand-derives mirror-then-turn) — note. Fixtures: R,R,M (2 turns + mirror) and R+M (1 turn + mirror) placements at ~(81377,-36904)/(76402,-45518), base point off origin, camera 0.05.
- F-16: the permission tests assert handleSeed unchanged and no throw; the dispatcher alone would throw PermissionDeniedError after allocating (M-09b2: seed 18 -> 23), so the tool's own check is what is measured.
- Final git status --short: empty.

## Verdict: Approved
Notes (no fix required): 1. R-B7-1 accepted: Shift+M toggling is within spec (only Ctrl/Meta/Alt excluded); Ctrl+R swallowed mid-press follows the spec's "mid-press every other key is swallowed" (spec :272-273) over "Ctrl+R passes through" (:269-270); harmless, idle passes it; key-ups bubbling matches PlacementTool (placement_tool.dart:185). 2. The mirror's expected transform is not hand-literal in this file (covered by Task 5's hand derivation).
