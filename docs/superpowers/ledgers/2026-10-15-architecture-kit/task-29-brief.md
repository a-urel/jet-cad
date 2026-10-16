### Task 29: The exit gate (spec "Exit gate", "Amendments to other specs"; the plan's "Appendix A coverage")

**Files:**
- Create: `docs/superpowers/notes/2026-10-15-architecture-kit-results.md` (the results of record; template in Step 11).
- Modify: `packages/jet_cad_2d_kit/CHANGELOG.md` (3a's additions under `## 0.1.0`), `packages/jet_cad_2d_plan/CHANGELOG.md` (under `## 0.8.0 (unreleased)`), `packages/jet_cad_2d_kit_architecture/CHANGELOG.md` (its `## 0.1.0 (unreleased)` entry, Task 9's heading); every C1 task left its CHANGELOG lines to this task (Tasks 1-7's "CHANGELOG: Task 29").
- Modify, only if Step 9 finds it missing: `docs/superpowers/specs/2026-10-13-kit-architecture-design.md` (the umbrella's `## Amendments`: A13's demos and A11's `apps/floor_planner` → `apps/architecture_demo` move to sub-project 3b, decision 1), and any other amendment line of the spec's list that its C1 task did not write.
- Modify: `STATUS.md` ("In flight" and "Resume here", Step 12).
- No code changes. A failure here goes back to the task that owns the code; its fix is a commit of that task's kind (`fix(kit): …`, `fix(plan): …`, `fix(architecture): …`, `test(integration): …`) made and reviewed as that task's fix round, never inside this task.

**Interfaces:**
- Consumes: everything of Tasks 1-28; the per-task reports in `.superpowers/sdd/2026-10-15-architecture-kit/` (each mutation's id, file, edit and red test; each port's source, destination and count; each ruling), as recorded there; the plan's "Appendix A coverage" table.
- Produces: the evidence the whole-branch review reads (spec "Exit gate"). The Opus review, its fix wave and the ledger's archive onto the branch are the coordinator's, after this task.

Plan decisions:
- **The note carries only what a command printed in this run (quoted, last lines) or what a task report recorded (named as such).** A count no command printed is never written; a gate not run is written "not run" with the reason (CLAUDE.md's "never synthesize test output"; 2a's and 2b's rule).
- **Dry runs: the three packages the spec names** (`jet_cad_2d_kit`, `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture`), 0 warnings each; `jet_cad_2d_integration` is `publish_to: none` and is not dry-run. The untouched publishable packages are not re-run here (A12: Step 6 proves them unchanged by diff).
- **Appendix A is the checklist.** Every row of the spec's A.1 (D-01 to D-50), A.2 and A.3 gets one line in the note: ported (its destination and its tests' ids or names, each found by `grep` in the tree), ruled (the ruling's id and where it is written), or carried to 3b or 4 (by name). A row with none of the three is a finding for the task the plan's coverage table names; this task stops and reports it before the note is committed.

- [ ] **Step 1: A clean tree and the branch.** From the worktree root:
  - `git status --short`: no output (a rewritten `analysis_options.yaml` from a pub operation is restored with `git checkout -- <that file>`, then the command is run again).
  - `git log --name-only --format= main..HEAD | grep analysis_options`: exactly `packages/jet_cad_2d_kit_architecture/analysis_options.yaml` and `packages/jet_cad_2d_integration/analysis_options.yaml`, each once (Task 9's single commit; Global Constraints).
  - `git log --format='%H %s' main..HEAD | wc -l`, `git rev-parse HEAD`, `git rev-parse main`, `git rev-parse origin/main`, `git merge-base --is-ancestor main HEAD; echo $?` (expected `0`): record each for the note.

- [ ] **Step 2: The four plan-line packages** (spec exit gate). One at a time, each line quoted:
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - Expected each: `All tests passed!` (a `~<n>` skip only if a task report recorded it with its reason and a ruling kept it), `No issues found!`, the format line with `0 changed` and exit 0.
  - The invariants on their own, their last lines quoted: `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice test/invariants`; `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/invariants/paint_allocation_test.dart` (IA-alloc, Task 28).

- [ ] **Step 3: The tools gate** (as CI's `ci-tools` job runs it, `.github/workflows/ci.yml:120-169`):
  - `cd tool/ci && dart test` → `All tests passed!`.
  - `cd tool/ci && dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart` → `No issues found!`.
  - `cd tool/ci && dart format --output=none --set-exit-if-changed lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart ../readme_probe/lib` and `dart format --language-version=3.6 --output=none --set-exit-if-changed host_probe/lib` → exit 0 each; `cd tool/readme_probe && flutter analyze` → `No issues found!` (the job's last step).
  - From the root: `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit` (the contract and `jet_cad_2d_kit_architecture`; the count is what it prints, and it must name the new kit: `grep -rn "jet_cad_2d_kit_architecture" tool/ci/lib/kit_deps.dart tool/ci/test` or the check's own output shows it was read).
  - From the root: `dart run tool/ci/check_guide.dart`, `dart run tool/ci/check_readmes.dart`, `dart run tool/ci/check_screenshots.dart`: each line quoted, exit 0.

- [ ] **Step 4: The CLAUDE.md gates** (spec exit gate: the engine's two standing hash lines stay the only failures):
  - `cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_gpu && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - Expected: `jet_cad_2d` and `jet_cad_2d_flutter` fail exactly their lines of `tool/ci/standing_failures.txt` (compare line by line, write the comparison into the note), nothing else; every analyze `No issues found!`; every format exit 0; `jet_cad_2d_gpu` passes whole. Also `cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart` and `cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart`, each last line quoted (CLAUDE.md's frame-path invariants).
  - Once each, for the old line (A12: untouched, still green on the engine as it is): `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice`, `cd packages/jet_cad_restaurant_symbols && flutter test`, `cd apps/floor_planner && flutter test`. Expected: their state on `main` (the branch changes nothing under them, Step 6); a difference is a finding.

- [ ] **Step 5: The dry runs.** Never `dart pub publish` without `--dry-run`.
  - `cd packages/jet_cad_2d_kit && dart pub publish --dry-run`
  - `cd packages/jet_cad_2d_plan && dart pub publish --dry-run`
  - `cd packages/jet_cad_2d_kit_architecture && dart pub publish --dry-run`
  - Expected each: exit 0 and `Package has 0 warnings.` For the kit, the printed file list holds `LICENSE`, `README.md`, `CHANGELOG.md`, `example/main.dart`, `lib/jet_cad_2d_kit_architecture.dart`, `assets/library/furniture.jetlib`, `pubspec.yaml`; from the root `cmp LICENSE packages/jet_cad_2d_kit_architecture/LICENSE` prints nothing.
  - A warning is a finding for the task that owns the file it names (a CHANGELOG: this task, Step 8; a pubspec: Task 9 or 23); never change a version or a constraint to silence one.

- [ ] **Step 6: The constraints, by hand** (each command from the root, its output quoted into the note):
  - The old packages are untouched (A12): `git diff --stat main -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu packages/jet_cad_2d packages/jet_cad_2d_flutter apps` prints nothing.
  - Versions: `grep -n "^version:" packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml packages/jet_cad_2d_kit_architecture/pubspec.yaml packages/jet_cad_2d_integration/pubspec.yaml` prints `0.1.0`, `0.8.0`, `0.1.0`, `0.0.0`; `grep -n "publish_to" packages/jet_cad_2d_integration/pubspec.yaml` prints `publish_to: none`; `git diff main -- packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml | grep "^[-+][^-+]"` prints nothing.
  - The kit's dependencies (Global Constraints, R-P11): `sed -n '/^dependencies:/,/^dev_dependencies:/p' packages/jet_cad_2d_kit_architecture/pubspec.yaml` lists `flutter`, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `meta`, `vector_math`, nothing else; `grep -rn "jet_cad_2d_plan\|jet_cad_2d_kit_[a-z]" packages/jet_cad_2d_kit_architecture --include=*.dart --include=*.yaml | grep -v "jet_cad_2d_kit_architecture"` prints nothing.
  - The integration package's imports (R-P1): `grep -rn "package:jet_cad_2d_plan/src\|package:jet_cad_2d_kit_architecture/src\|package:jet_cad_2d_kit/src" packages/jet_cad_2d_integration` prints nothing; `grep -rln "invalid_use_of_internal_member" packages/jet_cad_2d_integration/test` lists only the files the task reports name (R-P9).
  - The contract and the plan stay kit-free: `grep -n "jet_cad_2d_kit_architecture\|jet_cad_floor_plan\|jet_cad_restaurant_symbols" packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml` prints nothing; `grep -rn "import 'package:jet_cad_floor_plan\|import 'package:jet_cad_2d_kit_architecture" packages/jet_cad_2d_plan packages/jet_cad_2d_kit` prints nothing.
  - The contract's pure files stay pure: `cd packages/jet_cad_2d_kit && flutter test test/invariants/purity_test.dart`, its last line quoted.
  - No `dart:io` in a library: `grep -rn "import 'dart:io'" packages/jet_cad_2d_plan/lib packages/jet_cad_2d_kit/lib packages/jet_cad_2d_kit_architecture/lib` prints nothing.
  - The furniture library regenerates to its bytes (Task 23): `cd packages/jet_cad_2d_kit_architecture && dart run tool/generate_furniture_library.dart`, then from the root `git diff --quiet -- packages/jet_cad_2d_kit_architecture/assets/library` exits 0.
  - The CI jobs (Task 9): `grep -n "jet_cad_2d_kit_architecture\|jet_cad_2d_integration" .github/workflows/ci.yml` shows both packages in the test matrix, the integration package with `--enable-vmservice`, and the architecture kit in the `publishable` matrix if Task 9 put it there (record what is there; a kit not in `publishable` is a finding for the coordinator: the spec's C2 has it publishable).
  - `git status --short` prints nothing after all of the above.

- [ ] **Step 7: Appendix A, closed.** Build the closure table from the plan's "Appendix A coverage" table and the task reports, never from memory. For each row of the spec's A.1 (D-01 to D-50), A.2 (the six types' files, the "other architecture files", the rows carried to 4) and A.3: its owner task, its state (ported / ruled / carried), and the evidence: for "ported", the destination file and at least one test name found by `grep -rn "<name>" packages/jet_cad_2d_kit_architecture/test packages/jet_cad_2d_integration/test packages/jet_cad_2d_plan/test packages/jet_cad_2d_kit/test`; for "ruled", the ruling's id and the task body or ledger line that holds it; for "carried", the sub-project and the line of this note that carries it by name. Rows this run must check particularly:
  - D-35 to D-38 (R-16): Task 28's room-line tests, and `grep -n "hasLength(6), reason: 'A, B, C, U, K and R'" packages/jet_cad_2d_integration/test/service/room_fill_test.dart` prints one line; the plan's `unit_fill_test.dart:535` keeps `hasLength(5)` (the plan's tests stay domain-free, spec C6).
  - D-40 (not added: Task 6's ruling), D-42 (carried to 4), D-49 (3b), D-50 (4), D-16 (4), PA4 (4).
  - D-48: Task 26's Step 12 table, every test named there found by `grep`.
  - A.2's rows carried by name to sub-project 4's parity table (`host/camera_test` CM8-CM14, CM16, CR1-CR6, UC1, UC2; `host/controller_test` CZ2-CZ6, CV1-CV3, CS1-CS4; `host/page_flows_test` PF1; `host/editor_tools_test` T4-c, T4-d, T4-h, T4-i; `host/editor_capabilities_test` EC3, EC4, EC6, EC7, PC8; `host/editor_panels_test` T5-h; `host/seams_test` SM1-SM3; `widget_theme_test` (7); `symbols/symbol_component_test` SC7-SC12; `package_assets_test` PA4): listed in the note under "Carried to sub-project 4", each by name.
  - A.3: WE1, SS16, SS17 and the layer picker's wall case (Tasks 28, 26); everything else of `apps/floor_planner/test` listed under "Carried to sub-project 3b".
  - Every assertion line a task left out by a ruling marked **human** (Task 28's IA-R3, IA-R4, IA-R5, and any other task's), listed under "Lines dropped, the human's word" with the human's answer when the ledger records it, or "pending" (a pending one is said in STATUS, Step 12).

- [ ] **Step 8: The CHANGELOGs.** Check each name below exists before writing it (`grep -rn "<name>" packages/<pkg>/lib`); a name a ruling changed is written as the code has it.
  1. `packages/jet_cad_2d_kit/CHANGELOG.md`, under `## 0.1.0`, appended:

```markdown
- Sub-project 3a (the architecture kit's contract amendments): the symbol
  box family (`SymbolBox`, `isOrthonormal`, `boxOfLeaves`, `boxOfEntry`,
  `servedTopOfEntry`, `boxOfDefinition`, `footprintOf`) and
  `placementTransform`, moved from the plan library; the object a property
  or section is shown for (`PlanObject`, `DocumentPlanObject`), a read-only
  `TextDisplay`, `LengthProperty.range`, `PropertySpec.visible` and
  `PropertyField.visible`; the one-context section builder (`PlanSection`);
  words with parameters (`KitText`, `fillText`, `placeholdersOf`,
  `KitWords.text`, `KitWords.decimalSeparator`, the `text:` namespace in
  `validate`, `validateHostWords` and conformance's placeholder check) and
  `numberedNameIndex`; `ToolNotice`; `PlanKit.prepare` and `PlanBuild`;
  `PlanServices.liveTypeIdOf`; `KitProblemCode.settingsNeedObject` and
  `placeholderMismatch`; `package:jet_cad_2d_kit/testing.dart` with
  `FakePlanServices`.
```

     (Add `PlanWords` (R-P7) and the words on `PlanObject`, `fieldsOf` and `commitField` (R-P4) if Tasks 2-3 landed them so.)
  2. `packages/jet_cad_2d_plan/CHANGELOG.md`, under `## 0.8.0 (unreleased)`, appended:

```markdown
- Sub-project 3a: a kit tool's notice on the status line, put into words
  when read (`PlanController.toolNotice`, `textOf`); a plan built in code
  (`PlanController(build:)`, `newPlan(build:)`) and every kit's `prepare`
  run on a plan the library makes, never on one it loads or imports; the
  property panel's `TextDisplay` row, hidden fields and the object view;
  the words' decimal separator from the UI language; numbered names over
  the contract's `numberedNameIndex`; a grip refusal during a drag gives no
  move, and a grip drop goes through `execute`; a frozen object's live
  references locked; the symbol box family now the contract's.
```

  3. `packages/jet_cad_2d_kit_architecture/CHANGELOG.md`, Task 9's `## 0.1.0 (unreleased)` section, its body:

```markdown
The architecture kit for the jet_cad_2d plan library, moved from
`jet_cad_floor_plan` unchanged in behaviour.

- Six types: boxes, walls (joined, cut by their openings), openings
  (doors, windows, gaps), room separators, rooms (traced from walls and
  separators, tinted, named and measured) and dimensions (attached to wall
  faces or fixed); their grips, properties and section words.
- Eight tools: Box (B), Wall (W), Door (D), Window (N), Gap (G), Room (M),
  Separator (S), Dimension (I); the Room tool's "already a room" and the
  Dimension tool's value as status-line notices.
- The furniture library (41 symbols, six size families, the wall-attached
  ones marked `attachTo: ['wall-face']`) and the wall-face attachment
  provider.
- `buildSampleFlat`, a sample flat for a host's `PlanController(build:)`.
- Words in English, German and Turkish.
```

     (Check the counts against the code: `grep -c "CatalogSymbol(" packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_catalog.dart`; write the number the code has.)
  - `cd packages/jet_cad_2d_kit && dart pub publish --dry-run`, the same for the plan and the kit again: `Package has 0 warnings.` each (a CHANGELOG change can raise one).

- [ ] **Step 9: The amendment lines.** The spec's "Amendments to other specs" list, each checked by `grep` and quoted into the note:
  - Umbrella (A13's demos and A11's `apps/floor_planner` → `apps/architecture_demo` to sub-project 3b): `grep -n "architecture_demo" docs/superpowers/specs/2026-10-13-kit-architecture-design.md`. If no amendment line carries it, append to its `## Amendments` section (`:512`):

```markdown
- **2026-10-15, sub-project 3 split** (the human: *"3a kit, 3b demo"*;
  [2026-10-15-architecture-kit-design.md](2026-10-15-architecture-kit-design.md),
  decision 1): sub-project 3 is carried by two specs, 3a (the contract's
  amendments, `jet_cad_2d_kit_architecture` and `jet_cad_2d_integration`)
  and 3b (`apps/architecture_demo`). A13's "the demos" and A11's
  `apps/floor_planner` → `apps/architecture_demo` are 3b's for the
  architecture demo; `apps/restaurant_demo` stays sub-project 4's.
```

  - Contract spec (K4's `text:` namespace; the surface: the symbol box family and `placementTransform`, `numberedNameIndex`, `KitText`, `ToolNotice`, `PlanObject`, `TextDisplay`, `range`, `visible`, `PlanSection`, `PlanKit.prepare`, `liveTypeIdOf`, `KitWords.text` and `decimalSeparator`, `testing.dart`): `sed -n '/## Amendments from sub-project 3a/,/^## /p' docs/superpowers/specs/2026-10-13-kit-contract-design.md` shows each (Tasks 1-6).
  - 2a spec (P3's property specs and section builder; P2's notice and status line; P4's new plan and `prepare`, the grips row, the lock set; the controller's `build`): `sed -n '/^## Amendments/,$p' docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md` shows each (Tasks 2, 4, 5, 7).
  - 2b spec: none expected; `git diff main -- docs/superpowers/specs/2026-10-14-plan-library-service-mode-design.md` prints what a C1 task added, if any.
  - A line missing from the contract or 2a spec is a finding for its C1 task (its fix round writes it); only the umbrella's is this task's.

- [ ] **Step 10: The ported tests and the mutations.** From the task reports only:
  - Every source file a task ported, its destination(s) (kit or integration, per R-P1), the count of tests the report named, and "assertions unchanged" or each ruling that changed or left a line (its id). Check that each destination carries its port comment: `grep -rln "Ported from jet_cad_floor_plan/test/<source>\|Ported to jet_cad_2d_kit_architecture\|Ported for jet_cad_2d_integration" packages/jet_cad_2d_kit_architecture/test packages/jet_cad_2d_integration/test`.
  - Every mutation each report recorded: id, task, file, edit, the test that went red; a named mutation that stayed green is listed with its resolution.
  - The source files of the six types (spec A.2's list, 54 files: box 2, wall 7, opening 13, separator 2, room 16, dimension 14) each with its destination(s); `ls packages/jet_cad_floor_plan/test/*_test.dart` filtered to `box_`, `wall_`, `opening_`, `separator`, `room_`, `dimension_`, `planner_box`: a file with neither a destination nor a ruling is a finding.

- [ ] **Step 11: The results of record.** Create `docs/superpowers/notes/2026-10-15-architecture-kit-results.md` from this template; every `<…>` from this run or from a task report, a section whose command was not run says so and why:

````markdown
# The architecture kit (sub-project 3a): results of record

Branch `feat/architecture-kit`, head at the exit gate: `<git rev-parse HEAD>`
(the commit that adds this note sits on top of it); `<n>` commits over `main`
(local `main` at `<sha>`, an ancestor of the head; `origin/main` at `<sha>`).
Plan: `docs/superpowers/plans/2026-10-15-architecture-kit.md`. Spec:
`docs/superpowers/specs/2026-10-15-architecture-kit-design.md` (revision 2).
Transcripts copied from the terminal on `<date>`, last lines only.

Two kinds of evidence, each named: **this run** (a command run by Task 29 on
the head above, its output quoted) and **report** (what a task report in
`.superpowers/sdd/2026-10-15-architecture-kit/` recorded, not re-run here).

## Gates

### `packages/jet_cad_2d_kit`, `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture`, `jet_cad_2d_integration`

Per package: `flutter test` (exit, last line), `flutter analyze`, format.
The invariants: `<plan's test/invariants lines>`; IA-alloc: `<line>`.

### Tools

`dart test`: `<line>`. `dart analyze --fatal-infos …`: `<line>`.
`check_kit_deps`: `<line>`. `check_guide`, `check_readmes`, `check_screenshots`: `<lines>`.

### CLAUDE.md's gates

`jet_cad_2d`: `<last line and the failing list>`; against `standing_failures.txt`: `<exactly its lines / the difference>`.
`jet_cad_2d_flutter`: likewise. `jet_cad_2d_gpu`: `<lines>`.
`query_allocation_test`: `<line>`. The Flutter layer's `paint_allocation_test`: `<line>`.
The old line, once: `jet_cad_floor_plan`, `jet_cad_restaurant_symbols`, `apps/floor_planner`: `<lines>`.

### Dry runs

`jet_cad_2d_kit`, `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture`: `<exit, warning line each>`; the kit's file list `<as printed>`; `cmp LICENSE`: `<nothing>`.

### Hand checks

`<each Step 6 command and its output>`

## Appendix A, closed

| Row | Owner | State | Evidence |
|---|---|---|---|
| `<D-01 … D-50, A.2's rows, A.3>` | `<task>` | `<ported / ruled / carried>` | `<file and test names / ruling id / sub-project>` |

### Carried to sub-project 3b
`<by name>`

### Carried to sub-project 4
`<by name, A.2's parity rows included>`

### Lines dropped, the human's word
`<each line, its ruling, the human's answer or "pending">`

## D-48: the closed lists, each through the kit's hooks

`<Task 26 Step 12's table, each test found>`

## Ported tests (A12)

| Source (`jet_cad_floor_plan/test/…`, `apps/floor_planner/test/…`) | Destination(s) | Tests | Assertions |
|---|---|---|---|
| `<…>` | `<…>` | `<n>` | `<unchanged / rulings …>` |

## Mutations of Tasks 1-28

| ID | Task | File | The change | Red test |
|---|---|---|---|---|

## Planning rulings and plan decisions

R-P1 to R-P12 (`task-scopes.md`), each task's rulings (IT-R…, IP-R…, IA-R…, and the other tasks'), one line each, in task order, from the plan.

## Amendment lines

`<the umbrella's, the contract spec's, the 2a spec's; each quoted with its line number>`

## Spec gaps and interface problems found while executing

Each `#### Interface problem` of the plan's task bodies and each finding a
task report raised, with its resolution (amendment, ruling, or carried).
````

- [ ] **Step 12: STATUS.** In `STATUS.md`:
  - "In flight", the kit architecture's entry (`:390` on), after its 2b sentences, a paragraph:

```markdown
**3a, the architecture kit** (`jet_cad_2d_kit_architecture` 0.1.0 and the
unpublished `jet_cad_2d_integration`; the contract's 3a amendments): spec
[2026-10-15-architecture-kit-design.md](docs/superpowers/specs/2026-10-15-architecture-kit-design.md)
(rev 2, approved), plan
[2026-10-15-architecture-kit.md](docs/superpowers/plans/2026-10-15-architecture-kit.md)
(29 tasks), results
[2026-10-15-architecture-kit-results.md](docs/superpowers/notes/2026-10-15-architecture-kit-results.md),
on `feat/architecture-kit` (worktree `.claude/worktrees/architecture-kit`).
Every task done and reviewed, the exit gate passed at `<head sha>`; the
whole-branch review, its fix wave and the ledger's archive are next. Not
merged, not pushed. 3b (`apps/architecture_demo`) follows from its own
spec; the human is told when the demo runs on the new packages.
```

  - "Resume here", the first paragraph's "Next: sub-project 3 (the architecture kit)." → "**3a (the architecture kit) passed its exit gate on `feat/architecture-kit` at `<head sha>`; next: the whole-branch Opus review and its fix wave, then the ledger archived and the merge on the human's word; then 3b's brainstorm.**" and, when Step 7 left any line "pending", one sentence naming them: "Owed to the human: the dropped lines listed in the results note's 'Lines dropped, the human's word'."
  - "Last updated" at the top: this run's date. No other line changes.

- [ ] **Step 13: Commit.**

```bash
git add docs/superpowers/notes/2026-10-15-architecture-kit-results.md STATUS.md packages/jet_cad_2d_kit/CHANGELOG.md packages/jet_cad_2d_plan/CHANGELOG.md packages/jet_cad_2d_kit_architecture/CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs: the architecture kit (3a), results of record

The exit gate's transcripts, Appendix A closed row by row, the closed
lists through the kit's hooks, the ported tests, the mutations and the
rulings of sub-project 3a, for the whole-branch review; the CHANGELOGs'
3a additions; STATUS says 3a passed its gate and the review is next.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

  (If Step 9 appended the umbrella's line, add `docs/superpowers/specs/2026-10-13-kit-architecture-design.md` to the `git add` line, and only it.)

- [ ] **Step 14: Hand over.** The Opus review of the whole branch, its fix wave and the ledger archived onto the branch as its last commit are the coordinator's. Nothing is pushed, tagged, merged or published from this task.

There is no Mutation step: this task changes no code.


## Appendix A coverage

Every row of the spec's Appendix A, with the task that closes it. Task 29's results note repeats this table with the destination of each ported file.

| Row | Task(s) |
|---|---|
| D-01 | 24 (`wall_faces_test`, kit); 28 (`wall_attach_test`, `wall_attach_property_test` in the kit over `place_entry.dart`, R-P1; `symbol_move_test` integration) |
| D-02, D-03, D-04, D-05 | 28 |
| D-06, D-07, D-08 | 24 |
| D-09, D-10 | 1 |
| D-11, D-15 (PA2, PA3), D-47 | 23 (and 9's conformance test) |
| D-12, D-13, D-14 | 28 |
| D-16 | sub-project 4 |
| D-17 | SE8: 8; SE10, SE10b, SE11 and the furniture seating group dropped (spec decision 7) |
| D-18 | 9 |
| D-19 | 10 (box), 11-12 (wall), 13-15 (opening), 16-17 (separator), 16, 18, 19 (room), 20-22 (dimension), 26 (their sample-flat cases, R-P5, R-P10) |
| D-20, D-21, D-24, D-32, D-39, D-46 | 27 |
| D-22, D-23, D-26, D-29, D-33, D-48 | 26 |
| D-25 | 3, 9 |
| D-27 | 4, 19, 22 |
| D-28 | 5 (the generic lines), 9 (SC-prepare), 17 (the DASHED lines, ND4) |
| D-30 | 17 |
| D-31 | 18 |
| D-34 | 25 (`startup_plan_test`), 26 (`intersection_snap_test`) |
| D-35, D-36, D-37, D-38 | 28 (the room lines, R-P18) |
| D-40 | 6 (recorded as not added, spec C1.5) |
| D-41 | 2 |
| D-42, D-50 | sub-project 4 |
| D-43 | 7 |
| D-44, D-45 | 8 |
| D-49 | 3b |
| A.2 `planner_grips_test` A1-A4, `editor_panels_test`'s and `keyboard_focus_test`'s architecture remainders | 26 |
| A.2 rows carried to sub-project 4 | 29 lists them in the results note |
| A.3 WE1, SS16, SS17, the layer picker's wall case | 28 (WE1, SS16, SS17), 26 (the layer picker) |


## Gates

Every task ends with its own gates (Global Constraints). Task 29 runs them all on the final tree and records the output in the results note:

- `packages/jet_cad_2d`: `dart test && dart analyze && dart format --output=none --set-exit-if-changed .` (only `tool/ci/standing_failures.txt`'s lines fail).
- `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d_kit`, `packages/jet_cad_2d_kit_architecture`: `flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`.
- `packages/jet_cad_2d_plan`, `packages/jet_cad_2d_integration`: the same with `flutter test --enable-vmservice`.
- `tool/ci`: `dart test`; from the root `dart run tool/ci/check_kit_deps.dart`.
- `dart pub publish --dry-run` in `jet_cad_2d_kit`, `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture`: 0 warnings.

## Appendix: rulings made while planning (2026-10-15)

Nine writers drafted the tasks in parallel; one reconcile pass and five pre-flight passes checked them against the code and each other (scratch logs, not committed). The rulings below bind the tasks.

### The controller's rulings (R-P1 to R-P19)

- **R-P1 (public libraries only).** `jet_cad_2d_integration` imports only public libraries (`implementation_imports`). So C7's rule reads: a ported case runs **in the kit** when it uses kit internals, the contract, the engine or the Flutter layer — and a plan-library *internal* helper it needs (e.g. `placeSymbol`, `symbol_placer.dart:169`) is reproduced as a **test-local fixture in the kit** (`test/support/place_entry.dart`: `placeEntry(doc, entry, {at, quarterTurns, mirrored, transform})`, `copyOfEntry`; a fixture change, A12). A case runs **in the integration package** only when it needs the plan library's public widgets or controller (`PlanCanvas`, `PlanEditor`, `PlanPropertyPanel`, `PlanController`, the public tools) and no kit internal. A case needing both a plan widget and a kit internal is rewritten to reach the kit internal through public behaviour (a ruling in the task) or split.
- **R-P2.** `furnitureSource` joins `architectureKit.symbols` in Task 24 with the provider (else `attachmentKindUnoffered` fires).
- **R-P3.** Kit test support shared across tasks: `test/support/place_entry.dart` (Task 23 creates it), `test/support/wall_attach_fixture.dart` (Task 24). Kit-internal readers with today's signatures plus a `LiveTypeOf` parameter: `faceRunsOf(doc, wall, LiveTypeOf live, {accept})`, `WallFaces(bands, live, {accept})`.
- **R-P4.** `PlanObject` gains `KitWords get words`; `DocumentPlanObject(document, handle, words)`; `PlanType.fieldsOf(document, group, words)` and `commitField(document, group, field, input, words)`. (Writer 7: `TextDisplay.read` needs the decimal separator and `text:` words.)
- **R-P5.** Dimension cases on the sample flat (`dimension_paint_test` RR1-RR3, `dimension_shell_test` SL1, SL2, TL9) are Task 26's.
- **R-P6.** The kit's test catalog: `test/support/wall_fixture.dart` (Task 11) gives `testCatalog()` and `installParametric(doc)` registering the kit's raw types in today's order; each type task appends its line. `wallsInDocument` (Task 13) gains `{required LiveTypeOf live}`. The kit pubspec lists `vector_math`; the integration pubspec lists `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `vector_math` directly (Task 9).
- **R-P7.** A pure `PlanWords` (contract model: `word`, `maybe`, `text`, `decimalSeparator`); `KitWords implements PlanWords` adds `locale`. `PlanObject.words` is a `PlanWords`, so `properties.dart` stays pure (2a's P9 unchanged).
- **R-P8 (the wall/opening/room split).** Today's `wall.dart`/`wall_grips.dart` use `opening_geometry.dart` and `room_inputs.dart`. Split: Task 11's `WallType.generate` has **no opening cut** and **no place hooks** (`contributesPlace`/`placeBox`/`placeInput`); `wallsInView` and `wallsInDocument(doc, host, LiveTypeOf live, {moved})` live in `wall_geometry.dart` (Task 11). Task 12's `WallGrips({required LiveTypeOf live})` has no 08 D13 `_keptPut`/`_seated`. Task 13 adds the wall's cut; Task 14 adds `_keptPut` and `_seated`; Task 16 adds the wall's place hooks. Wall tests whose cases need openings or rooms move to the task that adds the code they need (say so in both tasks).
- **R-P9.** Integration test files that read `@internal` members of the plan library's public classes (`selection`, `grips`, `toolContext`, `servicesOf`, `toolFor`, `frozen`, `fill`) start with `// ignore_for_file: invalid_use_of_internal_member` (precedent: `apps/restaurant_demo/test`). A Global Constraint.
- **R-P10.** Sample-flat cases are Task 26's in the integration package over `sampleFlatController()`: besides R-P5, `room_cost_test` LZ3 and `room_paint_test`'s six cases.
- **R-P11.** The kit's pubspec lists `meta` and `vector_math` besides the Global Constraints' list.
- **R-P12.** `FakePlanServices.settingsOf` reads the map it was given at each call (no copy), so a test can change a tool's settings between events.
- **R-P13 (kit test catalog).** One file, `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart`, created by Task 10 with `ParametricCatalog testCatalog()` and `ParametricSystem installParametric(DraftDocument doc)`; each type task appends its registration in today's order (`jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39`). Domain fixtures (`wall_fixture.dart`, `room_fixture.dart`, `opening_fixture.dart`) import and re-export it; no other names (`architectureCatalog`, `installArchitecture`) are used.
- **R-P14 (integration test support).** One shared rig, `packages/jet_cad_2d_integration/test/support/editor_rig.dart` (Task 9/10: `pumpEditor`, `globalOf`, `status`, `press`, `activeTool`, `pagePlanJson`, `kitCatalog`, `liveOf`); domain support files (`opening_support.dart`, `room_plans.dart`, ...) import it and add only domain fixtures, never a second copy of a rig helper. The reconcile pass merges duplicates.
- **R-P15 (Review Focus 3, corrected to today's).** A grip drag at a refused point: the preview keeps the last accepted state, nothing is reported; a **drop at the refused point commits nothing** (today: `GripDrag.command` asks the provider at the drop point, `grip_drag.dart:303-313`; wall grips return null there, `wall_grips.dart:60-63, 198`); the grips stay usable. C1.8(2) is done through one private refusal rule shared by `execute` and `plan.select`'s `GuardedTool` (Task 7), since `ToolContext.execute` is the Flutter layer's.
- **R-P16.** 2b's renames (`SeatingComponent` → `UnitComponent(kind: table, capacity: n)`, table → unit) count as C7 class 1 (ids). Task 5 does not port ND2 (the plan library has no page-less set-up).
- **R-P17.** R-P15 corrected: at a refused point today's preview is empty (`wall_grips.dart:137-138`, `grip_drag.dart:262-263`), not the last accepted state. `wallsInDocument(doc, host, LiveTypeOf live, {moved})` takes `live` positionally (R-P6's named form struck). The kit test helper for a live reader is `liveOf(doc, {frozen})` in `wall_fixture.dart`; Task 16's `liveIn` is replaced by it.
- **R-P18.** R-16 (spec C6): the table halves of TF1/TF3/TF7, EX2/EX3/EX5 and CZ1 stay in the plan's 2b tests (they use plan internals); the integration package carries their room lines over public routes (Task 28). Spec C6's "full copies" is amended by this ruling.
- **R-P19.** R14-1 accepted: the opening's position range decides "is the host a wall" by the engine's naming rule over a catalog the kit builds lazily from its own raw type registrations (a kit-internal list in `lib/src/`, not from `architectureKit`, so no import cycle). EG8-k/EG9-k/EG10-k's test-local grip dispatch follows DM-R1/R14-7 (a fixture standing in for the plan's dispatch).

### The writers' rulings (confirmed by the controller; each is also in its task)

| id | task | one line |
|---|---|---|
| (unnamed) | 5 | ND2 not ported: its premise (`prepareDocument`, a page-less set-up) is absent in the plan library (A14 reason). |
| (unnamed) | 5 | ND4's generic half runs on two test-kit slabs: `hasLength(10)` walls → `hasLength(2)` slabs, `liveObjectsOf<WallParams>` → `objectsOf<SlabComponent>` (fixture premise follows the fixture). |
| (unnamed) | 6 | D-40: `PlanServices.isLocked`, `allows` and a settings listenable are not added (no user today). |
| (unnamed) | 7 | D-43: `_LockCheck._first`'s catch-all probe kept as it is; cost recorded (one probe of every live kit object per refused edit). |
| (unnamed) | 7 | C1.8(2) done through one private `_refusal` shared by `execute` and `plan.select`'s `GuardedTool` (SelectTool executes through `ToolContext`, untouchable). |
| (unnamed) | 8 | SE8's seating is 2b's unit (`SeatingComponent(seats: 3)` → `UnitComponent(kind: table, capacity: 3)`, key `test.table` → `test.table.plain`), value unchanged. |
| (unnamed) | 9 | D-18 (old `example_test`) not ported, replaced by SC-example over the kit's descriptor. |
| (unnamed) | 10 | BX1-BX6 run with grid snap on (a turned camera does not give back exact corners); fixture change. |
| R11-1 | 11 | WR9's sample-plan line (`wall_regen_test.dart:497-501`) carried to Task 25 (now its Step 2b). |
| R12-1 | 12 | The Wall tool's settings are set through the panel's `setting-*` fields instead of the tool's notifier. |
| R12-2 | 12 | WT3/WT9's `classify` lines (kit geometry) leave the shell cases and run in the kit as WT3-k, WT9-k. |
| R12-3 | 12 | EG1/EG3/EG4/EG6's provider-direct tails run in the kit (EG1-k …); the shell parts in integration. |
| R13-1 | 13 | The opening's document adapters take a `LiveTypeOf`; a live wall is `live(h) == ArchitectureTypes.wall`. |
| R13-2 | 13 | Every case ported in Task 13 runs in the kit. |
| R13-3 | 13 | KJ3 (→ Task 15), KJ4, KJ5, OR8 (→ Task 14) need the opening's type or tools: ported there. |
| R13-4 | 13 | The wall's cut by its openings is added back to `WallType.generate` here (Task 11 left it out). |
| R13-5 | 13 | The kit's tests regenerate through the test catalog, not today's global one. |
| R14-1 | 14 | "Is the host a wall" for the position range asks a kit-local catalog over `architectureKit.types` (see Unresolved 2). |
| R14-2 | 14 | `L` is the host's centreline length in its own group space, not world. |
| R14-3 | 14 | The Opening section's four fields, their gates and the title by kind. |
| R14-4 | 14 | The opening's grips over the services (edge aperture from `objectSnap` and the camera). |
| R14-5 | 14 | 08 D13's "openings stay put" (`_keptPut`, `_seated`) lands in `WallGrips` here. |
| R14-6 | 14 | C7 placement of the opening type's cases (kit vs C6). |
| R14-7 | 14 | SG6's composite dispatcher becomes a test-local `_Dispatch`. |
| R14-8 | 14 | C6 files reading `@internal` controller members start with the ignore line (= R-P9). |
| R14-9 | 14 | The opening oracles are copied into the integration support; KJ4 reads the oracle's span end instead of `hostFrameInDocument(...).uE`. |
| R14-10 | 14 | Finder keys renamed (C7 class 3). |
| R15-1 | 15 | `OpeningTool(kind, services)` reads its width from the services per event. |
| R15-2 | 15 | OT1 (shell)'s preview line moves to the kit as "OT1 (preview)". |
| R15-3 | 15 | OS3's settings width is read through `settingsText` (`OpeningSettings.toString`). |
| R15-4 | 15 | Palette and settings keys renamed (C7 class 3). |
| R15-5 | 15 | C7 placement of `opening_tool_test`. |
| R17-1 | 17 | ST1's shell half reads `isPending` as the guard's `isMidShape`. |
| R17-2 | 17 | ND4's live case runs on a built plan of the sample's shape (ten turned walls, page off origin), not the sample's bytes. |
| (unnamed) | 18 | GR4's trace area is read from the drawn tint instead of a second trace (R-P1). |
| DM-R1 | 21 | GE1's line `ObjectGrips(edgeAperture: () => null).gripsOf(doc, dim2)` isEmpty not ported (premise impossible). |
| DM-R2 | 21 | PN1/PN2's `bruteCandidates` premises dropped from the integration copy (kit internals). |
| DM-R3 | 21 | The kind is a dropdown, not a segmented button (C7 class 3); keys renamed. |
| DT-R1 | 22 | TL4 and TL5's status-line case split: public lines in integration, tool-state lines in the kit (TL4k, TL5k). |
| DT-R2 | 22 | `isA<DimensionTool>()` on the active tool → `c.activeTool.value == ArchitectureTools.dimension`. |
| DT-R3 | 22 | TL5's canvas-width premise `== 896` → `greaterThan(4690 * 0.12)`. |
| DT-R4 | 22 | Kit lines reading the notice's string read `debugValue`; DT-notice pins the `KitText`. |
| (unnamed) | 23 | Every furniture entry asserted at version 1 (C7 class 1 rewrite of the version line). |
| IT-R1 | 26 | C6 public only: shell internals read through public roads (InteractionLayer tools, grips). |
| IT-R2 | 26 | Tables stay tables: 2b's unit editor fixture on the sample flat. |
| IT-R3 | 26 | `planner_grips_test` ported over its own two-line fixture (the source, not the spec's wording). |
| IT-R4 | 26 | `planner_shell_test` cases run at 1440 x 900. |
| IT-R5 | 26 | TD1's camera set on the plan's middle at 0.05 px/mm. |
| IT-R6 | 26 | A choice is a dropdown (C7 class 3). |
| IT-R7 | 26 | One finder for a field in either scope (`property-`/`setting-`). |
| IT-R8 | 26 | T5-f's sofa placed by arming and clicking, not `placeSymbol`. |
| IT-R9 | 26 | A12b's palette map regains the eight architecture rows. |
| IT-R10 | 26 | `tools_layer_test`'s placer case places through `plan.symbol`. |
| IT-R11 | 26 | P-1 keeps the data and the newer release's payload. |
| IT-R12 | 26 | `dimension_shell_test`'s shell reads mapped to public roads (grips cache, active tool, an own `SpatialIndex`). |
| IT-R13 | 26 | SL1's oracle lines over kit internals not ported (see dropped lines). |
| IT-R14 | 26 | SR3 opens the stripped file through the plan library; diagnostics from a fresh engine system. |
| IT-R15 | 26 | LZ3 runs in the kit over `buildSampleFlat` (R-P1 over R-P10's "over sampleFlatController"). |
| IP-R1 | 27 | Keys and choices renamed (C7 classes 1 and 3). |
| IP-R2 | 27 | WS3/WS10's `WallTool.settings` reads not ported (covered by the field and the next wall). |
| IP-R3 | 27 | The Dimension notice through `c.textOf(c.toolNotice.value!)`; two tool-state premises not ported. |
| IP-R4 | 27 | DT1/LK2's library table is the fixture kit's (the architecture kit's tables are plain). |
| IP-R5 | 27 | LK2's leak allowlist extended to the kit's Turkish words and filled `text:` templates. |
| IP-R6 | 27 | PW1 opens the dropdown to find the other two justification words. |
| IP-R7 | 27 | CP3's `recolorCommand` lines not ported (the swatch taps make the same claims). |
| IP-R8 | 27 | WS9's malformed file loaded as a plan file; a lock instead of a refusal is a finding. |
| IA-R1 | 28 | The provider's answer through the contract is the oracle instead of `attachToWall` over `faceRunsOf`. |
| IA-R2 | 28 | MV1-MV3, MV5, MV6 dragged through `plan.select` on the canvas. |
| IA-R3 | 28 | Human: MV1's marker line and MV3's "library not ready" clause not ported. |
| IA-R4 | 28 | D-02 through `plan.symbol`; human: ghost repaint count, marker glyph paint calls, `tool.faces` lines not ported. |
| IA-R5 | 28 | View internals mapped to public roads; human: WE1's hover ghost. |
| IA-R6 | 28 | R-16's room lines run whole in integration over public roads; the table halves stay 2b's (R-P18). |
| (reconcile) | 17, 21 | EG8-k/EG9-k/EG10-k: today's `ObjectGrips` dispatcher → the naming type's `gripsFor(FakePlanServices(...))` (DM-R1's mapping, two more cases); `object.separators!` → `SeparatorGrips(...)`. |
| (reconcile) | 25 | WR9's sample line builds the sample as Task 25's `sampleFlat` does (kit catalog, `prepare`, `buildSampleFlat`), assertion unchanged (R11-1's fixture change). |
| (reconcile) | 19, 20 | TT10 (and M-RT-7, M-RT-10) moved from Task 19 to Task 20. |

### Ported assertion lines dropped or with a changed instrument (the human's word, A14)

**Decided** (2026-10-15): the human left these to the controller (*"kararları sana bırakıyorum. hemen başla."*); the controller accepts every row below with its stated reason. A further line an implementer cannot keep is a finding to report, not covered by this decision.

Not C7 classes 1-3 (ids, tags to fields, widget form). Each: task, test id, the line, the reason.

1. **Task 5, ND2** (whole case, `jet_cad_floor_plan/test/new_document_test.dart`): not ported; premise (`prepareDocument`, no page) absent in the plan library.
2. **Task 5, ND4** "with the page's/catalog's registration alone": `hasLength(10)` (walls) → `hasLength(2)` (slabs) and `liveObjectsOf<WallParams>` → `objectsOf<SlabComponent>`: the count line rewritten with the generic fixture.
3. **Task 9, D-18** `example_test` (1 case): not ported, replaced by SC-example (the kit may not import the planner widget).
4. **Task 14, KJ4**: `hostFrameInDocument(doc, hA)!.uE` → `OpeningOracle(c.document).span(hA).$2` (R14-9): the instrument changes (oracle instead of the kit's frame); value and tolerance unchanged.
5. **Task 15, OS3 / OT1**: `expect(door.settings.value.width, want)` → `expect(settingsText(c, …), 'OpeningSettings($want)')` (R15-3): read through `toString`.
6. **Task 18, GR4 (shell)**: `(faceAt(doc, …) as Traced).area` → the area of the room's drawn tint (Interface problem 3): instrument change, value unchanged.
7. **Task 21, GE1** (DM-R1): `expect(ObjectGrips(edgeAperture: () => null).gripsOf(doc, dim2), isEmpty)` (`dimension_grips_test.dart:139`) not ported (premise impossible).
8. **Task 21, PN1, PN2** (DM-R2): the `bruteCandidates` premises (`dimension_panel_test.dart:126-128`, `:201-203`) dropped from the integration copy (kit internals).
9. **Task 22, TL5 status-line case** (DT-R3): `expect(tester.getSize(find.byType(InteractionLayer)).width, 896)` (`:1371`) → `greaterThan(4690 * 0.12)` (weakened to the premise it stood for).
10. **Task 23, furniture_library_test**: the pre-09c group (4) and "the 14 new symbols … == 27" not ported (umbrella decision 9); the seating group's two seat-count tests dropped (decision 7). Already decided by the spec; listed for the record.
11. **Task 8, seating_test SE10, SE10b, SE11**: dropped on the human's word (decision 7); listed for the record.
12. **Task 26, SL1** (IT-R13): `:345-349` (the attached end E1/1/left through the oracle), `:359`, `:427` (`oracleFailures`) not ported (kit internals).
13. **Task 27, WS3, WS10** (IP-R2): `(view.tools.active as WallTool).settings.value.thickness` (`selection_panel_test.dart:383-384`, `:776`) not ported.
14. **Task 27, decimal_separator noticeCases** (IP-R3): `tool.points` hasLength 2 (`:187`) and `tool.hoverKind` isNull (`:189`) not ported.
15. **Task 27, CP3** (IP-R7): the `recolorCommand` lines (`color_picker_test.dart:497-507`) not ported.
16. **Task 28, MV1, MV3** (IA-R3, human): MV1's marker line (`symbol_move_test.dart:167`), MV3's "before the library is ready" (`:191-195`).
17. **Task 28, D-02 group** (IA-R4, human): the ghost's repaint count (`rig.notifications`), the marker glyph's paint calls ("the marker is the nearest glyph"), `rig.tool.faces` null; and "a tool given no wall faces never attaches" (`:1496-1506`, premise impossible).
18. **Task 28, WE1** (IA-R5, human): the hover ghost (`bedAt.hovered`). **WE2** not ported (premise impossible under decision 9).
19. **Task 26, SR3** (IT-R14) and **Task 25, SP5/SP9** (systems): diagnostics/drift read from a fresh engine system or the installed one instead of today's hand-made system; values unchanged (instrument change).

### Cases moved between tasks

| case | from → to | in the receiving task |
|---|---|---|
| WR9's sample line | 11 → 25 | **was missing**; added (Task 25 Step 2b) |
| EG7, EG8 | 12 → 17 | **was missing**; added (Task 17 Step 7b) |
| EG9, EG10 | 12 → 21 | **was missing**; added (Task 21 Step 10b) |
| ST4 | 17 → 18 | **was missing**; added (Task 18 Step 3b) |
| TT10 (+ M-RT-7, M-RT-10) | 19 → 20 | moved by this reconcile (order); Task 20 Step 9b |
| KJ4, KJ5, OR8 / KJ3 | 13 → 14 / 15 | present |
| OS1 (runtime), OS3 | 14 → 15 | present |
| `_keptPut`, `_seated`, `opening_end_drag_test` | 12 → 14 | present |
| the wall's cut / place hooks | 11 → 13 / 16 | present |
| DE2, DE3, RK1, RK2 | 16 → 18 | present |
| GR5 | 17 → 18 | present |
| LZ3 | 16 → 26 (R-P10; notes said 25) | present (Task 26 Step 8 item 5) |
| room_paint (6) | 18 → 26 (R-P10) | present (Task 26 Step 9 item 12) |
| dimension_paint (3), dimension_shell (3) | 21, 22 → 26 (R-P5; notes said 25) | present (Task 26 Step 9 items 10, 11) |
| ND1/ND3 DASHED lines, ND4 live case | 5 → 17 | present |
| wall_attach (23), wall_attach_property (2), D-13 (3) | 23, 24 → 28 | present |
| SC-conformance over the real catalog | 9 → 23 | present |

**Orphans after the reconcile: none.**
