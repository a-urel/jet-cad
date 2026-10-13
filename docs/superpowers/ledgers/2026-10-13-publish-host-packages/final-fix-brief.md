# Final fix wave — feat/publish-host-packages (BASE c660947)

The final whole-branch review said "With fixes". Apply exactly these items. Each item carries the controller's ruling where one applies (the ledger, progress.md, has R-1..R-13).

## F1 (Important) STATUS.md, Resume here, the D7 step after the planner's publish

As written it cannot work. The probe's `lib/main.dart` imports `restaurant_names.dart`, and its pubspec declares `assets/restaurant.jetlib`. Both are git-ignored files that only `host_probe.sh` creates, from the overridden package, so they are absent once the overrides are removed.

Spell out the human's exact commands, one per fenced `bash` block or as a short numbered list, from the repository root on `main` after the planner's publish:

1. Copy `packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib` to `tool/ci/host_probe/assets/restaurant.jetlib`.
2. Copy `packages/jet_cad_restaurant_symbols/lib/src/names.dart` to `tool/ci/host_probe/lib/restaurant_names.dart`, verbatim (F5).
3. Write `tool/ci/host_probe/pubspec.yaml` from `pubspec.yaml.in` with the whole `dependency_overrides:` block removed. No `@URL@` or `@REF@` then remains; check it.
4. `cd tool/ci/host_probe && flutter pub get`.
5. `dart run ../check_host_lock.dart pubspec.lock` without `--ref`, which keeps the no-GPU check.
6. `flutter analyze`, expecting "No issues found!", and optionally `flutter build web`.
7. Record the result in the results note. Delete the written pubspec and the copies (all git-ignored), or let the next `host_probe.sh` run clean them.

Verify each path exists and that `check_host_lock.dart`'s argument form is right. Read `tool/ci/check_host_lock.dart` and `tool/ci/host_probe.sh`.

Do NOT run step 4 or later yourself: the packages are not on pub.dev, so it must fail now. Verify only steps 1–3 mechanically, in a scratch copy under the scratchpad, never in the tree.

## F2 (Minor 1) STATUS.md, Resume step 1: the engine's order

