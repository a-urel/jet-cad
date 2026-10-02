// Spec 09b D7, F-4, F-13, plan 09b Task 8: the Symbols tab, pumped
// standalone in a minimal host -- a canvas stand-in `Focus` that holds the
// focus, and a `CallbackShortcuts` ancestor counting the shell's R, W, M and
// Escape, as the shell's own bindings sit above its panels.
//
// Fixtures (plan P-3): the real asset, read by `File` and injected through
// the loader's `read`; every entry's base point is off the origin (checked).
// The thumbnail cache is the real one: no test here reads a pixel, so none
// needs `tester.runAsync`.
import 'dart:async';
import 'dart:io';

import 'package:floor_planner/new_document.dart';
import 'package:floor_planner/panel_focus.dart';
import 'package:floor_planner/symbols/symbol_component.dart';
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_library_loader.dart';
import 'package:floor_planner/symbols/symbol_library_state.dart';
import 'package:floor_planner/symbols/symbol_panel.dart';
import 'package:floor_planner/symbols/symbol_place_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

final Uint8List assetBytes =
    File('assets/library/furniture.jetlib').readAsBytesSync();

final SymbolLibrary library = SymbolLibrary.decode(assetBytes);

SymbolEntry entryOf(String key) =>
    library.entries.singleWhere((e) => e.key == key);

final List<String> allIds = [
  for (final e in library.entries) '${e.key}@${e.version}',
];

/// The "Bed Room" category: the only one `bed` matches (its name; and
/// nothing outside it carries `bed` in a name, tag or category).
const List<String> bedIds = [
  'bed.double.1400@1',
  'bed.double@1',
  'bed.double.1800@1',
  'bed.single.800@1',
  'bed.single@1',
  'bed.single.1000@1',
  'bed.nightstand@1',
  'bed.wardrobe.1200@1',
  'bed.wardrobe@1',
  'bed.wardrobe.2400@1',
];

/// A tool that does nothing: the controller's other tool.
class IdleTool extends Tool {
  @override
  String get name => 'Idle';

  @override
  ToolPhase get phase => ToolPhase.idle;

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerExit(ToolContext ctx) {}

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;

  @override
  void cancel(ToolContext ctx) {}

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}
}

class Host {
  Host(this.tester, {Future<Uint8List> Function()? read})
      : loader = SymbolLibraryLoader(read: read ?? () async => assetBytes) {
    document = newDocument(const InsertionPointMeasurer());
    index = SpatialIndex(document);
    camera = CameraController(ViewportTransform(
        worldToScreenMatrix: Transform2.translation(400, 300)
            .multiply(Transform2.scale(0.05, -0.05))));
    selection = SelectionController(document);
    final ctx = ToolContext(
        document: document, index: index, camera: camera, selection: selection);
    tools = ToolController(initial: idle, context: ctx);
    tool = SymbolPlaceTool(armed);
    addTearDown(dispose);
  }

  final WidgetTester tester;
  final SymbolLibraryLoader loader;
  final SymbolThumbnails thumbnails = SymbolThumbnails();
  final FocusNode canvas = FocusNode(debugLabel: 'canvas');
  final PanelFieldFocusNode searchFocus =
      PanelFieldFocusNode(debugLabel: 'symbol-search');
  final ValueNotifier<SymbolEntry?> armed = ValueNotifier<SymbolEntry?>(null);
  final IdleTool idle = IdleTool();
  late final DraftDocument document;
  late final SpatialIndex index;
  late final CameraController camera;
  late final SelectionController selection;
  late final ToolController tools;
  late final SymbolPlaceTool tool;

  /// The shell's keys that reached the ancestor `CallbackShortcuts`.
  final Map<String, int> shortcuts = {'R': 0, 'W': 0, 'M': 0, 'Esc': 0};

  final List<SymbolEntry> selected = [];

  /// The loader's own entry for [key] (the loader decodes its own library).
  SymbolEntry loaded(String key) => (loader.state as SymbolLibraryReady)
      .library
      .entries
      .singleWhere((e) => e.key == key);

