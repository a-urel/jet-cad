// Spec 09b D8, D9, R-4, R-5, plan 09b Task 9: the shell's Tools | Symbols
// tabs and the placement tool's wiring, through the app and its host.
//
// Fixtures (plan P-2, P-3): the app pumped with a scripted `DocumentFiles`,
// a loader over the real asset read by `File`, and a thumbnail cache the
// test owns (the real one: no test here reads a pixel, so none waits under
// `tester.runAsync`). The camera is rotated, at 0.1 px/mm, centred far from
// the origin; the placed symbol's base point is off its origin (checked);
// the placement is turned AND mirrored.
//
// Spec 09c D6 (plan 09c-1 Task 7): the shell's wall faces. The walls are
// added straight through the document's commands (no Wall or Opening tool
// ever runs, W-5), each in its own rotated group near (1e5, −7e4) at 30°
// (`wall_attach_fixture.dart`, plan P-2); the expected placements are
// `attachToWall` over the wall's own runs from the raw pointer the layer
// computes.
import 'dart:io';
import 'dart:typed_data';

import 'package:floor_planner/document_host.dart';
import 'package:floor_planner/main.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/document_rig.dart';
import '../support/fake_document_files.dart';
import '../support/wall_attach_fixture.dart' show attachGroup, farAt;
import '../support/wall_fixture.dart' show addWall, polar;

final Uint8List assetBytes =
    File('../../packages/jet_cad_floor_plan/assets/library/furniture.jetlib')
        .readAsBytesSync();

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

final Finder searchField = find.byKey(const Key('symbol-search'));

/// The gallery's cell ids, in order.
List<String> galleryIdsOf(WidgetTester tester) => [
      for (final c in galleryOf(tester).categories)
        for (final s in c.symbols) s.id,
    ];

/// The ids "bed" matches in the loaded library, by the search itself.
List<String> bedIdsOf(WidgetTester tester) {
  final library = (panelOf(tester).loader.state as SymbolLibraryReady).library;
  return [
    for (final g in searchSymbols(library.entries, 'bed'))
      for (final e in g.symbols) symbolIdOf(e),
  ];
}

void _noop() {}

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

/// The raw world point the layer computes for a pointer at world [p] (the
/// screen round trip), as the tool receives it.
Vector2 rawAt(WidgetTester tester, Vector2 p) {
  final local =
      globalOf(tester, p) - tester.getTopLeft(find.byType(InteractionLayer));
  return viewOf(tester).camera.value.screenToWorld(Vector2(local.dx, local.dy));
}

/// The loaded library's entry [key].
SymbolEntry entryOf(WidgetTester tester, String key) =>
    (panelOf(tester).loader.state as SymbolLibraryReady)
        .library
        .entries
        .singleWhere((e) => e.key == key);

/// Spec 09c D6's shell fixture: a wall at 30°, 3600 long and 150 thick,
/// justified left, added through the document's commands in its own rotated
/// group near (1e5, −7e4) (no tool runs), the camera aimed at it. Returns
/// the wall and its left face's run.
Future<(Handle, FaceRun)> addAttachWall(WidgetTester tester) async {
  final doc = sessionOf(tester).document;
  final s = farAt(1234.5, 678.25);
  final h = doc.handleSeed.next();
  doc.commands.execute(addWall(
      doc, h, s, polar(s, 30, 3600), 150, Justification.left,
      at: attachGroup(h.value)));
  await aimCamera(tester, polar(s, 30, 1800));
  final run = faceRunsOf(doc, h).singleWhere((r) => r.side == FaceSide.left);
  return (h, run);
}

