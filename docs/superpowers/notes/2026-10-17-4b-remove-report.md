# 4b removal — report

Branch `chore/4b-remove-old`, worktree `.claude/worktrees/4b-remove`, cut by
hand from local `main`. The three old packages and the old host probe are
gone, the tooling and tests that read them are gone or ported, and the whole
workspace is green (the two standing failure sets aside — see below).

This is the task the inventory
`docs/superpowers/notes/2026-10-17-4b-removal-inventory.md` maps (§3/§4).

## Commits

| sha | subject |
|---|---|
| `d34c5f2b` | docs: update the package tables and stale references after 4b |
| `4516f3a8` | test: port the screenshot scenes and the README probes to the new API |
| `79193439` | chore: remove the old packages, apps/floor_planner and the old host probe |
| `3c5311da` | docs: name the gallery widget the regenerated picture shows |

`ea81b082` (this branch's parent below the four) is `docs: 4b removal
inventory` — a cherry-pick of `017182cd`, which lives on
`chore/4b-inventory` and is not merged into `main`. The inventory is the
task's map, so it was carried onto the branch that uses it. **Deviation:**
the task expected the inventory to be reachable from the branch; it was
not, so I cherry-picked the single commit rather than re-deriving the map.
`chore/4b-inventory` holds exactly that one commit beyond `main`.

The commits are ordered so each leaves the tree as green as it can:
docs first (no code edge), then the tooling/tests that stop *reading* the
old packages (which still exist), then the deletion with the CI, host-lock
and script-test changes that must land with it.

## The regenerated PNG

Only `packages/jet_cad_2d_flutter/doc/screenshots/symbol_gallery.png`
changed (38,921 → 44,586 bytes). R1–R4 (`canvas_light.png`,
`canvas_dark.png`, `selection_grips.png`, `selection_band.png`) came out
**byte for byte identical**: `buildSampleFlat` through a `PlanController`
reproduces the drawing the old `startupPlan` produced, which is the
strongest evidence the port preserved the scenes.

The new `symbol_gallery.png` is scene R5, rendered from the public
`PlanSymbolGallery`. I opened it: a **Search symbols** field across the top,
then the architecture kit's six categories as headers with their counts
(Dining Room 7, Kitchen 10, Bed Room 10, Living Room 5, Bathroom 4, Office
5); **Bathroom** is the one expanded, showing four labelled thumbnails —
Toilet, Washbasin, Bathtub, Shower tray. (The scene collapses every other
category; 41 symbols in all.) The search field is the only visible
difference from the old picture, which showed the bare `SymbolGallery`.

Because the picture now shows `PlanSymbolGallery` and no longer the render
package's bare `SymbolGallery`, `packages/jet_cad_2d_flutter/README.md`'s
caption and sentence were corrected to name `PlanSymbolGallery` (commit
`3c5311da`); the alternative — leaving a caption naming a widget the
picture no longer shows — would have been prose that is now false.

## Decisions and deviations, with reasons

- **The two `host_*_split.lock.txt` fixtures are kept.** The inventory
  (§3, §4) judged them readable only by the removed `--old` path. They are
  not: `host_lock_test.dart`'s HL1/HL2 and the HL-N group read them as the
  surviving guard's corpus. Deleting them would have deleted live
  assertions, which the task forbids. Each gained one top line:
  `# Recorded from the old host probe; kept as the host-lock guard's corpus.`
- **SC18 is deleted** (not moved). Its subject is the released-host guard
  (`old_host_probe.sh v0.3.0`…`v0.6.0`), which ends with 4b — the released
  hosts of the old line have no new probe to run against unless the new
  probe is pointed at the old tags, which the inventory left open (Q3) and
  the plan does not ask for.
- **The `host-probe` job's `fetch-depth: 0` is removed.** It existed only
  for the released probes' tags (its old comment said so), which are gone.
  The probe's git `dependency_overrides` clone the commit under test from
  the checkout, which is the shallow tip. I verified this rather than
  asserting it: with a `git clone --depth 1` of this branch,
  `host_probe.sh file:///tmp/4b_shallow <sha>` resolved, checked,
  analysed and built the probe to exit 0 (transcript below).
- **DOC scope.** The task enumerated the false prose to fix: the three
  README package tables and the "adds only `jet_cad_floor_plan`" sentence,
  the font attribution, the two `restaurant_demo` comments, `.vscode`.
  All six are done. Per the task, `STATUS.md` is P6's; `docs/host-guide.md`
  §12 and the roadmap are history and are left. See "Open questions".
- **`apps/restaurant_demo/analysis_options.yaml`** was reworded to
  `# The demo's lints: flutter_lints', without the generated platform
  folders.` The inventory suggested repointing to `apps/architecture_demo`,
  but that app's `analysis_options.yaml` is the generated Flutter template
  (`include: package:flutter_lints/flutter.yaml` plus the standard
  comments) — not "the app's lints, without the generated platform
  folders" — so the suggestion would have been false. The reworded comment
  says exactly what the file does.
- **`packages/jet_cad_2d_plan/assets/fonts/README.md`**: only the *source
  path* (line 9) was false after `jet_cad_floor_plan` was deleted; it now
  cites `packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf`
  (which `test/fonts/plan_assets_test.dart` already proves the bytes
  equal). The "ported from `jet_cad_floor_plan`" provenance on line 6, the
  SHA-256 and the licence are left, per §5.
- **`SC17` 2 → 1** (`reason: 'premise: the restaurant demo'`) and **`DL2`
  20 → 11** (`reason:` names the six holders: renderer 1, gpu 2,
  restaurant_demo 2, dev_harness_2d 2, tool/screenshots 2, readme_probe 2).
  Both numbers were re-derived by reading the files, and the number and the
  `reason:` text moved together — neither assertion was deleted.
- **`SC14`** now runs only `host_probe.sh`; **`SC15`**'s scratch asset
  directory was renamed `jet_cad_floor_plan` → `jet_cad_2d_flutter`.
- **`check_readmes.dart`** lost the `jet_cad_floor_plan` case and the
  `yaml:` input (its README was the only package README with a YAML block),
  and the block count it reports is now the Dart blocks only, so the
  message ("all 2 code blocks are in the probes") counts exactly what
  `readmeProblems` verifies.
- **`check_screenshots.dart`** iterates `['jet_cad_2d_flutter']`. Naming a
  new package would turn the check red on `no screenshots: entry` until the
  new line gets pictures and README images (the inventory's Q1); that is P5's.
- **`tool/screenshots`** lost `planner_scenes_test.dart` (its pictures
  belong to the deleted package), kept `renderer_scenes_test.dart` ported to
  the public API, swapped its two old deps for `jet_cad_2d_plan` + the two
  kits, and re-pointed the Roboto asset at
  `packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf`. Its description no
  longer says "eleven scenes" (there are five).
- **`tool/readme_probe`** lost `lib/planner.dart` and its
  `jet_cad_floor_plan` dependency (RM4 and the planner case of RM1 went with
  it).
- **`.vscode/launch.json`** lost the two `floor_planner` configurations and
  its "The two applications" header now reads "The applications".
- **`pubspec.yaml`** lost the three `workspace:` members; **`ci.yml`** lost
  the three matrix entries, the "Build the floor planner" web step, the
  `publishable` entry, the old-probe steps, and names only `host_probe/lib`
  in its probe-format step.

## Commands and their real last lines

All run in the worktree, on the final tree (`3c5311da`), after `flutter pub
get`.

### Root resolve

```
$ flutter pub get
Changed 135 dependencies!
16 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
```

### Every workspace member: tests, analyze, format

`dart` for pure-Dart members, `flutter` otherwise; `--enable-vmservice` for
`jet_cad_2d_plan` and `jet_cad_2d_integration` (the CI matrix's own flags).

```
### packages/jet_cad (flutter)
00:01 +95 ~6: All tests passed!
No issues found! (ran in 2.5s)
Formatted 40 files (0 changed) in 0.05 seconds.
### packages/jet_cad_2d (dart)
00:06 +1343 -2: Some tests failed.
No issues found!
Formatted 188 files (0 changed) in 0.43 seconds.
### packages/jet_cad_2d_flutter (flutter)
00:21 +1453 ~1 -5: Some tests failed.
No issues found! (ran in 3.3s)
Formatted 234 files (0 changed) in 0.47 seconds.
### packages/jet_cad_2d_gpu (flutter)
00:00 +20: All tests passed!
No issues found! (ran in 2.8s)
Formatted 10 files (0 changed) in 0.02 seconds.
### packages/jet_cad_2d_kit (flutter)
00:04 +403: All tests passed!
No issues found! (ran in 3.2s)
Formatted 92 files (0 changed) in 0.11 seconds.
### packages/jet_cad_2d_plan (flutter)
02:02 +1579: All tests passed!
No issues found! (ran in 4.1s)
Formatted 308 files (0 changed) in 0.79 seconds.
### packages/jet_cad_2d_kit_architecture (flutter)
00:20 +655: All tests passed!
No issues found! (ran in 3.1s)
Formatted 136 files (0 changed) in 0.42 seconds.
### packages/jet_cad_2d_kit_restaurant (flutter)
00:01 +184: All tests passed!
No issues found! (ran in 2.7s)
Formatted 22 files (0 changed) in 0.04 seconds.
### packages/jet_cad_2d_integration (flutter)
00:59 +228: All tests passed!
No issues found! (ran in 3.1s)
Formatted 80 files (0 changed) in 0.21 seconds.
### apps/dev_harness (flutter)
00:01 +10: All tests passed!
No issues found! (ran in 3.5s)
Formatted 8 files (0 changed) in 0.01 seconds.
### apps/dev_harness_2d (flutter)
00:15 +82: All tests passed!
No issues found! (ran in 3.0s)
Formatted 22 files (0 changed) in 0.05 seconds.
### apps/architecture_demo (flutter)
00:34 +176: All tests passed!
No issues found! (ran in 3.3s)
Formatted 44 files (0 changed) in 0.08 seconds.
### apps/restaurant_demo (flutter)
00:23 +102: All tests passed!
No issues found! (ran in 3.0s)
Formatted 38 files (0 changed) in 0.07 seconds.
### tool/ci (dart)
00:43 +114: All tests passed!
No issues found!
Formatted 22 files (0 changed) in 0.04 seconds.
### tool/screenshots (flutter)
00:08 +8: All tests passed!
No issues found! (ran in 3.5s)
Formatted 4 files (0 changed) in 0.01 seconds.
### tool/readme_probe (flutter)
TEST: no test/ directory
No issues found! (ran in 2.6s)
Formatted 2 files (0 changed) in 0.00 seconds.
```

`tool/ci`'s `dart format . ` is only clean once the probe has been resolved:
`host_probe/lib/main.dart` is a host of its own (`sdk ^3.6.0`) and, with the
probe's generated `host_probe/pubspec.yaml` absent, `dart format .` falls
back to `tool/ci`'s language version and wants the short style. CI names the
paths and the language version explicitly, so those are the commands that
matter:

```
$ cd tool/ci && dart format --output=none --set-exit-if-changed \
    lib test expect_failures.dart check_guide.dart check_host_lock.dart \
    package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart \
    ../readme_probe/lib
Formatted 23 files (0 changed) in 0.03 seconds.            # exit 0
$ cd tool/ci && dart format --language-version=3.6 --output=none \
    --set-exit-if-changed host_probe/lib
Formatted 1 file (0 changed) in 0.01 seconds.              # exit 0
$ cd tool/ci && dart analyze --fatal-infos lib test expect_failures.dart \
    check_guide.dart check_host_lock.dart package_root.dart \
    check_screenshots.dart check_readmes.dart check_kit_deps.dart
No issues found!
```

### The `tool/ci` checks

```
$ dart run tool/ci/check_guide.dart
docs/host-guide.md: all 29 code blocks are in the host probe        # exit 0
$ dart run tool/ci/check_readmes.dart
package READMEs: all 2 code blocks are in the probes                # exit 0
$ dart run tool/ci/check_screenshots.dart
screenshots: every rule holds                                       # exit 0
$ dart run tool/ci/check_kit_deps.dart
kit dependencies: 3 package(s) checked, none names the plan library or another kit  # exit 0
```

### The host probe

Against this branch:

```
$ bash tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"
.../tool/ci/host_probe/pubspec.lock: 42 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
Analyzing host_probe...
No issues found! (ran in 3.5s)
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is  42M
```

Against a `--depth 1` clone (the `fetch-depth: 0` removal's evidence):

```
$ git clone --depth 1 file://$PWD /tmp/4b_shallow      # 1 commit, .git/shallow present
$ bash tool/ci/host_probe.sh "file:///tmp/4b_shallow" <same sha>
.../tool/ci/host_probe/pubspec.lock: 42 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
Analyzing host_probe...
No issues found! (ran in 3.6s)
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is  42M      # exit 0
```

## The failures — the standing sets, not mine

`jet_cad_2d`:

```
Failing tests:
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
```

`jet_cad_2d_flutter`:

```
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Both sets are listed verbatim in `tool/ci/standing_failures.txt` as
macOS-measured, Linux-CI-by-design. No other test is red.

## What I could not do, and open questions

- **`STATUS.md` is still partly stale.** Its live status (package list,
  publish order, repository tree, gates) names the removed packages. Per
  the task's DOC scope and "STATUS.md is P6's to update", I left it whole
  for P6.
- **`docs/host-guide.md` §12** ("From `jet_cad_floor_plan`": the old-name
  mapping table and the note that the old guide "stays at the tag
  `v0.7.2`") is left. It is true as history, and GD6 only guards code
  blocks. Keep-or-trim is the inventory's Q4, undecided.
- **No pictures for the new line.** `check_screenshots.dart` guards one
  package; the plan library and the kits have no `screenshots:` entry and
  no README images yet (the inventory's Q1, P5's).
- **The three README package tables' pub.dev links 404** until the new
  packages are released — expected, and the inventory's row asks for
  exactly this table.
- **The renderer README shows the plan library's gallery widget.** R5 is on
  `PlanSymbolGallery` because the inventory says the bare `SymbolGallery`
  has no public way to build its grouping from the plan library's barrel;
  the picture and the caption now name the plan library's widget inside
  `jet_cad_2d_flutter`'s README. If P5 would rather the renderer's README
  show the renderer's own widget, R5 would have to reach a non-barrel
  helper.
- **Provenance comments** naming the removed packages are left everywhere
  §5 lists them. `git grep -E
  "jet_cad_floor_plan|jet_cad_restaurant_symbols|old_host_probe|oldProbedFromCommit"`
  now hits only those comments, the two lock fixtures, the deliberate
  guards (`guide_test.dart` GD6, `host_lock_test.dart` HL1/HL-N1,
  `apps/*/test/boundary_test.dart`,
  `jet_cad_2d_kit_architecture/test/dimension/dimension_live_test.dart`),
  and `docs/host-guide.md` / `STATUS.md`.
- **The `chore/4b-inventory` branch** still holds `017182cd` on its own
  base; I cherry-picked it here instead of merging, so the two branches
  carry the same file at different commits.
