# 4b prompts for OpenCode (weekend, free models)

Run them in this order: P1 → P2 → P3 → P4 → P5 → P6. P7 can run any time.
Each prompt runs in its own worktree and branch, cut from local `main`.
The shared rules are in `AGENTS.md`; paste each prompt as it is.

---

## Common rules

The rules every prompt relies on live in `AGENTS.md` ("Rules for every agent
session"), which OpenCode reads on its own. The prompts below carry only the
task.

---

## P1. Inventory before removal (read-only, no code changes)

```text
Worktree: git worktree add .claude/worktrees/4b-inventory -b chore/4b-inventory main

Task: 4b removes packages/jet_cad_floor_plan, packages/jet_cad_restaurant_symbols and
apps/floor_planner (umbrella spec docs/superpowers/specs/2026-10-13-kit-architecture-design.md,
A10-A12; docs/superpowers/specs/2026-10-16-restaurant-kit-design.md, "Out of scope").
Before anything is deleted, map every dependency on them. Change NO code.

Do:
1. `git grep -n -E "jet_cad_floor_plan|jet_cad_restaurant_symbols|floor_planner"` outside those three
   directories and outside docs/superpowers. Group the hits by file.
2. For each hit, classify:
   - DEP: a pubspec dependency or dev_dependency
   - IMPORT: a Dart import (name the imported symbols)
   - TEST-ORACLE: a test that uses the old package as a reference to compare the new one against
   - CI: .github/workflows/ci.yml, tool/ci/*
   - DOC: README, CHANGELOG, host guide, .vscode
   - OTHER
3. For each IMPORT and TEST-ORACLE, propose one action: delete the test (only if the same behaviour is
   tested on the new packages; name that test file:line), port it to the new API, or keep a copied
   fixture. Do not decide alone if unsure: mark it QUESTION.
4. List what tool/ci checks (SC*, DL*, check_readmes, check_screenshots, check_host_lock) will break
   and why.

Write the result to docs/superpowers/notes/2026-10-17-4b-removal-inventory.md as a table.
Commit only that file: "docs: 4b removal inventory".
```

---

## P2. Remove the old packages, apps/floor_planner and the old host probe (revised after P1)

Before this: `chore/4b-inventory` is merged into `main` (so the inventory is visible).
The old host probe depends on the removed packages, so it goes here too; P3 shrinks to a check.

```text
Worktree: git worktree add .claude/worktrees/4b-remove -b chore/4b-remove-old main

Read docs/superpowers/notes/2026-10-17-4b-removal-inventory.md first; it is your map.
Task: delete packages/jet_cad_floor_plan, packages/jet_cad_restaurant_symbols, apps/floor_planner
AND the old host probe (tool/ci/old_host_probe/, old_host_probe.sh, old_host_probe_resolve.sh,
`--old` + oldProbedFromCommit in check_host_lock / lib/host_lock.dart, the two *_split.lock.txt
fixtures and their tests), then make the workspace green. Follow the inventory's §3 and §4 rows.

Decisions on the inventory's QUESTION rows (binding):
- tool/screenshots/test/planner_scenes_test.dart: DELETE it (its pictures belong to the removed
  package; new pictures are a later task).
- tool/screenshots/test/renderer_scenes_test.dart: KEEP and port it to the new API with the names
  in the inventory. symbolThumbnailDocument is not exported (src/ only) — do not import src/.
  Scene R5 (searchSymbols/symbolIdOf): if its PNG is referenced by a README, rewrite it on the
  public gallery widget so the picture shows the same thing; if not, delete the scene. Say which.
  Any regenerated PNG: open it and describe it in the report.
- tool/screenshots/pubspec.yaml: swap the old deps for jet_cad_2d_plan + the two kits; font asset
  packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf.
- harness_test.dart SH3: point it at jet_cad_2d_flutter.
- check_screenshots.dart: only ['jet_cad_2d_flutter'] for now.
- tool/readme_probe: delete lib/planner.dart, its dependency, and the planner case + yaml input in
  check_readmes.dart and readmes_test.dart (RM4).
- DL2, SC17 and any other count: re-derive the number by reading the files, change the number and
  its `reason:` text together; never delete such an assertion.
- Provenance comments (inventory §5): leave them.
- README/STATUS/host-guide prose (DOC rows): only fix what would now be false
  (published-packages tables, "adds only jet_cad_floor_plan", the font attribution, the two
  restaurant_demo comments, .vscode). Keep CHANGELOGs and STATUS-HISTORY as history.

Gates: `flutter pub get` at the root; tests/analyze/format in every package and app of the
workspace (list each with its real last line); `cd tool/ci && dart test`; `bash tool/ci/host_probe.sh`;
`dart run tool/ci/check_guide.dart`; `dart run tool/ci/check_readmes.dart`;
`dart run tool/ci/check_screenshots.dart`.
Report: docs/superpowers/notes/2026-10-17-4b-remove-report.md.
```

---

## P3. CI check (optional; the controller can do it while reviewing P2)

```text
Worktree: git worktree add .claude/worktrees/4b-ci -b chore/4b-ci main   (after P2)

Check, change only if wrong: every live package under packages/ (each with a pubspec, less the
dormant packages/jet_cad) is in both matrices of .github/workflows/ci.yml (test and publishable);
no step names a removed directory or old_host_probe; `bash tool/ci/host_probe.sh` and
`cd tool/ci && dart test` pass. Report: docs/superpowers/notes/2026-10-17-4b-ci-report.md.
```

---

## P4. Versions and dependency floors

```text
Worktree: git worktree add .claude/worktrees/4b-floors -b chore/4b-floors main   (after P3)

Context: umbrella spec A10 (docs/superpowers/specs/2026-10-13-kit-architecture-design.md).
jet_cad_2d and jet_cad_2d_flutter changed in 4a (drag snap `exclude` seam; see their CHANGELOG
"Unreleased"), so they are released in the wave. New packages: jet_cad_2d_kit 0.1.0,
jet_cad_2d_plan 0.8.0, jet_cad_2d_kit_architecture 0.1.0, jet_cad_2d_kit_restaurant 0.1.0.

Task:
1. PROPOSE (do not decide) the new versions of jet_cad_2d and jet_cad_2d_flutter: read each
   "Unreleased" CHANGELOG section and the public API diff since tag `jet_cad_2d-v0.7.2`
   (`git diff jet_cad_2d-v0.7.2..main -- packages/jet_cad_2d/lib`). Additive in 0.x → say whether
   you suggest a patch or a minor bump and why. Write the proposal into the report and STOP before
   changing versions. The human picks.
2. After the human's answer (a follow-up prompt): set the versions, turn "Unreleased" into the
   version heading, and raise every dependent's caret floor (`jet_cad_2d: ^X.Y.Z`) to the version
   that contains the APIs it uses. Update tool/ci DL2's expected caret and count.
3. Lower-bound check: for jet_cad_2d_plan and each kit, run `flutter pub downgrade` in the package,
   then its tests, then `flutter pub upgrade`. Report any failure as a floor that is too low.
4. `flutter pub publish --dry-run` (dry-run ONLY) for every package in the wave: 0 warnings each.

Report: docs/superpowers/notes/2026-10-17-4b-floors-report.md.
```

---

## P5. README pictures

```text
Worktree: git worktree add .claude/worktrees/4b-pictures -b chore/4b-pictures main   (P2 is merged; can run beside P4)

Context: umbrella spec A11 "README pictures show what the package itself gives". Screenshots come from
tool/screenshots (read tool/screenshots/README.md and its tests; regenerate with
`cd tool/screenshots && UPDATE_SCREENSHOTS=1 flutter test`). tool/ci/check_screenshots.dart and
check_readmes.dart check them.

Task:
- jet_cad_2d_plan: pictures of its widgets with the architecture kit (a plan with walls, rooms,
  doors, windows and furniture).
- jet_cad_2d_kit_architecture: pictures of its types.
- jet_cad_2d_kit_restaurant: the Salon (apps/restaurant_demo/lib/samples/salon.dart) and the
  Symbols gallery with its section.
Add scenes to tool/screenshots for each, generate the PNGs, reference them in each package README
with the same pattern the existing READMEs use (absolute raw.githubusercontent URLs if that is the
pattern; check jet_cad_2d's README). Remove scenes and PNGs of jet_cad_floor_plan.
Each README's package table lists the new packages. Its "host guide" link points to docs/host-guide.md
(which now describes jet_cad_2d_plan).
- jet_cad_2d_flutter: its README's gallery picture (scene R5 in tool/screenshots/test/renderer_scenes_test.dart,
  symbol_gallery.png) now shows jet_cad_2d_plan's PlanSymbolGallery, which breaks A11 (a package's pictures show
  what the package itself gives). Either render the renderer's own public SymbolGallery (barrel only, no src/
  imports), or drop that picture from jet_cad_2d_flutter's README and use it in jet_cad_2d_plan's. Say which and why.
Look at every PNG you generate (open it) and describe each one in the report in one line.
Gates: tool/screenshots tests, check_screenshots, check_readmes, tool/ci tests,
publish --dry-run of each touched package (0 warnings).

Report: docs/superpowers/notes/2026-10-17-4b-pictures-report.md.
```

---

## P6. Release checklist

```text
Worktree: git worktree add .claude/worktrees/4b-release -b docs/4b-release-checklist main   (after P4, P5)

Task: write docs/superpowers/notes/2026-10-17-4b-release-checklist.md, the human's step-by-step list
for the wave (umbrella A10). Use the earlier release ledgers as the model:
docs/superpowers/ledgers/2026-10-13-release-0.7.0/ and 2026-10-13-publish-host-packages/.
For each package, in A10's order (jet_cad_2d, jet_cad_2d_flutter, jet_cad_2d_kit, then
jet_cad_2d_plan, jet_cad_2d_kit_architecture, jet_cad_2d_kit_restaurant):
version, CHANGELOG heading, the dry-run command, the publish command (for the HUMAN to run),
the tag name `<package>-v<version>`, the pana lower-bound check once its dependencies are on pub.dev,
and after the wave: mark jet_cad_floor_plan discontinued on pub.dev, replaced by jet_cad_2d_plan.
Do NOT run any publish. Run every dry-run and paste the real last lines.
Also update STATUS.md: 4b state and the resume point.
```

---

## P7. Small look fix: the status caption overlaps a chair

```text
Worktree: git worktree add .claude/worktrees/fix-caption -b fix/status-caption main

Bug: in apps/restaurant_demo (Service mode, Salon), table 2's status caption ("Bill") is drawn over
the lower chair (see docs/superpowers/notes/2026-10-16-restaurant-kit-pos.png). Find where the
status caption is placed (start in apps/restaurant_demo/lib/statuses.dart and the plan library's
unit label / caption painting in packages/jet_cad_2d_plan). Decide whether it is a demo or library
issue; say which in the report.
Fix so the caption does not overlap the table's chairs, for any rotation of the table.
Write a test that fails before the fix (a table rotated by 90 degrees too, not only the identity),
then fix, then show the test passes. Name one mutation that turns the test red and run it.
Report: docs/superpowers/notes/2026-10-17-fix-caption-report.md.
```
