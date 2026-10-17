// Ported from jet_cad_floor_plan/test/service/table_status_painter_test.dart; assertions unchanged.
// Spec 14c S5-S7, R-2, R-3, R-10: the status layer. Fills follow the
// tables' numbers, skip hidden tables, sit where the turned, mirrored,
// asymmetric top is (pixels read back), and steady frames pass the same
// objects to the canvas (the allocation bar, measured structurally).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogPolyline, CatalogSymbol;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;
import 'package:jet_cad_2d_plan/src/service/paint/unit_status_painter.dart';
import 'package:jet_cad_2d_plan/src/service/service_state.dart'
    show UnitGroup, UnitStatus;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../support/unit_fixtures.dart';

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

/// The first table at screen (400, 300), 0.1 px per mm.
ValueNotifier<ViewportTransform> cameraOn(DraftDocument doc) {
  final first = doc.tree[unitsOf(doc).current.withLabel('1').single.instance]!
      as InstanceNode;
  final c = first.transform.transformPoint(Vector2(900, 650));
  return ValueNotifier(ViewportTransform(
      worldToScreenMatrix:
          Transform2(0.1, 0, 0, -0.1, 400 - 0.1 * c.x, 300 + 0.1 * c.y)));
}

/// The painter over [doc]; its paper is [paper], White when not given (dark
/// theme spec D6c: the tests before it paint on White).
UnitStatusPainter painterFor(
    DraftDocument doc,
    ValueNotifier<ViewportTransform> camera,
    ValueNotifier<Map<String, UnitStatus>> statuses,
    {ValueNotifier<int>? paper}) {
  final p = paper ?? ValueNotifier<int>(0xFFFFFFFF);
  return UnitStatusPainter(
      document: doc,
      units: unitsOf(doc),
      camera: camera,
      statuses: statuses,
      unitGroups: ValueNotifier(const <String, UnitGroup>{}),
      groupStatuses: ValueNotifier(const <String, UnitStatus>{}),
      paper: p,
      repaint: Listenable.merge([camera, statuses, p]));
}

