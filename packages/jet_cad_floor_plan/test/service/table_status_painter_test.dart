// Spec 14c S5-S7, R-2, R-3, R-10: the status layer. Fills follow the
// tables' numbers, skip hidden tables, sit where the turned, mirrored,
// asymmetric top is (pixels read back), and steady frames pass the same
// objects to the canvas (the allocation bar, measured structurally).
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/service/table_status_painter.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// Records what the painter hands the canvas, by identity.
class SpyCanvas implements ui.Canvas {
  final List<Object> seen = [];
  final List<ui.Path> paths = [];
  final List<ui.Paint> paints = [];
  final List<ui.Offset> translations = [];
  final List<ui.Paragraph> paragraphs = [];

  @override
  void save() {}
  @override
  void restore() {}
  @override
  void translate(double dx, double dy) => translations.add(ui.Offset(dx, dy));
  @override
  void transform(Float64List matrix4) => seen.add(matrix4);
  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    seen
      ..add(path)
      ..add(paint);
    paths.add(path);
    paints.add(paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    expect(offset, ui.Offset.zero, reason: 'no Offset per frame (R-3)');
    seen.add(paragraph);
    paragraphs.add(paragraph);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// [n] trapezoid tables in a row 40 m off the origin, each turned 37 degrees
/// and mirrored; numbered 1..n.
DraftDocument rowOfTables(int n) {
  final doc = plan();
  for (var i = 0; i < n; i++) {
    final at = Vector2(40000.0 + 2500 * (i % 10), -27000.0 - 2500 * (i ~/ 10));
    doc.commands.execute(
        placeSymbol(doc, entryOf(trapezoidTable), at: at, mirrored: true));
    final node = doc.tree.nodes
        .whereType<InstanceNode>()
        .reduce((a, b) => a.handle.value > b.handle.value ? a : b);
    final turn = Transform2.translation(at.x, at.y)
        .multiply(Transform2.rotation(kDeg37))
        .multiply(Transform2.translation(-at.x, -at.y));
    doc.commands.execute(
        TransformNodeCommand(node.handle, turn.multiply(node.transform)));
  }
  return doc;
}

/// The first table at screen (400, 300), 0.1 px per mm.
ValueNotifier<ViewportTransform> cameraOn(DraftDocument doc) {
  final first = doc.tree[TableSurvey.of(doc).withNumber('1').single.instance]!
      as InstanceNode;
  final c = first.transform.transformPoint(Vector2(900, 650));
  return ValueNotifier(ViewportTransform(
      worldToScreenMatrix:
          Transform2(0.1, 0, 0, -0.1, 400 - 0.1 * c.x, 300 + 0.1 * c.y)));
}

TableStatusPainter painterFor(
        DraftDocument doc,
        ValueNotifier<ViewportTransform> camera,
        ValueNotifier<Map<String, TableStatus>> statuses) =>
    TableStatusPainter(
        document: doc,
        camera: camera,
        statuses: statuses,
        repaint: Listenable.merge([camera, statuses]));

void main() {
  test(
      'SP1 N = 60 statused tables: after warm-up every frame passes the same '
      'objects, the camera moving (M-14c2-8)', () {
    final doc = rowOfTables(60);
    final camera = cameraOn(doc);
    final statuses = ValueNotifier<Map<String, TableStatus>>({
      for (var i = 1; i <= 60; i++)
        '$i': TableStatus(
            color: Color(0xFF000000 | (i * 0x030507)),
            caption: i.isEven ? 'Bill' : null),
    });
    final painter = painterFor(doc, camera, statuses);
    const size = ui.Size(1600, 1200);
    SpyCanvas frame() {
      final spy = SpyCanvas();
      painter.paint(spy, size);
      return spy;
    }

    for (var i = 0; i < 3; i++) {
      frame();
    }
    final made = painter.debugAllocations;
    final reference = frame().seen;
    expect(reference.whereType<ui.Path>(), hasLength(60));
    for (final t in [
      Transform2(0.13, 0, 0, -0.13, -5000, 4200),
      Transform2(0.02, 0, 0, -0.02, -700, 900),
    ]) {
      camera.value = ViewportTransform(worldToScreenMatrix: t);
      frame(); // a zoomed frame may skip captions: not compared
    }
    camera.value = cameraOn(doc).value;
    final again = frame().seen;
    expect(again.length, reference.length);
    for (var i = 0; i < again.length; i++) {
      expect(identical(again[i], reference[i]), isTrue, reason: 'item $i');
    }
    expect(painter.debugAllocations, made, reason: 'nothing new per frame');
  });

  testWidgets(
      'SP2 the fill lies on the turned, mirrored, asymmetric top: inside '
      'near its edges, not where the mirror would put it (M-14g)',
      (tester) async {
    final doc = rowOfTables(1);
    final camera = cameraOn(doc);
    final statuses = ValueNotifier<Map<String, TableStatus>>(
        {'1': TableStatus(color: const Color(0xFF2E7D32))});
    final painter = painterFor(doc, camera, statuses);
    final node = doc.tree[TableSurvey.of(doc).withNumber('1').single.instance]!
        as InstanceNode;
    (int, int) screen(double x, double y) {
      final w = node.transform.transformPoint(Vector2(x, y));
      final s = camera.value.worldToScreen(w);
      return (s.x.round(), s.y.round());
    }

    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      painter.paint(ui.Canvas(recorder), const ui.Size(800, 600));
      final image = await recorder.endRecording().toImage(800, 600);
      final data = await image.toByteData();
      image.dispose();
      return data!;
    });
    int alphaAt((int, int) p) => bytes!.getUint8((p.$2 * 800 + p.$1) * 4 + 3);
    for (final (x, y) in [(1200.0, 920.0), (600.0, 860.0), (300.0, 350.0)]) {
      expect(alphaAt(screen(x, y)), 255, reason: 'inside at ($x, $y)');
    }
    for (final (x, y) in [(1450.0, 950.0), (380.0, 920.0), (1700.0, 350.0)]) {
      expect(alphaAt(screen(x, y)), 0, reason: 'outside at ($x, $y)');
    }
  });

