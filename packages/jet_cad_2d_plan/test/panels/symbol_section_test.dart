// Ported from jet_cad_floor_plan/test/symbols/symbol_section_test.dart; assertions unchanged.
//
// Spec 09c D7, revision 5 (R5-2..R5-4, R5-7, V-1, V-3..V-7): the Symbol
// section -- name, size, Rotation, Mirror and the Size menu -- and the
// commands behind them, over a kit library ("test") built with the
// authoring toolkit. Hand-made symbols, so every rule has a fixture that
// can tell it apart: a bed family whose base point is the box's centre (not
// its back-left corner), a servable member in that family, a family of
// tables, and a corner seat whose base point is off its box's centre x.
// Instances sit 40 m off the origin, mirrored and turned 30 degrees.
//
// SS9 (definitionForEntry's assertion) is Task 13's; SW6 and SW9 (a unit's
// label, the runtime unit rule) are 2b's (Task 10), over the library's
// corner seat and table A, which are units; SW7 (a loader handed to the
// panel) has no counterpart: the controller owns the loader (Task 13).
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer, SelectionKey;
import 'package:jet_cad_2d_kit/authoring.dart'
    show
        Catalog,
        CatalogLine,
        CatalogPolyline,
        CatalogSymbol,
        CatalogUnit,
        encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/panels/symbol_section.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_box.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/unit_fixtures.dart' show addUnitLabel;

/// A [w] x [d] rectangle, base point at its centre.
CatalogSymbol rect(String key, double w, double d,
        {List<String> tags = const [],
        int? seats,
        double? baseX,
        String? family}) =>
    CatalogSymbol(
      key: key,
      name: 'Test $key',
      category: 'Tests',
      tags: tags,
      family: family,
      unit: seats == null
          ? null
          : CatalogUnit(kind: UnitKinds.table, capacity: seats),
      base: (baseX ?? w / 2, d / 2),
      shapes: [
        CatalogPolyline([(0, 0), (w, 0), (w, d), (0, d)], closed: true),
        CatalogLine((w * 0.2, d * 0.7), (w * 0.8, d * 0.7)),
      ],
    );

const bedTags = ['bed'];

// K2's library rule 9 refuses a unit in a size family: the library holds
// today's servable bed and its tables with no family, and [familyEntries]
// puts today's servable bed back in the beds' family, by hand, for the
// family rule (V-4) the library can no longer express.
final List<CatalogSymbol> catalog = [
  rect('test.bed.1800', 1800, 2000, tags: bedTags, family: 'test-bed'),
  rect('test.bed.1400', 1400, 2000, tags: bedTags, family: 'test-bed'),
  rect('test.bed.1600', 1600, 2000, tags: bedTags, family: 'test-bed'),
  // Servable: never offered (V-4).
  rect('test.bed.table', 1500, 2000, tags: bedTags, seats: 2),
  rect('test.table.a', 900, 900, tags: ['table'], seats: 2),
  rect('test.table.b', 1200, 900, tags: ['table'], seats: 4),
  // A corner seat: its base point at x 1100 of a 2000-wide box.
  rect('test.corner.seat', 2000, 1000, seats: 3, baseX: 1100),
];

Uint8List libraryBytes() =>
    encodeLibrary(Catalog(kit: 'test', symbols: catalog));

final SymbolLibrary library = SymbolLibrary.decode(libraryBytes());

/// [library]'s entries with `test.bed.table` in the beds' family, as
/// today's catalog had it (a servable member, V-4).
final List<SymbolEntry> familyEntries = List.unmodifiable([
  for (final e in library.entries)
    if (e.symbol.key == 'test.bed.table')
      SymbolEntry(
          symbol: SymbolComponent(
              key: e.symbol.key,
              version: e.symbol.version,
              name: e.symbol.name,
              category: e.symbol.category,
              tags: e.symbol.tags,
              family: 'test-bed'),
          unit: e.unit,
          definition: e.definition,
          leaves: e.leaves)
    else
      e,
]);

