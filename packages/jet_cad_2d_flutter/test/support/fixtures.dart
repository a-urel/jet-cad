import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const Size kViewport = Size(800, 600);

Handle addEntity(
  DraftDocument doc,
  Handle owner,
  Handle handle,
  EntityKind kind,
  List<double> coords,
  List<double> scalars, {
  DraftColor color = const ByLayerColor(),
  int transparency = 0,
}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: 25,
      transparency: transparency,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

/// The corpus every differential test runs on.
///
/// **No identity transform anywhere.** Plan 2's post-mortem records a
/// composition-order defect that four separate fixtures failed to catch because
/// their transforms were the identity, which commutes and hides ordering. Every
/// instance here carries a distinct non-uniform scale, a rotation and a
/// translation; one is mirrored; one is nested two levels deep; one leaf is
/// owned by a group node so the folded leaf transform is exercised.
///
/// [measurer] defaults to the zero-metric [InsertionPointMeasurer]: most
/// callers only ever paint this fixture through [paintToRecording] or
/// [referenceToRecording], never through a [DraftCanvas], and never touch
/// text. A caller that does build a [DraftCanvas] over this fixture must pass
/// a real [FlutterTextMeasurer] — the widget refuses anything else.
DraftDocument differentialFixture(
    {double originX = 0,
    TextMeasurer measurer = const InsertionPointMeasurer()}) {
  final doc = DraftDocument.empty(measurer: measurer);
  final ox = originX;
  final oy = originX == 0 ? 0.0 : 1200000.0;

  // --- definitions -------------------------------------------------------
  const inner = Handle(500), outer = Handle(501);
  doc.tree.addDefinition(Definition(
      handle: inner,
      name: 'inner',
      basePoint: Vector2.zero(),
      children: const []));
  doc.tree.addDefinition(Definition(
      handle: outer,
      name: 'outer',
      basePoint: Vector2.zero(),
      children: const []));

  addEntity(
      doc, inner, const Handle(700), EntityKind.line, [0, 0, 4, 1], const []);
  addEntity(
      doc, inner, const Handle(701), EntityKind.circle, [2, 2], const [1.5]);
  addEntity(doc, outer, const Handle(702), EntityKind.polyline,
      [0, 0, 3, 0, 3, 3, 0, 3], const [],
      color: const ByBlockColor());
  addEntity(doc, outer, const Handle(703), EntityKind.arc, [6, 1],
      const [2, 0.4, 1.9]);

  // The nested instance: two levels deep once `outer` is placed.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(520),
    parent: outer,
    transform: Transform2.translation(7.5, 2.25)
        .multiply(Transform2.rotation(0.53))
        .multiply(Transform2.scale(1.4, 2.1)),
    definition: inner,
    layer: ReservedHandles.layerZero,
    color: const ByBlockColor(),
  )));

  // --- root content ------------------------------------------------------
  addEntity(doc, doc.rootHandle, const Handle(800), EntityKind.line,
      [ox + 1, oy + 1, ox + 9, oy + 6], const []);

  // A group, so a root leaf carries a folded transform.
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: const Handle(810),
    parent: doc.rootHandle,
    transform: Transform2.translation(ox + 12, oy + 3)
        .multiply(Transform2.rotation(-0.37))
        .multiply(Transform2.scale(1.9, 1.15)),
    children: const [],
  )));
  addEntity(doc, const Handle(810), const Handle(811), EntityKind.line,
      [0, 0, 5, 2], const []);

  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(820),
    parent: doc.rootHandle,
    transform: Transform2.translation(ox + 20, oy + 8)
        .multiply(Transform2.rotation(0.21))
        .multiply(Transform2.scale(1.6, 1.1)),
    definition: outer,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(3),
  )));

  // Mirrored, and still conformal: anisotropyRatio 1. Its own polyline leaf
  // takes the screen-space path regardless (every line-like leaf does now);
  // the arc sharing this instance is what still exercises the residual path.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(830),
    parent: doc.rootHandle,
    transform: Transform2.translation(ox + 40, oy + 4)
        .multiply(Transform2.rotation(1.1))
        .multiply(Transform2.scale(-1.3, 1.3)),
    definition: outer,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(5),
  )));

  addEntity(doc, doc.rootHandle, const Handle(840), EntityKind.point,
      [ox + 30, oy + 15], const []);

  return doc;
}

/// Adds a line entity from ([x0], [y0]) to ([x1], [y1]), owned by [owner].
///
/// [transparency] defaults to `0`, this channel's identity, so every existing
/// caller is unaffected; a caller exercising translucency must pass a
/// non-zero value explicitly.
Handle addLine(DraftDocument doc, Handle owner, Handle handle, double x0,
        double y0, double x1, double y1, {int transparency = 0}) =>
    addEntity(doc, owner, handle, EntityKind.line, [x0, y0, x1, y1], const [],
        transparency: transparency);

