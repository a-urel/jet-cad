import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

GeometryPayload payload(List<double> coords,
        [List<double> scalars = const []]) =>
    GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    );

void main() {
  const measurer = InsertionPointMeasurer();
  const style = TextStyleRecord(
      handle: Handle(7), name: 'STANDARD', fontFamily: 'Roboto');

  test('line bounds its endpoints', () {
    final box = entityBounds(
      kind: EntityKind.line,
      payload: payload([0, 0, 10, -5]),
      measurer: measurer,
      textStyle: style,
    );
    expect(box.min, Vector2(0, -5));
    expect(box.max, Vector2(10, 0));
  });

  test('circle bounds centre plus radius, not just the centre point', () {
    final box = entityBounds(
      kind: EntityKind.circle,
      payload: payload([100, 50], [10]),
      measurer: measurer,
      textStyle: style,
    );
    expect(box.min, Vector2(90, 40));
    expect(box.max, Vector2(110, 60));
  });

  test('arc includes an axis extreme inside its sweep', () {
    // The same trap arcBounds exists to avoid, reached through the entity path.
    final box = entityBounds(
      kind: EntityKind.arc,
      payload: payload([0, 0], [1, -math.pi / 4, math.pi / 2]),
      measurer: measurer,
      textStyle: style,
    );
    expect(box.max.x, closeTo(1, 1e-12));
  });

  test('polyline bounds every vertex', () {
    final box = entityBounds(
      kind: EntityKind.polyline,
      payload: payload([0, 0, 5, 12, -3, 4]),
      measurer: measurer,
      textStyle: style,
    );
    expect(box.min, Vector2(-3, 0));
    expect(box.max, Vector2(5, 12));
  });

  test('text uses the injected measurer, so the engine needs no font stack',
      () {
    final box = entityBounds(
      kind: EntityKind.text,
      payload: payload([7, 8], [2.5]),
      measurer: measurer,
      textStyle: style,
      text: 'Table 12',
    );
    // InsertionPointMeasurer returns TextMetrics.zero regardless of the
    // string, so height scale collapses to zero and the laid-out box
    // collapses to the insertion point; a real layout arrives with the
    // widget layer's measurer.
    expect(box.min, Vector2(7, 8));
    expect(box.max, Vector2(7, 8));
  });

  test(
      'text with a real measurer is bound by its laid-out glyph box, not '
      'the insertion point', () {
    final box = entityBounds(
      kind: EntityKind.text,
      payload: payload([7, 8], [200]),
      measurer: MetricModelMeasurer(),
      textStyle: style,
      text: 'WC',
    );
    // Hand-derived, not re-run through the production formulas: two-char
    // 'WC' under MetricModelMeasurer's defaults (advanceRatio 0.55, ascentRatio
    // 0.8, descentRatio 0.2, capRatio 0.7 of a 100px em) gives advanceWidth
    // 110, ascent 80, descent 20, capHeight 70. Left/baseline justification
    // (default textAttrs = 0) puts the anchor at the box's bottom-left, and
    // height 200 over capHeight 70 scales everything by 20/7.
    const scale = 200 / 70.0;
    expect(box.min.x, closeTo(7, 1e-9));
    expect(box.min.y, closeTo(8 - 20 * scale, 1e-9));
    expect(box.max.x, closeTo(7 + 110 * scale, 1e-9));
    expect(box.max.y, closeTo(8 + 80 * scale, 1e-9));
  });

  test("doc.extents is computed through the document's own measurer", () {
    // Every other text case in this file calls `entityBounds` with an
    // explicit measurer, which proves the *function* reads its argument and
    // proves nothing at all about the field. `DraftDocument._boxOfContainer`
    // passes `textMeasurer`, and Plan 3c Task 13's S21 mutant — replacing that
    // with a fresh default `MetricModelMeasurer()` — survived both full
    // suites. The spec's table calls this the measurer-dependence test and it
    // did not exist.
    //
    // Two measurers that differ only in their *ratios*, not in their kind: a
    // fixture whose second measurer is `InsertionPointMeasurer` would pass
    // against a mutant that hard-codes any real model, which is the same
    // degenerate-fixture trap the rest of this plan keeps walking into.
    DraftDocument docWith(TextMeasurer m) {
      final doc = DraftDocument.empty(measurer: m);
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: doc.handleSeed.next(),
          owner: doc.rootHandle,
          kind: EntityKind.text,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: kByLayer,
          transparency: kByLayer,
          flags: 0,
          text: 'A MUCH LONGER LABEL',
          textStyle: ReservedHandles.standardTextStyle,
          textAttrs: 0,
        ),
        payload: payload([7, 8], [200, 0, 0, 0]),
      ));
      return doc;
    }

    final narrow = docWith(MetricModelMeasurer(advanceRatio: 0.30));
    final wide = docWith(MetricModelMeasurer(advanceRatio: 0.90));
    final defaults = docWith(MetricModelMeasurer());

    double width(DraftDocument d) => d.extents.maxX - d.extents.minX;

    // Non-degenerate on both sides: both are real boxes, and the ratio
    // between them is the ratio between the two advance ratios, so this fails
    // on a measurer that is ignored *and* on one that is only partly read.
    expect(width(narrow), greaterThan(1.0));
    expect(width(wide), closeTo(width(narrow) * (0.90 / 0.30), 1e-9));

    // And neither equals the default model, which is what a mutant that
    // hard-codes `MetricModelMeasurer()` would produce for all three.
    expect(width(defaults), isNot(closeTo(width(narrow), 1e-6)));
    expect(width(defaults), isNot(closeTo(width(wide), 1e-6)));
  });
}
