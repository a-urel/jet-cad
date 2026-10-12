// Plan colours spec PC-5 and PC-6 (Slice 2 plan, Task 3): a table's colour
// drawn as a fill under its drafting, the lowest rung of the fill chain
// (group status, own status, colour), in the selection mode and in the
// design mode, toned on a dark canvas as a room's tint is, at the theme's
// `tableColorOpacity` (null: 0.35).
//
// The fixture: one plan, every table turned and mirrored, 38 m and more off
// the origin. Most tables are the embedding fixture's hand-made top (an
// asymmetric quadrilateral, its box off the definition's origin, which is
// the base point and where the number label sits, outside the top); B and K
// are a round top whose circle is off the definition's origin too. A carries
// a status, B a group status, C a colour alone; U is coloured and
// unnumbered, K coloured on a locked layer, H coloured on a hidden layer, M
// carries the unknown name "magenta", N has no colour, and R is coloured
// inside a teal room. Hues teal and purple.
//
// Expected colours are literals and arithmetic here (`composite`), never
// read from the code under test; the dark canvas's tone is the engine's
// `darkCanvasTone`, the function a room's tint goes through.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/colors/plan_color.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_theme.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/new_document.dart' show prepareDocument;
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart'
    show installParametric;
import 'package:jet_cad_floor_plan/src/parametric/room.dart' show RoomParams;
import 'package:jet_cad_floor_plan/src/parametric/wall.dart'
    show Justification, WallParams;
import 'package:jet_cad_floor_plan/src/service/table_status_painter.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_color_component.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show CircleShape, FurnitureSymbol;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../host/embedding_fixture.dart' show embeddingPlacement, embeddingTable;
import '../host/zone_fixture.dart' show addZoneLayer;
import '../support/palette_fixture.dart'
    show
        Shot,
        channelDistance,
        darkTheme,
        hex,
        lightTheme,
        pixelOf,
        shoot,
        shotKey,
        windowAt;
import '../tables/table_fixture.dart' show entryOf;

/// A servable round top, its circle off the definition's origin (the base
/// point, where the number sits, 670 mm from the centre).
const FurnitureSymbol roundTable = FurnitureSymbol(
  key: 'test.round.off',
  name: 'Off-centre round table',
  category: 'Tests',
  tags: ['table', 'test'],
  seats: 4,
  baseX: 0,
  baseY: 0,
  shapes: [CircleShape(600, 300, 400)],
);

const int teal = 0x00897B, purple = 0x8E24AA;
const int whitePaper = 0xFFFFFF;

/// A status colour, opaque, and a group status colour: neither a hue of
/// the palette at 0.35.
const Color red = Color(0xFFE53935);
const Color indigo = Color(0xFF3949AB);

/// `round(255 * 0.35)`, `round(255 * 0.6)`, and a room tint's alpha
/// (transparency 204 of 255).
const int alphaDefault = 89, alphaThemed = 153, tintAlpha = 51;

/// One table of the fixture: its label (null: unnumbered), its top, its base
/// point, its turn (always mirrored), its layer and its stored colour name.
typedef Spec = ({
  String key,
  String? label,
  bool round,
  double x,
  double y,
  double deg,
  String? layer,
  String? color,
});

const String hiddenLayer = 'Hidden', lockedLayer = 'Locked';