SymbolEntry entry(String key) =>
    familyEntries.singleWhere((e) => e.symbol.key == key);

const double kDeg30 = 30 * math.pi / 180;

DraftDocument rig() {
  final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

/// [key] placed at [at], mirrored when asked, then turned 30 degrees about
/// [at]; returns the instance.
Handle place(DraftDocument doc, String key, Vector2 at,
    {bool mirrored = true}) {
  doc.commands
      .execute(placeSymbol(doc, entry(key), at: at, mirrored: mirrored));
  final node = doc.tree.nodes
      .whereType<InstanceNode>()
      .reduce((a, b) => a.handle.value > b.handle.value ? a : b);
  final turn = Transform2.translation(at.x, at.y)
      .multiply(Transform2.rotation(kDeg30))
      .multiply(Transform2.translation(-at.x, -at.y));
  doc.commands.execute(
      TransformNodeCommand(node.handle, turn.multiply(node.transform)));
  return node.handle;
}

Transform2 transformOf(DraftDocument doc, Handle h) =>
    (doc.tree[h]! as InstanceNode).transform;

/// The world corners of [h]'s box, as a sorted list of rounded points.
List<(double, double)> footprint(DraftDocument doc, Handle h) {
  final node = doc.tree[h]! as InstanceNode;
  final b = boxOfDefinition(doc, node.definition)!;
  final t = node.transform;
  final out = [
    for (final (x, y) in [
      (b.left, b.front),
      (b.right, b.front),
      (b.right, b.back),
      (b.left, b.back),
    ])
      (() {
        final p = t.transformPoint(Vector2(x, y));
        return (
          (p.x * 1e6).roundToDouble() / 1e6,
          (p.y * 1e6).roundToDouble() / 1e6
        );
      })(),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return out;
}

void expectNear(Vector2 got, Vector2 want, String why) {
  expect(got.x, closeTo(want.x, 1e-6), reason: why);
  expect(got.y, closeTo(want.y, 1e-6), reason: why);
}

final Vector2 far = Vector2(40000, -27000);

void main() {
  group('the model', () {
    test(
        'SS1 the Rotation reads the local y column: a mirrored instance at '
        '30 degrees reads 30, not 150 (M-09c-x)', () {
      final doc = rig();
      final h = place(doc, 'test.bed.1600', far);
      expect(transformOf(doc, h).determinant, lessThan(0), reason: 'premise');
      expect(rotationDegreesOf(transformOf(doc, h)), closeTo(30, 1e-9));
      final plain = place(doc, 'test.bed.1600', far, mirrored: false);
      expect(rotationDegreesOf(transformOf(doc, plain)), closeTo(30, 1e-9));
    });

    test(
        'SS2 a Rotation composes about the insertion point and keeps the '
        'mirror and a file\'s scale (M-09c-y, M-09c-al)', () {
      final doc = rig();
      final h = place(doc, 'test.bed.1600', far);
      // A file's scale of 1.5 about the insertion point.
      final t0 = transformOf(doc, h);
      final base = doc.tree
          .definition((doc.tree[h]! as InstanceNode).definition)!
          .basePoint;
      final p = t0.transformPoint(base);
      doc.commands.execute(TransformNodeCommand(
          h,
          Transform2.translation(p.x, p.y)
              .multiply(Transform2.scale(1.5, 1.5))
              .multiply(Transform2.translation(-p.x, -p.y))
              .multiply(t0)));
      final t = transformOf(doc, h);
      final next = rotatedTo(t, base, 67);
      expectNear(next.transformPoint(base), p, 'the insertion point stays');
      expect(rotationDegreesOf(next), closeTo(67, 1e-9));
      expect(next.determinant, closeTo(t.determinant, 1e-6),
          reason: 'the mirror and the scale are kept');
    });

    test(
        'SS3 quarter turns are exact; 370 is 10; -90 is 270; -0.0 is '
        'normalised', () {
      final doc = rig();
      final h = place(doc, 'test.bed.1600', far);
      final t = transformOf(doc, h);
      final base = doc.tree
          .definition((doc.tree[h]! as InstanceNode).definition)!
          .basePoint;
      final q = rotatedTo(t, base, 90);
      expect([q.a, q.b, q.c, q.d], [0.0, -1.0, -1.0, 0.0],
          reason: 'R(90)·mirror, exactly');
      for (final v in [q.a, q.b, q.c, q.d, q.e, q.f]) {
        expect(v.isNegative && v == 0, isFalse, reason: 'no -0.0');
      }
      expect(rotationDegreesOf(rotatedTo(t, base, 370)), closeTo(10, 1e-9));
      expect(rotationDegreesOf(rotatedTo(t, base, -90)), closeTo(270, 1e-9));
    });

    test(
        'SS4 Mirror keeps the footprint, about the box\'s centre x, not the '
        'base point (M-09c-bh)', () {
      final doc = rig();
      final h = place(doc, 'test.corner.seat', far, mirrored: false);
      final before = footprint(doc, h);
      final det = transformOf(doc, h).determinant;
      doc.commands.execute(mirrorSymbolCommand(doc, h)!);
      expect(footprint(doc, h), before);
      expect(transformOf(doc, h).determinant, closeTo(-det, 1e-9));
    });

    test(
        'SS5 a size change keeps the back-left corner and the linear part; '
        'mirrored, a wider bed grows the other way (M-09c-u)', () {
      final doc = rig();
      for (final mirrored in [false, true]) {
        final h = place(doc, 'test.bed.1600', far, mirrored: mirrored);
        final t = transformOf(doc, h);
        final corner = t.transformPoint(Vector2(0, 2000));
        doc.commands
            .execute(changeSizeCommand(doc, h, entry('test.bed.1800'))!);
        final n = transformOf(doc, h);
        expect([n.a, n.b, n.c, n.d], [t.a, t.b, t.c, t.d]);
        expectNear(n.transformPoint(Vector2(0, 2000)), corner, 'back-left');
        final node = doc.tree[h]! as InstanceNode;
        expect(boxOfDefinition(doc, node.definition)!.width, 1800);
        // The right side moved 200 mm along the local x axis, which a
        // mirror turns around.
        final right = n.transformPoint(Vector2(1800, 2000));
        final oldRight = t.transformPoint(Vector2(1600, 2000));
        final dir = t.transformPoint(Vector2(1, 0))
          ..sub(t.transformPoint(Vector2.zero()));
        expectNear(right - oldRight, dir * 200, 'grows along local +x');
      }
    });

    test(
        'SS6 a size change reuses a definition already in the plan, and is '
        'one undo step (M-09c-v)', () {
      final doc = rig();
      place(doc, 'test.bed.1800', far + Vector2(5000, 0));
      final h = place(doc, 'test.bed.1600', far);
      final definitions = doc.tree.definitions.length;
      final depth = doc.commands.undoDepth;
      final before = transformOf(doc, h);
      doc.commands.execute(changeSizeCommand(doc, h, entry('test.bed.1800'))!);
      expect(doc.tree.definitions.length, definitions, reason: 'reused');
      expect(doc.commands.undoDepth, depth + 1);
      doc.commands.undo();
      expect(transformOf(doc, h).e, before.e);
      expect(
          boxOfDefinition(doc, (doc.tree[h]! as InstanceNode).definition)!
              .width,
          1600);
    });

    test(
        'SS7 the family: sorted by width, one per key, no servable member '
        '(V-4, V-5, M-09c-bi)', () {
      final members = familyMembers(familyEntries, entry('test.bed.1600'));
      expect([for (final m in members) m.symbol.key],
          ['test.bed.1400', 'test.bed.1600', 'test.bed.1800']);
      expect(
          identical(
              familyMembers(familyEntries, entry('test.bed.1400')), members),
          isTrue,
          reason: 'memoised per library and family');
      expect(familyMembers(familyEntries, entry('test.corner.seat')), isEmpty);
    });

    test('SS8 the entry: the exact version, else the key\'s highest (V-5)', () {
      final doc = rig();
      final h = place(doc, 'test.bed.1600', far);
      expect(entryOfInstance(library.entries, doc, h)!.symbol.key,
          'test.bed.1600');
      final v2 =
          SymbolLibrary.decode(encodeLibrary(Catalog(kit: 'test', symbols: [
        const CatalogSymbol(
            key: 'test.bed.1600',
            name: 'v2',
            category: 'Tests',
            tags: bedTags,
            family: 'test-bed',
            version: 2,
            base: (
              800,
              1000
            ),
            shapes: [
              CatalogPolyline([(0, 0), (1600, 0), (1600, 2000), (0, 2000)],
                  closed: true)
            ]),
      ])));
      expect(entryOfInstance(v2.entries, doc, h)!.symbol.version, 2,
          reason: 'no v1 here: the highest');
    });

    test(
        'SS10 the Rotate step turns about the insertion point, not the box\'s '
        'centre nor the origin: a corner seat whose base point is off its '
        'centre x (M-09c-y)', () {
      final doc = rig();
      final h = place(doc, 'test.corner.seat', far, mirrored: false);
      final base = doc.tree
          .definition((doc.tree[h]! as InstanceNode).definition)!
          .basePoint;
      final box =
          boxOfDefinition(doc, (doc.tree[h]! as InstanceNode).definition)!;
      expect(base.x, isNot((box.left + box.right) / 2), reason: 'premise');
      final p = transformOf(doc, h).transformPoint(base);
      doc.commands.execute(rotateSymbolCommand(doc, h, 37)!);
      expect(rotationDegreesOf(transformOf(doc, h)), closeTo(37, 1e-9));
      expectNear(transformOf(doc, h).transformPoint(base), p,
          'the insertion point stays');
    });

    test(
        'SS11 re-picking the instance\'s own size is nothing, even when its '
        'definition was edited and would be copied afresh', () {
      final doc = rig();
      final h = place(doc, 'test.bed.1600', far);
      expect(changeSizeCommand(doc, h, entry('test.bed.1600')), isNull);
      // Edit one leaf of the definition: no longer leaf-equal to the entry.
      final def = (doc.tree[h]! as InstanceNode).definition;
      final e = doc.entities;
      final leaf = [
        for (final slot in e.liveSlots)
          if (e.ownerAt(slot) == def) e.handleAt(slot)
      ].last;
      final payload = doc.geometry.read(e.geomIndexAt(e.slotOf(leaf)!));
      final coords = Float64List.fromList(payload.coords)..[0] += 10;
      doc.commands.execute(SetEntityGeometryCommand(
          leaf, GeometryPayload(coords: coords, scalars: payload.scalars)));
      expect(
          definitionForEntry(doc, entry('test.bed.1600')).commands, isNotEmpty,
          reason: 'premise: the entry would be copied');
      expect(changeSizeCommand(doc, h, entry('test.bed.1600')), isNull);
    });

    test(
        'SS12 (new, Task 17 fix round 1) the Size menu offers a bed its '
        'family and a servable instance nothing, even when its entry names '
        'the beds\' family (V-4, R5-3, M-09c-bf)', () {
      final doc = rig();
      final bed = place(doc, 'test.bed.1600', far);
      final bedTable = place(doc, 'test.bed.table', far + Vector2(4000, 0));
      expect(entryOfInstance(familyEntries, doc, bedTable)!.symbol.family,
          'test-bed',
          reason: 'premise: the servable instance\'s entry has a family');
      expect(
          familyMembers(familyEntries, entry('test.bed.table')), hasLength(3),
          reason: 'premise: the family offers beds');
      expect([
        for (final m in sizeMenuMembers(familyEntries, doc, bed)) m.symbol.key
      ], [
        'test.bed.1400',
        'test.bed.1600',
        'test.bed.1800'
      ]);
      expect(sizeMenuMembers(familyEntries, doc, bedTable), isEmpty);
    });
  });

  group('the panel', () {
    Finder byKey(String k) => find.byKey(Key(k));

    /// Lets the controller's symbol load settle: a few pumps, as the
    /// gallery's tests do.
    Future<void> settle(WidgetTester tester, PlanController c) async {
      for (var i = 0;
          i < 10 && c.symbolsState.value == SymbolsState.loading;
          i++) {
        await tester.pump();
      }
      expect(c.symbolsState.value, SymbolsState.ready,
          reason: 'premise: the library loaded');
      await tester.pump();
    }

    /// A controller over the kit "test" whose one source reads
    /// [libraryBytes] (once [gate] completes, when given), and the panel
    /// over it; without a gate, once the library has loaded.
    Future<PlanController> pumpPanel(WidgetTester tester,
        {Completer<Uint8List>? gate}) async {
      final c = PlanController(kits: [
        PlanKit(id: 'test', version: '1.0.0', symbols: [
          SymbolLibrarySource(
              label: 'test',
              read: () => gate?.future ?? Future.value(libraryBytes())),
        ]),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlanPropertyPanel(controller: c),
          ),
        ),
      ));
      if (gate == null) await settle(tester, c);
      return c;
    }

    Future<void> select(
        WidgetTester tester, PlanController c, List<Handle> hs) async {
      c.selection.replace([for (final h in hs) SelectionKey.root(h)]);
      await tester.pump();
    }

    Future<void> typeRotation(WidgetTester tester, String text) async {
      await tester.pump(kDoubleTapTimeout * 2);
      await tester.tap(byKey('symbol-rotation'));
      await tester.pump();
      await tester.enterText(byKey('symbol-rotation'), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
    }

    bool editable(WidgetTester tester) =>
        !tester.widget<TextField>(byKey('symbol-rotation')).readOnly;
    bool mirrorEnabled(WidgetTester tester) =>
        tester.widget<OutlinedButton>(byKey('symbol-mirror')).onPressed != null;
    bool menuEnabled(WidgetTester tester) =>
        tester
            .widget<DropdownButton<SymbolEntry>>(byKey('symbol-size-menu'))
            .onChanged !=
        null;

    testWidgets(
        'SW1 one symbol shows name, size and rotation; two hide it; a table '
        'shows the Symbol and the Table sections', (tester) async {
      final c = await pumpPanel(tester);
      final doc = c.document;
      final bed = place(doc, 'test.bed.1600', far);
      final other = place(doc, 'test.bed.1400', far + Vector2(4000, 0));
      final table = place(doc, 'test.table.a', far + Vector2(0, 4000));
      await select(tester, c, [bed]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(
          tester.widget<Text>(byKey('symbol-name')).data, 'Test test.bed.1600');
      expect(tester.widget<Text>(byKey('symbol-size')).data, '1600 × 2000');
      expect(
          tester.widget<TextField>(byKey('symbol-rotation')).controller!.text,
          '30');
      await select(tester, c, [bed, other]);
      expect(byKey('symbol-section'), findsNothing);
      await select(tester, c, [table]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(byKey('unit-section'), findsOneWidget);
      expect(tester.getTopLeft(byKey('symbol-section')).dy,
          lessThan(tester.getTopLeft(byKey('unit-section')).dy),
          reason: 'the Symbol section above the Table section (R5-2)');
    });

    testWidgets(
        'SW2 a typed rotation is one step; a word reverts; Mirror is one step',
        (tester) async {
      final c = await pumpPanel(tester);
      final doc = c.document;
      final bed = place(doc, 'test.bed.1600', far);
      await select(tester, c, [bed]);
      final depth = doc.commands.undoDepth;
      // The bed reads 29.999999999999996 and shows 30: 30 again is nothing.
      await typeRotation(tester, '30');
      expect(doc.commands.undoDepth, depth, reason: 'the shown value again');
      await typeRotation(tester, '45');
      expect(rotationDegreesOf(transformOf(doc, bed)), closeTo(45, 1e-9));
      expect(doc.commands.undoDepth, depth + 1);
      await typeRotation(tester, '45');
      expect(doc.commands.undoDepth, depth + 1, reason: 'the same: nothing');
      await typeRotation(tester, 'east');
      expect(doc.commands.undoDepth, depth + 1);
      expect(
          tester.widget<TextField>(byKey('symbol-rotation')).controller!.text,
          '45');
      final before = footprint(doc, bed);
      await tester.tap(byKey('symbol-mirror'));
      await tester.pump();
      expect(doc.commands.undoDepth, depth + 2);
      expect(footprint(doc, bed), before);
    });

    testWidgets(
        'SW3 the Size menu appears when the library turns ready; a choice is '
        'one Change size step (V-3)', (tester) async {
      final gate = Completer<Uint8List>();
      final c = await pumpPanel(tester, gate: gate);
      final doc = c.document;
      final bed = place(doc, 'test.bed.1600', far);
      await select(tester, c, [bed]);
      expect(byKey('symbol-size-menu'), findsNothing, reason: 'not ready');
      gate.complete(libraryBytes());
      await settle(tester, c);
      expect(byKey('symbol-size-menu'), findsOneWidget);
      final depth = doc.commands.undoDepth;
      await tester.tap(byKey('symbol-size-menu'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('symbol-size-test.bed.1800').last);
      await tester.pumpAndSettle();
      expect(doc.commands.undoDepth, depth + 1);
      expect(tester.widget<Text>(byKey('symbol-size')).data, '1800 × 2000');
    });

    testWidgets(
        'SW4 under runtime a symbol turns and mirrors, its size does not; a '
        'table does neither; geometry alone denied disables the size '
        '(M-09c-be, M-09c-bg)', (tester) async {
      final c = await pumpPanel(tester);
      final doc = c.document;
      final bed = place(doc, 'test.bed.1600', far);
      final table = place(doc, 'test.table.a', far + Vector2(0, 4000));
      doc.commands.permissions = DraftPermissions.runtime;
      await select(tester, c, [bed]);
      expect(editable(tester), isTrue);
      expect(mirrorEnabled(tester), isTrue);
      expect(menuEnabled(tester), isFalse);
      await select(tester, c, [table]);
      expect(editable(tester), isFalse, reason: 'a table: the design mode');
      expect(mirrorEnabled(tester), isFalse);
      doc.commands.permissions = const DraftPermissions(
          transform: true, components: true, geometry: false, structure: true);
      await select(tester, c, [bed]);
      expect(menuEnabled(tester), isFalse);
      doc.commands.permissions = DraftPermissions.all;
      await select(tester, c, [table]);
      await select(tester, c, [bed]);
      expect(menuEnabled(tester), isTrue);
    });

    testWidgets(
        'SW5 a table has no Size menu, its family all tables or all beds '
        '(R5-3; K2 rule 9 leaves the loaded library\'s tables without a '
        'family, so M-09c-bf is pinned by SS12)', (tester) async {
      final c = await pumpPanel(tester);
      final doc = c.document;
      final table = place(doc, 'test.table.a', far);
      await select(tester, c, [table]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(byKey('symbol-size-menu'), findsNothing);
      // A servable member of the beds' family: its family lists three beds,
      // but a table never changes size.
      final bedTable = place(doc, 'test.bed.table', far + Vector2(4000, 0));
      expect(
          familyMembers(familyEntries, entry('test.bed.table')), hasLength(3),
          reason: 'premise: the family offers beds');
      await select(tester, c, [bedTable]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(byKey('symbol-size-menu'), findsNothing);
    });

    testWidgets(
        'SW6 a corner unit turned to 37 then mirrored: its label stays '
        'upright, its footprint stays; one undo each (R5-2, V-6)',
        (tester) async {
      final c = await pumpPanel(tester);
      final doc = c.document;
      final corner = place(doc, 'test.corner.seat', far, mirrored: false);
      addUnitLabel(doc, corner, '1');
      await select(tester, c, [corner]);
      void expectUpright(String why) {
        final info = c.unitIndex[corner]!;
        final slot = doc.entities.slotOf(info.label!)!;
        final scalars =
            doc.geometry.read(doc.entities.geomIndexAt(slot)).scalars;
        final want = unitLabelStamp(transformOf(doc, corner));
        expect(scalars[1], closeTo(want.rotation, 1e-12), reason: why);
        expect(scalars[2], want.widthFactor, reason: why);
      }

      final depth = doc.commands.undoDepth;
      final base = doc.tree
          .definition((doc.tree[corner]! as InstanceNode).definition)!
          .basePoint;
      final insertion = transformOf(doc, corner).transformPoint(base);
      await typeRotation(tester, '37');
      expect(rotationDegreesOf(transformOf(doc, corner)), closeTo(37, 1e-9));
      expectNear(transformOf(doc, corner).transformPoint(base), insertion,
          'turned about the insertion point (M-09c-y)');
      expectUpright('after the rotation');
      final before = footprint(doc, corner);
      await tester.tap(byKey('symbol-mirror'));
      await tester.pump();
      expect(footprint(doc, corner), before);
      expectUpright('after the mirror');
      expect(doc.commands.undoDepth, depth + 2);
      doc.commands.undo();
      expectUpright('after one undo');
      doc.commands.undo();
      expect(rotationDegreesOf(transformOf(doc, corner)), closeTo(30, 1e-9));
      expectUpright('after two');
    });

    testWidgets(
        'SW9 a rotation typed for a bed under runtime commits to the bed '
        'when the selection moves to a table before the edit ends: the '
        'pinned target decides (V-1)', (tester) async {
      final c = await pumpPanel(tester);
      final doc = c.document;
      final bed = place(doc, 'test.bed.1600', far);
      final table = place(doc, 'test.table.a', far + Vector2(0, 4000));
      doc.commands.permissions = DraftPermissions.runtime;
      await select(tester, c, [bed]);
      expect(editable(tester), isTrue, reason: 'premise: a bed turns');
      final tableBefore = transformOf(doc, table);
      await tester.pump(kDoubleTapTimeout * 2);
      await tester.tap(byKey('symbol-rotation'));
      await tester.pump();
      await tester.enterText(byKey('symbol-rotation'), '45');
      await select(tester, c, [table]);
      // The table's field is read-only: the input connection closes, and
      // the edit ends by losing focus, which commits (06 D13).
      expect(editable(tester), isFalse, reason: 'premise: a table does not');
      tester.binding.focusManager.primaryFocus!.unfocus();
      await tester.pump();
      await tester.pump();
      expect(rotationDegreesOf(transformOf(doc, bed)), closeTo(45, 1e-9),
          reason: 'the bed, which the field was pinned to');
      expect(transformOf(doc, table), tableBefore, reason: 'not the table');
    });

    testWidgets('SW8 the Rotation field offers a minus key (−90 on a phone)',
        (tester) async {
      final c = await pumpPanel(tester);
      final bed = place(c.document, 'test.bed.1600', far);
      await select(tester, c, [bed]);
      expect(tester.widget<TextField>(byKey('symbol-rotation')).keyboardType,
          const TextInputType.numberWithOptions(decimal: true, signed: true));
    });

    testWidgets(
        'P-mirror (Task 12 carry: mirror has no SelectGates member) the '
        'Mirror button follows PlanPermissions.mirror: hidden while it is '
        'off, back when it is on; the Rotation row stays (M-P-mirror)',
        (tester) async {
      final c = await pumpPanel(tester);
      final bed = place(c.document, 'test.bed.1600', far);
      c.permissions = PlanPermissions.full.copyWith(mirror: false);
      await select(tester, c, [bed]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(byKey('symbol-mirror'), findsNothing);
      expect(editable(tester), isTrue, reason: 'rotate is still on');
      c.permissions = PlanPermissions.full;
      await tester.pump();
      expect(byKey('symbol-mirror'), findsOneWidget);
      expect(mirrorEnabled(tester), isTrue);
    });
  });
}
