// Ported from jet_cad_floor_plan/test/host/bars_test.dart; assertions
// unchanged.
//
// Ports the service parts Part A owns: BC1 (all eight cases); BT1's service
// half (the 16 FloorPlanServiceBar / FloorPlanServiceAction expects, through
// the barrel, `host.`); BT2's service case; M-H40's
// service test; the service half of "the editor bar [print, undo] ... the
// service bar [redo, undo, merge, export, split]"; "today's rules inside the
// subset"; "the selection mode: no bar, the canvas starts at the view's
// top"; "the service bar: leading before the buttons ..."; T2-b's service
// test; the mergeCandidate group (M-H44, S-5, T2-d, "its notifications");
// T2-c "the selection mode is unchanged: undo() acts"; T2-e's service half;
// R-5 "a host TextField in the service bar's trailing". The group "the
// canvas re-measured", the R-3 tests and K1 are Part B's
// (test/editor/editor_modes_test.dart). Not ported (2a's or
// design-only): BC2, BC3, BT1's editor half, BT2's editor case, M-H40's
// editor test, "a bare shell's other file commands", the design halves.
//
// Host embedding API spec C-1 and C-3's merge (2b spec S4 "The service
// bar"): the service bar a host may hide, reorder, cut down or extend;
// `mergeCandidate`; on the embedding fixture (turned, mirrored, scaled units
// 40 m off the origin, two units sharing a label) under `embeddingCamera()`.
// The default bar's left edges were read on today's base (BC); every other
// expected place is computed here from the widgets' own sizes or from the
// camera's forward transform.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' as host;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_state.dart';
import 'package:jet_cad_2d_plan/src/service/view/plan_service_bar.dart';
import 'package:jet_cad_2d_plan/src/service/view/plan_service_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../support/service_fixtures.dart';
import '../../support/service_host.dart'
    show byKey, pumpService, serviceController;

const List<String> kServiceKeys = [
  'service-undo',
  'service-redo',
  'service-guides',
  'service-merge',
  'service-split',
  'service-export',
  'service-print',
];

Map<String, double> edgesOf(WidgetTester tester, List<String> keys) => {
      for (final k in keys)
        if (byKey(k).evaluate().isNotEmpty) k: tester.getTopLeft(byKey(k)).dx,
    };

Future<PlanController> mountBars(WidgetTester tester,
    {bool export = true, bool merge = false, bool split = false}) async {
  final c = serviceController();
  await pumpService(
      tester,
      c,
      PlanServiceView(
          controller: c,
          onExport: export ? (_) {} : null,
          onMergeRequested: merge ? (_) {} : null,
          onSplitRequested: split ? (_) {} : null));
  return c;
}

/// Every left edge of the default service bar, read on today's base
/// (`ffe0b9c`) at 1440 x 900, per (onExport, Merge, Split); the alignment
/// guides' toggle (task 9b) sits after Redo, 48 px wide, and moves what
/// follows it by that.
const Map<(bool, bool, bool), Map<String, double>> kServiceEdges = {
  (true, true, true): {
    'service-undo': 12,
    'service-redo': 60,
    'service-guides': 108,
    'service-merge': 164,
    'service-split': 212,
    'service-export': 268,
    'service-print': 316,
  },
  (true, true, false): {
    'service-undo': 12,
    'service-redo': 60,
    'service-guides': 108,
    'service-merge': 164,
    'service-export': 220,
    'service-print': 268,
  },
  (true, false, true): {
    'service-undo': 12,
    'service-redo': 60,
    'service-guides': 108,
    'service-split': 164,
    'service-export': 220,
    'service-print': 268,
  },
  (true, false, false): {
    'service-undo': 12,
    'service-redo': 60,
    'service-guides': 108,
    'service-export': 164,
    'service-print': 212,
  },
  (false, true, true): {
    'service-undo': 12,
    'service-redo': 60,
    'service-guides': 108,
    'service-merge': 164,
    'service-split': 212,
    'service-print': 268,
  },
  (false, true, false): {
    'service-undo': 12,
    'service-redo': 60,
    'service-guides': 108,
    'service-merge': 164,
    'service-print': 220,
  },
  (false, false, true): {
    'service-undo': 12,
    'service-redo': 60,
    'service-guides': 108,
    'service-split': 164,
    'service-print': 220,
  },
  (false, false, false): {
    'service-undo': 12,
    'service-redo': 60,
    'service-guides': 108,
    'service-print': 164,
  },
};

/// The bar the host rebuilds its view with, and what it heard.
final class BarHost {
  BarHost(this.c, PlanServiceBar service) : bars = ValueNotifier(service);