const List<Spec> specs = [
  (
    key: 'A',
    label: 'A',
    round: false,
    x: 46000,
    y: -27500,
    deg: 120,
    layer: null,
    color: 'teal'
  ),
  (
    key: 'B',
    label: 'B',
    round: true,
    x: 49000,
    y: -27500,
    deg: 25,
    layer: null,
    color: 'purple'
  ),
  (
    key: 'C',
    label: 'C',
    round: false,
    x: 46000,
    y: -30500,
    deg: 30,
    layer: null,
    color: 'teal'
  ),
  (
    key: 'N',
    label: 'N',
    round: false,
    x: 49000,
    y: -30500,
    deg: -40,
    layer: null,
    color: null
  ),
  (
    key: 'U',
    label: null,
    round: false,
    x: 46000,
    y: -33500,
    deg: 15,
    layer: null,
    color: 'teal'
  ),
  (
    key: 'K',
    label: 'K',
    round: true,
    x: 49000,
    y: -33500,
    deg: 60,
    layer: lockedLayer,
    color: 'purple'
  ),
  (
    key: 'H',
    label: 'H',
    round: false,
    x: 39500,
    y: -27500,
    deg: 45,
    layer: hiddenLayer,
    color: 'teal'
  ),
  (
    key: 'M',
    label: 'M',
    round: false,
    x: 42500,
    y: -27500,
    deg: -20,
    layer: null,
    color: 'magenta'
  ),
  (
    key: 'R',
    label: 'R',
    round: false,
    x: 39000,
    y: -33300,
    deg: 10,
    layer: null,
    color: 'purple'
  ),
];

Spec spec(String key) => specs.singleWhere((s) => s.key == key);

/// The table's placement: turned [Spec.deg] and mirrored, its base point on
/// ([Spec.x], [Spec.y]).
Transform2 placementOf(Spec s) => embeddingPlacement(s.x, s.y, s.deg, sy: -1);

/// A world point inside [s]'s top, well clear of its edges and of its
/// number (at the base point, outside the top): the quadrilateral's (650,
/// 50), 250 mm and more from every edge; the circle's centre.
Vector2 insideTop(Spec s) => placementOf(s)
    .transformPoint(s.round ? Vector2(600, 300) : Vector2(650, 50));

/// The teal room's tint, clear of every table and of the room's labels.
final Vector2 tintSample = Vector2(43000, -34300);

/// The fixture: a 1:50 page, a teal room (four 200 mm walls, 38-44 m by
/// -35 to -31 m), then [specs] in order, their colours stored as the plan
/// stores them. History cleared, the parametric system disposed.
DraftDocument fillDoc(TextMeasurer measurer, {List<Spec>? only}) {
  final doc = prepareDocument(measurer);
  final system = installParametric(doc);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          originX: 37000,
          originY: -36200,
          background: 0xFFFFFFFF,
          gridVisible: false,
          snapToGrid: false)));
  if (only == null) {
    void wall(double sx, double sy, double ex, double ey) {
      final h = doc.handleSeed.next();
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        SetComponentCommand<WallParams>(
            h, WallParams(sx, sy, ex, ey, 200, Justification.centre)),
      ], label: 'Add wall'));
    }

    wall(38000, -35000, 44000, -35000);
    wall(44000, -35000, 44000, -31000);
    wall(44000, -31000, 38000, -31000);
    wall(38000, -31000, 38000, -35000);
    final room = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: room,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      SetComponentCommand<RoomParams>(
          room, const RoomParams(41500, -32000, 'Dining', color: 'teal')),
    ], label: 'Add room'));
  }
  final layers = {
    hiddenLayer: addZoneLayer(doc, hiddenLayer, visible: false),
    lockedLayer: addZoneLayer(doc, lockedLayer, locked: true),
  };
  for (final s in only ?? specs) {
    doc.commands.execute(placeSymbol(
        doc, entryOf(s.round ? roundTable : embeddingTable),
        at: Vector2(s.x, s.y),
        transform: placementOf(s),
        numbered: s.label != null));
    final info = TableSurvey.of(doc).tables.last;
    if (s.label case final label?) {
      doc.commands
          .execute(SetEntityTextCommand(info.label!, label, kTableLabelTag));
    }
    if (s.layer case final layer?) {
      doc.commands
          .execute(SetInstanceLayerCommand(info.instance, layers[layer]!));
    }
    if (s.color case final name?) {
      final known = floorPlanColorNamed(name);
      doc.commands.execute(SetComponentCommand<FloorPlanTableColor>(
          info.instance,
          known == null
              ? FloorPlanTableColor.fromJson({'color': name})
              : FloorPlanTableColor(known)));
    }
  }
  system.dispose();
  doc.commands.clearHistory();
  return doc;
}

