### Task 1: The library exports the export dialog and the file chords

The app's busy wrapper (decision 5) must call the library's own export
dialog, and its consume-only chord layer (Review Focus 5) must name the
same chords the editor binds. Both exist in `jet_cad_2d_plan` but are not
exported.

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`
- Modify: `packages/jet_cad_2d_plan/test/barrel_test.dart`
- Modify: `packages/jet_cad_2d_plan/CHANGELOG.md` (the unreleased 0.1.0
  section: one line)

**Interfaces:**
- Produces: public `showPlanExportDialog(BuildContext, PlanExportAnswer,
  List<PlanExporter>) → Future<PlanExportAnswer?>` (matches
  `PlanExportDialog`) and `kFileChords` (`List<SingleActivator>`: New,
  Open, Save, Save As, Export, Print, each in its Ctrl and Meta form).

- [ ] **Step 1: Read `barrel_test.dart`** to see how it pins the barrel's
  names (a list of names, or a compile-time use of each).

- [ ] **Step 2: Add the two names to the test** in that file's style, e.g.

```dart
test('the barrel exports the export dialog and the file chords', () {
  const PlanExportDialog dialog = showPlanExportDialog;
  expect(dialog, isNotNull);
  expect(kFileChords, isNotEmpty);
});
```

- [ ] **Step 3: Run it red:** `cd packages/jet_cad_2d_plan && flutter test test/barrel_test.dart` → compile error, undefined names.

- [ ] **Step 4: Export them:**

```dart
export 'src/export/export_dialog.dart'
    show PlanExportDialog, showPlanExportDialog;
export 'src/shortcuts/chords.dart' show kFileChords;
```

(replace the existing `export 'src/export/export_dialog.dart' show
PlanExportDialog;` line; keep the file's sort order).

- [ ] **Step 5:** If `kFileChords`' doc comment does not say what it holds,
  add one line. Run the package gates: `flutter test --enable-vmservice`,
  `flutter analyze`, `dart format --output=none --set-exit-if-changed .`.
  Mutation: drop `showPlanExportDialog` from the show list → the test
  fails to compile.

- [ ] **Step 6: Commit** `feat(plan): export showPlanExportDialog and kFileChords for hosts`.

---

