# Final fix wave report

Commits: ce69050f7ad3b41f0f238485bf08085c6bd123df (F1-F9),
a45f87f2fee425f339a5aa44be4dcc3a2904c407 (note: probe re-run and M-CP1).

## Items
- F1: STATUS.md Resume step 4 now lists the human's commands (two cp, sed dropping the dependency_overrides block, grep for @URL@/@REF@, pub get, check_host_lock.dart without --ref, analyze, optional build, cleanup). Paths verified; check_host_lock.dart takes `<lock> [--ref sha]`, run from tool/ci/host_probe as `../check_host_lock.dart pubspec.lock`.
- F2: STATUS.md step 1 publishes the engine from main (d41e5f6) before the merge, with the reason; steps 2-3 say "the commit main points at after the merge".
- F3: .github/workflows/ci.yml host-probe job name: "a host from pub.dev, repo packages overridden".
- F4/F5: tool/ci/host_probe.sh header reworded (--ref compares resolved-ref exactly); names.dart copied with plain cp, comment updated. SC14 did not pin the sed line (it pins the clean line, symbols= line, ordering), so scripts_test.dart is unchanged.
- F5 guide: docs/host-guide.md "The restaurant symbols" drops the rewrite, says the copy imports symbol_sources.dart, adds the dart:typed_data / rootBundle / import 'restaurant_names.dart' prose (inline code only). Results note D11 step 3 likewise. Planner CHANGELOG/README did not describe the rewrite.
- F6: packages/jet_cad_floor_plan/README.md: symbol_sources.dart exports SymbolLibrarySource, furnitureSymbolSource, readBundledLibrary, SymbolNames; loader is on the main barrel (checked both export lines).
- F7: host-guide FloorPlanStrings bullet: subclass FloorPlanStringsEn/De/Tr (names verified in lib/src/l10n); direct implementers must write abstract tableNumberProblem(TableNumberProblem), unexported in 0.7.1.
- F8: host-guide Schema 10 bullet adds 0.7.1 (planner CHANGELOG: stored as 0.7.0, schema 10).
- F9: results note: package_root path fixed, R-10..R-13 added, "Final review" section with F1-F9 table, Minors 7/8 left, R-10 open question, probe re-run record (second commit), T3 minor marked fixed.

## F1 scratch verification (steps 1-3, in the scratchpad copy f1/, not the tree)
- cp of restaurant.jetlib: 130778 bytes at host_probe/assets/restaurant.jetlib.
- cp of names.dart: `cmp` against source printed cmp-ok (restaurant_names.dart, 8504 bytes).
- sed '/^dependency_overrides:/,$d' pubspec.yaml.in > pubspec.yaml: `grep -c '@URL@\|@REF@'` printed 0; the file ends with the assets: block; no `git:` line remained.
- Steps 4+ not run.

## Gates (real tails)
- tool/ci dart test: `00:04 +77: All tests passed!`
- dart analyze --fatal-infos (ci.yml file list): `No issues found!`
- dart format: `Formatted 13 files (0 changed)`
- check_guide: `docs/host-guide.md: all 56 code blocks are in the host probe`
- planner `dart pub publish --dry-run` before committing: 1 warning (dirty git tree, expected); after commit: `Package has 0 warnings.` (462 KB)
- planner `flutter analyze`: `No issues found!`

## Probe (at ce69050; pub git cache glob matched nothing, so nothing to clear)
exit=0; tail: `pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu`, `No issues found! (ran in 2.5s)`, `✓ Built build/web`, `host probe: no GPU renderer, no build hook; build/web is  42M`. `git status --short` clean.

## M-CP1
Deleted line 37 (`cp "$symbols/lib/src/names.dart" "$probe/lib/restaurant_names.dart"`); probe exit=1:
```
error • Target of URI doesn't exist: 'restaurant_names.dart'. ... • lib/main.dart:21:8 • uri_does_not_exist
error • Invalid constant value • lib/main.dart:33:12 • invalid_constant
error • Undefined name 'restaurantSymbolNames'. ... • lib/main.dart:33:12 • undefined_identifier
3 issues found. (ran in 2.6s)
```
Restored with `git checkout`; `git show HEAD:tool/ci/host_probe.sh | cmp - tool/ci/host_probe.sh` identical (cmp-ok). The probe was not re-run after the restore (the file is byte-identical to the one that passed).

## Deviations / self-review
- The final reviewer's report is not in the ledger; the note's "Final review" claims only what progress.md records of it (flagging that), not invented measurements.
- A first mutation attempt with grep -v also removed the clean line; discarded, redone by deleting line 37 only.
- Ignored probe files (pubspec.yaml, lock, build, no restaurant_names.dart after the mutant run) remain in tool/ci/host_probe; the next probe run cleans them.
- No lib/ or barrel change. analysis_options.yaml untouched; tree clean.