  test('SP3 a hidden table is not painted (M-14c2-10)', () {
    final doc = rowOfTables(2);
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    final hidden = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: hidden,
        name: 'Hidden',
        color: const IndexedColor(2),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: false,
        locked: false)));
    doc.commands.execute(SetInstanceLayerCommand(
        TableSurvey.of(doc).withNumber('2').single.instance, hidden));
    final statuses = ValueNotifier<Map<String, TableStatus>>({
      '1': TableStatus(color: const Color(0xFFAA0000)),
      '2': TableStatus(color: const Color(0xFF0000AA)),
    });
    final spy = SpyCanvas();
    painterFor(doc, cameraOn(doc), statuses)
        .paint(spy, const ui.Size(800, 600));
    expect(spy.paths, hasLength(1));
  });

  test(
      'SP4 a status follows the number: a renumber moves the fill; a number '
      'used twice fills both (M-14c2-7)', () {
    final doc = plan();
    doc.commands.execute(placeSymbol(doc, entryOf(trapezoidTable),
        at: Vector2(-3000, 0), mirrored: true));
    doc.commands.execute(
        placeSymbol(doc, entryOf(tableSymbol()), at: Vector2(3000, 0)));
    final camera = ValueNotifier(ViewportTransform(
        worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, 400, 300)));
    final statuses = ValueNotifier<Map<String, TableStatus>>(
        {'1': TableStatus(color: const Color(0xFFAA0000))});
    final painter = painterFor(doc, camera, statuses);
    ui.Rect drawn() {
      final spy = SpyCanvas();
      painter.paint(spy, const ui.Size(800, 600));
      return spy.paths.single.getBounds();
    }

    expect(drawn(), const ui.Rect.fromLTRB(200, 300, 1600, 1000),
        reason: 'the trapezoid is 1');
    final s = TableSurvey.of(doc);
    doc.commands.execute(SetEntityTextCommand(
        s.withNumber('1').single.label!, '5', kTableLabelTag));
    doc.commands.execute(SetEntityTextCommand(
        s.withNumber('2').single.label!, '1', kTableLabelTag));
    expect(drawn(), const ui.Rect.fromLTRB(300, 300, 1500, 1100),
        reason: 'the rectangle is 1 now');
    doc.commands.execute(SetEntityTextCommand(
        TableSurvey.of(doc).withNumber('5').single.label!,
        '1',
        kTableLabelTag));
    final spy = SpyCanvas();
    painter.paint(spy, const ui.Size(800, 600));
    expect(spy.paths, hasLength(2));
  });

  test('SP5 a caption is cut to 12 characters, not code units (R-12)', () {
    final s =
        TableStatus(color: const Color(0xFF000000), caption: '👍🏽' * 13 + 'x');
    expect(s.caption, '👍🏽' * 12);
    expect(TableStatus(color: const Color(0xFF000000), caption: 'Bill'),
        TableStatus(color: const Color(0xFF000000), caption: 'Bill'));
  });

  test('SP6 fills are drawn in draw order, whatever the map\'s order', () {
    final doc = plan();
    doc.commands
        .execute(placeSymbol(doc, entryOf(trapezoidTable), at: Vector2(0, 0)));
    doc.commands
        .execute(placeSymbol(doc, entryOf(tableSymbol()), at: Vector2(0, 0)));
    final statuses = ValueNotifier<Map<String, TableStatus>>({
      '2': TableStatus(color: const Color(0xFFAA0000)),
      '1': TableStatus(color: const Color(0xFF0000AA)),
    });
    final spy = SpyCanvas();
    painterFor(
            doc,
            ValueNotifier(ViewportTransform(
                worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, 400, 300))),
            statuses)
        .paint(spy, const ui.Size(800, 600));
    expect([
      for (final p in spy.paths) p.getBounds()
    ], const [
      ui.Rect.fromLTRB(200, 300, 1600, 1000),
      ui.Rect.fromLTRB(300, 300, 1500, 1100),
    ]);
  });

  test(
      'SP7 a new status map is drawn at once, the plan unchanged (R-4, '
      'review F-3)', () {
    final doc = rowOfTables(2);
    final statuses = ValueNotifier<Map<String, TableStatus>>(
        {'1': TableStatus(color: const Color(0xFFAA0000))});
    final painter = painterFor(doc, cameraOn(doc), statuses);
    SpyCanvas frame() {
      final spy = SpyCanvas();
      painter.paint(spy, const ui.Size(800, 600));
      return spy;
    }

    expect(frame().paints.single.color.toARGB32(), 0xFFAA0000);
    statuses.value = {
      '1': TableStatus(color: const Color(0xFF0000AA)),
      '2': TableStatus(color: const Color(0xFF00AA00)),
    };
    expect([for (final p in frame().paints) p.color.toARGB32()],
        [0xFF0000AA, 0xFF00AA00]);
    statuses.value = const {};
    expect(frame().paths, isEmpty);
  });

  // A trapezoid whose base point, where the number sits, is off its top's
  // centre (900, 650).
  const offCentre = FurnitureSymbol(
    key: 'test.trapezoid.off',
    name: 'Off-centre trapezoid',
    category: 'Tests',
    tags: ['table', 'test'],
    seats: 2,
    baseX: 1200,
    baseY: 500,
    shapes: [
      PolylineShape([(200, 300), (1600, 300), (1300, 1000), (500, 900)],
          closed: true),
    ],
  );

  test(
      'SP8 the caption sits centred below the number, clear of it at any '
      'zoom; a table smaller than its caption has none (S7, review F-4, '
      'F-5)', () {
    final doc = plan();
    final at = Vector2(40000, -27000);
    doc.commands
        .execute(placeSymbol(doc, entryOf(offCentre), at: at, mirrored: true));
    final node = doc.tree.nodes.whereType<InstanceNode>().single;
    final turn = Transform2.translation(at.x, at.y)
        .multiply(Transform2.rotation(kDeg37))
        .multiply(Transform2.translation(-at.x, -at.y));
    doc.commands.execute(
        TransformNodeCommand(node.handle, turn.multiply(node.transform)));
    // The base point lands on `at`; the camera puts it at (400, 300).
    final camera = ValueNotifier(ViewportTransform(
        worldToScreenMatrix:
            Transform2(0.1, 0, 0, -0.1, 400 - 4000, 300 - 2700)));
    final statuses = ValueNotifier<Map<String, TableStatus>>({
      '1': TableStatus(color: const Color(0xFFAA0000), caption: 'Bill'),
    });
    final painter = painterFor(doc, camera, statuses);
    SpyCanvas frame() {
      final spy = SpyCanvas();
      painter.paint(spy, const ui.Size(800, 600));
      return spy;
    }

    // The label's height: min(200, 0.4 x 700) = 200, so 100 below the
    // anchor, plus a 2 px gap, or 11 px when that is less.
    for (final (scale, below) in [(0.1, 12.0), (0.5, 52.0), (0.07, 11.0)]) {
      camera.value = ViewportTransform(
          worldToScreenMatrix: Transform2(
              scale, 0, 0, -scale, 400 - scale * at.x, 300 + scale * at.y));
      final spy = frame();
      final p = spy.paragraphs.single;
      expect(spy.translations.single.dx, closeTo(400 - p.width / 2, 1e-6),
          reason: 'x at $scale');
      expect(spy.translations.single.dy, closeTo(300 + below, 1e-6),
          reason: 'y at $scale');
    }
    camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(
            0.001, 0, 0, -0.001, 400 - 0.001 * at.x, 300 + 0.001 * at.y));
    final tiny = frame();
    expect(tiny.paths, hasLength(1), reason: 'the fill stays');
    expect(tiny.paragraphs, isEmpty, reason: 'the caption does not');
  });

  test('SP9 captions and paints no table holds are dropped (review F-8)', () {
    final doc = rowOfTables(2);
    final statuses = ValueNotifier<Map<String, TableStatus>>({});
    final painter = painterFor(doc, cameraOn(doc), statuses);
    for (var minute = 0; minute < 30; minute++) {
      statuses.value = {
        '1': TableStatus(
            color: Color(0xFF000000 | minute), caption: '$minute min'),
        '2': TableStatus(color: const Color(0xFF00AA00), caption: 'Bill'),
      };
      painter.paint(SpyCanvas(), const ui.Size(800, 600));
    }
    expect(painter.debugCached, 4, reason: 'two paints, two captions');
    statuses.value = const {};
    painter.paint(SpyCanvas(), const ui.Size(800, 600));
    expect(painter.debugCached, 0);
  });
}
