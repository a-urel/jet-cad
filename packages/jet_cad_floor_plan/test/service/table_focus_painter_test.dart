// Zone spec Z12, Z13, Z16, Z17: the focus's veil (`TableFocusPainter`).
// Pixels are read back through a `PictureRecorder` under `runAsync` (14c
// R-10) and compared with what the test computes from the symbols' own
// boxes by the forward transform; the allocation bar is 14c R-3's
// structural recording canvas.
//
// The fixture is `zone_fixture.dart`'s (turned, mirrored, 40 m and more off
// the origin; a hidden, a locked and an unnumbered table), plus, where
// overlaps are needed, a cluster of three overlapping tables: F (the
// trapezoid, turned), G (the trapezoid, turned and mirrored, over F's
// corner) and H (the rectangle, turned, over G). The camera is panned at
// 0.37 px/mm before every frame.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart'
    show registerAppComponents;
import 'package:jet_cad_floor_plan/src/service/table_focus_painter.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../host/zone_fixture.dart';
import '../tables/table_fixture.dart';
import 'table_status_painter_test.dart' show SpyCanvas, rowOfTables;

/// The image, in pixels.
const int kW = 1400, kH = 800;

/// What the veil lies on in these images, `0xRRGGBB`.
const int kUnder = 0x2A4B7C;

/// A paper that is neither White nor grey, ARGB.
const int kPaper = 0xFFF4EEE0;

/// The zone fixture, decoded with every permission.
DraftDocument zoneDoc() => DraftDocumentCodec.decodeString(zonePlanJson(),
    registerComponents: registerAppComponents);

/// F, G and H (header), 41 m and more off the origin.
void addCluster(DraftDocument doc) {
  placeZoneTable(doc, trapezoidTable, 41000, -45000, 'F');
  placeZoneTable(doc, trapezoidTable, 41500, -45300, 'G', mirrored: true);
  placeZoneTable(doc, tableSymbol(), 42000, -46000, 'H');
}

/// World ([x], [y]) at the image's centre, 0.37 px/mm, off the pixel grid.
ViewportTransform cameraAt(double x, double y) => ViewportTransform(
    worldToScreenMatrix: Transform2(
        0.37, 0, 0, -0.37, kW / 2 - 0.37 * x + 0.31, kH / 2 + 0.37 * y + 0.17));

TableFocusPainter painterOn(
        DraftDocument doc,
        ValueNotifier<ViewportTransform> camera,
        ValueNotifier<Set<String>?> focus,
        ValueNotifier<int> paper) =>
    TableFocusPainter(
        document: doc,
        camera: camera,
        focus: focus,
        paper: paper,
        repaint: Listenable.merge([camera, focus, paper]));

/// The painter over [kUnder], read back.
Future<ByteData> render(WidgetTester tester, TableFocusPainter p) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const Color(0xFF000000 | kUnder), ui.BlendMode.src);
      p.paint(canvas, const ui.Size(kW + 0.0, kH + 0.0));
      final image = await recorder.endRecording().toImage(kW, kH);
      final data = await image.toByteData();
      image.dispose();
      return data!;
    }))!;

int rgbAt(ByteData b, int x, int y) {
  final i = (y * kW + x) * 4;
  return (b.getUint8(i) << 16) | (b.getUint8(i + 1) << 8) | b.getUint8(i + 2);
}

/// Renders and checks the whole image: [faded] veiled with [paper]'s RGB,
/// [focused] and everything else clear.
Future<VeilCheck> shot(WidgetTester tester, TableFocusPainter painter,
    ViewportTransform camera, List<TestQuad> faded, List<TestQuad> focused,
    {int paper = kPaper,
    Map<String, bool Function(double x, double y)> regions = const {}}) async {
  final bytes = await render(tester, painter);
  final check = checkVeil(
      camera: camera,
      width: kW,
      height: kH,
      under: (_, __) => kUnder,
      got: (x, y) => rgbAt(bytes, x, y),
      faded: faded,
      focused: focused,
      paper: paper & 0xFFFFFF,
      regions: regions);
  expect(check.wrong, isEmpty,
      reason: '${check.mismatched} pixels wrong: ${check.wrong.join('; ')}');
  return check;
}

