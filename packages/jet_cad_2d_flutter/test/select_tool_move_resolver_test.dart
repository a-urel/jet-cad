// Spec 09c D8: the Select tool's move resolver seam. A body drag of exactly
// one root-level node asks the resolver on every retarget (a pointer move, a
// camera change, the release); its answer is previewed as a delta and
// committed verbatim; without one, or when it answers null, the move is
// today's bit for bit. The instance is turned 30 degrees, off the origin, at
// a camera of 0.5 px/mm, y up.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/canvas_palette.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart'
    show kPickRadiusPixels;
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart'
    show kSnapMarkerPixels;
import 'package:jet_cad_2d_flutter/src/snap_marker.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/selection_fixture.dart';

final Transform2 kPlace = Transform2.translation(5000, -3000)
    .multiply(Transform2.rotation(30 * math.pi / 180));

/// What a resolver would answer: the node turned to 70 degrees at
/// (5200, -2900).
final Transform2 kExact = Transform2.translation(5200, -2900)
    .multiply(Transform2.rotation(70 * math.pi / 180));
final Vector2 kMarker = Vector2(5210.5, -2890.25);

final class RecordingResolver implements MoveResolver {
  RecordingResolver(this.answer);

  /// The answer for a call with the plain move's [delta].
  ({Transform2 transform, Vector2 marker})? Function(Transform2 delta) answer;
  final List<(Handle, Transform2)> calls = [];

  @override
  ({Transform2 transform, Vector2 marker})? resolveMove(
      ToolContext ctx, Handle node, Transform2 delta) {
    calls.add((node, delta));
    return answer(delta);
  }
}

final class Rig {
  Rig({MoveResolver? resolver, bool second = false}) {
    doc = DraftDocument.empty();
    final def = addDefinition(doc, 'Def');
    addEntity(doc, def, EntityKind.line, [0, 0, 100, 0], []);
    instance = addInstance(doc, def, kPlace);
    if (second) {
      other = addInstance(doc, def, Transform2.translation(5400, -3100));
    }
    index = SpatialIndex(doc);
    selection = SelectionController(doc);
    camera = cameraAt(0.5, const ui.Offset(-2200, -1300));
    ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    tool = SelectTool(moveResolver: resolver);
  }

  late final DraftDocument doc;
  late final Handle instance;
  Handle? other;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final CameraController camera;
  late final ToolContext ctx;
  late final SelectTool tool;

  void dispose() {
    tool.dispose();
    selection.dispose();
    index.dispose();
    camera.dispose();
  }

  /// The screen point of the instance's leaf at local x [x].
  ui.Offset body([double x = 50]) {
    final w = kPlace.transformPoint(Vector2(x, 0));
    final s = camera.value.worldToScreen(w);
    return ui.Offset(s.x, s.y);
  }

  ToolPointerEvent ev(ui.Offset s,
          {int buttons = kPrimaryButton, bool shift = false}) =>
      ToolPointerEvent(
        screen: s,
        world: camera.value.screenToWorld(Vector2(s.dx, s.dy)),
        pointer: 1,
        buttons: buttons,
        shift: shift,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
      );

  /// Press on the body, move through [path], release at its last point.
  void drag(List<ui.Offset> path, {bool shift = false}) {
    tool.onPointerDown(ev(body(), shift: shift), ctx);
    for (final p in path) {
      tool.onPointerMove(ev(p, shift: shift), ctx);
    }
    tool.onPointerUp(ev(path.last, buttons: 0, shift: shift), ctx);
  }

  Transform2 get transform => (doc.tree[instance]! as InstanceNode).transform;
}

Rig rig({MoveResolver? resolver, bool second = false}) {
  final r = Rig(resolver: resolver, second: second);
  addTearDown(r.dispose);
  return r;
}

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

