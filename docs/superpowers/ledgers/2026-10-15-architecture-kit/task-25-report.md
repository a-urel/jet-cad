# Task 25 report: the sample flat (spec C3.7, C1.9, C6; D-34)

Status: DONE
Commit: `45be3170 feat(architecture): the sample flat as a plan build (3a C3.7)` (on e35cc9ff)

## Implementation summary

- `packages/jet_cad_2d_kit_architecture/lib/src/sample/sample_flat.dart` (new):
  - `buildSampleFlat(DraftDocument, KitWords)`, a `PlanBuild`. It is today's
    `startupPlan` (`jet_cad_floor_plan/lib/src/startup_plan.dart`) with these parts:
    - Lines 84-198 copied verbatim: walls, doors, windows, finishes, furniture,
      column and separator.
    - Then the page, set by command before the rooms. Its separator comes from
      `words.decimalSeparator == ','`, mapped to comma or point (today's
      `documentSeparatorFor`).
    - Then the seven rooms, named by
      `words.text('text:architecture.sample-…', {'n': …})`.
    - Then lines 222-247 verbatim: the five dimensions.
  - It contains no `prepareDocument`, no `installParametric` or system dispose,
    and no `clearHistory`. The plan library does all of these (C1.9).
  - Today's constants `kPlanOriginX/Y`, `kPlanWidth/Height`, `_wall`,
    `_partition` and the two colours are unchanged. `kMinScale`/`kMaxScale` are
    not moved; the plan's `kPlanMinScale`/`kPlanMaxScale` replace them.
  - `startupPage` became the private `_samplePage`, unchanged otherwise.
  - `_Pen` (lines 269-422) is copied verbatim.
- Barrel: `export 'src/sample/sample_flat.dart' show buildSampleFlat;`.
- Integration library: `sampleFlatController()` is
  `PlanController(kits: [architectureKit], build: buildSampleFlat)`, because
  `architectureController` passes only kits, json and permissions. The library
  doc's "(Task 25: `sampleFlatController`)" note was trimmed to "Later tasks
  add their fixtures here."
- `test/wall/wall_regen_test.dart`, WR9: the sample-plan line is restored as
  the brief gives it (R11-1), with its assertion unchanged
  (`expect(diagnosticsOf(sample), isEmpty);`). The 4 imports were added as the
  brief lists them.

## Fidelity check (object for object, source order)

Method:
- I wrote three temporary dump tests. None were committed, and all were
  deleted afterwards; `git status` is clean.
  - In `jet_cad_floor_plan/test`: `startupPlan(m)` and
    `startupPlan(m, strings: FloorPlanStringsDe())`.
  - In the kit: the brief's `sampleFlat` document path, in en and in de with
    `','`.
  - In the integration package: `sampleFlatController().document` after the
    library settles.
- Each document was written with `DraftDocumentCodec.encodeToString` to the
  scratchpad. The codec writes stored values exactly (save, load, save is byte
  identical, SP6).
- A Python comparer (`scratchpad/compare25.py`) does two checks:
  - (a) A byte comparison after renaming the component type ids
    `"floor_planner.` → `"architecture.`. This is C7 class 1, and it is the
    only allowed difference.
  - (b) A structural, exact-`==` walk over every key: header, tables, nodes,
    every entity's record and geometry in slot order, every component per type
    per handle, and handleSeed.

Results:

```
== old_en vs kit_en
bytes identical after id rename: True
entities: 611 vs 611
entity handles in order equal: True
nodes: 39 vs 39
component architecture.dimension 5 vs 5 / opening 15 vs 15 / room 7 vs 7 / separator 1 vs 1 / wall 10 vs 10 / jetcad.page 1 vs 1
linetypes: ['ByLayer', 'ByBlock', 'Continuous', 'DASHED']
handleSeed: 666 vs 666
differences: 0
== old_de vs kit_de         -> bytes identical after id rename: True, differences: 0
== old_en vs plan_en (sampleFlatController) -> bytes identical after id rename: True, differences: 0
```

(The component lines are abbreviated here; each printed on its own line.)

- R-3 holds: the plan library's document carries the DASHED record (the plan's
  prepare). The open path was not touched.

Negative controls:
1. The en document against the kit's de document:

   ```
   bytes identical after id rename: False
   differences: 27
      entities[555].record.text | "Hall" | "Flur"
      entities[556].record.text | "22.00 m²" | "22,00 m²"
      ...
      entities[586].record.text | "14.00" | "14,00"
   ```

2. The M-SF3 mutant (separator moved above the column) against today's en
   document. This ran on the committed file, before the revert:

   ```
   bytes identical after id rename: False
   entity handles in order equal: False
   differences: 29
      nodes[0].children[25] | 595 | 593
      entities[549].record.kind | "fill" | "polyline"
      ...
   ```

## TDD evidence

RED, with the tests written before the lib file:
- Kit: `flutter test test/sample/` fails to compile:
  - `test/sample/sample_flat_test.dart:19:8: Error: Error when reading 'lib/src/sample/sample_flat.dart': No such file or directory`
  - `:89:3: Error: Method not found: 'buildSampleFlat'.`
  - `Undefined name 'kPlanOriginX'`
- Integration: `flutter test --enable-vmservice test/sample/` fails with
  `test/sample/sample_flat_test.dart:40:13: Error: Method not found: 'sampleFlatController'.`

