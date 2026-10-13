# Publishing the host packages on pub.dev — results

**Date:** 2026-10-13. **Branch:** `feat/publish-host-packages`, cut by hand from
`main` at `d41e5f6` (the engine's publication merged at `1dc167d`; tag
`v0.7.0` → `0fa649e`). Spec:
[2026-10-13-publish-host-packages-design.md](../specs/2026-10-13-publish-host-packages-design.md)
(revision 2). Plan:
[2026-10-13-publish-host-packages.md](../plans/2026-10-13-publish-host-packages.md),
executed task by task with an implementer and an independent reviewer per
task (the SDD ledger is archived on the branch as its last commit). This note is the record.
The shape follows
[2026-10-13-publish-jet-cad-2d.md](2026-10-13-publish-jet-cad-2d.md).

Nothing here ran `dart pub publish` without `--dry-run`, pushed, merged or
tagged: those are the human's (Owed).

## The request and the rulings

**The human's request** (2026-10-13): *"bence tümünü sırayla
yayınlayalım. restoran sembolleri de yayınlandıktan sonra restoran
yazılımı içinden pub.dev üzerinden kurarak kullanabilirim."* The
restaurant software is to install the planner from pub.dev instead of by
git.

**The human's decisions** (the spec's Decisions, quoted):

1. **Publish in order:** `jet_cad_2d` → `jet_cad_2d_flutter` →
   `jet_cad_floor_plan` (*"tümünü sırayla yayınlayalım"*). `jet_cad_2d_gpu`
   is not published.
2. **Apache 2.0 for every published package** (*"tümü için lisans apache
   2.0 olsun"*).
3. **The restaurant symbols: a fourth step, deferred** (a SWOT in chat;
   *"tamam yaz"*). A pub.dev release cannot be taken back, and the
   library's source name and entry keys become a contract once published.
4. **Each package its own version** (*"Her biri bağımsız"*): its own
   semver, CHANGELOG and tag; published only when it changes.
5. **pub.dev only for hosts** (*"Yalnız pub.dev"*): the host guide
   describes pub.dev alone; CI checks the commit under test through
   `dependency_overrides`.
6. **Approach A** (*"evet a"*): every dependency on a published package
   is a hosted constraint, in the repository as in the archive; no
   `path:` to a published package, no rewriting at publish time, no
   committed `pubspec_overrides.yaml`.
7. Sections 1 (the packages), 2 (CI and the probes) and 3 (the host guide
   and the release flow) approved as presented (*"onaylıyorum"*, three
   times); the spec, revision 2, approved (*"onaylıyorum"*).

**The controller's rulings** (the SDD ledger, quoted):

- **R-1.** On macOS the render package's `expect_failures.dart` reports the
  text-lod-ladder rungs 1–2 passing and the five text-ladder goldens
  failing; a task is green there when exactly those differ — STATUS records
  the macOS standing set as differing (not ruled), and `main` at `133cf03`
  shows the same five. Cost if wrong: a real golden regression hidden
  behind the macOS difference; CI (Linux) compares exactly and would catch
  it.
- **R-2.** At the end the workspace's ledger is archived to
  `docs/superpowers/ledgers/2026-10-13-publish-host-packages/` as the
  branch's last commit, not deleted: CLAUDE.md and the repo's merged plans
  archive their ledger before the merge.
- **R-3.** The no-Codex rule binds every reviewer dispatch (the human,
  2026-10-10).
- **R-4.** pana for a dependent cannot be measured before its dependency is
  on pub.dev (pana resolves outside the workspace; `jet_cad_2d` 0.7.1
  answers 404): this note records 40/160 with that reason, and the human's
  checklist runs pana after each dependency is published (already D1's
  lower-bound step). Cost if wrong: a pana defect found only at
  publication time; mitigated by the dry run, `dart doc` 0 warnings and
  the gates on the same files.
- **R-5.** `packages/jet_cad_2d/README.md`'s "the Flutter packages … are
  not published on pub.dev" sentence is rewritten in Task 7 (no engine
  version bump: the README reaches pub.dev with the engine's next
  release). Cost if wrong: pub.dev's engine page keeps the stale sentence
  until then.