void main() {
  test(
      'MR1 without a resolver, or with one that answers null, the move is '
      'today\'s: the same preview, command and bytes', () {
    final plain = rig();
    final nulled = rig(resolver: RecordingResolver((_) => null));
    final path = [
      plain.body() + const ui.Offset(30, 0),
      plain.body() + const ui.Offset(57, -23),
    ];
    List<double>? preview(Rig r) {
      r.tool.onPointerDown(r.ev(r.body()), r.ctx);
      r.tool.onPointerMove(r.ev(path[0]), r.ctx);
      r.tool.onPointerMove(r.ev(path[1]), r.ctx);
      final t = r.tool.selectionPreviewTransform;
      r.tool.onPointerUp(r.ev(path[1], buttons: 0), r.ctx);
      return t == null ? null : parts(t);
    }

    expect(preview(nulled), preview(plain));
    expect(parts(nulled.transform), parts(plain.transform));
    expect(DraftDocumentCodec.encodeToString(nulled.doc),
        DraftDocumentCodec.encodeToString(plain.doc));
    expect(nulled.doc.commands.undoDepth, plain.doc.commands.undoDepth);
  });

  test(
      'MR2 an answer is previewed as its delta and committed verbatim '
      '(M-09c-aa, M-09c-ad)', () {
    final resolver =
        RecordingResolver((_) => (transform: kExact, marker: kMarker.clone()));
    final r = rig(resolver: resolver);
    final before = r.transform;
    r.tool.onPointerDown(r.ev(r.body()), r.ctx);
    r.tool.onPointerMove(r.ev(r.body() + const ui.Offset(40, 10)), r.ctx);
    expect(resolver.calls.single.$1, r.instance);
    final preview = r.tool.selectionPreviewTransform!;
    final composed = preview.multiply(before);
    for (final (got, want) in [
      (composed.a, kExact.a),
      (composed.b, kExact.b),
      (composed.e, kExact.e),
      (composed.f, kExact.f),
    ]) {
      expect(got, closeTo(want, 1e-9), reason: 'the preview is T\'·T⁻¹');
    }
    r.tool.onPointerUp(
        r.ev(r.body() + const ui.Offset(40, 10), buttons: 0), r.ctx);
    expect(parts(r.transform), parts(kExact), reason: 'exactly T\'');
    expect(r.doc.commands.undoDepth, greaterThan(0));
  });

  test(
      'MR3 an attached drag released at its press point still turns the '
      'symbol; T\' equal to the transform commits nothing (M-09c-ae)', () {
    // The marker on the drag's base (the press snaps to the leaf's
    // midpoint): the plain move's "target == base" no-op must not apply.
    final base = kPlace.transformPoint(Vector2(50, 0));
    final r = rig(
        resolver: RecordingResolver(
            (_) => (transform: kExact, marker: base.clone())));
    final depth = r.doc.commands.undoDepth;
    r.drag([r.body() + const ui.Offset(30, 0), r.body()]);
    expect(parts(r.transform), parts(kExact));
    expect(r.doc.commands.undoDepth, depth + 1);

    final same = rig(
        resolver: RecordingResolver(
            (_) => (transform: kPlace, marker: kMarker.clone())));
    final sameDepth = same.doc.commands.undoDepth;
    same.drag([same.body() + const ui.Offset(30, 0)]);
    expect(same.doc.commands.undoDepth, sameDepth, reason: 'nothing changes');

    // The same linear part, another translation: a change, committed.
    final slid = Transform2(
        kPlace.a, kPlace.b, kPlace.c, kPlace.d, kPlace.e + 7.25, kPlace.f);
    final along = rig(
        resolver: RecordingResolver(
            (_) => (transform: slid, marker: kMarker.clone())));
    final alongDepth = along.doc.commands.undoDepth;
    along.drag([along.body() + const ui.Offset(30, 0)]);
    expect(along.doc.commands.undoDepth, alongDepth + 1,
        reason: 'the translation alone is a change');
    expect(parts(along.transform), parts(slid));
  });

  test(
      'MR4 a drag that attaches, then leaves the face, commits the plain '
      'move (M-09c-av)', () {
    var attach = true;
    final r = rig(
        resolver: RecordingResolver((_) =>
            attach ? (transform: kExact, marker: kMarker.clone()) : null));
    r.tool.onPointerDown(r.ev(r.body()), r.ctx);
    r.tool.onPointerMove(r.ev(r.body() + const ui.Offset(30, 0)), r.ctx);
    attach = false;
    final end = r.body() + const ui.Offset(60, -20);
    r.tool.onPointerMove(r.ev(end), r.ctx);
    r.tool.onPointerUp(r.ev(end, buttons: 0), r.ctx);
    // 60, -20 px at 0.5 px/mm: +120, +40 in world, y up.
    expect(r.transform.a, kPlace.a, reason: 'not turned');
    expect(r.transform.e, closeTo(kPlace.e + 120, 1e-6));
    expect(r.transform.f, closeTo(kPlace.f + 40, 1e-6));
  });

  test('MR5 a camera change mid-drag and the release ask again (M-09c-aw)', () {
    final resolver = RecordingResolver((_) => null);
    final r = rig(resolver: resolver);
    r.tool.onPointerDown(r.ev(r.body()), r.ctx);
    final p = r.body() + const ui.Offset(30, 0);
    r.tool.onPointerMove(r.ev(p), r.ctx);
    final n = resolver.calls.length;
    r.camera.panBy(const ui.Offset(15, -9));
    expect(resolver.calls.length, n + 1, reason: 'the camera');
    r.tool.onPointerUp(r.ev(p, buttons: 0), r.ctx);
    expect(resolver.calls.length, n + 2, reason: 'the release');
  });

  test(
      'MR6 never asked with Shift down, nor for a selection of two, nor '
      'for a Shift press that adds a second (M-09c-ao, -ax, -z)', () {
    final shifted =
        RecordingResolver((_) => (transform: kExact, marker: kMarker.clone()));
    final a = rig(resolver: shifted);
    a.drag([a.body() + const ui.Offset(30, 0)], shift: true);
    expect(shifted.calls, isEmpty);
    expect(a.transform.a, kPlace.a, reason: 'the plain move');

    final two =
        RecordingResolver((_) => (transform: kExact, marker: kMarker.clone()));
    // Two keys of which the drag captures one node (a fill is skipped):
    // the selection, not the capture, decides.
    final b = rig(resolver: two);
    b.selection.replace(
        [SelectionKey.root(b.instance), SelectionKey.root(fillOf(b.doc))]);
    expect(b.selection.keys, hasLength(2), reason: 'premise');
    b.drag([b.body() + const ui.Offset(30, 0)]);
    expect(two.calls, isEmpty);

    final added =
        RecordingResolver((_) => (transform: kExact, marker: kMarker.clone()));
    final c = rig(resolver: added);
    c.selection.replace([SelectionKey.root(fillOf(c.doc))]);
    // A Shift press on the unselected body adds it: two keys.
    c.tool.onPointerDown(c.ev(c.body(), shift: true), c.ctx);
    c.tool.onPointerMove(c.ev(c.body() + const ui.Offset(30, 0)), c.ctx);
    expect(added.calls, isEmpty);
    c.tool.cancel(c.ctx);
  });

  test('MR7 an attached drag marks its marker with the nearest glyph', () {
    final r = rig(
        resolver: RecordingResolver(
            (_) => (transform: kExact, marker: kMarker.clone())));
    r.tool.onPointerDown(r.ev(r.body()), r.ctx);
    r.tool.onPointerMove(r.ev(r.body() + const ui.Offset(30, 0)), r.ctx);
    final spy = LineSpy();
    r.tool.paintOverlay(
        spy, r.camera.value, const ui.Size(800, 600), PaperPalette.light);
    final m = r.camera.value.worldToScreen(kMarker);
    const h = kSnapMarkerPixels / 2;
    expect(
        spy.lines.any((l) =>
            (l.$1 - ui.Offset(m.x - h, m.y - h)).distance < 1e-6 &&
            (l.$2 - ui.Offset(m.x + h, m.y - h)).distance < 1e-6),
        isTrue,
        reason: 'the hourglass\'s top edge at the marker');
    r.tool.cancel(r.ctx);
  });

  test(
      'MR9 a centre-grip drag of the one selected node never asks: D8 is a '
      'body drag (M-09c-ao\'s grip half)', () {
    // A root group whose provider gives it one centre grip: the only way a
    // single selected node has a move grip (an instance has none).
    final doc = DraftDocument.empty();
    final group = addGroup(doc, doc.rootHandle, kPlace);
    addEntity(doc, group, EntityKind.line, [0, 0, 100, 0], []);
    final centre = kPlace.transformPoint(Vector2(50, 0));
    final index = SpatialIndex(doc);
    final selection = SelectionController(doc);
    final camera = cameraAt(0.5, const ui.Offset(-2200, -1300));
    final outlines = OutlineCache(doc, selection);
    final grips = GripCache(doc, selection, outlines,
        objects: _CentreGrip(group, centre));
    final resolver =
        RecordingResolver((_) => (transform: kExact, marker: kMarker.clone()));
    final tool = SelectTool(moveResolver: resolver);
    addTearDown(() {
      tool.dispose();
      grips.dispose();
      outlines.dispose();
      selection.dispose();
      index.dispose();
      camera.dispose();
    });
    final ctx = ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        grips: grips);
    selection.replace([SelectionKey.root(group)]);
    expect([for (final g in grips.grips) g.grip.role], [GripRole.move],
        reason: 'premise: the centre grip');
    ui.Offset screen(Vector2 w) {
      final s = camera.value.worldToScreen(w);
      return ui.Offset(s.x, s.y);
    }

    ToolPointerEvent ev(ui.Offset s, {int buttons = kPrimaryButton}) =>
        ToolPointerEvent(
          screen: s,
          world: camera.value.screenToWorld(Vector2(s.dx, s.dy)),
          pointer: 1,
          buttons: buttons,
          shift: false,
          control: false,
          meta: false,
          alt: false,
          pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
        );
    void drag(ui.Offset from) {
      final end = from + const ui.Offset(30, -10);
      tool.onPointerDown(ev(from), ctx);
      tool.onPointerMove(ev(from + const ui.Offset(15, -5)), ctx);
      tool.onPointerMove(ev(end), ctx);
      tool.onPointerUp(ev(end, buttons: 0), ctx);
    }

    Transform2 t() => (doc.tree[group]! as GroupNode).transform;
    drag(screen(centre));
    expect(resolver.calls, isEmpty, reason: 'a grip drag');
    expect(t().a, kPlace.a, reason: 'the plain move, not turned');
    expect(t().e, isNot(kPlace.e), reason: 'premise: it moved');

    // The same context's body drag asks: the grips do not block D8. The
    // provider's grip stays where it was, so the press is far from it.
    drag(screen(t().transformPoint(Vector2(95, 0))));
    expect(resolver.calls, isNotEmpty, reason: 'a body drag');
  });

  test('MR8 drawSnapMarker draws nearest as an hourglass of four lines', () {
    final spy = LineSpy();
    drawSnapMarker(spy, const ui.Offset(100, 50), SnapKind.nearest,
        grid: false, paint: ui.Paint());
    const h = kSnapMarkerPixels / 2;
    expect(spy.lines, [
      (const ui.Offset(100 - h, 50 - h), const ui.Offset(100 + h, 50 - h)),
      (const ui.Offset(100 + h, 50 - h), const ui.Offset(100 - h, 50 + h)),
      (const ui.Offset(100 - h, 50 + h), const ui.Offset(100 + h, 50 + h)),
      (const ui.Offset(100 + h, 50 + h), const ui.Offset(100 - h, 50 - h)),
    ]);
  });
}