GREEN:
- Kit `flutter test test/sample/` → `00:01 +13: All tests passed!`. With
  `test/wall/wall_regen_test.dart` included: `+26: All tests passed!`.
- Integration `flutter test --enable-vmservice test/sample/` →
  `00:00 +3: All tests passed!`. The quoted line:

  `STARTUP fit scale 0.08857319758870041 px/mm; min 0.001 (88.57319758870041x out), max 100.0 (1129.0097086068997x in)`

## Gates

- Kit:
  - `dart format .` → `Formatted 124 files (0 changed)`
  - `flutter test` → `00:18 +597: All tests passed!`
  - `flutter analyze` → `No issues found!`
  - Format gate: OK
  - `dart pub publish --dry-run` → `Package has 0 warnings.` (after the
    commit; before it, the only warning was the uncommitted files).
- Integration:
  - `flutter test --enable-vmservice` → `00:15 +99: All tests passed!`
  - `flutter analyze` → `No issues found!`
  - Format gate: OK
- Root: `dart run tool/ci/check_kit_deps.dart` →
  `kit dependencies: 2 package(s) checked, none names the plan library or another kit`,
  exit 0.
- `git status --short` after the commit and the mutations: empty.

## Mutations

All mutations ran on committed files. Each was reverted with
`git checkout --`, and `git diff --quiet` exited 0 after every revert.

- **M-SF1** (`== ','` → `false`): SF-words red.
  - `Expected: DecimalSeparator:<DecimalSeparator.comma>  Actual: DecimalSeparator:<DecimalSeparator.point>`
- **M-SF2** (`sample('sample-hall')` → `'Hall'`): SF-words red.
  - `Which: at location [0] is 'Hall' instead of 'Flur'`
- **M-SF3** (separator moved above the column): SP2 and SP5 red.
  - SP2: `Expected: a value greater than <596>  Actual: <591>`
  - SP5: `Expected: a value greater than <593>  Actual: <591>`
- **M-SF4** (the page statement deleted): the integration page case is red.
  - `Expected: a numeric value within <1e-9> of <19000.0>  Actual: <0.0>`
- **M-SF5** (`build:` dropped): SF-controller red, along with both ported
  integration cases.
  - SF-controller: `Expected: ['Hall', …] Actual: [] Which: at location [0] is [] which shorter than expected`
  - Clamp case: `Expected: a value greater than <100> Actual: <100.0>`
  - Page case: `Expected: <19000> Actual: <NaN>`

## Ported-test accounting (D-34, startup_plan_test.dart, 14 cases)

| Old case | New home | Change class |
|---|---|---|
| is at the target scale: between 500 and 1,000 entities | kit | fixture (`sampleFlat(measurer).doc`) |
| is off-origin and not axis-symmetric | kit | fixture |
| the outer walls close … | kit | fixture; constants imported from `src/sample/sample_flat.dart` |
| the clamp constants bracket the fitted scale by decades | integration | fixture (`sampleFlatController().document`); `kMinScale/kMaxScale` → `kPlanMinScale/kPlanMaxScale` (equal values, the plan's) |
| the startup plan carries an A4 landscape page … with no history | integration | fixture; the kit constants written out (R-P1) |
| SP1 | kit | fixture |
| SP2 | kit | fixture |
| SP3 | kit | fixture |
| SP4 | kit | fixture |
| SP5 | kit | fixture; `drift()`/`diagnostics()` asked of the installed system (`flat.system`) |
| SP8 | kit | fixture (`const DimensionType()` unchanged) |
| SP9 | kit | fixture; the installed system (`flat.system`) instead of a second `installParametric` |
| SP6 | kit | fixture; decode registers `flat.catalog`, and its own system is installed and disposed at tear-down |
| SP7 | kit | fixture |

No assertion changed. Non-ASCII lines (`² √ − — ° × → · –`) were diffed
against the source with grep. The only extra line is SF-words'
`'22,00 m²'`.

New cases:
- SF-words (kit): German names and the comma. It checks the page, the area
  labels and the dimension values. Killed by M-SF1 and M-SF2.
- SF-controller (integration): killed by M-SF5.
- WR9's sample-plan line is restored (R11-1).

## Files changed

- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit_architecture/lib/src/sample/sample_flat.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit_architecture/test/sample/sample_flat_test.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit_architecture/test/wall/wall_regen_test.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_integration/lib/jet_cad_2d_integration.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_integration/test/sample/sample_flat_test.dart (new)

## Deviations

- The integration library's doc comment: the obsolete
  "(Task 25: `sampleFlatController`)" pointer was removed.
- The fidelity check added a temporary file under `packages/jet_cad_floor_plan/test/`.
  - It was never staged, and it was deleted right after the dump.
  - The old package is unchanged: `git status` is clean, and it is not in the
    commit.

## Concerns

- WR9's restored line, `diagnosticsOf(sample)` empty, is today's assertion. On
  its own it would also pass for a build that adds nothing. The sample flat's
  content is pinned by SP1-SP9, SF-words, SF-controller and the byte-level
  fidelity check, so this is noted, not acted on.
- In the kit test path, `buildSampleFlat` runs on a document with no page
  until the build sets one. This is the brief's set-up and matches today's
  `prepareDocument`. The plan path attaches the default page first.
- Both paths produce byte-identical documents, so neither difference is
  observable.
