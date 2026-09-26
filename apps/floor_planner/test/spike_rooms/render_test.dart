// SPIKE 10 -- throwaway. Q6: the sample plan with rooms, rendered by the
// real floor planner shell inside flutter_test (RenderRepaintBoundary
// .toImage, the software rasteriser), and picks through the engine's
// SpatialIndex and the render layer's resolveHit. The camera maps world y
// down the screen, so the images are mirrored top to bottom.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

const x0 = 12000.0, y0 = 8000.0;

/// Decision 16's sample plan: the startup flat, a column in Living, the
/// Living | Dining separator, and seven rooms. [rooms] false leaves the
/// rooms out (the separator and column stay), for the before/after pixels.
(DraftDocument, Map<String, Handle>) samplePlanWithRooms(
    {bool rooms = true, int? background}) {
  final doc = startupPlan(FlutterTextMeasurer());
  if (background != null) {
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page.copyWith(background: background)));
  }
  final sys = installParametric(doc);
  ensureSeparatorLinetype(doc);
  final (cx0, cy, cx1, _, ct) = sampleColumn;
  final col = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: col,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])),
    SetComponentCommand<WallParams>(
        col, WallParams(cx0, cy, cx1, cy, ct, Justification.centre)),
  ], label: 'Add wall'));
  final (sx, sy, ex, ey) = sampleSeparator;
  addSeparator(doc, Vector2(sx, sy), Vector2(ex, ey));
  final handles = <String, Handle>{};
  if (rooms) {
    for (final (name, (x, y)) in [
      ('Hall', sampleSeeds['Hall']!),
      ('Bedroom 1', sampleSeeds['Bedroom 1']!),
      ('Bedroom 2', sampleSeeds['Bedroom 2']!),
      ('Kitchen', sampleSeeds['Kitchen']!),
      ('Bath', sampleSeeds['Bath']!),
      ('Dining', (19000.0, 14000.0)),
      ('Living', (23000.0, 15500.0)),
    ]) {
      handles[name] = clickRoom(doc, Vector2(x, y), name)!;
    }
  }
  expect(ParametricSystem(doc, parametricCatalog).drift(), isEmpty);
  sys.dispose();
  doc.commands.clearHistory();
  return (doc, handles);
}

/// Renders [doc] through the shell, centred on world [centre] at
/// [pxPerMm]; writes `build/spike_rooms/<name>.png` and returns a sampler
/// of the RGBA at a world point.
Future<Color Function(Vector2)> snap(WidgetTester tester, String name,
    DraftDocument doc, Vector2 centre, double pxPerMm) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final capture = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
      key: capture, child: MaterialApp(home: PlannerShell(document: doc))));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final layer = find.byType(InteractionLayer);
  final size = tester.getSize(layer);
  final topLeft = tester.getTopLeft(layer);
  final linear = Transform2.scale(pxPerMm, pxPerMm);
  final mid = linear.transformPoint(centre);
  final camera = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  view.camera.value = camera;
  await tester.pump();
  final boundary =
      capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final (png, raw, width, height) = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width, h = image.height;
    image.dispose();
    return (png!, raw!, w, h);
  }))!;
  Directory('build/spike_rooms').createSync(recursive: true);
  File('build/spike_rooms/$name.png')
      .writeAsBytesSync(png.buffer.asUint8List());
  await tester.pumpWidget(const SizedBox());
  final bytes = Uint8List.sublistView(raw);
  // The camera's world-to-screen map, applied by hand.
  final m = camera.worldToScreenMatrix;
  return (Vector2 w) {
    final s = m.transformPoint(w);
    final px = (topLeft.dx + s.x).round(), py = (topLeft.dy + s.y).round();
    if (px < 0 || py < 0 || px >= width || py >= height) {
      throw RangeError('$w is off the ${width}x$height image');
    }
    final i = (py * width + px) * 4;
    return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  };
}

