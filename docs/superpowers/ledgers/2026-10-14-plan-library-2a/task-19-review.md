# Task 19 review: export, import and print through registries (7c0156a3..826ee7e1)

### Spec Compliance

- ✅ Spec compliant. Each file the brief lists has its hunk (20 files, matching Steps 0-10 and the Step 13 `git add` list). No old package changed: `git diff --stat` over `packages/jet_cad_floor_plan`, `packages/jet_cad_2d`, `packages/jet_cad_2d_flutter` and `apps` is empty.
  - **P5 registries.**
    - `PlanExporter` has id, extension, mimeType and `export(request)`, and `PlanImporter` returns `Future<String>` (`registries.dart:13-46`).
    - The built-ins come first as `plan.pdf`/`plan.png` (`page_flows.dart:38-42`). Ids must be unique, and a duplicate throws an ArgumentError naming the list (`page_flows.dart:56-74`; the factory checks first at `plan_controller.dart:107`).
    - Text without a manifest goes through `ensureManifest` before `_load` (`page_flows.dart:266`).
    - Types with `exported: false` produce `omitted` (`plan_controller.dart` pageFlows initialiser; `page_flows.dart:125-135`).
    - The dialog lists the registry, one segment per exporter, keyed `export-format-<id>` (`export_dialog.dart:66-75`). Printing goes through `const PlanPdfExporter()` (`page_flows.dart:220`).
    - The copy is decoded synchronously before the first await and disposed in `finally` (`page_flows.dart:188-199`, `:140-158`).
  - **P2 export rules.**
    - One export or print at a time: `acquire` in `guarded` and in `_run` (`page_flows.dart:162-171`; `editor_page_flows.dart:97-114`).
    - No page where one is needed answers null (`page_flows.dart:185-187`), and a plan replaced before or after the bytes answers null (`:184`, `:200`).
    - Pending input is settled first (`:165`; `editor_page_flows.dart:101`).
    - `controller.export` keeps the remembered answer; only `EditorPageFlows` writes `dialogAnswer`.
    - Errors propagate. Print returns `Future<bool>` and import returns `Future<void>`.
  - **A17.4.** The interfaces are `abstract interface` and exported from the barrel (`jet_cad_2d_plan.dart:46-58`).
  - **R-k.** `registries.dart` is extended in place, not duplicated.
- Deviations checked:
  - **Dev 1, `document: () => this.document`.** This is correct and necessary. `PlanController._(this.kits, this.catalog, DraftDocument document, …)` (`plan_controller.dart:152`) shadows the getter `DraftDocument get document => _session.document` (`:383`). `catalog` is an initializing formal of a `final` field (`:227`), so `() => catalog` is the same object. Checked by reading those three lines.
  - **Dev 2, `keepUnreadableComponents: true`.** It is consistent with `decodePlan` (ruling E4). The registrations in `_copyOf` match `PlanController._register` (`plan_controller.dart:211-215`, checked).
  - **Devs 3-9.** These are lint, import or brief-sanctioned port mechanics. None weakens an assertion.
- Ported assertions were spot-checked against `packages/jet_cad_floor_plan/test/host/page_flows_test.dart`:
  - PF8 (`:400-448`): 7 expects, identical.
  - PF13 (`:573-617`): identical apart from the `fileName`→`name` rename.
  - PF9 (`:450-491`): identical with `reason: mode.name`→`'run $run'`.
  - PF22-PF24 (`:856-976`): identical. PF23's dropped `expect(got.single.fileName, 'plan.png')` is the selection-mode block the brief moves to 2b (S-22).
- pubspec: `pdf: ^3.13.1` and `printing: ^5.15.1` match `jet_cad_floor_plan/pubspec.yaml:49-50`.
- ⚠️ Cannot verify from the diff:
  - Test results and the 14 mutation red-lines are the implementer's claims. I did not re-run them. Re-run at least M-X-4, M-X-6 and M-X-10, which cover the copy, the manifest and the replaced-plan rules.
  - PF2-PF4, PF7, PF10-PF12, PF14-PF16 and PF18-PF21 were not compared line by line with the source.

