### Task 19: Export, import and print (spec P5 registries, P2 export rules)

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/export/registries.dart` (Task 8 created it with `PlanExporter`, `PlanImporter` and a three-field `PlanExportRequest`; this task extends it with the registries' other types, Step 4)
- Create: `packages/jet_cad_2d_plan/lib/src/export/builtin_exporters.dart` (`plan.pdf`, `plan.png`; port of `export_bytes.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/export/export_font.dart` (port: `loadExportFont`, `ExportFontCache`)
- Create: `packages/jet_cad_2d_plan/lib/src/export/page_printer.dart` (port, verbatim)
- Create: `packages/jet_cad_2d_plan/lib/src/export/page_flows.dart` (`PlanPageFlows`: the controller's export, print and import under one guard; port of `page_flows.dart`'s bodies and the controller's `_pageFlow`)
- Create: `packages/jet_cad_2d_plan/lib/src/export/export_dialog.dart` (port of `export_dialog.dart`, generic over the registry)
- Create: `packages/jet_cad_2d_plan/lib/src/export/editor_page_flows.dart` (`EditorPageFlows`: port of `PageFlows`, the view's dialogs and hooks; Task 20's bar uses it)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (`pageFlows`, `export`, `print`, `import`, `exporters`, `importers`; `dispose`)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (exports)
- Modify: `packages/jet_cad_2d_plan/pubspec.yaml` (`pdf`, `printing`, with `jet_cad_floor_plan`'s constraints; Task 6's pubspec leaves them to this task)
- Create (test support): `test/support/fake_page_printer.dart` (port), `test/support/export_plan.dart`, `test/support/recording_exporters.dart`, `test/support/flows_bar.dart`
- Test (new): `test/export/plan_export_types_test.dart` (X-1), `test/export/registry_test.dart` (X-2 … X-8), `test/export/export_dialog_test.dart` (X-9)
- Test (ported): `test/export/export_font_test.dart`, `test/export/page_flows_test.dart`
- Modify (test): `packages/jet_cad_2d_plan/test/controller/plan_controller_test.dart` (Task 8's C13: its `exporters` expectations include the built-ins, Step 8 item 5)

**Interfaces:**
- Consumes:
  - Shared interfaces: `PlanExporter`, `PlanImporter`, `PlanExport` (this task produces them as written there), `PlanController` (Task 8), `PlanPermissions` (`export`, `print`; Task 12), `ParametricCatalog.typeIdOf` (E1), `PlanType.exported` (Task 4), `ensureManifest` (Task 7), `PlanFormatException`, `PlanFormatCode` (Task 7).
  - The Flutter layer: `exportPagePdf`, `exportPagePng`, `ExportDpi` (`jet_cad_2d_flutter/lib/src/export/page_export.dart:37`, `:79`, `:113`), `FlutterTextMeasurer`.
  - The engine: `DraftDocumentCodec.encodeToString` / `decodeString(json, measurer:, registerComponents:, diagnostics:)` (as `floor_plan_controller.dart:1311-1316` calls it), `PageComponent.register`, `sheetWorldRect`.
  - The kit contract: `registerKitComponents`, `ManifestComponent`.
  - `markKit`, `addMark`, `addLineOn` (Task 18's test support).
  - From earlier tasks, the names in "Assumed from earlier tasks".
- Produces (exported from the barrel):
  - `abstract interface class PlanExporter { String get id; String get extension; String get mimeType; Future<Uint8List> export(PlanExportRequest request); }` (shared interfaces).
  - `abstract interface class PlanPageExporter implements PlanExporter {}` — an exporter that plots the page (listed in the Shared interfaces): the controller answers null for a page-less plan without calling it (X-5).
  - `abstract interface class PlanImporter { String get id; List<String> get extensions; Future<String> import(Uint8List bytes); }` (shared interfaces).
  - `final class PlanExport { const PlanExport({required Uint8List bytes, required String name, required String mimeType}); }` (shared interfaces; `name` is `<name>.<extension>`).
  - `final class PlanExportRequest { PlanExportRequest({required DraftDocument document, required PageComponent? page, required PlanExportChoice choice, required Set<Handle> omitted, required PlanExportFonts fonts}); }` (spec P5).
  - `enum PlanExportDpi { d96, d150, d300; int get value; }`.
  - `final class PlanExportChoice { const PlanExportChoice({PlanExportDpi dpi = PlanExportDpi.d150}); static const initial; copyWith; ==; toString }` (spec P2: "today's export choice without the format").
  - `final class PlanExportAnswer { const PlanExportAnswer({required String exporter, required PlanExportChoice choice}); static const initial; copyWith; ==; toString }` (the dialog's answer: the exporter's id names the format).
  - `abstract interface class PlanExportFonts { Future<Uint8List> get bytes; }`.
  - `typedef PlanExportDialog = Future<PlanExportAnswer?> Function(BuildContext context, PlanExportAnswer initial, List<PlanExporter> exporters);`
  - `abstract interface class PagePrinter`, `class PrintingPagePrinter` (ported unchanged).
  - On `PlanController`: `Future<PlanExport?> export(String exporterId, PlanExportChoice choice, {String? name})`, `Future<bool> print(PlanExportChoice choice, {PagePrinter? printer, String? name})`, `Future<void> import(String importerId, Uint8List bytes)`, `List<PlanExporter> get exporters`, `List<PlanImporter> get importers`.
- Produces (package-internal):
  - `PlanController.pageFlows` (`@internal`): `PlanPageFlows` — `ValueListenable<bool> ready`, `bool acquire()`, `void release()`, `PlanExportAnswer dialogAnswer`, `PlanExportFonts fonts`, `exportOnce`, `printOnce`, `exporterOf`, `omittedOf`.
  - `EditorPageFlows({required PlanController controller, required PageFlowSettings Function() settings, PageFlowHooks Function() hooks})` with `ready`, `canExport`, `Future<void> export(BuildContext)`, `Future<void> print(BuildContext)`, `dispose()`; `typedef PageFlowSettings`, `typedef PageFlowHooks`.
  - `showPlanExportDialog(BuildContext, PlanExportAnswer initial, List<PlanExporter> exporters)`, `bool isRasterExporter(PlanExporter)`.
  - `PlanPdfExporter`, `PlanPngExporter` (ids `plan.pdf`, `plan.png`), `exportPageOf`, `printPageFormat`.

Plan decision: **the exporter's document is a copy made when the export starts** (spec P5): the plan's engine JSON (`DraftDocumentCodec.encodeToString`) decoded with a `FlutterTextMeasurer` of its own and the controller's component registrations (`PageComponent`, the kit components, the catalog's types), as the planner's service copy is made (`floor_plan_controller.dart:1301-1316`). It is made synchronously, after the settle and before the first `await`, and disposed (its measurer cleared) once the exporter's bytes are back. The `omitted` set is computed on the copy (handles survive the round trip).

Plan decision: **the built-in exporters ignore the table colours.** `exportBytes` filled the coloured tables under the drawing (`export_bytes.dart:35-51`, plan colours spec PC-7); tables are 2b's. Without them the underlay is empty, and `exportPagePdf`/`exportPagePng` with an empty underlay write today's bytes (`page_export.dart:28-29`, `:107-108`).

Plan decision: **one flow at a time per controller, as today** (`floor_plan_controller.dart:1376-1388`): the guard (`ready`) belongs to `PlanPageFlows`, owned by the controller and shared by its views' `EditorPageFlows`, so a host's `export` while the bar's Print runs answers `null`. The remembered dialog answer is `pageFlows.dialogAnswer`; `controller.export` leaves it as it is (today's rule).

Plan decision: **the dialog lists the registry.** The format row has one segment per exporter, labelled by its extension in capitals (`PDF`, `PNG`, as today's literal labels, `export_dialog.dart:74-79`) and keyed `export-format-<id>`; the resolution row shows while the chosen exporter writes an image (`mimeType` starting `image/`), which is today's "PNG only" rule (`:85`) for any raster format a host adds.

Plan decision: **registry ids are unique.** The built-ins come first, the host's after them in its order; two exporters (or two importers) with one id are an `ArgumentError` naming `exporters` (or `importers`) when the controller is built. An unknown id given to `export` or `import` is an `ArgumentError` at once, before any flow runs (today's `exportPlan` threw its argument errors at once, `floor_plan_controller.dart:1344-1347`).

Plan decision: **host calls are not gated** (spec P2): `controller.export` and `controller.print` ignore `permissions.export` / `.print`; `EditorPageFlows` reads them after the dialog and after the bytes, as today's `exportAllowed`/`printAllowed` read the capabilities (`floor_plan_view.dart`'s `_flowsFor`; `page_flows.dart:146-153`).

- [ ] **Step 0: The dependencies.** In `packages/jet_cad_2d_plan/pubspec.yaml`, add under `dependencies:`, in alphabetical place, the two lines of `packages/jet_cad_floor_plan/pubspec.yaml`: `pdf: ^3.13.1` and `printing: ^5.15.1`. Run `cd packages/jet_cad_2d_plan && flutter pub get` (expected: it resolves), then from the root `git status --short`: ` M packages/jet_cad_2d_plan/pubspec.yaml` and possibly rewritten `analysis_options.yaml` files of other packages, which are never staged (restore them with `git checkout --`).

- [ ] **Step 1: Test support.** Create `packages/jet_cad_2d_plan/test/support/fake_page_printer.dart`: copy `packages/jet_cad_floor_plan/test/support/fake_page_printer.dart:1-45` verbatim, with the import of `:8` becoming `import 'package:jet_cad_2d_plan/src/export/page_printer.dart';`.

Create `packages/jet_cad_2d_plan/test/support/export_plan.dart`:

```dart
// The export fixture: a plan on the default page with, around the sheet's
// centre (not the origin), two marks turned 0.4 and -1.1 rad and a line,
// saved by a controller of the given kits; and the same plan without its
// page.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'mark_kit.dart';

