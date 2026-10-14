### Task 21: The exit gate

**Files:**
- Create: `docs/superpowers/notes/2026-10-14-plan-library-2a-results.md` (the results of record; the template is Step 8).
- No code changes. A failure here goes back to the task that owns the code: its fix is a commit of that task's kind (`fix(plan): …`, `fix(kit): …`, `fix(engine): …`), made and reviewed as that task's fix round, never inside this task.

**Interfaces:**
- Consumes: everything of Tasks 1-20; the per-task reports in `.superpowers/sdd/2026-10-14-plan-library-2a/` (each mutation's ID, file, edit and the test that went red, as recorded there).
- Produces: the evidence the whole-branch review reads (spec "Exit gate").

Plan decision: the results note carries **only** what a command printed in this task's run (quoted, last lines) or what a task report recorded (named as such). A count that no command printed is never written; a gate that was not run is written as "not run" with the reason. This is CLAUDE.md's "never synthesize test output" applied to the note.

- [ ] **Step 1: A clean tree and the one committed `analysis_options.yaml`.**
  - Run from the worktree root: `git status --short`. Expected: no output. (A rewritten `analysis_options.yaml` from a pub operation shows here as ` M …`; restore it with `git checkout -- <that file>` — it is a pub artefact, not work — and run the command again.)
  - Run: `git log --name-only --format= main..HEAD | grep analysis_options`. Expected: exactly one line, `packages/jet_cad_2d_plan/analysis_options.yaml` (Task 6's single allowed commit).
  - Run: `git log --format='%H %s' main..HEAD | wc -l` and `git rev-parse HEAD`. Record both in the note (Step 8, "Branch").

- [ ] **Step 2: The two contract and plan packages** (spec exit gate, "for `jet_cad_2d_kit` and `jet_cad_2d_plan`").
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_plan && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - Expected shape, each package: `flutter test` ends with a line `NN:NN +<count>: All tests passed!` (and, for `jet_cad_2d_plan`, `~<skipped>` only if a task recorded a skip with its reason); `flutter analyze` prints `No issues found!`; the format gate prints `Formatted <n> files (0 changed) …` and exits 0.
  - Quote each package's last `flutter test` line, the analyze line and the format line into the note.

- [ ] **Step 3: The tools gate.**
  - `cd tool/ci && dart test`. Expected: `All tests passed!` (this includes the CI-matrix checks Task 6 extended: every live package is in the CI matrix, `jet_cad_2d_plan` among them).
  - From the repository root: `dart run tool/ci/check_kit_deps.dart`. Expected shape: `kit dependencies: <n> package(s) checked, none names the plan library or another kit` (A1: `jet_cad_2d_kit` names neither `jet_cad_2d_plan` nor a kit, now that it depends on `jet_cad_2d_flutter`).
  - From the repository root, the two old checks CI runs beside it, unchanged by this branch: `dart run tool/ci/check_readmes.dart` (expected shape `package READMEs: all <n> code blocks are in the probes`) and `dart run tool/ci/check_screenshots.dart` (exit 0). They read only the old packages; they are run so the note shows nothing of this branch broke them.

- [ ] **Step 4: The three CLAUDE.md gates** (spec exit gate, "CLAUDE.md's gates").
  - `cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_gpu && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - Expected: `jet_cad_2d` and `jet_cad_2d_flutter` fail **exactly** the lines of `tool/ci/standing_failures.txt` for their package (the engine's two document fingerprints, the renderer's text-ladder goldens), and nothing else; every analyze prints `No issues found!`; every format gate exits 0. `jet_cad_2d_gpu` passes whole.
  - Compare each failing-test list with `tool/ci/standing_failures.txt` line by line and say so in the note. Any other failure is a finding: stop, report it to the coordinator with the test's name and output, and do not write the note as passed. In particular `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` must pass: Task 11's guarding adapter sits in the catalog on the hot path (spec Risks).
  - Also run `cd packages/jet_cad_floor_plan && flutter test` once (expected: its own standing state as on `main`; this branch changes nothing there, A12) and record its last line; it proves E1-E4 left the old planner's suite as it was.

- [ ] **Step 5: The publish dry runs** (spec exit gate, "a publishable dry-run entry with 0 warnings"). **Never** run `dart pub publish` without `--dry-run`.
  - `cd packages/jet_cad_2d_kit && dart pub publish --dry-run`
  - `cd packages/jet_cad_2d_plan && dart pub publish --dry-run`
  - Expected, each: exit 0 and the line `Package has 0 warnings.` A dependent's dry run does not need its dependency on pub.dev (the `publishable` job's comment in `.github/workflows/ci.yml`, spec F-2 of the publishing plan), so `jet_cad_2d_kit: ^0.1.0` unpublished is no warning.
  - For `jet_cad_2d_plan`, the file list printed must hold `LICENSE`, `README.md`, `CHANGELOG.md`, `example/main.dart`, `lib/jet_cad_2d_plan.dart`, the font asset `lib/fonts/Roboto-Regular.ttf` and its licence asset (Task 9 copied them; Task 19's PDF export embeds the font), and `pubspec.yaml`. Then from the root: `cmp LICENSE packages/jet_cad_2d_plan/LICENSE` and `cmp LICENSE packages/jet_cad_2d_kit/LICENSE`. Expected: both print nothing.
  - A warning is a finding for the task that owns the file it names (a missing CHANGELOG entry: Task 20; a pubspec field: Task 6). Never change a dependency constraint to silence one: the floors stay `^0.7.2` (Global Constraints, plan decision).

- [ ] **Step 6: The constraints, checked by hand.** Each command from the repository root; quote its output (or "printed nothing") into the note.
  - **The old packages are untouched** (A12, Global Constraints): `git diff --stat main -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu packages/jet_cad_2d_flutter apps` prints nothing.
  - **The engine changed only in Tasks 1 and 2:** `git log --format='%h %s' main..HEAD -- packages/jet_cad_2d` lists only Task 1's and Task 2's commits (and their fix rounds, named as such in the ledger).
  - **No import of the old planner or the restaurant symbols:** `grep -rn "jet_cad_floor_plan\|jet_cad_restaurant_symbols" packages/jet_cad_2d_plan/lib packages/jet_cad_2d_plan/test packages/jet_cad_2d_plan/example packages/jet_cad_2d_plan/pubspec.yaml packages/jet_cad_2d_kit/lib packages/jet_cad_2d_kit/pubspec.yaml` prints only comment lines that cite a ported source (`// Ported from jet_cad_floor_plan/…`); no `import` and no pubspec line. Run `grep -rn "import 'package:jet_cad_floor_plan\|import 'package:jet_cad_restaurant_symbols" packages/jet_cad_2d_plan packages/jet_cad_2d_kit` too: it prints nothing.
  - **The contract never depends on the plan library or a kit (A1):** `grep -n "jet_cad_2d_plan\|jet_cad_2d_kit_" packages/jet_cad_2d_kit/pubspec.yaml` prints nothing.
  - **`authoring.dart` stays pure Dart:** `grep -rln "package:flutter\|dart:ui" packages/jet_cad_2d_kit/lib/src/model packages/jet_cad_2d_kit/lib/src/authoring packages/jet_cad_2d_kit/lib/authoring.dart` prints nothing (the kit's purity test P1 is the binding check; this is the reviewer's quick look). Also `grep -ln "package:flutter\|dart:ui" packages/jet_cad_2d_kit/lib/src/kit/properties.dart packages/jet_cad_2d_kit/lib/src/kit/colour.dart` prints nothing (Task 3's rule).
  - **No `dart:io` in either library:** `grep -rn "import 'dart:io'" packages/jet_cad_2d_plan/lib packages/jet_cad_2d_kit/lib` prints nothing.
  - **The engine and the Flutter layer kept their versions:** `grep -n "^version:" packages/jet_cad_2d/pubspec.yaml packages/jet_cad_2d_flutter/pubspec.yaml packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml` prints `0.7.2`, `0.7.2`, `0.1.0`, `0.8.0`; `grep -n "## Unreleased" packages/jet_cad_2d/CHANGELOG.md` prints one line (E1-E4 named under it). `packages/jet_cad_2d_flutter/CHANGELOG.md` is not touched by this branch (the Flutter layer does not change).
  - **Draw order and the frame path:** `packages/jet_cad_2d_plan/test/invariants/` holds Task 15's paint-allocation test, and Step 2's run passed it; `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` passed in Step 4.
  - **The sample kit still regenerates to its bytes** (Task 5 touched `retired` and rule 11): `cd packages/jet_cad_2d_kit && dart run test/fixtures/sample_kit/generate.dart`, then from the root `git diff --quiet -- packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample.jetlib packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample_snapshot.json` exits 0 (K7.1 byte equality: `retired` is written only when true).
  - `git status --short` prints nothing after all of the above.

- [ ] **Step 7: The spec coverage table.** Build it from the task reports and the plan's task bodies, never from memory: for each spec section, the task(s) that implement it and the test ids that pin it. Every row must name at least one test id that exists in the tree: check each id with `grep -rn "<id>" packages/jet_cad_2d packages/jet_cad_2d_kit packages/jet_cad_2d_plan tool/ci` (a test's name starts with its id) and write `missing` in the row when the grep finds nothing. A `missing` row is a finding for the task that owns it, reported before the note is committed.

- [ ] **Step 8: The results of record.** Create `docs/superpowers/notes/2026-10-14-plan-library-2a-results.md` from this template. Every `<…>` is filled from this task's run or from a task report; a section whose command was not run says so and why.

````markdown
# The plan library in design mode (sub-project 2a): results of record

Branch `feat/plan-library-2a`, head at the exit gate: `<git rev-parse HEAD>`
(the commit that adds this note sits on top of it); `<n>` commits over `main`.
Plan: `docs/superpowers/plans/2026-10-14-plan-library-2a.md`. Spec:
`docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md` (revision 3).
All transcripts below were copied from the terminal on `<date>`, last lines only.

## Gates

### 1. `packages/jet_cad_2d_kit`

`flutter test`:

```
<last line as printed>
```

`flutter analyze`: `<line>`. `dart format --output=none --set-exit-if-changed .`: `<line>`.

### 2. `packages/jet_cad_2d_plan`

`flutter test`:

```
<last line as printed>
```

`flutter analyze`: `<line>`. Format: `<line>`.

### 3. Tools

`cd tool/ci && dart test`: `<last line>`.
`dart run tool/ci/check_kit_deps.dart`: `<line>`.
`dart run tool/ci/check_readmes.dart`: `<line>`. `dart run tool/ci/check_screenshots.dart`: `<exit status and line>`.

### 4. The three CLAUDE.md gates

`packages/jet_cad_2d` (`dart test`):

```
<last line and the "Failing tests:" list as printed>
```

Compared with `tool/ci/standing_failures.txt`: `<"exactly its jet_cad_2d lines" or the difference>`.
`dart analyze`: `<line>`. Format: `<line>`.

`packages/jet_cad_2d_flutter` (`flutter test`):

```
<last line and the "Failing tests:" list as printed>
```

Compared with `tool/ci/standing_failures.txt`: `<…>`. `flutter analyze`: `<line>`. Format: `<line>`.

`packages/jet_cad_2d_gpu`: `<test line>`, `<analyze line>`, `<format line>`.

`packages/jet_cad_floor_plan` (`flutter test`, untouched, run once): `<last line>`.

### 5. Publish dry runs

`packages/jet_cad_2d_kit`: exit `<code>`, `<"Package has 0 warnings." as printed>`.
`packages/jet_cad_2d_plan`: exit `<code>`, `<line>`; the file list holds `<the files Step 5 names, as printed>`.
`cmp LICENSE packages/jet_cad_2d_plan/LICENSE`, `cmp LICENSE packages/jet_cad_2d_kit/LICENSE`: `<printed nothing>`.

### 6. Hand checks

- `git status --short`: `<empty before and after every gate>`.
- `git log --name-only --format= main..HEAD | grep analysis_options`: `<the one line>`.
- `git diff --stat main -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu packages/jet_cad_2d_flutter apps`: `<printed nothing>`.
- Engine commits (`git log … -- packages/jet_cad_2d`): `<the list>`.
- Old-package imports, contract dependencies, purity, `dart:io`: `<each grep's output>`.
- Versions: `<the four version lines>`; `## Unreleased` in the engine's CHANGELOG: `<line>`.
- Sample kit regenerated, `git diff --quiet` on its two fixtures: `<exit 0>`.

## Spec coverage

| Spec section | Task(s) | Test ids |
|---|---|---|
| E1 `typeIds`, `typeIdOf` | 1 | `<E1-…>` |
| E2 frozen objects, `probe` | 2 | `<E2-…>` |
| E3 `PartialMutationError` | 1 | `<E3-…>` |
| E4 unreadable component kept raw | 1 | `<E4-…>` |
| P1 `PlanKit` growth, `PlanType`, `PlanTool`, `PlanServices`, `KitWords` | 4, 8 | `<PT-…>`, `<C-…>` |
| P1 lifetimes (factories once per document, `shared` disposed) | 8 | `<C-…>` |
| P1 reserved ids `plan`, `jetcad` | 6, 12 | `<KS-…>`, `<PM-…>` |
| P2 `PlanController` commands, listenables, events | 8 | `<C-…>` |
| P2 undo mid-shape, `deleteSelection` | 8, 12 | `<C-…>`, `<PM-…>` |
| P2 permissions and their enforcement points | 12, 16, 17, 18 | `<PM-…>`, `<KB-…>`, `<P-…>`, `<LP-…>` |
| P2 symbol libraries (loader, state, problems) | 13 | `<S-…>` |
| P2 widgets: `PlanCanvas` | 15 | `<CV-…>` |
| P2 widgets: `PlanToolPalette`, `PlanShortcuts`, the letters | 16 | `<KB-…>` |
| P2 widgets: `PlanSymbolGallery` | 13 | `<S-…>` |
| P2 widgets: `PlanPropertyPanel` | 17 | `<P-…>` |
| P2 widgets: `PlanLayerPanel`, `PlanPagePanel` | 18 | `<LP-…>` |
| P2 widgets: `PlanEditor`, `PlanEditorBar` | 20 | `<ED-…>` |
| P3 property specs, `PropertyField` | 3, 17 | `<PS-…>`, `<P-…>` |
| P3 colour targets | 3, 17 | `<PS-…>`, `<P-…>` |
| P3 attachment | 4, 14 | `<PT-…>`, `<AT-…>` |
| P4 the plan file, manifest, semver | 7 | `<PF-…>` |
| P4 the kit set | 6 | `<KS-…>` |
| P4 locks | 10 | `<L-…>` |
| P4 the failure boundary | 11 | `<F-…>` |
| P5 export and import registries, print | 19 | `<X-…>` |
| P5 words, locale, fonts | 9 | `<W-…>` |
| P5 theme | 9, 20 | `<W-…>`, `<ED-…>` |
| P6 R2 `retired` | 5, 13 | `<R2-…>`, `<S-…>` |
| P6 R3 conformance ids | 5 | `<R3-…>` |
| P6 R5 `docs/kits.md` | 5 | `<the doc-sync test's id>` |
| P6 R7 rule 11 width | 5 | `<R7-…>` |
| P7 the design-mode host API, mapped | 8, 12, 15-20 | `<one id per P7 row 2a owns>` |
| Review Focus 1 (missing kit, saved) | 10 | `L-1` |
| Review Focus 2 (one broken object) | 11 | `F-2` |
| Review Focus 3 (two `T`s) | 8, 17 | `C-covariance`, `P-two-types` |
| Review Focus 4 (load mid-shape, pending field) | 8, 17 | `C-swap-mid-shape`, `P-swap-pending` |
| Review Focus 5 (late, failing library) | 13 | `S-late-fail` |
| The paint-allocation invariant | 15 | `<CV-…>` |

## Ported tests (A12)

One row per source test file ported, from the task reports: the source file, the destination,
the number of tests ported (as the report counted them by name), and "assertions unchanged".
A ported test whose assertion had to change was a finding (Global Constraints); list each such
finding here with the coordinator's ruling, or write "none".

| Source (`jet_cad_floor_plan` / `apps/floor_planner`) | Destination | Tests | Assertions |
|---|---|---|---|
| `<…>` | `<…>` | `<n>` | `<unchanged / finding: …>` |

## Mutations of Tasks 1-20

As the task reports record (`.superpowers/sdd/2026-10-14-plan-library-2a/task-N-report.md`),
each ran on a committed file and was reverted with `git checkout --`, then `git diff --quiet`.

| ID | Task | File | The change | Red test |
|---|---|---|---|---|
| `<…>` | `<…>` | `<…>` | `<…>` | `<…>` |

A named mutation that did not turn its test red is listed here with the task's resolution
(a test strengthened in the fix round, or the coordinator's ruling).

## Plan decisions

One line each, in task order, copied from the plan's "Plan decision" paragraphs.

## Spec gaps and interface problems found while executing

Each `#### Interface problem` of the plan's task bodies and each finding a task report raised
against the spec, with its resolution (amendment, ruling, or carried to 2b / sub-project 3).
````

- [ ] **Step 9: Commit.**

```bash
git add docs/superpowers/notes/2026-10-14-plan-library-2a-results.md
git commit -m "$(cat <<'EOF'
docs: the plan library in design mode, results of record

The exit gate's transcripts, the spec coverage table, the ported-test
and mutation tables and the plan decisions of sub-project 2a
(jet_cad_2d_plan and the contract's code side), for the whole-branch
review.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Hand over.** The independent Opus review of the whole branch, its fix wave, and the ledger archived onto the branch as its last commit (spec exit gate, "Review") are the coordinator's next steps. Nothing is pushed, tagged, merged or published from this task.

There is no Mutation step: this task changes no code.

---

## Appendix: rulings made while planning (2026-10-14)

Each was made by the controller while seven writers drafted the tasks in parallel; the spec stays the authority.

- **E4 is opt-in.** `DraftDocumentCodec.decode`/`decodeString` take `keepUnreadableComponents` (default `false`), so `SymbolLibrary.decode`'s rule errors and `jet_cad_floor_plan` keep today's behaviour; `decodePlan` passes `true` (Task 1, Task 7).
- **E3 has four sites** (regeneration ×3, `CompoundCommand.apply`); E2's frozen object is a plain group (Task 2).
- **`Disposable`** is contract (`jet_cad_2d_kit`, Task 4): kits' caches and providers implement it.
- **`PlanToolSettings.fieldsOf(..., {required String toolId})`** builds `property:<tool id>.<id>` words (Task 4).
- **`PlanSwatch`**, the eight-colour palette, is contract (`jet_cad_2d_kit/lib/src/kit/swatch.dart`, Task 9): kits name swatches without depending on the plan library. A contract addition the spec implies (P3 colour) but does not name.
- **Every widget-side commit goes through `PlanController.execute(DraftCommand) -> bool`**, which turns every refusal (`PlanLocked`, `DanglingReferenceError`, `ArgumentError`, `KitHookFailure`) into `false` (Tasks 10-11, consumed by 15-19).
- **Names:** `toolController` (never `tools`); `panel_focus.dart` and `placeSymbol` in Task 13; the shortcut guard in Task 15; `DiagnosticsLog` at `lib/src/controller/diagnostics_log.dart`; `registries.dart` and `camera_bounds.dart` created by Task 8; the property panel's layer field filled by Task 18 through Task 17's slot.
- **Panel fields use the language's decimal separator** (spec P3 corrected at `c4cccac`); the plan's separator governs what is drawn.
- **NS7 kept (A14):** `PlanLocaleScope.push` reports the locale and `PlanStrings.of(context)`; a new plan's separator comes from those strings, so a host's own language class still sets it (Task 9).
- **Ported assertions may move, never weaken:** each moved assertion is listed in its task with its new owner (another task, 2b or sub-project 3).
- **Tool settings belong to the controller** and survive a document swap (today's shell kept them per document): a deliberate change, recorded in Task 8 and the results note.

