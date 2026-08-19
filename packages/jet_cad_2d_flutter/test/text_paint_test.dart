import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/differential.dart';
import 'support/fixtures.dart';

/// Every field a wrong composition could quietly drop, set to something the
/// defaults are not.
///
/// The anchor is far from the origin, the height is the entity's own rather
/// than the style's, the rotation is not a right angle, the width factor and
/// the oblique angle are both per-entity overrides, and the justification is
/// neither left nor baseline. A fixture at the identity would pass under a
/// painter that ignored all six.
const double _kAnchorX = 300.0;
const double _kAnchorY = 20.0;
const double _kHeight = 8.0;
const double _kRotation = 0.4;
const double _kWidthFactor = 1.3;
const double _kOblique = 0.2;

final int _kAttrs = packTextAttrs(
  h: TextJustifyH.centre,
  v: TextJustifyV.top,
  overrideWidthFactor: true,
  overrideOblique: true,
);

/// A style that agrees with nothing: a fixed height that overrides the
/// entity's own, and a width factor and oblique angle the entity does *not*
/// override, so all three only reach the drawing through this record.
const TextStyleRecord _titleStyle = TextStyleRecord(
    handle: Handle(30),
    name: 'TITLE',
    fontFamily: 'Roboto',
    widthFactor: 2.4,
    obliqueAngle: 0.45,
    fixedHeight: 13.0);

Handle _addText(DraftDocument doc, Handle owner, Handle handle, String text,
    {double x = _kAnchorX,
    double y = _kAnchorY,
    Handle style = ReservedHandles.standardTextStyle,
    int? attrs}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const IndexedColor(3),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: text,
      textStyle: style,
      textAttrs: attrs ?? _kAttrs,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y]),
      scalars: Float64List.fromList(
          [_kHeight, _kRotation, _kWidthFactor, _kOblique]),
    ),
  ));
  return handle;
}

/// A document whose only entity is one label at the root.
DraftDocument _docWithOneLabel({String text = 'KITCHEN'}) {
  final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
  _addText(doc, doc.rootHandle, const Handle(900), text);
  return doc;
}

/// The same label, inside a definition placed by an instance whose transform
/// has [mirrored] handedness.
DraftDocument _docWithPlacedLabel({required bool mirrored}) {
  final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
  const definition = Handle(500);
  doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'plate',
      basePoint: Vector2.zero(),
      children: const []));
  _addText(doc, definition, const Handle(900), 'KITCHEN', x: 4, y: 3);
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(820),
    parent: doc.rootHandle,
    // Rotation and a non-unit scale in both cases, so the only difference
    // between the two documents is the sign of the x scale.
    transform: Transform2.translation(120, 45)
        .multiply(Transform2.rotation(0.37))
        .multiply(Transform2.scale(mirrored ? -1.7 : 1.7, 1.1)),
    definition: definition,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(5),
  )));
  return doc;
}

/// The rig corpus with real strings and real metrics.
///
/// `labelFraction` replaces the corpus's contentless floor texts with words
/// from its vocabulary one for one, and the measurer has to be a real one:
/// `InsertionPointMeasurer` returns the zero metrics, which collapses every
/// glyph box to a point and every text transform to a singular matrix — a
/// differential run over that corpus would compare nothing.
DraftDocument _textCorpus(int entityCount) => generateDocument(
      entityCount,
      definitionCount: 40,
      instanceCount: 400,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 10,
      layerCount: 4,
      byBlockFraction: 0.3,
      labelFraction: 0.08,
      attributedInstanceFraction: 0.1,
      measurer: MetricModelMeasurer(),
    );

