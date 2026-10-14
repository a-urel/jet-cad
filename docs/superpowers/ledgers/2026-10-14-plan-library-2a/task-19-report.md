# Task 19 report: export, import and print

Status: DONE_WITH_CONCERNS (minor ones; see the end)
Commit: 826ee7e1 `feat(plan): export, print and import through registries` (BASE 7c0156a3)

## Implemented

- `pubspec.yaml`: `pdf: ^3.13.1` and `printing: ^5.15.1` (jet_cad_floor_plan's constraints), in alphabetical order.
- `lib/src/export/registries.dart` (Task 8's file, extended under R-k, no parallel file): `PlanExporter`, `PlanPageExporter`, `PlanImporter`, `PlanExportDpi`, `PlanExportChoice`, `PlanExportAnswer`, `PlanExportFonts`, `PlanExportRequest` (with `choice` and `fonts`), `PlanExport`. These match the brief's Step 4 exactly.
- `lib/src/export/page_printer.dart`: a verbatim port with the header line added.
- `lib/src/export/export_font.dart`: a port of `loadExportFont` and `ExportFontCache implements PlanExportFonts` that reads `kPlanFontAsset`. The asset constants and `registerFontLicences` were dropped because Task 9 owns them.
- `lib/src/export/builtin_exporters.dart`: `PlanPdfExporter` (`plan.pdf`) and `PlanPngExporter` (`plan.png`), both `PlanPageExporter`s, plus `exportPageOf` and `printPageFormat`. There is no table underlay.
- `lib/src/export/page_flows.dart`: `PlanPageFlows`, which holds:
  - the registries (built-ins first, unique ids, `checkRegistry`);
  - the one-flow guard (`ready`, `acquire`, `release`, `guarded`), the remembered `dialogAnswer` and `fonts`;
  - `exportOnce` and `printOnce` over a copy decoded at the start and disposed once the bytes are back;
  - `omittedOf`, which uses `catalog.typeIdOf` on the copy;
  - `export`, `print` and `import` (an unknown id throws an `ArgumentError` at once; `ensureManifest` runs before `load`).
- `lib/src/export/export_dialog.dart`:
  - `PlanExportDialog` typedef, `isRasterExporter` and `showPlanExportDialog`.
  - The dialog has one segment per exporter, labelled by its extension in capitals and keyed `export-format-<id>`.
  - The dpi row shows only for `image/*` exporters.
- `lib/src/export/editor_page_flows.dart`: `EditorPageFlows`, `PageFlowSettings` and `PageFlowHooks`. Hooks and settings are read at each call. `permissions.export` and `.print` are re-read after the dialog and after the bytes, and the flows share the controller's guard.
- `lib/src/controller/plan_controller.dart`:
  - The factory calls `PlanPageFlows.checkRegistry`.
  - The `@internal` fields `exporters` and `importers` are replaced by `@internal late final PlanPageFlows pageFlows`, built in the private constructor.
  - New public members: `exporters`, `importers`, `export`, `print`, `import`.
  - `dispose` calls `pageFlows.dispose()`.
- Barrel: the brief's three `show` exports.
- Test support (new): `fake_page_printer.dart` (a verbatim port; only the import changed), `export_plan.dart`, `recording_exporters.dart`, `flows_bar.dart`.
- Tests (new):
  - `plan_export_types_test.dart` (X-1)
  - `registry_test.dart` (X-2 to X-8)
  - `export_dialog_test.dart` (X-9)
- Tests (ported):
  - `export_font_test.dart` (EF4, EF5, EF7, EF8)
  - `page_flows_test.dart` (PF2, PF3, PF4, PF7-PF16, PF18-PF24, as the brief lists them)
- C13 (`plan_controller_test.dart`): its three `exporters` expectations now include the built-ins (Step 8 item 5).

## TDD evidence

RED: after Steps 0-3, `flutter test test/export` failed to compile, as expected. Excerpt:

```
test/export/export_font_test.dart:11:8: Error: Error when reading 'lib/src/export/export_font.dart': No such file or directory
test/export/export_font_test.dart:40:27: Error: Method not found: 'loadExportFont'.
test/export/plan_export_types_test.dart:10:21: Error: Undefined name 'PlanExportChoice'.
test/export/plan_export_types_test.dart:11:25: Error: Undefined name 'PlanExportDpi'.
```

First GREEN attempt: 2 real failures, PF8 and PF21. Both came from a defect in the brief's code, deviation 1 below:

```
00:01 +17 -1: ... PF8 (T1-b) export of a plan replaced before its bytes ... [E]
Expected: null
  Actual: <Instance of 'PlanExport'>
00:05 +28 -2: ... PF21 (R-5) the hook's answer is remembered even when the plan is replaced ... [E]
Expected: empty
  Actual: [Instance of 'PlanExport']
```

After fixing it, `flutter test test/export` printed `00:19 +33: All tests passed!`.

## Gates (packages/jet_cad_2d_plan, before the commit; the source is identical at 826ee7e1)

- `dart format .` printed `Formatted 162 files (0 changed)`.
- `flutter analyze` printed `No issues found! (ran in 3.1s)`.
- `flutter test` printed `00:36 +635: All tests passed!`.
- `dart format --output=none --set-exit-if-changed .` exited 0.
- `dart pub publish --dry-run`, after the commit, printed `Package has 0 warnings.` Before the commit it reported 1 warning: the uncommitted files.
- `git status --short` after the pub operations and after the mutations is clean. No `analysis_options.yaml` was rewritten.

## Mutations (on 826ee7e1)

Each was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` exited 0 (`REVERTED` printed) every time.

| Mutation | Change | Red line |
|---|---|---|
| M-X-1a | `PlanExportChoice.==` becomes `other is PlanExportChoice` | X-1, `plan_export_types_test.dart 16:5`: `Expected: false  Actual: <true>` |
| M-X-1b | `PlanExportAnswer.==` drops `other.exporter == exporter &&` | X-1, `plan_export_types_test.dart 31:5`: `Expected: false  Actual: <true>` |
| M-X-2 | delete both `_unique(...)` calls in `checkRegistry` | X-2, `registry_test.dart line 67`: `Expected: throws <Instance of 'ArgumentError'> with name: 'exporters'  Actual: <Closure: () => PlanPageFlows>` |
| M-X-3a | `omittedOf` returns `const {}` first | X-3, `registry_test.dart line 106` (`got.bytes` vs `without`) |
| M-X-3b | `unexported` drops `if (!type.exported)` (plan_controller.dart) | X-3, `registry_test.dart line 111` (`drawn.bytes` vs `whole`) |
| M-X-4 | `exportOnce` passes `document: live`; the `finally` no longer disposes the copy | X-4, `registry_test.dart line 133`: `Expected: false  Actual: <true>` |
| M-X-5 | delete the page test in `exportOnce` | X-5, `registry_test.dart line 161`: `Expected: null  Actual: <Instance of 'PlanExport'>` |
| M-X-6 | `_load(ensureManifest(text))` becomes `_load(text)` | X-6, `registry_test.dart line 202`: `PlanFormatException(noManifest)` thrown; `Expected: false  Actual: <true>` |
| M-X-7 | `printOnce` uses `const PlanPngExporter()` | X-7, `registry_test.dart line 256`: `Expected: [37, 80, 68, 70]  Actual: [137, 80, 78, 71]` |
| M-X-8 | delete `_settle();` in `guarded` | X-8, `registry_test.dart line 278`: `Expected: a value greater than <0>  Actual: <0>` |
| M-X-9 | `if (isRasterExporter(_exporter)) ...[` becomes `...[` | X-9, `export_dialog_test.dart line 42`: `Expected: no matching candidates  Actual: Found 1 widget with key [<'export-dpi'>]` |
| M-X-10 | `exportOnce`'s post-bytes check becomes `if (cancelled()) return null;` | PF8, `page_flows_test.dart line 273`: `Expected: null  Actual: <Instance of 'PlanExport'>` |
| M-X-11 | `editor_page_flows.dart`: `if (answer == null) return;` | PF22, `page_flows_test.dart line 693`: `Expected: PlanExportAnswer(plan.pdf, 150 dpi)  Actual: PlanExportAnswer(plan.png, 150 dpi)` |
| M-X-12 | `if (!acquire()) return busy;` becomes `acquire();` | PF7, `page_flows_test.dart line 216`: `Expected: null  Actual: <Instance of 'PlanExport'>` |
| M-C13 (Task 8's, re-checked) | `PlanPageFlows(exporters: const [], importers: const [], …)` | C13, `plan_controller_test.dart line 330`: `Expected: ['plan.pdf', 'plan.png', 'acme.dxf', 'acme.svg']  Actual: ['plan.pdf', 'plan.png']` |

Mapping the brief's M-X-4 onto my code: the brief's "the finally no longer disposes it" is my `finally { _disposeCopy(copy); }` becoming `finally {}`. That is the same change, through the helper of deviation 3.

## Files

- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/pubspec.yaml`
- `.../packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`
- `.../packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`
- `.../packages/jet_cad_2d_plan/lib/src/export/{registries,builtin_exporters,export_font,page_printer,page_flows,export_dialog,editor_page_flows}.dart`
- `.../packages/jet_cad_2d_plan/test/support/{fake_page_printer,export_plan,recording_exporters,flows_bar}.dart`
- `.../packages/jet_cad_2d_plan/test/export/{plan_export_types,registry,export_dialog,export_font,page_flows}_test.dart`
- `.../packages/jet_cad_2d_plan/test/controller/plan_controller_test.dart`

## Deviations from the brief

1. **`document: () => this.document` in the controller (Step 8, item 2).** The brief's `document: () => document` sits in the private constructor's body. There, `document` names the constructor's own positional parameter, which is the first plan, not the `document` getter. The flows therefore never saw a `load` or `newPlan`. PF8 and PF21 went red (quoted above). I added `this.` and a comment saying why. `catalog` refers to the same object either way and was left as it is.
2. **The copy is decoded with `keepUnreadableComponents: true`, and the measurer is cleared if the decode throws (`_copyOf`).**
   - A plan can hold a component that E4 kept raw. Re-encoding writes it raw, and decoding it without the flag throws (today's E4 default). The flag makes the copy read the plan as `decodePlan` does.
   - This does not change the brief's contract.
3. **`_disposeCopy` helper with `unawaited(copy.document.dispose())`.** `DraftDocument.dispose()` returns a `Future`, and the package's `unawaited_futures` lint rejects the brief's bare call. The helper keeps `exportOnce` and `printOnce` from duplicating it.
4. **`page_flows_test.dart` also imports `…/export/export_dialog.dart`.** `pumpCaps` types its `dialog` parameter as `PlanExportDialog`, and the brief's import list omitted that file.
5. **The controller does not import `dart:typed_data` (Step 8, item 1).** The analyzer reported `unnecessary_import`, because `package:flutter/foundation.dart` already provides `Uint8List`.
6. **PF9: `final c = await pumpFlows(…)` became `await pumpFlows(…)`.** Its only reader was the dropped `toMode`, and `unused_local_variable` is an error in this package. The assertions are unchanged.
7. **PF8 port details, within the brief's rule.**
   - The source's mode switch and its load both become `c.load(next)`.
   - `next = exportPlanJson()` is computed once, before the `runAsync` blocks. This is a fixture change; it keeps the scratch controller's construction out of the timed section.
   - The `setMode(design)` restorations between cases were dropped: a load needs no restoring.
   - `c.exportFont.bytes` became `c.pageFlows.fonts.bytes`.
8. **The mode loops, per the brief's rule.**
   - Run twice: PF3, PF9, PF12. Each counts per mode (`hasLength(2)`, and PF12's three-entry `initials`).
   - Run once: PF7, PF10.
   - PF14: the selection-mode `service-export` press is a third `toolbar-export` press, so `initials` stays `[pdf150, png300, png96]`.
   - PF7's last block: `service-print` and `service-export` became `toolbar-print` and `toolbar-export`.
9. **PF2 and PF23 were trimmed as the brief says.** PF2 keeps its design half and its last assertion (`dialogAnswer == PlanExportAnswer.initial`). PF23 drops its selection-mode block (S-22, 2b).

No Shared interface and no other task's contract changed.

## Self-review

- **The binding rules hold.**
  - An import without a manifest gets one through `ensureManifest` (X-6, M-X-6).
  - A host never touches `DraftDocument` except inside its own exporter.
  - Exporters run on a decoded copy: X-4 checks identity, that a later edit stays out of the copy, and that the copy is disposed.
- **The export rules hold.**
  - One flow at a time: X-2, PF7 and M-X-12.
  - No page where one is needed answers null: X-5.
  - A plan replaced during the export answers null: PF8 and M-X-10.
  - Pending input is settled first: X-8.
  - The dialog's answer is remembered: PF12, PF14, PF21, PF22.
  - Errors complete the `Future`: PF11 and X-6.
  - After `dispose` the answer is null or false: PF4 and PF18.
  - Host calls are not gated by the permissions; `EditorPageFlows` re-reads them (PF22 to PF24).
- **Ported assertions:** every `expect` in the ported tests is the source's, apart from the brief's name changes and the per-mode loops described above.

## Concerns (minor)

- **`printOnce` makes the copy before the font is awaited.** The source awaited the font first, then checked identity before making the bytes. The new code checks identity only after the bytes, which gives the same outcome (PF8's late-swap case passes).
- **`EditorPageFlows.export` on a page-less plan with a host page-free exporter.** The dialog still lists `plan.pdf` and `plan.png`. If the user picks one, `exportOnce` answers null silently, as the brief's code does. Task 20 may want to filter page exporters out of the dialog when there is no page.
- **`omittedOf` walks every tree node once per export.** This is not the frame path, and `typeIdOf` returns null for nested groups.
- **`import` is not under the one-flow guard (the brief does not put it there).** A `load` it triggers makes an in-flight export answer null, which is today's rule for a replaced plan.

## Spot-check (controller's request, re-run at 826ee7e1)

The three mutations were re-applied exactly as in the table above, the named test was run, and the file was reverted with `git checkout -- lib/src/export/page_flows.dart`.

- **M-X-4** (`exportOnce` passes `document: live`; `finally {}`), X-4:
  ```
  Expected: false
    Actual: <true>
    file:///…/packages/jet_cad_2d_plan/test/export/registry_test.dart line 133
  00:00 +0 -1: X-4 an exporter is handed a copy made when the export starts: … [E]
  diff-quiet exit 0
  ```
- **M-X-6** (`_load(text)`), X-6:
  ```
  PlanFormatException(noManifest): the plan carries no jetcad.manifest on its root
  Expected: false
    Actual: <true>
    file:///…/packages/jet_cad_2d_plan/test/export/registry_test.dart line 202
  00:00 +0 -1: X-6 import: a host importer's drawing without a manifest opens as plain geometry; … [E]
  diff-quiet exit 0
  ```
- **M-X-10** (`if (cancelled()) return null;` in `exportOnce`), PF8:
  ```
  Expected: null
    Actual: <Instance of 'PlanExport'>
    file:///…/packages/jet_cad_2d_plan/test/export/page_flows_test.dart line 273
  00:00 +0 -1: PF8 (T1-b) export of a plan replaced before its bytes: … [E]
  diff-quiet exit 0
  ```
- Afterwards, `git status --short` printed nothing (`status-lines: 0`). This append to the report is the only change, and it lives in the git-ignored `.superpowers/` directory.