String exportPlanJson({List<PlanKit>? kits, bool page = true}) {
  final scratch = PlanController(kits: kits ?? [markKit()]);
  final doc = scratch.document;
  final root = doc.rootHandle;
  final sheet = sheetWorldRect(doc.components.get<PageComponent>(root)!);
  final cx = (sheet.minX + sheet.maxX) / 2, cy = (sheet.minY + sheet.maxY) / 2;
  Transform2 put(double dx, double dy, double turn) =>
      Transform2.translation(cx + dx, cy + dy)
          .multiply(Transform2.rotation(turn));
  addMark(doc, ReservedHandles.layerZero,
      at: put(-2600.5, 900.25, 0.4), size: 700.5);
  addMark(doc, ReservedHandles.layerZero,
      at: put(2100.25, -700.5, -1.1), size: 520.25);
  doc.commands.execute(addDrafted(
      doc,
      EntityKind.line,
      linePayload(Vector2(cx - 3900.5, cy - 2100.25),
          Vector2(cx + 3300.75, cy + 1800.5)),
      layer: ReservedHandles.layerZero));
  if (!page) {
    doc.commands.execute(SetComponentCommand<PageComponent>(root, null));
  }
  final json = scratch.save();
  scratch.dispose();
  return json;
}
```

Create `packages/jet_cad_2d_plan/test/support/recording_exporters.dart`:

```dart
// A host's exporter and importer for tests: each records what it was
// handed, can fail once, and (the exporter) can hold its bytes until the
// test lets them go.
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';

class RecordingExporter implements PlanExporter {
  RecordingExporter(this.id, this.extension, this.mimeType);

  @override
  final String id;
  @override
  final String extension;
  @override
  final String mimeType;

  final List<PlanExportRequest> requests = [];

  /// Each request's document as the codec writes it, read on arrival (the
  /// copy is disposed once the bytes are back).
  final List<String> seen = [];

  /// Thrown by the next call, then cleared.
  Object? failNext;

  /// While true, each call waits on a completer added to [held].
  bool hold = false;
  final List<Completer<void>> held = [];

  @override
  Future<Uint8List> export(PlanExportRequest request) async {
    requests.add(request);
    seen.add(DraftDocumentCodec.encodeToString(request.document));
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    if (hold) {
      final open = Completer<void>();
      held.add(open);
      await open.future;
    }
    return Uint8List.fromList(utf8.encode('$id ${request.omitted.length}'));
  }
}

/// A host exporter that plots the page.
class RecordingPageExporter extends RecordingExporter
    implements PlanPageExporter {
  RecordingPageExporter(super.id, super.extension, super.mimeType);
}

class TextImporter implements PlanImporter {
  TextImporter(this.id, {this.text = ''});

  @override
  final String id;

  @override
  List<String> get extensions => const ['json'];

  /// What the next import answers.
  String text;

  /// Thrown by the next call, then cleared.
  Object? failNext;

  final List<Uint8List> asked = [];

  @override
  Future<String> import(Uint8List bytes) async {
    asked.add(bytes);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    return text;
  }
}
```

Create `packages/jet_cad_2d_plan/test/support/flows_bar.dart` (the editor bar's Export and Print as Task 20's `PlanEditorBar` builds them, so the ported view-level tests run before the editor exists):

```dart
// The editor bar's two page buttons over EditorPageFlows, as Task 20's
// PlanEditorBar has them: Export (`toolbar-export`) only with onExport and
// while permissions.export is on; Print (`toolbar-print`) while
// permissions.print is on; each enabled while the controller's flows are
// ready. The flows read this widget's fields at each call.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/export/editor_page_flows.dart';
import 'package:jet_cad_2d_plan/src/export/export_dialog.dart';
import 'package:jet_cad_2d_plan/src/export/page_printer.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';

class FlowsBar extends StatefulWidget {
  const FlowsBar(
      {super.key,
      required this.controller,
      this.onExport,
      this.printer,
      this.exportName = 'plan',
      this.onExportDialog,
      this.onPageFlowError});

  final PlanController controller;
  final void Function(PlanExport export)? onExport;
  final PagePrinter? printer;
  final String exportName;
  final PlanExportDialog? onExportDialog;
  final void Function(Object error)? onPageFlowError;

  @override
  State<FlowsBar> createState() => FlowsBarState();
}

class FlowsBarState extends State<FlowsBar> {
  late EditorPageFlows flows = _flowsFor(widget.controller);

  EditorPageFlows _flowsFor(PlanController c) => EditorPageFlows(
        controller: c,
        settings: () => (
          onExport: widget.onExport,
          printer: widget.printer ?? const PrintingPagePrinter(),
          exportName: widget.exportName,
        ),
        hooks: () => (
          exportDialog: widget.onExportDialog,
          onError: widget.onPageFlowError,
        ),
      );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(FlowsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      flows.dispose();
      flows = _flowsFor(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    flows.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Widget _button(String key, IconData icon, VoidCallback run) =>
      ValueListenableBuilder<bool>(
        valueListenable: flows.ready,
        builder: (_, ready, __) => IconButton(
            key: Key(key), icon: Icon(icon), onPressed: ready ? run : null),
      );

  @override
  Widget build(BuildContext context) {
    final permissions = widget.controller.permissions;
    return Material(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (flows.canExport && permissions.export)
          _button('toolbar-export', Icons.ios_share_outlined,
              () => unawaited(flows.export(context))),
        if (permissions.print)
          _button('toolbar-print', Icons.print_outlined,
              () => unawaited(flows.print(context))),
      ]),
    );
  }
}
```

- [ ] **Step 2: The new tests (they fail first).** Create `packages/jet_cad_2d_plan/test/export/plan_export_types_test.dart`:

```dart
// Spec P2 and P5: the export choice without the format, the dialog's
// answer naming the exporter, and the resolutions.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';

void main() {
  test(
      'X-1 the choice and the answer: ==, hashCode, copyWith, toString; the '
      'resolutions in order', () {
    const initial = PlanExportChoice.initial;
    expect(initial.dpi, PlanExportDpi.d150);
    expect(initial.toString(), 'PlanExportChoice(150 dpi)');
    expect(PlanExportDpi.values.map((d) => d.value), [96, 150, 300]);
    final d96 = initial.copyWith(dpi: PlanExportDpi.d96);
    // M-X-1a: PlanExportChoice.== ignores dpi.
    expect(d96 == initial, isFalse);
    expect(initial.copyWith(), initial);
    expect(const PlanExportChoice(dpi: PlanExportDpi.d150), initial);
    expect(initial.hashCode == d96.hashCode, isFalse);

    const answer = PlanExportAnswer.initial;
    expect(answer.exporter, 'plan.pdf');
    expect(answer.choice, initial);
    expect(answer.toString(), 'PlanExportAnswer(plan.pdf, 150 dpi)');
    final png = answer.copyWith(exporter: 'plan.png');
    final fine =
        answer.copyWith(choice: const PlanExportChoice(dpi: PlanExportDpi.d300));
    expect(png.choice, initial, reason: 'choice kept');
    expect(fine.exporter, 'plan.pdf', reason: 'exporter kept');
    // M-X-1b: PlanExportAnswer.== ignores the exporter.
    expect(png == answer, isFalse);
    expect(fine == answer, isFalse);
    expect(png == fine, isFalse);
    expect(answer.copyWith(), answer);
    expect(
        const PlanExportAnswer(
            exporter: 'plan.png', choice: PlanExportChoice.initial),
        png);
    expect(png.hashCode == answer.hashCode, isFalse);
  });
}
```

Create `packages/jet_cad_2d_plan/test/export/registry_test.dart`:

```dart
// Spec P5 (the registries, the copy, omitted types, import) and P2 (the
// export rules: a page where needed, pending input settled first).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ExportDpi, exportPagePng;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/export/builtin_exporters.dart';
import 'package:jet_cad_2d_plan/src/export/page_flows.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';
import 'package:jet_cad_2d_plan/src/file/plan_format_exception.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/export_plan.dart';
import '../support/fake_page_printer.dart';
import '../support/layer_plan.dart' show addLineOn;
import '../support/mark_kit.dart';
import '../support/recording_exporters.dart';

/// Flows over [doc] alone, for the registry's own rules.
PlanPageFlows flowsOver(DraftDocument doc,
        {List<PlanExporter> exporters = const [],
        List<PlanImporter> importers = const []}) =>
    PlanPageFlows(
        exporters: exporters,
        importers: importers,
        unexported: const {},
        document: () => doc,
        catalog: ParametricCatalog.new,
        settle: () {},
        load: (_) {});

