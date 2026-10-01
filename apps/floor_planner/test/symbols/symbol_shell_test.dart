// Spec 09b D8, D9, R-4, R-5, plan 09b Task 9: the shell's Tools | Symbols
// tabs and the placement tool's wiring, through the app and its host.
//
// Fixtures (plan P-2, P-3): the app pumped with a scripted `DocumentFiles`,
// a loader over the real asset read by `File`, and a thumbnail cache the
// test owns (the real one: no test here reads a pixel, so none waits under
// `tester.runAsync`). The camera is rotated, at 0.1 px/mm, centred far from
// the origin; the placed symbol's base point is off its origin (checked);
// the placement is turned AND mirrored.
import 'dart:io';
import 'dart:typed_data';

import 'package:floor_planner/document_host.dart';
import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/wall_tool.dart';
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_library_loader.dart';
import 'package:floor_planner/symbols/symbol_library_state.dart';
import 'package:floor_planner/symbols/symbol_panel.dart';
import 'package:floor_planner/symbols/symbol_place_tool.dart';
import 'package:floor_planner/symbols/symbol_placer.dart';
import 'package:floor_planner/tool_palette.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/document_rig.dart';
import '../support/fake_document_files.dart';

final Uint8List assetBytes =
    File('assets/library/furniture.jetlib').readAsBytesSync();

/// Far from the origin and from the page.
final Vector2 far = Vector2(41234.5, 27345.25);

final Finder tabTools = find.byKey(const Key('tab-tools'));
final Finder tabSymbols = find.byKey(const Key('tab-symbols'));
final Finder strip = find.byKey(const Key('left-tabs'));

/// The app with a loader over the real asset and [thumbnails] (a fresh
/// test-owned cache when null and [ownCache] is false; none at all, so the
/// app makes its own, when [ownCache] is true). Returns the cache the test
/// passed, if any.
Future<SymbolThumbnails?> pumpSymbolsApp(WidgetTester tester,
    {bool ownCache = false, SymbolThumbnails? thumbnails}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final loader = SymbolLibraryLoader(read: () async => assetBytes);
  addTearDown(loader.dispose);
  final cache = ownCache ? null : (thumbnails ?? SymbolThumbnails());
  if (cache != null && thumbnails == null) addTearDown(cache.dispose);
  await tester.pumpWidget(FloorPlannerApp(
      files: FakeDocumentFiles(), symbols: loader, thumbnails: cache));
  await tester.pump();
  expect(loader.state, isA<SymbolLibraryReady>(), reason: 'premise: loaded');
  return cache;
}

ToolController toolsOf(WidgetTester tester) => viewOf(tester).tools;

SymbolPanel panelOf(WidgetTester tester) =>
    tester.widget<SymbolPanel>(find.byType(SymbolPanel));

SymbolGallery galleryOf(WidgetTester tester) =>
    tester.widget<SymbolGallery>(find.byType(SymbolGallery));

/// The loaded library's first entry: the first cell of the first category.
SymbolEntry firstEntry(WidgetTester tester) =>
    (panelOf(tester).loader.state as SymbolLibraryReady).library.entries.first;

Future<void> tapKey(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump();
}

/// Opens the Symbols tab and taps [entry]'s cell.
Future<void> armBySymbolsTab(WidgetTester tester, SymbolEntry? entry) async {
  await tapKey(tester, tabSymbols);
  final e = entry ?? firstEntry(tester);
  final cell = find.byKey(Key('symbol-cell-${symbolIdOf(e)}'));
  await tester.ensureVisible(cell);
  await tester.pump();
  await tapKey(tester, cell);
}

/// The canvas's focus node: the primary focus, inside the interaction
/// layer (F-12).
FocusNode canvasFocus(WidgetTester tester) {
  final node = FocusManager.instance.primaryFocus!;
  expect(
      find
          .descendant(
              of: find.byType(InteractionLayer),
              matching: find.byElementPredicate((e) => e == node.context),
              matchRoot: true)
          .evaluate(),
      isNotEmpty,
      reason: 'premise: the canvas has the focus');
  return node;
}

