// Task 8 (spec "The gallery (decision 9)"): the library's own gallery body.
// The thumbnail cache is a recording stand-in whose images never complete:
// no test here reads a pixel.
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SymbolThumbnails;
import 'package:jet_cad_2d_plan/src/chrome/shad_scope.dart';
import 'package:jet_cad_2d_plan/src/panels/gallery_grid.dart';

final class _Recording extends SymbolThumbnails {
  final List<({Object key, int foreground, double dpr})> calls = [];

  @override
  Future<ui.Image> imageFor({
    required Object key,
    required DraftDocument Function() document,
    required ui.Size logicalSize,
    required double devicePixelRatio,
    required int foreground,
  }) {
    calls.add((key: key, foreground: foreground, dpr: devicePixelRatio));
    return Completer<ui.Image>().future;
  }
}

PlanGalleryCell cell(String id, {List<String>? built}) =>
    PlanGalleryCell(id, 'label $id', id, () => DraftDocument.empty());

List<PlanGalleryGroup> groups(List<(String, int)> spec) => [
      for (final (id, n) in spec)
        PlanGalleryGroup(id, 'Group $id', [
          for (var i = 0; i < n; i++) cell('$id$i'),
        ]),
    ];

Widget host(
  PlanGalleryGrid grid, {
  ThemeData? theme,
  double dpr = 1,
  Size size = const Size(240, 400),
}) =>
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(devicePixelRatio: dpr, size: size),
        child: Scaffold(
          body:
              PlanShadScope(child: SizedBox.fromSize(size: size, child: grid)),
        ),
      ),
    );

PlanGalleryGrid grid(
  List<PlanGalleryGroup> g, {
  SymbolThumbnails? thumbnails,
  String? selectedId,
  bool enabled = true,
  void Function(String)? onSelect,
}) =>
    PlanGalleryGrid(
      groups: g,
      selectedId: selectedId,
      enabled: enabled,
      onSelect: onSelect ?? (_) {},
      thumbnails: thumbnails ?? _Recording(),
    );

void main() {
  testWidgets(
      'GG1 a header tap collapses and expands its group; collapse survives '
      'a rebuild with new groups of the same ids', (tester) async {
    await tester.pumpWidget(host(grid(groups([('a', 2), ('b', 2)]))));
    expect(find.byKey(const Key('symbol-cell-a0')), findsOneWidget);
    expect(find.byKey(const Key('symbol-cell-b0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('symbol-group-a')));
    await tester.pump();
    expect(find.byKey(const Key('symbol-cell-a0')), findsNothing);
    expect(find.byKey(const Key('symbol-cell-b0')), findsOneWidget,
        reason: 'only the tapped group collapses');

    // New group objects (and names) with the same ids, in another order
    // (a search narrowed the list): still collapsed, and b is not.
    final renamed = [
      for (final g in groups([('c', 1), ('b', 2), ('a', 2)]))
        PlanGalleryGroup(g.id, 'Other ${g.id}', g.cells),
    ];
    await tester.pumpWidget(host(grid(renamed)));
    expect(find.byKey(const Key('symbol-cell-a0')), findsNothing);
    expect(find.text('Other a'), findsOneWidget);
    expect(find.byKey(const Key('symbol-cell-b0')), findsOneWidget);
    expect(find.byKey(const Key('symbol-cell-c0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('symbol-group-a')));
    await tester.pump();
    expect(find.byKey(const Key('symbol-cell-a0')), findsOneWidget);
  });

  testWidgets(
      'GG2 cells are built lazily: with 500 symbols only the visible cells '
      'build', (tester) async {
    final rec = _Recording();
    await tester.pumpWidget(host(grid(groups([('a', 500)]), thumbnails: rec)));
    // 240 wide, two columns: a handful of rows fit 400 px (plus the cache
    // extent).
    expect(rec.calls.length, lessThan(40));
    expect(rec.calls.length, greaterThan(0));
    expect(find.byKey(const Key('symbol-cell-a499')), findsNothing);
  });

  testWidgets(
      'GG3 thumbnails come from the given SymbolThumbnails and no other '
      'cache is created, at the device pixel ratio', (tester) async {
    final rec = _Recording();
    await tester
        .pumpWidget(host(grid(groups([('a', 2)]), thumbnails: rec), dpr: 2.5));
    expect(rec.calls.map((c) => c.key), containsAll(['a0', 'a1']));
    expect(rec.calls.every((c) => c.dpr == 2.5), isTrue);
    // A different cache handed in is the one asked from then on.
    final other = _Recording();
    await tester.pumpWidget(
        host(grid(groups([('a', 2)]), thumbnails: other), dpr: 2.5));
    expect(other.calls.map((c) => c.key), containsAll(['a0', 'a1']));
  });

  testWidgets(
      'GG4 the selected cell exposes selected semantics; enabled:false '
      'ignores taps', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = <String>[];
    await tester.pumpWidget(
        host(grid(groups([('a', 2)]), selectedId: 'a1', onSelect: taps.add)));
    SemanticsNode node(String id) =>
        tester.getSemantics(find.byKey(Key('symbol-cell-$id')));
    expect(node('a1').flagsCollection.isSelected, Tristate.isTrue);
    expect(node('a0').flagsCollection.isSelected, Tristate.isFalse);
    expect(node('a0').flagsCollection.isButton, isTrue);
    expect(node('a0').label, contains('label a0'));

    await tester.tap(find.byKey(const Key('symbol-cell-a0')));
    expect(taps, ['a0']);

    await tester.pumpWidget(host(grid(groups([('a', 2)]),
        selectedId: 'a1', enabled: false, onSelect: taps.add)));
    expect(node('a0').flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(find.byKey(const Key('symbol-cell-a0')));
    expect(taps, ['a0'], reason: 'disabled: the tap is ignored');
    // Headers still collapse.
    await tester.tap(find.byKey(const Key('symbol-group-a')));
    await tester.pump();
    expect(find.byKey(const Key('symbol-cell-a0')), findsNothing);
    handle.dispose();
  });

  testWidgets(
      'GG6 the thumbnail ink is the foreground of its own cell colour, '
      'the selected cell\'s from the selected colour', (tester) async {
    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      final rec = _Recording();
      await tester.pumpWidget(host(
          grid(groups([('a', 2)]), thumbnails: rec, selectedId: 'a1'),
          theme: theme));
      await tester.pump(const Duration(seconds: 1));
      final colours = planShadThemeFrom(theme).colorScheme;
      int ink(Color c) => foregroundFor(c.toARGB32() & 0xFFFFFF);
      int of(String key) => rec.calls.lastWhere((c) => c.key == key).foreground;
      expect(of('a0'), ink(colours.card), reason: '${theme.brightness}');
      expect(of('a1'), ink(colours.secondary), reason: '${theme.brightness}');
    }
  });
}
