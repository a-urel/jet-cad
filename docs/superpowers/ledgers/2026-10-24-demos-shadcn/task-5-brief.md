### Task 5: The guards

**Files:**
- Create: `apps/restaurant_demo/test/invariants/kept_material_test.dart`
- Create: `apps/architecture_demo/test/invariants/kept_material_test.dart`

- [ ] **Step 1: Write DKM1 and DKM2** (spec D8) per demo, modelled on
  `packages/jet_cad_2d_plan/test/invariants/kept_material_test.dart`
  (read it): scan `lib/**.dart`; DKM1 — every match of the Material
  construct list (the library's list: `MaterialApp`, `Scaffold`, `AppBar`,
  `Drawer`, `*Button`, `TextField`, `Tooltip`, `AlertDialog`,
  `SimpleDialog`, `showDialog`, `showMenu`, `PopupMenu*`, `Dropdown*`,
  `SegmentedButton`, `*ListTile`, `Switch(`, `Checkbox(`, `Material(`,
  `InkWell`, `Divider`, `Card(`, `SnackBar`, `ThemeData(`, `Theme.of`)
  is in an allow-list of (file, construct, reason); a stale entry fails;
  expected allow-list: empty. DKM2 — no `Icons.`.
- [ ] **Step 2: Run** — green (Tasks 1–4 removed them).
- [ ] **Mutations (controller):** an `IconButton` in
  `restaurant_demo/lib/side_panel.dart` → DKM1 red; `Icons.add` in
  `architecture_demo/lib/document_host.dart` → DKM2 red; a stale
  allow-list entry → DKM1 red.
- [ ] **Step 3: Commit** `test(demos): no Material and no Icons in the demos' lib`.

## Global Constraints

- Never commit `analysis_options.yaml` (`git status --short` before every
  commit); never synthesize output; English code, comments, commits;
  trailer `Co-Authored-By: <model> <noreply@anthropic.com>`.
- Never merge, push, tag or publish.
- **No change under `packages/`** (spec N1). A library defect found on the
  way: stop the task, report it; never a demo-side workaround.
- **Keys:** every `Key` in the demos' `lib/` keeps its value and lands on
  the widget a user acts on (spec D6).
- **Strings:** every visible word stays where it comes from today
  (`DemoStrings`, `AppStrings`, `PlanStrings`); no shadcn component that
  shows its own English words (no `ShadSelect.withSearch`, no date picker).
- **No `Icons.`** in a demo's `lib/` once its task is done: `LucideIcons`.
- **Rulings:** a test changes only under a ruling in
  `.superpowers/sdd/2026-10-24-demos-shadcn/rulings.md`: file:line,
  old → new, how the new finder checks the same thing on the same key.
  Never drop an assertion; never widen a tolerance.
- **Self-review per task** (the human's rule: no reviewer subagents): the
  controller reads the diff, runs the task's named mutation itself and
  re-runs the gates.
- **A task ends green** in the demo it touched: `flutter test`,
  `flutter analyze`, `dart format --output=none --set-exit-if-changed .`.

## Review Focus

1. **The system flips light/dark at runtime:** `ShadApp`'s derived
   Material theme flips with it, so the canvas background and the paper
   follow, as they did under `MaterialApp`. → Task 1 test `RD2`, Task 4
   test `AD2`.
2. **The language switch at runtime** (EN → DE → TR): the top pane's tabs,
   the sheet's switches and the dialogs show the new words with no stale
   English. → Task 2 test `RT4`.
3. **Phone width (375 px):** the top pane's controls scroll, the sheet
   opens from the side button and fits, nothing overflows. → Task 2 test
   `RT2`.
4. **Large text (`TextScaler.linear(2.0)`)** at 375 and 1300 px: the top
   pane and the side panel do not overflow. → Task 2 test `RT3`.
5. **Keyboard only in the architecture demo's dialogs:** Save has the focus,
   Enter saves, Escape cancels, the name prompt's Enter submits. → Task 4
   test `AD4`.

---