/// Every focus node whose widget sits under [of].
List<FocusNode> focusNodesUnder(WidgetTester tester, Finder of) => [
      for (final n in FocusManager.instance.rootScope.descendants)
        if (n.context != null &&
            find
                .descendant(
                    of: of,
                    matching: find.byElementPredicate((e) => e == n.context))
                .evaluate()
                .isNotEmpty)
          n,
    ];

/// The point a release at world [p] resolves to: the tool's snap chain
/// (F-5) computed here from the shell's own index, page, camera and snap.
Vector2 snappedAt(WidgetTester tester, Vector2 p) {
  final view = viewOf(tester);
  final cam = view.camera.value;
  final local =
      globalOf(tester, p) - tester.getTopLeft(find.byType(InteractionLayer));
  final raw = cam.screenToWorld(Vector2(local.dx, local.dy));
  final out = DragPoint();
  resolveDragPoint(
    raw: raw,
    orthoBase: null,
    index: view.index,
    apertureWorld: kSnapAperturePixels / cam.scale,
    objectSnap: hostOf(tester).snap.objectSnap,
    page: view.page.value,
    gridStepMm: dragGridStepMm(view.page.value, cam.scale),
    scratch: SnapResult(),
    out: out,
  );
  return out.point.clone();
}

/// Whether [cache] is disposed: only a disposed cache throws from
/// `imageFor` **synchronously**. The probe's builder throws too, but only
/// into the returned future, which is ignored.
bool isDisposed(SymbolThumbnails cache) {
  try {
    cache
        .imageFor(
            key: Object(),
            document: () => throw UnsupportedError('probe'),
            logicalSize: const Size(10, 10),
            devicePixelRatio: 1,
            foreground: 0)
        .ignore();
    return false;
  } on StateError {
    return true;
  }
}