/// Adds an empty block definition named [name].
Handle addDefinition(DraftDocument doc, Handle handle, String name) {
  doc.tree.addDefinition(Definition(
      handle: handle,
      name: name,
      basePoint: Vector2.zero(),
      children: const []));
  return handle;
}

/// Adds a group node at [transform], owned by [owner].
///
/// A group is not an instance, and the difference is load-bearing for anything
/// that watches the painter: a group's leaves are flattened into its
/// container's leaf list with a composed transform, so `DraftPainter` never
/// descends into the group as such and `debugOnVisit` never names it. A
/// fixture matrix without one cannot see that.
Handle addGroup(
    DraftDocument doc, Handle owner, Handle handle, Transform2 transform) {
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: handle,
    parent: owner,
    transform: transform,
    children: const [],
  )));
  return handle;
}

/// Places [definition] at [transform], owned by [owner].
Handle addInstance(DraftDocument doc, Handle owner, Handle handle,
    Handle definition, Transform2 transform) {
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: handle,
    parent: owner,
    transform: transform,
    definition: definition,
    layer: ReservedHandles.layerZero,
    color: const ByBlockColor(),
  )));
  return handle;
}

/// A guard so the rule cannot rot.
void assertNoIdentityTransforms(DraftDocument doc) {
  for (final handle in const [
    Handle(520),
    Handle(810),
    Handle(820),
    Handle(830),
  ]) {
    final node = doc.tree[handle];
    expect(node, isNotNull, reason: 'fixture node $handle went missing');
    expect(node!.transform.isIdentity, isFalse,
        reason: 'fixture rule: an identity transform hides ordering defects');
  }
}

/// The one spelling every differential test uses, so a signature change lands
/// in one place.
///
/// [minTextCapPixels] is steerable on **both** helpers, not just on the
/// oracle: a matched on/off control arm needs the two sides driven to the same
/// threshold on purpose, and a differential row that could only turn the
/// painter's cull off would be comparing two different rules.
List<DrawOp> paintToRecording(DraftDocument doc,
    [ViewportTransform? camera, double minTextCapPixels = kMinTextCapPixels]) {
  final index = SpatialIndex(doc);
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  DraftPainter(
          document: doc,
          index: index,
          resolver: DocumentStyleResolver(doc),
          minTextCapPixels: minTextCapPixels)
      .paint(sink, view, kViewport);
  index.dispose();
  return sink.ops;
}

List<DrawOp> referenceToRecording(DraftDocument doc,
    [ViewportTransform? camera, double minTextCapPixels = kMinTextCapPixels]) {
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  referenceWalk(doc, sink, view, kViewport, DocumentStyleResolver(doc),
      minTextCapPixels: minTextCapPixels);
  return sink.ops;
}

/// A camera tight around the nested instance, so most of the document culls
/// away and the comparison is about what survives.
ViewportTransform cameraOverNestedInstance(DraftDocument doc) {
  final node = doc.tree[const Handle(820)] as InstanceNode;
  final centre = node.transform.transformPoint(Vector2(8, 3));
  return ViewportTransform.fit(
      Aabb2(Vector2(centre.x - 6, centre.y - 5),
          Vector2(centre.x + 6, centre.y + 5)),
      kViewport);
}

/// [paintToRecording] plus the painter itself, for the tests that assert on a
/// counter as well as on the ops.
///
/// The two must stay one call: a test that painted twice — once for the ops,
/// once for the counter — would be reading a counter reset by the second run
/// and could not tell a stale value from a fresh one.
({DraftPainter painter, RecordingDrawSink sink, ViewportTransform camera})
    paintRecorded(DraftDocument doc, [ViewportTransform? camera]) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  final painter = DraftPainter(
      document: doc, index: index, resolver: DocumentStyleResolver(doc));
  painter.paint(sink, view, kViewport);
  return (painter: painter, sink: sink, camera: view);
}

/// A viewport-sized window over the middle of [doc], so most of it culls away.
///
/// The fit camera draws everything and therefore exercises no culling at all;
/// a differential run that only ever uses it compares two walks that both
/// kept every entity.
ViewportTransform cameraOverDocumentCentre(DraftDocument doc) {
  final e = doc.extents;
  final cx = (e.minX + e.maxX) / 2;
  final cy = (e.minY + e.maxY) / 2;
  final w = (e.maxX - e.minX) / 8;
  final h = (e.maxY - e.minY) / 8;
  return ViewportTransform.fit(
      Aabb2(Vector2(cx - w, cy - h), Vector2(cx + w, cy + h)), kViewport);
}

