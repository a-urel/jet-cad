import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'support/fixtures.dart';

// Image work completes through engine callbacks the fake-async zone of a
// pumped test never delivers (spec F-15): every wait for a thumbnail runs
// under `tester.runAsync`, then a pump delivers the cells' callbacks.

/// A one-symbol document the way `placeSymbol` makes one: a definition whose
/// base point is off the origin, placed by a rotated, mirrored instance far
/// from the origin, its line BYBLOCK. [seed] varies the geometry so two
/// symbols paint differently.
DraftDocument symbolDoc(int seed) {
  final doc = DraftDocument.empty();
  final def = Handle(800 + seed * 10);
  final base = Vector2(250.0 + seed * 40, -170.0 - seed * 25);
  doc.tree.addDefinition(Definition(
      handle: def, name: 's$seed', basePoint: base, children: const []));
  addEntity(doc, def, Handle(801 + seed * 10), EntityKind.line,
      [base.x - 60, base.y - 30 * seed, base.x + 60, base.y + 20], const [],
      color: const ByBlockColor(), lineweight: 100);
  addEntity(doc, def, Handle(802 + seed * 10), EntityKind.circle,
      [base.x + 10, base.y], [25.0 + seed * 5],
      color: const ByBlockColor(), lineweight: 50);
  addInstance(
      doc,
      doc.rootHandle,
      Handle(805 + seed * 10),
      def,
      Transform2.translation(41000.0 + seed, -27000)
          .multiply(Transform2.rotation(0.6 + seed / 10))
          .multiply(Transform2.scale(1, -1)));
  return doc;
}

GallerySymbol sym(String id, String label, int seed) => GallerySymbol(
    id: id,
    label: label,
    thumbnailKey: id,
    thumbnailDocument: () => symbolDoc(seed));

/// Two categories; ids are `key@version`, one key at two versions.
final List<GalleryCategory> kCategories = [
  GalleryCategory(name: 'Seating', symbols: [
    sym('chair@1', 'Chair', 1),
    sym('chair@2', 'Chair (wide arm rest, oak)', 2),
    sym('sofa@1', 'Sofa', 3),
  ]),
  GalleryCategory(name: 'Tables', symbols: [
    sym('table@1', 'Table', 4),
  ]),
];

const Color kCell = Color(0xFFF4F1EA);

/// The thumbnail cache, recording every future it hands out.
class RecordingThumbnails extends SymbolThumbnails {
  RecordingThumbnails({super.maxEntries});

  final List<Future<ui.Image>> requests = [];

  @override
  Future<ui.Image> imageFor({
    required Object key,
    required DraftDocument Function() document,
    required ui.Size logicalSize,
    required double devicePixelRatio,
    required int foreground,
  }) {
    final f = super.imageFor(
        key: key,
        document: document,
        logicalSize: logicalSize,
        devicePixelRatio: devicePixelRatio,
        foreground: foreground);
    requests.add(f);
    return f;
  }

  /// Waits, in real time, for every request so far, errors included.
  Future<void> settle() => Future.wait([
        for (final r in requests) r.then((_) {}, onError: (Object _) {}),
      ]);
}

class Harness {
  Harness(this.tester, {int maxEntries = 64})
      : thumbnails = RecordingThumbnails(maxEntries: maxEntries);

  final WidgetTester tester;
  final RecordingThumbnails thumbnails;
  final List<String> selected = [];
  final FocusNode outside = FocusNode(debugLabel: 'canvas');

  Widget build({
    List<GalleryCategory>? categories,
    String? selectedId,
    bool enabled = true,
    int foreground = 0x000000,
    bool showGallery = true,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Row(children: [
            SizedBox(
              width: 240,
              child: showGallery
                  ? SymbolGallery(
                      categories: categories ?? kCategories,
                      selectedId: selectedId,
                      enabled: enabled,
                      onSelect: selected.add,
                      thumbnails: thumbnails,
                      foreground: foreground,
                      cellColor: kCell,
                    )
                  : const SizedBox(),
            ),
            Expanded(
              child: Focus(
                focusNode: outside,
                autofocus: true,
                child: const SizedBox.expand(),
              ),
            ),
          ]),
        ),
      );

  Future<void> pump({
    List<GalleryCategory>? categories,
    String? selectedId,
    bool enabled = true,
    int foreground = 0x000000,
    bool showGallery = true,
  }) async {
    await tester.pumpWidget(build(
        categories: categories,
        selectedId: selectedId,
        enabled: enabled,
        foreground: foreground,
        showGallery: showGallery));
  }

