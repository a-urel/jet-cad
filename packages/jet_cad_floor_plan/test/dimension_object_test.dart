// Spec 11 D3, D7, D8, D15, D16: a dimension as an object. Its six records
// and their attributes, its page key (a page change rewrites every dimension
// in the page edit's own undo step; a paper or grid change generates none),
// save and load, its handles across regenerations, and its diagnostics.
// Every expected value is hand arithmetic beside the assertion; each
// dimension's own group sits at the placement (and, in `DO1` and `DO3`,
// turned further), so a hand value in the plan's frame holds at every
// placement. Ported from the spike's `engine_test.dart` (`Q5a`) and
// `drift_test.dart` (`Q2d`); the file cases from 10's
// `room_diagnostics_test.dart` (`staleFile`).
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/src/parametric/box.dart';
import 'package:jet_cad_floor_plan/src/parametric/dimension.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

const l = WallSide.left, r = WallSide.right;

/// [doc]'s `dimension.` diagnostics.
List<Diagnostic> dimDiagnostics(DraftDocument doc) =>
    codedAs(diagnosticsOf(doc), 'dimension.');

/// `dimension.degenerate` for [h] (D15).
Diagnostic degenerate(Handle h) => Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'dimension.degenerate',
      message: '${h.toHex()} measures zero',
      handles: [h],
    );

/// `dimension.broken` for [h] (D15), for the reasons [why].
Diagnostic broken(Handle h, String why) => Diagnostic(
      severity: DiagnosticSeverity.error,
      code: 'dimension.broken',
      message: '${h.toHex()} is broken ($why): it draws nothing',
      handles: [h],
    );

/// [dim]'s parameters with [change] applied, one command.
DraftCommand setDim(DraftDocument doc, Handle dim,
        DimensionParams Function(DimensionParams p) change) =>
    SetComponentCommand<DimensionParams>(
        dim, change(doc.components.get<DimensionParams>(dim)!));

/// Wall [w]'s thickness to [t], one command.
DraftCommand thickness(DraftDocument doc, Handle w, double t) =>
    SetComponentCommand<WallParams>(
        w, doc.components.get<WallParams>(w)!.copyWith(thickness: t));

/// The page edit the Page panel makes: [change] of the root's page.
DraftCommand setPage(
        DraftDocument doc, PageComponent Function(PageComponent p) change) =>
    SetComponentCommand<PageComponent>(doc.rootHandle, change(pageOf(doc)));

/// 1:100 in feet-inches.
PageComponent ftIn100(PageComponent p) =>
    p.copyWith(scaleDenominator: 100, displayUnit: DisplayUnit.feetInches);

/// `DO3`'s and `DO4`'s L at [place], a millimetres page at 1:50: A (0, 0)
/// → (4000, 0) and B (4000, 0) → (4000, 3000), 200 each, and three
/// dimensions:
///
/// - [d1], attached to attached: A/0/right (0, −100) → A/1/right, the outer
///   mitre (4100, −100), aligned, offset −612.25: 4100;
/// - [d2], attached to a fixed fractional point, in a group turned a further
///   30°: B/1/left (3900, 3000) → the plan point (1234.5, 2500.25), aligned,
///   offset 400.75: √(2665.5² + 499.75²) = √(7,104,890.25 + 249,750.0625) =
///   √7,354,640.3125 = 2,711.944: 2712;
/// - [d3], a `-0.0` offset: A/0/left (0, 100) → A/1/left, the inner corner
///   (3900, 100), horizontal: 3900.
({Plan plan, Handle a, Handle b, Handle d1, Handle d2, Handle d3}) threeOnL(
    Placement place) {
  final plan = buildPlan(
      const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
      place: place);
  final doc = plan.doc;
  attachPage(doc, mmPage);
  final [a, b] = plan.walls;
  final g = place.m;
  final turned = g.multiply(Transform2.rotation(math.pi / 6));
  final d1 = addDimension(doc, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
      offset: -612.25, at: g);
  final d2 = addDimension(
      doc, AttachedEnd(b, 1, l), fixedAt(plan.at(1234.5, 2500.25), turned),
      offset: 400.75, at: turned);
  final d3 = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
      kind: DimKind.horizontal, offset: -0.0, at: g);
  return (plan: plan, a: a, b: b, d1: d1, d2: d2, d3: d3);
}

