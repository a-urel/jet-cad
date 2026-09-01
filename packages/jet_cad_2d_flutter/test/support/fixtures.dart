import 'dart:typed_data';
import 'dart:ui' show Canvas, PictureRecorder, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'triangle_rasterizer.dart';

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
  int lineweight = 25,
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
      lineweight: lineweight,
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
///
/// [lineweight] is 1/100 mm on paper and defaults to the `25` every entity
/// this file builds has always carried, so no existing fixture moves by a
/// pixel. A caller that needs a stroke wide enough to ink across a boundary
/// its centreline does not cross -- `bandCrossingGrid` is the one -- passes
/// its own.
Handle addLine(DraftDocument doc, Handle owner, Handle handle, double x0,
        double y0, double x1, double y1,
        {int transparency = 0, int lineweight = 25}) =>
    addEntity(doc, owner, handle, EntityKind.line, [x0, y0, x1, y1], const [],
        transparency: transparency, lineweight: lineweight);

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
/// Registers linetype [handle] named [name] with [dashes] under [doc].
///
/// [totalLength] is derived as the sum of `dashes`' absolute values, kept
/// *consistent* with `dashes` on purpose: `dasher.dart` deliberately never
/// reads the stored total (see its own comments), so this fixture must not be
/// the place that hides a disagreement between the two.
Handle _addShadedLinetype(
    DraftDocument doc, Handle handle, String name, List<double> dashes) {
  final total = dashes.fold<double>(0, (sum, d) => sum + d.abs());
  doc.tables.linetypes.add(LinetypeRecord(
    handle: handle,
    name: name,
    description: name,
    pattern: DashPattern(dashes: dashes, totalLength: total),
  ));
  return handle;
}

