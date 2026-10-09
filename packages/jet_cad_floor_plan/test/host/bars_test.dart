// Host embedding API spec C-1, C-2 and C-3's merge and Undo (Slice 4 plan,
// Task 2; S-2, S-4, S-5, S-19, S-20): the two bars a host may hide,
// reorder, cut down or extend; `mergeCandidate`; an Undo that waits for an
// idle tool in the design mode; and the canvas measured again when a bar
// is shown or hidden at runtime (S-10 generalised, R-13). On the embedding
// fixture (turned, mirrored, scaled tables 40 m off the origin, two tables
// sharing a number) under `embeddingCamera()`, both modes. The default
// bars' left edges were read on the base before `lib` changed (BC); every
// other expected place is computed here from the widgets' own sizes or
// from the camera's forward transform.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, kRulerThickness;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart' as host;
import 'package:jet_cad_floor_plan/src/host/bars.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/service_view.dart'
    show kServiceBarHeight;
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:jet_cad_floor_plan/src/shell_commands.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'embedding_fixture.dart';

Finder byKey(String k) => find.byKey(Key(k));

const List<String> kServiceKeys = [
  'service-undo',
  'service-redo',
  'service-merge',
  'service-split',
  'service-export',
  'service-print',
];

const List<String> kEditorKeys = [
  'toolbar-export',
  'toolbar-print',
  'toolbar-undo',
  'toolbar-redo',
  'status-text',
  'osnap-text',
  'zoom-text',
];

Map<String, double> edgesOf(WidgetTester tester, List<String> keys) => {
      for (final k in keys)
        if (byKey(k).evaluate().isNotEmpty) k: tester.getTopLeft(byKey(k)).dx,
    };

Future<FloorPlanController> mountBars(WidgetTester tester,
    {required FloorPlanMode mode,
    bool export = true,
    bool merge = false,
    bool split = false}) async {
  final c = FloorPlanController(json: embeddingPlanJson());
  addTearDown(c.dispose);
  c.setMode(mode);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FloorPlanView(
              controller: c,
              onExport: export ? (_) {} : null,
              onMergeRequested: merge ? (_) {} : null,
              onSplitRequested: split ? (_) {} : null))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = embeddingCamera();
  await tester.pump();
  return c;
}

const List<String> kBareIds = [
  'new',
  'open',
  'open-sample',
  'save',
  'save-as',
  'export',
  'print'
];

/// Every left edge of the default bars, read on the base (`ffe0b9c`)
/// before this task changed a line of `lib`, at 1440 x 900: the service
/// bar per (onExport, Merge, Split), the view's editor bar per onExport,
/// and a bare shell with the floor planner's seven file commands.
const Map<(bool, bool, bool), Map<String, double>> kServiceEdges = {
  (true, true, true): {
    'service-undo': 12,
    'service-redo': 60,
    'service-merge': 116,
    'service-split': 164,
    'service-export': 220,
    'service-print': 268,
  },
  (true, true, false): {
    'service-undo': 12,
    'service-redo': 60,
    'service-merge': 116,
    'service-export': 172,
    'service-print': 220,
  },
  (true, false, true): {
    'service-undo': 12,
    'service-redo': 60,
    'service-split': 116,
    'service-export': 172,
    'service-print': 220,
  },
  (true, false, false): {
    'service-undo': 12,
    'service-redo': 60,
    'service-export': 116,
    'service-print': 164,
  },
  (false, true, true): {
    'service-undo': 12,
    'service-redo': 60,
    'service-merge': 116,
    'service-split': 164,
    'service-print': 220,
  },
  (false, true, false): {
    'service-undo': 12,
    'service-redo': 60,
    'service-merge': 116,
    'service-print': 172,
  },
  (false, false, true): {
    'service-undo': 12,
    'service-redo': 60,
    'service-split': 116,
    'service-print': 172,
  },
  (false, false, false): {
    'service-undo': 12,
    'service-redo': 60,
    'service-print': 116,
  },
};

const Map<bool, Map<String, double>> kEditorEdges = {
  true: {
    'toolbar-export': 12,
    'toolbar-print': 52,
    'toolbar-undo': 104,
    'toolbar-redo': 144,
    'status-text': 200,
    'osnap-text': 1184,
    'zoom-text': 1271.25,
  },
  false: {
    'toolbar-print': 12,
    'toolbar-undo': 64,
    'toolbar-redo': 104,
    'status-text': 160,
    'osnap-text': 1184,
    'zoom-text': 1271.25,
  },
};

