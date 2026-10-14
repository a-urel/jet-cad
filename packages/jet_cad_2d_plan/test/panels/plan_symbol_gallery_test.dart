// Spec P2 "PlanSymbolGallery" (Task 13), ported from jet_cad_floor_plan's
// symbol_panel_test.dart (spec 09b D7, F-4, F-13; 09c D13): the gallery,
// pumped standalone in a minimal host -- a canvas stand-in `Focus` that
// holds the focus, and a `CallbackShortcuts` ancestor counting the shell's
// R, W, M and Escape, as the editor's own bindings sit above its panels.
//
// Fixtures: the demo library (test/support/symbol_fixtures.dart), read
// through the controller's own loader; every entry's base point is off the
// origin (checked). The thumbnail cache is the controller's own: no test
// here reads a pixel, so none needs `tester.runAsync`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/symbol_fixtures.dart';

/// The demo library's visible symbols' ids, in library order.
final List<String> allIds = demoVisibleIds();

/// The "Bed Room" category: the only one `bed` matches (its name; and
/// nothing outside it carries `bed` in a name, tag or category).
const List<String> bedIds = [
  'demo.bed.double@1',
  'demo.bed.single@1',
  'demo.bed.night@1',
];

final class Host {
  Host(this.tester, {Future<Uint8List> Function()? read}) {
    controller = PlanController(kits: [
      demoKit(
          source: SymbolLibrarySource(
              label: 'demo', read: read ?? () async => demoBytes())),
    ]);
    addTearDown(dispose);
  }

  final WidgetTester tester;
  late final PlanController controller;
  final FocusNode canvas = FocusNode(debugLabel: 'canvas');

  /// The search field's controller (spec 09c D13): the host's, as the
  /// editor's is; the gallery neither makes nor disposes a given one.
  final TextEditingController query = TextEditingController();

  /// The shell's keys that reached the ancestor `CallbackShortcuts`.
  final Map<String, int> shortcuts = {'R': 0, 'W': 0, 'M': 0, 'Esc': 0};

  /// The search field's focus node: the gallery's own.
  FocusNode get searchFocus => tester.widget<TextField>(field).focusNode!;

  PlanSymbol loaded(String key) =>
      controller.symbols.singleWhere((s) => s.component.key == key);

