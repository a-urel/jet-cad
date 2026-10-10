// Host embedding API spec C-5's tools, palette and filter, C-3's
// `activeTool` / `selectTool`, the bar's flags and a runtime change (Slice
// 4 plan, Task 4; S-6, S-9 b c f, S-12 to S-14, S-22). Through
// `FloorPlanView` on the editor fixture under `editorCamera()`; a host
// `CallbackShortcuts` above the view counts every key that reaches it, and
// a host tool strip listens to `activeTool` beside the view. Screen points
// come from the camera's forward transform from the canvas's origin.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show
        InteractionLayer,
        ViewportTransform,
        PageChromePainter,
        RulerFrame,
        SymbolGallery,
        kRulerThickness;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_state.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_fixture.dart';

typedef Caps = FloorPlanEditorCapabilities;

Finder byKey(String k) => find.byKey(Key(k));

/// The palette's rows, in its order, and their letters.
const List<(String, LogicalKeyboardKey, FloorPlanTool)> kRows = [
  ('tool-select', LogicalKeyboardKey.keyV, FloorPlanTool.select),
  ('tool-line', LogicalKeyboardKey.keyL, FloorPlanTool.line),
  ('tool-polyline', LogicalKeyboardKey.keyP, FloorPlanTool.polyline),
  ('tool-rectangle', LogicalKeyboardKey.keyR, FloorPlanTool.rectangle),
  ('tool-box', LogicalKeyboardKey.keyB, FloorPlanTool.box),
  ('tool-wall', LogicalKeyboardKey.keyW, FloorPlanTool.wall),
  ('tool-door', LogicalKeyboardKey.keyD, FloorPlanTool.door),
  ('tool-window', LogicalKeyboardKey.keyN, FloorPlanTool.window),
  ('tool-gap', LogicalKeyboardKey.keyG, FloorPlanTool.gap),
  ('tool-room', LogicalKeyboardKey.keyM, FloorPlanTool.room),
  ('tool-separator', LogicalKeyboardKey.keyS, FloorPlanTool.separator),
  ('tool-dimension', LogicalKeyboardKey.keyI, FloorPlanTool.dimension),
  ('tool-circle', LogicalKeyboardKey.keyC, FloorPlanTool.circle),
  ('tool-arc', LogicalKeyboardKey.keyA, FloorPlanTool.arc),
  ('tool-text', LogicalKeyboardKey.keyT, FloorPlanTool.text),
];

/// The keys the host binds above the view, by name.
final Map<String, ShortcutActivator> kHostKeys = {
  for (final (_, key, tool) in kRows) tool.name: SingleActivator(key),
  'fill': const SingleActivator(LogicalKeyboardKey.keyF),
  'f3': const SingleActivator(LogicalKeyboardKey.f3),
  'ctrl+e': const SingleActivator(LogicalKeyboardKey.keyE, control: true),
  'ctrl+z': const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
};

/// The bundled tables (seats != null) and the other symbols the query
/// `table` finds, read on the base (`e8a21a0`) before this task changed a
/// line of `lib` (the task's report names the run).
const Set<String> kTables = {
  'dining.table.square.two',
  'dining.table.square.four',
  'dining.table.rect.four',
  'dining.table.rect.six',
  'dining.table.round',
};
const Set<String> kOtherTables = {
  'bed.nightstand',
  'table.coffee',
  'office.desk.1200',
  'office.desk',
  'office.desk.1600',
};

final class EditorHost {
  EditorHost(this.c, Caps caps) : caps = ValueNotifier(caps);

  final FloorPlanController c;
  final ValueNotifier<Caps> caps;

  /// The keys that reached the host's bindings, by name.
  final Map<String, int> reached = {for (final k in kHostKeys.keys) k: 0};

  /// The host's export dialog's calls.
  int dialogs = 0;

  /// Every value `activeTool` announced.
  final List<FloorPlanTool> announced = [];
}

final GlobalKey shotKey = GlobalKey(debugLabel: 'editor-shot');