/// Asserts the glyph box carried through [residual] is the entity's world box
/// carried through the camera — the same rectangle by two derivations.
///
/// This is what makes the painter and `entityBounds` agree in screen space.
/// Without it a painter that dropped the justification offset, the oblique
/// shear, the cap-height scale or the entity's own style would still emit
/// exactly one `TextOp` and every op-counting assertion would stay green.
void _expectResidualMatchesBounds(
  ({
    DraftPainter painter,
    RecordingDrawSink sink,
    ViewportTransform camera
  }) run,
  Transform2 residual, {
  required TextStyleRecord style,
  required int attrs,
  required String text,
}) {
  final doc = run.painter.document;
  final payload = doc.geometry.peek(doc.entities.geomIndexAt(0));
  final metrics = doc.textMeasurer.measure(text: text, style: style);
  final local =
      textLocalBounds(resolveTextAttributes(payload, attrs, style), metrics);
  final world = entityBounds(
    kind: EntityKind.text,
    payload: payload,
    measurer: doc.textMeasurer,
    textStyle: style,
    textAttrs: attrs,
    text: text,
  );

  Aabb2 corners(Aabb2 box, Transform2 by) {
    var out = Aabb2.empty();
    for (final p in [
      Vector2(box.minX, box.minY),
      Vector2(box.maxX, box.minY),
      Vector2(box.maxX, box.maxY),
      Vector2(box.minX, box.maxY),
    ]) {
      out = out.expandedToPoint(by.transformPoint(p));
    }
    return out;
  }

  final viaResidual = corners(local, residual);
  final viaCamera = corners(world, run.camera.worldToScreenMatrix);

  // Not a degenerate box: the whole comparison is vacuous if the metrics
  // collapsed to a point.
  expect(viaCamera.maxX - viaCamera.minX, greaterThan(1.0));
  expect(viaCamera.maxY - viaCamera.minY, greaterThan(1.0));
  expect(viaResidual.minX, closeTo(viaCamera.minX, kScreenTolerance));
  expect(viaResidual.minY, closeTo(viaCamera.minY, kScreenTolerance));
  expect(viaResidual.maxX, closeTo(viaCamera.maxX, kScreenTolerance));
  expect(viaResidual.maxY, closeTo(viaCamera.maxY, kScreenTolerance));
}