  Widget build({TextEditingController? query}) => MaterialApp(
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
                child: PlanSymbolGallery(
                    controller: controller, query: query ?? this.query),
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

  /// Lets the load settle (when [load]), pumps the gallery and lets the
  /// canvas take focus.
  Future<void> pump({bool load = true, TextEditingController? query}) async {
    await tester.pumpWidget(build(query: query));
    if (load) {
      for (var i = 0;
          i < 10 && controller.symbolsState.value == SymbolsState.loading;
          i++) {
        await tester.pump();
      }
    }
    await tester.pump();
  }

  void dispose() {
    query.dispose();
    canvas.dispose();
    controller.dispose();
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

void _noop() {}

void main() {
  test('the fixture is not degenerate: every base point is off the origin', () {
    final entries = SymbolLibrary.decode(demoBytes()).entries;
    expect(entries.length, greaterThan(5));
    for (final e in entries) {
      expect(e.definition.basePoint.length, greaterThan(100),
          reason: e.symbol.key);
    }
  });

  group('states', () {
    testWidgets('loading shows a progress indicator and "Loading symbols…"',
        (tester) async {
      final read = Completer<Uint8List>();
      final h = Host(tester, read: () => read.future);
      await h.pump(load: false);
      expect(find.byKey(const Key('symbol-loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading symbols…'), findsOneWidget);
      expect(field, findsNothing);
      expect(find.byType(SymbolGallery), findsNothing);

      read.complete(demoBytes());
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
        return demoBytes();
      });
      await h.pump();
      expect(find.byKey(const Key('symbol-failed')), findsOneWidget);
      // The words, not the exception (spec 14d V-17): it is logged.
      expect(find.text('The symbols could not be loaded.'), findsOneWidget);
      expect(find.textContaining('no asset here'), findsNothing);
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
      expect(
          find.byKey(const Key('symbol-cell-demo.sofa.three@1')), findsNothing);

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

  group('the search controller is the caller\'s (spec 09c D13)', () {
    testWidgets(
        'the field edits the given controller, and its text filters the '
        'gallery both ways (M-09c-t)', (tester) async {
      final h = Host(tester);
      await h.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(h.query.text, 'bed', reason: 'the field writes the given one');
      expect(galleryIds(tester), bedIds);

      // Written from outside, as the editor's survives the gallery: the
      // gallery listens to it.
      h.query.text = 'sofa three';
      await tester.pump();
      expect(galleryIds(tester), ['demo.sofa.three@1']);
      expect(tester.widget<TextField>(field).controller, same(h.query));
    });

    testWidgets(
        'a gallery built over a controller that already reads "bed" opens '
        'filtered, the clear button showing (M-09c-t)', (tester) async {
      final h = Host(tester);
      h.query.text = 'bed';
      await h.pump();
      expect(galleryIds(tester), bedIds);
      expect(
          [for (final c in gallery(tester).categories) c.name], ['Bed Room']);
      expect(find.byKey(const Key('symbol-search-clear')), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'bed');
    });

    testWidgets(
        'the gallery gone, the controller stays usable: not disposed, and '
        'the gallery\'s listener removed (M-09c-t2, M-09c-t3)', (tester) async {
      final h = Host(tester);
      await h.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      expect(find.byType(PlanSymbolGallery), findsNothing, reason: 'premise');
      // A disposed controller asserts on any use; a listener left on it
      // would call setState on the disposed gallery. Neither throws.
      h.query.text = 'sofa';
      h.query.addListener(_noop);
      h.query.removeListener(_noop);
      expect(h.query.text, 'sofa');

      // A new gallery over it reads its text.
      await h.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'sofa');
      expect(galleryIds(tester), isNot(allIds));
      expect(galleryIds(tester),
          allOf(isNotEmpty, everyElement(startsWith('demo.sofa.'))));
    });

    testWidgets(
        'a different controller handed in: the gallery follows it and '
        'leaves the old one (M-09c-t4)', (tester) async {
      final h = Host(tester);
      final other = TextEditingController(text: 'bed');
      addTearDown(other.dispose);
      await h.pump();
      expect(galleryIds(tester), allIds, reason: 'premise: empty text');

      await h.pump(query: other);
      expect(galleryIds(tester), bedIds);
      expect(tester.widget<TextField>(field).controller, same(other));

      // The old one no longer drives the gallery...
      h.query.text = 'bed zebra';
      await tester.pump();
      expect(galleryIds(tester), bedIds);
      // ...the new one does.
      other.text = 'sofa three';
      await tester.pump();
      expect(galleryIds(tester), ['demo.sofa.three@1']);

      // And the gallery gone, the old one has no listener of the
      // gallery's that would call setState on a disposed state.
      await tester.pumpWidget(const SizedBox());
      h.query.text = 'x';
      other.text = 'y';
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
    // Ported from symbol_panel_test.dart (Task 14), assertions unchanged;
    // the state is reached through the controller: armSymbol then
    // selectTool('plan.select') stands for "armed, another tool active",
    // selectTool('plan.symbol') for activating the placement tool.
    testWidgets(
        'the highlight follows the active tool and the armed entry '
        '(M-09b9)', (tester) async {
      final h = Host(tester);
      await h.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(gallery(tester).selectedId, isNull);

      h.controller.armSymbol(h.loaded('demo.bed.double'));
      h.controller.selectTool('plan.select');
      await tester.pump();
      expect(gallery(tester).selectedId, isNull,
          reason: 'armed, but another tool is active');

      h.controller.selectTool('plan.symbol');
      await tester.pump();
      expect(gallery(tester).selectedId, 'demo.bed.double@1');

      h.controller.armSymbol(h.loaded('demo.bed.single'));
      await tester.pump();
      expect(gallery(tester).selectedId, 'demo.bed.single@1');

      h.controller.selectTool('plan.select');
      await tester.pump();
      expect(gallery(tester).selectedId, isNull,
          reason: 'another tool chosen: the highlight clears, armed stays');
      expect(h.controller.armedSymbol.value, same(h.loaded('demo.bed.single')));
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
        h.controller.document.commands.permissions = permissions;
        await h.pump();
        await tester.enterText(field, 'bed');
        await tester.pump();
        expect(gallery(tester).enabled, isFalse, reason: denied);
        await tester
            .tap(find.byKey(const Key('symbol-cell-demo.bed.double@1')));
        await tester.pump();
        expect(h.controller.armedSymbol.value, isNull, reason: denied);
      }

      // Transform is no placement capability.
      h.controller.document.commands.permissions = const DraftPermissions(
          transform: false, components: true, geometry: true, structure: true);
      await h.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(gallery(tester).enabled, isTrue);
      await tester.tap(find.byKey(const Key('symbol-cell-demo.bed.single@1')));
      await tester.pump();
      expect(h.controller.armedSymbol.value, same(h.loaded('demo.bed.single')));
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
      final visible = [
        for (final e in SymbolLibrary.decode(demoBytes()).entries)
          if (!e.symbol.retired) e,
      ];
      expect(symbols.length, visible.length);
      for (final (i, e) in visible.indexed) {
        expect(symbols[i].id, '${e.symbol.key}@${e.symbol.version}');
        expect(symbols[i].label, e.symbol.name);
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
      final entry = h.loaded('demo.bed.double').entry;
      final symbol = gallery(tester)
          .categories
          .single
          .symbols
          .singleWhere((s) => s.id == 'demo.bed.double@1');
      final doc = symbol.thumbnailDocument();

      final instance = doc.tree.nodes.whereType<InstanceNode>().single;
      final t = instance.transform;
      expect([t.a, t.b, t.c, t.d, t.e, t.f], [1, 0, 0, 1, 0, 0]);
      final definition = doc.tree.definitions.single;
      expect(instance.definition, definition.handle);
      expect(definition.basePoint, entry.definition.basePoint);
      final component = doc.components.get<SymbolComponent>(definition.handle)!;
      expect(component.key, 'demo.bed.double');
      expect(component.version, 1);
      // The kit's components, no page.
      expect(doc.components.withComponent<PageComponent>(), isEmpty);
    });
  });

  group('the plan library\'s gallery (new)', () {
    testWidgets(
        'S-15 retired symbols are not shown; the filter narrows the cells '
        'and a tap outside it arms nothing', (tester) async {
      final h = Host(tester);
      await h.pump();
      expect(galleryIds(tester), isNot(contains('demo.chair.old@1')));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  child: PlanSymbolGallery(
                      controller: h.controller,
                      filter: (s) =>
                          s.component.key.startsWith('demo.sofa.'))))));
      await tester.pump();
      // M-S15: the gallery ignores its filter.
      expect(galleryIds(tester), ['demo.sofa.three@1', 'demo.sofa.two@1']);
    });

    testWidgets(
        'S-16 the gallery is disabled while plan.symbol is not among the '
        'permitted tools', (tester) async {
      final h = Host(tester);
      await h.pump();
      expect(gallery(tester).enabled, isTrue);
      h.controller.permissions =
          PlanPermissions.full.copyWith(tools: {'plan.select', 'plan.line'});
      await tester.pump();
      // M-S16: `_enabled` drops the allowsTool test.
      expect(gallery(tester).enabled, isFalse);
      await tester.tap(find.byKey(const Key('symbol-cell-demo.sofa.two@1')));
      await tester.pump();
      expect(h.controller.armedSymbol.value, isNull);
    });

    testWidgets(
        'S-18 the gallery reports the app\'s locale to the controller and '
        'shows the kit\'s words in its language', (tester) async {
      final h = Host(tester);
      await tester.pumpWidget(MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  child: PlanSymbolGallery(controller: h.controller)))));
      await tester.pump();
      await tester.pump();
      // M-S18a: didChangeDependencies drops PlanLocaleScope.push.
      expect(h.controller.locale.value, const Locale('tr'));
      // M-S18b: the gallery's words fixed to English.
      final categories = gallery(tester).categories;
      expect(categories.first.name, 'Yatak odası');
      expect(categories.first.id, 'demo/Bed Room');
      expect(categories.first.symbols.first.label, 'Çift kişilik yatak');
      expect(categories.last.name, 'Office', reason: 'no word: the stored');
      await tester.pumpWidget(const SizedBox());
    });

    // A positive control (exempt from a mutant): the gallery's own query.
    testWidgets('S-17 a gallery given no query searches with its own',
        (tester) async {
      final h = Host(tester);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  child: PlanSymbolGallery(controller: h.controller)))));
      await tester.pump();
      await tester.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(galleryIds(tester),
          ['demo.bed.double@1', 'demo.bed.single@1', 'demo.bed.night@1']);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