- **R-6.** `editor.dart`'s `hide readBundledLibrary` stands though D4
  publishes barrels as they stand: the package still exports the symbol
  from `symbol_sources.dart` (its one home), `editor.dart` is internal by
  its own header, the hide removes `dart doc`'s ambiguous-export warning,
  and nothing imports it from `editor.dart` (grep). Cost if wrong: a
  caller importing `editor.dart` for `readBundledLibrary` must import
  `symbol_sources.dart` instead.
- **R-7.** The planner's CHANGELOG and README cite the host guide's "The
  restaurant symbols" as written; Task 6 writes that subsection under
  exactly that heading. Cost if wrong: a dangling reference until Task 6
  landed (before any merge).
- **R-8.** Task 6's `package_root` test is SC22 (the next number after
  SC21), and Task 6 keeps SC21 untouched: the plan's SC17 name predates
  SC16–SC21.
- **R-9.** The host guide's intro names the release a host depends on —
  "covers `jet_cad_floor_plan` 0.7.1", linking the planner's CHANGELOG; the
  "Since 0.7.0" feature markers stay (0.7.1 is packaging only).
- **R-10.** The unexported `SymbolLibraryState` family and
  `TableNumberProblem` stay unexported in 0.7.1 (spec D4: barrels
  published as they stand); the note records them as 0.x export
  candidates with the `FloorPlanStrings` consequence, and the hand-off
  names them to the human. Cost if wrong: a host implementing
  `FloorPlanStrings` imports `editor.dart` until a 0.x release exports the
  enum (adding an export is non-breaking).