void main() {
  test(
      'DO1 a dimension\'s children are five LINEs and one TEXT in handle '
      'order; only the two extension lines carry EntityFlags.unpickable; '
      'lineweight 25, ByLayer, layer 0, bottom-centre text', () {
    const place = corpusGroups;
    final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
    final doc = plan.doc;
    attachPage(doc, mmPage);
    final [a] = plan.walls;
    // The dimension's group at the placement, turned a further 37°.
    final g = place.m.multiply(Transform2.rotation(37 * math.pi / 180));
    final dim = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
        offset: 600.5, at: g);
    // A/0/left (0, 100) → A/1/left (4000, 100), aligned: 4000.
    expect(dimText(doc, dim), '4000');

    final ks = kids(doc, dim);
    expect(ks, hasLength(6));
    for (var i = 1; i < ks.length; i++) {
      expect(ks[i].value, greaterThan(ks[i - 1].value), reason: 'ascending');
    }
    expect([
      for (final k in ks) kindOf(doc, k)
    ], [
      EntityKind.line,
      EntityKind.line,
      EntityKind.line,
      EntityKind.line,
      EntityKind.line,
      EntityKind.text,
    ]);
    // The premise: the not-pickable bit is 1 << 1 (D19).
    expect(EntityFlags.unpickable, 2);
    const flags = [0, 2, 2, 0, 0, 0];
    expect([for (final k in ks) recordOf(doc, k).flags], flags);

    final bottomCentre =
        packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.bottom);
    expect(kDimTextAttrs, bottomCentre);
    for (var i = 0; i < ks.length; i++) {
      final rec = recordOf(doc, ks[i]);
      final what = 'child $i';
      expect(rec.owner, dim, reason: what);
      expect(rec.color, const ByLayerColor(), reason: what);
      expect(rec.linetype, ReservedHandles.byLayerLinetype, reason: what);
      expect(rec.layer, ReservedHandles.layerZero, reason: what);
      // 0.25 mm on the five LINEs (decision 20); the TEXT ByLayer.
      final lw = i < 5 ? 25 : kByLayer;
      final attrs = i < 5 ? 0 : bottomCentre;
      expect(rec.lineweight, lw, reason: what);
      expect(rec.textAttrs, attrs, reason: what);
      // Every other attribute is draftRecord's default.
      final want = draftRecord(ks[i], dim, kindOf(doc, ks[i]),
              text: rec.text, layer: ReservedHandles.layerZero)
          .copyWith(flags: flags[i], lineweight: lw, textAttrs: attrs);
      expect(rec.toJson(), want.toJson(), reason: what);
    }
    expect(driftOf(doc), isEmpty);
  });

  for (final place in [origin, corpusGroups]) {
    test(
        'DO2 a page change rewrites every dimension in one undo step with '
        'the same child handles; a paper colour or grid change generates '
        'none; no page reads as 1:50 m, at $place', () {
      // Q5a: A (0, 0) → (4000, 0), 200; A/0/left (0, 100) → A/1/left (4000,
      // 100), aligned, offset 600. u = (1, 0), n = (0, 1): the line at y 100
      // + 600 = 700; at 1:50 the text 1 × 50 = 50 above it at (2000, 750),
      // 2.5 × 50 = 125 tall.
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      final dim = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
          offset: 600, at: place.m);
      void expectText(String text, double height, double y, String what) {
        expect(dimText(doc, dim), text, reason: what);
        final (at, h, _) = dimTextGeometry(doc, dim);
        expect(h, closeTo(height, 1e-9), reason: what);
        expect((at - plan.at(2000, y)).length, lessThan(1e-6), reason: what);
        final line = dimLines(doc, dim)[0];
        expect((line.$1 - plan.at(0, 700)).length, lessThan(1e-6),
            reason: what);
        expect((line.$2 - plan.at(4000, 700)).length, lessThan(1e-6),
            reason: what);
      }

      expectText('4000', 125, 750, '1:50 mm');
      final ks = kids(doc, dim);
      expect(ks, hasLength(6));

      // The page key holds both halves (D3): a scale-only change (1:50 →
      // 1:100 in mm: the text 250 tall, 100 above the line at (2000, 800),
      // still 4000) and a unit-only change (mm → cm at 1:50: 4000 mm = 4000
      // tenths of a cm, 400.0) each regenerate the text; each is undone.
      for (final (what, change, text, height, y) in [
        (
          'scale only',
          (PageComponent p) => p.copyWith(scaleDenominator: 100),
          '4000',
          250.0,
          800.0
        ),
        (
          'unit only',
          (PageComponent p) => p.copyWith(displayUnit: DisplayUnit.centimeters),
          '400.0',
          125.0,
          750.0
        ),
      ]) {
        final n = debugDimensionGenerates;
        doc.commands.execute(setPage(doc, change));
        expect(debugDimensionGenerates, greaterThan(n), reason: what);
        expectText(text, height, y, what);
        expect(kids(doc, dim), ks, reason: what);
        doc.commands.undo();
        expectText('4000', 125, 750, '$what undone');
      }

      // 1:50 mm → 1:100 ft-in, one command. 4000 / 25.4 = 157.48"; in
      // quarters 629.92 → 630 = 13 × 48 + 6: 13'-1 1/2". The text 2.5 × 100
      // = 250 tall, 1 × 100 = 100 above the line: (2000, 800). The line
      // stays at 700: the offset is a model length (decision 18).
      final depth = doc.commands.undoDepth;
      final gens = debugDimensionGenerates;
      doc.commands.execute(setPage(doc, ftIn100));
      expect(doc.commands.undoDepth, depth + 1);
      expect(debugDimensionGenerates, greaterThan(gens));
      expectText("13'-1 1/2\"", 250, 800, '1:100 ft-in');
      expect(kids(doc, dim), ks);
      expect(driftOf(doc), isEmpty);
      doc.commands.undo();
      expectText('4000', 125, 750, 'undone');
      expect(kids(doc, dim), ks);
      doc.commands.redo();
      expectText("13'-1 1/2\"", 250, 800, 'redone');
      expect(kids(doc, dim), ks);

      // A paper colour change and a grid step change: each one step, and no
      // dimension generates (D3's page key).
      for (final (what, change) in [
        ('paper', (PageComponent p) => p.copyWith(background: 0xFF1E3A5F)),
        ('grid', (PageComponent p) => p.copyWith(gridStepMm: 250.0)),
      ]) {
        final before = pageOf(doc);
        final d = doc.commands.undoDepth;
        final n = debugDimensionGenerates;
        doc.commands.execute(setPage(doc, change));
        expect(doc.commands.undoDepth, d + 1, reason: what);
        expect(pageOf(doc) == before, isFalse, reason: what);
        expect(debugDimensionGenerates, n, reason: what);
        expectText("13'-1 1/2\"", 250, 800, what);
      }
      expect(driftOf(doc), isEmpty);

      // No page attached: PageComponent()'s defaults, 1:50 in metres. 4000
      // mm = 400 hundredths of a metre: 4.00, 125 tall.
      final bare = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      expect(bare.doc.components.isRegistered<PageComponent>(), isFalse);
      final [ba] = bare.walls;
      final noPage = addDimension(
          bare.doc, AttachedEnd(ba, 0, l), AttachedEnd(ba, 1, l),
          offset: 600, at: place.m);
      expect(dimText(bare.doc, noPage), '4.00');
      expect(dimTextGeometry(bare.doc, noPage).$2, closeTo(125, 1e-9));
    });

    test(
        'DO3 save, load and save is byte-identical, with references intact, '
        'drift() empty after the load, and a -0.0 offset kept, at $place', () {
      final (:plan, :a, :b, :d1, :d2, :d3) = threeOnL(place);
      final doc = plan.doc;
      expect(dimText(doc, d1), '4100');
      expect(dimText(doc, d2), '2712');
      expect(dimText(doc, d3), '3900');
      final s1 = enc(doc);
      final back = reloadWithPage(s1);
      expect(enc(back), s1);
      expect(driftOf(back), isEmpty);
      for (final d in [d1, d2, d3]) {
        expect(back.components.get<DimensionParams>(d),
            doc.components.get<DimensionParams>(d));
        expect(kids(back, d), kids(doc, d));
      }
      expect(
          back.components.get<DimensionParams>(d3)!.offset.isNegative, isTrue);
      // The equality above tells the loaded -0.0 from +0.0 (D2: the offset
      // by compareTo), so it is not blind to the zero's sign: d3 read back
      // is not its +0.0 twin.
      final d3back = back.components.get<DimensionParams>(d3)!;
      expect(d3back == d3back.copyWith(offset: 0.0), isFalse);
      expect(
          (back.components.get<DimensionParams>(d1)!.a as AttachedEnd).wall, a);
      expect(
          (back.components.get<DimensionParams>(d2)!.a as AttachedEnd).wall, b);

      // The references are intact: B 200 → 300 moves its faces to 4000 ±
      // 150. d1's outer mitre goes to (4150, −100): 4150. d2's B/1/left to
      // (3850, 3000): √(2615.5² + 499.75²) = √(6,840,840.25 + 249,750.0625)
      // = √7,090,590.3125 = 2,662.816: 2663. d3's inner corner to (3850,
      // 100): 3850.
      back.commands.execute(thickness(back, b, 300));
      expect(dimText(back, d1), '4150');
      expect(dimText(back, d2), '2663');
      expect(dimText(back, d3), '3850');
      expect(driftOf(back), isEmpty);
      expect(
          back.components.get<DimensionParams>(d3)!.offset.isNegative, isTrue);
    });
  }

  test('DO4 the same state plus the same edit gives the same bytes', () {
    final x = threeOnL(corpusGroups), y = threeOnL(corpusGroups);
    expect(enc(x.plan.doc), enc(y.plan.doc));
    for (final t in [x, y]) {
      t.plan.doc.commands.execute(thickness(t.plan.doc, t.b, 300.5));
      // B's outer face at 4000 + 150.25: 4150.25 → 4150.
      expect(dimText(t.plan.doc, t.d1), '4150');
    }
    expect(enc(x.plan.doc), enc(y.plan.doc));
  });

  // The -0.0 arises only in an unturned group: in a turned one the text's
  // world angle less the group's is x − x, which is +0.0 in round-to-nearest,
  // or a nonzero residue. So the row sits at the three unturned placements,
  // the far ones among them.
  for (final place in [origin, corpusAxis, km1000Axis]) {
    test(
        'DO6 (rvF-textAngleNoZero) a right-to-left aligned pair stores its '
        'TEXT rotation as +0.0, not -0.0 (D8\'s "+ 0.0"), generated and '
        'after save and load, at $place', () {
      final doc = buildPlan(const [], place: place).doc;
      attachPage(doc, mmPage);
      final g = place.m;
      // (1000, 0) → (0, 0) in the group: d = (−1000, 0), u = (−1, 0),
      // which readable() reverses to ur = (1, −0.0); the world angle is
      // atan2(−0.0, 1) = −0.0, and the group's atan2(0.0, 1) = +0.0, so
      // angle − group = −0.0 − 0.0 = −0.0 before the + 0.0.
      final dim = addDimension(
          doc, const FixedEnd(1000, 0), const FixedEnd(0, 0),
          offset: 400.75, at: g);
      expect(dimText(doc, dim), '1000');
      final l = layoutDimension(place.at(1000, 0), place.at(0, 0),
          DimKind.aligned, g, 400.75, mmPage)!;
      expect(l.textAngle, 0.0);
      expect(l.textAngle.isNegative, isTrue,
          reason: 'premise: the world angle is -0.0');
      expect(math.atan2(g.b, g.a).isNegative, isFalse,
          reason: 'premise: the group\'s angle is +0.0');

      final rotation = payloadOf(doc, dimTextHandle(doc, dim)).scalars[1];
      expect(rotation, 0.0);
      expect(rotation.isNegative, isFalse,
          reason: 'the generated TEXT stores +0.0');

      final s1 = enc(doc);
      final back = reloadWithPage(s1);
      expect(enc(back), s1);
      expect(driftOf(back), isEmpty);
      final loaded = payloadOf(back, dimTextHandle(back, dim)).scalars[1];
      expect(loaded, 0.0);
      expect(loaded.isNegative, isFalse, reason: 'the loaded TEXT keeps +0.0');
    });
  }

  for (final place in [origin, corpusGroups]) {
    test(
        'DO5 a dimension keeps its six child handles across twenty '
        'regenerations, undo and redo, a zero value included, at $place', () {
      final plan = buildPlan(
          const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
          place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a, b] = plan.walls;
      // A/0/left (0, 100) → A/1/left, the inner corner (3900, 100),
      // horizontal: 3900.
      final dim = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
          kind: DimKind.horizontal, offset: 500.25, at: place.m);
      expect(dimText(doc, dim), '3900');
      final ks = kids(doc, dim);
      expect(ks, hasLength(6));

      final edits = <(String, DraftCommand Function())>[
        ('A longer', () => moveWall(plan, 0, const W(0, 0, 4200.25, 0, 200))),
        ('A back', () => moveWall(plan, 0, const W(0, 0, 4000, 0, 200))),
        (
          'B longer',
          () => moveWall(plan, 1, const W(4000, 0, 4000, 3500.75, 200))
        ),
        ('A thicker', () => thickness(doc, a, 300.5)),
        ('offset', () => setDim(doc, dim, (p) => p.copyWith(offset: 612.375))),
        (
          'offset < 0',
          () => setDim(doc, dim, (p) => p.copyWith(offset: -250.125))
        ),
        (
          'offset -0.0',
          () => setDim(doc, dim, (p) => p.copyWith(offset: -0.0))
        ),
        ('offset +0.0', () => setDim(doc, dim, (p) => p.copyWith(offset: 0.0))),
        (
          'vertical',
          () => setDim(doc, dim, (p) => p.copyWith(kind: DimKind.vertical))
        ),
        (
          'aligned',
          () => setDim(doc, dim, (p) => p.copyWith(kind: DimKind.aligned))
        ),
        (
          'horizontal',
          () => setDim(doc, dim, (p) => p.copyWith(kind: DimKind.horizontal))
        ),
        ('1:100 ft-in', () => setPage(doc, ftIn100)),
        ('1:50 mm', () => setPage(doc, (_) => mmPage)),
        // A turned north: its left face at x −100, so A/0/left (−100, 0) and
        // A/1/left (−100, 3000.5) differ along y only: horizontal 0.
        ('zero', () => moveWall(plan, 0, const W(0, 0, 0, 3000.5, 300.5))),
        ('restored', () => moveWall(plan, 0, const W(0, 0, 4000, 0, 300.5))),
        (
          'A left-justified',
          () => SetComponentCommand<WallParams>(
              a,
              doc.components
                  .get<WallParams>(a)!
                  .copyWith(justification: Justification.left))
        ),
        (
          'offset again',
          () => setDim(doc, dim, (p) => p.copyWith(offset: 1000.5))
        ),
        (
          'B moved',
          () => moveWall(plan, 1, const W(4000, 0, 4200.5, 3000, 200))
        ),
        ('B thinner', () => thickness(doc, b, 150.5)),
        (
          'vertical again',
          () => setDim(doc, dim, (p) => p.copyWith(kind: DimKind.vertical))
        ),
      ];
      expect(edits, hasLength(20));
      final texts = <String>[dimText(doc, dim)];
      final depth = doc.commands.undoDepth;
      for (final (what, edit) in edits) {
        final n = debugDimensionGenerates;
        doc.commands.execute(edit());
        expect(debugDimensionGenerates, greaterThan(n), reason: what);
        expect(kids(doc, dim), ks, reason: what);
        texts.add(dimText(doc, dim));
        if (what == 'zero') expect(dimText(doc, dim), '0', reason: what);
      }
      expect(doc.commands.undoDepth, depth + 20);
      expect(driftOf(doc), isEmpty);
      for (var i = edits.length - 1; i >= 0; i--) {
        doc.commands.undo();
        expect(kids(doc, dim), ks, reason: 'undo ${edits[i].$1}');
        expect(dimText(doc, dim), texts[i], reason: 'undo ${edits[i].$1}');
      }
      for (var i = 0; i < edits.length; i++) {
        doc.commands.redo();
        expect(kids(doc, dim), ks, reason: 'redo ${edits[i].$1}');
        expect(dimText(doc, dim), texts[i + 1], reason: 'redo ${edits[i].$1}');
      }
      expect(driftOf(doc), isEmpty);
    });

    test(
        'DD1 dimension.degenerate is one warning while the value is within '
        'wallJoin.linear of zero, and clears when it grows, at $place', () {
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      final g = place.m;
      // Horizontal A/0/left (0, 100) → A/1/left (4000, 100): 4000.
      final dim = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
          kind: DimKind.horizontal, offset: 500.5, at: g);
      expect(dimText(doc, dim), '4000');
      expect(dimDiagnostics(doc), isEmpty);

      // Made zero by a wall edit: A's end to (0, 3000.5), so A runs north,
      // its left face at x −100: A/0/left (−100, 0), A/1/left (−100,
      // 3000.5), which differ along y only. Horizontal: 0.
      doc.commands.execute(moveWall(plan, 0, const W(0, 0, 0, 3000.5, 200)));
      expect(dimText(doc, dim), '0');
      expect(kids(doc, dim), hasLength(6));
      expect(dimDiagnostics(doc), [degenerate(dim)]);
      expect(driftOf(doc), isEmpty);
      doc.commands.undo();
      expect(dimText(doc, dim), '4000');
      expect(dimDiagnostics(doc), isEmpty);

      // Made zero by a rotation: the dimension's group alone turned a further
      // 90° (decision 17: the axis turns with the group, the attached ends
      // stay). Its local x is now the plan's y, along which the pair (0,
      // 100)-(4000, 100) does not differ: 0.
      doc.commands.execute(TransformNodeCommand(
          dim, g.multiply(Transform2.rotation(math.pi / 2))));
      expect(dimText(doc, dim), '0');
      expect(kids(doc, dim), hasLength(6));
      expect(dimDiagnostics(doc), [degenerate(dim)]);
      expect(driftOf(doc), isEmpty);
      doc.commands.undo();
      expect(dimText(doc, dim), '4000');
      expect(dimDiagnostics(doc), isEmpty);
      doc.commands.redo();
      expect(dimDiagnostics(doc), [degenerate(dim)]);
      doc.commands.undo();

      // The bound, where the arithmetic is exact (the origin, a group at the
      // identity, fixed ends): a horizontal component of exactly 1e-6 =
      // wallJoin.linear is zero; 2e-6 is not.
      if (place == origin) {
        expect(wallJoin.linear, 1e-6);
        final at = addDimension(
            doc, const FixedEnd(0, 0), const FixedEnd(1e-6, 5000.5),
            kind: DimKind.horizontal, offset: 300.25);
        final over = addDimension(
            doc, const FixedEnd(0, 0), const FixedEnd(2e-6, 5000.5),
            kind: DimKind.horizontal, offset: 300.25);
        expect(dimText(doc, at), '0');
        expect(dimText(doc, over), '0');
        expect(dimDiagnostics(doc), [degenerate(at)]);
      }
    });

    test(
        'DD2 dimension.broken from a file (a live box as the wall, k = 2, '
        'an infinite point, an infinite offset) and from a command (a NaN '
        'point, a NaN offset): each an error, childless; a dead wall handle '
        'is parametric.dangling only, at $place', () {
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      final g = place.m;
      // A live box, a root-level group far from the wall.
      final box = doc.handleSeed.next();
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: box,
            parent: doc.rootHandle,
            transform: g.multiply(Transform2.translation(9000.5, 3000.25)),
            children: const [])),
        SetComponentCommand<BoxParams>(box, const BoxParams(1200, 800)),
      ], label: 'Add box'));

      // --- The file cases (Ruling 11-12): a file no program regenerated,
      // with markers where the file will carry 1e999 and -1e999.
      const pointMarker = 98765.4375, offsetMarker = 7777.125;
      late final Handle dBox, dK2, dPoint, dOffset, dDead, dKm1, ghost;
      final clean = staleFile(doc, (bare) {
        dBox = addDimension(bare, AttachedEnd(box, 0, l), AttachedEnd(a, 1, l),
            offset: 600.5, at: g);
        dK2 = addDimension(bare, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
            offset: 600.5, at: g);
        dPoint = addDimension(
            bare, AttachedEnd(a, 0, l), const FixedEnd(pointMarker, 250.25),
            offset: 600.5, at: g);
        dOffset = addDimension(bare, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
            offset: offsetMarker, at: g);
        // A handle the seed issued that names no object at all.
        ghost = bare.handleSeed.next();
        dDead = addDimension(
            bare, AttachedEnd(ghost, 0, l), AttachedEnd(a, 1, l),
            offset: 600.5, at: g);
        dKm1 = addDimension(bare, AttachedEnd(a, 1, r), AttachedEnd(a, 0, l),
            offset: 600.5, at: g);
      });
      // k = 2 by editing the JSON; then the two markers become 1e999 and
      // -1e999 in the text, which jsonDecode reads as ±Infinity.
      final json = jsonDecode(clean) as Map<String, Object?>;
      final dims =
          ((json['components']! as Map)[DimensionParams.componentTypeId]!
              as Map)[dK2.value.toString()]! as Map;
      (dims['a']! as Map)['k'] = 2;
      ((((json['components']! as Map)[DimensionParams.componentTypeId]!
          as Map)[dKm1.value.toString()]! as Map)['a']! as Map)['k'] = -1;
      var file = jsonEncode(json);
      for (final m in ['$pointMarker', '$offsetMarker']) {
        expect(file.split(m), hasLength(2), reason: 'the marker $m, once');
      }
      file = file
          .replaceFirst('$pointMarker', '1e999')
          .replaceFirst('$offsetMarker', '-1e999');
      final back = reloadWithPage(file);
      // The premises: the file carried what it says.
      DimensionParams paramsOf(Handle h) =>
          back.components.get<DimensionParams>(h)!;
      expect((paramsOf(dK2).a as AttachedEnd).k, 2);
      expect((paramsOf(dKm1).a as AttachedEnd).k, -1);
      expect((paramsOf(dPoint).b as FixedEnd).x, double.infinity);
      expect(paramsOf(dOffset).offset, double.negativeInfinity);
      expect(back.components.get<BoxParams>(box), isNotNull);
      expect(back.tree[ghost], isNull);

      final want = [
        Diagnostic(
          severity: DiagnosticSeverity.error,
          code: 'parametric.dangling',
          message: '${dDead.toHex()} references ${ghost.toHex()}, which is '
              'not a live parametric object',
          handles: [dDead, ghost],
        ),
        broken(dBox, 'end a names ${box.toHex()}, which is not a wall'),
        broken(dK2, 'end a has k = 2, not 0 or 1'),
        broken(dPoint, 'end b is a point that is not finite'),
        broken(dOffset, 'the offset is not finite'),
        broken(dKm1, 'end a has k = -1, not 0 or 1'),
      ];
      List<Diagnostic> reported(DraftDocument d) => [
            for (final x in diagnosticsOf(d))
              if (x.code.startsWith('dimension.') ||
                  x.code.startsWith('parametric.'))
                x,
          ];
      final all = [dBox, dK2, dPoint, dOffset, dDead, dKm1];
      expect(reported(back), want);
      expect(driftOf(back), isEmpty);
      // A page change regenerates every dimension (D3): each broken one, and
      // the dangling one, generates nothing.
      back.commands.execute(setPage(back, ftIn100));
      for (final h in all) {
        expect(kids(back, h), isEmpty, reason: h.toHex());
      }
      expect(reported(back), want);
      expect(driftOf(back), isEmpty);

      // --- The command cases: NaN, which no file can carry. A live
      // dimension, A/0/left (0, 100) → the fixed (2500.5, 1250.25), six
      // children, then its point, its offset, and both made NaN.
      final dim = addDimension(
          doc, AttachedEnd(a, 0, l), fixedAt(plan.at(2500.5, 1250.25), g),
          offset: 600.5, at: g);
      final ks = kids(doc, dim);
      expect(ks, hasLength(6));
      expect(dimDiagnostics(doc), isEmpty);
      for (final (what, change, why) in [
        (
          'NaN point',
          (DimensionParams p) =>
              p.copyWith(b: const FixedEnd(double.nan, 1250.25)),
          'end b is a point that is not finite'
        ),
        (
          'NaN offset',
          (DimensionParams p) => p.copyWith(offset: double.nan),
          'the offset is not finite'
        ),
        (
          'both',
          (DimensionParams p) => p.copyWith(
              b: const FixedEnd(1250.25, double.nan), offset: double.nan),
          'end b is a point that is not finite; the offset is not finite'
        ),
      ]) {
        doc.commands.execute(setDim(doc, dim, change));
        // Never == on a NaN-carrying value (a NaN coordinate equals
        // nothing): the fields are read instead.
        final p = doc.components.get<DimensionParams>(dim)!;
        expect(
            (p.b as FixedEnd).x.isNaN ||
                (p.b as FixedEnd).y.isNaN ||
                p.offset.isNaN,
            isTrue,
            reason: what);
        expect(kids(doc, dim), isEmpty, reason: what);
        expect(dimDiagnostics(doc), [broken(dim, why)], reason: what);
        expect(driftOf(doc), isEmpty, reason: what);
        doc.commands.undo();
        expect(kids(doc, dim), ks, reason: '$what undone');
        expect(dimDiagnostics(doc), isEmpty, reason: '$what undone');
      }

      // --- Unmeasurable: two finite fixed points whose world distance
      // overflows (|x| = 1e200, the difference 2e200, its square beyond a
      // double). No stored value is non-finite, but the aligned value is:
      // layoutDimension gives nothing, generate makes no child, and the
      // dimension is broken, never silently empty (D7).
      final wide = addDimension(
          doc, const FixedEnd(1e200, 0.5), const FixedEnd(-1e200, 0.5),
          offset: 500.25, at: g);
      final w0 = g.transformPoint(Vector2(1e200, 0.5));
      final w1 = g.transformPoint(Vector2(-1e200, 0.5));
      expect(w0.x.isFinite && w1.x.isFinite, isTrue);
      expect((w1 - w0).length.isFinite, isFalse);
      expect(
          layoutDimension(w0, w1, DimKind.aligned, g, 500.25, mmPage), isNull);
      expect(kids(doc, wide), isEmpty);
      expect([
        for (final x in diagnosticsOf(doc))
          if (x.handles.contains(wide)) x,
      ], [
        broken(wide, 'it cannot be laid out in finite numbers')
      ]);
      expect(driftOf(doc), isEmpty);
    });
  }

  for (final place in [origin, corpusAxis, corpusGroups]) {
    test(
        'DD3 a wall edit that overflows an aligned dimension\'s length makes '
        'it broken, not silently empty, while a horizontal one on the same '
        'points still draws and reads zero, at $place', () {
      // Task 7's review (I1): A (0, 0) → (4000, 0), 200; both dimensions
      // A/0/left (0, 100) → A/0/right (0, −100): aligned 200, horizontal 0
      // (the pair differs along y only), each in a group at the placement.
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      final al = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 0, r),
          offset: 300.25, at: place.m);
      final ho = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 0, r),
          kind: DimKind.horizontal, offset: 300.25, at: place.m);
      expect(dimText(doc, al), '200');
      expect(dimText(doc, ho), '0');
      final alKids = kids(doc, al), hoKids = kids(doc, ho);
      expect(alKids, hasLength(6));
      expect(hoKids, hasLength(6));
      expect(dimDiagnostics(doc), [degenerate(ho)]);

      // One command: the thickness to 1.5e154, which a wall accepts. The
      // faces lie ±7.5e153 off the centreline, so the pair is 1.5e154 apart,
      // whose square (2.25e308) is beyond a double's 1.8e308: the aligned
      // length overflows. The horizontal component is still (0, −1.5e154) ·
      // (1, 0) = 0, exactly, where the wall is unturned.
      final edit = thickness(doc, a, 1.5e154);
      if (place.deg != 0) {
        // Turned, 07's region check refuses the wall's own outline at this
        // thickness, and the edit rolls back whole: the premise the clause
        // needs is unreachable there, and nothing changes.
        final depth = doc.commands.undoDepth;
        expect(() => doc.commands.execute(edit), throwsArgumentError);
        expect(doc.commands.undoDepth, depth);
        expect(doc.components.get<WallParams>(a)!.thickness, 200);
        expect(kids(doc, al), alKids);
        expect(kids(doc, ho), hoKids);
        expect(dimDiagnostics(doc), [degenerate(ho)]);
        expect(driftOf(doc), isEmpty);
        return;
      }
      doc.commands.execute(edit);
      expect(kids(doc, al), isEmpty);
      expect(kids(doc, ho), hoKids);
      expect(dimText(doc, ho), '0');
      expect(dimDiagnostics(doc), [
        broken(al, 'it cannot be laid out in finite numbers'),
        degenerate(ho),
      ]);
      expect(driftOf(doc), isEmpty);

      doc.commands.undo();
      expect(kids(doc, al), alKids);
      expect(kids(doc, ho), hoKids);
      expect(dimText(doc, al), '200');
      expect(dimText(doc, ho), '0');
      expect(dimDiagnostics(doc), [degenerate(ho)]);
      expect(driftOf(doc), isEmpty);
    });
  }

  for (final place in [origin, corpusGroups]) {
    test(
        'DD4 a page so large that the text height overflows makes a 4000 mm '
        'dimension broken ("it cannot be laid out in finite numbers"); a NaN '
        'offset on a coincident pair is broken only, never also degenerate, '
        'at $place', () {
      // Task 7's re-review (m1, m2). A (0, 0) → (4000, 0), 200.
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      final g = place.m;

      // --- 1:1e308. A/0/left (0, 100) → A/1/left (4000, 100), aligned:
      // 4000, finite and small. The page's paper lengths are not: the text
      // height is 2.5 × 1e308 and the overshoot 2 × 1e308, both beyond a
      // double's 1.8e308. So the dimension cannot be laid out, though its
      // value can.
      final dim = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
          offset: 600.5, at: g);
      expect(dimText(doc, dim), '4000');
      final ks = kids(doc, dim);
      expect(ks, hasLength(6));
      expect(dimDiagnostics(doc), isEmpty);
      expect((kDimTextPaperMm * 1e308).isFinite, isFalse);
      expect((kDimExtOvershootPaperMm * 1e308).isFinite, isFalse);
      doc.commands
          .execute(setPage(doc, (p) => p.copyWith(scaleDenominator: 1e308)));
      expect(pageOf(doc).scaleDenominator, 1e308);
      expect(kids(doc, dim), isEmpty);
      expect(dimDiagnostics(doc),
          [broken(dim, 'it cannot be laid out in finite numbers')]);
      expect(driftOf(doc), isEmpty);
      doc.commands.undo();
      expect(kids(doc, dim), ks);
      expect(dimText(doc, dim), '4000');
      expect(dimDiagnostics(doc), isEmpty);
      expect(driftOf(doc), isEmpty);

      // --- A coincident aligned pair, the fixed plan point (1234.5,
      // −310.25) twice: it measures 0 and is degenerate. Its offset made
      // NaN: broken, and only broken. (The layout the diagnosis tries with a
      // zero offset still measures 0; that is not reported.)
      final zero = addDimension(doc, fixedAt(plan.at(1234.5, -310.25), g),
          fixedAt(plan.at(1234.5, -310.25), g),
          offset: 600.5, at: g);
      final zks = kids(doc, zero);
      expect(zks, hasLength(6));
      expect(dimText(doc, zero), '0');
      expect(dimDiagnostics(doc), [degenerate(zero)]);
      doc.commands
          .execute(setDim(doc, zero, (p) => p.copyWith(offset: double.nan)));
      expect(doc.components.get<DimensionParams>(zero)!.offset.isNaN, isTrue);
      expect(kids(doc, zero), isEmpty);
      expect(dimDiagnostics(doc), [broken(zero, 'the offset is not finite')]);
      expect(driftOf(doc), isEmpty);
      doc.commands.undo();
      expect(kids(doc, zero), zks);
      expect(dimDiagnostics(doc), [degenerate(zero)]);
      expect(driftOf(doc), isEmpty);
    });
  }

  for (final place in [origin, corpusAxis]) {
    test(
        'DD5 a value above kDimMaxValueMm (1e15 mm) is not laid out: an '
        'aligned dimension across a wall made 1e20 thick is broken and draws '
        'nothing, while a horizontal one on the same points still reads 0, '
        'at $place', () {
      // Task 7's re-review (m3). The bound's two sides, through the one
      // layout: 9.99e14 mm prints; 1.01e15 mm is not laid out.
      final o = Vector2(1234.5, -310.25);
      expect(kDimMaxValueMm, 1e15);
      expect(
          layoutDimension(o, o + Vector2(9.99e14, 0), DimKind.aligned,
                  Transform2.identity(), 600.5, mmPage)!
              .text,
          '999000000000000');
      expect(
          layoutDimension(o, o + Vector2(1.01e15, 0), DimKind.aligned,
              Transform2.identity(), 600.5, mmPage),
          isNull);
      // The premise the bound answers: the format cannot print 1e20 mm.
      expect(formatDimension(1e20, DisplayUnit.millimeters),
          isNot('100000000000000000000'));

      // A (0, 0) → (4000, 0), 200, unturned (07's region check refuses a
      // turned wall at an absurd thickness, DD3). Both dimensions A/0/left
      // (0, 100) → A/0/right (0, −100): aligned 200, horizontal 0.
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      final al = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 0, r),
          offset: 300.25, at: place.m);
      final ho = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 0, r),
          kind: DimKind.horizontal, offset: 300.25, at: place.m);
      expect(dimText(doc, al), '200');
      expect(dimText(doc, ho), '0');
      final alKids = kids(doc, al), hoKids = kids(doc, ho);
      expect(dimDiagnostics(doc), [degenerate(ho)]);

      // The thickness to 1e20 through the panel's command: the faces lie
      // ±5e19 off the centreline, so the aligned value is 1e20, finite and
      // above 1e15; the horizontal component is still exactly 0.
      doc.commands.execute(SetComponentCommand<WallParams>(
          a, doc.components.get<WallParams>(a)!.copyWith(thickness: 1e20)));
      expect(doc.components.get<WallParams>(a)!.thickness, 1e20);
      expect(kids(doc, al), isEmpty);
      expect(kids(doc, ho), hoKids);
      expect(dimText(doc, ho), '0');
      expect(dimDiagnostics(doc), [
        broken(al, 'it cannot be laid out in finite numbers'),
        degenerate(ho),
      ]);
      expect(driftOf(doc), isEmpty);

      doc.commands.undo();
      expect(kids(doc, al), alKids);
      expect(dimText(doc, al), '200');
      expect(dimDiagnostics(doc), [degenerate(ho)]);
      expect(driftOf(doc), isEmpty);
    });
  }
}
