// Spec P2 and P5: the controller's export and print without their
// dialogs, under one guard per controller; the editor's Export and Print
// (EditorPageFlows, here under the editor bar's two buttons, FlowsBar) with
// the host's onExportDialog and onPageFlowError. Ported from
// jet_cad_floor_plan/test/host/page_flows_test.dart (PF2-PF4, PF7-PF16,
// PF18-PF24) on the export fixture: two turned marks and a line around the
// sheet's centre. Expected pixel sizes are computed here from the page,
// never read from the code under test.
import 'dart:async';
import 'dart:convert' show latin1, utf8;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/export/builtin_exporters.dart';
import 'package:jet_cad_2d_plan/src/export/editor_page_flows.dart';
import 'package:jet_cad_2d_plan/src/export/export_dialog.dart';
import 'package:jet_cad_2d_plan/src/export/page_printer.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';
import 'package:jet_cad_2d_plan/src/fonts/plan_fonts.dart' show kPlanFontAsset;

import '../support/export_plan.dart';
import '../support/fake_page_printer.dart';
import '../support/flows_bar.dart';
import '../support/mark_kit.dart';

Finder byKey(String k) => find.byKey(Key(k));

/// A PNG's width and height, from its IHDR chunk.
({int w, int h}) pngSize(Uint8List b) {
  expect(b.sublist(1, 4), 'PNG'.codeUnits);
  final d = ByteData.sublistView(b);
  return (w: d.getUint32(16), h: d.getUint32(20));
}

/// The page of [c]'s plan in pixels at [dpi] (spec 13 D5:
/// `round(effW / 25.4 · dpi)`), computed here.
({int w, int h}) pagePixels(PlanController c, int dpi) {
  final page = exportPageOf(c.document)!;
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

const pdf150 = PlanExportAnswer.initial;
const png96 = PlanExportAnswer(
    exporter: 'plan.png', choice: PlanExportChoice(dpi: PlanExportDpi.d96));
const png300 = PlanExportAnswer(
    exporter: 'plan.png', choice: PlanExportChoice(dpi: PlanExportDpi.d300));

/// The controller's export as [a] says.
Future<PlanExport?> exportAs(PlanController c, PlanExportAnswer a,
        {String? name}) =>
    c.export(a.exporter, a.choice, name: name);

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

  PlanExportAnswer? answer;
  final List<PlanExportAnswer> initials = [];

  /// Thrown instead of answering, once, when set.
  Object? failNext;

  Future<PlanExportAnswer?> call(BuildContext context, PlanExportAnswer initial,
      List<PlanExporter> exporters) async {
    initials.add(initial);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    return answer;
  }
}

Future<PlanController> pumpFlows(
  WidgetTester tester, {
  String? json,
  void Function(PlanExport)? onExport,
  PagePrinter? printer,
  String exportName = 'plan',
  RecordingHook? hook,
  void Function(Object error)? onError,
}) async {
  final c = PlanController(kits: [markKit()], json: json ?? exportPlanJson());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FlowsBar(
              controller: c,
              onExport: onExport,
              printer: printer,
              exportName: exportName,
              onExportDialog: hook?.call,
              onPageFlowError: onError))));
  await tester.pump();
  await tester.pump();
  return c;
}

bool enabled(WidgetTester tester, String key) =>
    tester.widget<IconButton>(byKey(key)).onPressed != null;

