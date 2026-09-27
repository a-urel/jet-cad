// Spec 10 D9, D3 and D24 in the shell, on the sample plan (D23): the
// room's tint is the page's foreground at about 10%, never picked,
// band-selected or stroked (RR1, RR2, RR3; Ruling 10-23); the separator
// paints dashes (RR4) and, without the DASHED record, draws continuous
// (SR3); a selected room outlines its labels and its ring (OL4).
//
// 07's WP5 method: the real shell in `flutter_test`, read back with
// `RenderRepaintBoundary.toImage`. The camera is y-up and unrotated, so a
// band dragged left to right is a window, at 0.15 px per mm and a
// fractional translation (Ruling 10-28: `flutter_test`'s rasteriser skips a
// one-pixel stroke centred on an integer device coordinate). A sample on a
// stroke reads the darkest pixel of its 3 × 3 block, one off a stroke the
// darkest too, so a stroke that should not be there cannot hide beside the
// sampled pixel. Every sample of bare floor lies at least 60 mm (9 px) from
// every floor-finish line, found from the document itself.
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// The page panel's Blueprint paper.
const int blueprint = 0xFF1F3A5F;

/// The tint's alpha: transparency 229 is alpha 26 of 255 (spec 10 D9).
const double tintAlpha = 26 / 255;

/// The camera: 0.15 px per mm, centred here, y up.
const double pxPerMm = 0.15;
final Vector2 centre = Vector2(21000, 12800);

SelectionKey k(Handle h) => SelectionKey.root(h);

/// The startup plan, as the app opens it, on [background] paper when
/// given; with [rooms] false, its seven rooms deleted (the column and the
/// separator stay), the plan every probe is compared against. With [grid]
/// false the page grid is hidden, as the Page panel's switch hides it: the
/// grid is chrome painted under the drawing at a spacing the camera picks,
/// so a pixel test hides it to read bare floor as paper. No room
/// regenerates for it (spec 10 D14's key).
DraftDocument sample({bool rooms = true, int? background, bool grid = true}) {
  final doc = startupPlan(FlutterTextMeasurer());
  final system = installParametric(doc);
  if (!rooms) {
    for (final h in doc.components.withComponent<RoomParams>().toList()) {
      doc.commands.execute(deleteObject(doc, h));
    }
    expect(doc.components.withComponent<RoomParams>(), isEmpty);
  }
  if (background != null || !grid) {
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        pageOf(doc).copyWith(
            background: background ?? pageOf(doc).background,
            gridVisible: grid)));
  }
  expect(driftOf(doc), isEmpty);
  system.dispose();
  doc.commands.clearHistory();
  return doc;
}

/// The room named [name] in [doc].
Handle roomNamed(DraftDocument doc, String name) => [
      for (final r in doc.components.withComponent<RoomParams>())
        if (doc.components.get<RoomParams>(r)!.name == name) r,
    ].single;

/// The floor-finish lines (`startup_plan.dart`'s hairlines), world.
List<(Vector2, Vector2)> finishLines(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.line &&
            doc.entities.read(slot).color == const TrueColor(0xBBBBBB))
          (
            doc.geometry.read(doc.entities.geomIndexAt(slot)).pointAt(0),
            doc.geometry.read(doc.entities.geomIndexAt(slot)).pointAt(1),
          ),
    ];

double distToSegment(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a;
  final t = ((p - a).dot(d) / d.length2).clamp(0.0, 1.0);
  return (a + d * t - p).length;
}

/// The distance from [p] to the nearest floor-finish line of [doc].
double clearance(DraftDocument doc, Vector2 p) =>
    finishLines(doc).map((l) => distToSegment(p, l.$1, l.$2)).reduce(math.min);

/// The shell over one document, its camera set, its pixels read once.
final class Shot {
  Shot._(this.tester, this.view, this.topLeft, this.pixels, this.width);

  final WidgetTester tester;
  final PlannerView view;
  final Offset topLeft;
  final ByteData pixels;
  final int width;

