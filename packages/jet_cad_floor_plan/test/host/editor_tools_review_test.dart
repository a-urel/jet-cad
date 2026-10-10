// Slice 4 Task 4 review's killers (R-1 to R-4): the symbol tool's stored
// turn and mirror bounded by the capabilities, a runtime rulers change with
// a tool active, the reviewer's probes RV4 to RV9, the Symbols tab, the
// grips' snapping, the empty toolbar, a host's own tools set and a filter
// offering nothing. Through `FloorPlanView` on the editor fixture under
// `editorCamera()`, with `editor_tools_test.dart`'s host and helpers.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey, SymbolGallery, Tool;
import 'package:jet_cad_floor_plan/editor.dart'
    show DocumentToolbar, PlannerView;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_floor_plan/src/parametric/dimension.dart'
    show DimensionParams;
import 'package:jet_cad_floor_plan/src/parametric/dimension_geometry.dart'
    show AttachedEnd, FixedEnd;
import 'package:jet_cad_floor_plan/src/parametric/opening.dart'
    show OpeningParams;
import 'package:jet_cad_floor_plan/src/symbols/symbol_place_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_fixture.dart';
import 'editor_tools_test.dart' as t;

typedef Caps = FloorPlanEditorCapabilities;

double det(Transform2 m) => m.a * m.d - m.b * m.c;

/// Clicks world [w] and answers the one instance it placed.
Future<InstanceNode> place(
    WidgetTester tester, FloorPlanController c, Vector2 w) async {
  final before = t.instancesOf(c.activeDocument);
  await t.click(tester, t.screenOf(tester, c, w));
  final added = t.instancesOf(c.activeDocument).difference(before);
  expect(added, hasLength(1), reason: 'one placement at $w');
  return c.activeDocument.tree[added.single]! as InstanceNode;
}

/// The canvas's active tool.
Tool activeTool(WidgetTester tester) =>
    tester.widget<InteractionLayer>(find.byType(InteractionLayer)).tools.active;

/// Whether the bar's Undo button is enabled.
bool undoEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(t.byKey('toolbar-undo')).onPressed != null;

/// A mouse resting at world [w] (a hover, no press).
Future<TestGesture> hover(
    WidgetTester tester, FloorPlanController c, Vector2 w) async {
  final at = t.screenOf(tester, c, w);
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: at - const Offset(3, 3));
  await g.moveTo(at);
  await tester.pump();
  return g;
}

/// A mouse drag from world [from] to world [to], through a move off it.
Future<void> drag(WidgetTester tester, FloorPlanController c, Vector2 from,
    Vector2 to) async {
  final g = await tester.startGesture(t.screenOf(tester, c, from),
      kind: ui.PointerDeviceKind.mouse);
  await tester.pump();
  await g.moveTo(t.screenOf(tester, c, to) + const Offset(0, 0.5));
  await tester.pump();
  await g.moveTo(t.screenOf(tester, c, to));
  await tester.pump();
  await g.up();
  await tester.pump();
}

/// The page's grid snap off, outside the history: a drop is the raw point.
void gridSnapOff(DraftDocument d) {
  d.commands.execute(SetComponentCommand<PageComponent>(
      d.rootHandle, t.pageOf(d).copyWith(snapToGrid: false)));
  d.commands.clearHistory();
}

/// A line drawn and finished: one undo step, so Undo has something to do.
Future<void> drawLine(WidgetTester tester, FloorPlanController c) async {
  await t.press(tester, LogicalKeyboardKey.keyL);
  await t.click(tester, t.screenOf(tester, c, Vector2(24200, 13600)));
  await t.click(tester, t.screenOf(tester, c, Vector2(25000, 13600)));
  await t.press(tester, LogicalKeyboardKey.escape);
  await t.press(tester, LogicalKeyboardKey.escape);
}

/// The root group carrying a component [T] that [test] accepts.
Handle groupWith<T extends Component>(DraftDocument d, bool Function(T) test) =>
    d.tree.nodes.whereType<GroupNode>().singleWhere((n) {
      final p = d.components.get<T>(n.handle);
      return p != null && test(p);
    }).handle;