/// Adds an entity with an explicit [linetype] and [linetypeScale].
///
/// The shared [addEntity] above always resolves `ByLayer` at scale 1.0,
/// which cannot build a dashed fixture -- every dashed entity here needs its
/// own linetype handle and, for entity 913, its own scale.
Handle _addShadedEntity(
  DraftDocument doc,
  Handle owner,
  Handle handle,
  EntityKind kind,
  List<double> coords,
  List<double> scalars, {
  required Handle linetype,
  double linetypeScale = 1.0,
  int lineweight = 25,
}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: linetype,
      linetypeScale: linetypeScale,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: lineweight,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

/// The corpus for shaded dashes.
///
/// **Separate from [differentialFixture] on purpose, and the reason is not
/// tidiness.** `test/differential_test.dart` compares [DraftPainter] against
/// `reference_walk.dart`, and the reference walk does not dash at all -- it
/// emits raw `polyline` and `arc` ops. A dashed entity in
/// [differentialFixture] would make the painter emit spans and the reference
/// walk emit whole polylines, reddening this project's oldest correctness
/// gate over a difference that is not a defect. Task 3's own report carries
/// the transcript: a dashed probe long enough to actually span more than one
/// pattern element reddens "the painter draws a superset of the reference
/// walk, in order" and three tests downstream of it, for a reason that has
/// nothing to do with either walk being wrong. The cost of the split is that
/// every gate which should see dashes needs a dashed arm written for it
/// explicitly; Plan C's results note lists the gates that have one.
///
/// **Nothing here sits at the identity, the origin, or a uniform scale.**
/// Every entity lives in one definition placed by a single instance whose
/// transform carries a rotation and a distinct non-uniform scale --
/// `CLAUDE.md`'s named dominant failure mode is the degenerate fixture, and a
/// dashed run under an anisotropic placement is exactly the case Ruling C4
/// bounds.
///
/// Handles, so a test can name what it is looking at:
///
/// | handle | what |
/// |---|---|
/// | 900 | the `DASHED` linetype, `[12, -6]` -- one drawn element |
/// | 901 | the `DASHDOT` linetype, `[12, -3, 0.5, -3]` -- two drawn elements |
/// | 902 | the `ALLGAP` linetype, `[-4]` -- **no** drawn element |
/// | 910 | a five-vertex dashed polyline, three interior corners |
/// | 911 | a dashed circle -- a closed run, so the seam join is in play |
/// | 912 | a dashed arc under the non-uniform instance |
/// | 913 | a `DASHDOT` line, so `D == 2` has a witness |
/// | 914 | an `ALLGAP` line, so the collapse representative has a witness |
/// | 915 | a **solid** line crossing 910, so dash gaps have something behind them |
/// | 916 | a hairline dashed line (`lineweight: 1`), so `_coveredArgb` meets a dash |
/// | 917 | a **solid** three-point polyline -- the control for Ruling C3 |
///
/// [linetypeScale] multiplies entity 913's own `linetypeScale` field only, so
/// a test can vary one entity's dash rate without rebuilding the corpus.
DraftDocument shadedDashFixture({double linetypeScale = 1.0}) {
  final doc = DraftDocument.empty();

  // A multiplicand, not the identity -- it is folded into `_dashScale` at
  // three separate call sites in `draft_painter.dart`, and a fixture that
  // left it at 1.0 could not tell it from a dropped term.
  doc.header.globalLinetypeScale = 1.7;

  // --- linetypes -----------------------------------------------------------
  _addShadedLinetype(doc, const Handle(900), 'DASHED', const [12.0, -6.0]);
  _addShadedLinetype(
      doc, const Handle(901), 'DASHDOT', const [12.0, -3.0, 0.5, -3.0]);
  // All gap, no dash: nothing draws until the whole pattern collapses below
  // three screen pixels, at which point the reference walk's rule -- draw it
  // solid -- takes over. That collapse is a live case, not a degenerate one.
  _addShadedLinetype(doc, const Handle(902), 'ALLGAP', const [-4.0]);

  // --- the shaded corpus, all in one definition -----------------------------
  const defs = Handle(990);
  doc.tree.addDefinition(Definition(
      handle: defs,
      name: 'shadedDefs',
      basePoint: Vector2.zero(),
      children: const []));

  // 910: five-point polyline, three interior vertices. The turn at P1 is
  // 130 deg (interior 50 deg -- sharp, under 90); the turn at P2 is 3 deg
  // (interior 177 deg -- nearly straight, under 5). Ruling C3 says a dashed
  // run emits no joins; a fixture whose corners are all shallow cannot tell
  // a missing join from a collinear one. The turn at P3 (67 deg) is a third,
  // ordinary corner. Total path length 360 local units, so at the default
  // scale (DASHED's 18-unit cycle x globalLinetypeScale 1.7) the pattern
  // repeats about 11.8 times -- comfortably past four.
  _addShadedEntity(
    doc,
    defs,
    const Handle(910),
    EntityKind.polyline,
    const [0, 0, 90, 0, 32.15, 68.94, -29.23, 134.77, -113.8, 103.98],
    const [],
    linetype: const Handle(900),
  );

  // 911: a dashed circle -- a closed run, so the seam join is in play.
  // Circumference ~408 local units, several periods of DASHED.
  _addShadedEntity(
    doc,
    defs,
    const Handle(911),
    EntityKind.circle,
    const [400, -250],
    const [65],
    linetype: const Handle(900),
  );

  // 912: a dashed arc under the fixture's non-uniform instance. Arc length
  // 85 * 3.3 = 280.5 local units, several periods of DASHED. The running
  // phase per chord is `GeometryCollector`'s concern, not this fixture's --
  // this only has to give it enough chords to advance across.
  _addShadedEntity(
    doc,
    defs,
    const Handle(912),
    EntityKind.arc,
    const [-350, 300],
    const [85, 0.2, 3.3],
    linetype: const Handle(900),
  );

  // 913: a DASHDOT line, so D == 2 (two positive entries in the pattern) has
  // a witness. [linetypeScale] touches only this entity's own field.
  _addShadedEntity(
    doc,
    defs,
    const Handle(913),
    EntityKind.line,
    const [500, 300, 750, 300],
    const [],
    linetype: const Handle(901),
    linetypeScale: linetypeScale,
  );

  // 914: an ALLGAP line, so the collapse representative -- D == 0 -- has a
  // witness.
  _addShadedEntity(
    doc,
    defs,
    const Handle(914),
    EntityKind.line,
    const [500, -300, 650, -300],
    const [],
    linetype: const Handle(902),
  );

  // 915: a solid line crossing 910's second segment (P1-P2 passes through
  // local (39.64, 60) at t=0.87), so dash gaps have something behind them.
  _addShadedEntity(
    doc,
    defs,
    const Handle(915),
    EntityKind.line,
    const [-140, 60, 110, 60],
    const [],
    linetype: ReservedHandles.continuousLinetype,
  );

  // 916: a hairline dashed line -- lineweight 1, below one device pixel at
  // dpr 1, so it routes through `_coveredArgb`. Plan B's final review found
  // `lineweightScale` sitting at the identity in every instrument; a dashed
  // hairline is a second, independent place that factor has to be right.
  _addShadedEntity(
    doc,
    defs,
    const Handle(916),
    EntityKind.line,
    const [500, 500, 700, 500],
    const [],
    linetype: const Handle(900),
    lineweight: 1,
  );

  // 917: a SOLID three-point polyline, and it is the control for Ruling C3
  // rather than filler. Ruling C3 says a *dashed* run emits no joins; an
  // assertion that a corpus contains no dashed joins is worth nothing unless
  // the same corpus contains a solid run that *does* have one, or the rule
  // is indistinguishable from "this collector never emits joins". Every
  // other multi-segment entity here is dashed (910) and every solid one is a
  // two-point line with no interior vertex at all, so before this entity the
  // corpus could not tell those two readings apart -- found by Plan C Task
  // 10's own vacuity check, not by review.
  _addShadedEntity(
    doc,
    defs,
    const Handle(917),
    EntityKind.polyline,
    const [-500, -450, -380, -390, -300, -480],
    const [],
    linetype: ReservedHandles.continuousLinetype,
  );

  // The one placement: rotated (0.62 rad) and non-uniformly scaled (1.8 vs
  // 0.65 -- ratio far from 1), so nothing in this fixture sits at the
  // identity, the origin, or a uniform scale.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(991),
    parent: doc.rootHandle,
    transform: Transform2.translation(1000, -600)
        .multiply(Transform2.rotation(0.62))
        .multiply(Transform2.scale(1.8, 0.65)),
    definition: defs,
    layer: ReservedHandles.layerZero,
    color: const ByBlockColor(),
  )));

  return doc;
}

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

