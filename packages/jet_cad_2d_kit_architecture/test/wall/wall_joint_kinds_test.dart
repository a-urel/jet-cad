// 3a Task 12, R-P1: the joint-kind assertions of today's shell cases WT3
// and WT9 (jet_cad_floor_plan/test/wall_tool_test.dart:273-386, :499-524),
// whose `classify` is a kit internal the integration package cannot import.
// Each companion replays its case's chains through the Wall tool, at the
// points the shell resolves them to (a tick's end, exactly; a grid point of
// the case's 1:20 page, `snapToGrid`), with the case's settings; its
// assertions are the case's `classify` lines, unchanged. The shell halves
// (WT3, WT9) run in jet_cad_2d_integration with every other assertion.
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_bands.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

// The room of WR12, turned 23° about the far origin (wall_tool_test.dart:
// 20-27).
final Vector2 c0 = plan(0, 0), c1 = plan(4000, 300);
final Vector2 c2 = plan(3600, 3100), c3 = plan(-200, 2700);
final Vector2 s0 = plan(1300, 1900);

/// The shell cases' page: 1:20 near the far origin, grid at 10 mm.
final PageComponent page = PageComponent(
    scaleDenominator: 20,
    originX: ox - 2000,
    originY: oy - 2000,
    gridStepMm: 10);

/// The grid point the shell's click at [p] resolves to.
Vector2 grid(Vector2 p) => snapToGrid(p, 10, page);

/// The unit left normal of the line from [a] to [b].
Vector2 leftOf(Vector2 a, Vector2 b) {
  final d = (b - a).normalized();
  return Vector2(-d.y, d.x);
}

/// The Wall tool over [doc] with [settings], its own band cache, a unit
/// camera and [snap] (null: object snap on); one chain per [draw].
final class Chains {
  Chains(this.doc, {SnapSettings? snap}) {
    tool = WallTool(() => settings, bands);
    ctx = ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap);
    addTearDown(() {
      tool.dispose();
      bands.dispose();
      selection.dispose();
      camera.dispose();
      index.dispose();
    });
  }

  final DraftDocument doc;
  WallSettings settings = const WallSettings();
  late final WallBands bands = WallBands(liveOf(doc));
  late final SpatialIndex index = SpatialIndex(doc);
  late final CameraController camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  late final SelectionController selection = SelectionController(doc);
  late final WallTool tool;
  late final ToolContext ctx;

  void _press(Vector2 world) => tool.onPointerDown(
      ToolPointerEvent(
          screen: Offset.zero,
          world: world,
          pointer: 1,
          buttons: kPrimaryButton,
          shift: false,
          control: false,
          meta: false,
          alt: false,
          pickRadiusWorld: 1),
      ctx);

  /// One wall from [a] to [b], then Enter: the new wall.
  Handle draw(Vector2 a, Vector2 b) {
    _press(a);
    _press(b);
    tool.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.enter,
            logicalKey: LogicalKeyboardKey.enter,
            timeStamp: Duration.zero),
        ctx);
    return walls(doc).last;
  }
}

void main() {
  test(
      "WT3-k WT3's joint kinds: a click on a centreline body makes a T, one "
      'within a thickness of its end a node, one outside the band nothing', () {
    final doc = wallDoc();
    final k = Chains(doc);
    final h = k.draw(c0, c1);
    k.settings =
        const WallSettings(thickness: 115, justification: Justification.left);
    final foot = c0 + (c1 - c0) * 0.35;
    final side = (s0 - project(s0, c0, c1)).normalized();
    final s = k.draw(s0, grid(foot + side * 20));
    expect(classify(worldWallOf(doc, s), 1, [worldWallOf(doc, h)]), isA<Tee>());

    k.settings = const WallSettings();
    final nH = leftOf(c0, c1);
    final inSign = nH.dot(s0 - c0) > 0 ? 1.0 : -1.0;
    final t1 = k.draw(grid(plan(2300, 1000)),
        grid(c0 + (c1 - c0) * 0.6 + nH * (90 * inSign)));
    expect(classify(worldWallOf(doc, t1), 1, [worldWallOf(doc, h)]), isA<Tee>(),
        reason: t1.toHex());
    final t2 = k.draw(grid(plan(3100, -1300)),
        grid(c0 + (c1 - c0) * 0.8 - nH * (60 * inSign)));
    expect(classify(worldWallOf(doc, t2), 1, [worldWallOf(doc, h)]), isA<Tee>(),
        reason: t2.toHex());
    final len = c0.distanceTo(c1);
    final n = k.draw(
        grid(c0 + (c1 - c0) * ((len - 120) / len) + nH * (70 * inSign)),
        grid(plan(5200, 1100)));
    expect(classify(worldWallOf(doc, n), 0, [worldWallOf(doc, h)]),
        isA<NodeJoint>());

    k.settings =
        const WallSettings(thickness: 240, justification: Justification.left);
    final h2 = k.draw(c3, c2);
    final nH2 = leftOf(c3, c2);
    k.settings = const WallSettings();
    final t3 =
        k.draw(grid(plan(1500, 2200)), grid(c3 + (c2 - c3) * 0.4 + nH2 * 180));
    expect(
        classify(worldWallOf(doc, t3), 1, [worldWallOf(doc, h2)]), isA<Tee>(),
        reason: t3.toHex());
    final t4 =
        k.draw(grid(plan(2500, 2100)), grid(c3 + (c2 - c3) * 0.7 - nH2 * 150));
    expect(
        classify(worldWallOf(doc, t4), 1, [worldWallOf(doc, h2)]), isA<Free>());
  });

  test(
      "WT9-k WT9's joint kind: with object snap off, a click in a wall's "
      'band joins nothing', () {
    final doc = wallDoc();
    final h = Chains(doc).draw(c0, c1);
    final k = Chains(doc, snap: SnapSettings(objectSnap: false));
    final nH = leftOf(c0, c1);
    final inSign = nH.dot(s0 - c0) > 0 ? 1.0 : -1.0;
    final t = k.draw(grid(plan(2300, 1000)),
        grid(c0 + (c1 - c0) * 0.6 + nH * (90 * inSign)));
    expect(classify(worldWallOf(doc, t), 1, [worldWallOf(doc, h)]),
        isNot(isA<Tee>()));
  });
}
