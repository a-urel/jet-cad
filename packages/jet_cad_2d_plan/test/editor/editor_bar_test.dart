// 2a spec P2 (`PlanEditor(bar:)`): the editor's top bar a host may hide,
// reorder, cut down or extend. Ported from jet_cad_floor_plan/test/host/
// bars_test.dart (host embedding API spec C-2; S-2, S-19, S-20: BC2, BT1's
// and BT2's editor halves, M-H40's editor test, the editor half of "[print,
// undo]", the design mode's "visible: false", the editor bar's host
// widgets, T2-b's editor test, R-5's [snap, zoom]) and page_flows_test.dart
// (PF5, PF6: their design-mode halves). On the editor's fixture (two turned
// marks and a line 40 m off the origin, on the embedding fixture's page)
// under `embeddingCamera()`. The default bar's left edges were read on the
// floor planner's base (BC); every other expected place is computed here
// from the widgets' own sizes.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, kRulerThickness;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' as host;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor_bar.dart';
import 'package:jet_cad_2d_plan/src/export/builtin_exporters.dart'
    show exportPageOf;
import 'package:jet_cad_2d_plan/src/export/registries.dart';

import '../support/editor_host.dart';

const List<String> kEditorKeys = [
  'toolbar-export',
  'toolbar-print',
  'toolbar-undo',
  'toolbar-redo',
  'toolbar-guides',
  'status-text',
  'osnap-text',
  'zoom-text',
];

Map<String, double> edgesOf(WidgetTester tester, List<String> keys) => {
      for (final k in keys)
        if (byKey(k).evaluate().isNotEmpty) k: tester.getTopLeft(byKey(k)).dx,
    };

/// Every left edge of the default editor bar, read on the floor planner's
/// base (`ffe0b9c`) at 1440 x 900, per onExport; the alignment guides'
/// toggle (task 9b) sits after Redo, 40 px wide, and moves the status line.
const Map<bool, Map<String, double>> kEditorEdges = {
  true: {
    'toolbar-export': 12,
    'toolbar-print': 52,
    'toolbar-undo': 104,
    'toolbar-redo': 144,
    'toolbar-guides': 184,
    'status-text': 240,
    'osnap-text': 1184,
    'zoom-text': 1271.25,
  },
  false: {
    'toolbar-print': 12,
    'toolbar-undo': 64,
    'toolbar-redo': 104,
    'toolbar-guides': 144,
    'status-text': 200,
    'osnap-text': 1184,
    'zoom-text': 1271.25,
  },
};

/// The editor over [editorPlanJson] with [bar]; Export offered unless told
/// otherwise.
Future<PlanController> mountEditor(WidgetTester tester,
    {PlanEditorBar bar = const PlanEditorBar(),
    bool export = true,
    void Function(PlanExport)? onExport,
    String exportName = 'plan',
    host.PlanExportDialog? onExportDialog}) async {
  final c = editorController();
  await pumpEditor(
      tester,
      PlanEditor(
          controller: c,
          bar: bar,
          onExport: onExport ?? (export ? (_) {} : null),
          exportName: exportName,
          onExportDialog: onExportDialog));
  return c;
}

/// Where the shown canvas starts in the editor.
Offset canvasIn(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer)) -
    tester.getTopLeft(find.byType(PlanEditor));

/// Ctrl+[key], pressed and released; whether the key-down was handled.
Future<bool> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  final handled = await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  return handled;
}

/// Cmd+[key] ([meta]) or Ctrl+[key], pressed and released.
Future<void> chord(WidgetTester tester, LogicalKeyboardKey key,
    {required bool meta}) async {
  final modifier =
      meta ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
}

String statusText(WidgetTester tester) =>
    tester.widget<Text>(byKey('status-text')).data!;

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

const pdf150 = PlanExportAnswer.initial;
const png300 = PlanExportAnswer(
    exporter: 'plan.png', choice: PlanExportChoice(dpi: PlanExportDpi.d300));

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

  Future<PlanExportAnswer?> call(BuildContext context, PlanExportAnswer initial,
      List<PlanExporter> exporters) async {
    initials.add(initial);
    return answer;
  }
}