/// The point `a + t·u + m·s` of run [r].
Vector2 onRun(FaceRun r, double u, double s) =>
    Vector2(r.a.x + r.t.x * u + r.m.x * s, r.a.y + r.t.y * u + r.m.y * s);

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

  group('the search text (spec 09c D13)', () {
    testWidgets(
        'SS12 "bed" typed, Tools and back: the field reads "bed" and the '
        'gallery is filtered (M-09c-t, M-09c-t5)', (tester) async {
      await pumpSymbolsApp(tester);
      await tapKey(tester, tabSymbols);
      final all = galleryIdsOf(tester);
      await tester.enterText(searchField, 'bed');
      await tester.pump();
      final beds = galleryIdsOf(tester);
      expect(beds, bedIdsOf(tester), reason: 'premise: filtered');
      expect(beds.length, lessThan(all.length), reason: 'premise');

      await tapKey(tester, tabTools);
      expect(find.byType(SymbolPanel), findsNothing,
          reason: 'the panel is removed on the Tools tab');
      // A second build of the shell while the panel is away.
      await press(tester, LogicalKeyboardKey.keyW);
      await tapKey(tester, tabSymbols);
      expect(tester.widget<TextField>(searchField).controller!.text, 'bed');
      expect(galleryIdsOf(tester), beds);
      expect(
          [for (final c in galleryOf(tester).categories) c.name], ['Bed Room']);
      expect(find.byKey(const Key('symbol-search-clear')), findsOneWidget);
    });

    testWidgets(
        'SS13 a document replacement keeps it: New, then Open sample, and '
        'the new shell\'s Symbols tab reads "bed" (M-09c-t6, M-09c-t7)',
        (tester) async {
      await pumpSymbolsApp(tester);
      await tapKey(tester, tabSymbols);
      await tester.enterText(searchField, 'bed');
      await tester.pump();
      final given = panelOf(tester).query;
      final firstShell = tester.state(find.byType(PlannerShell));

      for (final replace in [
        () => hostOf(tester).newFlow(),
        () => hostOf(tester).openSampleFlow(),
      ]) {
        final before = sessionOf(tester).document;
        await replace();
        await tester.pump();
        expect(sessionOf(tester).document, isNot(same(before)),
            reason: 'premise: replaced');
        expect(before.commands.isDisposed, isTrue, reason: 'premise');
        expect(tester.state(find.byType(PlannerShell)), isNot(same(firstShell)),
            reason: 'premise: a new shell');
        expect(find.byType(SymbolPanel), findsNothing,
            reason: 'a new shell opens on Tools');

        await tapKey(tester, tabSymbols);
        expect(panelOf(tester).query, same(given));
        expect(tester.widget<TextField>(searchField).controller!.text, 'bed');
        expect(galleryIdsOf(tester), bedIdsOf(tester));
      }
    });

    testWidgets(
        'SS14 the panel gone, the controller stays usable; it is the host\'s '
        'and goes with the app, and a new app starts empty (M-09c-t2, '
        'M-09c-t8)', (tester) async {
      await pumpSymbolsApp(tester);
      await tapKey(tester, tabSymbols);
      await tester.enterText(searchField, 'bed');
      await tester.pump();
      final given = panelOf(tester).query;
      expect(
          tester.widget<PlannerShell>(find.byType(PlannerShell)).symbolSearch,
          same(given),
          reason: 'the host hands its own to the shell');

      await tapKey(tester, tabTools);
      expect(find.byType(SymbolPanel), findsNothing, reason: 'premise');
      // Not disposed with the panel: it still takes text and listeners.
      given.text = 'sofa';
      given.addListener(_noop);
      given.removeListener(_noop);
      await tapKey(tester, tabSymbols);
      expect(tester.widget<TextField>(searchField).controller!.text, 'sofa');
      expect(galleryIdsOf(tester),
          allOf(isNotEmpty, everyElement(startsWith('sofa.'))));

      await tester.pumpWidget(const SizedBox());
      expect(() => given.addListener(_noop), throwsFlutterError,
          reason: 'disposed with the host');

      await pumpSymbolsApp(tester);
      await tapKey(tester, tabSymbols);
      expect(panelOf(tester).query, isNot(same(given)));
      expect(tester.widget<TextField>(searchField).controller!.text, isEmpty);
    });

    testWidgets(
        'SS15 a bare shell given a loader keeps its own across a tab switch '
        'and disposes it (M-09c-t9)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final loader = SymbolLibraryLoader(read: () async => assetBytes);
      addTearDown(loader.dispose);
      await loader.load();
      await tester.pumpWidget(MaterialApp(home: PlannerShell(symbols: loader)));
      await tester.pump();
      await tapKey(tester, tabSymbols);
      await tester.enterText(searchField, 'bed');
      await tester.pump();
      final own = panelOf(tester).query;

      await tapKey(tester, tabTools);
      await tapKey(tester, tabSymbols);
      expect(panelOf(tester).query, same(own));
      expect(own.text, 'bed');
      expect(galleryIdsOf(tester), bedIdsOf(tester));

      await tester.pumpWidget(const SizedBox());
      expect(() => own.addListener(_noop), throwsFlutterError,
          reason: 'disposed by the shell that made it');
    });
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

  group('the wall attachment (spec 09c D6)', () {
    testWidgets(
        'SS16 a fresh shell where no Wall or Opening tool ran: a base unit '
        'attaches to a 30° face, a second placed after it snaps to its '
        'side; one undo step each (W-5)', (tester) async {
      await pumpSymbolsApp(tester);
      final (wall, run) = await addAttachWall(tester);
      final doc = sessionOf(tester).document;
      await tapKey(tester, tabSymbols);
      final unit = entryOf(tester, 'kitchen.base.600');
      await armBySymbolsTab(tester, unit);
      final tool = toolsOf(tester).active as SymbolPlaceTool;
      final box = boxOfEntry(unit)!;
      final scale = viewOf(tester).camera.value.scale;
      expect(scale, closeTo(0.1, 1e-12), reason: 'capture 160 mm, edge 100');
      final depth = doc.commands.undoDepth;

      Future<void> click(Vector2 p) async {
        final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
        await mouse.down(globalOf(tester, p));
        await tester.pump();
        await releaseGesture(mouse);
        await tester.pump();
      }

      final p1 = onRun(run, 1000, 120);
      await click(p1);
      final want1 = attachToWall([run], box, rawAt(tester, p1), 16 / scale,
          mirrored: false,
          neighbours: const [[]],
          edgeCaptureWorld: 10 / scale)!;
      final first = instancesOf(doc).single;
      expect(partsOf(first.transform), partsOf(want1.transform));
      expect(doc.commands.undoDepth, depth + 1);

      // 60 mm (inside the 100 mm edge capture) right of the first's side.
      final p2 = onRun(run, 1000 + 600 + 60, 90);
      await click(p2);
      final second = instancesOf(doc).last;
      expect(instancesOf(doc), hasLength(2));
      final q2 = second.transform.transformPoint(box.backCentre);
      expect((q2 - run.a).dot(run.t), closeTo(1600, 1e-6),
          reason: 'its left side on the first\'s right side');
      expect((q2 - run.a).dot(run.m), closeTo(0, 1e-6), reason: 'on the face');
      expect(tool.ghostAttachment, isNotNull);
      expect(
          partsOf(second.transform), partsOf(tool.ghostAttachment!.transform));
      expect(doc.commands.undoDepth, depth + 2);

      await undoKey(tester);
      expect(instancesOf(doc).single.handle, first.handle,
          reason: 'one undo step took the second only');
      await undoKey(tester);
      expect(instancesOf(doc), isEmpty);
      expect(wallsOf(doc), [wall]);
    });

    testWidgets(
        'SS17 a wall on a hidden or a locked layer hosts nothing: the shell '
        'hands its faces the openings\' host rule (M-09c-e)', (tester) async {
      await pumpSymbolsApp(tester);
      final (wall, run) = await addAttachWall(tester);
      final doc = sessionOf(tester).document;
      final zero = doc.tables.layers[ReservedHandles.layerZero]!;
      Handle layer(String name, {bool visible = true, bool locked = false}) {
        final h = doc.handleSeed.next();
        doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: h,
          name: name,
          color: const IndexedColor(3),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: visible,
          locked: locked,
        )));
        return h;
      }

      final hidden = layer('Hidden', visible: false);
      final locked = layer('Locked', locked: true);
      final open = layer('Open');
      await tapKey(tester, tabSymbols);
      final toilet = entryOf(tester, 'bath.toilet');
      // The gallery builds its cells lazily: filter to bring this one in.
      await tester.enterText(searchField, 'toilet');
      await tester.pump();
      await armBySymbolsTab(tester, toilet);
      final tool = toolsOf(tester).active as SymbolPlaceTool;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: globalOf(tester, onRun(run, 900, 80)));
      addTearDown(mouse.removePointer);
      for (final (i, (on, hosts)) in [
        (hidden, false),
        (locked, false),
        (open, true),
      ].indexed) {
        doc.commands
            .execute(SetComponentCommand<ObjectLayer>(wall, ObjectLayer(on)));
        await tester.pump();
        final why = doc.tables.layers[on]!.name;
        expect(isUsableHost(doc, wall), hosts, reason: 'premise: $why');
        await mouse.moveTo(globalOf(tester, onRun(run, 1100 + 250.0 * i, 80)));
        await tester.pump();
        expect(tool.ghostVisible, isTrue, reason: why);
        expect(tool.ghostAttachment != null, hosts, reason: why);
      }
    });
  });
}
