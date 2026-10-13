### Task 1: R-10 — the planner exports `SymbolLibraryState` and `TableNumberProblem` (D9, A4)

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart` (the export list, near line 64)
- Modify: `packages/jet_cad_floor_plan/test/host/barrel_test.dart` (B1's set; a new test)
- Modify: `docs/host-guide.md:155-164` (the `FloorPlanStrings` bullet)

**Interfaces:**
- Produces: `SymbolLibraryState`, `SymbolLibraryLoading`, `SymbolLibraryReady`, `SymbolLibraryFailed`, `TableNumberProblem` on `package:jet_cad_floor_plan/jet_cad_floor_plan.dart`. Task 3 relies on `SymbolLibraryReady` from the barrel.

- [ ] **Step 1: Write the failing test.** In `barrel_test.dart`, add the five names to B1's expected set, and add:

```dart
  test('B-R10 the library state and the number problem through the barrel',
      () {
    // An exhaustive switch over the sealed family and every enum value:
    // dropping either export (M-R10a, M-R10b) is a compile error here.
    String word(SymbolLibraryState s) => switch (s) {
          SymbolLibraryLoading() => 'loading',
          SymbolLibraryReady() => 'ready',
          SymbolLibraryFailed() => 'failed',
        };
    expect(word(const SymbolLibraryLoading()), 'loading');
    expect(TableNumberProblem.values.map((p) => p.name).toList(),
        ['length', 'control']);
  });
```

- [ ] **Step 2: Run it to see it fail.** `cd packages/jet_cad_floor_plan && flutter test test/host/barrel_test.dart`. Expected: compile errors naming `SymbolLibraryState` and `TableNumberProblem` (undefined).

- [ ] **Step 3: Add the exports** after the `symbol_library_loader.dart` export:

```dart
export 'src/symbols/symbol_library_state.dart'
    show
        SymbolLibraryState,
        SymbolLibraryLoading,
        SymbolLibraryReady,
        SymbolLibraryFailed;
```

and, keeping the file's order by path, `export 'src/tables/table_numbers.dart' show TableNumberProblem;`.

- [ ] **Step 4: Run it to see it pass.** Same command: all tests passed.

- [ ] **Step 5: Mutations.** Copy the barrel aside; remove the `symbol_library_state` export (M-R10a): B-R10 fails to compile; restore, `cmp`. Remove the `table_numbers` export (M-R10b): same; restore, `cmp`. Record both outputs' first error line for the results note.

- [ ] **Step 6: The guide.** Replace the bullet's last sentence (lines 161–164) with: "A class that implements or directly extends `FloorPlanStrings` must also write the abstract `tableNumberProblem(TableNumberProblem)`; the barrel exports `TableNumberProblem` since 0.7.2." The guide gains no code block, so the probe does not change. Run `dart run tool/ci/check_guide.dart` from the root: green.

- [ ] **Step 7: Gate and commit.** The planner's gate (CLAUDE.md, `--enable-vmservice` as CI runs it, compared with `dart run tool/ci/expect_failures.dart --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan <report>`), then:

```bash
git add packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart packages/jet_cad_floor_plan/test/host/barrel_test.dart docs/host-guide.md
git commit -m "feat(floor_plan): export SymbolLibraryState and TableNumberProblem (R-10)"
```

---

