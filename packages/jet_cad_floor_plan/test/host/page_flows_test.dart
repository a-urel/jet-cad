// Host embedding API spec C-3 and C-4 (Slice 4 plan, Task 1; S-1, S-7,
// S-8): the export choice made public, the controller's `exportPlan` and
// `printPlan` without their dialogs under one guard per controller, the
// view's `onExportDialog` at every Export entry point of both modes, and
// `onPageFlowError`. On the embedding fixture (turned, mirrored, scaled
// tables 40 m off the origin) under `embeddingCamera()`; a print or a PDF
// on it without table 9, whose corners are not finite (the PDF writer
// asserts on its NaN coordinates, on the base too). Expected pixel sizes
// are computed here from the page, never read from the code under test.
import 'dart:async';
import 'dart:convert' show latin1;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show ExportDpi;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart' as host;
import 'package:jet_cad_floor_plan/src/export/export_bytes.dart';
import 'package:jet_cad_floor_plan/src/export/export_dialog.dart';
import 'package:jet_cad_floor_plan/src/export/page_printer.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/fake_page_printer.dart';
import '../tables/table_fixture.dart';
import 'embedding_fixture.dart';
import 'zone_fixture.dart' show addZoneLayer;

Finder byKey(String k) => find.byKey(Key(k));

/// [embeddingPlanJson] without table 9: every other table, layer and the
/// page as the fixture makes them, so a PDF of it can be written.
String finitePlanJson() {
  final doc = plan();
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, PageComponent(originX: 37000, originY: -36200)));
  final hidden = addZoneLayer(doc, kEmbeddingHidden, visible: false);
  final locked = addZoneLayer(doc, kEmbeddingLocked, locked: true);
  final entry = entryOf(embeddingTable);
  for (final t in embeddingTables.where((t) => t.finite)) {
    doc.commands.execute(placeSymbol(doc, entry,
        at: Vector2(t.transform.e, t.transform.f),
        transform: t.transform,
        numbered: t.label != null));
    final info = TableSurvey.of(doc).tables.last;
    if (t.label case final label?) {
      doc.commands
          .execute(SetEntityTextCommand(info.label!, label, kTableLabelTag));
    }
    switch (t.layer) {
      case kEmbeddingHidden:
        doc.commands.execute(SetInstanceLayerCommand(info.instance, hidden));
      case kEmbeddingLocked:
        doc.commands.execute(SetInstanceLayerCommand(info.instance, locked));
    }
  }
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  return json;
}

/// A PNG's width and height, from its IHDR chunk.
({int w, int h}) pngSize(Uint8List b) {
  expect(b.sublist(1, 4), 'PNG'.codeUnits);
  final d = ByteData.sublistView(b);
  return (w: d.getUint32(16), h: d.getUint32(20));
}

/// The page of [c]'s active plan in pixels at [dpi] (spec 13 D5:
/// `round(effW / 25.4 · dpi)`), computed here.
({int w, int h}) pagePixels(FloorPlanController c, int dpi) {
  final page = exportPageOf(c.activeDocument)!;
  return (
    w: (page.effectiveWidthMm / 25.4 * dpi).round(),
    h: (page.effectiveHeightMm / 25.4 * dpi).round(),
  );
}

/// The PDF's first `/MediaBox`, in pt.
List<double> mediaBox(Uint8List pdf) {
  final text = latin1.decode(pdf);
  final m = RegExp(r'/MediaBox\s*\[\s*([-\d.\s]+)\]').firstMatch(text);
  expect(m, isNotNull, reason: 'a PDF names its page size');
  return [
    for (final n in m!.group(1)!.trim().split(RegExp(r'\s+'))) double.parse(n)
  ];
}

const pdf150 = FloorPlanExportChoice.initial;
const png96 = FloorPlanExportChoice(
    format: FloorPlanExportFormat.png, dpi: FloorPlanExportDpi.d96);
const png300 = FloorPlanExportChoice(
    format: FloorPlanExportFormat.png, dpi: FloorPlanExportDpi.d300);