  Widget build(DraftPermissions permissions) => MaterialApp(
        home: Scaffold(
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyR): () =>
                  shortcuts['R'] = shortcuts['R']! + 1,
              const SingleActivator(LogicalKeyboardKey.keyW): () =>
                  shortcuts['W'] = shortcuts['W']! + 1,
              const SingleActivator(LogicalKeyboardKey.keyM): () =>
                  shortcuts['M'] = shortcuts['M']! + 1,
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  shortcuts['Esc'] = shortcuts['Esc']! + 1,
            },
            child: Row(children: [
              SizedBox(
                width: 240,
                child: SymbolPanel(
                  loader: loader,
                  thumbnails: thumbnails,
                  tools: tools,
                  tool: tool,
                  armed: armed,
                  permissions: permissions,
                  searchFocus: searchFocus,
                  onSelect: selected.add,
                ),
              ),
              Expanded(
                child: Focus(
                  key: const Key('canvas'),
                  focusNode: canvas,
                  autofocus: true,
                  child: const SizedBox.expand(),
                ),
              ),
            ]),
          ),
        ),
      );

  /// Loads the library, pumps the panel and lets the canvas take focus.
  Future<void> pump(
      {DraftPermissions permissions = DraftPermissions.all,
      bool load = true}) async {
    if (load) await loader.load();
    await tester.pumpWidget(build(permissions));
    await tester.pump();
  }

  void dispose() {
    tools.dispose();
    tool.dispose();
    idle.dispose();
    armed.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
    searchFocus.dispose();
    canvas.dispose();
    thumbnails.dispose();
    loader.dispose();
  }
}

final Finder field = find.byKey(const Key('symbol-search'));

SymbolGallery gallery(WidgetTester tester) =>
    tester.widget<SymbolGallery>(find.byType(SymbolGallery));

List<String> galleryIds(WidgetTester tester) => [
      for (final c in gallery(tester).categories)
        for (final s in c.symbols) s.id,
    ];

/// Whether the button keyed [key] could take the focus (Ruling 05-6): the
/// nearest `Focus` above [inner], a widget inside the button, is the
/// button's own node, and an `ExcludeFocus` above it makes it refuse.
bool canTakeFocus(WidgetTester tester, String key, Finder inner) =>
    Focus.of(tester.element(
            find.descendant(of: find.byKey(Key(key)), matching: inner).first))
        .canRequestFocus;

/// Taps the field and checks the premise: the field, not the canvas, has
/// the focus.
Future<void> focusField(WidgetTester tester, Host h) async {
  await tester.tap(field);
  await tester.pump();
  expect(h.searchFocus.hasFocus, isTrue, reason: 'premise: field focused');
  expect(h.canvas.hasFocus, isFalse, reason: 'premise: canvas not focused');
}