  /// Pumps the shell over [doc] with [pxPerMm] at [centre], y up, the
  /// translation fractional, and reads its pixels back.
  static Future<Shot> of(WidgetTester tester, DraftDocument doc) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final capture = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: capture, child: MaterialApp(home: PlannerShell(document: doc))));
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final layer = find.byType(InteractionLayer);
    final size = tester.getSize(layer);
    view.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(
            pxPerMm,
            0,
            0,
            -pxPerMm,
            size.width / 2 - pxPerMm * centre.x + 0.37,
            size.height / 2 + pxPerMm * centre.y + 0.61));
    await tester.pump();
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final (pixels, width) = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      image.dispose();
      return (bytes!, width);
    }))!;
    return Shot._(tester, view, tester.getTopLeft(layer), pixels, width);
  }

  /// Tears the shell down, so another can be pumped over another document.
  Future<void> close() => tester.pumpWidget(const SizedBox());

  Offset globalOf(Vector2 p) {
    final s = view.camera.value.worldToScreen(p);
    return topLeft + Offset(s.x, s.y);
  }

  /// The RGB of the pixel [dx], [dy] away from the one holding [p].
  List<int> _rgb(Vector2 p, int dx, int dy) {
    final o = globalOf(p);
    final i = ((o.dy.floor() + dy) * width + o.dx.floor() + dx) * 4;
    return [pixels.getUint8(i), pixels.getUint8(i + 1), pixels.getUint8(i + 2)];
  }

  /// The pixel that holds [p].
  List<int> rgb(Vector2 p) => _rgb(p, 0, 0);

  /// The darkest pixel of the 3 × 3 block around [p], by luminance.
  List<int> darkest(Vector2 p) {
    List<int>? best;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final c = _rgb(p, dx, dy);
        if (best == null || lum(c) < lum(best)) best = c;
      }
    }
    return best!;
  }

  Future<void> tap(Vector2 p) async {
    await tester.tapAt(globalOf(p));
    await tester.pump();
  }

  /// A mouse drag from world [from] to world [to], past the slop at once.
  Future<void> drag(Vector2 from, Vector2 to) async {
    final a = globalOf(from), b = globalOf(to);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(a);
    await gesture.moveTo(a + const Offset(12, 0));
    await gesture.moveTo(b);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    await tester.pump();
  }
}