/// Lets real asynchronous work (the bytes, the font) run until [done].
Future<void> letRun(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 600 && !done(); i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// A host's export dialog that records each `initial` and answers [answer].
final class RecordingHook {
  RecordingHook(this.answer);

  FloorPlanExportChoice? answer;
  final List<FloorPlanExportChoice> initials = [];

  /// Thrown instead of answering, once, when set.
  Object? failNext;

  Future<FloorPlanExportChoice?> call(
      BuildContext context, FloorPlanExportChoice initial) async {
    initials.add(initial);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    return answer;
  }
}

Future<FloorPlanController> pumpFlows(
  WidgetTester tester, {
  String? json,
  void Function(FloorPlanExport)? onExport,
  PagePrinter? printer,
  String exportName = 'plan',
  RecordingHook? hook,
  void Function(Object error)? onError,
}) async {
  final c = FloorPlanController(json: json ?? embeddingPlanJson());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FloorPlanView(
              controller: c,
              onExport: onExport,
              printer: printer,
              exportName: exportName,
              onExportDialog: hook?.call,
              onPageFlowError: onError))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = embeddingCamera();
  await tester.pump();
  return c;
}

Future<void> toMode(
    WidgetTester tester, FloorPlanController c, FloorPlanMode mode) async {
  c.setMode(mode);
  await tester.pump();
  await tester.pump();
  c.cameraController.value = embeddingCamera();
  await tester.pump();
}