/// The fixture as a file.
String fillJson() {
  final m = FlutterTextMeasurer();
  final doc = fillDoc(m);
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  m.clear();
  return json;
}

/// [rgb] at [alpha] over the opaque [paper], straight alpha, per channel
/// `round(a * s + (1 - a) * p)`.
int composite(int rgb, int alpha, int paper) {
  final a = alpha / 255;
  var out = 0;
  for (final shift in const [16, 8, 0]) {
    final s = (rgb >> shift) & 0xFF;
    final p = (paper >> shift) & 0xFF;
    out |= (a * s + (1 - a) * p).round() << shift;
  }
  return out;
}

// ---------------------------------------------------------------------------
// The painter alone.

/// The painter's camera: 0.1 px/mm, y up, the plan in a 1400 x 1000 image.
const Transform2 painterCamera = Transform2(0.1, 0, 0, -0.1, -3780, -2560);
const int imageW = 1400, imageH = 1000;

/// Screen of world [w] under [painterCamera], as a pixel.
(int, int) painterPixel(Vector2 w) => (
      (painterCamera.a * w.x + painterCamera.c * w.y + painterCamera.e).floor(),
      (painterCamera.b * w.x + painterCamera.d * w.y + painterCamera.f).floor(),
    );

/// Screen of [s]'s base point under [painterCamera]: where its fill's
/// matrix translates to, and its caption's centre.
({double x, double y}) originOf(Spec s) => (
      x: painterCamera.a * s.x + painterCamera.c * s.y + painterCamera.e,
      y: painterCamera.b * s.x + painterCamera.d * s.y + painterCamera.f,
    );

/// Records each fill (its matrix's translation and its paint's ARGB) and
/// each caption's centre x.
final class FillSpy implements ui.Canvas {
  final List<({double x, double y, int argb})> fills = [];
  final List<({double x, double y})> captions = [];
  double _x = double.nan, _y = double.nan;
  ui.Offset _t = ui.Offset.zero;

  @override
  void save() {}
  @override
  void restore() {}
  @override
  void transform(Float64List matrix4) {
    _x = matrix4[12];
    _y = matrix4[13];
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) =>
      fills.add((x: _x, y: _y, argb: paint.color.toARGB32()));
  @override
  void translate(double dx, double dy) => _t = ui.Offset(dx, dy);
  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) =>
      captions.add((x: _t.dx + paragraph.width / 2, y: _t.dy));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');

  /// The ARGB of [s]'s fill, null when it has none.
  int? fillOf(Spec s) {
    final o = originOf(s);
    final at = [
      for (final f in fills)
        if ((f.x - o.x).abs() < 1e-6 && (f.y - o.y).abs() < 1e-6) f.argb
    ];
    expect(at.length, lessThanOrEqualTo(1), reason: '${s.key}: one fill');
    return at.isEmpty ? null : at.single;
  }

  /// Whether a caption is centred below [s]'s number: on its x, its top
  /// within 40 px below it.
  bool captioned(Spec s) {
    final o = originOf(s);
    return captions
        .any((c) => (c.x - o.x).abs() < 1 && c.y - o.y >= 0 && c.y - o.y < 40);
  }
}

typedef Notifiers = ({
  ValueNotifier<Map<String, TableStatus>> statuses,
  ValueNotifier<Map<String, TableGroup>> groups,
  ValueNotifier<Map<String, TableStatus>> groupStatuses,
  ValueNotifier<FloorPlanTheme?> theme,
  ValueNotifier<int> paper,
});