### Strengths

- The implementer caught a real brief defect (Dev 1): the `document` closure captured the first plan. They proved it with PF8 and PF21 red and explained the fix in a comment. Without it, every replaced-plan rule would have silently held the first plan forever.
- `_copyOf` clears its measurer if the decode throws, and every argument of the `PlanExportRequest` (`omittedOf`, `exportPageOf` on the copy) is evaluated inside the `try`. The copy is disposed on every path.
- The new tests use off-origin fixtures with non-zero rotations and non-round coordinates (`export_plan.dart:16-27`).
- X-3 compares bytes against an independently computed `exportPagePng` with and without the marks, plus a premise that the two differ. X-4 checks identity, isolation from a later edit and disposal. X-6 covers both import refusals and keeps the plan.
- Each new X test names its mutation. The report adds three more (M-X-10..12) and a re-check of M-C13 for the redefined C13.

### Issues

#### Critical (Must Fix)
None.

#### Important (Should Fix)
None.

#### Minor (Nice to Have)

1. **`editor_page_flows.dart:82-86`: the answer is remembered before its id is checked.** `flows.dialogAnswer = answer` runs before `exportOnce` calls `exporterOf(answer.exporter)`. A host dialog that answers an unknown id therefore leaves an invalid remembered answer, and the ArgumentError goes to `onError`. The next host dialog is then handed that invalid `initial`; the Material dialog falls back to the first exporter. The brief's code is identical. Fix: validate with `flows.exporterOf(answer.exporter)` before assigning.
2. **`editor_page_flows.dart:69-71` with `page_flows.dart:185-187`: a page-less plan with a host page-free exporter.** The dialog still offers PDF and PNG, and choosing one exports nothing, silently. The report flags this. It is for Task 20: filter `PlanPageExporter`s out of the dialog when the plan has no page.
3. **`page_flows.dart:149-151`: a second registration list.** `_copyOf` repeats `PlanController._register`'s three registrations (`plan_controller.dart:211-215`). If the controller later registers another component, the export copy will drift: it will keep that component raw or misread it. Fix: inject a `void Function(ComponentRegistry)` (the controller's `_registerComponents`) in place of `catalog` for the decode.
4. **`export_font.dart:16-18`: a doc comment contradicts the header.** It says the bytes are "held for the app's lifetime (spec 13 D7: 'once per app')", but the cache is now one per `PlanPageFlows`, i.e. per controller. The file header (`:1-3`) says "once per controller".
5. **`test/export/page_flows_test.dart:292-293`: a stale PF8 comment.** It says "the swap's microtask runs right after the font's check". `printOnce` no longer checks between the font and the bytes; the late case is caught by the check after the bytes (`page_flows.dart:229`). The assertion still holds; only the explanation is stale.
6. **`test/export/page_flows_test.dart:704-738`: PF23 has no positive control.** Both cases now assert only `got, isEmpty`, because the brief trimmed the S-22 block, which carried the positive control. A flow that never got past the dialog would also pass. PF22's control covers a nearby path. This is brief-mandated (the assertion moved to 2b). Consider a one-line control after `c.permissions = PlanPermissions.full`.
7. **The test files do not name M-X-10/11/12.** PF7 (`page_flows_test.dart:203`), PF8 (`:262`) and PF22 (`:668`) carry no `// M-X-…` comment. The mutations are named only in the brief and the report, while the X tests name theirs inline.

### Assessment

**Task quality:** Approved

**Reasoning:** The diff implements Steps 0-10 almost verbatim. The one substantive deviation fixes a real closure-capture defect in the brief. The copy, guard, settle, page and replaced-plan rules are each enforced at a single site and pinned by a named mutation. What remains is polish and Task 20 follow-ups.