void main() {
  test('the fixture is not degenerate: every base point is off the origin', () {
    expect(library.entries.length, greaterThan(20));
    for (final e in library.entries) {
      expect(e.definition.basePoint.length, greaterThan(100), reason: e.key);
    }
  });

  group('states', () {
    testWidgets('loading shows a progress indicator and "Loading symbols…"',
        (tester) async {
      final read = Completer<Uint8List>();
      final h = Host(tester, read: () => read.future);
      unawaited(h.loader.load());
      await h.pump(load: false);
      expect(find.byKey(const Key('symbol-loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading symbols…'), findsOneWidget);
      expect(field, findsNothing);
      expect(find.byType(SymbolGallery), findsNothing);

      read.complete(assetBytes);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('symbol-loading')), findsNothing);
      expect(field, findsOneWidget);
      expect(galleryIds(tester), allIds);
    });

    testWidgets(
        'a failed load shows its message and Retry; Retry reaches ready '
        '(M-09b10)', (tester) async {
      var reads = 0;
      final h = Host(tester, read: () async {
        if (++reads == 1) throw StateError('no asset here');
        return assetBytes;
      });
      await h.pump();
      expect(find.byKey(const Key('symbol-failed')), findsOneWidget);
      expect(find.textContaining('no asset here'), findsOneWidget);
      expect(field, findsNothing);

      expect(canTakeFocus(tester, 'symbol-retry', find.text('Retry')), isFalse);
      await tester.tap(find.byKey(const Key('symbol-retry')));
      await tester.pump();
      await tester.pump();
      expect(reads, 2);
      expect(find.byKey(const Key('symbol-failed')), findsNothing);
      expect(field, findsOneWidget);
      expect(galleryIds(tester), allIds);
      // The canvas kept the focus (a button never takes it on a tap; the
      // guard against Retry taking it is `canTakeFocus` above).
      expect(h.canvas.hasFocus, isTrue);
    });
  });

  group('search', () {
    testWidgets(
        'typing "bed" shows only the matches; the clear button '
        'restores all', (tester) async {
      final h = Host(tester);
      await h.pump();
      expect(galleryIds(tester), allIds);
      expect(find.byKey(const Key('symbol-search-clear')), findsNothing);
      expect(find.text('Search symbols'), findsOneWidget);

      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(galleryIds(tester), bedIds);
      expect(
          [for (final c in gallery(tester).categories) c.name], ['Bed Room']);
      for (final id in bedIds) {
        expect(find.byKey(Key('symbol-cell-$id')), findsOneWidget);
      }
      expect(find.byKey(const Key('symbol-cell-sofa.three@1')), findsNothing);

      // The x takes no focus (Ruling 05-6); the field keeps it after a tap.
      expect(canTakeFocus(tester, 'symbol-search-clear', find.byType(Icon)),
          isFalse);
      await focusField(tester, h);
      await tester.tap(find.byKey(const Key('symbol-search-clear')));
      await tester.pump();
      expect(h.searchFocus.hasFocus, isTrue);
      expect(h.canvas.hasFocus, isFalse);
      expect(galleryIds(tester), allIds);
      expect(find.byKey(const Key('symbol-search-clear')), findsNothing);
    });

    testWidgets(
        'an empty result says so with the query, and its Clear restores all',
        (tester) async {
      final h = Host(tester);
      await h.pump();
      await tester.enterText(field, 'bed zebra');
      await tester.pump();
      expect(find.byType(SymbolGallery), findsNothing);
      expect(find.text('No symbols match "bed zebra"'), findsOneWidget);

      expect(
          canTakeFocus(tester, 'symbol-search-clear-empty', find.text('Clear')),
          isFalse);
      await tester.tap(find.byKey(const Key('symbol-search-clear-empty')));
      await tester.pump();
      expect(find.byKey(const Key('symbol-search-empty')), findsNothing);
      expect(galleryIds(tester), allIds);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    });
  });

  group('the field and the shell\'s keys', () {
    testWidgets(
        'premise: with the canvas focused, R, W, M and Esc reach the shell',
        (tester) async {
      final h = Host(tester);
      await h.pump();
      expect(h.canvas.hasFocus, isTrue);
      for (final k in [
        LogicalKeyboardKey.keyR,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyM,
        LogicalKeyboardKey.escape,
      ]) {
        await tester.sendKeyEvent(k);
      }
      expect(h.shortcuts, {'R': 1, 'W': 1, 'M': 1, 'Esc': 1});
    });

    testWidgets('typing r, w and m in the field fires no shortcut (M-09b7)',
        (tester) async {
      final h = Host(tester);
      await h.pump();
      await focusField(tester, h);
      for (final k in [
        LogicalKeyboardKey.keyR,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyM,
      ]) {
        await tester.sendKeyEvent(k);
      }
      await tester.pump();
      expect(h.shortcuts, {'R': 0, 'W': 0, 'M': 0, 'Esc': 0});
      expect(h.searchFocus.hasFocus, isTrue);
    });

    testWidgets(
        'Esc in the field hands the focus back to the canvas, and '
        'does not reach the shell (M-09b8)', (tester) async {
      final h = Host(tester);
      await h.pump();
      await tester.enterText(field, 'bed');
      await focusField(tester, h);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(h.canvas.hasFocus, isTrue);
      expect(h.searchFocus.hasFocus, isFalse);
      expect(h.shortcuts['Esc'], 0);
      // The query stays.
      expect(galleryIds(tester), bedIds);
    });

    testWidgets(
        'Enter in the field hands the focus back to the canvas '
        '(M-09b8)', (tester) async {
      final h = Host(tester);
      await h.pump();
      await focusField(tester, h);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(h.canvas.hasFocus, isTrue);
      expect(h.searchFocus.hasFocus, isFalse);
    });

    testWidgets(
        'a tap outside the field hands the focus back to the canvas '
        '(M-09b8)', (tester) async {
      final h = Host(tester);
      await h.pump();
      await focusField(tester, h);
      // The canvas stand-in requests no focus on a tap of its own.
      await tester.tapAt(tester.getCenter(find.byKey(const Key('canvas'))));
      await tester.pump();
      expect(h.canvas.hasFocus, isTrue);
      expect(h.searchFocus.hasFocus, isFalse);
    });
  });

  group('the gallery', () {
    testWidgets(
        'the highlight follows the active tool and the armed entry '
        '(M-09b9)', (tester) async {
      final h = Host(tester);
      await h.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(gallery(tester).selectedId, isNull);

      h.armed.value = entryOf('bed.double');
      await tester.pump();
      expect(gallery(tester).selectedId, isNull,
          reason: 'armed, but another tool is active');

      h.tools.activate(h.tool);
      await tester.pump();
      expect(gallery(tester).selectedId, 'bed.double@1');

      h.armed.value = entryOf('bed.single');
      await tester.pump();
      expect(gallery(tester).selectedId, 'bed.single@1');

      h.tools.activate(h.idle);
      await tester.pump();
      expect(gallery(tester).selectedId, isNull,
          reason: 'another tool chosen: the highlight clears, armed stays');
      expect(h.armed.value, same(entryOf('bed.single')));
    });

    testWidgets(
        'a tap reports the entry; a denied structure, geometry or '
        'components disables the cells (M-09b22)', (tester) async {
      final h = Host(tester);
      for (final (denied, permissions) in [
        (
          'structure',
          const DraftPermissions(
              transform: true,
              components: true,
              geometry: true,
              structure: false)
        ),
        (
          'geometry',
          const DraftPermissions(
              transform: true,
              components: true,
              geometry: false,
              structure: true)
        ),
        (
          'components',
          const DraftPermissions(
              transform: true,
              components: false,
              geometry: true,
              structure: true)
        ),
      ]) {
        await h.pump(permissions: permissions);
        await tester.enterText(field, 'bed');
        await tester.pump();
        expect(gallery(tester).enabled, isFalse, reason: denied);
        await tester.tap(find.byKey(const Key('symbol-cell-bed.double@1')));
        await tester.pump();
        expect(h.selected, isEmpty, reason: denied);
      }

      // Transform is no placement capability.
      await h.pump(
          permissions: const DraftPermissions(
              transform: false,
              components: true,
              geometry: true,
              structure: true));
      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(gallery(tester).enabled, isTrue);
      await tester.tap(find.byKey(const Key('symbol-cell-bed.single@1')));
      await tester.pump();
      expect(h.selected.single, same(h.loaded('bed.single')));
      // The tap was outside the field, which handed the focus back; the
      // cell took none.
      expect(h.canvas.hasFocus, isTrue);
      expect(h.searchFocus.hasFocus, isFalse);
    });

    testWidgets(
        'the cells are the entries: id key@version, label the name, '
        'the thumbnail key the id', (tester) async {
      final h = Host(tester);
      await h.pump();
      final symbols = [
        for (final c in gallery(tester).categories) ...c.symbols,
      ];
      expect(symbols.length, library.entries.length);
      for (final (i, e) in library.entries.indexed) {
        expect(symbols[i].id, '${e.key}@${e.version}');
        expect(symbols[i].label, e.name);
        expect(symbols[i].thumbnailKey, symbols[i].id);
      }
      expect(gallery(tester).foreground, 0x000000,
          reason: 'black on the light cell (F-8)');
    });

    testWidgets(
        "the thumbnail document is the placer's identity output: one "
        'instance, identity transform, a definition carrying the component',
        (tester) async {
      final h = Host(tester);
      await h.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();
      final entry = entryOf('bed.double');
      final symbol = gallery(tester)
          .categories
          .single
          .symbols
          .singleWhere((s) => s.id == 'bed.double@1');
      final doc = symbol.thumbnailDocument();

      final instance = doc.tree.nodes.whereType<InstanceNode>().single;
      final t = instance.transform;
      expect([t.a, t.b, t.c, t.d, t.e, t.f], [1, 0, 0, 1, 0, 0]);
      final definition = doc.tree.definitions.single;
      expect(instance.definition, definition.handle);
      expect(definition.basePoint, entry.definition.basePoint);
      final component = doc.components.get<SymbolComponent>(definition.handle)!;
      expect(component.key, 'bed.double');
      expect(component.version, 1);
      // prepareDocument: the app's components and the DASHED record, no page.
      expect(doc.components.withComponent<PageComponent>(), isEmpty);
    });
  });
}