/// The painter over [doc] under [painterCamera], with its notifiers.
(TableStatusPainter, Notifiers) painterOver(DraftDocument doc,
    {Map<String, TableStatus> statuses = const {},
    Map<String, TableGroup> groups = const {},
    Map<String, TableStatus> groupStatuses = const {},
    FloorPlanTheme? theme}) {
  final camera =
      ValueNotifier(ViewportTransform(worldToScreenMatrix: painterCamera));
  final n = (
    statuses: ValueNotifier(statuses),
    groups: ValueNotifier(groups),
    groupStatuses: ValueNotifier(groupStatuses),
    theme: ValueNotifier<FloorPlanTheme?>(theme),
    paper: ValueNotifier<int>(0xFFFFFFFF),
  );
  final painter = TableStatusPainter(
    document: doc,
    camera: camera,
    statuses: n.statuses,
    tableGroups: n.groups,
    groupStatuses: n.groupStatuses,
    paper: n.paper,
    theme: n.theme,
    repaint: Listenable.merge(
        [camera, n.statuses, n.groups, n.groupStatuses, n.theme, n.paper]),
  );
  return (painter, n);
}

FillSpy record(TableStatusPainter p) {
  final spy = FillSpy();
  p.paint(spy, const ui.Size(1400, 1000));
  return spy;
}

/// The painter drawn over white, read back.
Future<Shot> render(WidgetTester tester, TableStatusPainter p) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const Color(0xFFFFFFFF), ui.BlendMode.src);
      p.paint(canvas, const ui.Size(1400, 1000));
      final image = await recorder.endRecording().toImage(imageW, imageH);
      final data = await image.toByteData();
      image.dispose();
      return Shot(data!, imageW, imageH);
    }))!;

/// [shot]'s pixel at [p] is [want] within 2 per channel.
void expectPixel(Shot shot, (int, int) p, int want, String reason) {
  final got = shot.rgbAt(p.$1, p.$2);
  expect(channelDistance(got, want), lessThanOrEqualTo(2),
      reason: '$reason: ${hex(got)}, want ${hex(want)}');
}

int argb(int alpha, int rgb) => (alpha << 24) | rgb;

// ---------------------------------------------------------------------------
// Through the view.

/// The view's camera: 0.06 px/mm, y up, every table in the drawing area of
/// either mode at 1440 x 900.
final ViewportTransform viewCamera = ViewportTransform(
    worldToScreenMatrix: const Transform2(0.06, 0, 0, -0.06, -2260, -1528));

FloorPlanController controllerOver() {
  final c = FloorPlanController(json: fillJson());
  addTearDown(c.dispose);
  return c;
}

/// [c]'s view under the seed's themes in [mode], inside the capture
/// boundary; the tree keeps its shape, so a re-pump keeps every state.
Future<void> pumpApp(WidgetTester tester, FloorPlanController c,
        {ThemeMode mode = ThemeMode.light, FloorPlanTheme? theme}) =>
    tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: RepaintBoundary(
          key: shotKey,
          child: Scaffold(body: FloorPlanView(controller: c, theme: theme))),
    ));

/// The first pump of [c]'s view, then [viewCamera].
Future<void> pumpPlan(WidgetTester tester, FloorPlanController c,
    {ThemeMode mode = ThemeMode.light, FloorPlanTheme? theme}) async {
  windowAt(tester, const Size(1440, 900));
  await pumpApp(tester, c, mode: mode, theme: theme);
  await tester.pump();
  await tester.pump();
  c.cameraController.value = viewCamera;
  await tester.pump();
}

/// [shot]'s pixel at world [w] in the view is [want] within 2 per channel.
void expectAt(
        WidgetTester tester, Shot shot, Vector2 w, int want, String reason) =>
    expectPixel(shot, pixelOf(tester, w), want, reason);

/// The frame after a document change: the planner hears its document's
/// changes on the dispatcher's stream, which is asynchronous, so the first
/// pump delivers the change (it asks for a frame) and the second draws
/// that frame. Nothing else moves.
Future<void> nextFrame(WidgetTester tester) async {
  await tester.pump();
  expect(tester.binding.hasScheduledFrame, isTrue,
      reason: 'the change asks for a frame');
  await tester.pump();
}