List<InstanceNode> instancesOf(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().toList();

List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

Future<void> releaseGesture(TestGesture g) async {
  await g.up();
  await g.removePointer();
}

void main() {
  testWidgets(
      'SS1 a bare shell has no tabs and shows today\'s palette; the app\'s '
      'shell has the strip, Tools first (M-09b11)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlannerShell()));
    expect(strip, findsNothing);
    expect(tabTools, findsNothing);
    expect(tabSymbols, findsNothing);
    expect(find.byType(SymbolPanel), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('chrome-left')),
            matching: find.byType(ToolPalette)),
        findsOneWidget);

    await pumpSymbolsApp(tester);
    expect(strip, findsOneWidget, reason: 'control: the app has the strip');
    expect(tabTools, findsOneWidget);
    expect(tabSymbols, findsOneWidget);
    expect(find.byType(ToolPalette), findsOneWidget, reason: 'Tools default');
    expect(find.byType(SymbolPanel), findsNothing);
  });

  testWidgets('SS2 the tabs switch the panel\'s content and change no tool',
      (tester) async {
    await pumpSymbolsApp(tester);
    await press(tester, LogicalKeyboardKey.keyW);
    final wall = toolsOf(tester).active;
    expect(wall, isA<WallTool>(), reason: 'premise');

    await tapKey(tester, tabSymbols);
    expect(find.byType(SymbolPanel), findsOneWidget);
    expect(find.byType(ToolPalette), findsNothing);
    expect(toolsOf(tester).active, same(wall));

    await tapKey(tester, tabTools);
    expect(find.byType(ToolPalette), findsOneWidget);
    expect(find.byType(SymbolPanel), findsNothing);
    expect(toolsOf(tester).active, same(wall));
  });

  testWidgets(
      'SS3 a cell tap arms the tool, clears the selection, makes it the '
      'active tool and highlights the cell (M-09b6)', (tester) async {
    await pumpSymbolsApp(tester);
    await aimCamera(tester, far);
    await drawWall(tester, far + Vector2(-1500, 0), far + Vector2(1500, 0));
    final doc = sessionOf(tester).document;
    final selection = viewOf(tester).selection;
    selection.replace([SelectionKey.root(wallsOf(doc).single)]);
    await tester.pump();
    expect(selection.length, 1, reason: 'premise: a selection');

    await tapKey(tester, tabSymbols);
    final entry = firstEntry(tester);
    expect(entry.definition.basePoint, isNot(Vector2.zero()),
        reason: 'P-3: the base point is off the origin');
    await armBySymbolsTab(tester, entry);

    final active = toolsOf(tester).active;
    expect(active, isA<SymbolPlaceTool>());
    expect(active, same(panelOf(tester).tool));
    expect((active as SymbolPlaceTool).armed.value, same(entry));
    expect(selection.isEmpty, isTrue, reason: '_activate clears it');
    expect(galleryOf(tester).selectedId, symbolIdOf(entry));
    expect(tester.widget<Text>(find.byKey(const Key('status-text'))).data,
        'Symbol');
  });

  testWidgets(
      'SS4 armed, R and M through the canvas\'s focus turn and mirror the '
      'next placement (not Rectangle, not Room); W then chooses Wall',
      (tester) async {
    await pumpSymbolsApp(tester);
    await aimCamera(tester, far);
    await armBySymbolsTab(tester, null);
    final tool = toolsOf(tester).active as SymbolPlaceTool;
    final entry = tool.armed.value!;
    final doc = sessionOf(tester).document;

    await press(tester, LogicalKeyboardKey.keyR);
    await press(tester, LogicalKeyboardKey.keyM);
    expect(toolsOf(tester).active, same(tool),
        reason: 'R and M reach the tool before the shell\'s letters (F-12)');
    expect(instancesOf(doc), isEmpty, reason: 'premise');

    final a = far + Vector2(-700.25, 450.5), b = far + Vector2(1210.75, -380.5);
    final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.down(globalOf(tester, a));
    await mouse.moveTo(globalOf(tester, a) + const Offset(12, 7));
    await mouse.moveTo(globalOf(tester, b));
    await releaseGesture(mouse);
    await tester.pump();

    final placed = instancesOf(doc).single;
    final want = placementTransform(
        at: snappedAt(tester, b),
        basePoint: entry.definition.basePoint,
        quarterTurns: 1,
        mirrored: true);
    expect(partsOf(placed.transform), partsOf(want));

    await press(tester, LogicalKeyboardKey.keyW);
    expect(toolsOf(tester).active, isA<WallTool>(),
        reason: 'armed idle, W bubbles to the shell');
  });

  testWidgets(
      'SS5 Esc returns to Select and the highlight clears; so does choosing '
      'another tool (M-09b9 at the shell)', (tester) async {
    await pumpSymbolsApp(tester);
    await armBySymbolsTab(tester, null);
    final id = galleryOf(tester).selectedId;
    expect(id, isNotNull, reason: 'premise: highlighted');

    await press(tester, LogicalKeyboardKey.escape);
    expect(toolsOf(tester).active, isA<SelectTool>());
    expect(galleryOf(tester).selectedId, isNull);

    // Re-arm through the same cell, then a letter.
    await tapKey(tester, find.byKey(Key('symbol-cell-$id')));
    expect(galleryOf(tester).selectedId, id, reason: 'premise: re-armed');
    await press(tester, LogicalKeyboardKey.keyL);
    expect(toolsOf(tester).active, isA<LineTool>());
    expect(galleryOf(tester).selectedId, isNull);
  });

  testWidgets(
      'SS6 the tab strip and the cells take no focus: the canvas keeps it, '
      'on a tap and when asked (R-5, Ruling 05-6)', (tester) async {
    await pumpSymbolsApp(tester);
    final canvas = canvasFocus(tester);

    await armBySymbolsTab(tester, null);
    expect(FocusManager.instance.primaryFocus, same(canvas));

    final stripNodes = focusNodesUnder(tester, strip);
    expect(stripNodes, isNotEmpty, reason: 'premise: the segments\' nodes');
    for (final n in stripNodes) {
      n.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(canvas),
          reason: 'a segment cannot take the focus');
    }
    final cellNodes = focusNodesUnder(tester, find.byType(SymbolGallery));
    expect(cellNodes, isNotEmpty, reason: 'premise: the cells\' nodes');
    for (final n in cellNodes) {
      n.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(canvas),
          reason: 'a cell cannot take the focus');
    }
    await tapKey(tester, tabTools);
    expect(FocusManager.instance.primaryFocus, same(canvas));
  });

  testWidgets(
      'SS7 a document swap (New, clean) leaves no armed tool: the new '
      'shell\'s tool is idle and the old one is disposed with its armed '
      'symbol', (tester) async {
    await pumpSymbolsApp(tester);
    await armBySymbolsTab(tester, null);
    final old = toolsOf(tester).active as SymbolPlaceTool;
    final oldArmed = old.armed;
    expect(oldArmed.value, isNotNull, reason: 'premise: armed');
    expect(sessionOf(tester).dirty.value, isFalse, reason: 'premise: clean');
    final document = sessionOf(tester).document;

    await hostOf(tester).newFlow();
    await tester.pump();
    expect(sessionOf(tester).document, isNot(same(document)),
        reason: 'premise: swapped');

    expect(toolsOf(tester).active, isA<SelectTool>());
    expect(find.byType(ToolPalette), findsOneWidget, reason: 'Tools again');
    await tapKey(tester, tabSymbols);
    final panel = panelOf(tester);
    expect(panel.tool, isNot(same(old)));
    expect(panel.armed.value, isNull);
    expect(panel.tool.ghostVisible, isFalse);
    expect(galleryOf(tester).selectedId, isNull);

    expect(() => ChangeNotifier.debugAssertNotDisposed(old), throwsFlutterError,
        reason: 'the old shell disposed its tool');
    expect(() => ChangeNotifier.debugAssertNotDisposed(oldArmed),
        throwsFlutterError,
        reason: 'and its armed symbol');
  });

  testWidgets(
      'SS8 the 12a mid-shape rule: during a press the toolbar\'s Save is '
      'disabled; after the release it is enabled again (isMidShape)',
      (tester) async {
    await pumpSymbolsApp(tester);
    await aimCamera(tester, far);
    await armBySymbolsTab(tester, null);
    VoidCallback? save() => tester
        .widget<IconButton>(find.byKey(const Key('toolbar-save')))
        .onPressed;
    expect(save(), isNotNull, reason: 'premise: Save enabled');

    final a = far + Vector2(310.5, -220.25);
    final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.down(globalOf(tester, a));
    await tester.pump();
    expect(toolsOf(tester).active.isMidShape, isTrue, reason: 'premise');
    expect(save(), isNull);

    await mouse.moveTo(globalOf(tester, a) + const Offset(30, 20));
    await tester.pump();
    expect(save(), isNull);
    await releaseGesture(mouse);
    await tester.pump();
    expect(instancesOf(sessionOf(tester).document), hasLength(1),
        reason: 'premise: placed');
    expect(save(), isNotNull);
  });

  group('the thumbnail cache (plan R-B3-1)', () {
    testWidgets(
        'SS9 the app hands a given cache to the panel and does not dispose '
        'it', (tester) async {
      final cache = SymbolThumbnails();
      await pumpSymbolsApp(tester, thumbnails: cache);
      await tapKey(tester, tabSymbols);
      expect(panelOf(tester).thumbnails, same(cache));
      expect(tester.widget<DocumentHost>(find.byType(DocumentHost)).thumbnails,
          same(cache));

      await tester.pumpWidget(const SizedBox());
      expect(isDisposed(cache), isFalse, reason: 'still the caller\'s');
      cache.dispose();
      expect(isDisposed(cache), isTrue, reason: 'premise: the probe works');
    });

    testWidgets(
        'SS10 without a cache the app makes one, hands it to the panel and '
        'disposes it with itself', (tester) async {
      await pumpSymbolsApp(tester, ownCache: true);
      await tapKey(tester, tabSymbols);
      final own = panelOf(tester).thumbnails;
      expect(tester.widget<DocumentHost>(find.byType(DocumentHost)).thumbnails,
          same(own));

      expect(isDisposed(own), isFalse, reason: 'premise: alive while used');
      await tester.pumpWidget(const SizedBox());
      expect(isDisposed(own), isTrue,
          reason: 'disposed by the app that made it');
    });

    testWidgets(
        'SS11 a shell given a loader and no cache makes a cache of its own '
        'and disposes it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final loader = SymbolLibraryLoader(read: () async => assetBytes);
      addTearDown(loader.dispose);
      await loader.load();
      await tester.pumpWidget(MaterialApp(home: PlannerShell(symbols: loader)));
      await tester.pump();
      await tapKey(tester, tabSymbols);
      final own = panelOf(tester).thumbnails;

      expect(isDisposed(own), isFalse, reason: 'premise: alive while used');
      await tester.pumpWidget(const SizedBox());
      expect(isDisposed(own), isTrue, reason: 'disposed by the shell');
    });
  });
}