void main() {
  group('BC the default bar, characterized on the base (T2-a)', () {
    for (final MapEntry(key: export, value: want) in kEditorEdges.entries) {
      testWidgets(
          'BC2 the editor bar, onExport $export: every left edge as on the '
          'base', (tester) async {
        await mountEditor(tester, export: export);
        expect(edgesOf(tester, kEditorKeys), want);
      });
    }
  });

  group('the types', () {
    test(
        'BT1 the editor\'s names through the barrel alone: ==, hashCode, '
        'toString naming what differs from the default; the enum in '
        "today's left-to-right order (S-2)", () {
      expect(host.PlanEditorAction.values.map((a) => a.name),
          ['export', 'print', 'undo', 'redo', 'guides', 'snap', 'zoom']);
      const a = Text('a'), b = Text('b');
      const editor = host.PlanEditorBar();
      expect(editor.visible, isTrue);
      expect(editor.actions, host.PlanEditorAction.values);
      expect(editor, const host.PlanEditorBar());
      expect(editor.hashCode, const host.PlanEditorBar().hashCode);
      expect(editor.toString(), 'PlanEditorBar()');
      final editors = <host.PlanEditorBar>[
        const host.PlanEditorBar(visible: false),
        const host.PlanEditorBar(actions: [
          host.PlanEditorAction.redo,
          host.PlanEditorAction.undo,
          host.PlanEditorAction.zoom,
          host.PlanEditorAction.snap
        ]),
        const host.PlanEditorBar(leading: [a]),
        const host.PlanEditorBar(trailing: [a, b]),
      ];
      for (final v in editors) {
        expect(v, isNot(editor), reason: '$v');
      }
      expect(editors[1].toString(),
          'PlanEditorBar(actions: [redo, undo, zoom, snap])');
      expect(editors[3].toString(), 'PlanEditorBar(trailing: [Text, Text])');
      expect(
          const host.PlanEditorBar(
              visible: false, actions: [host.PlanEditorAction.zoom]).toString(),
          'PlanEditorBar(visible: false, actions: [zoom])');
    });

    testWidgets(
        'BT2 the editor bar listing an action twice is an ArgumentError '
        'naming actions', (tester) async {
      // M-ED-10: `validatePlanEditorBar` returns at once.
      final c = editorController();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: PlanEditor(
                  controller: c,
                  bar: const PlanEditorBar(actions: [
                    PlanEditorAction.zoom,
                    PlanEditorAction.zoom
                  ])))));
      final error = tester.takeException();
      expect(error, isA<ArgumentError>());
      expect((error as ArgumentError).name, 'actions');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('order and subset (M-H40)', () {
    testWidgets(
        'M-H40 the editor bar [redo, undo, zoom, snap], onExport given: Redo '
        'before Undo, the zoom read-out before OSNAP, no Export or Print',
        (tester) async {
      await mountEditor(tester,
          bar: const PlanEditorBar(actions: [
            PlanEditorAction.redo,
            PlanEditorAction.undo,
            PlanEditorAction.zoom,
            PlanEditorAction.snap
          ]));
      expect(byKey('toolbar-export'), findsNothing);
      expect(byKey('toolbar-print'), findsNothing);
      expect(left(tester, 'toolbar-redo'), 12);
      expect(left(tester, 'toolbar-undo'), right(tester, 'toolbar-redo'));
      expect(left(tester, 'status-text'), right(tester, 'toolbar-undo') + 16);
      expect(left(tester, 'osnap-text'), right(tester, 'zoom-text') + 16);
      expect(right(tester, 'osnap-text'),
          tester.getTopRight(byKey('chrome-top')).dx - 12,
          reason: 'the last read-out ends at the bar\'s padding');
    });

    testWidgets(
        'the editor bar [print, undo]: a file button and an edit button '
        '12 px apart', (tester) async {
      await mountEditor(tester,
          bar: const PlanEditorBar(
              actions: [PlanEditorAction.print, PlanEditorAction.undo]));
      expect(edgesOf(tester, kEditorKeys).keys,
          ['toolbar-print', 'toolbar-undo', 'status-text']);
      // M-ED-11: `_toolbarFor` opens a group only for the first button.
      expect(left(tester, 'toolbar-undo'), right(tester, 'toolbar-print') + 12);
    });
  });

  group('visible: false', () {
    testWidgets(
        'no top bar, the panels and the canvas start at the editor\'s top, '
        'the tools stay in the left panel', (tester) async {
      await mountEditor(tester, bar: const PlanEditorBar(visible: false));
      expect(byKey('chrome-top'), findsNothing);
      expect(edgesOf(tester, kEditorKeys), isEmpty);
      final view = tester.getTopLeft(find.byType(PlanEditor));
      expect(tester.getTopLeft(byKey('chrome-left')), view);
      expect(canvasIn(tester),
          const Offset(240 + kRulerThickness, kRulerThickness));
      for (final k in [
        'tool-plan.select',
        'tool-plan.line',
        'tool-plan.polyline'
      ]) {
        expect(byKey(k), findsOneWidget, reason: k);
        expect(find.descendant(of: byKey('chrome-left'), matching: byKey(k)),
            findsOneWidget,
            reason: k);
      }
    });
  });

  group('host widgets (S-19)', () {
    /// A leading box 30 px wide that counts its taps and a trailing box 70
    /// px wide that shows the count: the host's own state.
    (List<Widget>, List<Widget>) hostWidgets(ValueNotifier<int> taps) => (
          [
            SizedBox(
                key: const Key('host-lead'),
                width: 30,
                height: 30,
                child: GestureDetector(
                    onTap: () => taps.value++,
                    child: const ColoredBox(color: Color(0xFF123456)))),
          ],
          [
            SizedBox(
                key: const Key('host-trail'),
                width: 70,
                child: ValueListenableBuilder<int>(
                    valueListenable: taps,
                    builder: (_, n, __) =>
                        Text('taps $n', key: const Key('host-count')))),
          ]
        );

    void expectInBar(WidgetTester tester, String key, String bar) {
      final r = tester.getRect(byKey(key));
      final b = tester.getRect(byKey(bar));
      expect(r.top >= b.top && r.bottom <= b.bottom, isTrue,
          reason: '$key $r lies in $bar $b');
    }

    testWidgets(
        'the editor bar: leading before the toolbar, trailing after the '
        "zoom read-out, both inside the bar's height, and both reach the "
        "host's state", (tester) async {
      final taps = ValueNotifier(0);
      addTearDown(taps.dispose);
      final (lead, trail) = hostWidgets(taps);
      await mountEditor(tester,
          bar: PlanEditorBar(leading: lead, trailing: trail));
      expect(left(tester, 'host-lead'), 12);
      expect(left(tester, 'toolbar-export'), right(tester, 'host-lead'));
      expect(left(tester, 'host-trail'), right(tester, 'zoom-text'));
      expect(right(tester, 'host-trail'),
          tester.getTopRight(byKey('chrome-top')).dx - 12);
      expectInBar(tester, 'host-lead', 'chrome-top');
      expectInBar(tester, 'host-trail', 'chrome-top');
      await tester.tap(byKey('host-lead'));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget);
    });

    testWidgets(
        "T2-b a host TextField in the editor bar's trailing takes the focus "
        'and L as text: the tool stays Select', (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      await mountEditor(tester,
          bar: PlanEditorBar(trailing: [
            SizedBox(
                width: 120,
                child:
                    TextField(key: const Key('host-field'), controller: text))
          ]));
      expect(statusText(tester), 'Select');
      await tester.tap(byKey('host-field'));
      await tester.pump();
      final field = tester.state<EditableTextState>(find.descendant(
          of: byKey('host-field'), matching: find.byType(EditableText)));
      expect(field.widget.focusNode.hasPrimaryFocus, isTrue,
          reason: 'the field takes the focus');
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyL), isFalse,
          reason: 'L reaches the platform as text');
      tester.testTextInput.enterText('l');
      await tester.pump();
      expect(text.text, 'l');
      expect(statusText(tester), 'Select', reason: 'L switched no tool');
      expect(await ctrl(tester, LogicalKeyboardKey.keyZ), isFalse,
          reason: 'Ctrl+Z stays in the field');
    });

    testWidgets(
        'R-5 the editor bar [snap, zoom]: no button left, so no toolbar and '
        'no 16 px: the status line starts at the bar\'s padding',
        (tester) async {
      await mountEditor(tester,
          bar: const PlanEditorBar(
              actions: [PlanEditorAction.snap, PlanEditorAction.zoom]));
      expect(
          find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('toolbar-')),
          findsNothing);
      expect(left(tester, 'status-text'), 12);
    });
  });

  group('the page flows from the editor (PF5, PF6)', () {
    testWidgets(
        'PF5 without onExportDialog the Material dialog still opens from the '
        'chords', (tester) async {
      final got = <PlanExport>[];
      await mountEditor(tester, onExport: got.add);
      for (final meta in [true, false]) {
        await chord(tester, LogicalKeyboardKey.keyE, meta: meta);
        await tester.pump();
        expect(byKey('export-dialog'), findsOneWidget, reason: 'meta: $meta');
        await tester.tap(byKey('export-cancel'));
        await tester.pump();
        await tester.pump();
        expect(byKey('export-dialog'), findsNothing);
      }
      expect(got, isEmpty);
    });

    testWidgets(
        'PF6 (M-H46) onExportDialog at every Export entry point: Cmd+E and '
        'Ctrl+E and the bar; never the Material dialog', (tester) async {
      final got = <PlanExport>[];
      final hook = RecordingHook(png300);
      final c = await mountEditor(tester,
          onExport: got.add, exportName: 'salon', onExportDialog: hook.call);
      final want = pagePixels(c, 300);

      Future<void> exportBy(String how, Future<void> Function() trigger) async {
        final before = got.length;
        await trigger();
        await tester.pump();
        expect(byKey('export-dialog'), findsNothing, reason: how);
        expect(hook.initials, hasLength(before + 1), reason: how);
        await letRun(tester, () => got.length > before);
        expect(got, hasLength(before + 1), reason: how);
        expect(got.last.name, 'salon.png', reason: how);
        expect(got.last.mimeType, 'image/png', reason: how);
        expect(pngSize(got.last.bytes), want, reason: how);
        await letRun(tester, () => c.pageFlows.ready.value);
      }

      await exportBy('design Cmd+E',
          () => chord(tester, LogicalKeyboardKey.keyE, meta: true));
      await exportBy('design Ctrl+E',
          () => chord(tester, LogicalKeyboardKey.keyE, meta: false));
      await exportBy(
          'toolbar-export', () => tester.tap(byKey('toolbar-export')));
      expect(hook.initials, [pdf150, png300, png300],
          reason: 'the remembered choice is each call\'s initial');
    });
  });
}