/// Adds one text entity, which [addEntity] cannot: text carries `text`,
/// `textStyle` and `textAttrs` on the record rather than in the payload.
Handle addText(
  DraftDocument doc,
  Handle owner,
  Handle handle,
  String text,
  double x,
  double y,
  double height,
) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: text,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(),
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y]),
      // height, rotation, widthFactor, obliqueAngle.
      scalars: Float64List.fromList([height, 0, 1, 0]),
    ),
  ));
  return handle;
}

/// A drawing whose text straddles [kMinTextCapPixels] at the fitted camera,
/// placed under a scaled and rotated instance well away from the origin.
///
/// Every property here is load-bearing. At the identity transform the painter's
/// `chain` and the walk's `chain` are the same matrix by accident rather than
/// by agreement, so a walk that read the painter's decision would pass. Away
/// from the origin the rebase term differs between the two. And three heights
/// straddling the threshold are what make the comparison about culling rather
/// than about drawing.
///
/// **The heights are measured, not derived.** The arithmetic gets close — the
/// root line spans 16,000 x 12,000 world units into [kViewport]'s 800 x 600 and
/// `ViewportTransform.fit` keeps a 0.95 margin, so the fit is 0.0475 px per
/// world unit; the instance scales by 0.35; so on-screen cap height is
/// `height * 0.016625` and 3.0 px would fall at a height of about 180.5 — but
/// the glyph boxes of the labels themselves could push `doc.extents` past that
/// root line and move the fit again, so the numbers below were printed rather
/// than trusted. Measured from `attrs.height * chain.scaleMagnitude` at this
/// document's own fitted camera, and recorded in Task 6's report:
///
///   * `doc.extents` is exactly the root line, (0, 0)-(16000, 12000): every
///     glyph box lands inside it, so the fit is the plain 0.0475 and the chain
///     scale is 0.016625.
///   * TINY, height 40, is **0.665 px** — 4.5x below the threshold. Culled.
///   * NEAR, height 170, is **2.826 px** — 5.8% below it. Culled.
///   * EDGE, height 191, is **3.175 px** — 5.8% above it. Drawn.
///   * LARGE, height 800, is **13.30 px** — 4.4x above it. Drawn.
///
/// So two of the four cull, which is what makes the differential row
/// non-vacuous. NEAR and EDGE sit near the boundary but not *on* it on
/// purpose: the painter and the walk each multiply their own `chain`, and a
/// height landing within a few ulps of 3.0 could have the two round to
/// opposite sides of `<` and go flaky. 0.175 px of slack is enormous next to
/// that and still small next to the threshold.
///
/// **Four labels, not three, and NEAR is the fourth.** With only TINY, EDGE
/// and LARGE, a walk that used `camera.scale` in place of
/// `chain.scaleMagnitude` — forgetting the instance's own 0.35 — survived:
/// 1.9, 9.07 and 38.0 px fall on the same sides of 3.0 as 0.665, 3.175 and
/// 13.30 do, so the mutant culled exactly the same label and the row stayed
/// green. NEAR is the height that separates them: 2.826 px through the full
/// chain, 8.075 px through the camera alone, so the mutant draws what the
/// painter culls and the comparison reddens. See Task 6's report for the
/// transcript.
///
/// If a change here stops them straddling 3.0, **the heights move, never
/// [kMinTextCapPixels]** — a fixture tuned by moving the threshold tests
/// nothing.
DraftDocument textLodDifferentialDocument(TextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);

  // The drawing's real extent, so the camera fit is decided by this and not by
  // whichever glyph box happens to be widest.
  addEntity(doc, doc.rootHandle, const Handle(890), EntityKind.line,
      [0, 0, 16000, 12000], const []);

  const labels = Handle(900);
  // Not `const`: `Vector2.zero()` is not a const constructor, which is why
  // `differentialFixture` spells it this way too.
  doc.tree.addDefinition(Definition(
      handle: labels,
      name: 'labels',
      basePoint: Vector2.zero(),
      children: const []));

  // Definition-local coordinates, so nothing here is at the world origin once
  // the instance places it.
  addText(doc, labels, const Handle(901), 'TINY', 0, 0, 40);
  addText(doc, labels, const Handle(902), 'NEAR', 0, 900, 170);
  addText(doc, labels, const Handle(903), 'EDGE', 0, 1600, 191);
  addText(doc, labels, const Handle(904), 'LARGE', 0, 2400, 800);

  // Rotated, uniformly scaled, and far from the origin. Uniform scale keeps
  // `scaleMagnitude` exactly 0.35 so the arithmetic above is checkable; the
  // rotation and the translation are what make the painter's and the walk's
  // routes to `chain` genuinely different rather than accidentally equal.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(910),
    parent: doc.rootHandle,
    transform: Transform2.translation(12000, 9000)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(0.35, 0.35)),
    definition: labels,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(3),
  )));

  return doc;
}