/// A corpus for Plan D: two fills, and strokes on both sides of one of them
/// in handle order.
///
/// **Every element is here because a named mutation needs it:**
///  - handle 900 is a thick stroke the fill covers, so a fill that failed to
///    draw leaves it visible;
///  - handle 901 is an opaque fill on a **hairline layer**, so a fill routed
///    through `_coveredArgb` fades (M-D5) where a correct one does not --
///    `lineweight: 1` on both the layer and the fill's own record resolves
///    to a device width of about 0.038 px at `kLogicalPixelsPerMm` and
///    `devicePixelRatio: 1.0`, comfortably under `kMinStrokeDevicePixels`
///    (1.0) and comfortably above zero, which is the one width
///    `_coveredArgb` leaves untouched -- see that function's own comment;
///  - handle 903 is a thick stroke of HIGHER handle crossing the fill, so it
///    is drawn *after* the fill and stays visible over it. Permuting the
///    buffer to draw all fills last hides it -- which is spec criterion 4,
///    and the reason this corpus exists at all. [strokeInkInsideFill] proves
///    the overlap is real rather than assumed;
///  - handle 904 is a translucent fill over a circle boundary, so the fan
///    path (`fillCircle`) is exercised and the colour comparison has a
///    non-opaque value to disagree about;
///  - the whole thing sits under instance 910, rotated and non-uniformly
///    scaled, far from the origin: an identity transform commutes and hides
///    composition-order defects (Plan 2's post-mortem).
///
/// | handle | what |
/// |---|---|
/// | 900 | a thick stroke **under** the fill (lower handle) |
/// | 901 | the fill entity, opaque, on a hairline layer |
/// | 902 | its boundary polygon |
/// | 903 | a thick stroke **over** the fill (higher handle), crossing it |
/// | 904 | the translucent fill entity |
/// | 905 | its boundary circle |
/// | 910 | the placement: rotated, non-uniformly scaled, off-origin |
///
/// **The polygon boundary's triangulation is not supplied by hand.**
/// `AddRegionCommand.apply` calls `triangulationFor` itself and, when the
/// result is non-empty, writes it into `doc.fills` before returning --
/// `packages/jet_cad_2d/lib/src/document/commands.dart`'s `apply` method,
/// verified directly rather than assumed. `fillFixture`'s own guard test
/// checks `doc.fills.trianglesFor(const Handle(902))` is non-null for
/// exactly this reason: if a future change to `AddRegionCommand` ever stopped
/// materialising it, this is where that would be caught.
DraftDocument fillFixture() {
  final doc = DraftDocument.empty();

  const content = Handle(890);
  doc.tree.addDefinition(Definition(
      handle: content,
      name: 'filled-room',
      basePoint: Vector2.zero(),
      children: const []));

  // 900: under the fill.
  addEntity(doc, content, const Handle(900), EntityKind.line, [1, 1, 19, 13],
      const [],
      lineweight: 120);

  // 901 / 902: the opaque fill and its boundary, on a hairline layer.
  //
  // `AddLayerCommand` does not exist in this package -- layers are added
  // directly to `doc.tables.layers`, the same way
  // `test/document/style_resolver_test.dart`'s own `addLayer` helper does
  // it. `LayerRecord` also requires `transparency`, which the brief's shape
  // omitted.
  const hairline = Handle(895);
  doc.tables.layers.add(const LayerRecord(
    handle: hairline,
    name: 'hairline',
    color: TrueColor(0x333333),
    linetype: ReservedHandles.continuousLinetype,
    lineweight: 1,
    transparency: 0,
  ));
  doc.commands.execute(AddRegionCommand(
    fill: const EntityRecord(
      handle: Handle(901),
      owner: content,
      kind: EntityKind.fill,
      layer: hairline,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(0x2E7D32),
      lineweight: 1,
      transparency: 0,
      flags: 0,
    ),
    boundary: const EntityRecord(
      handle: Handle(902),
      owner: content,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(0x000000),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList(<double>[
        2, 2, //
        17, 3, //
        16, 12, //
        3, 11, //
        2, 2, // closing duplicate
      ]),
      scalars: Float64List(0),
    ),
  ));

  // 903: over the fill, and crossing it.
  addEntity(doc, content, const Handle(903), EntityKind.line, [3, 12, 17, 2],
      const [],
      lineweight: 120);

  // 904 / 905: the translucent fill, over a circle boundary.
  doc.commands.execute(AddRegionCommand(
    fill: const EntityRecord(
      handle: Handle(904),
      owner: content,
      kind: EntityKind.fill,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(0xC62828),
      lineweight: kLineweightDefault,
      transparency: 128,
      flags: 0,
    ),
    boundary: const EntityRecord(
      handle: Handle(905),
      owner: content,
      kind: EntityKind.circle,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(0x000000),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList(<double>[24, 7]),
      scalars: Float64List.fromList(<double>[5.5]),
    ),
  ));

  // The placement: rotated, non-uniformly scaled, far from the origin.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(910),
    parent: doc.rootHandle,
    transform: Transform2.translation(37.5, 22.25)
        .multiply(Transform2.rotation(0.44))
        .multiply(Transform2.scale(1.8, 1.15)),
    definition: content,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(7),
  )));

  return doc;
}