Future<EditorHost> mountEditor(WidgetTester tester,
    {Caps caps = Caps.full,
    FloorPlanMode mode = FloorPlanMode.design,
    FloorPlanController? controller}) async {
  final c = controller ?? FloorPlanController(json: editorPlanJson());
  if (controller == null) addTearDown(c.dispose);
  c.setMode(mode);
  final h = EditorHost(c, caps);
  addTearDown(h.caps.dispose);
  void announce() => h.announced.add(c.activeTool.value);
  c.activeTool.addListener(announce);
  addTearDown(() => c.activeTool.removeListener(announce));
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: CallbackShortcuts(
    bindings: {
      for (final MapEntry(:key, :value) in kHostKeys.entries)
        value: () => h.reached[key] = h.reached[key]! + 1,
    },
    child: Column(children: [
      // The host's own tool strip: it rebuilds on every announcement.
      ValueListenableBuilder<FloorPlanTool>(
          valueListenable: c.activeTool,
          builder: (_, tool, __) =>
              Text('host: ${tool.name}', key: const Key('host-tool'))),
      Expanded(
        child: RepaintBoundary(
          key: shotKey,
          child: ValueListenableBuilder<Caps>(
              valueListenable: h.caps,
              builder: (_, caps, __) => FloorPlanView(
                  controller: c,
                  onExport: (_) {},
                  onExportDialog: (_, __) async {
                    h.dialogs++;
                    return null;
                  },
                  editorCapabilities: caps)),
        ),
      ),
    ]),
  ))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = editorCamera();
  await tester.pump();
  return h;
}

/// The shown canvas's top left, global.
Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer));

/// World [w] on the screen, by the camera's forward transform.
Offset screenOf(WidgetTester tester, FloorPlanController c, Vector2 w) {
  final p = canvasOf(c.cameraController.value, w.x, w.y);
  return canvasOrigin(tester) + Offset(p.x, p.y);
}

/// The world centre of table [n]'s box in the active plan, by the
/// fixture's own transform of [embeddingBox]'s centre.
Vector2 centreOf(FloorPlanController c, String n) {
  final d = c.activeDocument;
  final node =
      d.tree[TableSurvey.of(d).withNumber(n).single.instance]! as InstanceNode;
  return node.transform.transformPoint(Vector2(700, 100));
}

/// Whether the primary focus is the canvas's (inside its interaction
/// layer).
bool canvasFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      context.findAncestorWidgetOfExactType<InteractionLayer>() != null;
}

Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

/// Ctrl+[key], pressed and released.
Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// A mouse click at [at], with a hover first (the placement tools read it).
Future<void> click(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: at - const Offset(3, 3));
  await g.moveTo(at);
  await tester.pump();
  await g.down(at);
  await tester.pump();
  await g.up();
  await tester.pump();
  await g.removePointer();
  await tester.pump();
}

String statusText(WidgetTester tester) =>
    tester.widget<Text>(byKey('status-text')).data!;

/// Waits for the controller's symbol library.
Future<void> librarySettled(WidgetTester tester, FloorPlanController c) async {
  for (var i = 0; i < 400 && c.symbols.state is! SymbolLibraryReady; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(c.symbols.state, isA<SymbolLibraryReady>());
  await tester.pump();
}

/// Opens the Symbols tab, the library loaded.
Future<void> openSymbols(WidgetTester tester, FloorPlanController c) async {
  await tester.tap(byKey('tab-symbols'));
  await tester.pump();
  await librarySettled(tester, c);
}

/// The keys of the gallery's cells, in order (the ids without `@version`).
List<String> galleryKeys(WidgetTester tester) => [
      for (final g in tester
          .widget<SymbolGallery>(find.byType(SymbolGallery))
          .categories)
        for (final s in g.symbols) s.id.substring(0, s.id.lastIndexOf('@')),
    ];

/// Taps the gallery's cell of [key].
Future<void> arm(WidgetTester tester, String key) async {
  final cell = find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('symbol-cell-$key@'));
  expect(cell, findsOneWidget, reason: key);
  await tester.tap(cell);
  await tester.pump();
}

/// The instances of the design, by handle.
Set<Handle> instancesOf(DraftDocument d) =>
    {for (final n in d.tree.nodes.whereType<InstanceNode>()) n.handle};

/// The newest root-level line of the design: its two ends, world.
(Vector2, Vector2) newestLine(DraftDocument d) {
  final e = d.entities;
  final slot = e.liveSlots
      .where(
          (s) => e.kindAt(s) == EntityKind.line && e.ownerAt(s) == d.rootHandle)
      .reduce((a, b) => e.handleAt(a).value > e.handleAt(b).value ? a : b);
  final p = d.geometry.read(e.geomIndexAt(slot)).coords;
  return (Vector2(p[0], p[1]), Vector2(p[2], p[3]));
}

