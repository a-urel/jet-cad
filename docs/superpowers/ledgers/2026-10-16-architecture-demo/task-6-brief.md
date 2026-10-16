### Task 6: Export and print

**Files:**
- Create: `lib/busy_wrappers.dart`
- Modify: `lib/document_host.dart` (`onExport`, `onExportDialog`,
  `printer`, `onPageFlowError`)
- Modify: `test/support/app_fakes.dart` (the recording printer, from the
  old tests)
- Create (port): `test/export/export_flow_test.dart`,
  `test/export/print_flow_test.dart`,
  `test/export/export_end_to_end_test.dart`,
  `test/export/export_font_test.dart` (EF1, EF2, EF9-EF12 per the audit)
- Create: `test/export/busy_test.dart` (N6)

**Interfaces:**
- Consumes: Task 1's `showPlanExportDialog`; Task 4's session.
- Produces:

```dart
/// The export dialog with the session busy while it is up (spec decision
/// 5): the library's own dialog, so the app sees the export in flight.
PlanExportDialog busyExportDialog(ValueNotifier<bool> busy,
        {PlanExportDialog dialog = showPlanExportDialog}) =>
    (context, initial, exporters) async {
      final outer = busy.value;
      busy.value = true;
      try {
        return await dialog(context, initial, exporters);
      } finally {
        if (!outer) busy.value = false;
      }
    };

/// [inner] with the session busy while the platform's print job runs.
final class BusyPagePrinter implements PagePrinter {
  BusyPagePrinter(this.busy, this.inner);

  final ValueNotifier<bool> busy;
  final PagePrinter inner;

  @override
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format) async {
    final outer = busy.value;
    busy.value = true;
    try {
      await inner.print(pdf, name, format);
    } finally {
      if (!outer) busy.value = false;
    }
  }
}
```

- [ ] **Step 1: The host's export write.** `onExport: (export) =>
  unawaited(_exportFlow(export))`; `_exportFlow` runs as a flow (busy),
  takes the kind from `export.name`'s extension (`pdf` → `FileKind.pdf`,
  `png` → `FileKind.png`; any other extension is an `ArgumentError` shown
  as `exportFailed`, since the library's built-ins make only pdf and
  png), asks `files.saveLocation(export.name,
  kind: kind)`, writes `export.bytes`; a throw shows `exportFailed`. A
  cancel writes nothing.

- [ ] **Step 2: Wire the wrappers and the error:** `onExportDialog:
  busyExportDialog(session.busy)`, `printer:
  BusyPagePrinter(session.busy, widget.printer)` (made once in
  `initState`, not per build), `onPageFlowError: (e) =>
  unawaited(_showError((w) => w.pageFlowFailed, e))`.

- [ ] **Step 3: Port the four export files** per their audit sections
  (PORT, SPLIT, COVERED, DROPPED as in Task 4 step 5). The SPLIT halves
  that assert "disabled while a flow runs" become "the callback does
  nothing while busy" (decision 5); their intent halves cite PF7.

- [ ] **Step 4: N6 (and Review Focus 3):**
  - N6-dialog: open the export dialog through the bar's Export button;
    while it is up, `session.busy` is true, `host.newFlow()` called
    through the editor's New button does nothing (no `replace-dialog`, the
    plan unchanged); dismiss; busy false.
  - N6-print: a fake printer that waits on a `Completer`; Print; while
    pending, Cmd+S does nothing (nothing written); complete; busy false.
  - N6-exit: while the export dialog is up, the exit request answers
    `AppExitResponse.cancel` with no second dialog.
  - Mutations: M-N6a pass the library's dialog directly (no wrapper) →
    N6-dialog red; M-N6b pass `widget.printer` directly → N6-print red.

- [ ] **Step 5:** Gates. **Commit** `feat(demo): export writes, print and the busy wrappers`, then `test(demo): export and print, ported; N6`.

---

