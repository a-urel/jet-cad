// Spec 09c D7, revision 5 (R5-2..R5-4, R5-7, V-1, V-3..V-7): the Symbol
// section -- name, size, Rotation, Mirror and the Size menu -- and the
// commands behind them. Hand-made symbols, so every rule has a fixture that
// can tell it apart: a bed family whose base point is the box's centre (not
// its back-left corner), a servable member in that family, a family of
// tables, and a corner seat whose base point is off its box's centre x.
// Instances sit 40 m off the origin, mirrored and turned 30 degrees.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/selection_panel.dart';
import 'package:jet_cad_floor_plan/src/symbols/build_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_box.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_loader.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_section.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label_system.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A [w] x [d] rectangle, base point at its centre.
FurnitureSymbol rect(String key, double w, double d,
        {List<String> tags = const [], int? seats, double? baseX}) =>
    FurnitureSymbol(
      key: key,
      name: 'Test $key',
      category: 'Tests',
      tags: tags,
      seats: seats,
      baseX: baseX ?? w / 2,
      baseY: d / 2,
      shapes: [
        PolylineShape([(0, 0), (w, 0), (w, d), (0, d)], closed: true),
        PolylineShape([(w * 0.2, d * 0.7), (w * 0.8, d * 0.7)]),
      ],
    );

const bedTags = ['bed', 'against-wall', 'family:test-bed'];
final List<FurnitureSymbol> catalog = [
  rect('test.bed.1800', 1800, 2000, tags: bedTags),
  rect('test.bed.1400', 1400, 2000, tags: bedTags),
  rect('test.bed.1600', 1600, 2000, tags: bedTags),
  // Servable, in the beds' family: never offered (V-4).
  rect('test.bed.table', 1500, 2000, tags: bedTags, seats: 2),
  rect('test.table.a', 900, 900,
      tags: ['table', 'family:test-tables'], seats: 2),
  rect('test.table.b', 1200, 900,
      tags: ['table', 'family:test-tables'], seats: 4),
  // A corner seat: its base point at x 1100 of a 2000-wide box.
  rect('test.corner', 2000, 1000, seats: 3, baseX: 1100),
];

Uint8List libraryBytes() => Uint8List.fromList(utf8
    .encode(DraftDocumentCodec.encodeToString(buildSymbolLibrary(catalog))));

final SymbolLibrary library = SymbolLibrary.decode(libraryBytes());
SymbolEntry entry(String key) =>
    library.entries.singleWhere((e) => e.key == key);

const double kDeg30 = 30 * math.pi / 180;

