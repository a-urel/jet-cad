### Task 10: The export dialog

**Files:**
- Modify: `lib/src/export/export_dialog.dart` (and `editor_page_flows.dart` only if it builds chrome)
- Test: `test/export/{export_dialog,page_flows}_test.dart`, `test/support/flows_bar.dart`, `apps/architecture_demo/test/support/export_rig.dart` users; new `test/export/export_dialog_chrome_test.dart`

**Interfaces:**
- Consumes: `planShadThemeOf`, `PlanShadScope(data:)`.
- Keeps: `showPlanExportDialog(BuildContext, PlanExportAnswer, List<PlanExporter>)` and `typedef PlanExportDialog` unchanged.

- [ ] **Step 1: Write failing tests:** `EX1 showPlanExportDialog called
  directly under a bare MaterialApp (no editor) opens, light and dark`;
  `EX2 called from inside a local Theme with a distinct ColorScheme, the
  dialog's card is that scheme's derived card colour`;
  `EX3 called under a host ShadTheme, the dialog uses it`;
  `EX4 the dialog's words come from the caller's PlanStrings (Turkish)`;
  `EX5 Escape and the barrier dismiss it with null; the primary button
  returns the answer`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement:** resolve
  `planShadThemeOf(context)`, the `PlanStrings` and `PlanTheme` at the call
  site; push `ShadDialogRoute` (exported at 0.57.1) or `RawDialogRoute`
  whose page is `PlanShadScope(data: resolved, child: <the captured
  scopes>(ShadDialog(...)))`; `SegmentedButton` ×2 → `PlanSegmented`;
  buttons → `ShadButton`.
- [ ] **Step 4: Run; rulings** (`AlertDialog → ShadDialog`). **Step 5: Mutation** M-EX call `showShadDialog(context: context, ...)` → EX1 red. Revert.
- [ ] **Step 6: Gates (plan, integration, both demos); commit** `feat(plan): the export dialog in shadcn`.

