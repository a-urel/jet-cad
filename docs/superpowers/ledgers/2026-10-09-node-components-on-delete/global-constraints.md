# Global constraints (verbatim from the plan)


- `CLAUDE.md`'s non-negotiables. **The two allocation invariants**
  (`query_allocation_test`, `paint_allocation_test`) and every image
  golden stay untouched. **Draw order stays ascending handle value**:
  nothing here touches the spatial index, the tile cache or a painter.
- **Additive API only.** `AddNodeCommand` gains an optional named
  `components` (default `ComponentSnapshot.empty`); `ComponentRegistry`
  gains `checkRestorable`. No signature, `==`, `hashCode` or `toString`
  changes otherwise. `AddNodeCommand(node)` and
  `AddNodeCommand(node, index: i)` keep their meaning.
- **`capability` (the summary) stays `structure`** on both node commands
  (D-2): `SpatialIndex`, `TileCache` and `CompoundCommand.capability`
  read what they read today. Only `capabilities` (the set) changes.
- **Existing tests pass unedited**, with these named exceptions and
  nothing else:
  - Task 1: `jet_cad_2d/test/document/compound_command_test.dart`
    *"capabilities is the union of the children's"* (`:300-313`, the
    expected set gains `Capability.components`); `test/parametric/`
    `cascade_test.dart` CS7 (`:405-431`) and LV2 (`:773-800`),
    `objects_of_test.dart` OB1 (`:122-124`), `misplaced_test.dart` MP6
    (`:246-249`), `dissolve_test.dart` DV1 (`:214-238`, `:290-298`),
    `page_test.dart` PG1 (`:205-228`). The spike at `e281372` saw exactly
    these seven go red under D-1 (spec F-14).
  - Task 2: `jet_cad_floor_plan/test/tables/table_data_test.dart` TD8's
    and TD9's titles, TD10 (rewritten) and `_RefusingTarget` (rewritten
    with TD10).

  Any other test that has to change is a finding for the task's report,
  not an edit to make.
- **Fixtures are never degenerate** (spec, *Testing*): the removed node
  is not the first handle, sits under a non-root parent at a
  non-identity transform and not last among its parent's `children`,
  carries two registered components with non-default values and two
  unknown payloads attached out of type-id order; a sibling carries the
  same types with other values. Snapshots in all-or-nothing tests are
  non-empty.
- **Each named mutant is applied, seen red, and reverted** from a saved
  copy (`cp file /tmp/x.bak` … `cp /tmp/x.bak file`), **never
  `git checkout`**. The report names each mutant, its killing test, and
  the line of output that shows it red. Every mutant belongs to exactly
  one task.
- **Never synthesize test output.** Paste real output into reports.
- **Never commit an `analysis_options.yaml`**: `flutter pub get` rewrites
  three. Check `git status` before each commit.
- **Gates, every task**, in every package it touches and every package
  that depends on one it changed:
  - `packages/jet_cad_2d`: `dart test`, `dart analyze --fatal-infos`,
    `dart format --output=none --set-exit-if-changed .`;
  - `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d_gpu`,
    `packages/jet_cad_restaurant_symbols`, `apps/floor_planner`,
    `apps/restaurant_demo`: `flutter test`, `flutter analyze`, format;
  - `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice`
    (the pick allocation test needs it, as CI passes it), analyze, format.
- **Standing failures on this machine (macOS), measured at `e281372`:**
  `jet_cad_2d`'s two `generate_document_test` fingerprints and
  `jet_cad_2d_flutter`'s five text-ladder goldens. Anything else red is a
  finding. CI on Linux compares its own lists exactly
  (`tool/ci/standing_failures.txt`); the branch's CI run is the check of
  record for those.

## Review focus

Inputs the spec implies that a person will meet, most likely first; each
has its test in the owning task.

1. **Delete then Undo of a wall that hosts a door**, in the planner: the
   door goes with the wall (08 D4's cascade) and both come back exactly,
   parameters and layers included. Task 2, **P-3**.
2. **Delete then Undo of a group holding a nested group and an
   instance**, each carrying data (registered and a newer release's
   unknown payload): one undo step, all three exact. Task 1, **S-1**.
3. **A plan saved by 0.4.0 or earlier with orphaned entries** opens and
   saves byte for byte, orphans kept. Task 1, **N-7**.
4. **A delete that fails part-way** (a compound whose later removal
   throws) leaves every component where it was. Task 1, **N-5**.
5. **A permission profile that allows structure but not components**: a
   delete is refused and the key stays selected; an add is allowed but
   its undo is refused and stays on the stack. Task 1, **N-3**.