const Map<String, double> kBareEdges = {
  'toolbar-new': 12,
  'toolbar-open': 52,
  'toolbar-open-sample': 92,
  'toolbar-save': 132,
  'toolbar-save-as': 172,
  'toolbar-export': 212,
  'toolbar-print': 252,
  'toolbar-undo': 304,
  'toolbar-redo': 344,
  'status-text': 400,
  'osnap-text': 1198.25,
  'zoom-text': 1285.5,
};

List<String> get kBareKeys =>
    [for (final id in kBareIds) 'toolbar-$id', ...kEditorKeys.skip(2)];

Future<void> mountBare(WidgetTester tester) async {
  final on = ValueNotifier(true);
  addTearDown(on.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: PlannerShell(fileCommands: [
    for (final id in kBareIds)
      ShellCommand(
          id: id, label: id, icon: Icons.add, enabled: on, run: () async {}),
  ])));
  await tester.pump();
}

/// The bars the host rebuilds its view with, and what it heard.
final class BarHost {
  BarHost(this.c, FloorPlanServiceBar service, FloorPlanEditorBar editor)
      : bars = ValueNotifier((service, editor));

  final FloorPlanController c;
  final ValueNotifier<(FloorPlanServiceBar, FloorPlanEditorBar)> bars;

  /// The sets `onMergeRequested` received.
  final List<Set<String>> merged = [];

  set service(FloorPlanServiceBar bar) => bars.value = (bar, bars.value.$2);
  set editor(FloorPlanEditorBar bar) => bars.value = (bars.value.$1, bar);
}

/// [embeddingPlanJson] in [mode] under a view whose bars a [BarHost]
/// rebuilds; Export, Merge and Split offered unless told otherwise.
Future<BarHost> mountHost(WidgetTester tester,
    {FloorPlanMode mode = FloorPlanMode.selection,
    FloorPlanServiceBar service = const FloorPlanServiceBar(),
    FloorPlanEditorBar editor = const FloorPlanEditorBar(),
    bool export = true,
    bool groups = true}) async {
  final c = FloorPlanController(json: embeddingPlanJson());
  addTearDown(c.dispose);
  c.setMode(mode);
  final h = BarHost(c, service, editor);
  addTearDown(h.bars.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ValueListenableBuilder(
              valueListenable: h.bars,
              builder: (_, bars, __) => FloorPlanView(
                  controller: c,
                  onExport: export ? (_) {} : null,
                  onMergeRequested: groups ? h.merged.add : null,
                  onSplitRequested: groups ? (_) {} : null,
                  serviceBar: bars.$1,
                  editorBar: bars.$2)))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = embeddingCamera();
  await tester.pump();
  return h;
}

/// Where the shown canvas starts in the view.
Offset canvasIn(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer)) -
    tester.getTopLeft(find.byType(FloorPlanView));

/// World [w] on the screen, by the camera's forward transform from the
/// shown canvas's origin.
Offset globalOf(WidgetTester tester, FloorPlanController c, Vector2 w) {
  final p = canvasOf(c.cameraController.value, w.x, w.y);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(p.x, p.y);
}

/// The world centre of table [n]'s box in the active plan, by the
/// fixture's own transform of [embeddingBox]'s centre.
Vector2 centreOf(FloorPlanController c, String n) {
  final d = c.activeDocument;
  final node =
      d.tree[TableSurvey.of(d).withNumber(n).single.instance]! as InstanceNode;
  return node.transform.transformPoint(Vector2(700, 100));
}

void expectAt(Offset got, Offset want, String reason) {
  expect(got.dx, closeTo(want.dx, 1e-6), reason: '$reason (x)');
  expect(got.dy, closeTo(want.dy, 1e-6), reason: '$reason (y)');
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

/// Ctrl+[key], pressed and released; whether the key-down was handled.
Future<bool> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  final handled = await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  return handled;
}

String statusText(WidgetTester tester) =>
    tester.widget<Text>(byKey('status-text')).data!;

double left(WidgetTester tester, String k) => tester.getTopLeft(byKey(k)).dx;
double right(WidgetTester tester, String k) => tester.getTopRight(byKey(k)).dx;