  /// Lets every pending thumbnail complete, then delivers the cells'
  /// completion callbacks.
  Future<void> settleImages() async {
    await tester.runAsync(thumbnails.settle);
    await tester.pump();
  }

  void dispose() {
    outside.dispose();
    thumbnails.dispose();
  }
}

Finder cell(String id) => find.byKey(Key('symbol-cell-$id'));
Finder header(String name) => find.byKey(Key('symbol-group-$name'));

ui.Image? shownImage(WidgetTester tester, String id) => tester
    .widget<RawImage>(
        find.descendant(of: cell(id), matching: find.byType(RawImage)))
    .image;

bool isSelected(WidgetTester tester, String id) =>
    tester
        .getSemantics(find
            .descendant(of: cell(id), matching: find.byType(Semantics))
            .first)
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    ui.Tristate.isTrue;

Material cellMaterial(WidgetTester tester, String id) =>
    tester.widget<Material>(
        find.descendant(of: cell(id), matching: find.byType(Material)).first);

void main() {
  test('the fixtures are not degenerate', () {
    for (final seed in [1, 2, 3, 4]) {
      final doc = symbolDoc(seed);
      final def = doc.tree.definitions.single;
      expect(def.basePoint.length, greaterThan(100), reason: 'base point');
      final node = doc.tree[Handle(805 + seed * 10)]!;
      expect(node.transform.isIdentity, isFalse);
      expect(node.transform.determinant, lessThan(0), reason: 'mirrored');
      expect(doc.extents.minX.abs(), greaterThan(1000), reason: 'far');
    }
  });

  testWidgets('headers and a two-column grid of keyed, labelled cells',
      (tester) async {
    final h = Harness(tester);
    addTearDown(h.dispose);
    await h.pump();
    expect(header('Seating'), findsOneWidget);
    expect(header('Tables'), findsOneWidget);
    expect(find.descendant(of: header('Seating'), matching: find.text('3')),
        findsOneWidget,
        reason: 'the header shows the count');
    for (final id in ['chair@1', 'chair@2', 'sofa@1', 'table@1']) {
      expect(cell(id), findsOneWidget, reason: id);
    }
    // Two columns: the first two cells share a row, the third starts the next.
    final a = tester.getTopLeft(cell('chair@1'));
    final b = tester.getTopLeft(cell('chair@2'));
    final c = tester.getTopLeft(cell('sofa@1'));
    expect(b.dy, a.dy);
    expect(b.dx, greaterThan(a.dx));
    expect(c.dx, a.dx);
    expect(c.dy, greaterThan(a.dy));
    // One line, ellipsis; the full label in the tooltip.
    final label = tester.widget<Text>(find.descendant(
        of: cell('chair@2'),
        matching: find.text('Chair (wide arm rest, oak)')));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(find.byTooltip('Chair (wide arm rest, oak)'), findsOneWidget);
    await h.settleImages();
  });

  testWidgets('a header collapses its category and expands it again',
      (tester) async {
    // MUTATION (collapse): the grid ignores the collapsed set -> the cells
    // stay after the tap.
    final h = Harness(tester);
    addTearDown(h.dispose);
    await h.pump();
    await h.settleImages();
    await tester.tap(header('Seating'));
    await tester.pump();
    expect(cell('chair@1'), findsNothing);
    expect(cell('sofa@1'), findsNothing);
    expect(header('Seating'), findsOneWidget, reason: 'the header stays');
    expect(cell('table@1'), findsOneWidget, reason: 'other groups stay');
    expect(find.descendant(of: header('Seating'), matching: find.text('3')),
        findsOneWidget);
    await tester.tap(header('Seating'));
    await tester.pump();
    expect(cell('chair@1'), findsOneWidget);
    expect(cell('sofa@1'), findsOneWidget);
    await h.settleImages();
  });

  testWidgets('a tap calls onSelect with the cell id', (tester) async {
    final h = Harness(tester);
    addTearDown(h.dispose);
    await h.pump();
    await h.settleImages();
    await tester.tap(cell('chair@2'));
    await tester.tap(cell('table@1'));
    expect(h.selected, ['chair@2', 'table@1']);
  });

  testWidgets('disabled cells are greyed and ignore taps; headers still work',
      (tester) async {
    // MUTATION: a disabled tap still calls onSelect -> ['chair@1'].
    final h = Harness(tester);
    addTearDown(h.dispose);
    await h.pump(enabled: false);
    await h.settleImages();
    await tester.tap(cell('chair@1'));
    await tester.tap(cell('table@1'));
    expect(h.selected, isEmpty);
    final opacity = tester.widget<Opacity>(
        find.descendant(of: cell('chair@1'), matching: find.byType(Opacity)));
    expect(opacity.opacity, lessThan(1));
    await tester.tap(header('Seating'));
    await tester.pump();
    expect(cell('chair@1'), findsNothing);
    // Enabled again: the same cell selects and is opaque.
    await tester.tap(header('Seating'));
    await h.pump(enabled: true);
    await h.settleImages();
    await tester.tap(cell('chair@1'));
    expect(h.selected, ['chair@1']);
    expect(
        tester
            .widget<Opacity>(find.descendant(
                of: cell('chair@1'), matching: find.byType(Opacity)))
            .opacity,
        1);
  });

  testWidgets('only the cell whose id is selectedId is highlighted',
      (tester) async {
    // MUTATION: the highlight ignores selectedId (`selectedId != null`) ->
    // every cell is highlighted.
    final h = Harness(tester);
    addTearDown(h.dispose);
    final semantics = tester.ensureSemantics();
    // The same key at two versions: the id tells them apart.
    await h.pump(selectedId: 'chair@2');
    await h.settleImages();
    final scheme = Theme.of(tester.element(cell('chair@2'))).colorScheme;
    expect(isSelected(tester, 'chair@2'), isTrue);
    expect(cellMaterial(tester, 'chair@2').color, scheme.primaryContainer);
    for (final id in ['chair@1', 'sofa@1', 'table@1']) {
      expect(isSelected(tester, id), isFalse, reason: id);
      expect(cellMaterial(tester, id).color, kCell, reason: id);
    }
    await h.pump(selectedId: 'table@1');
    expect(isSelected(tester, 'chair@2'), isFalse);
    expect(isSelected(tester, 'table@1'), isTrue);
    expect(cellMaterial(tester, 'table@1').color, scheme.primaryContainer);
    await h.pump(selectedId: null);
    for (final id in ['chair@1', 'chair@2', 'sofa@1', 'table@1']) {
      expect(isSelected(tester, id), isFalse, reason: id);
    }
    semantics.dispose();
  });

  testWidgets('a cell and a header never take focus', (tester) async {
    // MUTATION M-09b12: no ExcludeFocus -> the cell's own focus node can take
    // focus, and traversal from the canvas enters the gallery.
    final h = Harness(tester);
    addTearDown(h.dispose);
    await h.pump();
    await h.settleImages();
    expect(h.outside.hasPrimaryFocus, isTrue);
    await tester.tap(cell('sofa@1'));
    await tester.tap(header('Tables'));
    await tester.pump();
    expect(h.selected, ['sofa@1']);
    expect(h.outside.hasPrimaryFocus, isTrue, reason: 'the canvas keeps it');
    // The cell's own focus node (InkWell's) refuses a request.
    final node = Focus.of(tester.element(
        find.descendant(of: cell('sofa@1'), matching: find.text('Sofa'))));
    expect(node.canRequestFocus, isFalse);
    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isFalse);
    expect(h.outside.hasPrimaryFocus, isTrue);
    // Traversal from the canvas never lands in the gallery.
    final gallery = find.byType(SymbolGallery);
    for (var i = 0; i < 6; i++) {
      h.outside.nextFocus();
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null) {
        expect(
            find.descendant(
                of: gallery,
                matching: find.byElementPredicate((e) => e == focused)),
            findsNothing,
            reason: 'traversal step $i');
      }
    }
  });

  testWidgets('a cell shows its own clone; disposing it leaves the cache image',
      (tester) async {
    // MUTATION M-09b23: a cell keeps the cache's image instead of a clone ->
    // unmounting the gallery disposes the cache's image.
    final h = Harness(tester);
    addTearDown(h.dispose);
    await h.pump();
    await h.settleImages();
    final shown = shownImage(tester, 'chair@1');
    expect(shown, isNotNull);
    // The cell's request for chair@1 is the first one (build order).
    final cached = await tester.runAsync(() => h.thumbnails.requests.first);
    expect(identical(shown, cached), isFalse, reason: 'a clone is shown');
    expect(shown!.isCloneOf(cached!), isTrue);
    await h.pump(showGallery: false);
    expect(shown.debugDisposed, isTrue, reason: 'the cell disposed its clone');
    expect(cached.debugDisposed, isFalse, reason: "the cache's stays");
    // ... and stays usable.
    final bytes = await tester
        .runAsync(() => cached.toByteData(format: ui.ImageByteFormat.rawRgba));
    expect(bytes!.lengthInBytes, cached.width * cached.height * 4);
    expect(h.thumbnails.length, 4);
  });

  testWidgets('a cell whose image changes disposes its previous clone',
      (tester) async {
    // MUTATION: replacing the image does not dispose the old clone.
    final h = Harness(tester);
    addTearDown(h.dispose);
    await h.pump(foreground: 0x000000);
    await h.settleImages();
    final first = shownImage(tester, 'table@1')!;
    await h.pump(foreground: 0x336699);
    await h.settleImages();
    final second = shownImage(tester, 'table@1')!;
    expect(identical(first, second), isFalse);
    expect(first.debugDisposed, isTrue);
    expect(second.debugDisposed, isFalse);
    expect(h.thumbnails.requests, hasLength(8), reason: 'four cells, twice');
  });

  testWidgets('an image error shows the label, an empty cell and no exception',
      (tester) async {
    final h = Harness(tester);
    addTearDown(h.dispose);
    final broken = [
      GalleryCategory(name: 'Broken', symbols: [
        GallerySymbol(
            id: 'bad@1',
            label: 'Bad',
            thumbnailKey: 'bad@1',
            thumbnailDocument: () => throw StateError('no document')),
        sym('good@1', 'Good', 2),
      ]),
    ];
    await h.pump(categories: broken);
    await h.settleImages();
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: cell('bad@1'), matching: find.text('Bad')),
        findsOneWidget);
    expect(shownImage(tester, 'bad@1'), isNull);
    expect(shownImage(tester, 'good@1'), isNotNull);
    await expectLater(h.thumbnails.requests.first, throwsStateError);
    // Still selectable.
    await tester.tap(cell('bad@1'));
    expect(h.selected, ['bad@1']);
  });

  testWidgets('a rebuild with the same key requests no thumbnail again',
      (tester) async {
    // MUTATION: imageFor on every widget update (`if (true || ...`) -> the
    // request count grows on a selection or an enabled change.
    final h = Harness(tester);
    addTearDown(h.dispose);
    await h.pump();
    await h.settleImages();
    final before = h.thumbnails.requests.length;
    expect(before, 4, reason: 'one request per cell');
    await h.pump(selectedId: 'sofa@1');
    await h.settleImages();
    await h.pump(selectedId: 'sofa@1', enabled: false);
    await h.settleImages();
    expect(h.thumbnails.requests, hasLength(before));
    expect(h.thumbnails.length, 4);
    for (final id in ['chair@1', 'chair@2', 'sofa@1', 'table@1']) {
      final image = shownImage(tester, id);
      expect(image, isNotNull, reason: id);
      expect(image!.debugDisposed, isFalse, reason: id);
    }
  });

  testWidgets('a cell whose entry is evicted while pending still shows a clone',
      (tester) async {
    // MUTATION: the clone is taken after an await gap (`async { await null;
    // ...`) -> the evicted image is disposed first, the cell shows nothing.
    final h = Harness(tester, maxEntries: 1);
    addTearDown(h.dispose);
    final two = [
      GalleryCategory(name: 'Pair', symbols: [
        sym('left@1', 'Left', 1),
        sym('right@1', 'Right', 3),
      ]),
    ];
    await h.pump(categories: two);
    // Both requested in one build: the first entry was evicted while pending.
    expect(h.thumbnails.requests, hasLength(2));
    expect(h.thumbnails.length, 1);
    await h.settleImages();
    await tester.pump();
    final evicted = await tester.runAsync(() => h.thumbnails.requests.first);
    expect(evicted!.debugDisposed, isTrue,
        reason: 'the cache disposed the evicted original');
    for (final id in ['left@1', 'right@1']) {
      final image = shownImage(tester, id);
      expect(image, isNotNull, reason: id);
      expect(image!.debugDisposed, isFalse, reason: id);
    }
    expect(shownImage(tester, 'left@1')!.isCloneOf(evicted), isTrue);
    expect(h.thumbnails.requests, hasLength(2), reason: 'no re-request');
  });
}
