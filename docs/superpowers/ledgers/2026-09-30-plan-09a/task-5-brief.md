# Task 5 brief — the content, the generator, the asset

You are the implementer of Task 5 of plan 09a. Work ONLY in the git worktree
/home/user/jet-cad/.claude/worktrees/plan-09 (branch plan-09/symbol-library-core, HEAD 478c6dc).
Read, in order: CLAUDE.md, the spec docs/superpowers/specs/2026-09-30-symbol-library-design.md (whole; D2, D5, D7, F-9, F-14, R-5 are
yours), and Task 5 plus "Global constraints", "Gates", "Rulings" (P-2, P-4, P-5) of
docs/superpowers/plans/2026-09-30-symbol-library-core.md. Read the Task 3 and 4 reports and code:
apps/floor_planner/lib/symbols/{symbol_component,symbol_library,symbol_placer}.dart, apps/floor_planner/test/support/symbol_fixtures.dart,
apps/floor_planner/lib/new_document.dart (prepareDocument adds the DASHED record at handle 6: the loader's allow-list refuses a LEAF using handle 6,
but check whether a library DOCUMENT containing the DASHED table record is acceptable; decide and say which, preferring not to include it),
packages/jet_cad_2d/lib/src/document/drafting.dart (linePayload, polylinePayload, circlePayload, arcPayload, rectanglePayload).
Follow Task 5 exactly. Content rules: about 24 symbols in six categories (Dining Room, Kitchen, Bed Room, Living Room, Bathroom, Office) per spec D7's list;
world units are millimetres, realistic sizes (double bed 1600x2000, dining chair 450x450, 4-seat table 1600x900, three-seat sofa 2000x900, fridge 600x650,
toilet ~400x700, bathtub 1700x750, ...); plain outlines plus a few interior detail lines so a thumbnail reads (e.g. pillows on a bed, burners on a hob, a seat
back on a chair); LINES, POLYLINES (open/closed), ARCS, CIRCLES only; no text, fill or point. Author each in a corner-origin local frame with a basePoint at the
centre or front-centre so basePoint != (0,0) for every symbol. Keys lower-case dotted (e.g. bed.double), category display strings as above, >= 2 lower-case tags
each, version 1. Leaf style: layer layerZero, BYBLOCK-friendly colour (ByBlockColor), lineweight kByBlock? (check what the loader's allow-list accepts and
what draws sensibly: a BYBLOCK lineweight resolves from the instance, whose default is also kByBlock -> document default; confirm by the end-to-end Task 6
later; choose the allow-list-legal value that resolves sensibly and record the reasoning). Handles ascending in catalog order.
The generator tool: apps/floor_planner/tool/generate_furniture_library.dart, run as `dart run tool/generate_furniture_library.dart` from apps/floor_planner
(it must not import Flutter: if buildFurnitureLibrary transitively imports a Flutter library, restructure so the tool runs under plain dart; prove you ran it).
Commit the generated asset apps/floor_planner/assets/library/furniture.jetlib and declare it in pubspec.yaml under flutter: assets:.
Tests per Task 5 (bytes of the built library == committed asset's; decode lists every catalog key; basePoint != (0,0) for every symbol; >= 2 tags; keys unique;
each symbol placed into a fresh prepareDocument at an off-origin point and quarter turn validates and its transformed bounds contain 'at'; building twice
gives identical bytes; the asset is declared in pubspec (read the pubspec in the test)). Mutants per Task 5 (a symbol authored with basePoint (0,0); a point/text
leaf added -> loader rejects; asset left stale), each fired with real output.
Also, since you generate ~24 symbols: add ONE render-level sanity check that each symbol's bounds are plausible in mm (between 100 and 4000 on each axis) so a unit slip is caught.

Environment: export PATH=/root/flutter/bin:$PATH ; prefix every test command with CI=true. Scratch prefix for mutant backups: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/t5/ (create it).
Mutation procedure: cp file to scratch backup, mutate ONE line, run the named test file, cp back, diff must exit 0. NEVER git checkout -- a .dart file.
Never commit analysis_options.yaml (stage by explicit path). Never synthesize output. Code/comments/commit messages in English. Commit trailers:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
Do not push. Gates: app 683 + new, engine 1121 + 2 standing, render 974 + 1 skip + 7 standing, analyze/format clean, PLUS `CI=true flutter build web --release` in apps/floor_planner
(real output). Report to /home/user/jet-cad/.claude/worktrees/plan-09/.superpowers/sdd/symbol-library-core/task-5-report.md: commit SHA, files, the final symbol list with sizes,
real gate tails, mutant matrix with real output lines, decisions, anything the spec got wrong.
