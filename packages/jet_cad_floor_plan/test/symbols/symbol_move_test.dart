// Spec 09c D8: the wall-aware move's resolver, alone and through the
// Select tool. A free 3600 mm wall at 30 degrees in a turned group near
// (1e5, −7e4); a 1600 x 2000 bed tagged against-wall, its base point at its
// box's centre, 1000 mm from its back; the camera at 0.1 px/mm, so the
// 16 px capture is 160 mm: the back-centre within it, the insertion point
// far outside.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/parametric/opening_tool.dart'
    show isUsableHost;
import 'package:jet_cad_floor_plan/src/parametric/wall.dart' show Justification;
import 'package:jet_cad_floor_plan/src/parametric/wall_bands.dart';
import 'package:jet_cad_floor_plan/src/symbols/build_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/seating_component.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_box.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_component.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_move.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/symbols/wall_attach.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_attach_fixture.dart';

FurnitureSymbol rect(String key, double w, double d, List<String> tags) =>
    FurnitureSymbol(
      key: key,
      name: key,
      category: 'Tests',
      tags: tags,
      baseX: w / 2,
      baseY: d / 2,
      shapes: [
        PolylineShape([(0, 0), (w, 0), (w, d), (0, d)], closed: true),
      ],
    );

final SymbolLibrary library = SymbolLibrary.decode(Uint8List.fromList(
    utf8.encode(DraftDocumentCodec.encodeToString(buildSymbolLibrary([
  rect('test.bed', 1600, 2000, ['bed', 'against-wall']),
  rect('test.island', 1600, 2000, ['island']),
  rect('test.unit', 600, 600, ['kitchen', 'against-wall']),
])))));
SymbolEntry entry(String key) =>
    library.entries.singleWhere((e) => e.key == key);

final class Scene {
  Scene(
      {String key = 'test.bed',
      bool objectSnap = true,
      bool ready = true,
      bool mirrored = false,
      bool atFace = false}) {
    final s = freeWallScene(30, Justification.centre);
    doc = s.doc;
    SymbolComponent.register(doc.components);
    SeatingComponent.register(doc.components);
    bands = WallBands();
    faces = WallFaces(bands, accept: isUsableHost);
    run = faces.runsOf(doc).first;
    box = boxOfEntry(entry(key))!;
    // The attachment at the run's middle, then moved 800 mm into the room
    // and 300 along: a free bed whose back faces the wall.
    final mid = run.a + run.t * (run.length / 2);
    final att = faces.attach(doc, box, mid, 160,
        mirrored: mirrored, edgeCaptureWorld: 60)!;
    attachedAt = att.transform;
    off = atFace ? Vector2.zero() : run.m * 800 + run.t * 300;
    doc.commands.execute(placeSymbol(doc, entry(key), at: Vector2.zero()));
    instance = doc.tree.nodes
        .whereType<InstanceNode>()
        .reduce((a, b) => a.handle.value > b.handle.value ? a : b)
        .handle;
    doc.commands.execute(TransformNodeCommand(
        instance, Transform2.translation(off.x, off.y).multiply(attachedAt)));
    index = SpatialIndex(doc);
    selection = SelectionController(doc);
    camera = CameraController(ViewportTransform(
        worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, -9600, -6600)));
    snap = SnapSettings(objectSnap: objectSnap);
    ctx = ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap);
    resolver =
        SymbolMoveResolver(faces: faces, library: () => ready ? library : null);
  }

  late final DraftDocument doc;
  late final WallBands bands;
  late final WallFaces faces;
  late final FaceRun run;
  late final SymbolBox box;
  late final Transform2 attachedAt;
  late final Vector2 off;
  late final Handle instance;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final CameraController camera;
  late final SnapSettings snap;
  late final ToolContext ctx;
  late final SymbolMoveResolver resolver;

  Transform2 get transform => (doc.tree[instance]! as InstanceNode).transform;

  void dispose() {
    snap.dispose();
    selection.dispose();
    index.dispose();
    camera.dispose();
    bands.dispose();
  }
}

Scene scene(
    {String key = 'test.bed',
    bool objectSnap = true,
    bool ready = true,
    bool mirrored = false,
    bool atFace = false}) {
  final s = Scene(
      key: key,
      objectSnap: objectSnap,
      ready: ready,
      mirrored: mirrored,
      atFace: atFace);
  addTearDown(s.dispose);
  return s;
}

/// The plain move that brings the back-centre [into] mm from the face.
Transform2 backTo(Scene s, double into) {
  final v = s.run.m * into - s.off;
  return Transform2.translation(v.x, v.y);
}

double faceS(Scene s, Vector2 p) => (p - s.run.a).dot(s.run.m);