Publish the engine from `main` as it stands now (d41e5f6, whose `packages/jet_cad_2d` equals 1dc167d's) **before** this branch is merged. This branch rewrites the engine README (R-5), so publishing after the merge would upload the new README under the tag `jet_cad_2d-v0.7.1` → 1dc167d, and the archive would not match the tag.

In steps 2 and 3, "the merge commit" becomes "the commit `main` points at after the merge" (a fast-forward has no merge commit).

## F3 (Minor 2) `.github/workflows/ci.yml` ~line 174

The probe job's display name "… an external host, by git" is stale. Make it say a host from pub.dev, with the repo packages overridden to the commit under test. Keep it short. The branch is not protected, so renaming the check is safe (checked earlier: `gh api` answers "Branch not protected").

## F4 (Minor 3 + deferred T6) `tool/ci/host_probe.sh` header, lines ~10–12

The full-sha rationale is stale: the restaurant package no longer reaches the planner by path. The full sha is now required because `check_host_lock.dart --ref` compares it exactly with each package's `resolved-ref`. Reword it.

## F5 (Minor 4, ruling R-12) Copy `names.dart` verbatim; no sed

`package:jet_cad_floor_plan/symbol_sources.dart` is a host-facing public library and exports `SymbolNames`, so the import rewrite is a needless host step.

- `tool/ci/host_probe.sh`: replace the `sed … > "$probe/lib/restaurant_names.dart"` line with a plain `cp "$symbols/lib/src/names.dart" "$probe/lib/restaurant_names.dart"`. Update its comment.
- `docs/host-guide.md`, "### The restaurant symbols":
  - Drop "its import changed to the planner's barrel" and any other mention of the rewrite.
  - Say what the copied file imports: `symbol_sources.dart`, a public library of the planner. The host's pubspec already has the planner.
  - Add the missing instructions: the reader block needs `import 'dart:typed_data';` and `rootBundle` from `package:flutter/services.dart`, and the host imports its copy, e.g. `import 'restaurant_names.dart';`.
  - These are prose or inline code only. A new fenced dart block must appear verbatim in the probe's main.dart, and GD1 pins the yaml block count at 3.
- `tool/ci/test/scripts_test.dart` SC14: if it pins the sed line, update it to the `cp` line. Keep the ordering assertions.
- STATUS / CHANGELOGs / README / results note: grep for "sed", "import changed", "planner's barrel" near the restaurant recipe, and bring each mention in line. `packages/jet_cad_floor_plan/CHANGELOG.md` and its README cite the guide's subsection; check that they do not describe the rewrite.

## F6 (deferred T3) `packages/jet_cad_floor_plan/README.md`

The sentence saying `symbol_sources.dart` holds "the sources and their loader's Flutter side" is wrong. It exports `SymbolLibrarySource`, `furnitureSymbolSource`, `readBundledLibrary` and `SymbolNames`; the loader is on the main barrel. Check the real export lines in `lib/symbol_sources.dart` and `lib/jet_cad_floor_plan.dart`, then fix the sentence.

## F7 (ruling R-11, the reviewer's fallback) `docs/host-guide.md` ~151–154, the `FloorPlanStrings` bullet

Steer a host that wants its own words to subclass a built-in language (`FloorPlanStringsEn`, `FloorPlanStringsDe`, `FloorPlanStringsTr`; verify those names). Say that a class that implements or directly extends `FloorPlanStrings` must also write the abstract `tableNumberProblem(TableNumberProblem)`, and that in 0.7.1 the type `TableNumberProblem` is not exported by the planner's barrel.

Keep the existing "Since 0.6.0" facts. Do NOT change any barrel or any `lib/` code.

## F8 (Minor 5) `docs/host-guide.md` ~2262, the "Schema 10" bullet

It names 0.6.0 and 0.7.0. Add 0.7.1: same schema, saves and opens the same plans. Verify against the planner CHANGELOG's 0.7.1 entry.

## F9 (Minor 6) The results note, `docs/superpowers/notes/2026-10-13-publish-host-packages-results.md`

- Line ~102: the path `tool/ci/lib/package_root.dart` should be `tool/ci/package_root.dart`.
- The rulings list: add R-10..R-13, quoted from progress.md.
- Add a section "Final review": the verdict "With fixes", what the opus reviewer measured independently, and each item F1–F9 with what changed.
  - Record that Minors 7 and 8 are left (R-13).
  - Record the open R-10 question for the human. The reviewer recommends exporting `SymbolLibraryState`/`Loading`/`Ready`/`Failed` and `TableNumberProblem` from `jet_cad_floor_plan.dart` before 0.7.1, because:
    - the barrel's header calls a host's need a finding;
    - D9 makes the loader's failure state matter;
    - `tableNumberProblem` is abstract.
- Update the probe-run record with this wave's re-run (F5 changes the probe).
- The header's "archived on the branch as its last commit" stays: the controller archives the ledger after this wave.

## Gates

From the worktree root:
- `cd tool/ci && dart test && dart analyze <the ci-tools file list from ci.yml> && dart format --output=none --set-exit-if-changed .`
- `dart run tool/ci/check_guide.dart`
- `dart pub publish --dry-run` in `packages/jet_cad_floor_plan`, because its README changed: 0 warnings. NEVER without `--dry-run`.
- `cd packages/jet_cad_floor_plan && flutter analyze` (README only, so tests are not needed).
- After committing, F5 changes the probe: `rm -rf ~/.pub-cache/git/cache/jet-cad-*`, then `tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"`. Expect exit 0, "No issues found!", "✓ Built build/web" and the final line. Then `git status --short` must be clean.
- Mutant **M-CP1**: in `host_probe.sh`, delete the new `cp … restaurant_names.dart` line and re-run the probe. `flutter analyze` must fail on the missing `restaurant_names.dart` (the clean line removed the old copy). Restore the line and `cmp` it against the committed file.

## Commit

One commit, or one per logical group; no amend. Message e.g. "fix: the final review's findings (F1-F9)" + trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. If the probe needs a fix after the commit, that is a new commit and the probe runs again.