  final PlanController c;
  final ValueNotifier<PlanServiceBar> bars;

  /// The sets `onMergeRequested` received.
  final List<Set<String>> merged = [];

  set service(PlanServiceBar bar) => bars.value = bar;
}

/// [embeddingPlanJson] in service under a view whose bar a [BarHost]
/// rebuilds; Export, Merge and Split offered unless told otherwise.
Future<BarHost> mountHost(WidgetTester tester,
    {PlanServiceBar service = const PlanServiceBar(),
    bool export = true,
    bool groups = true}) async {
  final c = serviceController();
  final h = BarHost(c, service);
  addTearDown(h.bars.dispose);
  c.setMode(PlanMode.service);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ValueListenableBuilder(
              valueListenable: h.bars,
              builder: (_, bar, __) => PlanServiceView(
                  controller: c,
                  onExport: export ? (_) {} : null,
                  onMergeRequested: groups ? h.merged.add : null,
                  onSplitRequested: groups ? (_) {} : null,
                  bar: bar)))));
  await tester.pump();
  await tester.pump();
  c.camera.value = embeddingCamera();
  await tester.pump();
  return h;
}

/// Where the shown canvas starts in the view.
Offset canvasIn(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer)) -
    tester.getTopLeft(find.byType(PlanServiceView));

/// The world centre of unit [n]'s box in the active plan, by the
/// fixture's own transform of [embeddingBox]'s centre.
Vector2 centreOf(PlanController c, String n) {
  final d = c.activeDocument;
  final node =
      d.tree[c.unitIndex.withLabel(n).single.instance]! as InstanceNode;
  return node.transform.transformPoint(Vector2(700, 100));
}