void main() {
  test(
      'SP1 N = 60 statused tables: after warm-up every frame passes the same '
      'objects, the camera moving (M-14c2-8)', () {
    final doc = numberedRowOfTables(60);
    final camera = cameraOn(doc);
    final statuses = ValueNotifier<Map<String, UnitStatus>>({
      for (var i = 1; i <= 60; i++)
        '$i': UnitStatus(
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
    final doc = numberedRowOfTables(1);
    final camera = cameraOn(doc);
    final statuses = ValueNotifier<Map<String, UnitStatus>>(
        {'1': UnitStatus(color: const Color(0xFF2E7D32))});
    final painter = painterFor(doc, camera, statuses);
    final node = doc.tree[unitsOf(doc).current.withLabel('1').single.instance]!
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
    final doc = numberedRowOfTables(2);
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
        unitsOf(doc).current.withLabel('2').single.instance, hidden));
    final statuses = ValueNotifier<Map<String, UnitStatus>>({
      '1': UnitStatus(color: const Color(0xFFAA0000)),
      '2': UnitStatus(color: const Color(0xFF0000AA)),
    });
    final spy = SpyCanvas();
    painterFor(doc, cameraOn(doc), statuses)
        .paint(spy, const ui.Size(800, 600));
    expect(spy.paths, hasLength(1));
  });

  test(
      'SP4 a status follows the number: a renumber moves the fill; a number '
      'used twice fills both (M-14c2-7)', () {
    final doc = unitPlan();
    addUnitLabel(doc,
        placeAt(doc, trapezoidTable, Vector2(-3000, 0), mirrored: true), '1');
    addUnitLabel(doc, placeAt(doc, tableSymbol(), Vector2(3000, 0)), '2');
    final camera = ValueNotifier(ViewportTransform(
        worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, 400, 300)));
    final statuses = ValueNotifier<Map<String, UnitStatus>>(
        {'1': UnitStatus(color: const Color(0xFFAA0000))});
    final painter = painterFor(doc, camera, statuses);
    ui.Rect drawn() {
      final spy = SpyCanvas();
      painter.paint(spy, const ui.Size(800, 600));
      return spy.paths.single.getBounds();
    }

    expect(drawn(), const ui.Rect.fromLTRB(200, 300, 1600, 1000),
        reason: 'the trapezoid is 1');
    final units = unitsOf(doc);
    final s = units.current;
    doc.commands.execute(SetEntityTextCommand(
        s.withLabel('1').single.label!, '5', kUnitLabelTag));
    doc.commands.execute(SetEntityTextCommand(
        s.withLabel('2').single.label!, '1', kUnitLabelTag));
    expect(drawn(), const ui.Rect.fromLTRB(300, 300, 1500, 1100),
        reason: 'the rectangle is 1 now');
    doc.commands.execute(SetEntityTextCommand(
        units.current.withLabel('5').single.label!, '1', kUnitLabelTag));
    final spy = SpyCanvas();
    painter.paint(spy, const ui.Size(800, 600));
    expect(spy.paths, hasLength(2));
  });

  test('SP5 a caption is cut to 12 characters, not code units (R-12)', () {
    final s =
        UnitStatus(color: const Color(0xFF000000), caption: '👍🏽' * 13 + 'x');
    expect(s.caption, '👍🏽' * 12);
    expect(UnitStatus(color: const Color(0xFF000000), caption: 'Bill'),
        UnitStatus(color: const Color(0xFF000000), caption: 'Bill'));
  });

  test('SP6 fills are drawn in draw order, whatever the map\'s order', () {
    final doc = unitPlan();
    addUnitLabel(doc, placeAt(doc, trapezoidTable, Vector2(0, 0)), '1');
    addUnitLabel(doc, placeAt(doc, tableSymbol(), Vector2(0, 0)), '2');
    final statuses = ValueNotifier<Map<String, UnitStatus>>({
      '2': UnitStatus(color: const Color(0xFFAA0000)),
      '1': UnitStatus(color: const Color(0xFF0000AA)),
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
    final doc = numberedRowOfTables(2);
    final statuses = ValueNotifier<Map<String, UnitStatus>>(
        {'1': UnitStatus(color: const Color(0xFFAA0000))});
    final painter = painterFor(doc, cameraOn(doc), statuses);
    SpyCanvas frame() {
      final spy = SpyCanvas();
      painter.paint(spy, const ui.Size(800, 600));
      return spy;
    }

    expect(frame().paints.single.color.toARGB32(), 0xFFAA0000);
    statuses.value = {
      '1': UnitStatus(color: const Color(0xFF0000AA)),
      '2': UnitStatus(color: const Color(0xFF00AA00)),
    };
    expect([for (final p in frame().paints) p.color.toARGB32()],
        [0xFF0000AA, 0xFF00AA00]);
    statuses.value = const {};
    expect(frame().paths, isEmpty);
  });

  // A trapezoid whose base point, where the number sits, is off its top's
  // centre (900, 650).
  final offCentre = CatalogSymbol(
    key: 'fx.trapezoid.off',
    name: 'Off-centre trapezoid',
    category: 'Tests',
    tags: const ['table', 'test'],
    unit: tableUnit(2),
    base: (1200, 500),
    shapes: const [
      CatalogPolyline([(200, 300), (1600, 300), (1300, 1000), (500, 900)],
          closed: true),
    ],
  );

  test(
      'SP8 P7 the caption sits centred below the unit\'s box, clear of it '
      'at any zoom; a table smaller than its caption has none (S7, review '
      'F-4, F-5)', () {
    final doc = unitPlan();
    final at = Vector2(40000, -27000);
    addUnitLabel(doc, placeAt(doc, offCentre, at, mirrored: true), '1');
    final handle = doc.tree.nodes.whereType<InstanceNode>().single.handle;
    final turn = Transform2.translation(at.x, at.y)
        .multiply(Transform2.rotation(kDeg37))
        .multiply(Transform2.translation(-at.x, -at.y));
    doc.commands.execute(TransformNodeCommand(
        handle, turn.multiply((doc.tree[handle]! as InstanceNode).transform)));
    final node = doc.tree[handle]! as InstanceNode;
    // The base point lands on `at`; the camera puts it at (400, 300).
    final camera = ValueNotifier(ViewportTransform(
        worldToScreenMatrix:
            Transform2(0.1, 0, 0, -0.1, 400 - 4000, 300 - 2700)));
    final statuses = ValueNotifier<Map<String, UnitStatus>>({
      '1': UnitStatus(color: const Color(0xFFAA0000), caption: 'Bill'),
    });
    final painter = painterFor(doc, camera, statuses);
    final box = unitsOf(doc).current.withLabel('1').single.box;
    SpyCanvas frame() {
      final spy = SpyCanvas();
      painter.paint(spy, const ui.Size(800, 600));
      return spy;
    }

    // The box's greatest screen y, through the unit's world transform: the
    // caption is clear of the whole box (its chairs, if any), whatever the
    // zoom (P7).
    double boxBottom(Transform2 cam) {
      double screenY(double x, double y) {
        final w = node.transform.transformPoint(Vector2(x, y));
        return cam.b * w.x + cam.d * w.y + cam.f;
      }

      return [
        screenY(box.minX, box.minY),
        screenY(box.maxX, box.minY),
        screenY(box.minX, box.maxY),
        screenY(box.maxX, box.maxY),
      ].reduce(math.max);
    }

    // The label's height: min(200, 0.4 x 700) = 200, so 100 below the
    // anchor, plus a 2 px gap, or 11 px when that is less; but P7 puts the
    // caption at or below the box's own bottom, plus the gap, when that is
    // further down.
    for (final scale in const [0.1, 0.5, 0.07]) {
      camera.value = ViewportTransform(
          worldToScreenMatrix: Transform2(
              scale, 0, 0, -scale, 400 - scale * at.x, 300 + scale * at.y));
      final spy = frame();
      final p = spy.paragraphs.single;
      final t = spy.translations.single;
      final clamp =
          boxBottom(camera.value.worldToScreenMatrix) - 300 + kStatusCaptionGap;
      final below = math.max(
          math.max(kStatusCaptionSize, 100 * scale + kStatusCaptionGap), clamp);
      expect(t.dx, closeTo(400 - p.width / 2, 1e-6), reason: 'x at $scale');
      expect(t.dy, closeTo(300 + below, 1e-6), reason: 'y at $scale');
      expect(clamp, greaterThan(kStatusCaptionSize),
          reason: 'premise at $scale: the box, not the floor, decides');
    }
    camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(
            0.001, 0, 0, -0.001, 400 - 0.001 * at.x, 300 + 0.001 * at.y));
    final tiny = frame();
    expect(tiny.paths, hasLength(1), reason: 'the fill stays');
    expect(tiny.paragraphs, isEmpty, reason: 'the caption does not');
  });

  test(
      'SP13 P7: the caption clears the unit\'s own box, so it never lands on '
      'the chairs, at the identity and turned a quarter', () {
    // tableSymbol: a 1200 x 800 top with a 450 x 450 chair above and below,
    // its label at the top's centre, inside the box. Before the fix the
    // caption sat 12 px below the label, on the lower chair (the status
    // caption's 11 px floor, 14c). The box is the symbol's, chairs and all.
    for (final quarterTurns in const [0, 1]) {
      final doc = unitPlan();
      final at = Vector2(40000, -27000);
      final h = placeAt(doc, tableSymbol(), at, quarterTurns: quarterTurns);
      addUnitLabel(doc, h, '1');
      final node = doc.tree[h]! as InstanceNode;
      final box = unitsOf(doc).current.withLabel('1').single.box;
      expect(box.isEmpty, isFalse, reason: 'premise: the symbol has a box');

      // The base point, where the label sits, lands on (400, 300) at
      // 0.1 px/mm.
      final camera = ValueNotifier<ViewportTransform>(ViewportTransform(
          worldToScreenMatrix:
              Transform2(0.1, 0, 0, -0.1, 400 - 0.1 * at.x, 300 + 0.1 * at.y)));
      final statuses = ValueNotifier<Map<String, UnitStatus>>({
        '1': UnitStatus(color: const Color(0xFFAA0000), caption: 'Bill'),
      });
      final spy = SpyCanvas();
      painterFor(doc, camera, statuses).paint(spy, const ui.Size(800, 600));

      final cam = camera.value.worldToScreenMatrix;
      double screenY(double x, double y) {
        final w = node.transform.transformPoint(Vector2(x, y));
        return cam.b * w.x + cam.d * w.y + cam.f;
      }

      final bottom = [
        screenY(box.minX, box.minY),
        screenY(box.maxX, box.minY),
        screenY(box.minX, box.maxY),
        screenY(box.maxX, box.maxY),
      ].reduce(math.max);
      // Premise: the chairs reach below the number, so the test is not
      // degenerate.
      expect(bottom, greaterThan(300.5),
          reason: 'turns=$quarterTurns: the chairs sit below the number');

      final p = spy.paragraphs.single;
      final t = spy.translations.single;
      final caption = ui.Rect.fromLTWH(t.dx, t.dy, p.width, p.height);
      expect(caption.top, greaterThanOrEqualTo(bottom - 1e-6),
          reason: 'turns=$quarterTurns: the caption at ${caption.top} clears '
              'the box bottom $bottom');
    }
  });

  test('SP9 captions and paints no table holds are dropped (review F-8)', () {
    final doc = numberedRowOfTables(2);
    final statuses = ValueNotifier<Map<String, UnitStatus>>({});
    final painter = painterFor(doc, cameraOn(doc), statuses);
    for (var minute = 0; minute < 30; minute++) {
      statuses.value = {
        '1': UnitStatus(
            color: Color(0xFF000000 | minute), caption: '$minute min'),
        '2': UnitStatus(color: const Color(0xFF00AA00), caption: 'Bill'),
      };
      painter.paint(SpyCanvas(), const ui.Size(800, 600));
    }
    expect(painter.debugCached, 4, reason: 'two paints, two captions');
    statuses.value = const {};
    painter.paint(SpyCanvas(), const ui.Size(800, 600));
    expect(painter.debugCached, 0);
  });

  // Dark theme spec D6c: a caption's ink follows what it sits on, the
  // status colour composited over the paper.
  const white = 0xFFFFFFFF, blueprint = 0xFF1F3A5F;
  const ordered = Color(0x99FFB300), eating = Color(0x9943A047);
  const bill = Color(0x99E53935);

  test(
      'SP10 over composites a translucent status colour onto the paper\'s '
      'RGB: straight alpha, rounded per channel, the paper\'s alpha unread '
      '(D6c)', () {
    // 0x99 / 255 = 0.6: blue is 0.6 x 0x35 + 0.4 x 0xFF = 133.8, rounded to
    // 134 (0x86), not cut to 133.
    expect(over(bill, white), 0xEF8886);
    expect(over(bill, blueprint), 0x963946);
    expect(over(ordered, blueprint), 0xA58326);
    expect(over(eating, white), 0x8EC691);
    expect(over(const Color(0xFF123456), blueprint), 0x123456,
        reason: 'opaque: the colour');
    expect(over(const Color(0x00123456), blueprint), 0x1F3A5F,
        reason: 'transparent: the paper');
    expect(over(bill, 0x001F3A5F), 0x963946, reason: 'the paper is opaque');
  });

  test(
      'SP11 the caption colour: the demo\'s statuses on White keep today\'s '
      '0xFF202020; on Blueprint the paper decides, where the status colour '
      'alone would not (D6c, R-5)', () {
    expect(kStatusCaptionOnLight, const Color(0xFF202020));
    expect(kStatusCaptionOnDark, const Color(0xFFFFFFFF));
    for (final c in const [ordered, eating, bill]) {
      expect(statusCaptionInk(c, white), kStatusCaptionOnLight,
          reason: '$c on White');
    }
    expect(statusCaptionInk(bill, blueprint), kStatusCaptionOnDark);
    expect(statusCaptionInk(eating, blueprint), kStatusCaptionOnDark);
    // Amber over navy is still light: black ink.
    expect(statusCaptionInk(ordered, blueprint), kStatusCaptionOnLight);
    // Bill's RGB alone takes black ink: the white on Blueprint is the
    // paper's doing.
    expect(foregroundFor(0xE53935), 0x000000);
    // An opaque dark status takes white ink on White too.
    expect(
        statusCaptionInk(const Color(0xFF1B3A1B), white), kStatusCaptionOnDark);
  });

  testWidgets(
      'SP12 M-DT-13: on one painter, Bill on White has dark glyphs; the paper '
      'flips to Blueprint: light glyphs and exactly one new paragraph; ten '
      'steady frames build nothing (D6c, R-11)', (tester) async {
    final doc = unitPlan();
    final at = Vector2(40000, -27000);
    addUnitLabel(doc, placeAt(doc, offCentre, at, mirrored: true), '1');
    final node = doc.tree.nodes.whereType<InstanceNode>().single;
    final turn = Transform2.translation(at.x, at.y)
        .multiply(Transform2.rotation(kDeg37))
        .multiply(Transform2.translation(-at.x, -at.y));
    doc.commands.execute(
        TransformNodeCommand(node.handle, turn.multiply(node.transform)));
    // The base point at (400, 300), 0.2 px per mm.
    final camera = ValueNotifier(ViewportTransform(
        worldToScreenMatrix:
            Transform2(0.2, 0, 0, -0.2, 400 - 0.2 * at.x, 300 + 0.2 * at.y)));
    final paper = ValueNotifier<int>(white);
    final statuses = ValueNotifier<Map<String, UnitStatus>>(
        {'1': UnitStatus(color: bill, caption: 'Bill')});
    final painter = painterFor(doc, camera, statuses, paper: paper);
    const w = 800, h = 600;
    const size = ui.Size(800, 600);
    SpyCanvas frame() {
      final spy = SpyCanvas();
      painter.paint(spy, size);
      return spy;
    }

    // The caption's box: its translation and its paragraph's size.
    final first = frame();
    final p = first.paragraphs.single;
    final t = first.translations.single;
    final box = ui.Rect.fromLTWH(t.dx, t.dy, p.width, p.height);

    // The paper, then the painter, read back; the box's darkest and
    // brightest pixels.
    Future<(int, int)> glyphs() async {
      final bytes = (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)
          ..drawColor(Color(paper.value), ui.BlendMode.src);
        painter.paint(canvas, size);
        final image = await recorder.endRecording().toImage(w, h);
        final data = await image.toByteData();
        image.dispose();
        return data!;
      }))!;
      var darkest = 0xFFFFFF, brightest = 0, dMax = 256, bMin = -1;
      for (var y = box.top.floor(); y < box.bottom.ceil(); y++) {
        for (var x = box.left.floor(); x < box.right.ceil(); x++) {
          final i = (y * w + x) * 4;
          final r = bytes.getUint8(i),
              g = bytes.getUint8(i + 1),
              b = bytes.getUint8(i + 2);
          final hi = [r, g, b].reduce((a, b) => a > b ? a : b);
          final lo = [r, g, b].reduce((a, b) => a < b ? a : b);
          final rgb = (r << 16) | (g << 8) | b;
          if (hi < dMax) (dMax, darkest) = (hi, rgb);
          if (lo > bMin) (bMin, brightest) = (lo, rgb);
        }
      }
      return (darkest, brightest);
    }

    String hex(int v) => '0x${v.toRadixString(16).padLeft(6, '0')}';
    final (onWhite, _) = await glyphs();
    expect(hex(onWhite), hex(0x202020), reason: 'Bill on White: dark glyphs');
    final made = painter.debugAllocations;

    paper.value = blueprint;
    final (_, onBlueprint) = await glyphs();
    expect(hex(onBlueprint), hex(0xFFFFFF),
        reason: 'Bill on Blueprint: light glyphs');
    expect(painter.debugAllocations, made + 1,
        reason: 'the flip builds one paragraph');
    final flipped = frame().paragraphs.single;
    expect(identical(flipped, p), isFalse);
    for (var i = 0; i < 10; i++) {
      expect(identical(frame().paragraphs.single, flipped), isTrue,
          reason: 'steady frame $i');
    }
    expect(painter.debugAllocations, made + 1,
        reason: 'ten steady frames build nothing');
    expect(painter.debugCached, 2, reason: 'one paint, one caption');
  });
}