void main() {
  testWidgets(
      'PF2 export(PNG at 96): image/png, <name>.png, the page\'s pixel size '
      'at 96 dpi; the remembered answer is left as it is', (tester) async {
    final got = <PlanExport>[];
    final c = await pumpFlows(tester, onExport: got.add);
    final design = (await tester.runAsync(() => exportAs(c, png96)))!;
    expect(design.mimeType, 'image/png');
    expect(design.name, 'plan.png');
    expect(pngSize(design.bytes), pagePixels(c, 96));
    final named =
        (await tester.runAsync(() => exportAs(c, png96, name: 'salon')))!;
    expect(named.name, 'salon.png');
    expect(named.bytes, design.bytes);
    expect(got, isEmpty, reason: 'the command returns, it calls no onExport');
    expect(c.pageFlows.dialogAnswer, PlanExportAnswer.initial,
        reason: 'exportPlan leaves the remembered choice');
  });

  testWidgets(
      "PF3 a plan without a page exports null and prints false; print "
      "gives the printer one call with the name and the page's format",
      (tester) async {
    final pageless =
        PlanController(kits: [markKit()], json: exportPlanJson(page: false));
    addTearDown(pageless.dispose);
    expect(await tester.runAsync(() => exportAs(pageless, png96)), isNull);
    final none = FakePagePrinter();
    expect(
        await tester.runAsync(
            () => pageless.print(PlanExportChoice.initial, printer: none)),
        isFalse);
    expect(none.calls, isEmpty);

    final printer = FakePagePrinter();
    final c = await pumpFlows(tester, json: exportPlanJson());
    for (var run = 0; run < 2; run++) {
      expect(
          await tester.runAsync(() => c.print(PlanExportChoice.initial,
              printer: printer, name: 'teras')),
          isTrue);
    }
    expect(printer.calls, hasLength(2));
    final page = exportPageOf(c.document)!;
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
      'PF4 export and print act with no view mounted, and answer null and '
      'false after dispose()', (tester) async {
    final c = PlanController(kits: [markKit()], json: exportPlanJson());
    final png = (await tester.runAsync(() => exportAs(c, png96)))!;
    expect(pngSize(png.bytes), pagePixels(c, 96));
    final printer = FakePagePrinter();
    expect(
        await tester.runAsync(
            () => c.print(PlanExportChoice.initial, printer: printer)),
        isTrue);
    expect(printer.calls.single.name, 'plan');
    c.dispose();
    expect(await tester.runAsync(() => exportAs(c, png96)), isNull);
    expect(
        await tester.runAsync(
            () => c.print(PlanExportChoice.initial, printer: printer)),
        isFalse);
    expect(printer.calls, hasLength(1));
  });

  testWidgets(
      "PF7 (T1-a) one flow at a time per controller: a second export in "
      "the same step answers null; print while the bar's Print awaits "
      'its printer answers false, and true after it ends', (tester) async {
    final barPrinter = FakePagePrinter()..hold = true;
    final c = await pumpFlows(tester,
        json: exportPlanJson(), printer: barPrinter, onExport: (_) {});
    final both = await tester.runAsync(() {
      final first = exportAs(c, png96);
      final second = exportAs(c, png96);
      return Future.wait([first, second]);
    });
    expect(both![0], isNotNull);
    expect(both[1], isNull, reason: 'the first still ran');

    const print = 'toolbar-print';
    final calls = barPrinter.calls.length;
    await tester.tap(byKey(print));
    await tester.pump();
    await letRun(tester, () => barPrinter.calls.length > calls);
    expect(barPrinter.held, hasLength(calls + 1), reason: 'held');
    final own = FakePagePrinter();
    expect(
        await tester
            .runAsync(() => c.print(PlanExportChoice.initial, printer: own)),
        isFalse,
        reason: 'the bar\'s Print runs');
    expect(await tester.runAsync(() => exportAs(c, png96)), isNull);
    expect(own.calls, isEmpty);
    expect(enabled(tester, print), isFalse);
    barPrinter.held.last.complete();
    await tester.pump();
    await letRun(tester, () => c.pageFlows.ready.value);
    expect(enabled(tester, print), isTrue);
    expect(
        await tester
            .runAsync(() => c.print(PlanExportChoice.initial, printer: own)),
        isTrue,
        reason: 'after it ends');
    expect(own.calls, hasLength(1));

    // A host's print holds the bar's buttons too.
    final held = FakePagePrinter()..hold = true;
    late Future<bool> printing;
    await tester.runAsync(() async {
      printing = c.print(PlanExportChoice.initial, printer: held);
      while (held.calls.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(enabled(tester, 'toolbar-print'), isFalse);
    expect(enabled(tester, 'toolbar-export'), isFalse);
    held.held.single.complete();
    expect(await tester.runAsync(() => printing), isTrue);
    await tester.pump();
    expect(enabled(tester, 'toolbar-print'), isTrue);
  });

  testWidgets(
      'PF8 (T1-b) export of a plan replaced before its bytes: a load, '
      'each answers null; print too, before and while the PDF is made',
      (tester) async {
    final c = await pumpFlows(tester, json: exportPlanJson());
    final next = exportPlanJson();
    final switched = await tester.runAsync(() {
      final f = exportAs(c, png96);
      c.load(next);
      return f;
    });
    expect(switched, isNull);
    await tester.pump();
    await tester.pump();
    final loaded = await tester.runAsync(() {
      final f = exportAs(c, png96);
      c.load(next);
      return f;
    });
    expect(loaded, isNull);
    await tester.pump();
    await tester.pump();
    final printer = FakePagePrinter();
    final printed = await tester.runAsync(() {
      final f = c.print(PlanExportChoice.initial, printer: printer);
      c.load(next);
      return f;
    });
    expect(printed, isFalse);
    expect(printer.calls, isEmpty);
    // Replaced after the font, while the PDF is made: the font is cached,
    // so the swap's microtask runs right after the font's check.
    await tester.runAsync(() => c.pageFlows.fonts.bytes);
    await tester.pump();
    await tester.pump();
    final late = await tester.runAsync(() {
      final f = c.print(PlanExportChoice.initial, printer: printer);
      scheduleMicrotask(() => c.load(next));
      return f;
    });
    expect(late, isFalse);
    expect(printer.calls, isEmpty);
    await tester.pump();
    await tester.pump();
    expect(await tester.runAsync(() => exportAs(c, png96)), isNotNull,
        reason: 'the guard is free again');
  });

  testWidgets(
      "PF9 (T1-c) a failing flow with onPageFlowError: the error reported "
      "once, the flow ended, Print enabled again; the hook's own error too",
      (tester) async {
    final errors = <Object>[];
    final printer = FakePagePrinter();
    final hook = RecordingHook(png96);
    final got = <PlanExport>[];
    await pumpFlows(tester,
        json: exportPlanJson(),
        printer: printer,
        onExport: got.add,
        hook: hook,
        onError: errors.add);
    for (var run = 0; run < 2; run++) {
      const prefix = 'toolbar';
      final jam = StateError('jam');
      printer.failNext = jam;
      final before = errors.length;
      await tester.tap(byKey('$prefix-print'));
      await tester.pump();
      await letRun(tester, () => errors.length > before);
      await tester.pump();
      expect(errors, hasLength(before + 1), reason: 'run $run');
      expect(identical(errors.last, jam), isTrue, reason: 'run $run');
      expect(tester.takeException(), isNull);
      expect(enabled(tester, '$prefix-print'), isTrue, reason: 'run $run');

      final broken = ArgumentError('dialog');
      hook.failNext = broken;
      await tester.tap(byKey('$prefix-export'));
      await tester.pump();
      await letRun(tester, () => errors.length > before + 1);
      await tester.pump();
      expect(errors, hasLength(before + 2), reason: 'run $run');
      expect(identical(errors.last, broken), isTrue, reason: 'run $run');
      expect(got, isEmpty);
      expect(enabled(tester, '$prefix-export'), isTrue, reason: 'run $run');
    }
    expect(printer.calls, hasLength(2));
  });

  testWidgets(
      'PF10 (T1-c, S-8) without onPageFlowError a failing print escapes as '
      'an uncaught asynchronous error, as on the base, and Print is enabled '
      'again', (tester) async {
    final printer = FakePagePrinter();
    await pumpFlows(tester, json: exportPlanJson(), printer: printer);
    const print = 'toolbar-print';
    final jam = StateError('jam');
    printer.failNext = jam;
    final caught = <Object>[];
    await runZonedGuarded(() async {
      await tester.tap(byKey(print));
      await tester.pump();
      await letRun(tester, () => caught.isNotEmpty);
      await tester.pump();
    }, (error, _) => caught.add(error));
    expect(caught, hasLength(1));
    expect(identical(caught.single, jam), isTrue);
    expect(tester.takeException(), isNull);
    expect(enabled(tester, print), isTrue);
  });

  testWidgets(
      "PF11 print's error completes its Future; onPageFlowError hears "
      'nothing; the guard is free again', (tester) async {
    final errors = <Object>[];
    final c = await pumpFlows(tester,
        json: exportPlanJson(), onError: errors.add, onExport: (_) {});
    final printer = FakePagePrinter()..failNext = StateError('jam');
    Object? thrown;
    await tester.runAsync(() async {
      try {
        await c.print(PlanExportChoice.initial, printer: printer);
      } catch (e) {
        thrown = e;
      }
    });
    expect(thrown, isA<StateError>());
    expect(errors, isEmpty);
    expect(c.pageFlows.ready.value, isTrue);
    expect(
        await tester.runAsync(
            () => c.print(PlanExportChoice.initial, printer: printer)),
        isTrue);
    await tester.pump();
    expect(enabled(tester, 'toolbar-print'), isTrue);
  });

  testWidgets(
      'PF12 (T1-d) a hook answering null cancels: nothing exported, the '
      'remembered answer unchanged', (tester) async {
    final got = <PlanExport>[];
    final hook = RecordingHook(png300);
    final c = await pumpFlows(tester, onExport: got.add, hook: hook);
    // Remember PNG at 300 first, so a cancel that wrote anything shows.
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await letRun(tester, () => got.isNotEmpty);
    await letRun(tester, () => c.pageFlows.ready.value);
    expect(got, hasLength(1));
    hook.answer = null;
    for (var run = 0; run < 2; run++) {
      await tester.tap(byKey('toolbar-export'));
      await tester.pump();
      await letRun(tester, () => c.pageFlows.ready.value);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(got, hasLength(1), reason: 'run $run');
      expect(byKey('export-dialog'), findsNothing);
      expect(c.pageFlows.dialogAnswer, png300);
    }
    expect(hook.initials, [pdf150, png300, png300]);
  });

  testWidgets(
      "PF13 (T1-e) each of the six choices through export gives what the "
      "same choice gives through the exporter's bytes: a PNG's pixel size "
      "per dpi, a PDF's magic and page size", (tester) async {
    final c = await pumpFlows(tester, json: exportPlanJson());
    final document = c.document;
    final page = exportPageOf(document)!;
    for (final exporter in const ['plan.pdf', 'plan.png']) {
      for (final dpi in PlanExportDpi.values) {
        final choice = PlanExportAnswer(
            exporter: exporter, choice: PlanExportChoice(dpi: dpi));
        final e = (await tester.runAsync(() => exportAs(c, choice)))!;
        if (exporter == 'plan.png') {
          expect(e.mimeType, 'image/png', reason: '$choice');
          expect(e.name, 'plan.png', reason: '$choice');
          expect(pngSize(e.bytes), pagePixels(c, dpi.value), reason: '$choice');
          final dialogs = await tester.runAsync(() => const PlanPngExporter()
              .export(PlanExportRequest(
                  document: document,
                  page: page,
                  choice: PlanExportChoice(dpi: dpi),
                  omitted: const {},
                  fonts: c.pageFlows.fonts)));
          expect(e.bytes, dialogs, reason: '$choice');
        } else {
          expect(e.mimeType, 'application/pdf', reason: '$choice');
          expect(e.name, 'plan.pdf', reason: '$choice');
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
      "PF14 (T1-f) the hook's answer is remembered as the next initial; "
      'export leaves it as it was', (tester) async {
    final got = <PlanExport>[];
    final hook = RecordingHook(png300);
    final c = await pumpFlows(tester, onExport: got.add, hook: hook);
    Future<void> press(String key) async {
      final before = got.length;
      await tester.tap(byKey(key));
      await tester.pump();
      await letRun(tester, () => got.length > before);
      await letRun(tester, () => c.pageFlows.ready.value);
    }

    await press('toolbar-export');
    hook.answer = png96;
    await press('toolbar-export');
    expect(await tester.runAsync(() => exportAs(c, png300)), isNotNull);
    await press('toolbar-export');
    expect(hook.initials, [pdf150, png300, png96]);
    expect(pngSize(got.last.bytes), pagePixels(c, 96));
  });

  testWidgets(
      "PF15 a view removed while its Print runs releases the controller's "
      'guard when the printer is done: export acts again', (tester) async {
    final printer = FakePagePrinter()..hold = true;
    final c = await pumpFlows(tester, json: exportPlanJson(), printer: printer);
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    await letRun(tester, () => printer.held.isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(await tester.runAsync(() => exportAs(c, png96)), isNull,
        reason: 'the print still runs');
    printer.held.single.complete();
    await tester.pump();
    await letRun(tester, () => c.pageFlows.ready.value);
    expect(tester.takeException(), isNull);
    expect(await tester.runAsync(() => exportAs(c, png96)), isNotNull);
  });

  // The review's probes (s4-task-1-review R-1 to R-5): each holds a mutant
  // the tests above let survive.

  testWidgets(
      'PF16 (R-5) onExportDialog and onPageFlowError given by a host rebuild '
      'after the flows exist are the ones used at the next Export and the '
      'next error: read at each call, never captured', (tester) async {
    final got = <PlanExport>[];
    final c = PlanController(kits: [markKit()], json: exportPlanJson());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final printer = FakePagePrinter();
    Widget view({RecordingHook? hook, void Function(Object)? onError}) =>
        MaterialApp(
            home: Scaffold(
                body: FlowsBar(
                    controller: c,
                    onExport: got.add,
                    printer: printer,
                    onExportDialog: hook?.call,
                    onPageFlowError: onError)));
    await tester.pumpWidget(view());
    await tester.pump();
    await tester.pump();
    // The flows used once without a hook, so they exist before the rebuild.
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    expect(byKey('export-dialog'), findsOneWidget, reason: 'premise');
    await tester.tap(byKey('export-cancel'));
    await tester.pump();
    await tester.pump();
    await letRun(tester, () => c.pageFlows.ready.value);

    final hook = RecordingHook(png96);
    final errors = <Object>[];
    await tester.pumpWidget(view(hook: hook, onError: errors.add));
    await tester.pump();
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    expect(byKey('export-dialog'), findsNothing);
    await letRun(tester, () => got.isNotEmpty);
    expect(hook.initials, hasLength(1));
    expect(got, hasLength(1));
    expect(got.single.mimeType, 'image/png');
    await letRun(tester, () => c.pageFlows.ready.value);

    printer.failNext = StateError('jam');
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    await letRun(tester, () => errors.isNotEmpty);
    expect(errors, hasLength(1));
    expect(errors.single, isA<StateError>());
    await letRun(tester, () => c.pageFlows.ready.value);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'PF18 (R-3) dispose() while print awaits its printer: it answers '
      'false', (tester) async {
    final c = PlanController(kits: [markKit()], json: exportPlanJson());
    final printer = FakePagePrinter()..hold = true;
    late Future<bool> printing;
    await tester.runAsync(() async {
      printing = c.print(PlanExportChoice.initial, printer: printer);
      while (printer.held.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    c.dispose();
    printer.held.single.complete();
    expect(await tester.runAsync(() => printing), isFalse);
  });

  testWidgets(
      'PF19 (R-4) flows disposed while Print makes its bytes: nothing is '
      'printed', (tester) async {
    final printer = FakePagePrinter();
    final c = await pumpFlows(tester, json: exportPlanJson(), printer: printer);
    await tester.runAsync(() => c.pageFlows.fonts.bytes);
    final flows = EditorPageFlows(
        controller: c,
        settings: () => (onExport: null, printer: printer, exportName: 'plan'));
    final printing = flows.print(tester.element(find.byType(FlowsBar)));
    var done = false;
    unawaited(printing.whenComplete(() => done = true));
    scheduleMicrotask(flows.dispose);
    await letRun(tester, () => done);
    expect(done, isTrue);
    expect(printer.calls, isEmpty);
  });

  testWidgets(
      'PF20 (R-4) the view removed while Export makes its bytes: onExport '
      'is not called', (tester) async {
    final got = <PlanExport>[];
    final hook = RecordingHook(png96);
    await pumpFlows(tester, onExport: got.add, hook: hook);
    await tester.tap(byKey('toolbar-export'));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await tester.pump();
    expect(hook.initials, hasLength(1), reason: 'premise: the hook answered');
    expect(got, isEmpty);
  });

  testWidgets(
      "PF21 (R-5) the hook's answer is remembered even when the plan is "
      'replaced while it is open (as the dialog\'s always was); nothing is '
      'exported', (tester) async {
    final got = <PlanExport>[];
    final c = PlanController(kits: [markKit()], json: exportPlanJson());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final next = exportPlanJson();
    var asked = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowsBar(
                controller: c,
                onExport: got.add,
                onExportDialog: (context, initial, exporters) async {
                  asked++;
                  c.load(next);
                  return png300;
                }))));
    await tester.pump();
    await tester.pump();
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await letRun(tester, () => c.pageFlows.ready.value);
    await tester.pump();
    expect(asked, 1);
    expect(got, isEmpty);
    expect(c.pageFlows.dialogAnswer, png300);
  });

  /// [exportPlanJson] under a FlowsBar whose permissions the test sets on
  /// the controller, with `onExport`, a fake printer and, when given, a
  /// host's export dialog.
  Future<PlanController> pumpCaps(WidgetTester tester,
      {required void Function(PlanExport) onExport,
      required PagePrinter printer,
      PlanExportDialog? dialog}) async {
    final c = PlanController(kits: [markKit()], json: exportPlanJson());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowsBar(
                controller: c,
                onExport: onExport,
                printer: printer,
                onExportDialog: dialog))));
    await tester.pump();
    await tester.pump();
    return c;
  }

  testWidgets(
      'PF22 (final review F-4) the Material export dialog open when the '
      'host refuses export: OK exports nothing and the answer is not '
      'remembered; allowed again, the same steps export', (tester) async {
    final got = <PlanExport>[];
    final c =
        await pumpCaps(tester, onExport: got.add, printer: FakePagePrinter());
    Future<void> exportPng() async {
      await tester.tap(byKey('toolbar-export'));
      await tester.pump();
      await tester.pump();
      expect(byKey('export-dialog'), findsOneWidget, reason: 'premise');
      await tester.tap(byKey('export-format-plan.png'));
      await tester.pump();
    }

    await exportPng();
    c.permissions = PlanPermissions.full.copyWith(export: false);
    await tester.pump();
    expect(byKey('toolbar-export'), findsNothing, reason: 'premise: refused');
    await tester.tap(byKey('export-ok'));
    await tester.pump();
    await letRun(tester, () => got.isNotEmpty);
    await letRun(tester, () => c.pageFlows.ready.value);
    expect(got, isEmpty);
    expect(c.pageFlows.dialogAnswer, PlanExportAnswer.initial);

    c.permissions = PlanPermissions.full;
    await tester.pump();
    await exportPng();
    await tester.tap(byKey('export-ok'));
    await tester.pump();
    await letRun(tester, () => got.isNotEmpty);
    expect(got.single.name, 'plan.png', reason: 'the control');
  });

  testWidgets(
      "PF23 (final review F-4) a host's export dialog answering after the "
      'host refused export, and a refusal while the bytes are made: '
      'nothing is exported', (tester) async {
    final got = <PlanExport>[];
    var answer = Completer<PlanExportAnswer?>();
    final c = await pumpCaps(tester,
        onExport: got.add,
        printer: FakePagePrinter(),
        dialog: (_, __, ___) => answer.future);
    final refused = PlanPermissions.full.copyWith(export: false);

    // Refused while the hook's dialog is open.
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    c.permissions = refused;
    await tester.pump();
    answer.complete(png96);
    await letRun(tester, () => c.pageFlows.ready.value);
    expect(got, isEmpty, reason: 'refused while the dialog was open');

    // Refused after the dialog answered, while the bytes are made.
    c.permissions = PlanPermissions.full;
    await tester.pump();
    answer = Completer();
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    answer.complete(png96);
    await tester.pump();
    c.permissions = refused;
    await tester.pump();
    await letRun(tester, () => c.pageFlows.ready.value);
    expect(got, isEmpty, reason: 'refused while the bytes were made');
  });

  testWidgets(
      'PF24 (final review F-4) Print refused while its bytes wait on the '
      'font: nothing is printed; allowed, it prints', (tester) async {
    // The export font's asset held until the test lets it go, as a first
    // print's load can take a while.
    final gate = Completer<void>();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.allMessagesHandler = (channel, handler, message) {
      final send = handler ?? (m) => messenger.delegate.send(channel, m);
      if (channel == 'flutter/assets' &&
          utf8.decode(message!.buffer
                  .asUint8List(message.offsetInBytes, message.lengthInBytes)) ==
              kPlanFontAsset) {
        return gate.future.then((_) => send(message));
      }
      return send(message);
    };
    addTearDown(() => messenger.allMessagesHandler = null);
    final printer = FakePagePrinter();
    final c = await pumpCaps(tester, onExport: (_) {}, printer: printer);
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    expect(c.pageFlows.ready.value, isFalse, reason: 'premise: under way');
    c.permissions = PlanPermissions.full.copyWith(print: false);
    await tester.pump();
    expect(byKey('toolbar-print'), findsNothing, reason: 'premise: refused');
    gate.complete();
    await letRun(tester, () => c.pageFlows.ready.value);
    expect(c.pageFlows.ready.value, isTrue, reason: 'premise: the flow ended');
    expect(printer.calls, isEmpty);

    c.permissions = PlanPermissions.full;
    await tester.pump();
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    await letRun(tester, () => printer.calls.isNotEmpty);
    expect(printer.calls.single.name, 'plan', reason: 'the control');
  });
}