/// The camera on the table [q] (0.37 px/mm, panned).
ViewportTransform cameraOn(TestQuad q) {
  final c = q.centre;
  return cameraAt(c.x, c.y);
}

/// The painter's frame on a recording canvas.
SpyCanvas spyFrame(TableFocusPainter painter) {
  final spy = SpyCanvas();
  painter.paint(spy, const ui.Size(kW + 0.0, kH + 0.0));
  return spy;
}

/// Every table of [doc] but those numbered in [except] and the hidden 5:
/// what the test expects to fade.
List<TestQuad> fadedBut(DraftDocument doc, Set<String> except) =>
    quadsOf(doc, (t) => t.number != '5' && !except.contains(t.number));

void main() {
  testWidgets(
      'FP1 the veil is each faded table\'s quad, focused quads cut out: the '
      'turned focused table is whole where a faded one overlaps it, a faded '
      'pixel in its axis-aligned bound is veiled; the mirrored quad is '
      'veiled, not cancelled; no corner triangle of the bound, no box at '
      'its translation only (M-Z17, M-Z18)', (tester) async {
    final doc = zoneDoc();
    addCluster(doc);
    final f = quadsNumbered(doc, 'F').single;
    final g = quadsNumbered(doc, 'G').single;
    final h = quadsNumbered(doc, 'H').single;
    expect(f.transform.determinant, greaterThan(0), reason: 'premise');
    expect(g.transform.determinant, lessThan(0), reason: 'premise: mirrored');
    expect(h.transform.determinant, greaterThan(0), reason: 'premise');
    expect(g.transform.b, isNot(0), reason: 'premise: turned');
    // F's and G's world bounds, by the forward transform.
    final fBound = boundOf(doc, {'F'}), gBound = boundOf(doc, {'G'});
    final gt = g.transform;
    final camera = ValueNotifier(cameraAt(42100, -45300));
    final focus = ValueNotifier<Set<String>?>({'F'});
    final paper = ValueNotifier<int>(kPaper);
    final painter = painterOn(doc, camera, focus, paper);
    bool outsideAll(double x, double y) =>
        !f.holds(x, y, 0) && !g.holds(x, y, 0) && !h.holds(x, y, 0);
    final check =
        await shot(tester, painter, camera.value, fadedBut(doc, {'F'}), [
      f
    ], regions: {
      'F over G': (x, y) => f.holds(x, y, 0) && g.holds(x, y, 0),
      'G outside F, in F\'s bound': (x, y) =>
          g.holds(x, y, 0) &&
          !f.holds(x, y, 0) &&
          fBound.containsPoint(Vector2(x, y)),
      'G over H, outside F': (x, y) =>
          g.holds(x, y, 0) && h.holds(x, y, 0) && !f.holds(x, y, 0),
      'G\'s bound, outside every quad': (x, y) =>
          gBound.containsPoint(Vector2(x, y)) && outsideAll(x, y),
      'G\'s box at its translation only, outside every quad': (x, y) =>
          x - gt.e >= 200 &&
          x - gt.e <= 1600 &&
          y - gt.f >= 300 &&
          y - gt.f <= 1000 &&
          outsideAll(x, y),
    });
    for (final name in check.regions) {
      expect(check.counts[name] ?? 0, greaterThan(200), reason: name);
    }
  });

  testWidgets(
      'FP2 the unnumbered and the locked table are veiled, the hidden '
      'table\'s box is not; an empty focus veils every table (M-Z19, '
      'M-Z39)', (tester) async {
    final doc = zoneDoc();
    final unnumbered = quadsOf(doc, (t) => t.number == null).single;
    final locked = quadsNumbered(doc, 'L').single;
    final hidden = quadsNumbered(doc, '5').single;
    final three = quadsNumbered(doc, '3').single;
    final layers = doc.tables.layers;
    final lNode = doc.tree[TableSurvey.of(doc).withNumber('L').single.instance]!
        as InstanceNode;
    final fiveNode =
        doc.tree[TableSurvey.of(doc).withNumber('5').single.instance]!
            as InstanceNode;
    expect(layers[lNode.layer]!.locked, isTrue, reason: 'premise: locked');
    expect(layers[fiveNode.layer]!.visible, isFalse, reason: 'premise');
    final camera = ValueNotifier(cameraOn(three));
    final focus = ValueNotifier<Set<String>?>({'3'});
    final paper = ValueNotifier<int>(kPaper);
    final painter = painterOn(doc, camera, focus, paper);
    final faded = fadedBut(doc, {'3'});
    for (final (name, q) in [
      ('unnumbered, veiled', unnumbered),
      ('locked, veiled', locked),
      ('hidden, clear', hidden),
      ('focused, clear', three),
    ]) {
      camera.value = cameraOn(q);
      final check = await shot(tester, painter, camera.value, faded, [three],
          regions: {name: (x, y) => q.holds(x, y, 0)});
      expect(check.counts[name] ?? 0, greaterThan(20000), reason: name);
    }

    for (final empty in [
      <String>{},
      {''}
    ]) {
      focus.value = empty;
      camera.value = cameraOn(three);
      final check = await shot(
          tester, painter, camera.value, fadedBut(doc, {}), [],
          regions: {'3': (x, y) => three.holds(x, y, 0)});
      expect(check.counts['3'] ?? 0, greaterThan(20000), reason: '$empty');
    }
  });

  test(
      'FP3 N = 60 tables, half focused: after warm-up every frame passes the '
      'same matrix, path and paint, one draw, the camera panning and '
      'zooming; nothing is built (M-Z21)', () {
    final doc = rowOfTables(60);
    final first = quadsOf(doc, (t) => t.number == '1').single;
    final camera = ValueNotifier(cameraOn(first));
    final focus =
        ValueNotifier<Set<String>?>({for (var i = 1; i <= 30; i++) '$i'});
    final painter = painterOn(doc, camera, focus, ValueNotifier<int>(kPaper));
    for (var i = 0; i < 3; i++) {
      spyFrame(painter);
    }
    final made = painter.debugAllocations;
    final rebuilt = painter.debugRebuilds;
    final reference = spyFrame(painter).seen;
    expect(reference, hasLength(3), reason: 'one matrix, one path, one paint');
    expect(reference[0], isA<Float64List>());
    expect(reference[1], isA<ui.Path>());
    expect(reference[2], isA<ui.Paint>());
    for (final t in [
      Transform2(0.37, 0, 0, -0.37, -14700.5, -9800.25), // a pan
      Transform2(0.05, 0, 0, -0.05, -1900.75, -1300.5), // a zoom
    ]) {
      camera.value = ViewportTransform(worldToScreenMatrix: t);
      final seen = spyFrame(painter).seen;
      expect(seen, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(identical(seen[i], reference[i]), isTrue, reason: 'item $i');
      }
      final m = seen[0] as Float64List;
      expect([m[0], m[5], m[12], m[13]], [t.a, t.d, t.e, t.f],
          reason: 'the buffer holds this frame\'s camera');
    }
    expect(painter.debugAllocations, made, reason: 'nothing new per frame');
    expect(painter.debugRebuilds, rebuilt);
  });

  test(
      'FP4 with no focus nothing is built or drawn; with every table '
      'focused nothing is drawn (Z16, I-4)', () {
    final doc = rowOfTables(4);
    final camera =
        ValueNotifier(cameraOn(quadsOf(doc, (t) => t.number == '1').single));
    final focus = ValueNotifier<Set<String>?>(null);
    final painter = painterOn(doc, camera, focus, ValueNotifier<int>(kPaper));
    for (var i = 0; i < 3; i++) {
      expect(spyFrame(painter).seen, isEmpty, reason: 'no focus');
    }
    expect(painter.debugAllocations, 2, reason: 'the paint and the matrix');
    focus.value = {'1', '2', '3', '4'};
    expect(spyFrame(painter).seen, isEmpty, reason: 'every table focused');
    focus.value = {'1', '2', '3'};
    expect(spyFrame(painter).seen, hasLength(3), reason: 'one faded');
    focus.value = null;
    expect(spyFrame(painter).seen, isEmpty, reason: 'no focus again');
  });

  testWidgets(
      'FP5 the veil is the paper\'s RGB at 0.6, its alpha ignored; a paper '
      'change recolours the paint and rebuilds nothing (M-Z25)',
      (tester) async {
    final doc = zoneDoc();
    final seven = quadsNumbered(doc, '7').single;
    final three = quadsNumbered(doc, '3').single;
    final camera = ValueNotifier(cameraOn(seven));
    final focus = ValueNotifier<Set<String>?>({'3'});
    final paper = ValueNotifier<int>(kPaper);
    final painter = painterOn(doc, camera, focus, paper);
    final faded = fadedBut(doc, {'3'});
    Future<void> veiledWith(int rgb, String reason) async {
      final check = await shot(tester, painter, camera.value, faded, [three],
          paper: rgb, regions: {reason: (x, y) => seven.holds(x, y, 0)});
      expect(check.counts[reason] ?? 0, greaterThan(20000), reason: reason);
    }

    await veiledWith(kPaper, 'the paper');
    final made = painter.debugAllocations;
    final rebuilt = painter.debugRebuilds;
    final path = spyFrame(painter).paths.single;
    paper.value = kDarkCanvasPaper;
    await veiledWith(kDarkCanvasPaper, 'the dark canvas\'s paper');
    paper.value = 0x00FFD080;
    await veiledWith(0xFFD080, 'a paper of alpha 0: its RGB at 0.6');
    paper.value = 0x80304050;
    await veiledWith(0x304050, 'a paper of alpha 0x80: its RGB at 0.6');
    expect(painter.debugAllocations, made, reason: 'no path rebuilt');
    expect(painter.debugRebuilds, rebuilt);
    expect(identical(spyFrame(painter).paths.single, path), isTrue);
  });

  testWidgets(
      'FP6 the veil follows the plan: a faded table moved, the move undone, '
      'a layer hidden with no command (M-Z37)', (tester) async {
    final doc = zoneDoc();
    final three = quadsNumbered(doc, '3').single;
    final before = quadsNumbered(doc, '7').single;
    final camera = ValueNotifier(cameraOn(before));
    final focus = ValueNotifier<Set<String>?>({'3'});
    final painter = painterOn(doc, camera, focus, ValueNotifier<int>(kPaper));
    await shot(tester, painter, camera.value, fadedBut(doc, {'3'}), [three]);

    final instance = TableSurvey.of(doc).withNumber('7').single.instance;
    final node = doc.tree[instance]! as InstanceNode;
    doc.commands.execute(TransformNodeCommand(instance,
        Transform2.translation(610.5, -455.25).multiply(node.transform)));
    final after = quadsNumbered(doc, '7').single;
    final moved =
        await shot(tester, painter, camera.value, fadedBut(doc, {'3'}), [
      three
    ], regions: {
      'left': (x, y) => before.holds(x, y, 0) && !after.holds(x, y, 0),
      'reached': (x, y) => after.holds(x, y, 0) && !before.holds(x, y, 0),
    });
    expect(moved.counts['left'] ?? 0, greaterThan(5000), reason: 'clear');
    expect(moved.counts['reached'] ?? 0, greaterThan(5000), reason: 'veiled');

    doc.commands.undo();
    final undone =
        await shot(tester, painter, camera.value, fadedBut(doc, {'3'}), [
      three
    ], regions: {
      'back': (x, y) => before.holds(x, y, 0) && !after.holds(x, y, 0),
      'left': (x, y) => after.holds(x, y, 0) && !before.holds(x, y, 0),
    });
    expect(undone.counts['back'] ?? 0, greaterThan(5000), reason: 'veiled');
    expect(undone.counts['left'] ?? 0, greaterThan(5000), reason: 'clear');

    final locked = quadsNumbered(doc, 'L').single;
    camera.value = cameraOn(locked);
    await shot(tester, painter, camera.value, fadedBut(doc, {'3'}), [three]);
    final state = doc.commands.stateId;
    final revision = doc.tables.mutationRevision;
    final layer = doc.tables.layers.byName('L')!;
    doc.tables.layers
      ..remove(layer.handle)
      ..add(layer.copyWith(visible: false));
    expect(doc.commands.stateId, state, reason: 'premise: no command');
    expect(doc.tables.mutationRevision, isNot(revision), reason: 'premise');
    final hidden = await shot(
        tester, painter, camera.value, fadedBut(doc, {'3', 'L'}), [three],
        regions: {'L': (x, y) => locked.holds(x, y, 0)});
    expect(hidden.counts['L'] ?? 0, greaterThan(20000), reason: 'clear');
  });

  testWidgets(
      'FP7 the Task 2 review\'s R-4: with F and the mirrored G both focused, '
      'a faded table J laid over their overlap is clear there: the focused '
      'quads add up, never cancel (O13)', (tester) async {
    final doc = zoneDoc();
    addCluster(doc);
    final f = quadsNumbered(doc, 'F').single;
    final g = quadsNumbered(doc, 'G').single;
    expect(f.transform.determinant, greaterThan(0), reason: 'premise');
    expect(g.transform.determinant, lessThan(0), reason: 'premise: mirrored');
    // J, centred (its base point is its box's centre) on the centroid of a
    // 10 mm sampling of F and G's overlap.
    var sx = 0.0, sy = 0.0, n = 0;
    for (var x = 40000.0; x <= 44000; x += 10) {
      for (var y = -47000.0; y <= -43000; y += 10) {
        if (f.holds(x, y, 0) && g.holds(x, y, 0)) {
          sx += x;
          sy += y;
          n++;
        }
      }
    }
    expect(n, greaterThan(1000), reason: 'premise: F and G overlap');
    placeZoneTable(doc, tableSymbol(), sx / n, sy / n, 'J');
    final j = quadsNumbered(doc, 'J').single;
    final camera = ValueNotifier(cameraAt(sx / n, sy / n));
    final focus = ValueNotifier<Set<String>?>({'F', 'G'});
    final painter = painterOn(doc, camera, focus, ValueNotifier<int>(kPaper));
    final check =
        await shot(tester, painter, camera.value, fadedBut(doc, {'F', 'G'}), [
      f,
      g
    ], regions: {
      'F, G and J': (x, y) =>
          f.holds(x, y, 0) && g.holds(x, y, 0) && j.holds(x, y, 0),
      'J outside F and G': (x, y) =>
          j.holds(x, y, 0) && !f.holds(x, y, 0) && !g.holds(x, y, 0),
    });
    for (final name in check.regions) {
      expect(check.counts[name] ?? 0, greaterThan(200), reason: name);
    }
  });

  test(
      'FX1 a veil drawn, then every table focused: nothing is drawn (the '
      'region of the last build is dropped, not kept)', () {
    final doc = rowOfTables(4);
    final camera =
        ValueNotifier(cameraOn(quadsOf(doc, (t) => t.number == '1').single));
    final focus = ValueNotifier<Set<String>?>({'1', '2', '3'});
    final painter = painterOn(doc, camera, focus, ValueNotifier<int>(kPaper));
    expect(spyFrame(painter).seen, hasLength(3), reason: 'premise: one faded');
    focus.value = {'1', '2', '3', '4'};
    expect(spyFrame(painter).seen, isEmpty, reason: 'every table focused');
  });
}