/// The design's page.
PageComponent pageOf(DraftDocument d) =>
    d.components.get<PageComponent>(d.rootHandle)!;

/// Captures the view.
Future<(ByteData, int)> shoot(WidgetTester tester) async {
  final boundary =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (raw!, width);
  }))!;
}

/// The distinct colours of the global rect [r] of [shot].
Set<int> coloursIn((ByteData, int) shot, Rect r, Offset shotOrigin) {
  final (bytes, width) = shot;
  final colours = <int>{};
  for (var y = (r.top - shotOrigin.dy).ceil();
      y < (r.bottom - shotOrigin.dy).floor();
      y++) {
    for (var x = (r.left - shotOrigin.dx).ceil();
        x < (r.right - shotOrigin.dx).floor();
        x++) {
      colours.add(bytes.getUint32((y * width + x) * 4));
    }
  }
  return colours;
}

void main() {
  group('the defaults and the profiles', () {
    testWidgets(
        'full is today\'s editor through the view: every palette row and '
        'letter, the Fill row and F, the Symbols tab with every symbol, '
        'OSNAP and F3, the rulers and the grid', (tester) async {
      final h = await mountEditor(tester);
      final c = h.c;
      expect(canvasFocused(), isTrue);
      for (final (row, _, _) in kRows) {
        expect(byKey(row), findsOneWidget, reason: row);
      }
      expect(byKey('tool-fill'), findsOneWidget);
      expect(byKey('chrome-left'), findsOneWidget);
      for (final (row, key, tool) in kRows.reversed) {
        await press(tester, key);
        expect(c.activeTool.value, tool, reason: row);
      }
      await press(tester, LogicalKeyboardKey.escape);
      expect(c.activeTool.value, FloorPlanTool.select);
      final fill = tester.widget<CheckboxListTile>(byKey('tool-fill')).value!;
      await press(tester, LogicalKeyboardKey.keyF);
      expect(tester.widget<CheckboxListTile>(byKey('tool-fill')).value, !fill);
      final osnap = tester.widget<Text>(byKey('osnap-text')).data;
      await press(tester, LogicalKeyboardKey.f3);
      expect(tester.widget<Text>(byKey('osnap-text')).data, isNot(osnap));
      // No key reached the host.
      expect(h.reached.values.every((n) => n == 0), isTrue,
          reason: '${h.reached}');
      for (final k in [
        'toolbar-export',
        'toolbar-print',
        'toolbar-undo',
        'toolbar-redo',
        'zoom-text'
      ]) {
        expect(byKey(k), findsOneWidget, reason: k);
      }
      expect(find.byType(RulerFrame), findsOneWidget);
      expect(
          tester
              .widget<CustomPaint>(find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is PageChromePainter))
              .painter,
          isA<PageChromePainter>().having((p) => p.grid, 'grid', isTrue));
      await openSymbols(tester, c);
      final library = (c.symbols.state as SymbolLibraryReady).library;
      expect(galleryKeys(tester), [for (final e in library.entries) e.key]);
    });

    testWidgets(
        'tablesOnly: the Tools tab shows Select alone and no Fill row; a '
        'table armed from the Symbols tab places a numbered table; readOnly: '
        'no Symbols tab, no left column (T4-a)', (tester) async {
      final h = await mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      expect(byKey('chrome-left'), findsOneWidget);
      expect(byKey('tab-tools'), findsOneWidget);
      expect(byKey('tab-symbols'), findsOneWidget);
      expect(byKey('tool-select'), findsOneWidget);
      for (final (row, _, _) in kRows.skip(1)) {
        expect(byKey(row), findsNothing, reason: row);
      }
      expect(byKey('tool-fill'), findsNothing);
      await openSymbols(tester, c);
      final before = TableSurvey.of(c.activeDocument).tables.length;
      await arm(tester, 'dining.table.square.two');
      expect(c.activeTool.value, FloorPlanTool.symbol);
      await click(tester, screenOf(tester, c, Vector2(24800, 13900)));
      final after = TableSurvey.of(c.activeDocument).tables;
      expect(after.length, before + 1);
      expect(after.last.number, isNotNull);

      h.caps.value = Caps.readOnly;
      await tester.pump();
      await tester.pump();
      expect(byKey('chrome-left'), findsNothing);
      expect(byKey('tab-symbols'), findsNothing);
      expect(byKey('tool-fill'), findsNothing);
      expect(byKey('tool-select'), findsNothing);
      expect(c.activeTool.value, FloorPlanTool.select);
    });

    testWidgets(
        'editorCapabilities leaves the selection mode as it is: under '
        'readOnly a service drag still moves a table and Undo still undoes '
        'it (S-22)', (tester) async {
      final h = await mountEditor(tester,
          caps: Caps.readOnly, mode: FloorPlanMode.selection);
      final c = h.c;
      expect(byKey('service-undo'), findsOneWidget);
      final w = centreOf(c, '1');
      final at = screenOf(tester, c, w);
      final g = await tester.startGesture(at);
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(30, 20));
      await g.up();
      await tester.pump();
      final moved = centreOf(c, '1');
      expect(moved.x, closeTo(w.x + 60 / 0.37, 1e-6));
      expect(moved.y, closeTo(w.y - 20 / 0.37, 1e-6));
      expect(c.canUndo.value, isTrue);
      await tester.tap(byKey('service-undo'));
      await tester.pump();
      expect(centreOf(c, '1').x, closeTo(w.x, 1e-9));
      expect(centreOf(c, '1').y, closeTo(w.y, 1e-9));
      // Ctrl+Z is the service's still.
      await tester.tap(byKey('service-redo'));
      await tester.pump();
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(centreOf(c, '1').x, closeTo(w.x, 1e-9));
      expect(h.reached['ctrl+z'], 0);
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(c.selectTool(FloorPlanTool.select), isFalse);
    });
  });

  group('the letters, the palette and activeTool', () {
    testWidgets(
        'M-H41 tablesOnly, the canvas focused: every refused letter (L, P, R, '
        'B, W, D, N, G, M, S, I, C, A, T) and F reach the host and activeTool '
        'stays select; V still selects', (tester) async {
      final h = await mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      expect(canvasFocused(), isTrue);
      for (final (row, key, tool) in kRows.skip(1)) {
        await press(tester, key);
        expect(h.reached[tool.name], 1, reason: row);
        expect(c.activeTool.value, FloorPlanTool.select, reason: row);
        expect(statusText(tester), 'Select', reason: row);
      }
      await press(tester, LogicalKeyboardKey.keyF);
      expect(h.reached['fill'], 1);
      // V is the shell's: with a table armed, it selects.
      await openSymbols(tester, c);
      await arm(tester, 'dining.table.round');
      expect(c.activeTool.value, FloorPlanTool.symbol);
      expect(canvasFocused(), isTrue);
      await press(tester, LogicalKeyboardKey.keyV);
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(h.reached['select'], 0);
    });

    testWidgets(
        'T4-b selectTool: false for a refused tool under tablesOnly, true '
        'under full; false in the selection mode, with no editor mounted, '
        'and for symbol with none armed', (tester) async {
      final idle = FloorPlanController(json: editorPlanJson());
      addTearDown(idle.dispose);
      expect(idle.selectTool(FloorPlanTool.select), isFalse);
      expect(idle.selectTool(FloorPlanTool.wall), isFalse);
      expect(idle.activeTool.value, FloorPlanTool.select);

      final h = await mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      expect(c.selectTool(FloorPlanTool.wall), isFalse);
      expect(c.selectTool(FloorPlanTool.symbol), isFalse);
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(byKey('tool-wall'), findsNothing);

      h.caps.value = Caps.full;
      await tester.pump();
      expect(c.selectTool(FloorPlanTool.wall), isTrue);
      expect(c.activeTool.value, FloorPlanTool.wall);
      await tester.pump();
      expect(statusText(tester), 'Wall');
      expect(tester.widget<ListTile>(byKey('tool-wall')).selected, isTrue);
      expect(c.selectTool(FloorPlanTool.symbol), isFalse);
      expect(c.activeTool.value, FloorPlanTool.wall);
      expect(c.selectTool(FloorPlanTool.select), isTrue);
      expect(c.activeTool.value, FloorPlanTool.select);

      c.setMode(FloorPlanMode.selection);
      expect(c.selectTool(FloorPlanTool.wall), isFalse);
      await tester.pump();
      expect(c.selectTool(FloorPlanTool.wall), isFalse);
      expect(c.activeTool.value, FloorPlanTool.select);
    });

    testWidgets(
        'T4-h activeTool follows every change: W (one announcement), Escape, '
        'a palette tap, the host\'s selectTool, a mode switch; the host\'s '
        'strip shows it', (tester) async {
      final h = await mountEditor(tester);
      final c = h.c;
      h.announced.clear();
      await press(tester, LogicalKeyboardKey.keyW);
      expect(c.activeTool.value, FloorPlanTool.wall);
      expect(h.announced, [FloorPlanTool.wall]);
      expect(find.text('host: wall'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(c.activeTool.value, FloorPlanTool.select);
      await tester.tap(byKey('tool-arc'));
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.arc);
      expect(c.selectTool(FloorPlanTool.dimension), isTrue);
      expect(c.activeTool.value, FloorPlanTool.dimension);
      expect(h.announced, [
        FloorPlanTool.wall,
        FloorPlanTool.select,
        FloorPlanTool.arc,
        FloorPlanTool.dimension,
      ]);
      c.setMode(FloorPlanMode.selection);
      expect(c.activeTool.value, FloorPlanTool.select);
      await tester.pump();
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      await press(tester, LogicalKeyboardKey.keyL);
      expect(c.activeTool.value, FloorPlanTool.line);
      expect(find.text('host: line'), findsOneWidget);
      // A load builds a new editor, which starts with select.
      c.load(editorPlanJson());
      await tester.pump();
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(find.text('host: select'), findsOneWidget);
    });
  });

  group('a runtime change', () {
    for (final mode in FloorPlanMode.values) {
      testWidgets(
          'T4-i (${mode.name} mode) tools without select: an ArgumentError '
          'naming tools when the view builds', (tester) async {
        final c = FloorPlanController(json: editorPlanJson());
        addTearDown(c.dispose);
        c.setMode(mode);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: FloorPlanView(
                    controller: c,
                    editorCapabilities: const Caps(tools: {
                      FloorPlanTool.wall,
                    })))));
        expect(tester.takeException(),
            isA<ArgumentError>().having((e) => e.name, 'name', 'tools'));
      });
    }

    testWidgets(
        'M-H47(runtime tool) full, W, one click (a wall part-way), then '
        'tablesOnly: after one pump activeTool is select, the status line '
        'reads Select, the pending wall is gone, the wall row too',
        (tester) async {
      final h = await mountEditor(tester);
      final c = h.c;
      final d = c.activeDocument;
      await press(tester, LogicalKeyboardKey.keyW);
      await click(tester, screenOf(tester, c, Vector2(24200, 13600)));
      expect(statusText(tester), startsWith('Wall'));
      final state = d.commands.stateId;
      final depth = d.commands.undoDepth;
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(statusText(tester), 'Select');
      expect(byKey('tool-wall'), findsNothing);
      // The host's strip hears it after that frame.
      await tester.pump();
      expect(find.text('host: select'), findsOneWidget);
      // A further click adds nothing: no wall ends there.
      await click(tester, screenOf(tester, c, Vector2(25000, 13600)));
      await click(tester, screenOf(tester, c, Vector2(25000, 14000)));
      expect(d.commands.stateId, state);
      expect(d.commands.undoDepth, depth);
      // Back to full: the wall tool starts afresh, from no point.
      h.caps.value = Caps.full;
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(byKey('tool-wall'), findsOneWidget);
    });

    testWidgets(
        'T4-c full, a chair armed, then tablesOnly: activeTool select and a '
        'click places nothing; the Symbols tab and its search text are kept '
        '(C-5)', (tester) async {
      final h = await mountEditor(tester);
      final c = h.c;
      await openSymbols(tester, c);
      await tester.enterText(byKey('symbol-search'), 'chair');
      await tester.pump();
      await arm(tester, 'dining.chair');
      expect(c.activeTool.value, FloorPlanTool.symbol);
      final instances = instancesOf(c.activeDocument);
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(statusText(tester), 'Select');
      await click(tester, screenOf(tester, c, Vector2(24800, 13900)));
      expect(instancesOf(c.activeDocument), instances);
      // The tab and the search are the shell's: kept.
      expect(byKey('symbol-search'), findsOneWidget);
      expect(tester.widget<TextField>(byKey('symbol-search')).controller!.text,
          'chair');
      expect(c.selectTool(FloorPlanTool.symbol), isFalse);
      // A filter that offers the chair again lets the host re-activate it.
      h.caps.value = Caps.full;
      await tester.pump();
      expect(c.selectTool(FloorPlanTool.symbol), isTrue);
      expect(c.activeTool.value, FloorPlanTool.symbol);
    });

    testWidgets(
        'T4-e full.copyWith(export: false, undo: false): no Export, Undo or '
        'Redo button, Ctrl+E and Ctrl+Z reach the host; full at runtime: '
        'both shown and bound', (tester) async {
      final h = await mountEditor(tester,
          caps: Caps.full.copyWith(export: false, undo: false));
      for (final k in ['toolbar-export', 'toolbar-undo', 'toolbar-redo']) {
        expect(byKey(k), findsNothing, reason: k);
      }
      expect(byKey('toolbar-print'), findsOneWidget);
      expect(canvasFocused(), isTrue);
      await ctrl(tester, LogicalKeyboardKey.keyE);
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(h.reached['ctrl+e'], 1);
      expect(h.reached['ctrl+z'], 1);
      expect(h.dialogs, 0);

      h.caps.value = Caps.full;
      await tester.pump();
      for (final k in ['toolbar-export', 'toolbar-undo', 'toolbar-redo']) {
        expect(byKey(k), findsOneWidget, reason: k);
      }
      await ctrl(tester, LogicalKeyboardKey.keyE);
      await tester.pump();
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(h.reached['ctrl+e'], 1);
      expect(h.reached['ctrl+z'], 1);
      expect(h.dialogs, 1);
    });

    testWidgets(
        'T4-j readOnly: no left column, and the canvas origin measured '
        'again (a mode round trip keeps a table in place); tablesOnly: the '
        'column', (tester) async {
      final h = await mountEditor(tester);
      final c = h.c;
      final full = canvasOrigin(tester);
      h.caps.value = Caps.readOnly;
      await tester.pump();
      await tester.pump();
      expect(byKey('chrome-left'), findsNothing);
      expect(canvasOrigin(tester), full - const Offset(240, 0));
      await expectKept(tester, c, 'readOnly');
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      await tester.pump();
      expect(byKey('chrome-left'), findsOneWidget);
      expect(canvasOrigin(tester), full);
      await expectKept(tester, c, 'tablesOnly');
    });

    testWidgets(
        'T4-j readOnly from the start: the first switch keeps a table in '
        'place (the seed corrected)', (tester) async {
      final h = await mountEditor(tester, caps: Caps.readOnly);
      expect(byKey('chrome-left'), findsNothing);
      await expectKept(tester, h.c, 'readOnly from the start');
    });
  });

  group('the Symbols tab', () {
    testWidgets(
        'the Symbols tab without the symbol tool: the gallery shown and '
        'disabled, a tap arms nothing', (tester) async {
      final h = await mountEditor(tester,
          caps: Caps.full.copyWith(tools: {
            FloorPlanTool.select,
            FloorPlanTool.wall,
          }));
      final c = h.c;
      await openSymbols(tester, c);
      expect(tester.widget<SymbolGallery>(find.byType(SymbolGallery)).enabled,
          isFalse);
      await arm(tester, 'dining.table.round');
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(c.selectTool(FloorPlanTool.symbol), isFalse);
      h.caps.value = Caps.full;
      await tester.pump();
      // Nothing was armed: the host has no symbol to re-activate.
      expect(c.selectTool(FloorPlanTool.symbol), isFalse);
      expect(tester.widget<SymbolGallery>(find.byType(SymbolGallery)).enabled,
          isTrue);
      await arm(tester, 'dining.table.round');
      expect(c.activeTool.value, FloorPlanTool.symbol);
    });

    testWidgets(
        'M-H47(symbolFilter) tablesOnly: `table` shows the tables alone, '
        '`sofa` the no-match line; a one-key filter shows that cell alone',
        (tester) async {
      final h = await mountEditor(tester);
      final c = h.c;
      await openSymbols(tester, c);
      await tester.enterText(byKey('symbol-search'), 'table');
      await tester.pump();
      // The control, under full: the tables and the others.
      expect(galleryKeys(tester).toSet(), {...kTables, ...kOtherTables});
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      expect(galleryKeys(tester).toSet(), kTables);
      await tester.enterText(byKey('symbol-search'), 'sofa');
      await tester.pump();
      expect(byKey('symbol-search-empty'), findsOneWidget);
      expect(find.byType(SymbolGallery), findsNothing);
      await tester.enterText(byKey('symbol-search'), '');
      await tester.pump();
      expect(galleryKeys(tester).toSet(), kTables);

      h.caps.value =
          Caps.full.copyWith(symbolFilter: (s) => s.key == 'dining.chair');
      await tester.pump();
      expect(galleryKeys(tester), ['dining.chair']);
    });

    testWidgets(
        'T4-d tablesOnly, a table armed: M then a click places it '
        'unmirrored (det > 0); R then a click turns it 90 degrees; under '
        'full, M mirrors; without rotate, R reaches the host and turns '
        'nothing', (tester) async {
      final h = await mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      await openSymbols(tester, c);
      await arm(tester, 'dining.table.square.two');
      expect(canvasFocused(), isTrue);

      Future<InstanceNode> place(Vector2 w) async {
        final before = instancesOf(c.activeDocument);
        await click(tester, screenOf(tester, c, w));
        final added = instancesOf(c.activeDocument).difference(before);
        expect(added, hasLength(1));
        return c.activeDocument.tree[added.single]! as InstanceNode;
      }

      double det(Transform2 t) => t.a * t.d - t.b * t.c;

      await press(tester, LogicalKeyboardKey.keyM);
      final a = await place(Vector2(24700, 14000));
      expect(det(a.transform), greaterThan(0));
      expect(a.transform.a, closeTo(1, 1e-9));
      expect(a.transform.b, closeTo(0, 1e-9));
      await press(tester, LogicalKeyboardKey.keyR);
      final b = await place(Vector2(22200, 13300));
      expect(det(b.transform), greaterThan(0));
      expect(b.transform.a, closeTo(0, 1e-9));
      expect(b.transform.b, closeTo(1, 1e-9));

      // Under full, M mirrors (the control).
      h.caps.value = Caps.full;
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyM);
      final m = await place(Vector2(24700, 16900));
      expect(det(m.transform), lessThan(0));
      await press(tester, LogicalKeyboardKey.keyM);

      // Without rotate, R is any other key: it reaches the host, and the
      // turn stored while rotate was allowed is not used (Task 4 review
      // R-1): the next placement is unturned.
      h.caps.value = Caps.tablesOnly.copyWith(rotate: false);
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.symbol);
      await press(tester, LogicalKeyboardKey.keyR);
      expect(h.reached['rectangle'], 1);
      final r = await place(Vector2(25300, 13600));
      expect(r.transform.a, closeTo(1, 1e-9));
      expect(r.transform.b, closeTo(0, 1e-9));
      expect(det(r.transform), greaterThan(0));

      // rotate again: the stored turn returns with it.
      h.caps.value = Caps.tablesOnly;
      await tester.pump();
      final back = await place(Vector2(25300, 14200));
      expect(back.transform.a, closeTo(0, 1e-9));
      expect(back.transform.b, closeTo(1, 1e-9));
      expect(det(back.transform), greaterThan(0));
    });
  });

  group('snapping, rulers and grid', () {
    testWidgets(
        'T4-f snapping false: no OSNAP, F3 reaches the host, and a line '
        'drawn from within the aperture of the column\'s corner starts at '
        'the grid point of the raw one; under full it starts at the corner',
        (tester) async {
      final h =
          await mountEditor(tester, caps: Caps.full.copyWith(snapping: false));
      final c = h.c;
      expect(byKey('osnap-text'), findsNothing);
      await press(tester, LogicalKeyboardKey.f3);
      expect(h.reached['f3'], 1);

      // 5 px off the corner: inside the 10 px aperture.
      final corner = editorColumnCorner;
      final raw = Vector2(corner.x - 12, corner.y - 8);
      Future<Vector2> drawFrom() async {
        await press(tester, LogicalKeyboardKey.keyL);
        await click(tester, screenOf(tester, c, raw));
        await click(tester, screenOf(tester, c, Vector2(22900, 14600)));
        await press(tester, LogicalKeyboardKey.escape);
        await press(tester, LogicalKeyboardKey.escape);
        return newestLine(c.activeDocument).$1;
      }

      final page = pageOf(c.activeDocument);
      final step = dragGridStepMm(page, 0.37)!;
      final grid = Vector2(
          page.originX + ((raw.x - page.originX) / step).round() * step,
          page.originY + ((raw.y - page.originY) / step).round() * step);
      final off = await drawFrom();
      expect(off.x, closeTo(grid.x, 1e-6));
      expect(off.y, closeTo(grid.y, 1e-6));
      expect(off.distanceTo(corner), greaterThan(1));

      h.caps.value = Caps.full;
      await tester.pump();
      expect(byKey('osnap-text'), findsOneWidget);
      final on = await drawFrom();
      expect(on.x, closeTo(corner.x, 1e-6));
      expect(on.y, closeTo(corner.y, 1e-6));
    });

    testWidgets(
        'snapping false keeps the user\'s setting: F3 off under full, '
        'snapping false and back, still off', (tester) async {
      final h = await mountEditor(tester);
      final on = tester.widget<Text>(byKey('osnap-text')).data;
      await press(tester, LogicalKeyboardKey.f3);
      final off = tester.widget<Text>(byKey('osnap-text')).data;
      expect(off, isNot(on));
      h.caps.value = Caps.full.copyWith(snapping: false);
      await tester.pump();
      h.caps.value = Caps.full;
      await tester.pump();
      expect(tester.widget<Text>(byKey('osnap-text')).data, off);
    });

    testWidgets(
        'T4-g rulers and grid false: no RulerFrame, no grid pixel on the '
        'sheet; rulers toggled at runtime, then a mode round trip keeps a '
        'table in place', (tester) async {
      final h = await mountEditor(tester);
      final c = h.c;
      // The sheet above the flat (y 17,053 to the page's top, 17,750):
      // the grid, nothing drafted.
      final page = pageOf(c.activeDocument);
      expect(c.activeDocument.extents.maxY, lessThan(17100));
      expect(page.originY + page.effectiveHeightMm * page.scaleDenominator,
          greaterThan(17700));
      c.cameraController.value = ViewportTransform(
          worldToScreenMatrix:
              Transform2(0.37, 0, 0, -0.37, -0.37 * 12000, 0.37 * 17800));
      await tester.pump();
      Rect sheet() => Rect.fromPoints(
          screenOf(tester, c, Vector2(13000, 17650)),
          screenOf(tester, c, Vector2(16000, 17200)));
      final origin = tester.getTopLeft(find.byKey(shotKey));
      final withGrid = coloursIn(await shoot(tester), sheet(), origin);
      expect(withGrid.length, greaterThan(1));

      h.caps.value = Caps.full.copyWith(rulers: false, grid: false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(RulerFrame), findsNothing);
      final without = coloursIn(await shoot(tester), sheet(), origin);
      expect(without, hasLength(1));

      h.caps.value = Caps.full;
      await tester.pump();
      await tester.pump();
      c.cameraController.value = editorCamera();
      await tester.pump();
      final ruled = canvasOrigin(tester);
      h.caps.value = Caps.full.copyWith(rulers: false);
      await tester.pump();
      await tester.pump();
      expect(canvasOrigin(tester),
          ruled - const Offset(kRulerThickness, kRulerThickness));
      await expectKept(tester, c, 'rulers off');
      h.caps.value = Caps.full;
      await tester.pump();
      await tester.pump();
      expect(find.byType(RulerFrame), findsOneWidget);
      expect(canvasOrigin(tester), ruled);
      await expectKept(tester, c, 'rulers on');
    });
  });
}

/// Table `1`'s screen place is kept across design -> selection -> design.
Future<void> expectKept(
    WidgetTester tester, FloorPlanController c, String reason) async {
  final w = centreOf(c, '1');
  final at = screenOf(tester, c, w);
  for (final mode in [FloorPlanMode.selection, FloorPlanMode.design]) {
    c.setMode(mode);
    await tester.pump();
    await tester.pump();
    final got = screenOf(tester, c, w);
    expect(got.dx, closeTo(at.dx, 1e-6), reason: '$reason: $mode (x)');
    expect(got.dy, closeTo(at.dy, 1e-6), reason: '$reason: $mode (y)');
  }
}