DraftDocument rig() {
  final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  final parametric = installParametric(doc);
  final tables = TableLabelSystem(doc)..install();
  addTearDown(() {
    tables.dispose();
    parametric.dispose();
  });
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
      final h = place(doc, 'test.corner', far, mirrored: false);
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
      final members = familyMembers(library, entry('test.bed.1600'));
      expect([for (final m in members) m.key],
          ['test.bed.1400', 'test.bed.1600', 'test.bed.1800']);
      expect(identical(familyMembers(library, entry('test.bed.1400')), members),
          isTrue,
          reason: 'memoised per library and family');
      expect(familyMembers(library, entry('test.corner')), isEmpty);
    });

    test('SS8 the entry: the exact version, else the key\'s highest (V-5)', () {
      final doc = rig();
      final h = place(doc, 'test.bed.1600', far);
      expect(entryOfInstance(library, doc, h)!.key, 'test.bed.1600');
      final v2 = SymbolLibrary.decode(Uint8List.fromList(
          utf8.encode(DraftDocumentCodec.encodeToString(buildSymbolLibrary([
        FurnitureSymbol(
            key: 'test.bed.1600',
            name: 'v2',
            category: 'Tests',
            tags: bedTags,
            version: 2,
            baseX: 800,
            baseY: 1000,
            shapes: const [
              PolylineShape([(0, 0), (1600, 0), (1600, 2000), (0, 2000)],
                  closed: true)
            ]),
      ])))));
      expect(entryOfInstance(v2, doc, h)!.version, 2,
          reason: 'no v1 here: the highest');
    });

    test(
        'SS9 a copy asserts the entry\'s leaves ascending by handle '
        '(R5-7, V-7)', () {
      final e = entry('test.bed.1600');
      final shuffled = SymbolEntry(
        key: e.key,
        name: e.name,
        category: e.category,
        tags: e.tags,
        version: e.version,
        seats: e.seats,
        definition: e.definition,
        leaves: e.leaves.reversed.toList(),
      );
      expect(() => definitionForEntry(rig(), shuffled),
          throwsA(isA<AssertionError>()));
    });
  });

  group('the panel', () {
    Finder byKey(String k) => find.byKey(Key(k));

    Future<SelectionController> pumpPanel(
        WidgetTester tester, DraftDocument doc,
        {SymbolLibraryLoader? symbols}) async {
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectionPanel(
                document: doc, selection: selection, symbols: symbols),
          ),
        ),
      ));
      return selection;
    }

    Future<SymbolLibraryLoader> loader(WidgetTester tester,
        {bool load = true}) async {
      final l = SymbolLibraryLoader(read: () async => libraryBytes());
      addTearDown(l.dispose);
      if (load) await tester.runAsync(l.load);
      return l;
    }

    Future<void> select(
        WidgetTester tester, SelectionController s, List<Handle> hs) async {
      s.replace([for (final h in hs) SelectionKey.root(h)]);
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
      final doc = rig();
      final bed = place(doc, 'test.bed.1600', far);
      final other = place(doc, 'test.bed.1400', far + Vector2(4000, 0));
      final table = place(doc, 'test.table.a', far + Vector2(0, 4000));
      final s = await pumpPanel(tester, doc);
      await select(tester, s, [bed]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(
          tester.widget<Text>(byKey('symbol-name')).data, 'Test test.bed.1600');
      expect(tester.widget<Text>(byKey('symbol-size')).data, '1600 × 2000');
      expect(
          tester.widget<TextField>(byKey('symbol-rotation')).controller!.text,
          '30');
      await select(tester, s, [bed, other]);
      expect(byKey('symbol-section'), findsNothing);
      await select(tester, s, [table]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(byKey('table-section'), findsOneWidget);
    });

    testWidgets(
        'SW2 a typed rotation is one step; a word reverts; Mirror is one step',
        (tester) async {
      final doc = rig();
      final bed = place(doc, 'test.bed.1600', far);
      final s = await pumpPanel(tester, doc);
      await select(tester, s, [bed]);
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
      final doc = rig();
      final bed = place(doc, 'test.bed.1600', far);
      final l = await loader(tester, load: false);
      final s = await pumpPanel(tester, doc, symbols: l);
      await select(tester, s, [bed]);
      expect(byKey('symbol-size-menu'), findsNothing, reason: 'not ready');
      await tester.runAsync(l.load);
      await tester.pump();
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
      final doc = rig();
      final bed = place(doc, 'test.bed.1600', far);
      final table = place(doc, 'test.table.a', far + Vector2(0, 4000));
      final l = await loader(tester);
      final s = await pumpPanel(tester, doc, symbols: l);
      doc.commands.permissions = DraftPermissions.runtime;
      await select(tester, s, [bed]);
      expect(editable(tester), isTrue);
      expect(mirrorEnabled(tester), isTrue);
      expect(menuEnabled(tester), isFalse);
      await select(tester, s, [table]);
      expect(editable(tester), isFalse, reason: 'a table: the design mode');
      expect(mirrorEnabled(tester), isFalse);
      doc.commands.permissions = const DraftPermissions(
          transform: true, components: true, geometry: false, structure: true);
      await select(tester, s, [bed]);
      expect(menuEnabled(tester), isFalse);
      doc.commands.permissions = DraftPermissions.all;
      await select(tester, s, [table]);
      await select(tester, s, [bed]);
      expect(menuEnabled(tester), isTrue);
    });

    testWidgets(
        'SW5 a table has no Size menu even with a family (R5-3, M-09c-bf)',
        (tester) async {
      final doc = rig();
      final table = place(doc, 'test.table.a', far);
      final s = await pumpPanel(tester, doc, symbols: await loader(tester));
      await select(tester, s, [table]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(byKey('symbol-size-menu'), findsNothing);
    });

    testWidgets(
        'SW6 a corner table turned to 37 then mirrored: its number stays '
        'upright, its footprint stays; one undo each (R5-2, V-6)',
        (tester) async {
      final doc = rig();
      final corner = place(doc, 'test.corner', far, mirrored: false);
      final s = await pumpPanel(tester, doc);
      await select(tester, s, [corner]);
      void expectUpright(String why) {
        final info =
            TableSurvey.of(doc).tables.singleWhere((t) => t.instance == corner);
        final slot = doc.entities.slotOf(info.label!)!;
        final scalars =
            doc.geometry.read(doc.entities.geomIndexAt(slot)).scalars;
        final want = tableLabelStamp(transformOf(doc, corner));
        expect(scalars[1], closeTo(want.rotation, 1e-12), reason: why);
        expect(scalars[2], want.widthFactor, reason: why);
      }

      final depth = doc.commands.undoDepth;
      await typeRotation(tester, '37');
      expect(rotationDegreesOf(transformOf(doc, corner)), closeTo(37, 1e-9));
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
  });
}