/// Moves unit [n] of the active plan by (dx, dy) mm, one command.
void move(PlanController c, String n, double dx, double dy) {
  final d = c.activeDocument;
  final node =
      d.tree[c.unitIndex.withLabel(n).single.instance]! as InstanceNode;
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

double left(WidgetTester tester, String k) => tester.getTopLeft(byKey(k)).dx;
double right(WidgetTester tester, String k) => tester.getTopRight(byKey(k)).dx;

void main() {
  group('BC the default bars, characterized on the base (T2-a)', () {
    for (final MapEntry(key: (export, merge, split), value: want)
        in kServiceEdges.entries) {
      testWidgets(
          'BC1 the service bar, onExport $export, Merge $merge, Split '
          '$split: every left edge as on the base', (tester) async {
        await mountBars(tester, export: export, merge: merge, split: split);
        expect(edgesOf(tester, kServiceKeys), want);
      });
    }
  });

  group('the types', () {
    test(
        'BT1 the four names through the barrel alone: ==, hashCode, '
        'toString naming what differs from the default; the enums in '
        "today's left-to-right order (S-2)", () {
      expect(host.PlanServiceAction.values.map((a) => a.name),
          ['undo', 'redo', 'guides', 'merge', 'split', 'export', 'print']);
      const a = Text('a'), b = Text('b');
      const service = host.PlanServiceBar();
      expect(service.visible, isTrue);
      expect(service.actions, host.PlanServiceAction.values);
      expect(service.leading, isEmpty);
      expect(service.trailing, isEmpty);
      expect(service, const host.PlanServiceBar());
      expect(
          host.PlanServiceBar(actions: List.of(host.PlanServiceAction.values)),
          service,
          reason: 'equal lists, not the same list');
      expect(service.hashCode, const host.PlanServiceBar().hashCode);
      expect(service.toString(), 'PlanServiceBar()');
      final variants = <host.PlanServiceBar>[
        const host.PlanServiceBar(visible: false),
        const host.PlanServiceBar(actions: [
          host.PlanServiceAction.print,
          host.PlanServiceAction.undo
        ]),
        const host.PlanServiceBar(leading: [a]),
        const host.PlanServiceBar(trailing: [a]),
      ];
      for (final v in variants) {
        expect(v, isNot(service), reason: '$v');
      }
      expect(const host.PlanServiceBar(leading: [a]),
          isNot(const host.PlanServiceBar(leading: [b])));
      expect(const host.PlanServiceBar(leading: [a]),
          const host.PlanServiceBar(leading: [a]));
      expect(const host.PlanServiceBar(leading: [a]).hashCode,
          const host.PlanServiceBar(leading: [a]).hashCode);
      expect(variants[0].toString(), 'PlanServiceBar(visible: false)');
      expect(variants[1].toString(), 'PlanServiceBar(actions: [print, undo])');
      expect(variants[2].toString(), 'PlanServiceBar(leading: [Text])');
    });

    for (final (name, service) in [
      (
        'the service bar',
        const PlanServiceBar(actions: [
          PlanServiceAction.undo,
          PlanServiceAction.print,
          PlanServiceAction.undo
        ]),
      ),
    ]) {
      testWidgets(
          'BT2 $name listing an action twice is an ArgumentError naming '
          'actions, in either mode', (tester) async {
        // The view alone shows the service mode only.
        for (final mode in [PlanMode.service]) {
          final c = serviceController();
          c.setMode(mode);
          await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                  body: PlanServiceView(controller: c, bar: service))));
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
          service: const PlanServiceBar(
              actions: [PlanServiceAction.print, PlanServiceAction.undo]));
      expect(edgesOf(tester, kServiceKeys).keys,
          ['service-undo', 'service-print']);
      expect(left(tester, 'service-print'), 12);
      expect(left(tester, 'service-undo'), right(tester, 'service-print') + 8);
    });

    testWidgets(
        'the editor bar [print, undo]: a file button and an edit button '
        '12 px apart; the service bar [redo, undo, merge, export, split]: '
        '8 px at each change of group', (tester) async {
      await mountHost(tester,
          service: const PlanServiceBar(actions: [
            PlanServiceAction.redo,
            PlanServiceAction.undo,
            PlanServiceAction.merge,
            PlanServiceAction.export,
            PlanServiceAction.split
          ]));
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
          service: const PlanServiceBar(actions: [
            PlanServiceAction.export,
            PlanServiceAction.merge,
            PlanServiceAction.split,
            PlanServiceAction.print
          ]));
      expect(edgesOf(tester, kServiceKeys), {'service-print': 12.0});
    });
  });

  group('visible: false', () {
    testWidgets(
        'the selection mode: no bar, the canvas starts at the view\'s top',
        (tester) async {
      await mountHost(tester, service: const PlanServiceBar(visible: false));
      expect(byKey('service-bar'), findsNothing);
      expect(edgesOf(tester, kServiceKeys), isEmpty);
      expect(canvasIn(tester), Offset.zero);
      expect(tester.getSize(find.byType(InteractionLayer)),
          tester.getSize(find.byType(PlanServiceView)));
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
          service: PlanServiceBar(leading: lead, trailing: trail));
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
        "T2-b a host TextField in the service bar's leading takes the focus: "
        'Ctrl+Z in it does not undo the plan', (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      final h = await mountHost(tester,
          service: PlanServiceBar(leading: [
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
      final host.PlanController hc = c;
      final candidate = hc.mergeCandidate;
      c.select({'1'});
      await tester.pump();
      expect(c.selectedUnits.value, {'1'}, reason: 'premise');
      expect(candidate.value, isNull, reason: 'one table');
      c.select({'7'});
      await tester.pump();
      expect(c.selectedUnits.value, isNotEmpty, reason: 'premise');
      expect(candidate.value, isNull, reason: '7 and " 7 ": one number');
      c.setUnitGroups({
        'G': UnitGroup(members: {'3', '4'})
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
      c.setMode(PlanMode.design);
      await tester.pump();
      c.select({'1', '2'});
      await tester.pump();
      expect(c.selectedUnits.value, {'1', '2'}, reason: 'premise');
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
      c.setUnitGroups({
        'G': UnitGroup(members: {'1', '2'})
      });
      await tester.pump();
      expect(c.selectedUnits.value, {'1', '2'}, reason: 'no selection change');
      expect(c.mergeCandidate.value, isNull);
      expect(mergeOn(), isFalse);
      c.setUnitGroups({});
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
      c.setUnitGroups({
        'G': UnitGroup(members: {'3', '4'})
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
          service: const PlanServiceBar(actions: [PlanServiceAction.print]));
      // The service half: the view alone shows the service mode only.
      for (final mode in [PlanMode.service]) {
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

  group('the review fixes (s4-task-2-review R-2, R-3, R-5)', () {
    testWidgets(
        "R-5 a host TextField in the service bar's trailing: Ctrl+Z stays in "
        'the field (the guard covers the whole row)', (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      final h = await mountHost(tester,
          service: PlanServiceBar(trailing: [
            SizedBox(
                width: 120,
                child:
                    TextField(key: const Key('host-field'), controller: text))
          ]));
      move(h.c, '1', 500, -300);
      await tester.pump();
      final moved = centreOf(h.c, '1');
      await tester.tap(byKey('host-field'));
      await tester.pump();
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(centreOf(h.c, '1'), moved, reason: 'nothing undone');
      expect(h.c.canRedo.value, isFalse);
    });
  });
}
