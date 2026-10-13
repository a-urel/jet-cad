# Task 6 report

Status: DONE_WITH_CONCERNS. Commit: 4712baab28b2494205b442d538ccbb864d870156 (single commit, no amend).

## Steps
1. SC22 added (ruling R-8); red: "Could not find file `package_root.dart`" (exit 255). package_root.dart written, SC22 green. Added to ci-tools analyze and format lists in ci.yml.
2. Template rewritten verbatim from brief (hosted ^0.7.1 + four git overrides, asset entry, sdk ^3.6.0).
3. host_probe.sh: header, clean line, `--ref "$ref"`, copy block; .gitignore; SC14 updated (the rm line spans two script lines, so SC14 asserts both).
4. main.dart: restaurant import replaced, readRestaurantLibrary/restaurantSource added, loader updated, header comment.
5. Guide: section 1 rewritten, "### The restaurant symbols" added (R-7), section 4 loader line changed.
6. guide_test GD1/GD3/GD4 as in brief.
7. Probe and old probes run (below). M-PR1 run.

## Results
- Probe: exit 0; lock check "40 packages, none of flutter_scene, ...", "No issues found!", "✓ Built build/web", "host probe: no GPU renderer, no build hook; build/web is 42M". Note: only ONE lock-check line printed, not two as the brief expects.
- Old probes v0.3.0, v0.4.0, v0.5.1, v0.6.0: each "No issues found!", "old host probe: vX's main.dart analyses against 4712baab...".
- git status clean after the probes.
- M-PR1 (override for jet_cad_2d_flutter removed): resolution failed first, exit 69:
  "Because every version of jet_cad_floor_plan from git depends on jet_cad_2d_flutter any which doesn't exist (could not find package jet_cad_2d_flutter at https://pub.dev), jet_cad_floor_plan from git is forbidden. So, because host_probe depends on jet_cad_floor_plan from git, version solving failed."
  Restored, `cmp` OK. Lock check was not reached.
- Gates: tool/ci dart test +77 all passed; analyze (CI file list) no issues; format 0 changed; check_guide "all 56 code blocks are in the host probe"; jet_cad_floor_plan flutter test +2007 ~4 all passed, analyze no issues.

## Guide mentions
- jet_cad_restaurant_symbols: git YAML block removed; package-barrel import sentence removed; paths remain only in the new subsection (file source paths).
- restaurantSymbolSource: section 4 block changed to restaurantSource; new subsection names it only in the "never load the copy with it" rule.
- git / SHA / 0fa649e / "Why a SHA", restaurant-at-tag paragraph, engine-on-pub.dev sentence: all removed (lines 17-56 old). No other mentions found.
- check_guide.dart needs no change (reads yaml/dart blocks only; 56 blocks match).

## Deviations
- SC22 name (R-8). SC22 compares resolved symlinks on both sides (macOS /var vs /private/var made the brief's assertion fail). SC22 uses the existing dartRun helper.
- SC14 clean-line assertion split in two because commands are line-based.
- Subsection rule 2 wording: "you can change which library you ship without migrating saved plans" (I did not verify a stronger claim).
- `dart analyze` with no file list in tool/ci reports 3 errors in host_probe/lib/main.dart (missing restaurant_names.dart until the probe copies it). CI uses an explicit file list excluding it, which passes.

## Concerns
- Guide intro still says it covers release 0.7.0 while the dependency is ^0.7.1 (not in the brief; left).
- Guide's restaurant-files tag name `jet_cad_floor_plan-vX.Y.Z` taken from the brief; not verified against real tags.
- Probe passed only because of overrides; hosted 0.7.1 packages not yet on pub.dev.

## Fix round 1
Commit: ede728361b3a3a8bb0f90b442f1758029ab203d2 (on top of 4712baab).
- R-9: guide intro now "covers `jet_cad_floor_plan` **0.7.1**" linked to ../packages/jet_cad_floor_plan/CHANGELOG.md; Flutter sentence now "0.7.1 is built and tested with Flutter 3.47.6" (CI FLUTTER_VERSION is 3.47.6).
- SC22: package b rootUri is `file:///abs/b/`, expectation `/abs/b`. Mutant (the `.replaceAll(RegExp(r'/$'), '')` removed) went red:
  `Expected: '/abs/b'  Actual: '/abs/b/'  Which: is different ... trailing characters: /` (scripts_test.dart 165). Restored, `cmp` OK, SC22 green.
- Guide rules paragraph: added the loader-fails-on-same-key-and-version reason (F-8) and the paragraph that a symbols change reaches hosts with a planner release whose tag carries the files (D9); saved-plan sentence now cites that placing a symbol copies its definition into the plan (F-8). Prose only.
- Gates: tool/ci dart test "+77: All tests passed!"; analyze (CI list) "No issues found!"; format "Formatted 13 files (0 changed)"; check_guide "all 56 code blocks are in the host probe".
