### Task 17: The exit gate (spec "Exit gate")

**Files:**
- Create: `docs/superpowers/notes/2026-10-14-plan-library-2b-results.md` (the results of record; the template is Step 9).
- Modify: `STATUS.md` (the "In flight" entry of the kit architecture and "Resume here"; Step 10).
- No code changes. A failure here goes back to the task that owns the code: its fix is a commit of that task's kind (`fix(engine): …`, `fix(kit): …`, `fix(plan): …`), made and reviewed as that task's fix round, never inside this task.

**Interfaces:**
- Consumes: everything of Tasks 1-16; the per-task reports in `.superpowers/sdd/2026-10-14-plan-library-2b/` (each mutation's ID, file, edit and the test that went red; each ported file's source, destination and count; each ruling), as recorded there.
- Produces: the evidence the whole-branch review reads (spec "Exit gate"). The Opus review of the whole branch, its fix wave and the ledger's archive are the coordinator's, after this task.

Plan decision: the results note carries **only** what a command printed in this task's run (quoted, last lines) or what a task report recorded (named as such). A count no command printed is never written; a gate that was not run is written as "not run" with the reason. This is CLAUDE.md's "never synthesize test output" applied to the note (2a's Task 21 rule, kept).

Plan decision: **every publishable package is dry-run**, the five of CI's `publishable` job (`.github/workflows/ci.yml:165-197`): `jet_cad_2d` (its CHANGELOG gained E5), `jet_cad_2d_kit`, `jet_cad_2d_plan`, and the untouched `jet_cad_2d_flutter` and `jet_cad_floor_plan` (to show this branch broke neither). Spec "Exit gate": "Dry-runs of the publishable packages with 0 warnings".

Plan decision: **the STATUS update is this task's**, the ledger's archive is not (the coordinator's last commit, after the review). STATUS says where 2b stands at the exit gate: every task done, the gate passed, the whole-branch review next, nothing merged or pushed.

- [ ] **Step 1: A clean tree.** From the worktree root:
  - `git status --short`. Expected: no output. (A rewritten `analysis_options.yaml` from a pub operation shows as ` M …`; restore it with `git checkout -- <that file>`, a pub artefact, not work, and run the command again.)
  - `git log --name-only --format= main..HEAD | grep analysis_options`. Expected: no output, exit 1 (2b creates no package and stages no `analysis_options.yaml`, Global Constraints).
  - `git log --format='%H %s' main..HEAD | wc -l` and `git rev-parse HEAD`. Record both (Step 9, "Branch").
  - `git rev-parse main` and `git rev-parse origin/main`, and `git merge-base --is-ancestor main HEAD; echo $?` (expected `0`): record them; the note says which `main` the branch stands on (the 2a note's practice).

- [ ] **Step 2: The two contract and plan packages** (spec exit gate: "`flutter test`, `flutter analyze` and `dart format` for `jet_cad_2d_kit` and `jet_cad_2d_plan`").
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` (CI's `test_flags` for this package, Task 14: without the flag the two allocation files skip)
  - Expected shape, each: `flutter test` ends with `NN:NN +<count>: All tests passed!` (a `~<n>` only if a task report recorded a skip with its reason and a ruling kept it; Task 16's Part A skip of BT1 must be gone: `grep -rn "skip:" packages/jet_cad_2d_plan/test/service/view/service_bar_test.dart` prints nothing); `flutter analyze` prints `No issues found!`; the format gate prints `Formatted <n> files (0 changed) …` and exits 0.
  - Then each invariant on its own, quoting the last line: `cd packages/jet_cad_2d_plan && flutter test test/invariants/canvas_paint_allocation_test.dart` (the service scene, Task 15), and the ported `pick_allocation_test.dart` and `band_allocation_test.dart` with `flutter test --enable-vmservice <file>` (Task 14; `find packages/jet_cad_2d_plan/test -name "pick_allocation_test.dart" -o -name "band_allocation_test.dart"` gives their paths).
  - Quote each package's last `flutter test` line, the analyze line and the format line into the note.

- [ ] **Step 3: The tools gate** (spec exit gate: "`cd tool/ci && dart test`; `dart run tool/ci/check_kit_deps.dart`"), as CI's `ci-tools` job runs them (`.github/workflows/ci.yml:117-163`).
  - `cd tool/ci && dart test`. Expected: `All tests passed!`.
  - `cd tool/ci && dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart`. Expected: `No issues found!`.
  - From the repository root: `dart run tool/ci/check_kit_deps.dart`. Expected shape: `kit dependencies: <n> package(s) checked, none names the plan library or another kit`.
  - From the root, the checks CI runs beside it, which this branch must leave green: `dart run tool/ci/check_guide.dart`, `dart run tool/ci/check_readmes.dart` (`package READMEs: all <n> code blocks are in the probes`), `dart run tool/ci/check_screenshots.dart` (exit 0). Quote each line.

- [ ] **Step 4: The three CLAUDE.md gates** (spec exit gate: "CLAUDE.md's gates").
  - `cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_gpu && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - Expected: `jet_cad_2d` and `jet_cad_2d_flutter` fail **exactly** the lines of `tool/ci/standing_failures.txt` for their package (the engine's two document fingerprints; the renderer's text-ladder goldens), and nothing else; every analyze prints `No issues found!`; every format gate exits 0; `jet_cad_2d_gpu` passes whole. Compare each failing-test list with `tool/ci/standing_failures.txt` line by line and say so in the note. Any other failure is a finding: stop, report it to the coordinator with the test's name and output, and do not write the note as passed.
  - In particular, quote on their own: `cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart` (unchanged by E5, spec Tests "Invariants"), the engine's parametric tests with E5's (`dart test test/parametric`), and the engine's standing hash tests' own lines (spec Tests: "the engine's standing hash tests hold"; Task 1's report names them).
  - Also `cd packages/jet_cad_2d && dart analyze --fatal-infos` (CI's form for a Dart package, `.github/workflows/ci.yml:82`): expected `No issues found!`.
  - Once: `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice` (CI's form; expected: its standing state as on `main`; this branch changes nothing there, A12, but E5 changes the engine it runs on), then the other CI matrix entries over the engine, one at a time: `cd packages/jet_cad_restaurant_symbols && flutter test`, `cd apps/floor_planner && flutter test`, `cd apps/restaurant_demo && flutter test`, `cd tool/screenshots && flutter test`. Record each last line. Any failure that `main` does not have is a finding for Tasks 1-2 (E5 is additive: spec S1 "Version").

- [ ] **Step 5: The publish dry runs.** **Never** run `dart pub publish` without `--dry-run`.
  - `cd packages/jet_cad_2d && dart pub publish --dry-run`
  - `cd packages/jet_cad_2d_flutter && dart pub publish --dry-run`
  - `cd packages/jet_cad_2d_kit && dart pub publish --dry-run`
  - `cd packages/jet_cad_2d_plan && dart pub publish --dry-run`
  - `cd packages/jet_cad_floor_plan && dart pub publish --dry-run`
  - Expected, each: exit 0 and `Package has 0 warnings.` A dependent's dry run does not need its dependency on pub.dev (CI's comment, spec F-2 of the publishing plan).
  - For `jet_cad_2d_plan`, the printed file list holds `LICENSE`, `README.md`, `CHANGELOG.md`, `example/main.dart`, `lib/jet_cad_2d_plan.dart`, `lib/fonts/Roboto-Regular.ttf` and `pubspec.yaml`. From the root, for each of the five: `cmp LICENSE packages/<package>/LICENSE`. Expected: each prints nothing.
  - A warning is a finding for the task that owns the file it names (a CHANGELOG: Task 2 for the engine's, Task 3 for the kit's, Task 16 for the plan library's; a pubspec field: whoever touched it). Never change a version or a dependency constraint to silence one (Global Constraints: no version changes).

- [ ] **Step 6: The constraints, checked by hand.** Each command from the repository root; quote its output (or "printed nothing") into the note.
  - **The old packages are untouched** (A12): `git diff --stat main -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu packages/jet_cad_2d_flutter apps` prints nothing.
  - **The engine changed only in Tasks 1 and 2**: `git log --format='%h %s' main..HEAD -- packages/jet_cad_2d` lists only Task 1's and Task 2's commits and their fix rounds (named so in the ledger).
  - **No import of the old planner or the restaurant symbols**: `grep -rn "import 'package:jet_cad_floor_plan\|import 'package:jet_cad_restaurant_symbols" packages/jet_cad_2d_plan packages/jet_cad_2d_kit` prints nothing; `grep -rn "jet_cad_floor_plan\|jet_cad_restaurant_symbols" packages/jet_cad_2d_plan/lib packages/jet_cad_2d_plan/test packages/jet_cad_2d_plan/example packages/jet_cad_2d_plan/pubspec.yaml packages/jet_cad_2d_kit/lib packages/jet_cad_2d_kit/pubspec.yaml | grep -v ":[0-9]*: *//"` prints nothing (every hit is a comment citing a ported source); record the unfiltered count.
  - **The contract depends on neither the plan library nor a kit (A1)**: `grep -n "jet_cad_2d_plan\|jet_cad_2d_kit_" packages/jet_cad_2d_kit/pubspec.yaml` prints nothing.
  - **The contract's pure files stay pure**: `grep -rln "package:flutter\|dart:ui" packages/jet_cad_2d_kit/lib/src/model packages/jet_cad_2d_kit/lib/src/authoring packages/jet_cad_2d_kit/lib/authoring.dart packages/jet_cad_2d_kit/lib/src/kit/unit_label.dart packages/jet_cad_2d_kit/lib/src/kit/host_words.dart packages/jet_cad_2d_kit/lib/src/kit/properties.dart packages/jet_cad_2d_kit/lib/src/kit/colour.dart` prints nothing (Task 3 writes `unit_label.dart` as pure Dart; the kit's purity test is the binding check).
  - **No `dart:io` in a library**: `grep -rn "import 'dart:io'" packages/jet_cad_2d_plan/lib packages/jet_cad_2d_kit/lib packages/jet_cad_2d/lib` prints nothing.
  - **No version changed**: `grep -n "^version:" packages/jet_cad_2d/pubspec.yaml packages/jet_cad_2d_flutter/pubspec.yaml packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml` prints `0.7.2`, `0.7.2`, `0.1.0`, `0.8.0`; `git diff main -- packages/*/pubspec.yaml | grep "^[-+][^-+]"` prints exactly one line, `+  vm_service: ^15.2.0` in `jet_cad_2d_plan`'s `dev_dependencies` (ruling R-23); no other constraint changed.
  - **The CHANGELOGs**: `grep -n "## Unreleased" packages/jet_cad_2d/CHANGELOG.md` prints one line, and `sed -n '/## Unreleased/,/^## [0-9]/p' packages/jet_cad_2d/CHANGELOG.md | grep -n "E5\|GeneratedInstance\|instances"` shows E5 as a feature with the refused group add (spec S1 "Version"); `git diff --stat main -- packages/jet_cad_2d_kit/CHANGELOG.md packages/jet_cad_2d_plan/CHANGELOG.md` shows both changed (their 2b additions in their unreleased sections).
  - **The spec amendments**: `grep -n "2026-10-14-plan-library-service-mode-design" docs/superpowers/specs/2026-09-26-rooms-design.md` prints the D12 amendment line (Task 2; spec S1 "The rooms spec gets an amendment line"); `grep -n "unitChanges" docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md` prints P7's amendment line (spec S3: "2a's P7 gets an amendment line"). The P7 line is already on the branch (controller ruling R-6: commit `46866765`, line 668 of the 2a spec); this step only checks it. A missing line is a finding for the coordinator.
  - **Draw order and the frame path**: the invariants of Steps 2 and 4 passed; `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` passed in Step 4 (the Flutter layer unchanged).
  - **The sample kit still regenerates to its bytes** (Task 3 touched the contract): `cd packages/jet_cad_2d_kit && dart run test/fixtures/sample_kit/generate.dart`, then from the root `git diff --quiet -- packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample.jetlib packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample_snapshot.json` exits 0.
  - `git status --short` prints nothing after all of the above.

- [ ] **Step 7: The spec coverage table.** Build it from the task reports and the plan's task bodies, never from memory: for each row below, the test ids that pin it. Every row must name at least one test id that exists in the tree: check each with `grep -rn "<id>" packages/jet_cad_2d/test packages/jet_cad_2d_kit/test packages/jet_cad_2d_plan/test tool/ci/test` (a test's name starts with its id) and write `missing` in the row when the grep finds nothing. A `missing` row is a finding for the task that owns it, reported before the note is committed. The rows (spec sections, the tasks that own them, the id prefixes to look for):

| Spec requirement | Task(s) | Ids to find |
|---|---|---|
| S1 the output: `GeneratedInstance`, `GeneratedAttrib`, their `ArgumentError`s; `instances`' default | 1 | `E5-*` (`E5-default`) |
| S1 the definition: `GeneratedDefinitionError` (probe returns, drift throws) | 1 | `E5-def` |
| S1 the survey and matching: by position, ATTRIBs by tag, the own tag kept, the lowest of a duplicated tag, an unchanged row plans nothing | 1 | `E5-shrink`, `E5-noop`, `E5-tag`, `E5-dup-tag` |
| S1 the instance on its object's layer, ATTRIBs on layer 0; draw order | 1 | `E5-layer`, `E5-order` |
| S1 the guard: two branches; a component write passes and seeds nothing; adds refused | 2 | `E5G-refuse`, `E5G-component`, `E5G-add`, `E5G-undo` |
| S1 the dissolve gap closes | 2 | `E5G-dissolve` |
| S1 version: E5 in the engine's CHANGELOG; the rooms spec's amendment | 2, 17 | Step 6's greps |
| S1 `GuardedType` wraps `instances` | 4 | `PB-guard` |
| S2 a unit, placed and generated; `nested`; a held object stays held (R-9) | 6 | `UI-generated`, `UI-flip` |
| S2 locked units: `isLockedUnit`; frozen and missing-kit seats; a missing kit's seat locks its row | 6, 14 | `UI-missing-kit`, `UI-frozen-no-edit`, `UI-def-kit-missing`, `UI-held-seat-row-locked`, `ST-locked-seat` |
| S2 in design a generated unit stands for its object (pick, band, plain group) | 8 | `DS-click-seat`, `DS-click-attrib`, `DS-crossing`, `DS-window`, `DS-plain-group` |
| S2 `UnitIndex`, its cache and rebuild key | 6 | `UI-*`, the ported `table_index_test` |
| S2 the label: placed `numbered` and `assigned`; `nextUnitNumber`; the text rule | 6, 7 | `UI-next`, `UL-place-number`, `UL-assigned` |
| S2 the label system and the expander stack | 7 | `UL-stack`, the ported label system tests |
| S2 diagnostics; unlabelled, duplicate and bad labels | 6, 12, 14 | `UI-dup`, `UI-unlabelled`, `UI-bad`, `SS-dup-label-status`, `ST-unlabelled` |
| S2 per-unit data and colour, across regeneration | 6, 9 | `UA-seat-data`, `UA-shrink-data`, the ported data and colour tests |
| S2 uniqueness is the tool's: two rows, two prefixes | 5 | `TK-two-rows` |
| S2 the contract gains: `symbolDefinition`, `symbolsState`, `SymbolsState`, `unitLabelAttrib`, `PlanGate.relabel`, the `assigned` doc | 3, 4 | `K2B-*`, `PB-def-twice`, `PB-def-null` |
| S3 mode and copy; 2a's members in service; the members that switch | 11 | `SM-members`, `SM-execute-false` |
| S3 the copy's lock expander and failure boundary; the retry; the design's history untouched | 11 | `SM-copy-boundary`, `SM-copy-lock` |
| S3 the record: format, strict match, groups applied whole, `ServiceRestore`, errors | 13 | `SR-roundtrip`, `SR-groups-replaced`, `SR-invalid-groups`, `SR-locked-move-dropped`, `SR-old-format-refused` |
| S3 `serviceEdited`, `serviceChanges`' timing, `resetService` | 13 | `SR-edited-after-enter`, `SR-changes-timing`, `SR-reset` |
| S3 service state by label; kept across switches, reset, restore, load, newPlan | 12 | `SS-mixed-group`, `SS-shrink-group`, `SS-locked-not-selected` |
| S2 a changed label leaves statuses, groups and focus behind (spec Tests "a relabelled unit leaving its group") | 12, 15 | `SS-relabel`, the ported `SP4` |
| S3 the unit API and the design writes | 9 | `UA-locked-write`, `UA-label-used`, `UA-label-seat` |
| S3 `unitChanges` for a row edit | 9 | `UA-changes-row` |
| S4 `PlanServiceView` alone and in `PlanEditor`; its options passed through | 16 | `SV-1`, `SV-2`, `SV-8`, `SV-9` |
| S4 the service tool, the drag, the picker | 14 | `ST-seat`, `ST-mixed-drag`, `ST-band-two-rows`, the ported tool tests |
| S4 the service bar; Merge and Split under `serviceMerge` | 16 | `SV-4`, the ported `bars_test` service parts (BC1, BT1, BT2) |
| S4 unit overlays, seats included; rebuilt at the host's rebuild only | 16 | `SV-6`, `SV-10`, the ported `TO1` … `TO33` |
| S4 the events | 16 | `SV-7`, the ported `VE1` … `VE18` |
| S4 the unit inspector and the unit section | 10 | `UW-*`, the ported section and inspector tests |
| S4 painting: today's order; the unit colour opacity to every exporter | 15, 16 | `SP-*`, `SV-5` |
| S4 theme: the thirteen fields | 15 | `SP-*`, the ported theme tests |
| S4 permissions: `relabel`, `selectUnitsOnly`, `serviceMove`, `serviceMerge`, `unitsOnly`, `isUnitSymbol`; the design flags never gate service | 3, 8, 16 | `DS-units-only`, `DS-perm`, `SV-3`, `SV-4` |
| S4 words; the kind lookup; host words; the `unit:` namespace; `unitKindWord` | 3, 4, 10 | `K2B-*`, `PB-words`, `UW-kind-lookup`, `UW-host-word-first`, `TK-conformance` |
| S5 the controller rows (each row 2b owns) | 9, 11-13, 16 | one id per row, as the task reports map them |
| S5 the view rows | 14, 16 | one id per row |
| S5 the capabilities, theme, words and components rows | 3, 6, 8, 10, 15 | one id per row |
| R-13: the plan kept in place across a mode switch (2a's deferral) | 16 | the ported `V7a` … `V7h`, R-3, K1 |
| Review Focus 1 (a row shrunk under data, status, group) | 1, 9, 12 | `E5-shrink`, `UA-shrink-data`, `SS-shrink-group` |
| Review Focus 2 (record saved, design edited, restored) | 13 | `SR-design-edited` |
| Review Focus 3 (two rows placed) | 5 | `TK-two-rows` |
| Review Focus 4 (rows of a missing kit) | 6, 14 | `UI-missing-kit`, `ST-locked-seat` |
| Review Focus 5 (500 seats in 25 rows) | 14 | the ported `pick_allocation_test`, `band_allocation_test` |
| Invariants: `canvas_paint_allocation_test` with the service scene; `query_allocation_test` unchanged | 15 | the invariant's id; Step 4's run |

- [ ] **Step 8: The ported tests and the mutations.** From the task reports only:
  - Every source file each task ported, its destination, the count of tests the report named, and "assertions unchanged", or the finding and its ruling (a retirement by ruling, a moved assertion). Check, by `grep -rln "Ported from jet_cad_floor_plan/test/<source>"` over `packages/jet_cad_2d_plan/test`, that each listed destination carries its port comment; a destination with none is a finding for its task.
  - Every mutation each report recorded: its id, task, file, the edit, the test that went red. A named mutation that did not turn its test red is listed with its resolution (a test strengthened in the fix round, or a ruling).
  - The spec's "Tests" bullet "Ported, assertions unchanged" names `jet_cad_floor_plan`'s service, table, group, focus, overlay, event, host-data and theme tests and its two allocation tests: list, from `ls packages/jet_cad_floor_plan/test/host packages/jet_cad_floor_plan/test/service packages/jet_cad_floor_plan/test/tables packages/jet_cad_floor_plan/test/colors packages/jet_cad_floor_plan/test/invariants`, every such source file, and against each either its destination (from the reports) or the ruling that left it (a design-mode file 2a ported, a retirement). A source file with neither is a finding.

- [ ] **Step 9: The results of record.** Create `docs/superpowers/notes/2026-10-14-plan-library-2b-results.md` from this template. Every `<…>` is filled from this task's run or from a task report; a section whose command was not run says so and why.

````markdown
# The plan library in service mode (sub-project 2b): results of record

Branch `feat/plan-library-2b`, head at the exit gate: `<git rev-parse HEAD>`
(the commit that adds this note sits on top of it); `<n>` commits over `main`
(local `main` at `<sha>`, an ancestor of the head; `origin/main` at `<sha>`).
Plan: `docs/superpowers/plans/2026-10-14-plan-library-2b.md`. Spec:
`docs/superpowers/specs/2026-10-14-plan-library-service-mode-design.md` (revision 4).
All transcripts below were copied from the terminal on `<date>`, last lines only.

Two kinds of evidence appear below, and each is named as such:
- **this run**: a command run by Task 17 on the head above, its output quoted;
- **report**: what a task report in `.superpowers/sdd/2026-10-14-plan-library-2b/`
  recorded (`task-N-report.md`), not re-run here.

## Gates

### 1. `packages/jet_cad_2d_kit`

`flutter test` (this run, exit `<code>`):

```
<last line as printed>
```

`flutter analyze`: `<line>`. Format: `<line>`.

### 2. `packages/jet_cad_2d_plan`

`flutter test` (this run, exit `<code>`):

```
<last line as printed>
```

`flutter analyze`: `<line>`. Format: `<line>`.
The invariants on their own: `canvas_paint_allocation_test`: `<line>`;
`pick_allocation_test`: `<line>`; `band_allocation_test`: `<line>`.

### 3. Tools

`cd tool/ci && dart test`: `<line>`. `dart analyze --fatal-infos …`: `<line>`.
`check_kit_deps`: `<line>`. `check_guide`: `<line>`. `check_readmes`: `<line>`.
`check_screenshots`: `<exit status and line>`.

### 4. The three CLAUDE.md gates

`packages/jet_cad_2d` (`dart test`, exit `<code>`):

```
<last line and the "Failing tests:" list as printed>
```

Compared with `tool/ci/standing_failures.txt`: `<"exactly its jet_cad_2d lines" or the difference>`.
`dart analyze`: `<line>`; `dart analyze --fatal-infos`: `<line>`. Format: `<line>`.
`query_allocation_test`: `<line>`. `test/parametric`: `<line>`. The standing hash tests: `<lines>`.

`packages/jet_cad_2d_flutter` (`flutter test`, exit `<code>`):

```
<last line and the "Failing tests:" list as printed>
```

Compared with `tool/ci/standing_failures.txt`: `<…>`. `flutter analyze`: `<line>`. Format: `<line>`.

`packages/jet_cad_2d_gpu`: `<test line>`, `<analyze line>`, `<format line>`.

`packages/jet_cad_floor_plan` (`flutter test`, untouched, run once): `<last line>`.

### 5. Publish dry runs

`jet_cad_2d`: exit `<code>`, `<line>`. `jet_cad_2d_flutter`: exit `<code>`, `<line>`.
`jet_cad_2d_kit`: exit `<code>`, `<line>`. `jet_cad_2d_plan`: exit `<code>`, `<line>`; the
file list holds `<the files Step 5 names, as printed>`. `jet_cad_floor_plan`: exit `<code>`, `<line>`.
`cmp LICENSE packages/<package>/LICENSE`, the five: `<printed nothing>`.

### 6. Hand checks

- `git status --short`: `<empty before and after every gate>`.
- `git log --name-only --format= main..HEAD | grep analysis_options`: `<printed nothing>`.
- Old packages: `<printed nothing>`.
- Engine commits: `<the list>`.
- Old-package imports, contract dependencies, purity, `dart:io`: `<each grep's output>`.
- Versions and constraints: `<the four version lines; the pubspec diff printed nothing>`.
- CHANGELOGs: `<the engine's Unreleased line and its E5 lines; the two diffstat lines>`.
- Spec amendments: `<the rooms spec's line; the 2a spec's P7 line>`.
- Sample kit regenerated, `git diff --quiet` on its two fixtures: `<exit 0>`.

## Spec coverage

Every id below was found in the tree by this run's grep, as the first token of a test name.

| Spec requirement | Task(s) | Test ids |
|---|---|---|
| `<one row per Step 7 row>` | `<…>` | `<ids, or missing>` |

## Ported tests (A12)

| Source (`jet_cad_floor_plan/test/…`) | Destination | Tests | Assertions |
|---|---|---|---|
| `<…>` | `<…>` | `<n>` | `<unchanged / finding: … ruling: …>` |

Source files of the spec's ported families left unported, each with its ruling: `<…, or none>`.

## Mutations of Tasks 1-16

As the task reports record, each ran on a committed file and was reverted with
`git checkout --`, then `git diff --quiet`.

| ID | Task | File | The change | Red test |
|---|---|---|---|---|
| `<…>` | `<…>` | `<…>` | `<…>` | `<…>` |

## Plan decisions

One line each, in task order, copied from the plan's "Plan decision" paragraphs.

## Deliberate host-API differences (for sub-project 4's parity table)

From spec S5's rows marked **difference**, and any a task report added, each with
the test that pins it: `<…>`.

## Spec gaps and interface problems found while executing

Each `#### Interface problem` of the plan's task bodies and each finding a task report
raised against the spec, with its resolution (amendment, ruling, or carried to sub-project
3 or 4).
````

- [ ] **Step 10: STATUS.** In `STATUS.md`:
  - In "In flight", the kit architecture's entry: after the sentence ending "Next: 2b, the service mode, from a brainstorm." (or its successor, if the coordinator has edited it during 2b), replace that sentence with:

    ```markdown
    **2b, the plan library in service mode** (`jet_cad_2d_plan` 0.8.0 still
    unreleased, the contract's 2b additions, engine seam E5): spec
    [2026-10-14-plan-library-service-mode-design.md](docs/superpowers/specs/2026-10-14-plan-library-service-mode-design.md)
    (rev 4, approved), plan
    [2026-10-14-plan-library-2b.md](docs/superpowers/plans/2026-10-14-plan-library-2b.md)
    (17 tasks), results
    [2026-10-14-plan-library-2b-results.md](docs/superpowers/notes/2026-10-14-plan-library-2b-results.md),
    on `feat/plan-library-2b` (worktree `.claude/worktrees/plan-library-2b`).
    Every task done and reviewed, the exit gate passed at `<head sha>`; the
    whole-branch review, its fix wave and the ledger's archive are next. Not
    merged, not pushed.
    ```

  - In "Resume here", the first paragraph's last sentences ("Sub-project 2a … is merged at `4130ebc`, not pushed. Next: 2b (the service mode), from a brainstorm") become: "Sub-project 2a (the plan library in design mode) is merged at `4130ebc`, not pushed. **2b (the service mode) passed its exit gate on `feat/plan-library-2b` at `<head sha>`; next: the whole-branch Opus review and its fix wave, then the ledger archived and the merge on the human's word.**" Keep "Open for the human: A14's `selectTool`-without-a-view difference." only if the 2b spec's decision 9 did not close it; it did ("true kalsın", 2026-10-14), so replace it with: "A14's `selectTool` difference was settled by the human (2b spec decision 9: true kept)."
  - "Last updated" at the top: the date of this run.
  - Every `<…>` filled from this run; no other line of STATUS changes.

- [ ] **Step 11: Commit.**

```bash
git add docs/superpowers/notes/2026-10-14-plan-library-2b-results.md STATUS.md
git commit -m "$(cat <<'EOF'
docs: the plan library in service mode, results of record

The exit gate's transcripts, the spec coverage table, the ported-test
and mutation tables, the plan decisions and the host-API differences of
sub-project 2b (E5, the contract's 2b additions and jet_cad_2d_plan's
service mode), for the whole-branch review; STATUS says 2b passed its
gate and the review is next.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Hand over.** The independent Opus review of the whole branch, its fix wave, and the ledger archived onto the branch as its last commit (spec "Exit gate") are the coordinator's next steps. Nothing is pushed, tagged, merged or published from this task.

There is no Mutation step: this task changes no code.

---

## Appendix: rulings made while planning (2026-10-14)

The executor records each one that changes a test's premise as a ledger `Ruling:` line when its task runs.

- R-1 (from W2's Task 3 interface problem): GuardedType implements ParametricType, so Task 1 adds the guarded `instances` forwarder to jet_cad_2d_plan/lib/src/kits/guard.dart and runs the plan library's analyze+test in its gates. Task 4 keeps only the PB-guard tests. Sent to W1 before it finished.
- R-2: conformance.dart lives at jet_cad_2d_kit/lib/src/authoring/conformance.dart; fix the skeleton's File structure.
- R-3: W2's plan decisions accepted as written (label height on empty top = 200; unit: like category:, English only; validateHostWords codes unknownWordId/foreignWordId; full relabel flag in Task 3; KitServices stubs in Task 3; pending refs per controller; host words via @internal PlanController.namesOf; barrel re-exports SymbolsState).
- R-4 (W1's interface problem "R-2", engine test CS11, cascade_test.dart:623-672): accepted as W1 proposed, with one preference. Under spec S1 an InstanceNode directly under a live object IS a generated instance, so CS11's premise `drift(doc) isEmpty` becomes `[hP1]` (Task 1, with a comment citing spec S1), and its adds into P1 are now refused (Task 2). CS11's purpose (the cascade removes the object's whole subtree, undo exact) is kept: Task 2 builds that subtree as a loaded file would — prefer the tree/store API directly if one exists (as the test already does for the definition); otherwise null `doc.commands.expander` around the three adds with a comment "a loaded file's shape". Every other assertion is unchanged. The executor records this as a ledger ruling (an existing engine test's premise changed by the spec, not a weakened assertion).
- R-5: W1's private survey maps (`generated`, `leaves`, `nested`) and "added is read from the before-survey" accepted.
- R-6: 2a spec P7's amendment line for designChanges/unitChanges is ALREADY on the branch (commit 46866765, line 668 of the 2a spec); Task 17 only checks it.
- R-7: Task 16 may be dispatched as 16a and 16b (its two parts), each with its own review.
- Pending for the reconcile pass (W7's interface problems): ServiceHost on ServiceSession (Tasks 11/14), @internal PlanController.unitDetailInstances (Task 9), groupIdsByLabel (Task 12), painter constructors and the flows' opacity parameter (Task 15), the ported test fixtures' owner (earliest task that needs them creates test/support/service_fixtures.dart; later tasks reuse).
- R-8 (W3): UnitIndex.diagnostics() returns the engine's List<Diagnostic> (KitDiagnostic's code is an enum without unit.*). Update the skeleton's Shared interfaces.
- R-9 (W3): spec S2 "a held object flips" amended to "stays held" (commit on branch); UI-flip pins served+locked, kit loaded or not.
- R-10 (W3): PlanController.unitIndex lands in Task 6. P-1 fixture keys test.fixture.* accepted (fixture data, 2a precedent; ledger ruling at execution). P-2 accepted. unitKit() = testKit(units: true) accepted. placeSymbol gains `UnitIndex? units`.
- Check in reconcile: Task 7's UL-seat assumes regeneration's CommandResult.touched includes added seats (Task 1).
- R-11 (W5): proposed premise rulings accepted for execution: R11-a (VR1-VR3 not ported: sessions own the systems), R13-a/b (format name and keys; renames), R13-c (TG-C10's serviceEdited flips: groups count, decision 4 difference), R13-d (TG-C11's resetLayout step retired; SR-reset pins the new rule). Each is a ledger ruling at execution, citing the spec difference.
- Reconcile notes (W5): Task 11 adds selectedUnits if Task 9 does not; ServiceSession tool factory then Task 14's additions; @internal groupLookup/statusOf, GroupUnit.generated, UnitGroupLookup.byLabel, hasGeneratedVisibleMember, groupIdsByLabel; test support files: Task 11 creates test/support/service_plans.dart — Task 16's service_fixtures.dart and any Task 15 serviceCopyOf helper must not clash (reconcile to one support file).
- R-12 (W4 interface problem): UnitPicker is created in Task 8 as `UnitPicker(DraftDocument document, UnitIndexCache units, {bool skipLocked = false, bool placedOnly = false, @visibleForTesting leavesByOwner, invert})` with `UnitInfo? pick(Vector2 world, {double reach = 0})`, `candidates`, static `candidatesOf`. Task 9 and Task 14 consume it. Update the skeleton's Shared interfaces (move UnitPicker to Task 8).
- R-13 (W4 F-T9a/b/c): accepted as execution rulings: the undo labels become "Unit data"/"Unit colour" (S5 renames); toString texts gain the kind token (extends 2a's class-name ruling); DC8/9/11/12/13/17 ported a second time for unitChanges (a second stream, both need the oracle).
- R-14 (W4): 2a's PM-8 restrictsPick expectation becomes isTrue (spec S2: the design's pick is always restricted); PM-1/PM-7 grow; ED-9 gains exports. Execution rulings.
- Reconcile: test support files proliferated — T5 serviceFixture() in test_kit.dart, T8 unit_fixtures.dart + unit_editor_fixture.dart, T9 unit_embedding_fixture.dart, T11 service_plans.dart, T16 service_fixtures.dart, maybe T15's. Consolidate: each helper has exactly one owner (the earliest task), later tasks import it; no duplicate names (serviceCopyOf).
- R-15 (W6): view-level ports (service_options_test, band_view_test, table_groups_gesture_test, table_groups_context_test, theme_service_test, status_caption_test, table_groups_look_test, table_fill_test TF6 + TF7's service tail as TF7b, floor_plan_theme_test's service-mode resolution tests) belong to Task 16 (they need PlanServiceView). Task 15's service_paint.dart harness stays for painter-level tests only.
- R-16 (W6): TF1/TF7/EX5 room and tint lines go to sub-project 3 (2a precedent); execution ruling.
- R-17 (W6): ServiceHost + settable ServiceSession.host adopted; ServiceSession.tool is a ServiceTool (Task 11's tool factory and _IdleTool removed — Task 11 must not create them, or Task 14 removes them; reconcile picks one); ServiceOptions has no serviceMove (the tool reads the permission per press).
- R-18 (W6): Task 14's CI change (`--enable-vmservice` for the plan library's entry, SC20b) accepted if 2a's allocation tests need it; reconcile checks how 2a's canvas_paint_allocation_test runs in CI and keeps one consistent mechanism.
- R-19 (reconciler; from the Reconcile notes on test support): one owner per test-support helper, the earliest task; later tasks append to the owner's file or import it, never redeclare a name.
  - `test/support/unit_fixtures.dart` is Task 6's (it ports `table_fixture.dart`). Its shared symbols take Task 8's form, because five later tasks (8, 9, 10, 14, 15) load them with `fxKit()`: the fixture kit `fx` (`fxKitId`, `fxKit()`), keys `fx.*` (`fx.table.two`, `fx.stool.round`, `fx.planter.round`, `fx.table.one`, `fx.trapezoid.two`), `tableUnit`, `entryOf` built by hand (an open first leaf can be placed). R-10's P-1 stands with these values: TI1's key list reads `fx.stool.round`/`fx.table.two` (fixture data, 2a precedent). Task 8 appends (`sideChairTable`, `openTable`, `unitPlan`, `placeUnit`, `placeAt`, `placeTurned`, `worldOf`, `addLayer`, `addUnitLabel` (over Task 6's `labelUnit`), `unitsOf`, `pickerOf`, `rowOfTables`, `Tally`, `CountingTransform`, `f64`); Task 14 appends `numberedRowOfTables`, `copyForService`.
  - Task 9's `unit_embedding_fixture.dart` is the one embedding fixture (Task 8's `unit_editor_fixture.dart` holds `embeddingTable`, `embeddingBox`, `embeddingPlacement`, `kEmbeddingHidden`, `kEmbeddingLocked`, re-exported by it). Task 16's `service_fixtures.dart` keeps only `pagePlan`, `kToolbarNumbers` (today's `['12', '3', '7', '20', '5', '8', '9']`) and `toolbarPlanJson`, built over `fxKit()`, and re-exports the two fixtures; its view controllers load `fxKit()` (`rowsController`: `unitKit()`).
  - Task 11's `service_plans.dart` re-exports Task 6's `kDeg37` and Task 8's `addLayer` instead of declaring its own; its `placeUnit(DraftDocument, UnitDef, Transform2, …)` is renamed `placeDef` (Tasks 11-13). Task 14's `service_rig.dart` re-exports Task 11's `parts`.
- R-20 (reconciler): `firstLeafOf` is Task 6's (`units/unit_label.dart`), with today's optional `[Map<Handle, List<int>>? leavesByOwner]` (`table_label.dart:155-181`); Task 8's picker imports it and declares none. Task 6's box-of-the-top helper is not named `unitTopOf` (Task 8's picker owns `UnitTop? unitTopOf(...)`); see R-21 for what it became.
- R-21 (reconciler; spec S2 "today's stamp", `table_label.dart:22-44`): a placed unit's label height reads one box, Task 6's `Aabb2 placedLabelTop(List<(EntityKind, GeometryPayload)> leaves)` / `placedLabelTopOf(CommandTarget, Handle definition)`: the first leaf's box when it is a circle or a polyline (open or closed), else empty (height 200). Task 6's `addUnitLabelCommand`, Task 7's placer, Task 9's `unitLabelCommand` (through `addUnitLabelCommand`) and Task 8's fixture `addUnitLabel` (through `labelUnit`) all read it; `unitTopOfLeaves` stays spec S2's `top` (generated units, `UnitInfo.top`). Before: four implementations, two of them off today's rule for an open polyline or a non-polyline first leaf.
- R-22 (reconciler): `kUnitColourOpacity` had no producer (the Shared interfaces listed it under Task 9; Task 9 declares none, and Tasks 15 and 16 imported "the file that declares it"). Task 15, its first user, declares `const double kUnitColourOpacity = 0.35` in `lib/src/theme/plan_theme.dart`, where today's `kTableColorOpacity` lives (`floor_plan/lib/src/host/floor_plan_theme.dart:14`); Task 16 exports it from the barrel with `PlanTheme`.
- R-23 (pre-flight, Task 14): `jet_cad_2d_plan` gains `vm_service: ^15.2.0` as a dev dependency in Task 14, for the ported VM allocation meter (`pick_allocation_test`, `band_allocation_test` are today's oracle and measure with the VM profiler); the Global Constraints and Task 17's pubspec check allow exactly this line. A dev dependency is not a published constraint for hosts.
- R-24 (pre-flight coverage gap): a missing definition freezing the object through 2a's boundary is pinned on load by Task 6's new Step 11b (`UI-def-missing`).
- R-25 (pre-flight): its nine mechanical fixes are accepted (log: scratch `plan-2b/preflight-log.md`); `SS-relabel` added to Task 12 was written without running — Task 12's reviewer checks it.
