// R-16's room lines of the fill tests (3a Task 28, D-35, D-36; rulings
// R-P18, IA-R6), from jet_cad_floor_plan/test/service/table_fill_test.dart:
// the room's and its tint's lines of TF1 (:542-545), TF3 (:587) and TF7
// (:690-711, :718-719), verbatim, each with the premises it needs. Their
// table halves stay 2b's (jet_cad_2d_plan/test/service/paint/
// unit_fill_test.dart), which build the plan's internal painter by hand;
// here the fixture is 2b's with today's teal room and its table R
// (`fill_plan.dart`), in `PlanEditor` over the architecture kit and the
// fixture kit, the design canvas's colour layer read as the `CustomPainter`
// of the `CustomPaint` keyed `unit-colour-layer`
// (jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart:395-399) and recorded by
// the source's `FillSpy`; the pixels through `shot.dart`.
//
// Plan colours spec PC-5 and PC-6: a table's colour drawn as a fill under
// its drafting, toned on a dark canvas as a room's tint is. Expected
// colours are literals and arithmetic here (`composite`), never read from
// the code under test; the dark canvas's tone is the Flutter layer's
// `darkCanvasTone`, the function a room's tint goes through.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform, darkCanvasFor, darkCanvasTone, kDarkCanvasPaper;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/fill_plan.dart';
import '../support/shot.dart';
import '../support/units.dart' show fxKit;

/// The painter's camera: 0.1 px/mm, y up, the plan in a 1400 x 1000 image
/// (unit_fill_test.dart:262-263).
const Transform2 painterCamera = Transform2(0.1, 0, 0, -0.1, -3780, -2560);

/// Screen of [s]'s base point under [painterCamera]: where its fill's
/// matrix translates to, and its caption's centre.
({double x, double y}) originOf(Spec s) => (
      x: painterCamera.a * s.x + painterCamera.c * s.y + painterCamera.e,
      y: painterCamera.b * s.x + painterCamera.d * s.y + painterCamera.f,
    );

/// Records each fill (its matrix's translation and its paint's ARGB) and
/// each caption's centre x (unit_fill_test.dart:280-327, copied).
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
}

/// The view's camera: 0.06 px/mm, y up, every table in the drawing area at
/// 1440 x 900 (unit_fill_test.dart:401-402).
final ViewportTransform viewCamera = ViewportTransform(
    worldToScreenMatrix: const Transform2(0.06, 0, 0, -0.06, -2260, -1528));

PlanController controllerOver() {
  final c = PlanController(kits: [architectureKit, fxKit()], json: fillJson());
  addTearDown(c.dispose);
  return c;
}

/// [c]'s editor under the seed's themes in [mode], inside the capture
/// boundary; the tree keeps its shape, so a re-pump keeps every state.
Future<void> pumpApp(WidgetTester tester, PlanController c,
        {ThemeMode mode = ThemeMode.light}) =>
    pumpThemed(tester, Scaffold(body: PlanEditor(controller: c)), mode);

/// The first pump of [c]'s editor, then [camera] ([viewCamera]).
Future<void> pumpPlan(WidgetTester tester, PlanController c,
    {ThemeMode mode = ThemeMode.light, ViewportTransform? camera}) async {
  windowAt(tester, const Size(1440, 900));
  await pumpApp(tester, c, mode: mode);
  await tester.pump();
  await tester.pump();
  c.camera.value = camera ?? viewCamera;
  await tester.pump();
}

void expectPixel(Shot shot, (int, int) p, int want, String reason) {
  final got = shot.rgbAt(p.$1, p.$2);
  expect(channelDistance(got, want), lessThanOrEqualTo(2),
      reason: '$reason: ${hex(got)}, want ${hex(want)}');
}

/// [shot]'s pixel at world [w] in the view is [want] within 2 per channel.
void expectAt(
        WidgetTester tester, Shot shot, Vector2 w, int want, String reason) =>
    expectPixel(shot, pixelOf(tester, w), want, reason);

void main() {
  testWidgets(
      'TF1-room M-C18 design mode, default theme: a purple table in a teal '
      'room lies under the room\'s tint (the room\'s lines of TF1)',
      (tester) async {
    final c = controllerOver();
    await pumpPlan(tester, c);
    expect(find.byKey(const Key('unit-colour-layer')), findsOneWidget);
    final shot = await shoot(tester);
    final purpleFill = composite(purple, alphaDefault, whitePaper);
    expectAt(tester, shot, tintSample, composite(teal, tintAlpha, whitePaper),
        'the room\'s tint alone');
    expectAt(tester, shot, insideTop(spec('R')),
        composite(teal, tintAlpha, purpleFill), 'R under the room\'s tint');
  });

  testWidgets(
      'TF3-count M-C6 M-C21 a coloured table on the hidden layer and one '
      'carrying "magenta" draw nothing; R, coloured in the room, is filled '
      '(the room\'s line of TF3)', (tester) async {
    final c = controllerOver();
    await pumpPlan(tester, c,
        camera: ViewportTransform(worldToScreenMatrix: painterCamera));
    final painter = tester
        .widget<CustomPaint>(find.byKey(const Key('unit-colour-layer')))
        .painter!;
    final spy = FillSpy();
    painter.paint(spy, const Size(1400, 1000));
    expect(spy.fillOf(spec('H')), isNull, reason: 'hidden');
    expect(spy.fillOf(spec('M')), isNull, reason: 'unknown name');
    expect(spy.fillOf(spec('N')), isNull, reason: 'no colour');
    expect(spy.fills, hasLength(6), reason: 'A, B, C, U, K and R');
  });

  testWidgets(
      'TF7-tint M-C25 Review Focus 5: on the dark canvas a teal table is '
      'darkCanvasTone(teal) at alpha 89 over the dark paper, matching the '
      'teal room\'s tint; a switch to light with no document change: the '
      'tint over white (the room\'s lines of TF7)', (tester) async {
    expect(darkCanvasFor(page: 0xFFFFFFFF, brightness: Brightness.dark), isTrue,
        reason: 'premise: a dark theme over a white page');
    const paper = kDarkCanvasPaper & 0xFFFFFF;
    final tone = darkCanvasTone(teal, paper);
    expect(tone, isNot(teal), reason: 'premise: the tone moves teal');
    final c = controllerOver();
    await pumpPlan(tester, c, mode: ThemeMode.dark);
    final state = c.document.commands.stateId;
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
    expectAt(tester, shot, tintSample, composite(teal, tintAlpha, whitePaper),
        'light: the tint');
    expect(c.document.commands.stateId, state, reason: 'no document change');
  });
}