void main() {
  moreTests();
  test(
      'MV1 the back-centre brought near the face attaches: the back on the '
      'face, the marker its face point; the insertion point is far '
      '(M-09c-an)', () {
    final s = scene();
    final delta = backTo(s, 40);
    final insertion = delta
        .multiply(s.transform)
        .transformPoint(entry('test.bed').definition.basePoint);
    expect(faceS(s, insertion), greaterThan(160),
        reason: 'premise: the insertion point is outside the capture');
    final r = s.resolver.resolveMove(s.ctx, s.instance, delta)!;
    final back = r.transform.transformPoint(s.box.backCentre);
    expect(faceS(s, back), closeTo(0, 1e-6), reason: 'flush');
    expect((back - r.marker).length, lessThan(1e-6));
    for (final (got, want) in [
      (r.transform.a, s.attachedAt.a),
      (r.transform.b, s.attachedAt.b),
      (r.transform.c, s.attachedAt.c),
      (r.transform.d, s.attachedAt.d),
    ]) {
      expect(got, closeTo(want, 1e-12), reason: 'turned to the wall');
    }
  });

  test('MV2 far from the face, nothing', () {
    final s = scene();
    expect(s.resolver.resolveMove(s.ctx, s.instance, backTo(s, 400)), isNull);
  });

  test(
      'MV3 no attachment for an untagged symbol, with F3 off, before the '
      'library is ready, or for a scaled instance (M-09c-az, M-09c-am)', () {
    expect(
        scene(key: 'test.island').let(
            (s) => s.resolver.resolveMove(s.ctx, s.instance, backTo(s, 40))),
        isNull,
        reason: 'untagged');
    expect(
        scene(objectSnap: false).let(
            (s) => s.resolver.resolveMove(s.ctx, s.instance, backTo(s, 40))),
        isNull,
        reason: 'F3 off');
    expect(
        scene(ready: false).let(
            (s) => s.resolver.resolveMove(s.ctx, s.instance, backTo(s, 40))),
        isNull,
        reason: 'no library');
    final s = scene();
    // Scaled by 1.001 about its back-centre: still at 40 mm, not orthonormal.
    final c = s.transform.transformPoint(s.box.backCentre);
    s.doc.commands.execute(TransformNodeCommand(
        s.instance,
        Transform2.translation(c.x, c.y)
            .multiply(Transform2.scale(1.001, 1.001))
            .multiply(Transform2.translation(-c.x, -c.y))
            .multiply(s.transform)));
    expect(s.resolver.resolveMove(s.ctx, s.instance, backTo(s, 40)), isNull,
        reason: 'scaled');
  });

  test(
      'MV4 through the Select tool: a drag towards the wall commits the '
      'attachment verbatim, one step', () {
    final s = scene();
    final tool = SelectTool(moveResolver: s.resolver);
    addTearDown(tool.dispose);
    ToolPointerEvent ev(Vector2 world, {int buttons = kPrimaryButton}) {
      final p = s.camera.value.worldToScreen(world);
      return ToolPointerEvent(
        screen: ui.Offset(p.x, p.y),
        world: world,
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 60,
      );
    }

    // Press on the bed's left edge, halfway along: a point of the body.
    final press = s.transform.transformPoint(Vector2(0, 1000));
    final delta = backTo(s, 40);
    final release = delta.transformPoint(press);
    final depth = s.doc.commands.undoDepth;
    tool.onPointerDown(ev(press), s.ctx);
    tool.onPointerMove(ev((press + release) / 2), s.ctx);
    tool.onPointerMove(ev(release), s.ctx);
    tool.onPointerUp(ev(release, buttons: 0), s.ctx);
    expect(s.doc.commands.undoDepth, depth + 1);
    final back = s.transform.transformPoint(s.box.backCentre);
    expect(faceS(s, back), closeTo(0, 1e-6));
  });
}

void moreTests() {
  test('MV5 a mirrored symbol attaches mirrored (D4)', () {
    final s = scene(mirrored: true);
    expect(s.transform.determinant, lessThan(0), reason: 'premise');
    final r = s.resolver.resolveMove(s.ctx, s.instance, backTo(s, 40))!;
    expect(r.transform.determinant, lessThan(0));
    expect(faceS(s, r.transform.transformPoint(s.box.backCentre)),
        closeTo(0, 1e-6));
  });

  test(
      'MV6 a unit dragged along its face by nearly its width does not snap '
      'to where it was: its own instance is no neighbour (M-09c-ab)', () async {
    final s = scene(key: 'test.unit', atFace: true);
    // The bands hear the placement's change event; the faces rebuild.
    await Future<void>.delayed(Duration.zero);
    final u0 =
        (s.transform.transformPoint(s.box.backCentre) - s.run.a).dot(s.run.t);
    final v = s.run.t * 570;
    final r = s.resolver
        .resolveMove(s.ctx, s.instance, Transform2.translation(v.x, v.y))!;
    final u =
        (r.transform.transformPoint(s.box.backCentre) - s.run.a).dot(s.run.t);
    expect(u - u0, closeTo(570, 1e-6),
        reason: 'not snapped on to its own old right side');
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