/// The screen-space AABB of entity [handle], folding in [node]'s placement
/// and [camera]'s projection.
///
/// All four corners of the local box are transformed, not two: under
/// rotation the axis-aligned image of two opposite corners omits area a
/// rotated box actually covers -- the same reason
/// `ViewportTransform.visibleWorld` transforms all four of its own.
Aabb2 _screenBoxOf(DraftDocument doc, Handle handle, InstanceNode node,
    ViewportTransform camera) {
  final record = doc.entities.read(doc.entities.slotOf(handle)!);
  final payload = doc.geometry.read(record.geomIndex);
  final local = entityBounds(
    kind: record.kind,
    payload: payload,
    measurer: doc.textMeasurer,
    textStyle: doc.textStyleOf(record.textStyle),
  );
  var box = Aabb2.empty();
  for (final corner in [
    Vector2(local.minX, local.minY),
    Vector2(local.maxX, local.minY),
    Vector2(local.maxX, local.maxY),
    Vector2(local.minX, local.maxY),
  ]) {
    box = box.expandedToPoint(
        camera.worldToScreen(node.transform.transformPoint(corner)));
  }
  return box;
}

/// Paints [doc] through `VerticesDrawSink`, backed by a throwaway `Canvas`,
/// and returns the coverage rasterizer that watched the flush.
///
/// `VerticesDrawSink.flush` always submits to a real `canvas.drawVertices`,
/// so a `Canvas` backed by a `PictureRecorder` is required even though
/// nothing here ever reads the resulting picture --
/// `test/invariants/frame_accounting_test.dart` establishes the same pattern
/// for the same reason.
TriangleRasterizer _rasterizeFillFixture(
    DraftDocument doc, ViewportTransform camera) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final index = SpatialIndex(doc);
  final rasterizer =
      TriangleRasterizer(kViewport.width.toInt(), kViewport.height.toInt());
  final sink = VerticesDrawSink(
    pixelsPerPaperMm: kLogicalPixelsPerMm,
    canvas: canvas,
  )..observer = rasterizer.observe;
  DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc))
      .paint(sink, camera, kViewport);
  sink.flush();
  index.dispose();
  recorder.endRecording().dispose();
  return rasterizer;
}