void main() {
  testWidgets(
      'X-2 the registry: the built-ins first, then the host\'s in its order; '
      'one id twice is an ArgumentError naming the list; an unknown id is an '
      'ArgumentError at once, before any flow', (tester) async {
    final dxf = RecordingExporter('acme.dxf', 'dxf', 'image/vnd.dxf');
    final svg = RecordingExporter('acme.svg', 'svg', 'image/svg+xml');
    final c = PlanController(
        kits: const [],
        exporters: [dxf, svg],
        importers: [TextImporter('acme.json')]);
    addTearDown(c.dispose);
    expect([for (final e in c.exporters) e.id],
        ['plan.pdf', 'plan.png', 'acme.dxf', 'acme.svg']);
    expect([for (final i in c.importers) i.id], ['acme.json']);

    final doc = DraftDocument.empty();
    for (final (exporters, importers, name) in [
      ([RecordingExporter('plan.pdf', 'pdf', 'application/pdf')],
          <PlanImporter>[], 'exporters'),
      ([dxf, dxf], <PlanImporter>[], 'exporters'),
      (<PlanExporter>[], [TextImporter('a.b'), TextImporter('a.b')],
          'importers'),
    ]) {
      // M-X-2: drop PlanPageFlows' uniqueness checks.
      expect(
          () => flowsOver(doc, exporters: exporters, importers: importers),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', name)));
    }

    expect(() => c.export('acme.nope', PlanExportChoice.initial),
        throwsA(isA<ArgumentError>()));
    expect(() => c.import('acme.nope', Uint8List(0)),
        throwsA(isA<ArgumentError>()));
    expect(c.pageFlows.ready.value, isTrue, reason: 'no flow started');
  });

  testWidgets(
      'X-3 plan.png leaves out the objects of a type with exported: false: '
      'its bytes are the page drawn without them; with the type exported they '
      'are drawn', (tester) async {
    final hidden = PlanController(
        kits: [markKit(exported: false)],
        json: exportPlanJson(kits: [markKit(exported: false)]));
    addTearDown(hidden.dispose);
    final shown =
        PlanController(kits: [markKit()], json: exportPlanJson());
    addTearDown(shown.dispose);
    final doc = hidden.document;
    final marks = hidden.catalog.objectsOf<MarkCross>(doc);
    expect(marks, hasLength(2), reason: 'premise');
    final page = exportPageOf(doc)!;
    const d96 = PlanExportChoice(dpi: PlanExportDpi.d96);

    final without = (await tester.runAsync(() => exportPagePng(
        document: doc,
        page: page,
        dpi: ExportDpi.d96,
        omitOwners: marks.toSet())))!;
    final whole = (await tester.runAsync(
        () => exportPagePng(document: doc, page: page, dpi: ExportDpi.d96)))!;
    expect(without, isNot(whole), reason: 'premise: the marks are on the sheet');

    final got = (await tester.runAsync(() => hidden.export('plan.png', d96)))!;
    // M-X-3a: `omittedOf` answers the empty set.
    expect(got.bytes, without);
    expect(got.name, 'plan.png');
    expect(got.mimeType, 'image/png');
    final drawn = (await tester.runAsync(() => shown.export('plan.png', d96)))!;
    // M-X-3b: `unexported` lists every type, exported or not.
    expect(drawn.bytes, whole);
  });

  testWidgets(
      'X-4 an exporter is handed a copy made when the export starts: '
      'another document with the plan\'s bytes, which an edit made while it '
      'works does not reach, disposed once the bytes are back', (tester) async {
    final acme = RecordingExporter('acme.json', 'json', 'application/json')
      ..hold = true;
    final c = PlanController(
        kits: [markKit()], json: exportPlanJson(), exporters: [acme]);
    addTearDown(c.dispose);
    final start = DraftDocumentCodec.encodeToString(c.document);
    late Future<PlanExport?> pending;
    await tester.runAsync(() async {
      pending = c.export('acme.json', PlanExportChoice.initial, name: 'salon');
      while (acme.held.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final request = acme.requests.single;
    // M-X-4: the request carries the controller's own document.
    expect(identical(request.document, c.document), isFalse);
    expect(acme.seen.single, start);
    addLineOn(c.document, ReservedHandles.layerZero, 900.5, 300.25, 1800.75,
        650.5);
    expect(DraftDocumentCodec.encodeToString(request.document), start,
        reason: 'the edit is not in the copy');
    acme.held.single.complete();
    final export = (await tester.runAsync(() => pending))!;
    expect(export.name, 'salon.json');
    expect(export.mimeType, 'application/json');
    expect(request.document.commands.isDisposed, isTrue,
        reason: 'the copy is gone');
  });

  testWidgets(
      'X-5 a plan without a page: a page exporter answers null and is never '
      'called, plan.png too, print answers false; an exporter that needs no '
      'page is handed page null and its bytes come back', (tester) async {
    final plot = RecordingPageExporter('acme.plot', 'plt', 'application/vnd.hp-hpgl');
    final drawing = RecordingExporter('acme.json', 'json', 'application/json');
    final c = PlanController(
        kits: [markKit()],
        json: exportPlanJson(page: false),
        exporters: [plot, drawing]);
    addTearDown(c.dispose);
    expect(exportPageOf(c.document), isNull, reason: 'premise');
    // M-X-5: `exportOnce` drops its page test.
    expect(
        await tester
            .runAsync(() => c.export('acme.plot', PlanExportChoice.initial)),
        isNull);
    expect(plot.requests, isEmpty);
    expect(
        await tester
            .runAsync(() => c.export('plan.png', PlanExportChoice.initial)),
        isNull);
    final printer = FakePagePrinter();
    expect(
        await tester.runAsync(
            () => c.print(PlanExportChoice.initial, printer: printer)),
        isFalse);
    expect(printer.calls, isEmpty);
    final e = (await tester
        .runAsync(() => c.export('acme.json', PlanExportChoice.initial)))!;
    expect(drawing.requests.single.page, isNull);
    expect(e.name, 'plan.json');
  });

  testWidgets(
      'X-6 import: a host importer\'s drawing without a manifest opens as '
      'plain geometry; an importer\'s error and a plan load refuses each '
      'complete the Future and keep the plan', (tester) async {
    final drawing = DraftDocument.empty();
    PageComponent.register(drawing.components);
    final add = addDrafted(drawing, EntityKind.line,
        linePayload(Vector2(-4200.5, 3100.25), Vector2(-1800.75, 5200.5)),
        layer: ReservedHandles.layerZero);
    drawing.commands.execute(add);
    final importer = TextImporter('acme.json',
        text: DraftDocumentCodec.encodeToString(drawing));
    final c = PlanController(
        kits: [markKit()], json: exportPlanJson(), importers: [importer]);
    addTearDown(c.dispose);
    final first = c.document;
    await tester.runAsync(
        () => c.import('acme.json', Uint8List.fromList([7, 1, 9])));
    // M-X-6: `_import` loads the text without `ensureManifest`: the load
    // refuses it (noManifest) and the plan is kept.
    expect(identical(c.document, first), isFalse, reason: 'a new plan');
    expect(c.document.entities.slotOf(add.record.handle), isNotNull);
    expect(c.missingKits, isEmpty);
    expect(importer.asked.single, [7, 1, 9]);

    final kept = c.document;
    importer.failNext = StateError('unreadable');
    Object? thrown;
    await tester.runAsync(() async {
      try {
        await c.import('acme.json', Uint8List(0));
      } catch (e) {
        thrown = e;
      }
    });
    expect(thrown, isA<StateError>());
    expect(identical(c.document, kept), isTrue);

    // A plan of a format above 1 (spec P4): load refuses it.
    final future = DraftDocument.empty();
    registerKitComponents(future.components);
    future.commands.execute(SetComponentCommand<ManifestComponent>(
        future.rootHandle, ManifestComponent(format: 2, kits: const {})));
    importer.text = DraftDocumentCodec.encodeToString(future);
    thrown = null;
    await tester.runAsync(() async {
      try {
        await c.import('acme.json', Uint8List(0));
      } catch (e) {
        thrown = e;
      }
    });
    expect(thrown, isA<PlanFormatException>());
    expect((thrown! as PlanFormatException).code, PlanFormatCode.formatTooNew);
    expect(identical(c.document, kept), isTrue);
  });

  testWidgets(
      'X-7 print hands the printer one PDF of the page, named, at the page\'s '
      'size in pt', (tester) async {
    final c = PlanController(kits: [markKit()], json: exportPlanJson());
    addTearDown(c.dispose);
    final printer = FakePagePrinter();
    expect(
        await tester.runAsync(() =>
            c.print(PlanExportChoice.initial, printer: printer, name: 'teras')),
        isTrue);
    final call = printer.calls.single;
    final page = exportPageOf(c.document)!;
    expect(call.name, 'teras');
    expect(call.format.width, closeTo(page.effectiveWidthMm * 72 / 25.4, 1e-9));
    expect(
        call.format.height, closeTo(page.effectiveHeightMm * 72 / 25.4, 1e-9));
    // M-X-7: printOnce hands the printer the PNG exporter's bytes.
    expect(call.pdf.sublist(0, 4), '%PDF'.codeUnits);
  });

  testWidgets(
      'X-8 export settles pending input before it copies the plan: what a '
      'settler commits is in the exporter\'s copy', (tester) async {
    final acme = RecordingExporter('acme.json', 'json', 'application/json');
    final c = PlanController(
        kits: [markKit()], json: exportPlanJson(), exporters: [acme]);
    addTearDown(c.dispose);
    final before = DraftDocumentCodec.encodeToString(c.document);
    var runs = 0;
    final release = c.registerSettle(() {
      if (runs++ == 0) {
        addLineOn(c.document, ReservedHandles.layerZero, 400.5, 220.25,
            1300.75, 980.5);
      }
    });
    addTearDown(release);
    await tester.runAsync(() => c.export('acme.json', PlanExportChoice.initial));
    // M-X-8: `guarded` does not call `_settle()`.
    expect(runs, greaterThan(0));
    expect(acme.seen.single, isNot(before));
    expect(acme.seen.single, DraftDocumentCodec.encodeToString(c.document));
  });
}
```

Create `packages/jet_cad_2d_plan/test/export/export_dialog_test.dart`:

```dart
// Spec P5: the export dialog lists the registry; the resolution is asked
// for an image format only; OK answers the choice, Cancel null.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/export/builtin_exporters.dart';
import 'package:jet_cad_2d_plan/src/export/export_dialog.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';

import '../support/recording_exporters.dart';

Finder byKey(String k) => find.byKey(Key(k));

void main() {
  testWidgets(
      'X-9 the dialog lists every exporter by its extension, asks the '
      'resolution only for an image format, answers the choice on OK and '
      'null on Cancel', (tester) async {
    final exporters = <PlanExporter>[
      const PlanPdfExporter(),
      const PlanPngExporter(),
      RecordingExporter('acme.json', 'json', 'application/json'),
    ];
    PlanExportAnswer? got;
    var done = false;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                key: const Key('open'),
                onPressed: () async {
                  got = await showPlanExportDialog(
                      context, PlanExportAnswer.initial, exporters);
                  done = true;
                },
                child: const Text('open')))));
    await tester.tap(byKey('open'));
    await tester.pumpAndSettle();
    for (final e in exporters) {
      expect(byKey('export-format-${e.id}'), findsOneWidget, reason: e.id);
    }
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(byKey('export-dpi'), findsNothing, reason: 'a PDF has none');
    await tester.tap(byKey('export-format-plan.png'));
    await tester.pump();
    expect(byKey('export-dpi'), findsOneWidget);
    await tester.tap(byKey('export-dpi-300'));
    await tester.pump();
    await tester.tap(byKey('export-format-acme.json'));
    await tester.pump();
    // M-X-9: the resolution row shown for every exporter.
    expect(byKey('export-dpi'), findsNothing);
    await tester.tap(byKey('export-ok'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(
        got,
        const PlanExportAnswer(
            exporter: 'acme.json',
            choice: PlanExportChoice(dpi: PlanExportDpi.d300)));

    done = false;
    await tester.tap(byKey('open'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SegmentedButton<String>>(byKey('export-format')).selected,
        {'plan.pdf'},
        reason: 'the initial answer it was given');
    await tester.tap(byKey('export-cancel'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(got, isNull);
  });
}
```

Run: `cd packages/jet_cad_2d_plan && flutter test test/export`. Expected: compilation errors (`PlanExportChoice`, `PlanExportAnswer`, `PlanPageExporter` and the flows are not defined yet).

- [ ] **Step 3: The ported tests.** Every `expect` is unchanged apart from the spec's renaming of the export value types, which is a name, not an assertion: `fileName` → `name`; a `FloorPlanExportChoice(format: f, dpi: d)` → the exporter id `plan.<f.name>` with `PlanExportChoice(dpi: <d>)`; `ExportChoice.initial` (the remembered dialog choice) → `PlanExportAnswer.initial`; `ExportChoice(format: png, dpi: d300)` → `PlanExportAnswer(exporter: 'plan.png', choice: PlanExportChoice(dpi: PlanExportDpi.d300))`.

**`test/export/export_font_test.dart`** — from `apps/floor_planner/test/export/export_font_test.dart`: EF4 and EF5 (`:79-92`), EF7 and EF8 (`:113-141`). Not ported: EF1-EF3 and EF9-EF12 (the app's files, `main()` and pubspec), EF6 (`registerFontLicences`, Task 9's). Adaptations: imports become `package:jet_cad_2d_plan/src/export/export_font.dart` and Task 9's fonts file (for `kPlanFontAsset`); `vendoredDir` (`:17-18`) becomes `'../jet_cad_2d_flutter/test/golden/fonts'` (the test runs in `packages/jet_cad_2d_plan`); `kExportFontAsset` becomes `kPlanFontAsset`; `_MapBundle` (`:26-39`) and `vendoredFont()` (`:21-22`) are copied verbatim.

**`test/export/page_flows_test.dart`** — from `packages/jet_cad_floor_plan/test/host/page_flows_test.dart`. Ported: PF2 (`:203-230`: its design-mode half `:206-215` and its last assertion `:227-228`; the selection-mode half `:217-226`, the service copy moved, is 2b's), PF3 (`:232-264`), PF4 (`:266-280`), PF7 (`:342-398`, the design mode), PF8 (`:400-448`), PF9 (`:450-491`, the design mode), PF10 (`:493-518`, the design mode), PF11 (`:520-541`), PF12 (`:543-571`, the design mode), PF13 (`:573-617`), PF14 (`:619-641`, the design mode), PF15 (`:643-660`), PF16 (`:665-717`), PF18 (`:739-754`), PF19 (`:756-773`), PF20 (`:775-788`), PF21 (`:790-821`), PF22 (`:856-890`, with `pumpCaps` `:823-855`), PF23 (`:892-936`, without its last block "The selection mode exports under the same refusal", S-22, 2b), PF24 (`:938-976`). Task 9 routed `floor_plan_theme_test.dart`'s S-12 (the export dialog under a local Theme, the view's theme not reaching it) here; it needs `PlanEditor(theme:)`, so it lands as Task 20's ED-7. Not ported: PF1 (`:163-201`, the choice type with a format; its successor is X-1), PF5 and PF6 (`:282-340`, the chords; Task 20 ports them through `PlanEditor`), PF17 (`:719-737`, a table number field, 2b; its rule is X-8). Adaptations:
- Imports `:17-33`: drop every `jet_cad_floor_plan` import, `../tables/table_fixture.dart` and `embedding_fixture.dart`; add `package:jet_cad_2d_plan/src/controller/plan_controller.dart`, `…/controller/permissions.dart` (Task 12), `…/export/builtin_exporters.dart`, `…/export/editor_page_flows.dart`, `…/export/registries.dart`, Task 9's fonts file, and `../support/export_plan.dart`, `../support/fake_page_printer.dart`, `../support/flows_bar.dart`, `../support/mark_kit.dart`.
- The consts `pdf150`, `png96`, `png300` (`:59-63`) become `PlanExportAnswer`s (`PlanExportAnswer.initial`; `('plan.png', d96)`; `('plan.png', d300)`), and a helper `Future<PlanExport?> exportAs(PlanController c, PlanExportAnswer a, {String? name}) => c.export(a.exporter, a.choice, name: name);` replaces each `c.exportPlan(choice, name: …)`; `c.printPlan(printer: p, name: n)` becomes `c.print(PlanExportChoice.initial, printer: p, name: n)`.
- `RecordingHook` (`:75-93`) answers a `PlanExportAnswer?`, records each `initial`, and its `call` takes `(BuildContext context, PlanExportAnswer initial, List<PlanExporter> exporters)`.
- `pumpFlows` (`:95-123`): `PlanController(kits: [markKit()], json: json ?? exportPlanJson())` in place of `FloorPlanController(json: json ?? embeddingPlanJson())`, and `FlowsBar(controller: c, onExport:, printer:, exportName:, onExportDialog: hook?.call, onPageFlowError: onError)` in place of `FloorPlanView(…)`; the camera line (`c.cameraController.value = embeddingCamera()`) is dropped (an export reads the page, never the camera, `page_export.dart:20-21`).
- `pagePixels`, `mediaBox`, `pngSize`, `letRun` are copied verbatim, with `c.activeDocument` → `c.document`.
- Every `c.activeDocument` → `c.document`; `c.pageFlowReady` → `c.pageFlows.ready`; `c.exportChoice` → `c.pageFlows.dialogAnswer`; `c.exportFont.bytes` → `c.pageFlows.fonts.bytes`; `FloorPlanExport` → `PlanExport`; `byKey('service-…')` and `byKey('toolbar-…')` both become the `FlowsBar`'s `toolbar-export` / `toolbar-print`.
- The mode loops (`for (final mode in FloorPlanMode.values)`) run their body twice in the design mode where the source counted one call per mode (PF3's `hasLength(2)`, PF9's `hasLength(2)`), and once where it did not count; `toMode` is deleted.
- PF3's page-less plan (`FloorPlanController(json: DraftDocumentCodec.encodeToString(plan()))`, `:236-237`) is `PlanController(kits: [markKit()], json: exportPlanJson(page: false))`.
- PF8 and PF21: a mode switch or `resetLayout` that replaced the plan shown becomes `c.load(exportPlanJson())`, which replaces it (spec P2: "a plan replaced while the bytes are being made").
- PF13: the reference bytes (`:595-599`) are `const PlanPngExporter().export(PlanExportRequest(document: document, page: page, choice: PlanExportChoice(dpi: <the dpi>), omitted: const {}, fonts: c.pageFlows.fonts))` in place of `exportBytes(…)`; the loop runs over `('plan.pdf', 'plan.png') × PlanExportDpi.values`.
- PF19: `PageFlows(controller: c, settings: …)` becomes `EditorPageFlows(controller: c, settings: …)`, and the element is `find.byType(FlowsBar)`.
- PF22-PF24 (`pumpCaps`): the capabilities notifier becomes the controller's `permissions` (`c.permissions = PlanPermissions.full.copyWith(export: false)` or `print: false`, then `PlanPermissions.full`), and the view is `FlowsBar` (which hides a button whose permission is off, as the source's bar did); `kExportFontAsset` becomes `kPlanFontAsset`.

Run: `cd packages/jet_cad_2d_plan && flutter test test/export`. Expected: compilation errors (nothing of `lib/src/export/` exists yet).

- [ ] **Step 4: The types.** Replace the whole of `packages/jet_cad_2d_plan/lib/src/export/registries.dart` (Task 8's file: its `PlanExporter` and `PlanImporter` keep their members; `PlanExportRequest` gains `choice` and `fonts`; the rest is new) with:

```dart
// Spec P5: the export and import registries' types. A host adds its own
// exporters and importers through PlanController(exporters:, importers:);
// the plan library builds in `plan.pdf` and `plan.png`.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

/// What makes an export's bytes. Its [id] names the format in the dialog's
/// answer and in `PlanController.export`: the built-ins are `plan.pdf` and
/// `plan.png`, a host's its own (`acme.dxf`).
abstract interface class PlanExporter {
  String get id;

  /// The file name's extension, without the dot.
  String get extension;

  /// The bytes' MIME type.
  String get mimeType;

  /// The bytes of [request]'s document. An error completes the export's
  /// `Future` with it.
  Future<Uint8List> export(PlanExportRequest request);
}

/// An exporter that plots the plan's page (the built-ins do): for a plan
/// without a page the controller answers null and never calls it, and its
/// request's page is never null (spec P2: "a plan with no page where the
/// choice needs one").
abstract interface class PlanPageExporter implements PlanExporter {}

/// What turns a file into a plan's text (spec P5, decision 4). A text
/// without a manifest gets an empty one before it is loaded, so an imported
/// drawing opens as plain geometry.
abstract interface class PlanImporter {
  String get id;

  /// The file extensions it reads, without the dot.
  List<String> get extensions;

  Future<String> import(Uint8List bytes);
}

/// The resolutions an image export offers.
enum PlanExportDpi {
  d96,
  d150,
  d300;

  /// Dots per inch.
  int get value => switch (this) {
        PlanExportDpi.d96 => 96,
        PlanExportDpi.d150 => 150,
        PlanExportDpi.d300 => 300,
      };
}

/// An export's settings: today's export choice without the format, which
/// the exporter's id now names (spec P2). A PDF ignores the resolution.
@immutable
final class PlanExportChoice {
  const PlanExportChoice({this.dpi = PlanExportDpi.d150});

  /// The first choice of a controller's life: 150 dpi.
  static const PlanExportChoice initial = PlanExportChoice();

  final PlanExportDpi dpi;

  PlanExportChoice copyWith({PlanExportDpi? dpi}) =>
      PlanExportChoice(dpi: dpi ?? this.dpi);

  @override
  bool operator ==(Object other) =>
      other is PlanExportChoice && other.dpi == dpi;

  @override
  int get hashCode => dpi.hashCode;

  @override
  String toString() => 'PlanExportChoice(${dpi.value} dpi)';
}

/// The export dialog's answer, the host's dialog's too: the exporter's id
/// and the choice. Remembered per controller as the next dialog's initial.
@immutable
final class PlanExportAnswer {
  const PlanExportAnswer({required this.exporter, required this.choice});

  /// The first answer of a controller's life: PDF, 150 dpi, as today's
  /// dialog's.
  static const PlanExportAnswer initial =
      PlanExportAnswer(exporter: 'plan.pdf', choice: PlanExportChoice.initial);

  final String exporter;
  final PlanExportChoice choice;

  PlanExportAnswer copyWith({String? exporter, PlanExportChoice? choice}) =>
      PlanExportAnswer(
          exporter: exporter ?? this.exporter, choice: choice ?? this.choice);

  @override
  bool operator ==(Object other) =>
      other is PlanExportAnswer &&
      other.exporter == exporter &&
      other.choice == choice;

  @override
  int get hashCode => Object.hash(exporter, choice);

  @override
  String toString() => 'PlanExportAnswer($exporter, ${choice.dpi.value} dpi)';
}

/// The plan's fonts, for an exporter that embeds text.
abstract interface class PlanExportFonts {
  /// The bundled Roboto's bytes: the face the screen lays text out in.
  Future<Uint8List> get bytes;
}

/// What an exporter is handed (spec P5).
final class PlanExportRequest {
  PlanExportRequest({
    required this.document,
    required this.page,
    required this.choice,
    required Set<Handle> omitted,
    required this.fonts,
  }) : omitted = Set.unmodifiable(omitted);

  /// A copy of the plan made when the export started, so edits made while
  /// the export runs cannot race with it. Disposed once the bytes are back:
  /// keep nothing of it.
  final DraftDocument document;

  /// The plan's page, or null for a plan without one (never null for a
  /// [PlanPageExporter]).
  final PageComponent? page;

  final PlanExportChoice choice;

  /// The objects of types with `exported: false`: their leaves are not
  /// drawn.
  final Set<Handle> omitted;

  final PlanExportFonts fonts;
}

/// An export's bytes, its file name and its MIME type.
@immutable
final class PlanExport {
  const PlanExport(
      {required this.bytes, required this.name, required this.mimeType});

  final Uint8List bytes;

  /// `<name>.<extension>`.
  final String name;

  final String mimeType;
}
```

- [ ] **Step 5: The printer and the font.** Create `lib/src/export/page_printer.dart`: copy `packages/jet_cad_floor_plan/lib/src/export/page_printer.dart:1-31` verbatim, with one header line added: `// Ported from jet_cad_floor_plan/lib/src/export/page_printer.dart.`

Create `lib/src/export/export_font.dart`: copy `packages/jet_cad_floor_plan/lib/src/export/export_font.dart:1-61` with these adaptations:
  1. `:8-20` (the two asset-key constants) are deleted: the font and its licence are Task 9's (`kPlanFontAsset`, `registerFontLicences`); import Task 9's fonts file for `kPlanFontAsset`.
  2. `:28-37` (`registerFontLicences`) are deleted (Task 9 ported it).
  3. `loadExportFont` (`:22-26`) reads `kPlanFontAsset` in place of `kExportFontAsset`.
  4. `class ExportFontCache` (`:42`) becomes `class ExportFontCache implements PlanExportFonts`, with `@override` on `bytes` (`:51`), and the file imports `registries.dart`.
  5. The header comment says "Ported from jet_cad_floor_plan/lib/src/export/export_font.dart: the font the PDF export embeds, read once per controller."

- [ ] **Step 6: The built-in exporters.** Create `lib/src/export/builtin_exporters.dart`:

```dart
// Spec P5: the built-in exporters, `plan.pdf` and `plan.png`, and the page
// helpers the flows read. Ported from
// jet_cad_floor_plan/lib/src/export/export_bytes.dart without the table
// colours (2b): an empty underlay writes today's bytes.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ExportDpi, exportPagePdf, exportPagePng;
import 'package:pdf/pdf.dart' show PdfPageFormat;

import 'registries.dart';

/// The page [document]'s root carries, or null when it has none. Read from
/// the document, never from the screen (export_bytes.dart:18-24).
PageComponent? exportPageOf(DraftDocument document) =>
    document.components.isRegistered<PageComponent>()
        ? document.components.get<PageComponent>(document.rootHandle)
        : null;

/// [page]'s paper in pt, as laid out: the size the print dialog opens on
/// (export_bytes.dart:68-72).
PdfPageFormat printPageFormat(PageComponent page) => PdfPageFormat(
    page.effectiveWidthMm * 72 / 25.4, page.effectiveHeightMm * 72 / 25.4);

ExportDpi _dpiOf(PlanExportDpi dpi) => switch (dpi) {
      PlanExportDpi.d96 => ExportDpi.d96,
      PlanExportDpi.d150 => ExportDpi.d150,
      PlanExportDpi.d300 => ExportDpi.d300,
    };

/// `plan.pdf`: the page as a one-page vector PDF with the plan's font
/// embedded, the omitted objects not drawn.
final class PlanPdfExporter implements PlanPageExporter {
  const PlanPdfExporter();

  static const String exporterId = 'plan.pdf';

  @override
  String get id => exporterId;

  @override
  String get extension => 'pdf';

  @override
  String get mimeType => 'application/pdf';

  @override
  Future<Uint8List> export(PlanExportRequest request) async => exportPagePdf(
      document: request.document,
      page: request.page!,
      fontBytes: await request.fonts.bytes,
      omitOwners: request.omitted);
}

/// `plan.png`: the page as a PNG at the choice's resolution, the omitted
/// objects not drawn.
final class PlanPngExporter implements PlanPageExporter {
  const PlanPngExporter();

  static const String exporterId = 'plan.png';

  @override
  String get id => exporterId;

  @override
  String get extension => 'png';

  @override
  String get mimeType => 'image/png';

  @override
  Future<Uint8List> export(PlanExportRequest request) => exportPagePng(
      document: request.document,
      page: request.page!,
      dpi: _dpiOf(request.choice.dpi),
      omitOwners: request.omitted);
}
```

- [ ] **Step 7: The controller's flows.** Create `lib/src/export/page_flows.dart`:

```dart
// Spec P2 (the export rules) and P5 (the registries): the controller's
// export, print and import, one export or print at a time. Ported from
// jet_cad_floor_plan/lib/src/host/page_flows.dart (exportOnce, printOnce,
// :73-120) and floor_plan_controller.dart (_pageFlow, :1376-1388).
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show registerKitComponents;

import '../file/plan_file.dart' show ensureManifest;
import 'builtin_exporters.dart';
import 'export_font.dart';
import 'page_printer.dart';
import 'registries.dart';

bool _never() => false;

/// The export, print and import flows of one controller: the registries,
/// the one-flow guard its views share, the remembered dialog answer and
/// the font.
final class PlanPageFlows {
  /// [exporters] and [importers] are the host's; [unexported] the ids of
  /// the types with `exported: false`; [document], [catalog], [settle] and
  /// [load] read and act on the controller at each call.
  PlanPageFlows({
    required List<PlanExporter> exporters,
    required List<PlanImporter> importers,
    required Set<String> unexported,
    required DraftDocument Function() document,
    required ParametricCatalog Function() catalog,
    required void Function() settle,
    required void Function(String json) load,
    PlanExportFonts? fonts,
  })  : exporters = List.unmodifiable(<PlanExporter>[
          const PlanPdfExporter(),
          const PlanPngExporter(),
          ...exporters,
        ]),
        importers = List.unmodifiable(importers),
        fonts = fonts ?? ExportFontCache(),
        _unexported = Set.unmodifiable(unexported),
        _document = document,
        _catalog = catalog,
        _settle = settle,
        _load = load {
    checkRegistry(exporters: exporters, importers: importers);
  }

  /// Throws an [ArgumentError] naming `exporters` (or `importers`) when two
  /// of them, the built-ins included, share an id. The controller's factory
  /// calls it before it builds anything.
  static void checkRegistry(
      {required List<PlanExporter> exporters,
      required List<PlanImporter> importers}) {
    _unique([
      PlanPdfExporter.exporterId,
      PlanPngExporter.exporterId,
      for (final e in exporters) e.id,
    ], 'exporters');
    _unique([for (final i in importers) i.id], 'importers');
  }

  static void _unique(List<String> ids, String name) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        throw ArgumentError.value(ids, name, 'lists the id "$id" twice');
      }
    }
  }

  /// `plan.pdf`, `plan.png`, then the host's, in its order.
  final List<PlanExporter> exporters;
  final List<PlanImporter> importers;
  final PlanExportFonts fonts;
  final Set<String> _unexported;
  final DraftDocument Function() _document;
  final ParametricCatalog Function() _catalog;
  final void Function() _settle;
  final void Function(String json) _load;

  final ValueNotifier<bool> _ready = ValueNotifier(true);
  bool _disposed = false;

  /// False while an export or a print runs, for this controller and every
  /// view of it.
  ValueListenable<bool> get ready => _ready;

  /// The export dialog's last answer: the next dialog's initial.
  PlanExportAnswer dialogAnswer = PlanExportAnswer.initial;

  bool get isDisposed => _disposed;

  /// Takes the guard: false when a flow runs or the flows are disposed.
  bool acquire() {
    if (_disposed || !_ready.value) return false;
    _ready.value = false;
    return true;
  }

  /// Gives the guard back, unless the flows are disposed.
  void release() {
    if (!_disposed) _ready.value = true;
  }

  PlanExporter exporterOf(String id) {
    for (final e in exporters) {
      if (e.id == id) return e;
    }
    throw ArgumentError.value(id, 'exporterId', 'names no exporter');
  }

  PlanImporter importerOf(String id) {
    for (final i in importers) {
      if (i.id == id) return i;
    }
    throw ArgumentError.value(id, 'importerId', 'names no importer');
  }

  /// The live objects of [document] whose type has `exported: false`.
  Set<Handle> omittedOf(DraftDocument document) {
    if (_unexported.isEmpty) return const {};
    final catalog = _catalog();
    return {
      for (final node in document.tree.nodes)
        if (node is GroupNode)
          if (catalog.typeIdOf(document, node.handle) case final id?
              when _unexported.contains(id))
            node.handle,
    };
  }

  /// A copy of [live]: its codec JSON decoded with a measurer of its own
  /// and the controller's registrations.
  ({DraftDocument document, FlutterTextMeasurer measurer}) _copyOf(
      DraftDocument live) {
    final measurer = FlutterTextMeasurer();
    final catalog = _catalog();
    final copy = DraftDocumentCodec.decodeString(
        DraftDocumentCodec.encodeToString(live),
        measurer: measurer,
        registerComponents: (r) {
          PageComponent.register(r);
          registerKitComponents(r);
          catalog.registerComponents(r);
        },
        diagnostics: <Diagnostic>[]);
    return (document: copy, measurer: measurer);
  }

  /// [flow] under the guard, after the settle; [busy] when another flow
  /// runs or the flows are disposed, before or after it.
  Future<T> guarded<T>(T busy, Future<T> Function() flow) async {
    if (!acquire()) return busy;
    try {
      _settle();
      final result = await flow();
      return _disposed ? busy : result;
    } finally {
      release();
    }
  }

  /// Export's one body (page_flows.dart:73-97): [document] (the
  /// controller's plan when null) by [exporterId] as [choice] says, named
  /// `<name>.<extension>`. Null when the plan shown is no longer
  /// [document], before or after the bytes; when the exporter plots the
  /// page and the plan has none; or when [cancelled] says so after the
  /// bytes. The exporter gets a copy, disposed when its bytes are back.
  Future<PlanExport?> exportOnce(
      String exporterId, PlanExportChoice choice, String name,
      {DraftDocument? document, bool Function() cancelled = _never}) async {
    final exporter = exporterOf(exporterId);
    final live = document ?? _document();
    if (!identical(live, _document())) return null;
    if (exportPageOf(live) == null && exporter is PlanPageExporter) {
      return null;
    }
    final copy = _copyOf(live);
    final Uint8List bytes;
    try {
      bytes = await exporter.export(PlanExportRequest(
          document: copy.document,
          page: exportPageOf(copy.document),
          choice: choice,
          omitted: omittedOf(copy.document),
          fonts: fonts));
    } finally {
      copy.document.dispose();
      copy.measurer.clear();
    }
    if (cancelled() || !identical(live, _document())) return null;
    return PlanExport(
        bytes: bytes,
        name: '$name.${exporter.extension}',
        mimeType: exporter.mimeType);
  }

  /// Print's one body (page_flows.dart:99-120): the plan's page as
  /// `plan.pdf`'s bytes to [printer], named [name]. False when it has no
  /// page, when the plan shown changed while the bytes were made, or when
  /// [cancelled] says so after them; true once the printer is done.
  Future<bool> printOnce(PagePrinter printer, String name,
      {PlanExportChoice choice = PlanExportChoice.initial,
      bool Function() cancelled = _never}) async {
    final live = _document();
    final page = exportPageOf(live);
    if (page == null) return false;
    final copy = _copyOf(live);
    final Uint8List bytes;
    try {
      bytes = await const PlanPdfExporter().export(PlanExportRequest(
          document: copy.document,
          page: exportPageOf(copy.document),
          choice: choice,
          omitted: omittedOf(copy.document),
          fonts: fonts));
    } finally {
      copy.document.dispose();
      copy.measurer.clear();
    }
    if (cancelled() || !identical(live, _document())) return false;
    await printer.print(bytes, name, printPageFormat(page));
    return true;
  }

  /// `PlanController.export`: an unknown id throws at once.
  Future<PlanExport?> export(String exporterId, PlanExportChoice choice,
      {required String name}) {
    exporterOf(exporterId);
    return guarded<PlanExport?>(
        null,
        () => exportOnce(exporterId, choice, name,
            cancelled: () => _disposed));
  }

  /// `PlanController.print`.
  Future<bool> print(PlanExportChoice choice,
          {required PagePrinter printer, required String name}) =>
      guarded<bool>(
          false,
          () => printOnce(printer, name,
              choice: choice, cancelled: () => _disposed));

  /// `PlanController.import`: an unknown id throws at once; the importer's
  /// text, with an empty manifest added when it has none, is loaded.
  Future<void> import(String importerId, Uint8List bytes) {
    final importer = importerOf(importerId);
    return _import(importer, bytes);
  }

  Future<void> _import(PlanImporter importer, Uint8List bytes) async {
    final text = await importer.import(bytes);
    if (_disposed) return;
    _load(ensureManifest(text));
  }

  void dispose() {
    _disposed = true;
    _ready.dispose();
  }
}
```

- [ ] **Step 8: The controller.** In `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (Task 8's file):
  1. Imports: `dart:typed_data`, `package:meta/meta.dart` (if not there), `../export/page_flows.dart`, `../export/page_printer.dart` (`../export/registries.dart` is imported already, Task 8).
  2. Task 8's factory (`PlanController({required List<PlanKit> kits, …})`, which "throws … before it builds anything") already takes `List<PlanExporter> exporters = const []` and `List<PlanImporter> importers = const []` and hands them to the private constructor. It now also calls `PlanPageFlows.checkRegistry(exporters: exporters, importers: importers);` beside its other checks. In the private constructor, Task 8's two `@internal final` fields `exporters` and `importers` and their initialisers are removed (the getters of item 3 replace them: the registry is the single place that holds the lists), and the private constructor declares the field below and assigns it in its body:

     ```dart
     /// The export, print and import flows (spec P2, P5): the registries,
     /// the one-flow guard every view of this controller shares, the
     /// remembered dialog answer and the font.
     @internal
     late final PlanPageFlows pageFlows;
     ```

     ```dart
     pageFlows = PlanPageFlows(
       exporters: exporters,
       importers: importers,
       unexported: {
         for (final kit in kits.kits)
           for (final type in kit.types)
             if (!type.exported) type.id,
       },
       document: () => document,
       catalog: () => catalog,
       settle: settlePendingInput,
       load: load,
     );
     ```

     (`exporters` and `importers` here are the private constructor's parameters; `kits` is Task 8's `final KitSet kits` field.)
  3. The public members:

     ```dart
     /// `plan.pdf`, `plan.png`, then the host's exporters, in order.
     List<PlanExporter> get exporters => pageFlows.exporters;

     /// The host's importers, in order.
     List<PlanImporter> get importers => pageFlows.importers;

     /// [exporterId]'s bytes of the plan as [choice] says, named
     /// `<name>.<extension>` (`name` defaults to `plan`), with no view
     /// mounted (spec P2).
     ///
     /// Null when an export or a print already runs for this controller
     /// (one at a time, its views' included), when the exporter plots the
     /// page and the plan has none, when the plan is replaced (`load`,
     /// `newPlan`, `import`) before the bytes are made, or after [dispose].
     /// Pending input is settled first; the exporter is handed a copy of the
     /// plan made then. The dialog's remembered answer is left as it is. An
     /// error completes the `Future` with it; an unknown [exporterId] is an
     /// [ArgumentError] at once. Not gated by [permissions] (a host call).
     Future<PlanExport?> export(String exporterId, PlanExportChoice choice,
             {String? name}) =>
         pageFlows.export(exporterId, choice, name: name ?? 'plan');

     /// The plan's page as a PDF to [printer] (the platform's print dialog
     /// when null), named [name] (`plan` when null). True once the printer
     /// is done; false under [export]'s rules for null. Not gated by
     /// [permissions].
     Future<bool> print(PlanExportChoice choice,
             {PagePrinter? printer, String? name}) =>
         pageFlows.print(choice,
             printer: printer ?? const PrintingPagePrinter(),
             name: name ?? 'plan');

     /// Reads [bytes] with [importerId]'s importer and loads the plan's
     /// text, an empty manifest added when it has none (spec P5). An
     /// importer's error, or a load that refuses ([PlanFormatException]),
     /// completes the `Future` with it and changes nothing; an unknown
     /// [importerId] is an [ArgumentError] at once.
     Future<void> import(String importerId, Uint8List bytes) =>
         pageFlows.import(importerId, bytes);
     ```

  4. `dispose()`: call `pageFlows.dispose();` before `super.dispose()`.

  5. Task 8's C13 (`test/controller/plan_controller_test.dart`) reads `exporters` as the host's list alone; with the built-ins first, its three `exporters` expectations become `expect([for (final e in c.exporters) e.id], ['plan.pdf', 'plan.png']);`, `expect([for (final e in d.exporters) e.id], ['plan.pdf', 'plan.png', 'acme.dxf', 'acme.svg']);` and `expect(d.exporters, hasLength(4), reason: 'copied');` (the importers' lines are unchanged). C13 is a new test of Task 8 whose subject this task redefines (spec P5: the built-ins are in the registry), not a ported assertion; M-C13 still turns it red.

- [ ] **Step 9: The dialog and the view's flows.** Create `lib/src/export/export_dialog.dart`:

```dart
// The Export dialog over the registry (spec P5): the format, one segment
// per exporter, and for an image format its resolution; Export or Cancel.
// Escape cancels (a dismissible route pops on Escape). Ported from
// jet_cad_floor_plan/lib/src/export/export_dialog.dart.
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'registries.dart';

/// A host's export dialog (`PlanEditor.onExportDialog`): it starts from
/// [initial] over [exporters] and answers null to cancel.
typedef PlanExportDialog = Future<PlanExportAnswer?> Function(
    BuildContext context,
    PlanExportAnswer initial,
    List<PlanExporter> exporters);

/// Whether [exporter] writes a raster image, whose resolution the dialog
/// asks for.
bool isRasterExporter(PlanExporter exporter) =>
    exporter.mimeType.startsWith('image/');

/// Asks for the export's exporter and resolution, starting from [initial]
/// (from the first exporter when [initial] names none of [exporters]).
/// Null when cancelled (Cancel, Escape or a tap outside).
Future<PlanExportAnswer?> showPlanExportDialog(BuildContext context,
        PlanExportAnswer initial, List<PlanExporter> exporters) =>
    showDialog<PlanExportAnswer>(
      context: context,
      builder: (_) => _ExportDialog(initial: initial, exporters: exporters),
    );

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.initial, required this.exporters});

  final PlanExportAnswer initial;
  final List<PlanExporter> exporters;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late PlanExportAnswer _answer =
      widget.exporters.any((e) => e.id == widget.initial.exporter)
          ? widget.initial
          : widget.initial.copyWith(exporter: widget.exporters.first.id);

  PlanExporter get _exporter =>
      widget.exporters.firstWhere((e) => e.id == _answer.exporter);

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final strings = PlanStrings.of(context);
    return AlertDialog(
      key: const Key('export-dialog'),
      title: Text(strings.exportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            key: const Key('export-format'),
            showSelectedIcon: false,
            segments: [
              for (final e in widget.exporters)
                ButtonSegment(
                    value: e.id,
                    label: Text(e.extension.toUpperCase(),
                        key: Key('export-format-${e.id}'))),
            ],
            selected: {_answer.exporter},
            onSelectionChanged: (s) =>
                setState(() => _answer = _answer.copyWith(exporter: s.single)),
          ),
          if (isRasterExporter(_exporter)) ...[
            const SizedBox(height: 12),
            SegmentedButton<PlanExportDpi>(
              key: const Key('export-dpi'),
              showSelectedIcon: false,
              segments: [
                for (final d in PlanExportDpi.values)
                  ButtonSegment(
                      value: d,
                      label: Text(strings.dpi(d.value),
                          key: Key('export-dpi-${d.value}'))),
              ],
              selected: {_answer.choice.dpi},
              onSelectionChanged: (s) => setState(() => _answer = _answer
                  .copyWith(choice: _answer.choice.copyWith(dpi: s.single))),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('export-cancel'),
          onPressed: _cancel,
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('export-ok'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(_answer),
          child: Text(strings.exportAction),
        ),
      ],
    );
  }
}
```

Create `lib/src/export/editor_page_flows.dart` (port of `packages/jet_cad_floor_plan/lib/src/host/page_flows.dart:20-41` and `:122-231`; the conversions of `:45-71` are gone with the closed format enum):

```dart
// Export and Print from an editor's bar and chords (2a spec P2, P5): the
// dialog (the host's when it gave one), the remembered answer, the bytes
// to the host's onExport, the PDF to the printer. Under the controller's
// one-flow guard; the host's hooks and settings are read at each call;
// `permissions.export` and `.print` are read again after the dialog and
// after the bytes, so a flow started before the host refused it does not
// run to its end. Ported from jet_cad_floor_plan/lib/src/host/page_flows.dart.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart' show BuildContext;

import '../controller/plan_controller.dart';
import 'builtin_exporters.dart' show exportPageOf;
import 'export_dialog.dart';
import 'page_flows.dart';
import 'page_printer.dart';
import 'registries.dart';

/// What the flows read from the view at call time.
typedef PageFlowSettings = ({
  void Function(PlanExport export)? onExport,
  PagePrinter printer,
  String exportName,
});

/// The view's hooks, read at each call: the host's export dialog, in place
/// of the Material one, and where a flow's error goes.
typedef PageFlowHooks = ({
  PlanExportDialog? exportDialog,
  void Function(Object error)? onError,
});

PageFlowHooks _noHooks() => const (exportDialog: null, onError: null);

/// The two flows of one editor view, for its controller.
class EditorPageFlows {
  EditorPageFlows(
      {required this.controller, required this.settings, this.hooks = _noHooks});

  final PlanController controller;

  /// The view's current settings, read at each call.
  final PageFlowSettings Function() settings;

  /// The view's current hooks, read at each call.
  final PageFlowHooks Function() hooks;

  bool _disposed = false;

  PlanPageFlows get _flows => controller.pageFlows;

  /// False while a flow runs (this view's, another view's or the host's
  /// own call): a second press does nothing.
  ValueListenable<bool> get ready => _flows.ready;

  /// Export is offered only with an `onExport`.
  bool get canExport => settings().onExport != null;

  bool _exportAllowed() => controller.permissions.export;
  bool _printAllowed() => controller.permissions.print;

  Future<void> export(BuildContext context) => _run(() async {
        final sink = settings().onExport;
        if (sink == null) return;
        final flows = _flows;
        final document = controller.document;
        final paged = exportPageOf(document) != null;
        if (!paged && flows.exporters.every((e) => e is PlanPageExporter)) {
          return;
        }
        if (!context.mounted) return;
        // The host's dialog when it gave one, the Material one otherwise;
        // either way from the remembered answer, and null cancels.
        final dialog = hooks().exportDialog;
        final answer = dialog != null
            ? await dialog(context, flows.dialogAnswer, flows.exporters)
            : await showPlanExportDialog(
                context, flows.dialogAnswer, flows.exporters);
        // A view gone meanwhile is the bytes' cancel, below.
        if (answer == null || (!_disposed && !_exportAllowed())) return;
        flows.dialogAnswer = answer;
        final export = await flows.exportOnce(
            answer.exporter, answer.choice, settings().exportName,
            document: document,
            cancelled: () => _disposed || !_exportAllowed());
        if (export != null) sink(export);
      });

  Future<void> print(BuildContext context) => _run(() async {
        final s = settings();
        await _flows.printOnce(s.printer, s.exportName,
            choice: _flows.dialogAnswer.choice,
            cancelled: () => _disposed || !_printAllowed());
      });

  Future<void> _run(Future<void> Function() flow) async {
    final flows = _flows;
    if (_disposed || !flows.acquire()) return;
    try {
      controller.settlePendingInput();
      await flow();
    } catch (error) {
      // Without the host's callback the error propagates, as it always
      // did, out of a Future the caller drops.
      final report = hooks().onError;
      if (report == null) rethrow;
      report(error);
    } finally {
      // The view may have gone while the flow awaited; the controller's
      // guard is released all the same, unless the controller went too.
      flows.release();
    }
  }

  void dispose() => _disposed = true;
}
```

- [ ] **Step 10: The barrel.** In `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`, replace Task 8's `export 'src/export/registries.dart';` with the `show` list below, and add the two other lines:

```dart
export 'src/export/export_dialog.dart' show PlanExportDialog;
export 'src/export/page_printer.dart' show PagePrinter, PrintingPagePrinter;
export 'src/export/registries.dart'
    show
        PlanExport,
        PlanExportAnswer,
        PlanExportChoice,
        PlanExportDpi,
        PlanExportFonts,
        PlanExportRequest,
        PlanExporter,
        PlanImporter,
        PlanPageExporter;
```

- [ ] **Step 11: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/export`. Expected: `All tests passed!`.

- [ ] **Step 12: The gates.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, format exit 0. `git status --short` shows only this task's files.

- [ ] **Step 13: Commit.**

```bash
git add packages/jet_cad_2d_plan/pubspec.yaml packages/jet_cad_2d_plan/lib/src/export/registries.dart packages/jet_cad_2d_plan/lib/src/export/builtin_exporters.dart packages/jet_cad_2d_plan/lib/src/export/export_font.dart packages/jet_cad_2d_plan/lib/src/export/page_printer.dart packages/jet_cad_2d_plan/lib/src/export/page_flows.dart packages/jet_cad_2d_plan/lib/src/export/export_dialog.dart packages/jet_cad_2d_plan/lib/src/export/editor_page_flows.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/fake_page_printer.dart packages/jet_cad_2d_plan/test/support/export_plan.dart packages/jet_cad_2d_plan/test/support/recording_exporters.dart packages/jet_cad_2d_plan/test/support/flows_bar.dart packages/jet_cad_2d_plan/test/export/plan_export_types_test.dart packages/jet_cad_2d_plan/test/export/registry_test.dart packages/jet_cad_2d_plan/test/export/export_dialog_test.dart packages/jet_cad_2d_plan/test/export/export_font_test.dart packages/jet_cad_2d_plan/test/export/page_flows_test.dart packages/jet_cad_2d_plan/test/controller/plan_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): export, print and import through registries

PlanExporter and PlanImporter registries with plan.pdf and plan.png
built in; PlanController.export, print and import under today's rules
(one flow at a time, a page where needed, a plan replaced answers null,
pending input settled first, the dialog's answer remembered, errors
complete the Future). The exporter gets a copy of the plan made at the
start; objects of types with exported: false are omitted. The export
dialog lists the registry; EditorPageFlows ports the view's flows with
their hooks for the editor's bar.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 14: Mutation check** (on the committed files; after each, `git checkout -- <file>` and `git diff --quiet -- <file>` exits 0):
  - M-X-1a: in `registries.dart`, `PlanExportChoice.==` becomes `other is PlanExportChoice` → X-1 red.
  - M-X-1b: in `registries.dart`, `PlanExportAnswer.==` drops `other.exporter == exporter &&` → X-1 red.
  - M-X-2: in `page_flows.dart`'s `checkRegistry`, delete the two `_unique(...)` calls → X-2 red.
  - M-X-3a: in `page_flows.dart`, `omittedOf` returns `const {}` first → X-3 red.
  - M-X-3b: in `plan_controller.dart`, the `unexported` set drops `if (!type.exported)` → X-3 red (the exported kit's marks are left out).
  - M-X-4: in `page_flows.dart`'s `exportOnce`, `document: copy.document` becomes `document: live` (and the `finally` no longer disposes it) → X-4 red.
  - M-X-5: in `exportOnce`, delete `if (exportPageOf(live) == null && exporter is PlanPageExporter) { return null; }` → X-5 red.
  - M-X-6: in `_import`, `_load(ensureManifest(text))` becomes `_load(text)` → X-6 red.
  - M-X-7: in `printOnce`, `const PlanPdfExporter()` becomes `const PlanPngExporter()` → X-7 red.
  - M-X-8: in `guarded`, delete `_settle();` → X-8 red.
  - M-X-9: in `export_dialog.dart`, `if (isRasterExporter(_exporter)) ...[` becomes `...[` → X-9 red.
  - M-X-10: in `page_flows.dart`'s `exportOnce`, delete `!identical(live, _document())` from the check after the bytes → ported PF8 red (a load during the export no longer answers null).
  - M-X-11: in `editor_page_flows.dart`'s `export`, delete `(!_disposed && !_exportAllowed())` from the check after the dialog → ported PF22 red.
  - M-X-12: in `page_flows.dart`'s `guarded`, `if (!acquire()) return busy;` becomes `acquire();` → ported PF7 red (the second export in the step is not null).

#### Assumed from earlier tasks

Used as written; where an earlier task named it otherwise, use that task's name and report the difference.
- Task 7 (`lib/src/file/plan_file.dart`, `lib/src/file/plan_format_exception.dart`): `String ensureManifest(String text)`; `PlanFormatException` with `PlanFormatCode get code`; `load` refuses a manifest whose format is above 1 with `PlanFormatCode.formatTooNew`.
- Task 8 (`lib/src/controller/plan_controller.dart`): the factory and its private constructor, which already take and store `exporters` and `importers` (this task moves them into `pageFlows`); `lib/src/export/registries.dart` (Task 8 creates it; this task extends it, controller ruling R-k); `KitSet get kits`; `DraftDocument get document`; `ParametricCatalog get catalog`; `void load(String json)` (changes nothing when it throws); `void settlePendingInput()`; `VoidCallback registerSettle(VoidCallback)`; `Set<String> get missingKits`; `dispose()`.
- Task 9: `kPlanFontAsset` (the asset key of the plan library's bundled `Roboto-Regular.ttf`) in its fonts file; `PlanStrings` with `exportTitle`, `dpi(int)`, `cancel`, `exportAction` (today's `FloorPlanStrings` words).
- Task 12: `PlanPermissions` with `bool export`, `bool print`, `copyWith`, `full`; `PlanController.permissions` get and set.
- Task 18: `test/support/mark_kit.dart` (`markKit`, `MarkCross`, `addMark`) and `test/support/layer_plan.dart` (`addLineOn`).
- Task 6: the `jet_cad_2d_plan` pubspec, which leaves `pdf` and `printing` to this task (Step 0); the analysis options' `unawaited_futures` lint (so the bar's presses wrap their flows in `unawaited`).

#### Interface problem

Resolved by the controller's Shared interfaces (`PlanPageExporter`, `PlanExportAnswer` and `PlanExportDialog` are listed there) and ruling R-k (`lib/src/export/registries.dart` is Task 8's; this task extends it).

---