/// A region's fill at the root, far from the instance: a key the move's
/// capture skips.
Handle fillOf(DraftDocument doc) {
  final command = AddRegionCommand.allocate(
    seed: doc.handleSeed,
    owner: doc.rootHandle,
    boundaryKind: EntityKind.polyline,
    boundaryPayload: GeometryPayload(
        coords: Float64List.fromList(
            [9000, 9000, 9100, 9000, 9100, 9100, 9000, 9100, 9000, 9000]),
        scalars: Float64List(0)),
    layer: ReservedHandles.layerZero,
    fillColor: const IndexedColor(3),
    boundaryColor: const IndexedColor(3),
  );
  doc.commands.execute(command);
  return command.fill.handle;
}

/// Records lines; every other call is ignored.
class LineSpy implements ui.Canvas {
  final List<(ui.Offset, ui.Offset)> lines = [];

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) =>
      lines.add((p1, p2));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// One centre grip, at [at], for [group]; no reshape.
final class _CentreGrip implements ObjectGripProvider {
  _CentreGrip(this.group, this.at);

  final Handle group;
  final Vector2 at;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle g) =>
      g == group ? [Grip(GripRole.move, 0, at.x, at.y)] : const [];

  @override
  DraftCommand? drag(DraftDocument d, Handle g, Grip grip, Vector2 world) =>
      null;

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle g, Grip grip, Vector2 world) =>
      const [];

  @override
  bool movable(DraftDocument d, Handle g) => true;
}