/// Paints [fillFixture]'s corpus once as built and once with handle 903
/// removed, and returns how many screen pixels inside the opaque fill's own
/// box disagree between the two.
///
/// This is the corpus's own proof that 903 genuinely overlaps the fill
/// rather than merely sitting near it: a pixel inked identically both times
/// was never covered by 903 to begin with, and permuting the draw buffer
/// later could never move it -- the exact property Task 7's order gate
/// needs 903 to have. The camera is fixed **before** 903 is removed and
/// reused for both renders; refitting it afterwards would let the smaller
/// extents shift the camera and compare two different views of the drawing
/// instead of the same view with and without one stroke.
///
/// [doc] is mutated -- entity 903 is removed from it -- so a caller must not
/// paint or measure [doc] again afterwards.
int strokeInkInsideFill(DraftDocument doc) {
  final camera = ViewportTransform.fit(doc.extents, kViewport);
  final node = doc.tree[const Handle(910)]! as InstanceNode;
  final fillBox = _screenBoxOf(doc, const Handle(902), node, camera);

  final withStroke = _rasterizeFillFixture(doc, camera);
  doc.commands.execute(RemoveEntityCommand(const Handle(903)));
  final withoutStroke = _rasterizeFillFixture(doc, camera);

  final w = kViewport.width.toInt();
  final h = kViewport.height.toInt();
  final minX = fillBox.minX.floor().clamp(0, w - 1);
  final maxX = fillBox.maxX.ceil().clamp(0, w - 1);
  final minY = fillBox.minY.floor().clamp(0, h - 1);
  final maxY = fillBox.maxY.ceil().clamp(0, h - 1);

  var differing = 0;
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      if (withStroke.inked(x, y) != withoutStroke.inked(x, y)) differing++;
    }
  }
  return differing;
}