/// Relative luminance, 0 (black) to 1 (white).
double lum(List<int> c) =>
    (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;

/// Each channel of [got] within [tol] of [want].
void expectRgb(List<int> got, List<double> want, String why, {double tol = 2}) {
  for (var i = 0; i < 3; i++) {
    expect(got[i], closeTo(want[i], tol), reason: '$why: channel $i of $got');
  }
}

/// [paper] under the tint: the foreground [ink] at [tintAlpha] over it.
List<double> tinted(List<int> paper, int ink) =>
    [for (final c in paper) c + (ink - c) * tintAlpha];

List<int> rgbOf(int argb) =>
    [(argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF];

/// Two points of the Dining floor and one of the Kitchen's, each off the
/// furniture and at least 60 mm from every finish line (asserted).
final List<Vector2> floorPoints = [
  Vector2(17500, 12595),
  Vector2(19000, 11700),
  Vector2(18020, 10550),
];

/// Points of the sofa, the kitchen counter, the table and the lamp, each at
/// least 60 mm from every finish line under it (asserted): a click there
/// would otherwise pick a parquet joint or a tile joint, and a pixel there
/// could be one.
final Vector2 sofa = Vector2(19370.5, 12895.5),
    counter = Vector2(20820.5, 9950.5),
    table = Vector2(18800.5, 13945.5),
    lamp = Vector2(19700.5, 13945.5);
final List<Vector2> furniture = [sofa, counter, table, lamp];

void main() {
  testWidgets(
      'RR1 inside a room a click picks what it picked before, except on a '
      'label; a window band over bare floor selects nothing and over a label '
      'selects the room', (tester) async {
    // The spike's Q6 probes, on D23's plan. The lamp (a circle of 350 at
    // (19,600, 14,200), over the table) lies under the Dining name label,
    // centred at the Dining pole; a click there picks the label: the room
    // (decision 22).
    final probes = {
      'the sofa\'s fill': sofa,
      'the kitchen counter\'s fill': counter,
      'P1\'s east face, 5 mm into Dining': Vector2(17065, 15000.5),
      'Dining\'s bare floor, 75 mm off a parquet joint': floorPoints.first,
      'the lamp, under the Dining name': Vector2(19500.5, 14250.5),
    };
    // A window over the Dining floor, from a point 75 mm from the nearest
    // joint, inside one 150 mm parquet strip; and a window over both Living
    // labels, from bare floor below and left of them (the anchor is about
    // (22,857, 15,391), the area line's box about 100 mm high below it) to
    // above and right of them, 1,300 mm wide.
    final floorBand = (Vector2(17300.5, 12595.5), Vector2(17700.5, 12640.5));
    final labelBand = (Vector2(22200.5, 15145.5), Vector2(23500.5, 15595.5));

    Future<Map<String, Set<SelectionKey>>> run(DraftDocument doc) async {
      for (final p in [
        for (final MapEntry(:key, :value) in probes.entries)
          if (!key.startsWith('P1')) value,
        floorBand.$1,
        labelBand.$1,
      ]) {
        expect(clearance(doc, p), greaterThan(60), reason: 'premise: $p');
      }
      final shot = await Shot.of(tester, doc);
      final view = shot.view;
      final got = <String, Set<SelectionKey>>{};
      for (final MapEntry(key: what, value: p) in probes.entries) {
        view.selection.clear();
        await tester.pump();
        await shot.tap(p);
        got[what] = {...view.selection.keys};
      }
      for (final (what, (from, to)) in [
        ('window over bare floor', floorBand),
        ('window over the Living labels', labelBand),
      ]) {
        view.selection.clear();
        await tester.pump();
        await shot.drag(from, to);
        expect(shot.view.document.commands.undoDepth, 0,
            reason: '$what: a band, not a move');
        got[what] = {...view.selection.keys};
      }
      // The Living name label itself.
      final living = doc.components.withComponent<RoomParams>().isEmpty
          ? null
          : roomNamed(doc, 'Living');
      if (living != null) {
        view.selection.clear();
        await tester.pump();
        await shot.tap(anchorOf(doc, living) + Vector2(0, 0.7 * 125));
        got['the Living name'] = {...view.selection.keys};
      }
      await shot.close();
      return got;
    }

    final bare = sample(rooms: false);
    final without = await run(bare);
    final doc = sample();
    final withRooms = await run(doc);

    // Without rooms, by hand: the furniture, the wall, nothing, the lamp.
    // The topmost furniture region holding [p]: the last drawn, the
    // highest fill handle; its boundary is what a click selects.
    final fills = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == doc.rootHandle &&
            doc.entities.kindAt(slot) == EntityKind.fill)
          doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));
    Handle furnitureAt(Vector2 p) => fills
        .where((f) {
          final b = Handle(payloadOf(doc, f).scalars[0].toInt());
          final kind = kindOf(doc, b);
          final pts = payloadOf(doc, b);
          if (kind == EntityKind.circle) {
            return (p - pts.pointAt(0)).length <= pts.scalars[0];
          }
          return pointInRing(p, worldPoints(doc, b, closed: true));
        })
        .map((f) => Handle(payloadOf(doc, f).scalars[0].toInt()))
        .last;
    final walls = [
      for (final w in doc.components.withComponent<WallParams>())
        if (doc.components.get<WallParams>(w)
            case WallParams(sx: 17000, ex: 17000))
          w,
    ];
    final p1 = walls.single;
    expect(without['the sofa\'s fill'],
        {k(furnitureAt(probes['the sofa\'s fill']!))});
    expect(without['the kitchen counter\'s fill'],
        {k(furnitureAt(probes['the kitchen counter\'s fill']!))});
    expect(without['P1\'s east face, 5 mm into Dining'], {k(p1)});
    expect(without['Dining\'s bare floor, 75 mm off a parquet joint'], isEmpty);
    final lamp = furnitureAt(probes['the lamp, under the Dining name']!);
    expect(kindOf(doc, lamp), EntityKind.circle, reason: 'premise: the lamp');
    expect(without['the lamp, under the Dining name'], {k(lamp)});
    expect(without['window over bare floor'], isEmpty);
    expect(
        without['window over the Living labels']!.every((key) {
          final h = key.target;
          return doc.entities.slotOf(h) != null &&
              kindOf(doc, h) == EntityKind.line;
        }),
        isTrue,
        reason: 'only whole parquet joints');

    // With rooms: the same picks, except on a label.
    for (final what in probes.keys) {
      if (what == 'the lamp, under the Dining name') continue;
      expect(withRooms[what], without[what], reason: what);
    }
    expect(withRooms['the lamp, under the Dining name'],
        {k(roomNamed(doc, 'Dining'))},
        reason: 'the label over the lamp wins the click (decision 22)');
    expect(withRooms['the Living name'], {k(roomNamed(doc, 'Living'))});
    expect(withRooms['window over bare floor'], isEmpty,
        reason: 'the tint is not band-selected');
    expect(
        withRooms['window over the Living labels'],
        {
          ...without['window over the Living labels']!,
          k(roomNamed(doc, 'Living'))
        },
        reason: 'the room, by its labels; nothing else changes');
  });

  testWidgets(
      'RR2 on white paper the tint is the foreground at about 10%: bare '
      'floor #E5E5E5, furniture tinted, not hidden; the keyhole\'s bridge is '
      'not stroked', (tester) async {
    final bare = sample(rooms: false, grid: false);
    final doc = sample(grid: false);
    for (final p in floorPoints) {
      expect(clearance(doc, p), greaterThan(60), reason: 'premise: $p');
    }
    for (final p in furniture) {
      expect(clearance(doc, p), greaterThan(60), reason: 'premise: $p');
    }

    // Living's keyhole bridge (D9): the tint's edge from a corner of its
    // outer ring to a corner of the column, sampled where it lies farthest
    // from every finish line.
    final living = roomNamed(doc, 'Living');
    final tint = worldTintOf(doc, living);
    expect(tint, hasLength(10), reason: 'premise: 4 + 4 + the slit\'s 2');
    const ring = [
      (21500.0, 11560.0),
      (25750.0, 11560.0),
      (25750.0, 16750.0),
      (21500.0, 16750.0)
    ];
    const column = [
      (23500.0, 13800.0),
      (23900.0, 13800.0),
      (23900.0, 14200.0),
      (23500.0, 14200.0)
    ];
    bool isOneOf(Vector2 p, List<(double, double)> at) =>
        at.any((q) => p.x == q.$1 && p.y == q.$2);
    final bridges = [
      for (var i = 0; i < tint.length; i++)
        if (isOneOf(tint[i], ring) &&
            isOneOf(tint[(i + 1) % tint.length], column))
          (tint[i], tint[(i + 1) % tint.length]),
    ];
    final (v, h) = bridges.single;
    var onBridge = v;
    for (var t = 0.2; t <= 0.8; t += 0.01) {
      final p = v + (h - v) * t;
      if (clearance(doc, p) > clearance(doc, onBridge)) onBridge = p;
    }
    expect(clearance(doc, onBridge), greaterThan(60), reason: 'premise');

    final before = await Shot.of(tester, bare);
    final floorWithout = [for (final p in floorPoints) before.rgb(p)];
    final furnitureWithout = [for (final p in furniture) before.rgb(p)];
    final bridgeWithout = before.darkest(onBridge);
    await before.close();
    final shot = await Shot.of(tester, doc);

    for (final (i, p) in floorPoints.indexed) {
      expectRgb(floorWithout[i], [255, 255, 255], 'paper at $p');
      // Black at alpha 26 over white: 255 − 26 = 229, #E5E5E5.
      expectRgb(shot.rgb(p), [229, 229, 229], 'bare floor at $p');
    }
    for (final (i, p) in furniture.indexed) {
      final was = furnitureWithout[i];
      expect(lum(was), lessThan(0.97), reason: 'premise: furniture at $p');
      expectRgb(shot.rgb(p), tinted(was, 0), 'furniture at $p');
    }
    expectRgb(bridgeWithout, [255, 255, 255], 'paper on the bridge');
    expectRgb(shot.darkest(onBridge), [229, 229, 229],
        'the bridge at $onBridge: the tint, not a stroke');
    await shot.close();
  });

  testWidgets('RR3 on Blueprint the tint lifts the paper: white at about 10%',
      (tester) async {
    final bare = sample(rooms: false, background: blueprint, grid: false);
    final doc = sample(background: blueprint, grid: false);
    final before = await Shot.of(tester, bare);
    final floorWithout = [for (final p in floorPoints) before.rgb(p)];
    final sofaWithout = before.rgb(sofa);
    await before.close();
    final shot = await Shot.of(tester, doc);
    final paper = rgbOf(blueprint);
    for (final (i, p) in floorPoints.indexed) {
      expectRgb(floorWithout[i], [for (final c in paper) c.toDouble()],
          'Blueprint at $p');
      // White at alpha 26 over #1F3A5F: (53.8, 78.1, 111.3).
      expectRgb(shot.rgb(p), tinted(paper, 255), 'bare floor at $p');
    }
    expectRgb(shot.rgb(sofa), tinted(sofaWithout, 255), 'the sofa');
    await shot.close();
  });

  /// Samples along the separator, from its start (x 21,500, y 11,560):
  /// D3's pattern is a 200 mm dash and a 100 mm gap, in model millimetres
  /// (30 px and 15 px here), starting with a dash.
  final dashes = [for (var i = 0; i < 4; i++) 100.0 + 300 * i];
  final gaps = [for (var i = 0; i < 4; i++) 250.0 + 300 * i];
  Vector2 along(double d) => Vector2(21500, 11560 + d);

  testWidgets('RR4 the separator paints dashes at 1:50', (tester) async {
    final doc = sample(grid: false);
    expect(pageOf(doc).scaleDenominator, 50, reason: 'premise');
    for (final d in gaps) {
      expect(clearance(doc, along(d)), greaterThan(30), reason: 'premise');
    }
    final shot = await Shot.of(tester, doc);
    for (final d in dashes) {
      expect(lum(shot.darkest(along(d))), lessThan(0.25),
          reason: 'a dash, $d mm along');
    }
    for (final d in gaps) {
      expectRgb(shot.darkest(along(d)), [229, 229, 229], 'a gap, $d mm along');
    }
    await shot.close();
  });

  testWidgets(
      'SR3 without the DASHED record the separator draws continuous and '
      'nothing is refused', (tester) async {
    // The plan's document saved, its DASHED record taken out of the saved
    // tables, and loaded: a file written without it.
    final saved = jsonDecode(enc(sample(grid: false))) as Map<String, Object?>;
    final tables = saved['tables']! as Map<String, Object?>;
    final linetypes = tables['linetypes']! as List;
    final kept = [
      for (final r in linetypes)
        if (LinetypeRecord.fromJson((r as Map).cast<String, Object?>())
                .handle !=
            ReservedHandles.dashedLinetype)
          r,
    ];
    expect(kept, hasLength(linetypes.length - 1), reason: 'premise');
    tables['linetypes'] = kept;
    final doc = DraftDocumentCodec.decodeString(jsonEncode(saved),
        measurer: FlutterTextMeasurer(), registerComponents: (r) {
      PageComponent.register(r);
      parametricCatalog.registerComponents(r);
    });
    expect(
        doc.tables.linetypes.contains(ReservedHandles.dashedLinetype), isFalse);
    final system = installParametric(doc);
    expect(system.drift(), isEmpty);
    expect(system.diagnostics(), isEmpty);

    // An edit that regenerates the separator: 0.25 mm east, one step.
    final sep = doc.components.withComponent<SeparatorParams>().single;
    doc.commands.execute(SetComponentCommand<SeparatorParams>(
        sep, const SeparatorParams(21500.25, 11560, 21500.25, 16750)));
    expect(doc.commands.undoDepth, 1, reason: 'not refused');
    expect(recordOf(doc, kids(doc, sep).single).linetype,
        ReservedHandles.dashedLinetype,
        reason: 'it still names handle 6');
    // Dining (21,500.25 − 17,060) × 5,190 = 23,044,897.5 ("23.04 m²"),
    // Living 4,249.75 × 5,190 − 160,000 = 21,896,202.5 ("21.90 m²").
    expect(labelStrings(doc, roomNamed(doc, 'Dining')), ['Dining', '23.04 m²']);
    expect(labelStrings(doc, roomNamed(doc, 'Living')), ['Living', '21.90 m²']);
    expect(system.drift(), isEmpty);
    expect(system.diagnostics(), isEmpty);
    system.dispose();
    doc.commands.clearHistory();

    final shot = await Shot.of(tester, doc);
    for (final d in [...dashes, ...gaps]) {
      expect(lum(shot.darkest(along(d) + Vector2(0.25, 0))), lessThan(0.25),
          reason: 'continuous, $d mm along');
    }
    await shot.close();
  });

  testWidgets(
      'OL4 selecting a sample-plan room outlines its labels and its ring; '
      'Living\'s outline holds the column\'s hole', (tester) async {
    final doc = sample();
    final shot = await Shot.of(tester, doc);
    final view = shot.view;

    /// [room]'s outline points, world, after a click on its name label.
    Future<List<Vector2>> outlineOf(Handle room) async {
      view.selection.clear();
      await tester.pump();
      await shot.tap(anchorOf(doc, room) + Vector2(0, 0.7 * 125));
      expect(view.selection.keys, {k(room)});
      final c = view.outlines.debugWorldSegmentsOf(k(room))!;
      return [for (var i = 0; i < c.length; i += 2) Vector2(c[i], c[i + 1])];
    }

    bool holds(List<Vector2> points, (double, double) q) =>
        points.any((p) => (p - Vector2(q.$1, q.$2)).length < 1e-6);

    /// Whether [p] lies within the labels' reach of [room]'s anchor: the
    /// two lines are well within 1,000 mm either side and 250 mm above and
    /// below.
    bool nearLabels(Handle room, Vector2 p) {
      final a = anchorOf(doc, room);
      return (p.x - a.x).abs() <= 1000 && (p.y - a.y).abs() <= 250;
    }

    final living = roomNamed(doc, 'Living');
    final l = await outlineOf(living);
    for (final q in const [
      (21500.0, 11560.0),
      (25750.0, 11560.0),
      (25750.0, 16750.0),
      (21500.0, 16750.0)
    ]) {
      expect(holds(l, q), isTrue, reason: 'Living\'s ring corner $q');
    }
    for (final q in const [
      (23500.0, 13800.0),
      (23900.0, 13800.0),
      (23900.0, 14200.0),
      (23500.0, 14200.0)
    ]) {
      expect(holds(l, q), isTrue, reason: 'the column\'s corner $q');
      expect(nearLabels(living, Vector2(q.$1, q.$2)), isFalse,
          reason: 'premise: the column is not the labels');
    }
    expect(l.where((p) => nearLabels(living, p)), hasLength(10),
        reason: 'two label boxes, each closed');

    final kitchen = roomNamed(doc, 'Kitchen');
    final kl = await outlineOf(kitchen);
    const kitchenRing = [
      (17060.0, 8250.0),
      (21440.0, 8250.0),
      (21440.0, 11440.0),
      (17060.0, 11440.0)
    ];
    for (final q in kitchenRing) {
      expect(holds(kl, q), isTrue, reason: 'the Kitchen\'s ring corner $q');
    }
    // No hole: every other point is a label box's.
    for (final p in kl) {
      if (kitchenRing.any((q) => holds([p], q))) continue;
      expect(nearLabels(kitchen, p), isTrue, reason: 'the Kitchen\'s $p');
    }
    await shot.close();
  });
}