String rgb(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

void main() {
  testWidgets(
      'R1 the sample plan with seven rooms, a separator and a '
      'column, white paper; the tint over the furniture', (tester) async {
    final (doc, _) = samplePlanWithRooms();
    final (bare, _) = samplePlanWithRooms(rooms: false);
    final centre = Vector2(x0 + 7000, y0 + 4500);
    await snap(tester, 'r1_sample_rooms', doc, centre, 0.058);
    await snap(tester, 'r1_sample_no_rooms', bare, centre, 0.058);
    // The sofa (x0+6000..9000, y0+4500..5400, drawn before the rooms) and
    // the kitchen counter, zoomed, with and without the Dining and Kitchen
    // tints over them.
    final z = Vector2(x0 + 7600, y0 + 4200);
    final withRooms =
        await snap(tester, 'r2_dining_kitchen_zoom', doc, z, 0.35);
    final without =
        await snap(tester, 'r2_dining_kitchen_zoom_no_rooms', bare, z, 0.35);
    final probes = {
      'sofa fill': Vector2(x0 + 7500, y0 + 4800),
      'counter fill': Vector2(x0 + 8800, y0 + 3000),
      'dining floor, off the parquet joints': Vector2(x0 + 6700, y0 + 4430),
    };
    for (final e in probes.entries) {
      final a = withRooms(e.value), b = without(e.value);
      // ignore: avoid_print
      print('R2 ${e.key}: without rooms ${rgb(b)}, with rooms ${rgb(a)}');
    }
    // The sofa still shows, tinted: its own fill differs from the floor's.
    expect(withRooms(probes['sofa fill']!),
        isNot(withRooms(probes['dining floor, off the parquet joints']!)));
    await snap(tester, 'r3_living_column_separator', doc,
        Vector2(x0 + 9800, y0 + 6300), 0.2);
  });

  testWidgets('R4 Blueprint paper', (tester) async {
    final (doc, _) = samplePlanWithRooms(background: 0xFF1F3A5F);
    await snap(tester, 'r4_blueprint_rooms', doc, Vector2(x0 + 7000, y0 + 4500),
        0.058);
  });

  test('Q6 picks: furniture under a tint, the tint itself, the label', () {
    final (doc, rooms) = samplePlanWithRooms();
    final (bare, _) = samplePlanWithRooms(rooms: false);
    String pick(DraftDocument d, Vector2 p) {
      final index = SpatialIndex(d);
      final hit = HitPath();
      final found = index.pickInto(p, 20, const QueryFilter.picking(), hit);
      final out = !found
          ? 'miss'
          : '${hit.entity.value} (${hit.kind.name}) -> '
              '${resolveHit(hit, d)?.target.value}';
      index.dispose();
      return out;
    }

    final dining = rooms['Dining']!;
    final labels = [
      for (final k in kids(doc, dining))
        if (kindOf(doc, k) == EntityKind.text) k
    ];
    final labelAt = Vector2(payloadOf(doc, labels.first).coords[0],
        payloadOf(doc, labels.first).coords[1]);
    final points = {
      'sofa middle': Vector2(x0 + 7500, y0 + 4950),
      'counter middle': Vector2(x0 + 8800, y0 + 2000),
      'lamp middle': Vector2(x0 + 7600, y0 + 6200),
      'dining floor, 75 mm off a parquet joint':
          Vector2(x0 + 5500, y0 + 3500 + 120 + 75 + 150 * 6),
      'Dining name label': labelAt,
      'a room\'s inner face, 5 mm into the room':
          Vector2(x0 + 5000 + 60 + 5, y0 + 7000),
    };
    final results = <String, (String, String)>{};
    for (final e in points.entries) {
      results[e.key] = (pick(bare, e.value), pick(doc, e.value));
      // ignore: avoid_print
      print('Q6 ${e.key}: without rooms ${results[e.key]!.$1}; with rooms '
          '${results[e.key]!.$2}');
    }
    // The Dining label lands on the table and lamp (the pole ignores
    // furniture): a click on the lamp there picks the label's box, so the
    // room.
    expect(results['lamp middle']!.$2, endsWith('-> ${dining.value}'));
    for (final k in [
      'sofa middle',
      'counter middle',
      'dining floor, 75 mm off a parquet joint',
      'a room\'s inner face, 5 mm into the room',
    ]) {
      expect(results[k]!.$2, results[k]!.$1, reason: k);
    }
    expect(results['Dining name label']!.$2, endsWith('-> ${dining.value}'));
  });
}