void main() {
  group('BC the default bars, characterized on the base (T2-a)', () {
    for (final MapEntry(key: (export, merge, split), value: want)
        in kServiceEdges.entries) {
      testWidgets(
          'BC1 the service bar, onExport $export, Merge $merge, Split '
          '$split: every left edge as on the base', (tester) async {
        await mountBars(tester,
            mode: FloorPlanMode.selection,
            export: export,
            merge: merge,
            split: split);
        expect(edgesOf(tester, kServiceKeys), want);
      });
    }
    for (final MapEntry(key: export, value: want) in kEditorEdges.entries) {
      testWidgets(
          'BC2 the editor bar, onExport $export: every left edge as on the '
          'base', (tester) async {
        await mountBars(tester, mode: FloorPlanMode.design, export: export);
        expect(edgesOf(tester, kEditorKeys), want);
      });
    }
    testWidgets(
        'BC3 a bare shell with the floor planner\'s seven file commands: '
        'every left edge as on the base', (tester) async {
      await mountBare(tester);
      expect(edgesOf(tester, kBareKeys), kBareEdges);
    });
  });

  group('the types', () {
    test(
        'BT1 the four names through the barrel alone: ==, hashCode, '
        'toString naming what differs from the default; the enums in '
        "today's left-to-right order (S-2)", () {
      expect(host.FloorPlanServiceAction.values.map((a) => a.name),
          ['undo', 'redo', 'merge', 'split', 'export', 'print']);
      expect(host.FloorPlanEditorAction.values.map((a) => a.name),
          ['export', 'print', 'undo', 'redo', 'snap', 'zoom']);
      const a = Text('a'), b = Text('b');
      const service = host.FloorPlanServiceBar();
      expect(service.visible, isTrue);
      expect(service.actions, host.FloorPlanServiceAction.values);
      expect(service.leading, isEmpty);
      expect(service.trailing, isEmpty);
      expect(service, const host.FloorPlanServiceBar());
      expect(
          host.FloorPlanServiceBar(
              actions: List.of(host.FloorPlanServiceAction.values)),
          service,
          reason: 'equal lists, not the same list');
      expect(service.hashCode, const host.FloorPlanServiceBar().hashCode);
      expect(service.toString(), 'FloorPlanServiceBar()');
      final variants = <host.FloorPlanServiceBar>[
        const host.FloorPlanServiceBar(visible: false),
        const host.FloorPlanServiceBar(actions: [
          host.FloorPlanServiceAction.print,
          host.FloorPlanServiceAction.undo
        ]),
        const host.FloorPlanServiceBar(leading: [a]),
        const host.FloorPlanServiceBar(trailing: [a]),
      ];
      for (final v in variants) {
        expect(v, isNot(service), reason: '$v');
      }
      expect(const host.FloorPlanServiceBar(leading: [a]),
          isNot(const host.FloorPlanServiceBar(leading: [b])));
      expect(const host.FloorPlanServiceBar(leading: [a]),
          const host.FloorPlanServiceBar(leading: [a]));
      expect(const host.FloorPlanServiceBar(leading: [a]).hashCode,
          const host.FloorPlanServiceBar(leading: [a]).hashCode);
      expect(variants[0].toString(), 'FloorPlanServiceBar(visible: false)');
      expect(variants[1].toString(),
          'FloorPlanServiceBar(actions: [print, undo])');
      expect(variants[2].toString(), 'FloorPlanServiceBar(leading: [Text])');

      const editor = host.FloorPlanEditorBar();
      expect(editor.visible, isTrue);
      expect(editor.actions, host.FloorPlanEditorAction.values);
      expect(editor, const host.FloorPlanEditorBar());
      expect(editor.hashCode, const host.FloorPlanEditorBar().hashCode);
      expect(editor.toString(), 'FloorPlanEditorBar()');
      final editors = <host.FloorPlanEditorBar>[
        const host.FloorPlanEditorBar(visible: false),
        const host.FloorPlanEditorBar(actions: [
          host.FloorPlanEditorAction.redo,
          host.FloorPlanEditorAction.undo,
          host.FloorPlanEditorAction.zoom,
          host.FloorPlanEditorAction.snap
        ]),
        const host.FloorPlanEditorBar(leading: [a]),
        const host.FloorPlanEditorBar(trailing: [a, b]),
      ];
      for (final v in editors) {
        expect(v, isNot(editor), reason: '$v');
      }
      expect(editors[1].toString(),
          'FloorPlanEditorBar(actions: [redo, undo, zoom, snap])');
      expect(
          editors[3].toString(), 'FloorPlanEditorBar(trailing: [Text, Text])');
      expect(
          const host.FloorPlanEditorBar(
              visible: false,
              actions: [host.FloorPlanEditorAction.zoom]).toString(),
          'FloorPlanEditorBar(visible: false, actions: [zoom])');
    });

    for (final (name, service, editor) in [
      (
        'the service bar',
        const FloorPlanServiceBar(actions: [
          FloorPlanServiceAction.undo,
          FloorPlanServiceAction.print,
          FloorPlanServiceAction.undo
        ]),
        const FloorPlanEditorBar()
      ),
      (
        'the editor bar',
        const FloorPlanServiceBar(),
        const FloorPlanEditorBar(
            actions: [FloorPlanEditorAction.zoom, FloorPlanEditorAction.zoom])
      ),
    ]) {
      testWidgets(
          'BT2 $name listing an action twice is an ArgumentError naming '
          'actions, in either mode', (tester) async {
        for (final mode in FloorPlanMode.values) {
          final c = FloorPlanController(json: embeddingPlanJson());
          addTearDown(c.dispose);
          c.setMode(mode);
          await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                  body: FloorPlanView(
                      controller: c, serviceBar: service, editorBar: editor))));
          final error = tester.takeException();
          expect(error, isA<ArgumentError>(), reason: '$mode');
          expect((error as ArgumentError).name, 'actions', reason: '$mode');
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  });

  group('order and subset (M-H40)', () {
    testWidgets(
        'M-H40 the service bar [print, undo], Merge and Split offered: only '
        'Print and Undo, Print first, 8 px apart (two groups)', (tester) async {
      await mountHost(tester,
          service: const FloorPlanServiceBar(actions: [
            FloorPlanServiceAction.print,
            FloorPlanServiceAction.undo
          ]));
      expect(edgesOf(tester, kServiceKeys).keys,
          ['service-undo', 'service-print']);
      expect(left(tester, 'service-print'), 12);
      expect(left(tester, 'service-undo'), right(tester, 'service-print') + 8);
    });

    testWidgets(
        'M-H40 the editor bar [redo, undo, zoom, snap], onExport given: Redo '
        'before Undo, the zoom read-out before OSNAP, no Export or Print',
        (tester) async {
      await mountHost(tester,
          mode: FloorPlanMode.design,
          editor: const FloorPlanEditorBar(actions: [
            FloorPlanEditorAction.redo,
            FloorPlanEditorAction.undo,
            FloorPlanEditorAction.zoom,
            FloorPlanEditorAction.snap
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
        '12 px apart; the service bar [redo, undo, merge, export, split]: '
        '8 px at each change of group', (tester) async {
      final h = await mountHost(tester,
          mode: FloorPlanMode.design,
          editor: const FloorPlanEditorBar(actions: [
            FloorPlanEditorAction.print,
            FloorPlanEditorAction.undo
          ]),
          service: const FloorPlanServiceBar(actions: [
            FloorPlanServiceAction.redo,
            FloorPlanServiceAction.undo,
            FloorPlanServiceAction.merge,
            FloorPlanServiceAction.export,
            FloorPlanServiceAction.split
          ]));
      expect(edgesOf(tester, kEditorKeys).keys,
          ['toolbar-print', 'toolbar-undo', 'status-text']);
      expect(left(tester, 'toolbar-undo'), right(tester, 'toolbar-print') + 12);
      h.c.setMode(FloorPlanMode.selection);
      await tester.pump();
      await tester.pump();
      expect(left(tester, 'service-redo'), 12);
      expect(left(tester, 'service-undo'), right(tester, 'service-redo'));
      expect(left(tester, 'service-merge'), right(tester, 'service-undo') + 8);
      expect(
          left(tester, 'service-export'), right(tester, 'service-merge') + 8);
      expect(
          left(tester, 'service-split'), right(tester, 'service-export') + 8);
      expect(byKey('service-print'), findsNothing);
    });

    testWidgets(
        "today's rules inside the subset: without onExport no Export, "
        'without the callbacks no Merge or Split, whatever the actions',
        (tester) async {
      await mountHost(tester,
          export: false,
          groups: false,
          service: const FloorPlanServiceBar(actions: [
            FloorPlanServiceAction.export,
            FloorPlanServiceAction.merge,
            FloorPlanServiceAction.split,
            FloorPlanServiceAction.print
          ]));
      expect(edgesOf(tester, kServiceKeys), {'service-print': 12.0});
    });

    testWidgets(
        "a bare shell's other file commands come first, as today: [undo, "
        'redo, print] -> New to Save As, 12, Undo, Redo, 12, Print; no '
        'Export', (tester) async {
      final on = ValueNotifier(true);
      addTearDown(on.dispose);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: PlannerShell(
              editorBar: const FloorPlanEditorBar(actions: [
                FloorPlanEditorAction.undo,
                FloorPlanEditorAction.redo,
                FloorPlanEditorAction.print
              ]),
              fileCommands: [
            for (final id in kBareIds)
              ShellCommand(
                  id: id,
                  label: id,
                  icon: Icons.add,
                  enabled: on,
                  run: () async {}),
          ])));
      await tester.pump();
      final edges = edgesOf(tester, kBareKeys);
      expect(edges.keys, [
        'toolbar-new',
        'toolbar-open',
        'toolbar-open-sample',
        'toolbar-save',
        'toolbar-save-as',
        'toolbar-print',
        'toolbar-undo',
        'toolbar-redo',
        'status-text',
      ]);
      expect(edges['toolbar-new'], kBareEdges['toolbar-new']);
      expect(edges['toolbar-save-as'], kBareEdges['toolbar-save-as']);
      expect(
          left(tester, 'toolbar-undo'), right(tester, 'toolbar-save-as') + 12);
      expect(left(tester, 'toolbar-print'), right(tester, 'toolbar-redo') + 12);
      expect(edges['toolbar-undo']! < edges['toolbar-print']!, isTrue);
    });
  });

  group('visible: false', () {
    testWidgets(
        'the selection mode: no bar, the canvas starts at the view\'s top',
        (tester) async {
      await mountHost(tester,
          service: const FloorPlanServiceBar(visible: false));
      expect(byKey('service-bar'), findsNothing);
      expect(edgesOf(tester, kServiceKeys), isEmpty);
      expect(canvasIn(tester), Offset.zero);
      expect(tester.getSize(find.byType(InteractionLayer)),
          tester.getSize(find.byType(FloorPlanView)));
    });

    testWidgets(
        'the design mode: no top bar, the panels and the canvas start at '
        "the view's top, the tools stay in the left panel", (tester) async {
      await mountHost(tester,
          mode: FloorPlanMode.design,
          editor: const FloorPlanEditorBar(visible: false));
      expect(byKey('chrome-top'), findsNothing);
      expect(edgesOf(tester, kEditorKeys), isEmpty);
      final view = tester.getTopLeft(find.byType(FloorPlanView));
      expect(tester.getTopLeft(byKey('chrome-left')), view);
      expect(canvasIn(tester),
          const Offset(240 + kRulerThickness, kRulerThickness));
      for (final k in ['tool-select', 'tool-wall', 'tool-polyline']) {
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
        'the service bar: leading before the buttons, trailing after them, '
        "both inside the bar's height, and both reach the host's state",
        (tester) async {
      final taps = ValueNotifier(0);
      addTearDown(taps.dispose);
      final (lead, trail) = hostWidgets(taps);
      await mountHost(tester,
          service: FloorPlanServiceBar(leading: lead, trailing: trail));
      expect(left(tester, 'host-lead'), 12);
      expect(tester.getSize(byKey('host-lead')).width, 30);
      expect(left(tester, 'service-undo'), right(tester, 'host-lead'));
      expect(left(tester, 'host-trail'), right(tester, 'service-print'));
      expect(tester.getSize(byKey('host-trail')).width, 70);
      expectInBar(tester, 'host-lead', 'service-bar');
      expectInBar(tester, 'host-trail', 'service-bar');
      // The default buttons keep today's spacing, shifted by the lead.
      final shifted = {
        for (final e in kServiceEdges[(true, true, true)]!.entries)
          e.key: e.value + 30
      };
      expect(edgesOf(tester, kServiceKeys), shifted);
      await tester.tap(byKey('host-lead'));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget);
    });

    testWidgets(
        'the editor bar: leading before the toolbar, trailing after the '
        "zoom read-out, both inside the bar's height, and both reach the "
        "host's state", (tester) async {
      final taps = ValueNotifier(0);
      addTearDown(taps.dispose);
      final (lead, trail) = hostWidgets(taps);
      await mountHost(tester,
          mode: FloorPlanMode.design,
          editor: FloorPlanEditorBar(leading: lead, trailing: trail));
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
        'and W as text: the tool stays Select', (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      await mountHost(tester,
          mode: FloorPlanMode.design,
          editor: FloorPlanEditorBar(trailing: [
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
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyW), isFalse,
          reason: 'W reaches the platform as text');
      tester.testTextInput.enterText('w');
      await tester.pump();
      expect(text.text, 'w');
      expect(statusText(tester), 'Select', reason: 'W switched no tool');
      expect(await ctrl(tester, LogicalKeyboardKey.keyZ), isFalse,
          reason: 'Ctrl+Z stays in the field');
    });

    testWidgets(
        "T2-b a host TextField in the service bar's leading takes the focus: "
        'Ctrl+Z in it does not undo the plan', (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      final h = await mountHost(tester,
          service: FloorPlanServiceBar(leading: [
            SizedBox(
                width: 120,
                child:
                    TextField(key: const Key('host-field'), controller: text))
          ]));
      move(h.c, '1', 500, -300);
      await tester.pump();
      expect(h.c.canUndo.value, isTrue, reason: 'premise: a step to undo');
      final moved = centreOf(h.c, '1');
      await tester.tap(byKey('host-field'));
      await tester.pump();
      final field = tester.state<EditableTextState>(find.descendant(
          of: byKey('host-field'), matching: find.byType(EditableText)));
      expect(field.widget.focusNode.hasPrimaryFocus, isTrue);
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(centreOf(h.c, '1'), moved, reason: 'nothing undone');
      expect(h.c.canUndo.value, isTrue);
      expect(h.c.canRedo.value, isFalse);
    });
  });

  group('mergeCandidate (M-H44, T2-d, S-5)', () {
    testWidgets(
        'M-H44 the selection mode: one table, two tables sharing a number '
        'and one whole group give null; 1 and 2 give {1, 2}, what Merge '
        'sends; a group and a table outside it give their numbers; the '
        'design mode gives null', (tester) async {
      final h = await mountHost(tester);
      final c = h.c;
      final host.FloorPlanController hc = c;
      final candidate = hc.mergeCandidate;
      c.select({'1'});
      await tester.pump();
      expect(c.selectedTables.value, {'1'}, reason: 'premise');
      expect(candidate.value, isNull, reason: 'one table');
      c.select({'7'});
      await tester.pump();
      expect(c.selectedTables.value, isNotEmpty, reason: 'premise');
      expect(candidate.value, isNull, reason: '7 and " 7 ": one number');
      c.setTableGroups({
        'G': TableGroup(members: {'3', '4'})
      });
      c.select({'3', '4'});
      await tester.pump();
      expect(c.selectedGroup.value, 'G', reason: 'premise: the whole group');
      expect(candidate.value, isNull, reason: 'one group');
      c.select({'1', '3'});
      await tester.pump();
      expect(candidate.value, {'1', '3', '4'}, reason: 'a group and 1');
      c.select({'1', '2'});
      await tester.pump();
      expect(candidate.value, {'1', '2'});
      expect(() => candidate.value!.add('x'), throwsUnsupportedError);
      expect(tester.widget<IconButton>(byKey('service-merge')).onPressed,
          isNotNull);
      await tester.tap(byKey('service-merge'));
      await tester.pump();
      expect(h.merged, [
        {'1', '2'}
      ]);
      expect(h.merged.single, candidate.value);
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      c.select({'1', '2'});
      await tester.pump();
      expect(c.selectedTables.value, {'1', '2'}, reason: 'premise');
      expect(candidate.value, isNull, reason: 'the design mode');
    });

    testWidgets(
        'S-5 without onMergeRequested the candidate is still what Merge '
        'would send', (tester) async {
      final h = await mountHost(tester, groups: false);
      expect(byKey('service-merge'), findsNothing);
      h.c.select({'1', '2'});
      await tester.pump();
      expect(h.c.mergeCandidate.value, {'1', '2'});
    });

    testWidgets(
        'T2-d setTableGroups alone moves it: {1, 2} selected, a group {1, 2} '
        'set -> null; the group removed -> {1, 2}; the Merge button follows',
        (tester) async {
      final h = await mountHost(tester);
      final c = h.c;
      c.select({'1', '2'});
      await tester.pump();
      expect(c.mergeCandidate.value, {'1', '2'});
      bool mergeOn() =>
          tester.widget<IconButton>(byKey('service-merge')).onPressed != null;
      expect(mergeOn(), isTrue);
      c.setTableGroups({
        'G': TableGroup(members: {'1', '2'})
      });
      await tester.pump();
      expect(c.selectedTables.value, {'1', '2'}, reason: 'no selection change');
      expect(c.mergeCandidate.value, isNull);
      expect(mergeOn(), isFalse);
      c.setTableGroups({});
      await tester.pump();
      expect(c.mergeCandidate.value, {'1', '2'});
      expect(mergeOn(), isTrue);
    });

    testWidgets('its notifications: one per change, none for an equal set',
        (tester) async {
      final h = await mountHost(tester);
      final c = h.c;
      var heard = 0;
      void count() => heard++;
      c.mergeCandidate.addListener(count);
      addTearDown(() => c.mergeCandidate.removeListener(count));
      c.select({'1', '2'});
      expect(heard, 1);
      c.select({'2', '1'});
      expect(heard, 1, reason: 'an equal set');
      c.setTableGroups({
        'G': TableGroup(members: {'3', '4'})
      });
      expect(heard, 1, reason: 'a group that changes nothing here');
      c.select({'1', '2', '3'});
      expect(heard, 2);
      expect(c.mergeCandidate.value, {'1', '2', '3', '4'});
      c.select({'1'});
      expect(heard, 3);
      expect(c.mergeCandidate.value, isNull);
      c.select({'1'});
      c.select({});
      expect(heard, 3, reason: 'null stays null');
      await tester.pump();
    });
  });

  group('an idle Undo (S-4, T2-c)', () {
    testWidgets(
        'T2-c the Polyline tool with two points placed: undo() and redo() '
        'leave the plan and the pending shape; after Escape undo() undoes',
        (tester) async {
      final h = await mountHost(tester, mode: FloorPlanMode.design);
      final c = h.c;
      move(c, '1', 500, -300);
      move(c, '2', 200, 100);
      c.undo();
      await tester.pump();
      expect(c.canUndo.value && c.canRedo.value, isTrue,
          reason: 'premise: a step each way');
      final before = DraftDocumentCodec.encodeToString(c.activeDocument);
      final state = c.activeDocument.commands.stateId;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(statusText(tester), 'Polyline');
      for (final (x, y) in const [(40500.0, -26000.0), (41000.0, -26500.0)]) {
        await tester.tapAt(globalOf(tester, c, Vector2(x, y)));
        await tester.pump();
      }
      final tools = tester.widget<PlannerView>(find.byType(PlannerView)).tools;
      expect(tools.active.isMidShape, isTrue, reason: 'premise: part-way');
      c.undo();
      c.redo();
      await tester.pump();
      expect(c.activeDocument.commands.stateId, state);
      expect(DraftDocumentCodec.encodeToString(c.activeDocument), before);
      expect(tools.active.isMidShape, isTrue, reason: 'still pending');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(tools.active.isMidShape, isFalse, reason: 'premise: cancelled');
      expect(DraftDocumentCodec.encodeToString(c.activeDocument), before);
      final moved = centreOf(c, '1');
      c.undo();
      await tester.pump();
      expect(centreOf(c, '1'), isNot(moved), reason: 'undone');
      c.redo();
      await tester.pump();
      expect(centreOf(c, '1'), moved, reason: 'redone');
    });

    testWidgets('the selection mode is unchanged: undo() acts', (tester) async {
      final h = await mountHost(tester);
      move(h.c, '1', 500, -300);
      final moved = centreOf(h.c, '1');
      h.c.undo();
      await tester.pump();
      expect(centreOf(h.c, '1'), isNot(moved));
    });
  });

  group("a bar's actions leave the chords (S-20, T2-e)", () {
    testWidgets(
        'T2-e editor [export, print], service [print]: Ctrl+Z still undoes '
        'and Ctrl+Y redoes, in each mode', (tester) async {
      final h = await mountHost(tester,
          mode: FloorPlanMode.design,
          editor: const FloorPlanEditorBar(actions: [
            FloorPlanEditorAction.export,
            FloorPlanEditorAction.print
          ]),
          service: const FloorPlanServiceBar(
              actions: [FloorPlanServiceAction.print]));
      for (final mode in [FloorPlanMode.design, FloorPlanMode.selection]) {
        h.c.setMode(mode);
        await tester.pump();
        await tester.pump();
        expect(byKey('toolbar-undo'), findsNothing);
        expect(byKey('service-undo'), findsNothing);
        final at = centreOf(h.c, '1');
        move(h.c, '1', 500, -300);
        await tester.pump();
        final moved = centreOf(h.c, '1');
        expect(await ctrl(tester, LogicalKeyboardKey.keyZ), isTrue,
            reason: '$mode');
        expect(centreOf(h.c, '1'), at, reason: '$mode: undone');
        expect(await ctrl(tester, LogicalKeyboardKey.keyY), isTrue,
            reason: '$mode');
        expect(centreOf(h.c, '1'), moved, reason: '$mode: redone');
      }
    });
  });

  group('the canvas re-measured (R-13, S-10 generalised)', () {
    /// Table 1's box centre on the screen, read in each mode of
    /// design -> selection -> design, after each switch's frames.
    Future<void> expectKept(WidgetTester tester, FloorPlanController c,
        List<FloorPlanMode> modes, String reason) async {
      final w = centreOf(c, '1');
      final at = globalOf(tester, c, w);
      for (final mode in modes) {
        c.setMode(mode);
        await tester.pump();
        await tester.pump();
        expectAt(globalOf(tester, c, w), at, '$reason: $mode');
      }
    }

    testWidgets(
        'M-H47(serviceBar) hidden from the start: the controller measured '
        "the selection canvas at the view's top, and a round trip keeps a "
        'table in place at the first switch; shown at runtime, again',
        (tester) async {
      final h = await mountHost(tester,
          mode: FloorPlanMode.design,
          service: const FloorPlanServiceBar(visible: false));
      final c = h.c;
      final design = canvasIn(tester);
      await expectKept(
          tester, c, [FloorPlanMode.selection, FloorPlanMode.design], 'hidden');
      c.setMode(FloorPlanMode.selection);
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester), Offset.zero);
      // The controller's selection origin, read by the reframing it makes
      // into the design: by (selection origin - design origin).
      final m = c.cameraController.value.worldToScreenMatrix;
      c.setMode(FloorPlanMode.design);
      final n = c.cameraController.value.worldToScreenMatrix;
      expect(n.e - m.e, closeTo(0 - design.dx, 1e-9));
      expect(n.f - m.f, closeTo(0 - design.dy, 1e-9));
      await tester.pump();
      await tester.pump();

      c.setMode(FloorPlanMode.selection);
      await tester.pump();
      await tester.pump();
      h.service = const FloorPlanServiceBar();
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester), const Offset(0, kServiceBarHeight));
      await expectKept(
          tester, c, [FloorPlanMode.design, FloorPlanMode.selection], 'shown');
      h.service = const FloorPlanServiceBar(visible: false);
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester), Offset.zero);
      await expectKept(tester, c,
          [FloorPlanMode.design, FloorPlanMode.selection], 'hidden again');
    });

    testWidgets(
        'T2-f the editor bar hidden at runtime with the plan unchanged, '
        'then design -> selection -> design: a table keeps its place; shown '
        'again, the same', (tester) async {
      final h = await mountHost(tester, mode: FloorPlanMode.design);
      final c = h.c;
      h.editor = const FloorPlanEditorBar(visible: false);
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester),
          const Offset(240 + kRulerThickness, kRulerThickness));
      await expectKept(
          tester, c, [FloorPlanMode.selection, FloorPlanMode.design], 'hidden');
      h.editor = const FloorPlanEditorBar();
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester),
          const Offset(240 + kRulerThickness, 44 + kRulerThickness));
      await expectKept(
          tester, c, [FloorPlanMode.selection, FloorPlanMode.design], 'shown');
    });

    testWidgets(
        'a bar of the mode not shown changed: the next switch keeps the '
        'table in place (the seed corrected)', (tester) async {
      final h = await mountHost(tester);
      final c = h.c;
      h.editor = const FloorPlanEditorBar(visible: false);
      await tester.pump();
      await tester.pump();
      await expectKept(tester, c,
          [FloorPlanMode.design, FloorPlanMode.selection], 'editor hidden');
    });
  });
}