- **R-11.** R-10 stands for the final fix wave (spec D4, approved by the
  human, publishes barrels as they stand; widening the published API is
  the human's call). The wave applies the reviewer's fallback: the guide
  steers a custom `FloorPlanStrings` to a built-in language's subclass,
  and the hand-off asks the human whether to add the two exports before
  publishing. Cost if wrong: one more small commit after the human's
  answer.
- **R-12.** The restaurant names file is copied verbatim, no `sed`:
  `symbol_sources.dart` is a host-facing public library exporting
  `SymbolNames` (the reviewer verified), so the rewrite is a needless host
  step. Cost if wrong: `host_probe.sh` and the guide revert to the
  rewrite; the probe re-run catches a failure.
- **R-13.** Final-review Minors 7 (the root CHANGELOG says "published"
  before the publish: the spec's accepted window) and 8 (the example test
  calls `symbols.load` itself) are left and recorded. Cost if wrong: a
  stale word for the hours between merge and publish; a test that does
  not pin the example's own `load` call.

## What each task did

| Task | Commit(s) | What |
|---|---|---|
| 1 (D1) | `4d74b5b` | 15 path dependencies on `jet_cad_2d`, `jet_cad_2d_flutter` and `jet_cad_floor_plan` in 7 pubspecs (render 1, GPU 2, planner 2, harness 2, symbols 2, floor_planner 3, restaurant_demo 3) became `^0.7.1`; the render package and the planner at `version: 0.7.1`. New `tool/ci/test/dependency_lines_test.dart` (DL1 no `path:`/git entry for a published package, DL2 exactly 15 lines at `^0.7.1`, DL3 path entries of unpublished packages). `flutter pub get`: "Got dependencies!", the package config resolves the siblings to `../packages/<name>` (F-1). |
| 2 (D2) | `09153e8` | `jet_cad_2d_flutter` 0.7.1 packaged: `publish_to` removed, `sdk: ^3.6.0`, repository, issue tracker, topics, a description; LICENSE (byte-identical to the root's), `.pubignore` (`/test/`, `/build/`, `/shaders/`), README for pub.dev (the old developer README moved with `git mv` to `test/README.md`), CHANGELOG, `example/lib/main.dart` and `test/example_test.dart`, `export_testing.dart`'s library comment; 6 `dart doc` warnings fixed. |
| 3 (D3, D11) | `5eec301`, `e2869e5` | `jet_cad_floor_plan` 0.7.1 packaged the same way (`.pubignore` `/test/`, `/build/`, `/tool/`; the three assets stay in), a README with a section on a library of one's own, the CHANGELOG with the restaurant software's migration (D11), `editor.dart`'s library comment, 23 `dart doc` warnings fixed (R-6). The fix round (`e2869e5`) repaired one garbled CHANGELOG sentence. |
| 4 (D5) | `c9eed8a` | CI's `publishable` job became a matrix over the three packages: `cmp LICENSE`, then `dart pub publish --dry-run` (exit 65 on any warning). |
| 5 (D6) | `2f88612` | `check_host_lock.dart <lock> --ref <sha>`: each of the four packages must be in the lock with `source: git` and a `resolved-ref` equal to the ref; tests HL-C1…C3b and SC21. |
| 6 (D6, D8, D9) | `4712baa`, `ede7283` | The probe on pub.dev: `pubspec.yaml.in` with the planner's hosted line and four git overrides; `host_probe.sh` passes `--ref` and copies `restaurant.jetlib` and `names.dart` from the overridden symbols package (`tool/ci/package_root.dart`, SC22); the probe's `main.dart` builds its own `SymbolLibrarySource`; the host guide §1 rewritten for pub.dev with the new subsection "The restaurant symbols"; `guide_test.dart` GD1/GD3/GD4. The fix round (`ede7283`) applied R-9 and the two review minors (the guide's rules paragraph; SC22's trailing slash). |
| 7 | this commit | The root CHANGELOG as an index, STATUS, this note, and the engine README's stale sentence (R-5). |

## The dry runs

`dart pub publish --dry-run`, on the committed state at each task's
commit, and the three runs of Task 7 (below; the engine's is the README
rewrite's check: still 0 warnings). Sizes and results are the
reports' own.

| Package | Where | Exit | Warnings | Archive |
|---|---|---|---|---|
| `jet_cad_2d_flutter` | Task 2, `09153e8` | 0 | 0 | 226 KB |
| `jet_cad_floor_plan` | Task 3, `e2869e5` | 0 | 0 | 462 KB |
| `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_floor_plan` | Task 4, `c9eed8a` | 0, 0, 0 | 0, 0, 0 | not recorded |
| `jet_cad_2d` (Task 7, after the README rewrite) | the Task 7 commit | 0 | 0 | 229 KB (228 KB at `8f8ed32`) |
| `jet_cad_2d_flutter` (Task 7) | the Task 7 commit | 0 | 0 | 226 KB |
| `jet_cad_floor_plan` (Task 7) | the Task 7 commit | 0 | 0 | 462 KB |

Before packaging, at `d41e5f6`: the render package's dry run had one error
(no LICENSE) and one more issue (no CHANGELOG), the archive 1005 KB with
`test/` inside; the planner's exit 65 with three issues (repository,
README, CHANGELOG).

**Review Focus 1** (Task 3, on the committed state): `grep -E
'furniture.jetlib|Roboto-Regular.ttf|Roboto_LICENSE.txt'` on the planner's
dry-run output printed three lines (`Roboto_LICENSE.txt`,
`furniture.jetlib`, `Roboto-Regular.ttf`); the grep for a top-level
`test`, `tool` or `build` printed nothing. In the render package's archive
no `test/`, `build/` or `shaders/` is listed (Task 2); `lib/src/export/testing/`
is `export_testing.dart`'s source, kept on purpose.

The `cmp` of each LICENSE against the root's is silent for all three
packages (Task 4). **M-CI1** (below) shows the licence check and the dry
run catch a modified licence.

## `dart doc`

`dart doc --dry-run`: the render package 6 → 0 warnings (`[this]`,
`[_bake]`, `[anchor]`, `[centre]`, `[stem]` and `[_attach]` references
made plain or code-quoted); the planner 23 → 0 (unresolved references
code-quoted, `[0, 1]` reworded, and one ambiguous re-export of
`readBundledLibrary` removed by `editor.dart`'s `hide`, R-6). The engine's went
11 → 0 in its own record (`6f683f2`).

## pana (0.23.19), on each archive's file set

Run on a `git archive HEAD` copy with `test/`, `build/` (and `shaders/` or
`tool/`) removed, as `.pubignore` removes them.

| Section | `jet_cad_2d_flutter` (Task 2) | `jet_cad_floor_plan` (Task 3) |
|---|---|---|
| Dart file conventions | 20 / 30 | 20 / 30 |
| — valid pubspec | 0 / 10 | 0 / 10 |
| — README | 5 | 5 |
| — CHANGELOG | 5 | 5 |
| — OSI licence | 10 (Apache-2.0) | 10 (Apache-2.0) |
| Documentation | 10 / 20 | 10 / 20 |
| — dartdoc ≥ 20 % | 0 | 0 (could not run) |
| — example | 10 | 10 |
| Platform support | 0 / 20 | 0 / 20 |
| Static analysis | 0 / 50 | 0 / 50 |
| Up-to-date dependencies | 10 / 40 | 10 / 40 |
| **Total** | **40 / 160** | **40 / 160** |

**This is not a meaningful score (R-4).** pana resolves outside the
workspace, and the dependencies are not on pub.dev: `jet_cad_2d` 0.7.1
answers 404 (*"Because jet_cad_2d_flutter depends on jet_cad_2d any which
doesn't exist … version solving failed"*), the planner's copy fails the
same way on `jet_cad_2d_flutter`. Dartdoc, platform detection, analysis
and two of the dependency checks fail on that alone. A scratch copy with a
`dependency_overrides` path was tried for the render package: pana strips
overrides, same result.

**The repository check's note.** The pubspec's 0 / 10 is the branch not
being on GitHub's `main`: for the render package, pana found `main`'s copy
with `publish_to: none` and the old repository URL; for the planner's copy
(not a git checkout) it reported *"has no repository or homepage URL"*.
Both are expected to clear once the branch is on `main` on GitHub.

**Owed (the checklist):** pana re-run on each archive after its
dependency is published, which is also D1's lower-bound check.

## Named mutants

Each fired from a copy and restored from it (`cmp` checked).

| Mutant | Change | Result |
|---|---|---|
| M-DL1 | `restaurant_demo`'s `jet_cad_2d` back to `path:` | DL1 red naming `apps/restaurant_demo/pubspec.yaml` (`Actual: ['jet_cad_2d: path: ../../packages/jet_cad_2d']`); DL2 also red (expected 15, actual 14) |
| M-RX1 | the render example's circle command removed | red: `Expected: <2> Actual: <1>` |
| M-RX2 | `document.extents.expandedBy(20)` → `Aabb2(Vector2(0,0), Vector2(1,1))` | red: `Expected: a value greater than or equal to <500.0> Actual: <1.2017543859649122>` |
| M-FX1 | the planner example's `sources: const []` | red, but through the loader's own `ArgumentError: Invalid argument (sources): must not be empty`, not through the `library.entries` `isNotEmpty` assertion (see Review minors) |
| M-FX2 | `FloorPlanView` replaced by `const SizedBox()` | red: `findsOneWidget` on `FloorPlanView` |
| M-CI1 | one byte appended to `packages/jet_cad_2d_flutter/LICENSE` | `cmp` exit 1 (*"EOF on LICENSE"*); the dry run exit **65**, *"1 checked-in file is modified in git"*, *"Package has 1 warning."* |
| M-LK1 | the `source != 'git'` clause dropped from the lock check | **survived the brief's tests alone** (`+19: All tests passed!`): a hosted entry has no `resolved-ref`, so the ref clause catches it. HL-C3b (green entry, `source: path`, ref kept) was added and now turns it red |
| M-LK2 | the `resolved-ref != ref` clause dropped | red: `HL-C2 another ref: each of the four named` |
| M-PR1 | the `jet_cad_2d_flutter` override block removed from the template | red at **resolution**, exit 69: *"every version of jet_cad_floor_plan from git depends on jet_cad_2d_flutter any which doesn't exist (could not find package jet_cad_2d_flutter at https://pub.dev)"*. The lock check was not reached, which is the "either is red" case of the plan; once 0.7.1 is on pub.dev the lock check is what turns it red |
| SC22-M | the `.replaceAll(RegExp(r'/$'), '')` removed from `package_root.dart` | red: `Expected: '/abs/b'  Actual: '/abs/b/'` (found by Task 6's review: the test had not covered the trailing slash) |

## The probe and the released probes

`tool/ci/host_probe.sh` at `4712baa`: exit 0; lock check *"40 packages,
none of flutter_scene, …"* (one line printed, the brief had expected two),
*"No issues found!"*, *"✓ Built build/web"*, *"host probe: no GPU
renderer, no build hook; build/web is 42M"*.
`old_host_probe.sh` for `v0.3.0`, `v0.4.0`, `v0.5.1` and `v0.6.0`: each
*"No issues found!"* (*"vX's main.dart analyses against 4712baab…"*). The
probe passes only through its overrides: the hosted 0.7.1 packages are not
on pub.dev yet; D7 (Owed) is the check without them. `check_guide.dart`:
*"all 56 code blocks are in the host probe"* (54 before this branch).

The final wave (F5: the names file is copied with `cp`, no `sed`) re-ran
the probe at `ce69050` after clearing the pub git cache: exit 0, lock
check *"40 packages, none of flutter_scene, …"*, *"No issues found!"*,
*"✓ Built build/web"*, *"host probe: no GPU renderer, no build hook;
build/web is 42M"*; `git status --short` clean afterwards. **M-CP1** (the
new `cp … restaurant_names.dart` line deleted): `flutter analyze` fails,
exit 1: *"Target of URI doesn't exist: 'restaurant_names.dart'"*
(`lib/main.dart:21:8`), *"Undefined name 'restaurantSymbolNames'"*, *"3
issues found."*; restored and `cmp`-identical to the committed file.

## D4: the barrels, audited

The barrels are published as they stand. **Method (a rough grep, not a
finding list):** for each package a script lists the public libraries'
`export` lines (honouring `show` lists; `export 'package:…'` of other
packages ignored), collects the type names declared in the package's
`lib/` and not exported by any public library, and prints those that
appear, as a whole word, on a line at indent four or less of an exported
file. That over-reports (bodies, shown and hidden classes of one file) and
under-reports (types a signature reaches only through another package's
alias, or at deeper indent). Each hit was then read by hand.

- **`jet_cad_2d`:** `jet_cad_2d.dart` (56 files exported whole) and
  `testing.dart`; no hit (the script counted 60 files). The engine's own record lists its candidates.
- **`jet_cad_2d_flutter`:** `jet_cad_2d_flutter.dart` (59 exports) and
  `export_testing.dart`: no hit.
- **`jet_cad_floor_plan`** (`jet_cad_floor_plan.dart`, `symbols.dart`,
  `symbol_sources.dart`, and `editor.dart`, which is internal by its own
  header): the grep prints 14 names, almost all body or internal uses
  (`FloorPlanThemeScope`, `InheritedFloorPlanTheme`, `RenderFloorPlanOverlays`,
  `TableOverlayLayer`, `PlannerTextKeys`, `TablePicker`, `ExportFontCache`,
  `SymbolWords`, `FloorPlanTableData` in a controller body; `ExportChoice` is
  `@internal`). **Two are real:**
  - `SymbolLibraryLoader.state` (a public getter on a barrel export)
    returns `SymbolLibraryState`. It and `SymbolLibraryLoading`,
    `SymbolLibraryReady` and `SymbolLibraryFailed` are not exported by the
    host-facing barrels (`jet_cad_floor_plan.dart`, `symbols.dart`,
    `symbol_sources.dart`); only `editor.dart` exports them, and it is
    internal and outside semver. A host can read `state` but cannot name
    or pattern-match its result without importing `editor.dart` or `src/`;
    the planner's own example test imports
    `src/symbols/symbol_library_state.dart` for that reason.
  - `FloorPlanStrings.tableNumberProblem(TableNumberProblem)` (an abstract
    method of an exported class) takes the enum `TableNumberProblem`
    (`src/tables/table_numbers.dart`), likewise not exported by the
    host-facing barrels and exported only by `editor.dart`. The host guide
    (docs/host-guide.md, section on language) lets a host implement or
    directly extend `FloorPlanStrings`; such a class must write
    `tableNumberProblem(TableNumberProblem)` (the method is abstract) and
    cannot name the type from the public barrel without importing
    `editor.dart` or `src/`. A subclass of a built-in language
    (`FloorPlanStringsEn`, `De`, `Tr`) inherits the method and needs
    nothing.

  They are 0.x candidates for exporting (a minor release of the planner),
  not changes made here: narrowing or widening a barrel is a spec of its
  own (D4).

## Gates

On macOS, Flutter 3.47.6. `expect_failures.dart` is
`dart run tool/ci/expect_failures.dart --package <p> --root <p> <json>`,
from the repository root.

Run for this note on the tree before the Task 7 commit (documentation
only differs from `ede7283`); the exit code of `dart test` on the engine is
1 because of its two standing fingerprints, which `expect_failures.dart`
compares.

| Package | Tests | Analyze | Format |
|---|---|---|---|
| `jet_cad_2d` | `dart test` +1289 −2; `expect_failures`: "1291 tests; the standing failures and skips, exactly" | No issues found! | 177 files, 0 changed |
| `jet_cad_2d_flutter` | `flutter test` +1447 ~1 −5 (exit 1); `expect_failures` below | No issues found! | 234 files, 0 changed |
| `jet_cad_floor_plan` (`--enable-vmservice`) | +2011, all passed; `expect_failures`: "2011 tests; the standing failures and skips, exactly" | No issues found! | 298 files, 0 changed |
| `jet_cad_2d_gpu` | +20 | No issues found! | 10 files, 0 changed |
| `jet_cad_restaurant_symbols` | +97 | No issues found! | 15 files, 0 changed |
| `apps/floor_planner` (`--enable-vmservice`) | +212 | No issues found! | 47 files, 0 changed |
| `apps/restaurant_demo` | +69 | No issues found! | 9 files, 0 changed |
| `apps/dev_harness_2d` | none | No issues found! | n/a |
| `tool/ci` | `dart test` +77 | CI's file list: No issues found! | 13 files, 0 changed |
| `check_guide.dart` | "docs/host-guide.md: all 56 code blocks are in the host probe" | | |

`flutter pub get` rewrote no tracked `analysis_options.yaml` (`git status`
shows none modified).

### The expect_failures comparison

| Package | Result |
|---|---|
| `jet_cad_2d` | exit 0: "packages/jet_cad_2d: 1291 tests; the standing failures and skips, exactly" |
| `jet_cad_2d_flutter` | exit 1, with exactly the difference R-1 rules green on macOS: "standing failure passed or did not run" for `test/golden/text_lod_ladder_golden_test.dart` text lod ladder rungs 1 and 2 (RenderBackend.canvas); and the five goldens `test/golden/text_ladder_golden_test.dart` text ladder rungs 1 to 5 (RenderBackend.canvas) failing (+1447 ~1 −5). Nothing else differs |
| `jet_cad_floor_plan` | exit 0: "packages/jet_cad_floor_plan: 2011 tests; the standing failures and skips, exactly" |

The same five fail at `main` (`133cf03`) on this machine (the engine's
record); on Linux CI compares exactly and would catch a real regression.

## D11: the restaurant software's move

Written into the planner's 0.7.1 CHANGELOG entry, for the human to apply
in the restaurant software:

1. Replace the two git dependencies (`jet_cad_floor_plan` and
   `jet_cad_restaurant_symbols`) with `jet_cad_floor_plan: ^0.7.1`.
2. Drop every import of `package:jet_cad_restaurant_symbols/…`.
3. From the repository tree at the tag of the planner release it depends
   on (`jet_cad_floor_plan-v0.7.1`), copy
   `packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib` into the
   host's assets and `packages/jet_cad_restaurant_symbols/lib/src/names.dart`
   into the host's `lib/` as `restaurant_names.dart`, verbatim (it
   imports the planner's public `symbol_sources.dart`; R-12).
4. Declare the asset, build `SymbolLibrarySource(name: 'restaurant', …)`
   and pass it with `furnitureSymbolSource` to `SymbolLibraryLoader`
   (host guide, "The restaurant symbols").
5. Never load the copy together with the package's
   `restaurantSymbolSource`: the same keys in two sources make the loader
   fail. Saved plans do not depend on the library.

## Independent review minors (deferred, recorded)

From the per-task reviews; none blocks the publication.

- T1: `dependency_lines_test.dart` has an `if` without braces; DL1's regex
  misses a flow-style git map (DL2 catches it by value); DL3 covers
  `path:`, not git, though its header names both.
- T2: `geometry_collector.dart`'s comment still names
  `test/support/instance_expander.dart` and `frame_info.dart`, absent from
  the archive; the README snippet uses an undefined `size` (a fragment; the
  full example is linked); the README names `jet_cad_floor_plan`, true
  once the planner is published.
- T3: M-FX1 dies on the loader's `ArgumentError`, so the
  `library.entries` `isNotEmpty` assertion is exercised by no named
  mutant; (fixed in the final wave, F6: the README said `symbol_sources.dart`
  holds "the sources and their loader's Flutter side");
  `mySymbolSource` is a placeholder; CHANGELOG line 25 runs about 88
  columns in a 76-column paragraph.
- T5: `lockEntryFields` throws `RangeError`, not `FormatException`, on a
  quoted `"jet_cad_*":` key (pub never writes them); the success line does
  not say the ref check ran; `--ref ''` exits 1, not 2.
- T6: `host_probe.sh`'s header still says the restaurant package reaches
  the planner at the full sha (true for the override); a bare `dart analyze`
  in `tool/ci` reports `host_probe/lib/main.dart`'s missing
  `restaurant_names.dart` until a probe run copies it (CI's file list
  excludes it).

The whole-branch independent review (an Opus subagent, no Codex) on
`git diff main..HEAD` is the controller's; its findings are recorded below
when it returns.

## Final review

An Opus subagent (no Codex) reviewed `git diff main..c660947`. Verdict:
**With fixes**; 0 Critical. Its report is archived with the ledger
(`final-review.md`). It measured, in a throwaway worktree at `c660947`:

- the dry runs: `jet_cad_2d_flutter` 226 KB and `jet_cad_floor_plan`
  462 KB, both exit 0 with 0 warnings;
- the archive listings: the renderer's has no `test/`, `build/` or
  `shaders/`; the planner's has `furniture.jetlib`, `Roboto-Regular.ttf`
  and `Roboto_LICENSE.txt`, and no `test/`, `tool/` or `build/`;
- every README snippet and name, analysed against its barrel, clean;
- `names.dart` (then after the sed rewrite) analysed clean against the
  planner's barrel, and `symbol_sources.dart` exports `SymbolNames`
  (R-12);
- an analyzer-based API audit of the host barrels: nothing in the
  renderer; in the planner, `SymbolLibraryState` and
  `TableNumberProblem`, plus `ExportChoice` and `ExportFontCache`, which
  are reached only through `@internal` members;
- the only non-comment `lib/` change in either package since v0.7.0:
  `editor.dart`'s `hide readBundledLibrary`;
- the engine at `c660947`, which differs from `1dc167d` only in its README;
- `tool/ci` `dart test` +77 and `check_guide` 56 blocks;
- that `a-urel/jet-cad` is public.

Two Important findings and eight Minors; the fix wave (BASE `c660947`) applied F1-F9:

| Item | Finding | What changed |
|---|---|---|
| F1 | STATUS "Resume here", the D7 step, could not work: the probe's `main.dart` imports `restaurant_names.dart` and its pubspec declares `assets/restaurant.jetlib`, both git-ignored files only `host_probe.sh` creates from the overridden package | `STATUS.md` spells out the human's commands: a `mkdir -p` of the untracked `assets/`, two `cp`, a `sed` that drops the `dependency_overrides:` block, a `grep` for `@URL@`/`@REF@`, `pub get`, `check_host_lock.dart` without `--ref`, `flutter analyze`, the optional build. Steps 1-3 were run in a scratch copy (see the fix report); step 4 on was not (the packages are not on pub.dev) |
| F2 | Resume step 1: publishing the engine after this branch's merge would upload the rewritten README (R-5) under the tag `jet_cad_2d-v0.7.1` → `1dc167d` | `STATUS.md`: publish the engine from `main` as it stands (`d41e5f6`) before the merge; steps 2-3 tag "the commit `main` points at after the merge" |
| F3 | The probe job's name said "by git" | `.github/workflows/ci.yml`: "a host from pub.dev, repo packages overridden" (the branch is not protected, so the rename breaks no required check) |
| F4 | `host_probe.sh` header: the full-sha rationale was stale | reworded: `check_host_lock.dart --ref` compares it exactly with each `resolved-ref` |
| F5 (R-12) | the `sed` import rewrite was a needless host step | `host_probe.sh` copies `names.dart` verbatim; the guide's subsection drops the rewrite, says what the copy imports, and names the reader's imports (`dart:typed_data`, `rootBundle`) and `import 'restaurant_names.dart';`; this note's D11 step 3 likewise. SC14 did not pin the `sed` line |
| F6 | the planner README said `symbol_sources.dart` holds "the sources and their loader's Flutter side" | it exports `SymbolLibrarySource`, `furnitureSymbolSource`, `readBundledLibrary` and `SymbolNames`; the loader is on the main barrel |
| F7 (R-11) | R-10's consequence for the guide | the `FloorPlanStrings` bullet steers a host to `FloorPlanStringsEn`/`De`/`Tr` and says a direct implementer must also write the abstract `tableNumberProblem(TableNumberProblem)`, a type the 0.7.1 barrel does not export |
| F8 | the guide's "Schema 10" bullet named 0.6.0 and 0.7.0 | adds 0.7.1 (the planner CHANGELOG: plans stored as in 0.7.0, schema 10) |
| F9 | this note | the `package_root.dart` path, R-10 to R-13, this section, the probe record below |

Left (R-13): Minor 7 (the root CHANGELOG says "published" before the
publish) and Minor 8 (the example test calls `symbols.load` itself).

**Open for the human (R-10):** the reviewer recommends exporting
`SymbolLibraryState`, `SymbolLibraryLoading`, `SymbolLibraryReady`,
`SymbolLibraryFailed` and `TableNumberProblem` from
`jet_cad_floor_plan.dart` **before** 0.7.1 is published, because the
barrel's header calls a host's need for an unexported type a finding, D9
makes the loader's failure state matter to a host, and
`tableNumberProblem` is abstract. The branch publishes the barrels as
they stand (D4, R-10, R-11); adding the exports is non-breaking and one
small commit, but widening the published API is the human's call.

## Owed

- **The human, in order (STATUS, Resume here):** `jet_cad_2d` 0.7.1 —
  push `main`, CI green, dry run, publish, tag `jet_cad_2d-v0.7.1` on
  `1dc167d`; then `jet_cad_2d_flutter` 0.7.1 — merge of this branch,
  lower bounds, pana's lower-bounds section green, dry run, publish, tag
  `jet_cad_2d_flutter-v0.7.1` on the merge commit; then
  `jet_cad_floor_plan` 0.7.1 the same, tag `jet_cad_floor_plan-v0.7.1`.
  The version visible on pub.dev after each.
- **pana** on the two dependents after each dependency is on pub.dev (R-4).
  The engine's 160/160 is likewise expected, not measured.
- **D7:** after the planner, resolve a scratch copy of
  `tool/ci/host_probe/pubspec.yaml.in` with its `dependency_overrides`
  block removed, `flutter analyze`, and record the result here.
- **CI on the pushed branch** (Linux): the whole workflow, `publishable`
  for three packages, the probe and the four old probes; the push is the
  human's word.
- **D11**, in the restaurant software (above).
- **The human's ruling** on the dormant `packages/jet_cad` (no
  `publish_to`), carried from the engine's review.
- **The engine README (R-5):** its "Where it comes from" paragraph is
  rewritten on this branch (the renderer and the planner are on pub.dev
  too); the engine's version is not bumped, so the new text reaches
  pub.dev with its next release.