/// The design mode's fill painter.
TableStatusPainter designPainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const Key('table-colour-layer')))
    .painter! as TableStatusPainter;

void main() {
  test('the fixture: every table turned and mirrored, off the origin', () {
    final doc = fillDoc(const InsertionPointMeasurer());
    addTearDown(doc.dispose);
    final survey = TableSurvey.of(doc);
    expect(survey.tables, hasLength(specs.length));
    for (final s in specs) {
      final t = placementOf(s);
      expect(t.a * t.d - t.b * t.c, closeTo(-1, 1e-12), reason: s.key);
      expect(t.b.abs(), greaterThan(0.1), reason: '${s.key} turned');
    }
    expect(survey.tables.where((t) => t.number == null), hasLength(1));
    expect(floorPlanColorNamed('magenta'), isNull, reason: 'unknown name');
  });

  testWidgets(
      'TF1 M-C18 design mode, default theme: a teal top composites teal at '
      'alpha 89 over the paper, a purple one purple; an uncoloured, a hidden '
      'and an unknown-coloured one show the paper; a purple table in a teal '
      'room lies under the room\'s tint', (tester) async {
    final c = controllerOver();
    await pumpPlan(tester, c);
    expect(find.byKey(const Key('table-colour-layer')), findsOneWidget);
    final shot = await shoot(tester);
    final tealFill = composite(teal, alphaDefault, whitePaper);
    final purpleFill = composite(purple, alphaDefault, whitePaper);
    expect(hex(tealFill), hex(0xA6D6D1), reason: 'premise: the arithmetic');
    for (final k in ['A', 'C', 'U']) {
      expectAt(tester, shot, insideTop(spec(k)), tealFill, k);
    }
    for (final k in ['B', 'K']) {
      expectAt(tester, shot, insideTop(spec(k)), purpleFill, k);
    }
    for (final k in ['N', 'H', 'M']) {
      expectAt(tester, shot, insideTop(spec(k)), whitePaper, k);
    }
    expectAt(tester, shot, tintSample, composite(teal, tintAlpha, whitePaper),
        'the room\'s tint alone');
    expectAt(tester, shot, insideTop(spec('R')),
        composite(teal, tintAlpha, purpleFill), 'R under the room\'s tint');
  });

  testWidgets(
      'TF2 M-C5 the chain, selection mode\'s painter: A (teal, statused '
      'red) shows the status; B (purple, its group statused) the group\'s; '
      'C (teal, no status) teal, with no caption', (tester) async {
    final doc = fillDoc(const InsertionPointMeasurer());
    addTearDown(doc.dispose);
    final (painter, _) = painterOver(doc, statuses: {
      'A': TableStatus(color: red, caption: 'Bill')
    }, groups: {
      'g': TableGroup(members: {'B'})
    }, groupStatuses: {
      'g': TableStatus(color: indigo, caption: 'Gr')
    });
    final spy = record(painter);
    expect(spy.fillOf(spec('A')), 0xFFE53935);
    expect(spy.fillOf(spec('B')), 0xFF3949AB);
    expect(spy.fillOf(spec('C')), argb(alphaDefault, teal));
    expect(spy.captions, hasLength(2));
    expect(spy.captioned(spec('A')), isTrue, reason: 'A\'s status caption');
    expect(spy.captioned(spec('B')), isTrue, reason: 'the group\'s caption');
    expect(spy.captioned(spec('C')), isFalse, reason: 'a colour has none');

    final shot = await render(tester, painter);
    expectPixel(shot, painterPixel(insideTop(spec('A'))), 0xE53935, 'A');
    expectPixel(shot, painterPixel(insideTop(spec('B'))), 0x3949AB, 'B');
    expectPixel(shot, painterPixel(insideTop(spec('C'))),
        composite(teal, alphaDefault, whitePaper), 'C');
  });

  testWidgets(
      'TF3 M-C6 M-C21 a coloured table on the hidden layer and one '
      'carrying "magenta" draw nothing', (tester) async {
    final doc = fillDoc(const InsertionPointMeasurer());
    addTearDown(doc.dispose);
    final (painter, _) = painterOver(doc);
    final spy = record(painter);
    expect(spy.fillOf(spec('H')), isNull, reason: 'hidden');
    expect(spy.fillOf(spec('M')), isNull, reason: 'unknown name');
    expect(spy.fillOf(spec('N')), isNull, reason: 'no colour');
    expect(spy.fills, hasLength(6), reason: 'A, B, C, U, K and R');
    final shot = await render(tester, painter);
    for (final k in ['H', 'M', 'N']) {
      expectPixel(shot, painterPixel(insideTop(spec(k))), whitePaper, k);
    }
  });

  testWidgets(
      'TF4 M-C19 M-C20 the unnumbered table and the one on the locked layer '
      'are filled', (tester) async {
    final doc = fillDoc(const InsertionPointMeasurer());
    addTearDown(doc.dispose);
    final (painter, _) = painterOver(doc);
    final spy = record(painter);
    expect(spy.fillOf(spec('U')), argb(alphaDefault, teal), reason: 'U');
    expect(spy.fillOf(spec('K')), argb(alphaDefault, purple), reason: 'K');
    final shot = await render(tester, painter);
    expectPixel(shot, painterPixel(insideTop(spec('U'))),
        composite(teal, alphaDefault, whitePaper), 'unnumbered');
    expectPixel(shot, painterPixel(insideTop(spec('K'))),
        composite(purple, alphaDefault, whitePaper), 'locked');
  });

  testWidgets(
      'TF5 M-C8 tableColorOpacity 0.6 beside statusFillOpacity 0.8: a '
      'colour\'s alpha is 153, a status\'s its own alpha times 0.8, each '
      'applied once; in the design mode too', (tester) async {
    final doc = fillDoc(const InsertionPointMeasurer());
    addTearDown(doc.dispose);
    final (painter, n) = painterOver(doc,
        statuses: {'A': TableStatus(color: const Color(0xCCE53935))},
        theme: const FloorPlanTheme(
            tableColorOpacity: 0.6, statusFillOpacity: 0.8));
    var spy = record(painter);
    // 0xCC = 204; 204 x 0.8 = 163.2.
    expect(spy.fillOf(spec('A')), argb(163, 0xE53935));
    expect(spy.fillOf(spec('C')), argb(alphaThemed, teal));
    expect(spy.fillOf(spec('K')), argb(alphaThemed, purple));
    final shot = await render(tester, painter);
    expectPixel(shot, painterPixel(insideTop(spec('C'))),
        composite(teal, alphaThemed, whitePaper), 'C at 0.6');

    // statusFillOpacity alone leaves a colour at 0.35; no theme is 0.35.
    n.theme.value = const FloorPlanTheme(statusFillOpacity: 0.8);
    spy = record(painter);
    expect(spy.fillOf(spec('C')), argb(alphaDefault, teal));
    n.theme.value = null;
    spy = record(painter);
    expect(spy.fillOf(spec('C')), argb(alphaDefault, teal));
    expect(spy.fillOf(spec('A')), 0xCCE53935);

    // The design mode's mount reads the view's theme.
    final c = controllerOver();
    await pumpPlan(tester, c,
        theme: const FloorPlanTheme(
            tableColorOpacity: 0.6, statusFillOpacity: 0.8));
    final view = await shoot(tester);
    expectAt(tester, view, insideTop(spec('C')),
        composite(teal, alphaThemed, whitePaper), 'design mode, C at 0.6');
    expectAt(tester, view, insideTop(spec('B')),
        composite(purple, alphaThemed, whitePaper), 'design mode, B at 0.6');
  });

  testWidgets(
      'TF6 Review Focus 1: in the selection mode a status arriving on a teal '
      'table covers its colour, and leaving shows it again, with no '
      'document change', (tester) async {
    final c = controllerOver();
    c.setMode(FloorPlanMode.selection);
    await pumpPlan(tester, c);
    expect(find.byKey(const Key('table-colour-layer')), findsNothing,
        reason: 'the design mount is not in the selection mode');
    final state = c.activeDocument.commands.stateId;
    final c0 = insideTop(spec('C'));
    final tealFill = composite(teal, alphaDefault, whitePaper);
    expectAt(tester, await shoot(tester), c0, tealFill, 'teal before');

    c.setTableStatus({'C': TableStatus(color: red)});
    await tester.pump();
    expectAt(tester, await shoot(tester), c0, 0xE53935, 'the status');

    c.setTableStatus(const {});
    await tester.pump();
    expectAt(tester, await shoot(tester), c0, tealFill, 'teal again');
    expect(c.activeDocument.commands.stateId, state,
        reason: 'no document change');
  });

  testWidgets(
      'TF7 M-C25 Review Focus 5: on the dark canvas a teal table is '
      'darkCanvasTone(teal) at alpha 89 over the dark paper, matching the '
      'teal room\'s tint; a switch to light with no document change: plain '
      'teal over white; the selection mode tones too', (tester) async {
    expect(darkCanvasFor(page: 0xFFFFFFFF, brightness: Brightness.dark), isTrue,
        reason: 'premise: a dark theme over a white page');
    const paper = kDarkCanvasPaper & 0xFFFFFF;
    final tone = darkCanvasTone(teal, paper);
    expect(tone, isNot(teal), reason: 'premise: the tone moves teal');
    final c = controllerOver();
    await pumpPlan(tester, c, mode: ThemeMode.dark);
    final state = c.activeDocument.commands.stateId;
    var shot = await shoot(tester);
    final (cx, cy) = pixelOf(tester, insideTop(spec('C')));
    final (rx, ry) = pixelOf(tester, tintSample);
    final fill = shot.rgbAt(cx, cy), tint = shot.rgbAt(rx, ry);
    expect(channelDistance(fill, composite(tone, alphaDefault, paper)),
        lessThanOrEqualTo(2),
        reason: 'fill ${hex(fill)}, want '
            '${hex(composite(tone, alphaDefault, paper))}');
    expect(channelDistance(tint, composite(tone, tintAlpha, paper)),
        lessThanOrEqualTo(2),
        reason: 'tint ${hex(tint)}, want '
            '${hex(composite(tone, tintAlpha, paper))}');
    // The room's tint, taken back to its colour and recomposited at 89.
    var again = 0;
    for (final shift in const [16, 8, 0]) {
      final t = (tint >> shift) & 0xFF, p = (paper >> shift) & 0xFF;
      final hue = (t - (1 - tintAlpha / 255) * p) / (tintAlpha / 255);
      again |= (alphaDefault / 255 * hue + (1 - alphaDefault / 255) * p)
              .round()
              .clamp(0, 255) <<
          shift;
    }
    expect(channelDistance(fill, again), lessThanOrEqualTo(2),
        reason: 'fill ${hex(fill)}, the tint at 89 ${hex(again)}');

    await pumpApp(tester, c);
    await tester.pump();
    shot = await shoot(tester);
    expectAt(tester, shot, insideTop(spec('C')),
        composite(teal, alphaDefault, whitePaper), 'light: plain teal');
    expectAt(tester, shot, tintSample, composite(teal, tintAlpha, whitePaper),
        'light: the tint');
    expect(c.activeDocument.commands.stateId, state,
        reason: 'no document change');

    await pumpApp(tester, c, mode: ThemeMode.dark);
    await tester.pump();
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    c.cameraController.value = viewCamera;
    await tester.pump();
    expect(find.byKey(const Key('table-status-layer')), findsOneWidget);
    expectAt(tester, await shoot(tester), insideTop(spec('C')),
        composite(tone, alphaDefault, paper), 'selection mode, dark');
  });

  testWidgets(
      'TF8 M-C24 M-C15 setTableColor, undo and redo each show at the next '
      'frame in the design mode, nothing else moving', (tester) async {
    final c = controllerOver();
    await pumpPlan(tester, c);
    final n = insideTop(spec('N'));
    expectAt(tester, await shoot(tester), n, whitePaper, 'premise');

    expect(c.setTableColor('N', FloorPlanColor.teal), isTrue);
    await nextFrame(tester);
    final tealFill = composite(teal, alphaDefault, whitePaper);
    expectAt(tester, await shoot(tester), n, tealFill, 'set');

    c.undo();
    await nextFrame(tester);
    expectAt(tester, await shoot(tester), n, whitePaper, 'undone');

    c.redo();
    await nextFrame(tester);
    expectAt(tester, await shoot(tester), n, tealFill, 'redone');
  });

  testWidgets(
      'TF8b Review Focus 2 (on screen): a coloured table deleted in the '
      'editor leaves the paper; Undo brings its fill back at the next frame, '
      'at the same pixel, and in tableDetails', (tester) async {
    final c = controllerOver();
    await pumpPlan(tester, c);
    final doc = c.activeDocument;
    final instance = TableSurvey.of(doc).withNumber('C').single.instance;
    final at = insideTop(spec('C'));
    final tealFill = composite(teal, alphaDefault, whitePaper);
    expectAt(tester, await shoot(tester), at, tealFill, 'premise: teal');

    c.select({'C'});
    await tester.pump();
    expect(c.selectedTables.value, {'C'}, reason: 'premise: selected');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await nextFrame(tester);
    expect(doc.tree[instance], isNull, reason: 'premise: deleted');
    expect(c.tableDetails.where((d) => d.table.number == 'C'), isEmpty);
    expectAt(tester, await shoot(tester), at, whitePaper, 'deleted');

    c.undo();
    await nextFrame(tester);
    expect(doc.tree[instance], isA<InstanceNode>(), reason: 'premise: back');
    expect(c.tableDetails.singleWhere((d) => d.table.number == 'C').color,
        FloorPlanColor.teal);
    expectAt(tester, await shoot(tester), at, tealFill, 'undone: teal');
  });

  testWidgets(
      'TF9 the allocation bar on the design mount: ten camera frames '
      'allocate and rebuild nothing; a colour change rebuilds once',
      (tester) async {
    final c = controllerOver();
    await pumpPlan(tester, c);
    final painter = designPainter(tester);
    final made = painter.debugAllocations;
    final rebuilds = painter.debugRebuilds;
    expect(made, greaterThan(0), reason: 'premise: the fills are built');
    for (var i = 1; i <= 10; i++) {
      c.cameraController.value = ViewportTransform(
          worldToScreenMatrix: Transform2(0.06 + 0.002 * i, 0, 0,
              -0.06 - 0.002 * i, -2260 - 7.5 * i, -1528 + 3.25 * i));
      await tester.pump();
    }
    expect(identical(designPainter(tester), painter), isTrue);
    expect(painter.debugAllocations, made, reason: 'nothing per frame');
    expect(painter.debugRebuilds, rebuilds, reason: 'no rebuild per frame');

    expect(c.setTableColor('N', FloorPlanColor.purple), isTrue);
    await nextFrame(tester);
    expect(painter.debugRebuilds, rebuilds + 1);
    await tester.pump();
    expect(painter.debugRebuilds, rebuilds + 1);
  });

  test(
      'TF10 M-C18 with no statuses and no groups (the design mount), one '
      'coloured table is one fill after the first paint', () {
    final doc = fillDoc(const InsertionPointMeasurer(), only: [spec('C')]);
    addTearDown(doc.dispose);
    final (painter, _) = painterOver(doc);
    final spy = record(painter);
    expect(spy.fills, hasLength(1));
    expect(spy.fillOf(spec('C')), argb(alphaDefault, teal));
    expect(painter.debugRebuilds, 1);
  });
}