/// Cmd+[key] ([meta]) or Ctrl+[key], pressed and released.
Future<void> chord(WidgetTester tester, LogicalKeyboardKey key,
    {required bool meta}) async {
  final modifier =
      meta ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

/// Moves table [n] of the active plan by (dx, dy) mm, one command.
void move(FloorPlanController c, String n, double dx, double dy) {
  final d = c.activeDocument;
  final node =
      d.tree[TableSurvey.of(d).withNumber(n).single.instance]! as InstanceNode;
  d.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

bool enabled(WidgetTester tester, String key) =>
    tester.widget<IconButton>(byKey(key)).onPressed != null;

void main() {
  testWidgets(
      'PF1 the export choice through the barrel alone: ==, hashCode, '
      'copyWith, toString, the resolutions', (tester) async {
    const host.FloorPlanExportChoice initial =
        host.FloorPlanExportChoice.initial;
    expect(initial.format, host.FloorPlanExportFormat.pdf);
    expect(initial.dpi, host.FloorPlanExportDpi.d150);
    expect(initial.toString(), 'FloorPlanExportChoice(pdf, 150 dpi)');
    const png = host.FloorPlanExportChoice(
        format: host.FloorPlanExportFormat.png,
        dpi: host.FloorPlanExportDpi.d300);
    expect(png.toString(), 'FloorPlanExportChoice(png, 300 dpi)');
    expect(host.FloorPlanExportDpi.values.map((d) => d.value), [96, 150, 300]);
    expect(host.FloorPlanExportFormat.values,
        [host.FloorPlanExportFormat.pdf, host.FloorPlanExportFormat.png]);

    // Each field changed alone makes a different value.
    final format = initial.copyWith(format: host.FloorPlanExportFormat.png);
    final dpi = initial.copyWith(dpi: host.FloorPlanExportDpi.d96);
    expect(format.dpi, host.FloorPlanExportDpi.d150, reason: 'dpi kept');
    expect(dpi.format, host.FloorPlanExportFormat.pdf, reason: 'format kept');
    expect(format == initial, isFalse);
    expect(dpi == initial, isFalse);
    expect(format == dpi, isFalse);
    expect(initial.copyWith(), initial);
    expect(
        initial,
        const host.FloorPlanExportChoice(
            format: host.FloorPlanExportFormat.pdf,
            dpi: host.FloorPlanExportDpi.d150));
    expect(
        initial.copyWith(
            format: host.FloorPlanExportFormat.png,
            dpi: host.FloorPlanExportDpi.d300),
        png);
    expect(png.hashCode, png300.hashCode);
    expect(initial.hashCode == format.hashCode, isFalse);
    expect(initial.hashCode == dpi.hashCode, isFalse);
  });

  testWidgets(
      'PF2 exportPlan(PNG at 96) in each mode: image/png, <name>.png, the '
      "page's pixel size at 96 dpi; the copy's moved table is in the bytes",
      (tester) async {
    final got = <FloorPlanExport>[];
    final c = await pumpFlows(tester, onExport: got.add);
    final design = (await tester.runAsync(() => c.exportPlan(png96)))!;
    expect(design.mimeType, 'image/png');
    expect(design.fileName, 'plan.png');
    expect(pngSize(design.bytes), pagePixels(c, 96));
    final named =
        (await tester.runAsync(() => c.exportPlan(png96, name: 'salon')))!;
    expect(named.fileName, 'salon.png');
    expect(named.bytes, design.bytes);
    expect(got, isEmpty, reason: 'the command returns, it calls no onExport');

    await toMode(tester, c, FloorPlanMode.selection);
    final same = (await tester.runAsync(() => c.exportPlan(png96)))!;
    expect(same.fileName, 'plan.png');
    expect(pngSize(same.bytes), pagePixels(c, 96));
    expect(same.bytes, design.bytes, reason: 'the copy, unmoved');
    move(c, '1', 900, -600);
    await tester.pump();
    final moved = (await tester.runAsync(() => c.exportPlan(png96)))!;
    expect(moved.bytes, isNot(design.bytes), reason: 'the copy, moved');
    expect(c.exportChoice, ExportChoice.initial,
        reason: 'exportPlan leaves the remembered choice');
  });

  testWidgets(
      "PF3 a plan without a page exports null and prints false; printPlan "
      "gives the printer one call with the name and the page's format",
      (tester) async {
    final pageless =
        FloorPlanController(json: DraftDocumentCodec.encodeToString(plan()));
    addTearDown(pageless.dispose);
    expect(await tester.runAsync(() => pageless.exportPlan(png96)), isNull);
    final none = FakePagePrinter();
    expect(await tester.runAsync(() => pageless.printPlan(printer: none)),
        isFalse);
    expect(none.calls, isEmpty);

    final printer = FakePagePrinter();
    final c = await pumpFlows(tester, json: finitePlanJson());
    for (final mode in FloorPlanMode.values) {
      await toMode(tester, c, mode);
      expect(
          await tester
              .runAsync(() => c.printPlan(printer: printer, name: 'teras')),
          isTrue);
    }
    expect(printer.calls, hasLength(2));
    final page = exportPageOf(c.activeDocument)!;
    for (final call in printer.calls) {
      expect(call.name, 'teras');
      expect(
          call.format.width, closeTo(page.effectiveWidthMm * 72 / 25.4, 1e-9));
      expect(call.format.height,
          closeTo(page.effectiveHeightMm * 72 / 25.4, 1e-9));
      expect(call.pdf.sublist(0, 4), '%PDF'.codeUnits);
    }
  });

  testWidgets(
      'PF4 exportPlan and printPlan act with no view mounted, and answer '
      'null and false after dispose()', (tester) async {
    final c = FloorPlanController(json: finitePlanJson());
    c.cameraController.value = embeddingCamera();
    final png = (await tester.runAsync(() => c.exportPlan(png96)))!;
    expect(pngSize(png.bytes), pagePixels(c, 96));
    final printer = FakePagePrinter();
    expect(await tester.runAsync(() => c.printPlan(printer: printer)), isTrue);
    expect(printer.calls.single.name, 'plan');
    c.dispose();
    expect(await tester.runAsync(() => c.exportPlan(png96)), isNull);
    expect(await tester.runAsync(() => c.printPlan(printer: printer)), isFalse);
    expect(printer.calls, hasLength(1));
  });

  testWidgets(
      'PF5 without onExportDialog the Material dialog still opens from the '
      'chords, in both modes', (tester) async {
    final got = <FloorPlanExport>[];
    final c = await pumpFlows(tester, onExport: got.add);
    for (final mode in FloorPlanMode.values) {
      await toMode(tester, c, mode);
      for (final meta in [true, false]) {
        await chord(tester, LogicalKeyboardKey.keyE, meta: meta);
        await tester.pump();
        expect(byKey('export-dialog'), findsOneWidget,
            reason: '$mode meta: $meta');
        await tester.tap(byKey('export-cancel'));
        await tester.pump();
        await tester.pump();
        expect(byKey('export-dialog'), findsNothing);
      }
    }
    expect(got, isEmpty);
  });

  testWidgets(
      'PF6 (M-H46) onExportDialog at every Export entry point: Cmd+E and '
      'Ctrl+E and the bar in the design mode, Ctrl+E and the bar in the '
      'selection mode; never the Material dialog', (tester) async {
    final got = <FloorPlanExport>[];
    final hook = RecordingHook(png300);
    final c = await pumpFlows(tester,
        onExport: got.add, exportName: 'salon', hook: hook);
    final want = pagePixels(c, 300);

    Future<void> exportBy(String how, Future<void> Function() trigger) async {
      final before = got.length;
      await trigger();
      await tester.pump();
      expect(byKey('export-dialog'), findsNothing, reason: how);
      expect(hook.initials, hasLength(before + 1), reason: how);
      await letRun(tester, () => got.length > before);
      expect(got, hasLength(before + 1), reason: how);
      expect(got.last.fileName, 'salon.png', reason: how);
      expect(got.last.mimeType, 'image/png', reason: how);
      expect(pngSize(got.last.bytes), want, reason: how);
      await letRun(tester, () => c.pageFlowReady.value);
    }

    await exportBy('design Cmd+E',
        () => chord(tester, LogicalKeyboardKey.keyE, meta: true));
    await exportBy('design Ctrl+E',
        () => chord(tester, LogicalKeyboardKey.keyE, meta: false));
    await exportBy('toolbar-export', () => tester.tap(byKey('toolbar-export')));
    await toMode(tester, c, FloorPlanMode.selection);
    await exportBy('selection Ctrl+E',
        () => chord(tester, LogicalKeyboardKey.keyE, meta: false));
    await exportBy('service-export', () => tester.tap(byKey('service-export')));
    expect(hook.initials, [pdf150, png300, png300, png300, png300],
        reason: 'the remembered choice is each call\'s initial');
  });

  testWidgets(
      "PF7 (T1-a) one flow at a time per controller: a second exportPlan in "
      "the same step answers null; printPlan while the bar's Print awaits "
      'its printer answers false, and true after it ends', (tester) async {
    final barPrinter = FakePagePrinter()..hold = true;
    final c = await pumpFlows(tester,
        json: finitePlanJson(), printer: barPrinter, onExport: (_) {});
    final both = await tester.runAsync(() {
      final first = c.exportPlan(png96);
      final second = c.exportPlan(png96);
      return Future.wait([first, second]);
    });
    expect(both![0], isNotNull);
    expect(both[1], isNull, reason: 'the first still ran');

    for (final mode in FloorPlanMode.values) {
      await toMode(tester, c, mode);
      final print =
          mode == FloorPlanMode.design ? 'toolbar-print' : 'service-print';
      final calls = barPrinter.calls.length;
      await tester.tap(byKey(print));
      await tester.pump();
      await letRun(tester, () => barPrinter.calls.length > calls);
      expect(barPrinter.held, hasLength(calls + 1), reason: 'held: $mode');
      final own = FakePagePrinter();
      expect(await tester.runAsync(() => c.printPlan(printer: own)), isFalse,
          reason: '$mode: the bar\'s Print runs');
      expect(await tester.runAsync(() => c.exportPlan(png96)), isNull,
          reason: mode.name);
      expect(own.calls, isEmpty);
      expect(enabled(tester, print), isFalse, reason: mode.name);
      barPrinter.held.last.complete();
      await tester.pump();
      await letRun(tester, () => c.pageFlowReady.value);
      expect(enabled(tester, print), isTrue, reason: mode.name);
      expect(await tester.runAsync(() => c.printPlan(printer: own)), isTrue,
          reason: '$mode: after it ends');
      expect(own.calls, hasLength(1));
    }

    // A host's printPlan holds the bar's buttons too.
    final held = FakePagePrinter()..hold = true;
    late Future<bool> printing;
    await tester.runAsync(() async {
      printing = c.printPlan(printer: held);
      while (held.calls.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(enabled(tester, 'service-print'), isFalse);
    expect(enabled(tester, 'service-export'), isFalse);
    held.held.single.complete();
    expect(await tester.runAsync(() => printing), isTrue);
    await tester.pump();
    expect(enabled(tester, 'service-print'), isTrue);
  });

  testWidgets(
      'PF8 (T1-b) exportPlan of a plan replaced before its bytes: a mode '
      'switch, then a load, each answers null', (tester) async {
    final c = await pumpFlows(tester, json: finitePlanJson());
    final switched = await tester.runAsync(() {
      final f = c.exportPlan(png96);
      c.setMode(FloorPlanMode.selection);
      return f;
    });
    expect(switched, isNull);
    await tester.pump();
    await tester.pump();
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    final loaded = await tester.runAsync(() {
      final f = c.exportPlan(png96);
      c.load(finitePlanJson());
      return f;
    });
    expect(loaded, isNull);
    await tester.pump();
    await tester.pump();
    final printer = FakePagePrinter();
    final printed = await tester.runAsync(() {
      final f = c.printPlan(printer: printer);
      c.setMode(FloorPlanMode.selection);
      return f;
    });
    expect(printed, isFalse);
    expect(printer.calls, isEmpty);
    // Swapped after the font, while the PDF is made: the font is cached,
    // so the swap's microtask runs right after the font's check.
    await tester.runAsync(() => c.exportFont.bytes);
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    final late = await tester.runAsync(() {
      final f = c.printPlan(printer: printer);
      scheduleMicrotask(() => c.setMode(FloorPlanMode.selection));
      return f;
    });
    expect(late, isFalse);
    expect(printer.calls, isEmpty);
    await tester.pump();
    await tester.pump();
    expect(await tester.runAsync(() => c.exportPlan(png96)), isNotNull,
        reason: 'the guard is free again');
  });

  testWidgets(
      "PF9 (T1-c) a failing flow with onPageFlowError: the error reported "
      "once, the flow ended, Print enabled again; in both modes, the hook's "
      'own error too', (tester) async {
    final errors = <Object>[];
    final printer = FakePagePrinter();
    final hook = RecordingHook(png96);
    final got = <FloorPlanExport>[];
    final c = await pumpFlows(tester,
        json: finitePlanJson(),
        printer: printer,
        onExport: got.add,
        hook: hook,
        onError: errors.add);
    for (final mode in FloorPlanMode.values) {
      await toMode(tester, c, mode);
      final prefix = mode == FloorPlanMode.design ? 'toolbar' : 'service';
      final jam = StateError('jam');
      printer.failNext = jam;
      final before = errors.length;
      await tester.tap(byKey('$prefix-print'));
      await tester.pump();
      await letRun(tester, () => errors.length > before);
      await tester.pump();
      expect(errors, hasLength(before + 1), reason: mode.name);
      expect(identical(errors.last, jam), isTrue, reason: mode.name);
      expect(tester.takeException(), isNull);
      expect(enabled(tester, '$prefix-print'), isTrue, reason: mode.name);

      final broken = ArgumentError('dialog');
      hook.failNext = broken;
      await tester.tap(byKey('$prefix-export'));
      await tester.pump();
      await letRun(tester, () => errors.length > before + 1);
      await tester.pump();
      expect(errors, hasLength(before + 2), reason: mode.name);
      expect(identical(errors.last, broken), isTrue, reason: mode.name);
      expect(got, isEmpty);
      expect(enabled(tester, '$prefix-export'), isTrue, reason: mode.name);
    }
    expect(printer.calls, hasLength(2));
  });

  testWidgets(
      'PF10 (T1-c, S-8) without onPageFlowError a failing print escapes as '
      'an uncaught asynchronous error, as on the base, and Print is enabled '
      'again', (tester) async {
    final printer = FakePagePrinter();
    final c = await pumpFlows(tester, json: finitePlanJson(), printer: printer);
    for (final mode in FloorPlanMode.values) {
      await toMode(tester, c, mode);
      final print =
          mode == FloorPlanMode.design ? 'toolbar-print' : 'service-print';
      final jam = StateError('jam');
      printer.failNext = jam;
      final caught = <Object>[];
      await runZonedGuarded(() async {
        await tester.tap(byKey(print));
        await tester.pump();
        await letRun(tester, () => caught.isNotEmpty);
        await tester.pump();
      }, (error, _) => caught.add(error));
      expect(caught, hasLength(1), reason: mode.name);
      expect(identical(caught.single, jam), isTrue, reason: mode.name);
      expect(tester.takeException(), isNull);
      expect(enabled(tester, print), isTrue, reason: mode.name);
    }
  });

  testWidgets(
      "PF11 printPlan's error completes its Future; onPageFlowError hears "
      'nothing; the guard is free again', (tester) async {
    final errors = <Object>[];
    final c = await pumpFlows(tester,
        json: finitePlanJson(), onError: errors.add, onExport: (_) {});
    final printer = FakePagePrinter()..failNext = StateError('jam');
    Object? thrown;
    await tester.runAsync(() async {
      try {
        await c.printPlan(printer: printer);
      } catch (e) {
        thrown = e;
      }
    });
    expect(thrown, isA<StateError>());
    expect(errors, isEmpty);
    expect(c.pageFlowReady.value, isTrue);
    expect(await tester.runAsync(() => c.printPlan(printer: printer)), isTrue);
    await tester.pump();
    expect(enabled(tester, 'toolbar-print'), isTrue);
  });

  testWidgets(
      'PF12 (T1-d) a hook answering null cancels: nothing exported, the '
      'remembered choice unchanged, in both modes', (tester) async {
    final got = <FloorPlanExport>[];
    final hook = RecordingHook(png300);
    final c = await pumpFlows(tester, onExport: got.add, hook: hook);
    // Remember PNG at 300 first, so a cancel that wrote anything shows.
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await letRun(tester, () => got.isNotEmpty);
    await letRun(tester, () => c.pageFlowReady.value);
    expect(got, hasLength(1));
    hook.answer = null;
    for (final mode in FloorPlanMode.values) {
      await toMode(tester, c, mode);
      await tester.tap(byKey(
          mode == FloorPlanMode.design ? 'toolbar-export' : 'service-export'));
      await tester.pump();
      await letRun(tester, () => c.pageFlowReady.value);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(got, hasLength(1), reason: mode.name);
      expect(byKey('export-dialog'), findsNothing);
      expect(c.exportChoice,
          const ExportChoice(format: ExportFormat.png, dpi: ExportDpi.d300));
    }
    expect(hook.initials, [pdf150, png300, png300]);
  });

  testWidgets(
      "PF13 (T1-e) each of the six choices through exportPlan gives what the "
      "same choice gives through the dialog's bytes: a PNG's pixel size per "
      "dpi, a PDF's magic and page size", (tester) async {
    final c = await pumpFlows(tester, json: finitePlanJson());
    final document = c.activeDocument;
    final page = exportPageOf(document)!;
    const internalDpi = {
      FloorPlanExportDpi.d96: ExportDpi.d96,
      FloorPlanExportDpi.d150: ExportDpi.d150,
      FloorPlanExportDpi.d300: ExportDpi.d300,
    };
    const dpiValue = {
      FloorPlanExportDpi.d96: 96,
      FloorPlanExportDpi.d150: 150,
      FloorPlanExportDpi.d300: 300,
    };
    for (final format in FloorPlanExportFormat.values) {
      for (final dpi in FloorPlanExportDpi.values) {
        final choice = FloorPlanExportChoice(format: format, dpi: dpi);
        final e = (await tester.runAsync(() => c.exportPlan(choice)))!;
        if (format == FloorPlanExportFormat.png) {
          expect(e.mimeType, 'image/png', reason: '$choice');
          expect(e.fileName, 'plan.png', reason: '$choice');
          expect(pngSize(e.bytes), pagePixels(c, dpiValue[dpi]!),
              reason: '$choice');
          final dialogs = await tester.runAsync(() => exportBytes(
              document,
              page,
              ExportChoice(format: ExportFormat.png, dpi: internalDpi[dpi]!),
              fontBytes: () => c.exportFont.bytes));
          expect(e.bytes, dialogs, reason: '$choice');
        } else {
          expect(e.mimeType, 'application/pdf', reason: '$choice');
          expect(e.fileName, 'plan.pdf', reason: '$choice');
          expect(e.bytes.sublist(0, 5), '%PDF-'.codeUnits, reason: '$choice');
          final box = mediaBox(e.bytes);
          expect(box[2], closeTo(page.effectiveWidthMm * 72 / 25.4, 1e-3),
              reason: '$choice');
          expect(box[3], closeTo(page.effectiveHeightMm * 72 / 25.4, 1e-3),
              reason: '$choice');
        }
      }
    }
  });

  testWidgets(
      "PF14 (T1-f) the hook's answer is remembered as the next initial, "
      'across the modes; exportPlan leaves it as it was', (tester) async {
    final got = <FloorPlanExport>[];
    final hook = RecordingHook(png300);
    final c = await pumpFlows(tester, onExport: got.add, hook: hook);
    Future<void> press(String key) async {
      final before = got.length;
      await tester.tap(byKey(key));
      await tester.pump();
      await letRun(tester, () => got.length > before);
      await letRun(tester, () => c.pageFlowReady.value);
    }

    await press('toolbar-export');
    hook.answer = png96;
    await press('toolbar-export');
    expect(await tester.runAsync(() => c.exportPlan(png300)), isNotNull);
    await toMode(tester, c, FloorPlanMode.selection);
    await press('service-export');
    expect(hook.initials, [pdf150, png300, png96]);
    expect(pngSize(got.last.bytes), pagePixels(c, 96));
  });

  testWidgets(
      "PF15 a view removed while its Print runs releases the controller's "
      'guard when the printer is done: exportPlan acts again', (tester) async {
    final printer = FakePagePrinter()..hold = true;
    final c = await pumpFlows(tester, json: finitePlanJson(), printer: printer);
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    await letRun(tester, () => printer.held.isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(await tester.runAsync(() => c.exportPlan(png96)), isNull,
        reason: 'the print still runs');
    printer.held.single.complete();
    await tester.pump();
    await letRun(tester, () => c.pageFlowReady.value);
    expect(tester.takeException(), isNull);
    expect(await tester.runAsync(() => c.exportPlan(png96)), isNotNull);
  });
}