void main() {
  test('a text leaf draws one text op under its own composed residual', () {
    final doc = _docWithOneLabel();
    final run = paintRecorded(doc);

    final texts = run.sink.ops.whereType<TextOp>().toList();
    expect(texts.length, 1);
    expect(texts.single.text, 'KITCHEN');
    expect(texts.single.style, ReservedHandles.standardTextStyle);
    expect(run.painter.skippedTextCount, 0);
  });

  test('the composed residual lands the glyph box where the bounds say', () {
    // The painter and `entityBounds` are two derivations of one placement.
    // This is the assertion that makes them agree in screen space: the four
    // corners of `textLocalBounds` carried through the residual must be the
    // four corners of the entity's world box carried through the camera.
    // Without it a painter that dropped the justification offset, the oblique
    // shear or the cap-height scale would still emit exactly one `TextOp`.
    final doc = _docWithOneLabel();
    final run = paintRecorded(doc);
    _expectResidualMatchesBounds(
        run, run.sink.ops.whereType<BeginResidualOp>().last.residual,
        style: doc.textStyleOf(ReservedHandles.standardTextStyle),
        attrs: _kAttrs,
        text: 'KITCHEN');
  });

  test('an empty text entity draws nothing and is still counted', () {
    // Ruling 23's other half. The measurer now returns zero for the empty
    // string rather than -FLT_MAX, so the bounds are honest; the draw path
    // still has nothing to hand `Canvas` and must say so through the counter
    // rather than emitting an empty paragraph.
    final doc = _docWithOneLabel(text: '');
    final run = paintRecorded(doc);

    expect(run.sink.ops.whereType<TextOp>(), isEmpty);
    expect(run.painter.skippedTextCount, 1);
  });

  test('text inside a mirrored instance is drawn mirrored, not corrected', () {
    // v1 renders text faithfully mirrored. The sign of the residual's
    // determinant is the whole assertion, and it is taken against the
    // unmirrored twin rather than against a fixed sign: the camera flips y,
    // so an *unmirrored* residual is already left-handed and a bare
    // `lessThan(0)` would pass on the corrected drawing too.
    double detOf(bool mirrored) {
      final run = paintRecorded(_docWithPlacedLabel(mirrored: mirrored));
      final r = run.sink.ops.whereType<BeginResidualOp>().last.residual;
      expect(run.sink.ops.whereType<TextOp>().length, 1);
      return r.a * r.d - r.b * r.c;
    }

    final plain = detOf(false);
    final mirrored = detOf(true);
    expect(plain, lessThan(0));
    expect(mirrored, greaterThan(0));
  });

  test('the reference walk and the painter agree with text on', () {
    // The differential oracle over a corpus that actually contains text, at
    // both cameras: the working set, where culling decides most of the
    // answer, and the whole drawing, where it decides none of it.
    final doc = _textCorpus(2000);
    expectPainterSupersetOfReference(
        paintToRecording(doc, ViewportTransform.fit(doc.extents, kViewport)),
        referenceToRecording(
            doc, ViewportTransform.fit(doc.extents, kViewport)),
        kViewport);
    // The cropping camera is the one that exercises culling at all, and the
    // one whose edge the two walks read differently — see [slack].
    final cropped = cameraOverDocumentCentre(doc);
    expectPainterSupersetOfReference(paintToRecording(doc, cropped),
        referenceToRecording(doc, cropped), kViewport,
        edgeBandPx: 4.0);
  });

  test('a text entity is drawn through its own style, not through STANDARD',
      () {
    // Ruling 13's failure class, back in a new task: with every fixture on
    // STANDARD, `document.textStyleOf(entity.textStyle)` and a hard-coded
    // `textStyleOf(standardTextStyle)` are the same expression, and the
    // second passes the whole suite. This is the fixture that separates them.
    //
    // The three fields are chosen so each one has to travel: `fixedHeight`
    // overrides the entity's own height, and the width factor and oblique
    // angle are *not* overridden by the entity, so the style's values are the
    // only ones in play. Against STANDARD all three collapse to 1.0 / 0.0 /
    // "use the entity's height".
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    doc.tables.textStyles.add(_titleStyle);
    final attrs = packTextAttrs(h: TextJustifyH.right, v: TextJustifyV.bottom);
    _addText(doc, doc.rootHandle, const Handle(900), 'KITCHEN',
        style: _titleStyle.handle, attrs: attrs);
    final run = paintRecorded(doc);

    final op = run.sink.ops.whereType<TextOp>().single;
    // The handle reaches the sink, which is what resolves `fontFamily`.
    expect(op.style, _titleStyle.handle);

    final residual = run.sink.ops.whereType<BeginResidualOp>().last.residual;
    _expectResidualMatchesBounds(run, residual,
        style: _titleStyle, attrs: attrs, text: 'KITCHEN');

    // The oracle carries its own copy of this rule and no generated fixture
    // separates it there either — every label the corpus builds is on
    // STANDARD. A walk that resolved STANDARD here would compose a different
    // residual, and its `TextOp` would stop matching the painter's.
    expectPainterSupersetOfReference(
        run.sink.ops, referenceToRecording(doc, run.camera), kViewport);
  });

  test('the walk and the painter agree about a blank text entity', () {
    // The generated corpus cannot carry one: `labelFraction` *replaces* the
    // blank floor texts one for one rather than adding to them, so a corpus
    // with real strings has no blank left in it and the differential run
    // above cannot see this at all. Built by hand for that reason.
    //
    // Both sides must drop it. A walk that drew it would emit a `TextOp` the
    // painter never emits, which is the one direction the superset assertion
    // forbids — and the painter's own guard is asserted separately, so this
    // is the half that pins the *oracle's* copy of the rule.
    final doc = _docWithOneLabel(text: '');
    _addText(doc, doc.rootHandle, const Handle(901), 'STAIR', x: 340, y: 60);
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final reference = referenceToRecording(doc, camera);

    expect(
        reference.whereType<TextOp>().map((op) => op.text).toList(), ['STAIR']);
    expectPainterSupersetOfReference(
        paintToRecording(doc, camera), reference, kViewport);
  });

  test('the text corpus is not vacuous', () {
    // A superset assertion passes trivially against a reference that drew no
    // text at all, which is exactly what the previous shape of the walk did.
    final doc = _textCorpus(2000);
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final reference = referenceToRecording(doc, camera);
    final texts = reference.whereType<TextOp>().toList();
    expect(texts.length, greaterThan(20));
    expect(texts.map((op) => op.text).toSet().length, greaterThan(1));
  });
}
