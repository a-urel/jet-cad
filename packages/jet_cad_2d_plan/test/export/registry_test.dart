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
      (
        [RecordingExporter('plan.pdf', 'pdf', 'application/pdf')],
        <PlanImporter>[],
        'exporters'
      ),
      ([dxf, dxf], <PlanImporter>[], 'exporters'),
      (
        <PlanExporter>[],
        [TextImporter('a.b'), TextImporter('a.b')],
        'importers'
      ),
    ]) {
      // M-X-2: drop PlanPageFlows' uniqueness checks.
      expect(() => flowsOver(doc, exporters: exporters, importers: importers),
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
    final shown = PlanController(kits: [markKit()], json: exportPlanJson());
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
    expect(without, isNot(whole),
        reason: 'premise: the marks are on the sheet');

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
    addLineOn(
        c.document, ReservedHandles.layerZero, 900.5, 300.25, 1800.75, 650.5);
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
    final plot =
        RecordingPageExporter('acme.plot', 'plt', 'application/vnd.hp-hpgl');
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
    await tester
        .runAsync(() => c.import('acme.json', Uint8List.fromList([7, 1, 9])));
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
        addLineOn(c.document, ReservedHandles.layerZero, 400.5, 220.25, 1300.75,
            980.5);
      }
    });
    addTearDown(release);
    await tester
        .runAsync(() => c.export('acme.json', PlanExportChoice.initial));
    // M-X-8: `guarded` does not call `_settle()`.
    expect(runs, greaterThan(0));
    expect(acme.seen.single, isNot(before));
    expect(acme.seen.single, DraftDocumentCodec.encodeToString(c.document));
  });
}