void main() {
  group('R-1: the stored turn and mirror under the capabilities', () {
    testWidgets(
        'RV1 full, a table armed, M, then tablesOnly: still armed, the '
        'placement unmirrored; full again: the stored mirror returns',
        (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await t.openSymbols(tester, c);
      await t.arm(tester, 'dining.table.square.two');
      await t.press(tester, LogicalKeyboardKey.keyM);
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.symbol);
      final a = await place(tester, c, Vector2(24700, 14000));
      expect(det(a.transform), greaterThan(0));
      expect(a.transform.a, closeTo(1, 1e-9));
      h.caps.value = Caps.full;
      await tester.pump();
      final b = await place(tester, c, Vector2(22200, 13300));
      expect(det(b.transform), lessThan(0));
    });

    testWidgets(
        'RV2 full, a table armed, M, Escape; tablesOnly, the table armed '
        'again: unmirrored; full, armed again: mirrored', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await t.openSymbols(tester, c);
      await t.arm(tester, 'dining.table.square.two');
      await t.press(tester, LogicalKeyboardKey.keyM);
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(c.activeTool.value, FloorPlanTool.select);
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      await t.arm(tester, 'dining.table.square.two');
      final a = await place(tester, c, Vector2(24700, 14000));
      expect(det(a.transform), greaterThan(0));
      await t.press(tester, LogicalKeyboardKey.escape);
      h.caps.value = Caps.full;
      await tester.pump();
      await t.arm(tester, 'dining.table.square.two');
      final b = await place(tester, c, Vector2(22200, 13300));
      expect(det(b.transform), lessThan(0));
    });

    testWidgets(
        'RV3 full, a table armed, R, then tablesOnly without rotate: the '
        'placement unturned', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await t.openSymbols(tester, c);
      await t.arm(tester, 'dining.table.square.two');
      await t.press(tester, LogicalKeyboardKey.keyR);
      h.caps.value = Caps.tablesOnly.copyWith(rotate: false);
      await tester.pump();
      final a = await place(tester, c, Vector2(24700, 14000));
      expect(a.transform.a, closeTo(1, 1e-9));
      expect(a.transform.b, closeTo(0, 1e-9));
    });

    testWidgets(
        'the ghost follows the gates at the change, with no pointer event: '
        'mirrored under full, not under tablesOnly, mirrored again; turned, '
        'not without rotate, turned again', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await t.openSymbols(tester, c);
      await t.arm(tester, 'dining.table.square.two');
      final g = await hover(tester, c, Vector2(24700, 14000));
      await t.press(tester, LogicalKeyboardKey.keyM);
      final tool = activeTool(tester) as SymbolPlaceTool;
      expect(tool.ghostVisible, isTrue);
      expect(det(tool.ghostPlacement!), lessThan(0));
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      expect(det(tool.ghostPlacement!), greaterThan(0));
      expect(tool.mirrored, isTrue, reason: 'the stored mirror is kept');
      h.caps.value = Caps.full;
      await tester.pump();
      expect(det(tool.ghostPlacement!), lessThan(0));

      // The turn likewise: R under full, then rotate false, then full.
      await t.press(tester, LogicalKeyboardKey.keyM);
      await t.press(tester, LogicalKeyboardKey.keyR);
      expect(tool.ghostPlacement!.a, closeTo(0, 1e-9));
      expect(tool.ghostPlacement!.b, closeTo(1, 1e-9));
      h.caps.value = Caps.full.copyWith(rotate: false);
      await tester.pump();
      expect(tool.ghostPlacement!.a, closeTo(1, 1e-9));
      expect(tool.ghostPlacement!.b, closeTo(0, 1e-9));
      expect(tool.quarterTurns, 1, reason: 'the stored turn is kept');
      h.caps.value = Caps.full;
      await tester.pump();
      expect(tool.ghostPlacement!.a, closeTo(0, 1e-9));
      expect(tool.ghostPlacement!.b, closeTo(1, 1e-9));
      await g.removePointer();
    });

    testWidgets(
        'a symbol against the north wall: M under full, then mirror false: '
        'it attaches as an unmirrored one does; full: mirrored',
        (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      final d = c.activeDocument;
      await t.openSymbols(tester, c);
      await tester.enterText(t.byKey('symbol-search'), 'toilet');
      await tester.pump();
      await t.arm(tester, 'bath.toilet');
      // 20 mm below the north wall's inner face (16,750), clear of 1 and 2.
      final at = Vector2(24200, 16730);
      final control = await place(tester, c, at);
      final want = control.transform;
      // Attached: its base point is not the click's, as a free one's is.
      expect(Vector2(want.e, want.f).distanceTo(at), greaterThan(1),
          reason: 'premise: the control attaches');
      d.commands.undo();
      await tester.pump();
      await t.press(tester, LogicalKeyboardKey.keyM);
      h.caps.value = Caps.full.copyWith(mirror: false);
      await tester.pump();
      final kept = await place(tester, c, at);
      expect(kept.transform.toJson(), want.toJson());
      d.commands.undo();
      await tester.pump();
      h.caps.value = Caps.full;
      await tester.pump();
      final mirrored = await place(tester, c, at);
      expect(det(mirrored.transform), lessThan(0));
      expect(det(want), greaterThan(0));
    });
  });

  group('R-2: rulers changed at runtime with a tool active', () {
    testWidgets(
        'Wall part-way: rulers off and on throw nothing; the wall is '
        'cancelled cleanly and Undo enabled after the frame; the tool '
        'starts afresh', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      final d = c.activeDocument;
      await drawLine(tester, c);
      await t.press(tester, LogicalKeyboardKey.keyW);
      await t.click(tester, t.screenOf(tester, c, Vector2(24200, 14400)));
      expect(undoEnabled(tester), isFalse, reason: 'premise: mid-shape');
      final depth = d.commands.undoDepth;
      for (final rulers in [false, true]) {
        h.caps.value = Caps.full.copyWith(rulers: rulers);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'rulers $rulers');
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'rulers $rulers');
        expect(undoEnabled(tester), isTrue, reason: 'rulers $rulers');
        expect(c.activeTool.value, FloorPlanTool.wall);
        expect(t.statusText(tester), 'Wall');
        // A fresh start: one click is a first point, nothing added.
        await t.click(tester, t.screenOf(tester, c, Vector2(24200, 14400)));
        expect(d.commands.undoDepth, depth, reason: 'rulers $rulers');
        expect(undoEnabled(tester), isFalse);
      }
      await t.click(tester, t.screenOf(tester, c, Vector2(25000, 14400)));
      expect(d.commands.undoDepth, depth + 1);
    });

    testWidgets(
        'Line idle, the select tool hovering a line, a symbol\'s ghost '
        'shown: rulers off and on throw nothing', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      Future<void> toggle(String label, FloorPlanTool tool) async {
        for (final rulers in [false, true]) {
          h.caps.value = Caps.full.copyWith(rulers: rulers);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$label $rulers');
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$label $rulers');
          expect(c.activeTool.value, tool, reason: label);
        }
      }

      await t.press(tester, LogicalKeyboardKey.keyL);
      await toggle('line', FloorPlanTool.line);
      await t.press(tester, LogicalKeyboardKey.escape);

      final (a, b) = editorFreeLine;
      final over = await hover(tester, c, (a + b) / 2);
      await toggle('hover', FloorPlanTool.select);
      await over.removePointer();

      await t.openSymbols(tester, c);
      await t.arm(tester, 'dining.table.square.two');
      final ghost = await hover(tester, c, Vector2(24700, 14000));
      await toggle('symbol', FloorPlanTool.symbol);
      await ghost.removePointer();
    });

    testWidgets(
        'a fallback at runtime, a wall part-way: Undo enabled after that '
        'one pump', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await drawLine(tester, c);
      await t.press(tester, LogicalKeyboardKey.keyW);
      await t.click(tester, t.screenOf(tester, c, Vector2(24200, 14400)));
      expect(undoEnabled(tester), isFalse, reason: 'premise: mid-shape');
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(undoEnabled(tester), isTrue);
    });
  });

  group('R-3: the reviewer\'s probes and the survivors', () {
    testWidgets(
        'RV4 a table armed, then symbolPalette false (tools keep symbol): '
        'select, and a click places nothing', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await t.openSymbols(tester, c);
      await t.arm(tester, 'dining.table.square.two');
      expect(c.activeTool.value, FloorPlanTool.symbol);
      h.caps.value = Caps.full.copyWith(symbolPalette: false);
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      final before = t.instancesOf(c.activeDocument);
      await t.click(tester, t.screenOf(tester, c, Vector2(24700, 14000)));
      expect(t.instancesOf(c.activeDocument), before);
    });

    testWidgets('RV5 a chair armed, then the filter alone changes: select',
        (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await t.openSymbols(tester, c);
      await t.arm(tester, 'dining.chair');
      expect(c.activeTool.value, FloorPlanTool.symbol);
      h.caps.value =
          Caps.full.copyWith(symbolFilter: Caps.tablesOnly.symbolFilter);
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
    });

    testWidgets(
        'RV6 the view unmounted with Wall active: activeTool select, '
        'selectTool false', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await t.press(tester, LogicalKeyboardKey.keyW);
      expect(c.activeTool.value, FloorPlanTool.wall);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(c.selectTool(FloorPlanTool.wall), isFalse);
    });

    testWidgets(
        'RV7 tools {select, circle}: the Fill row, and F is the shell\'s; '
        '{select, line}: neither, F reaches the host', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.full
              .copyWith(tools: {FloorPlanTool.select, FloorPlanTool.circle}));
      expect(t.byKey('tool-fill'), findsOneWidget);
      await t.press(tester, LogicalKeyboardKey.keyF);
      expect(h.reached['fill'], 0);
      h.caps.value =
          Caps.full.copyWith(tools: {FloorPlanTool.select, FloorPlanTool.line});
      await tester.pump();
      expect(t.byKey('tool-fill'), findsNothing);
      await t.press(tester, LogicalKeyboardKey.keyF);
      expect(h.reached['fill'], 1);
    });

    testWidgets(
        'RV8 tools {select, symbol} with symbolPalette false: no left '
        'column', (tester) async {
      await t.mountEditor(tester,
          caps: Caps.tablesOnly.copyWith(symbolPalette: false));
      expect(t.byKey('chrome-left'), findsNothing);
    });

    testWidgets(
        'RV9 print and undo false: no Print, no Undo or Redo; Ctrl+Z '
        'reaches the host and undoes nothing', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.full.copyWith(print: false, undo: false));
      expect(t.byKey('toolbar-print'), findsNothing);
      expect(t.byKey('toolbar-export'), findsOneWidget);
      expect(t.byKey('toolbar-undo'), findsNothing);
      expect(t.byKey('toolbar-redo'), findsNothing);
      final d = h.c.activeDocument;
      final depth = d.commands.undoDepth;
      await drawLine(tester, h.c);
      expect(d.commands.undoDepth, depth + 1);
      await t.ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(d.commands.undoDepth, depth + 1);
      expect(h.reached['ctrl+z'], 1);
    });

    testWidgets(
        'O22 symbolPalette false with the symbol tool still in tools: no '
        'Symbols tab, the column holds the palette', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.full.copyWith(symbolPalette: false));
      expect(t.byKey('chrome-left'), findsOneWidget);
      expect(t.byKey('tab-symbols'), findsNothing);
      expect(t.byKey('left-tabs'), findsNothing);
      expect(t.byKey('tool-wall'), findsOneWidget);
      h.caps.value = Caps.full;
      await tester.pump();
      expect(t.byKey('tab-symbols'), findsOneWidget);
    });

    testWidgets(
        'O13a snapping false: a dimension\'s end grip dropped exactly on a '
        'wall\'s end corner stays a fixed end; under full it attaches',
        (tester) async {
      for (final snapping in [false, true]) {
        final h = await t.mountEditor(tester,
            caps: Caps.full.copyWith(snapping: snapping));
        final c = h.c;
        final d = c.activeDocument;
        gridSnapOff(d);
        // The overall depth, beyond the east wall: its north end at the
        // flat's outer corner (26,000, 17,000).
        final dim = groupWith<DimensionParams>(
            d, (p) => p.offset == -300 && p.a is AttachedEnd);
        final view = tester.widget<PlannerView>(find.byType(PlannerView));
        view.selection.replace([SelectionKey.root(dim)]);
        await tester.pump();
        expect(
            view.grips!.grips
                .any((r) => r.grip.x == 26000 && r.grip.y == 17000),
            isTrue,
            reason: 'premise: the end grip');
        await drag(tester, c, Vector2(26000, 17000), editorColumnCorner);
        final end = d.components.get<DimensionParams>(dim)!.b;
        if (snapping) {
          expect(end, isA<AttachedEnd>());
        } else {
          expect(end, isA<FixedEnd>());
          final p = (end as FixedEnd).point;
          expect(p.distanceTo(editorColumnCorner), lessThan(1e-6));
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
        'O13b snapping false: the east window\'s slide grip dropped 15 mm '
        'short of its stretch\'s end stores the projection; under full it '
        'snaps to the end', (tester) async {
      for (final snapping in [false, true]) {
        final h = await t.mountEditor(tester,
            caps: Caps.full.copyWith(snapping: snapping));
        final c = h.c;
        final d = c.activeDocument;
        gridSnapOff(d);
        // The east wall runs north from y 8,125; its window, 1,800 wide,
        // centred 6,075 along it. Its north stretch ends at the inner
        // face's corner (y 16,750): a centre of at most 7,725.
        final win = groupWith<OpeningParams>(
            d, (p) => p.position == 6075 && p.width == 1800);
        final view = tester.widget<PlannerView>(find.byType(PlannerView));
        view.selection.replace([SelectionKey.root(win)]);
        await tester.pump();
        final grip = view.grips!.grips.single.grip;
        expect((grip.x, grip.y), (25875.0, 14200.0), reason: 'premise');
        // The centre 7,710: its north jamb 15 mm short of the end, inside
        // the 27 mm aperture (10 px at 0.37 px/mm).
        await drag(tester, c, Vector2(grip.x, grip.y), Vector2(25878, 15835));
        final stored = d.components.get<OpeningParams>(win)!.position;
        expect(stored, closeTo(snapping ? 7725 : 15835 - 8125, 1e-6));
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
        'O23 every command refused: no toolbar, and the status line starts '
        'at the bar\'s padding', (tester) async {
      await t.mountEditor(tester,
          caps: Caps.full.copyWith(export: false, print: false, undo: false));
      expect(find.byType(DocumentToolbar), findsNothing);
      expect(tester.getTopLeft(t.byKey('status-text')).dx,
          tester.getTopLeft(t.byKey('chrome-top')).dx + 12);
    });
  });

  group('R-4', () {
    testWidgets(
        'a host\'s own set, changed after it was handed over, changes '
        'nothing; a new value from it is compared with the old one',
        (tester) async {
      final mine = {FloorPlanTool.select, FloorPlanTool.wall};
      // The constructor keeps the host's set as given. The host rebuilds
      // with setState, which compares nothing.
      var caps = Caps(tools: mine);
      late StateSetter rebuild;
      final c = FloorPlanController(json: editorPlanJson());
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(kEditorSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return FloorPlanView(controller: c, editorCapabilities: caps);
      }))));
      await tester.pump();
      await tester.pump();
      c.cameraController.value = editorCamera();
      await tester.pump();
      await t.press(tester, LogicalKeyboardKey.keyW);
      expect(c.activeTool.value, FloorPlanTool.wall);

      // Changed in place: the editor keeps what it was handed, through a
      // build of its own (a tab switch) and the host's rebuild with the
      // same value.
      mine.remove(FloorPlanTool.wall);
      await tester.tap(t.byKey('tab-symbols'));
      await tester.pump();
      await tester.tap(t.byKey('tab-tools'));
      await tester.pump();
      rebuild(() {});
      await tester.pump();
      expect(t.byKey('tool-wall'), findsOneWidget);
      expect(c.activeTool.value, FloorPlanTool.wall);

      // A new value from the changed set: compared with the copy of the
      // last, it refuses the wall, which falls back.
      rebuild(() => caps = Caps(tools: mine));
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(t.byKey('tool-wall'), findsNothing);
    });

    testWidgets(
        'a filter that offers nothing: no no-match line without a query; '
        'with one, the line names it', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.full.copyWith(symbolFilter: (_) => false));
      await t.openSymbols(tester, h.c);
      expect(find.byType(SymbolGallery), findsNothing);
      expect(t.byKey('symbol-search-empty'), findsNothing);
      await tester.enterText(t.byKey('symbol-search'), 'table');
      await tester.pump();
      expect(find.text('No symbols match "table"'), findsOneWidget);
    });
  });
}
