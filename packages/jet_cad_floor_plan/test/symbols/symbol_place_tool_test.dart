// Spec 09b D6, F-5, F-6, F-12, F-14, F-16, plan 09b Tasks 6 and 7: the
// placement tool's pointer, snap, ghost, keys and permission check, driven
// directly with `ToolPointerEvent`s and `KeyEvent`s; spec 09c D12 (plan 09c-1
// Task 8): the ghost follows a camera change (a wheel zoom, a pan).
//
// Fixtures (plan P-3): real entries of the committed asset (every base point
// is off the origin); a document from `prepareDocument`; a camera at 0.05
// px/mm with y up, centred far from the origin, so the snap aperture is
// 10 / 0.05 = 200 mm, not 10 mm; a page whose grid (25 mm, origin off every
// round number) moves every raw point; one line whose start E is the object
// snap target. The ghost is painted with a rebase origin far from zero.
//
// Spec 09c D6 (plan 09c-1 Task 7): the wall attachment. A rig with walls
// adds them through the parametric system, each in its own rotated group
// near (1e5, −7e4) (`wall_attach_fixture.dart`, plan P-2), at 30° and
// −112.5°, non-centre justified; the pointer rests on either face; the
// symbol is the toilet (its back the cistern, its base point off its back
// edge) and the kitchen base units, mirrored and not, turned and not. The
// expected transforms are `attachToWall`'s over the rig's own runs (pinned
// by `wall_attach_test.dart`) and checked against hand arithmetic along the
// run (`q = a + u·t`, the rotation `t`).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:jet_cad_floor_plan/src/new_document.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_component.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_ghost.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_place_tool.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart' show installParametric;
import 'package:jet_cad_floor_plan/src/parametric/opening_tool.dart' show isUsableHost;
import 'package:jet_cad_floor_plan/src/parametric/wall.dart' show Justification;
import 'package:jet_cad_floor_plan/src/parametric/wall_bands.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_box.dart';
import 'package:jet_cad_floor_plan/src/symbols/wall_attach.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        MouseCursor,
        PhysicalKeyboardKey,
        SystemMouseCursors;
import 'package:flutter/widgets.dart'
    show
        Align,
        Alignment,
        Directionality,
        KeyEventResult,
        SizedBox,
        TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_attach_fixture.dart' show SceneWall, attachGroup, farAt;
import '../support/wall_fixture.dart' show addWall, polar;

final SymbolLibrary library = SymbolLibrary.decode(
    File('assets/library/furniture.jetlib').readAsBytesSync());

SymbolEntry entry(String key) =>
    library.entries.singleWhere((e) => e.key == key);

final SymbolEntry chair = entry('office.chair');
final SymbolEntry toilet = entry('bath.toilet');

/// The camera's pixels per mm: the aperture is 200 mm.
const double scale = 0.05;

/// The line's start: the object snap target, off the grid.
final Vector2 e0 = Vector2(73250.5, -41810.25);

/// The page grid: 25 mm from an origin off every round number.
const double gridStep = 25;
const double gridOriginX = 70000.3, gridOriginY = -40000.7;

Vector2 gridOf(Vector2 p) => Vector2(
    gridOriginX + ((p.x - gridOriginX) / gridStep).roundToDouble() * gridStep,
    gridOriginY + ((p.y - gridOriginY) / gridStep).roundToDouble() * gridStep);

/// Far from [e0] (more than the aperture) and from each other.
final Vector2 pA = Vector2(80123.4, -35211.7);
final Vector2 pMid = Vector2(80741.15, -36013.35);
final Vector2 pB = Vector2(81377.9, -36904.2);
final Vector2 pC = Vector2(76402.6, -45518.85);

/// The rebase origin the overlay paints with.
final Vector2 origin = Vector2(70000, -40000);

final class Rig {
  /// [objectSnap] non-null: a `SnapSettings` with it in the context (null:
  /// none, object snap on). [step] null: the page has no fixed grid step,
  /// so the drag uses the zoom-adaptive one.
  ///
  /// [walls] non-null (spec 09c D6): the parametric system is installed,
  /// each wall is added in its own [attachGroup] (handles ascending, in
  /// order, in [wallHandles]), and, with [faces], the tool gets a
  /// [WallFaces] over its own [WallBands] and the shell's host rule
  /// ([isUsableHost]).
  Rig(
      {bool page = true,
      bool? objectSnap,
      double? step = gridStep,
      List<SceneWall>? walls,
      bool faces = true}) {
    document = prepareDocument(const InsertionPointMeasurer());
    final ParametricSystem? parametric =
        walls == null ? null : installParametric(document);
    for (final (s, e, t, j) in walls ?? const <SceneWall>[]) {
      final h = document.handleSeed.next();
      document.commands
          .execute(addWall(document, h, s, e, t, j, at: attachGroup(h.value)));
      wallHandles.add(h);
    }
    if (page) {
      document.commands.execute(SetComponentCommand<PageComponent>(
          document.rootHandle,
          PageComponent(
              originX: gridOriginX, originY: gridOriginY, gridStepMm: step)));
    }
    document.commands.execute(addDrafted(
        document, EntityKind.line, linePayload(e0, e0 + Vector2(1200, 700)),
        layer: ReservedHandles.layerZero));
    document.commands.clearHistory();
    index = SpatialIndex(document);
    final linear = Transform2.scale(scale, -scale);
    final mid = linear.transformPoint(Vector2(76000, -41000));
    camera = CountingCamera(ViewportTransform(
        worldToScreenMatrix:
            Transform2.translation(400 - mid.x, 300 - mid.y).multiply(linear)));
    selection = SelectionController(document);
    pages = PageNotifier(document);
    snap = objectSnap == null ? null : SnapSettings(objectSnap: objectSnap);
    ctx = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: pages,
        snap: snap);
    armed = CountingNotifier(chair);
    final bands = walls != null && faces ? WallBands() : null;
    this.bands = bands;
    wallFaces = bands == null ? null : WallFaces(bands, accept: isUsableHost);
    tool = SymbolPlaceTool(armed, faces: wallFaces);
    tool.addListener(() => notifications.add(tool.isMidShape));
    addTearDown(() {
      if (!disposed) tool.dispose();
      bands?.dispose();
      parametric?.dispose();
      armed.dispose();
      pages.dispose();
      snap?.dispose();
      selection.dispose();
      camera.dispose();
      index.dispose();
    });
  }

  late final DraftDocument document;
  late final SpatialIndex index;
  late final CountingCamera camera;
  late final SelectionController selection;
  late final PageNotifier pages;
  late final SnapSettings? snap;
  late final ToolContext ctx;
  late final CountingNotifier armed;
  late final SymbolPlaceTool tool;
  late final WallBands? bands;
  late final WallFaces? wallFaces;
  final List<Handle> wallHandles = [];
  bool disposed = false;

  /// `isMidShape` at each notification.
  final List<bool> notifications = [];

  ToolPointerEvent at(Vector2 world, {int buttons = 0, int pointer = 7}) {
    final s = camera.value.worldToScreen(world);
    return ToolPointerEvent(
        screen: ui.Offset(s.x, s.y),
        world: world,
        pointer: pointer,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: kPickRadiusPixels / scale);
  }

  void hover(Vector2 w) => tool.onPointerMove(at(w), ctx);
  void down(Vector2 w, {int pointer = 7}) =>
      tool.onPointerDown(at(w, buttons: kPrimaryButton, pointer: pointer), ctx);
  void drag(Vector2 w, {int pointer = 7}) =>
      tool.onPointerMove(at(w, buttons: kPrimaryButton, pointer: pointer), ctx);
  void up(Vector2 w, {int pointer = 7}) =>
      tool.onPointerUp(at(w, pointer: pointer), ctx);

  List<InstanceNode> get instances =>
      document.tree.nodes.whereType<InstanceNode>().toList();

  /// Where an instance put its symbol's base point: its `at`.
  Vector2 placedAt(InstanceNode n) => n.transform
      .transformPoint(document.tree.definition(n.definition)!.basePoint);

  List<Handle> get symbolDefinitions => [
        for (final h in document.components.withComponent<SymbolComponent>())
          if (document.tree.definition(h) != null) h
      ];
}

/// The armed notifier, counting its listeners.
final class CountingNotifier extends ValueNotifier<SymbolEntry?> {
  CountingNotifier(super.value);

  int listeners = 0;

  @override
  void addListener(ui.VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(ui.VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

/// The camera, counting its listeners (spec 09c D12: the tool listens while
/// the ghost is shown, and only then).
final class CountingCamera extends CameraController {
  CountingCamera(super.initial);

  int listeners = 0;

  @override
  void addListener(ui.VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(ui.VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

/// A canvas that records every call.
final class RecordingCanvas implements ui.Canvas {
  final List<Invocation> calls = [];

  Iterable<Invocation> named(String name) =>
      calls.where((c) => c.memberName == Symbol(name));

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return null;
  }
}

/// [m] (column-major 4×4) applied to (x, y).
(double, double) apply(Float64List m, double x, double y) =>
    (m[0] * x + m[4] * y + m[12], m[1] * x + m[5] * y + m[13]);

void expectAt(Vector2 actual, Vector2 expected, String reason) {
  expect(actual.x, expected.x, reason: '$reason (x)');
  expect(actual.y, expected.y, reason: '$reason (y)');
}

/// A key: its logical and physical halves.
typedef Key2 = (LogicalKeyboardKey, PhysicalKeyboardKey);

const Key2 kR = (LogicalKeyboardKey.keyR, PhysicalKeyboardKey.keyR);
const Key2 kM = (LogicalKeyboardKey.keyM, PhysicalKeyboardKey.keyM);
const Key2 kW = (LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW);
const Key2 kZ = (LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ);
const Key2 kF = (LogicalKeyboardKey.keyF, PhysicalKeyboardKey.keyF);
const Key2 kF3 = (LogicalKeyboardKey.f3, PhysicalKeyboardKey.f3);
const Key2 kEsc = (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);
const Key2 kShift =
    (LogicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftLeft);
const Key2 kCtrl =
    (LogicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlLeft);
const Key2 kMeta = (LogicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaLeft);
const Key2 kAlt = (LogicalKeyboardKey.altLeft, PhysicalKeyboardKey.altLeft);

KeyEvent keyDown(Key2 k) =>
    KeyDownEvent(logicalKey: k.$1, physicalKey: k.$2, timeStamp: Duration.zero);

/// Runs [body] with [modifiers] held in `HardwareKeyboard.instance`, which
/// the tool reads (as `PlacementTool._hasModifier` does).
T holding<T>(List<Key2> modifiers, T Function() body) {
  final hw = HardwareKeyboard.instance;
  for (final k in modifiers) {
    hw.handleKeyEvent(keyDown(k));
  }
  try {
    return body();
  } finally {
    for (final k in modifiers) {
      hw.handleKeyEvent(KeyUpEvent(
          logicalKey: k.$1, physicalKey: k.$2, timeStamp: Duration.zero));
    }
  }
}

extension on Rig {
  KeyEventResult key(Key2 k, {List<Key2> held = const []}) =>
      holding(held, () => tool.onKey(keyDown(k), ctx));

  KeyEventResult repeat(Key2 k) => tool.onKey(
      KeyRepeatEvent(
          logicalKey: k.$1, physicalKey: k.$2, timeStamp: Duration.zero),
      ctx);

  /// One full placement: a press at [a], a drag, a release at [b].
  void place(Vector2 a, Vector2 b) {
    down(a);
    drag(pMid);
    up(b);
  }

  /// The newest instance's transform must be exactly the independently
  /// computed placement of the chair at the snapped [b].
  void expectPlaced(Vector2 b, int turns, bool mirrored, String reason) {
    final t = instances.last.transform;
    final want = placementTransform(
        at: gridOf(b),
        basePoint: chair.definition.basePoint,
        quarterTurns: turns,
        mirrored: mirrored);
    expect([
      t.a,
      t.b,
      t.c,
      t.d,
      t.e,
      t.f
    ], [
      want.a,
      want.b,
      want.c,
      want.d,
      want.e,
      want.f
    ], reason: reason);
  }
}

/// [t]'s linear part.
List<double> linear(Transform2 t) => [t.a, t.b, t.c, t.d];

// ---------------------------------------------------------------------------
// Spec 09c D6: the wall attachment's fixtures.

final SymbolEntry island = entry('kitchen.island');
final SymbolEntry base600 = entry('kitchen.base.600');

/// The rig's attach capture and edge capture: 16 / 0.05 = 320 mm and
/// 10 / 0.05 = 200 mm.
const double captureWorld = kWallAttachPixels / scale;
const double edgeWorld = kSnapAperturePixels / scale;

/// A free wall at [deg], 3600 long and 150 thick, justified [j], from
/// `farAt(1234.5, 678.25)`.
SceneWall attachWall(double deg, Justification j) {
  final s = farAt(1234.5, 678.25);
  return (s, polar(s, deg, 3600), 150, j);
}

/// P-2's two angles, each with a non-centre justification and the face the
/// pointer rests on.
const List<(double, Justification, FaceSide)> attachCases = [
  (30, Justification.left, FaceSide.left),
  (-112.5, Justification.right, FaceSide.right),
];

/// The point `a + t·u + m·s` of run [r].
Vector2 onRun(FaceRun r, double u, double s) =>
    Vector2(r.a.x + r.t.x * u + r.m.x * s, r.a.y + r.t.y * u + r.m.y * s);

List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// The box's four corners under [t].
List<Vector2> footprint(SymbolBox b, Transform2 t) => [
      for (final (x, y) in [
        (b.left, b.front),
        (b.right, b.front),
        (b.right, b.back),
        (b.left, b.back),
      ])
        t.transformPoint(Vector2(x, y)),
    ];

extension on Rig {
  /// The rig's one wall's run on [side].
  FaceRun runOn(FaceSide side) =>
      wallFaces!.runsOf(document).singleWhere((r) => r.side == side);

  /// [attachToWall] over the rig's runs with no neighbours, for [e] at the
  /// raw point [p] and the camera scale [k].
  WallAttachment? attachOf(SymbolEntry e, Vector2 p,
      {bool mirrored = false, double k = scale}) {
    final runs = wallFaces!.runsOf(document);
    return attachToWall(runs, boxOfEntry(e)!, p, kWallAttachPixels / k,
        mirrored: mirrored,
        neighbours: [for (final _ in runs) const <FaceNeighbour>[]],
        edgeCaptureWorld: kSnapAperturePixels / k);
  }

  /// The free placement of [e] at the tool's resolved point.
  Transform2 freeOf(SymbolEntry e, {int turns = 0, bool mirrored = false}) =>
      placementTransform(
          at: tool.ghostAt,
          basePoint: e.definition.basePoint,
          quarterTurns: turns,
          mirrored: mirrored);
}

void main() {
  // The tool reads HardwareKeyboard.instance (F-12, `_hasModifier`), which
  // needs a bound ServicesBinding even in plain unit tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the fixtures are not degenerate', () {
    for (final e in [chair, toilet]) {
      final b = e.definition.basePoint;
      expect(b.x != 0 || b.y != 0, isTrue, reason: '${e.key} base point');
    }
    for (final p in [pA, pMid, pB, pC]) {
      expect(gridOf(p) == p, isFalse, reason: 'the grid moves $p');
      expect(p.distanceTo(e0), greaterThan(kSnapAperturePixels / scale * 3));
    }
    expect(gridOf(pA) == gridOf(pB), isFalse);
    expect(gridOf(e0) == e0, isFalse, reason: 'E is off the grid');
    final rig = Rig();
    expect(rig.camera.value.scale, closeTo(scale, 1e-15));
  });

  group('pointer', () {
    test('a release places at the snapped release point, not the press', () {
      final rig = Rig();
      rig.hover(pA);
      rig.down(pA);
      expect(rig.instances, isEmpty, reason: 'nothing before the release');
      // The up arrives at a point no move reported.
      rig.up(pB);
      final placed = rig.instances.single;
      expectAt(rig.placedAt(placed), gridOf(pB), 'at the release');
      expect(rig.placedAt(placed) == gridOf(pA), isFalse);
      final t = placed.transform;
      expect([t.a, t.b, t.c, t.d], [1.0, 0.0, 0.0, 1.0]);
      expect(rig.document.commands.undoDepth, 1);
    });

    test('touch: a press, a move and a release with no hover place', () {
      final rig = Rig();
      expect(rig.tool.ghostVisible, isFalse, reason: 'no hover, no ghost');
      rig.down(pA, pointer: 21);
      expect(rig.tool.ghostVisible, isTrue, reason: 'shown at the press');
      expectAt(rig.tool.ghostAt, gridOf(pA), 'the ghost at the press');
      rig.drag(pMid, pointer: 21);
      expectAt(rig.tool.ghostAt, gridOf(pMid), 'the ghost follows');
      rig.drag(pB, pointer: 21);
      expect(rig.instances, isEmpty, reason: 'nothing before the release');
      rig.up(pB, pointer: 21);
      expectAt(rig.placedAt(rig.instances.single), gridOf(pB), 'placed');
    });

    test('isMidShape is true between press and release, and notifies', () {
      final rig = Rig();
      rig.hover(pA);
      expect(rig.tool.isMidShape, isFalse);
      rig.notifications.clear();
      rig.down(pA);
      expect(rig.tool.isMidShape, isTrue);
      expect(rig.notifications, [true]);
      rig.drag(pB);
      expect(rig.tool.isMidShape, isTrue);
      rig.up(pB);
      expect(rig.tool.isMidShape, isFalse);
      expect(rig.notifications.last, isFalse);
      expect(rig.instances, hasLength(1));
    });

    test(
        'a pointer cancel drops the press: its moves are ignored and its up '
        'places nothing; the next press places', () {
      final rig = Rig();
      rig.down(pA);
      rig.drag(pMid);
      rig.tool.cancel(rig.ctx);
      expect(rig.tool.isMidShape, isFalse);
      expect(rig.tool.ghostVisible, isFalse, reason: 'hidden on cancel');
      rig.drag(pB);
      expect(rig.tool.ghostVisible, isFalse,
          reason: 'the cancelled press moves no ghost');
      rig.up(pB);
      expect(rig.instances, isEmpty);
      expect(rig.document.commands.undoDepth, 0);
      rig.hover(pC);
      expect(rig.tool.ghostVisible, isTrue, reason: 'a hover shows it again');
      rig.down(pC, pointer: 8);
      rig.up(pC, pointer: 8);
      expectAt(rig.placedAt(rig.instances.single), gridOf(pC), 'next press');
    });

    test('a secondary press does nothing; idle (nothing armed) is inert', () {
      final rig = Rig();
      rig.tool.onPointerDown(rig.at(pA, buttons: kSecondaryButton), rig.ctx);
      expect(rig.tool.isMidShape, isFalse);
      rig.up(pA);
      expect(rig.instances, isEmpty);
      expect(rig.tool.cursor, SystemMouseCursors.precise);

      rig.armed.value = null;
      rig.notifications.clear();
      rig.hover(pA);
      rig.down(pA);
      rig.up(pA);
      expect(rig.notifications, isEmpty);
      expect(rig.instances, isEmpty);
      expect(rig.tool.ghostVisible, isFalse);
      expect(rig.tool.cursor, MouseCursor.defer);
      final canvas = RecordingCanvas();
      rig.tool.paintWorldOverlay(canvas, origin, scale);
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600));
      expect(canvas.calls, isEmpty);
    });

    test(
        'it stays armed; one undo step per placement; a second placement '
        'reuses the definition', () {
      final rig = Rig();
      rig.down(pA);
      rig.up(pA);
      rig.hover(pC);
      rig.down(pC);
      rig.up(pC);
      expect(rig.armed.value, same(chair));
      expect(rig.tool.ghostVisible, isTrue);
      final placed = rig.instances;
      expect(placed, hasLength(2));
      expectAt(rig.placedAt(placed[0]), gridOf(pA), 'first');
      expectAt(rig.placedAt(placed[1]), gridOf(pC), 'second');
      expect(rig.symbolDefinitions, hasLength(1));
      expect(placed[1].definition, placed[0].definition);
      expect(rig.selection.isEmpty, isTrue, reason: 'not selected');
      expect(rig.document.commands.undoDepth, 2);
      rig.document.commands.undo();
      expect(rig.instances.single.handle, placed[0].handle);
      expect(rig.symbolDefinitions, hasLength(1));
      rig.document.commands.undo();
      expect(rig.instances, isEmpty);
      expect(rig.symbolDefinitions, isEmpty);
    });

    test(
        're-arming notifies, drops the press and swaps the ghost path; '
        'the next placement is the new symbol', () {
      final rig = Rig();
      rig.down(pA);
      expect(rig.tool.ghostPath, same(ghostPathFor(chair)));
      rig.notifications.clear();
      rig.armed.value = toilet;
      expect(rig.notifications, [false]);
      expect(rig.tool.ghostPath, same(ghostPathFor(toilet)));
      rig.up(pA);
      expect(rig.instances, isEmpty, reason: 'the old press places nothing');
      rig.down(pB, pointer: 9);
      rig.up(pB, pointer: 9);
      final def = rig.instances.single.definition;
      expect(
          rig.document.components.get<SymbolComponent>(def)!.key, toilet.key);
    });

    test('dispose removes the armed listener', () {
      final rig = Rig();
      expect(rig.armed.listeners, 1);
      rig.tool.dispose();
      rig.disposed = true;
      expect(rig.armed.listeners, 0);
      expect(() => rig.armed.value = toilet, returnsNormally);
    });
  });

  group('snap', () {
    test('with object snap off (F3), a release near E lands on the grid', () {
      final rig = Rig(objectSnap: false);
      final near = e0 + Vector2(60, -45);
      rig.hover(near);
      rig.down(near);
      rig.up(near);
      final placed = rig.placedAt(rig.instances.single);
      expectAt(placed, gridOf(near), 'the grid point');
      expect(placed == e0, isFalse, reason: 'not the endpoint');
      expect(placed == near, isFalse, reason: 'not the raw point');
    });

    test(
        'with no fixed grid step, a release lands on the zoom-adaptive step '
        'of dragGridStepMm', () {
      final rig = Rig(step: null);
      final page = rig.pages.value!;
      expect(page.gridStepMm, isNull);
      final step = dragGridStepMm(page, scale)!;
      expect(step, isNot(gridStep), reason: 'the adaptive step is not 25');
      Vector2 adaptive(Vector2 p) => Vector2(
          gridOriginX + ((p.x - gridOriginX) / step).roundToDouble() * step,
          gridOriginY + ((p.y - gridOriginY) / step).roundToDouble() * step);
      final want = adaptive(pB);
      expect(want == pB, isFalse, reason: 'the grid moves the raw point');
      expect(want == gridOf(pB), isFalse, reason: 'not the 25 mm grid');
      rig.hover(pA);
      rig.down(pA);
      rig.up(pB);
      expectAt(rig.placedAt(rig.instances.single), want, 'the adaptive grid');
    });

    test(
        'a release within 10 px (not 10 mm) of an endpoint places on it; '
        'beyond the aperture, on the grid', () {
      final rig = Rig();
      // 75 mm from E: 3.75 px, inside the 200 mm aperture, outside 10 mm.
      final near = e0 + Vector2(60, -45);
      // 234 mm from E: 11.7 px, outside the aperture.
      final far = e0 + Vector2(-180, 150);
      // Hovered first: once a symbol is placed, its own leaves snap too.
      rig.hover(far);
      expectAt(rig.tool.ghostAt, gridOf(far), 'beyond the aperture: grid');
      rig.hover(near);
      expectAt(rig.tool.ghostAt, e0, 'the ghost snaps to E');
      rig.down(near);
      rig.up(near);
      final first = rig.placedAt(rig.instances.single);
      expectAt(first, e0, 'placed on E');
      expect(first == near, isFalse);
      expect(first == gridOf(near), isFalse);
    });

    test('the snap marker is drawn in screen space at the snapped point', () {
      final rig = Rig();
      rig.hover(e0 + Vector2(60, -45));
      final canvas = RecordingCanvas();
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600));
      final rect =
          canvas.named('drawRect').single.positionalArguments[0] as ui.Rect;
      final s = rig.camera.value.worldToScreen(e0);
      expect(rect.center.dx, closeTo(s.x, 1e-9));
      expect(rect.center.dy, closeTo(s.y, 1e-9));
    });
  });

  group('the ghost', () {
    test(
        'paints the cached path under translate(−origin) ∘ P, at the preview '
        'stroke, with a cross at the local base point', () {
      final rig = Rig();
      rig.hover(pB);
      final canvas = RecordingCanvas();
      rig.tool.paintWorldOverlay(canvas, origin, scale);
      expect(canvas.calls.map((c) => c.memberName), [
        #save,
        #transform,
        #drawPath,
        #drawLine,
        #drawLine,
        #restore,
      ]);
      final m = canvas.named('transform').single.positionalArguments[0]
          as Float64List;
      final b = chair.definition.basePoint;
      final want = gridOf(pB);
      final (x, y) = apply(m, b.x, b.y);
      expect(x, closeTo(want.x - origin.x, 1e-9));
      expect(y, closeTo(want.y - origin.y, 1e-9));
      final draw = canvas.named('drawPath').single.positionalArguments;
      expect(draw[0], same(ghostPathFor(chair)));
      final paint = draw[1] as ui.Paint;
      expect(paint.strokeWidth, closeTo(kPreviewStrokePixels / scale, 1e-12));
      expect(paint.color.toARGB32(), kPreviewColor.toARGB32());
      expect(paint.style, ui.PaintingStyle.stroke);
      const k = kGhostCrossPixels / scale;
      final lines = canvas.named('drawLine').toList();
      expect([lines[0].positionalArguments[0], lines[0].positionalArguments[1]],
          [ui.Offset(b.x - k, b.y), ui.Offset(b.x + k, b.y)]);
      expect([lines[1].positionalArguments[0], lines[1].positionalArguments[1]],
          [ui.Offset(b.x, b.y - k), ui.Offset(b.x, b.y + k)]);
    });

    test('a second paint reuses the path, the matrix storage and the paint',
        () {
      final rig = Rig();
      rig.hover(pA);
      final first = RecordingCanvas();
      rig.tool.paintWorldOverlay(first, origin, scale);
      rig.hover(pC);
      final second = RecordingCanvas();
      rig.tool.paintWorldOverlay(second, origin, scale);
      Object? arg(RecordingCanvas c, String name, int i) =>
          c.named(name).single.positionalArguments[i];
      expect(arg(second, 'drawPath', 0), same(arg(first, 'drawPath', 0)));
      expect(arg(second, 'drawPath', 1), same(arg(first, 'drawPath', 1)));
      expect(arg(second, 'transform', 0), same(arg(first, 'transform', 0)));
      expect(rig.tool.ghostPath, same(ghostPathFor(chair)));
      // The reused storage now holds the second placement.
      final m = arg(second, 'transform', 0) as Float64List;
      final b = chair.definition.basePoint;
      final (x, y) = apply(m, b.x, b.y);
      expect(x, closeTo(gridOf(pC).x - origin.x, 1e-9));
      expect(y, closeTo(gridOf(pC).y - origin.y, 1e-9));
    });

    test(
        'the placement is computed on events, never in a paint (spec D5, '
        'W-15): hover, R, M and a re-arm each set it; repeated paints pass '
        'the stored transform and compute nothing', () {
      final rig = Rig();
      Transform2 want(SymbolEntry e, Vector2 p, int turns, bool mirrored) =>
          placementTransform(
              at: gridOf(p),
              basePoint: e.definition.basePoint,
              quarterTurns: turns,
              mirrored: mirrored);
      void paints(int n) {
        for (var i = 0; i < n; i++) {
          rig.tool.paintWorldOverlay(RecordingCanvas(), origin, scale);
        }
      }

      final matrix = rig.tool.ghostMatrix;
      rig.hover(pB);
      expect(
          rig.tool.ghostPlacement!.toJson(), want(chair, pB, 0, false).toJson(),
          reason: 'set by the hover, before any paint');
      expect(matrix.computations, 0, reason: 'no paint yet');
      paints(3);
      expect(matrix.computations, 1);
      expect(identical(matrix.placement, rig.tool.ghostPlacement), isTrue,
          reason: 'the paint passed the stored transform');

      rig.key(kR);
      expect(
          rig.tool.ghostPlacement!.toJson(), want(chair, pB, 1, false).toJson(),
          reason: 'R with no pointer move');
      paints(2);
      expect(matrix.computations, 2);
      expect(identical(matrix.placement, rig.tool.ghostPlacement), isTrue);

      rig.key(kM);
      expect(
          rig.tool.ghostPlacement!.toJson(), want(chair, pB, 1, true).toJson(),
          reason: 'M with no pointer move');
      paints(2);
      expect(matrix.computations, 3);
      final m = rig.tool.ghostMatrix.storage;
      // q=1 mirrored: local +x to −y, local +y to −x.
      expect([m[0], m[1], m[4], m[5]], [0.0, -1.0, -1.0, 0.0]);

      rig.armed.value = toilet;
      expect(
          rig.tool.ghostPlacement!.toJson(), want(toilet, pB, 1, true).toJson(),
          reason: 're-armed: the new base point');
      paints(2);
      expect(matrix.computations, 4);
      final tb = toilet.definition.basePoint;
      final (x, y) = apply(rig.tool.ghostMatrix.forOrigin(origin), tb.x, tb.y);
      expect(x, closeTo(gridOf(pB).x - origin.x, 1e-9));
      expect(y, closeTo(gridOf(pB).y - origin.y, 1e-9));

      rig.hover(pC);
      expect(rig.tool.ghostPlacement!.toJson(),
          want(toilet, pC, 1, true).toJson());
      paints(1);
      expect(matrix.computations, 5);
    });

    test(
        'touch: the press and the release each set the placement (spec D5, '
        'F-6): with no hover the ghost is drawn at the press, and after a '
        'release away from the drag it sits at the release point', () {
      final rig = Rig();
      Transform2 want(Vector2 p) => placementTransform(
          at: gridOf(p),
          basePoint: chair.definition.basePoint,
          quarterTurns: 3,
          mirrored: true);
      List<double> bytes(Transform2? t) =>
          t == null ? const [] : [t.a, t.b, t.c, t.d, t.e, t.f];
      void paintOnce() =>
          rig.tool.paintWorldOverlay(RecordingCanvas(), origin, scale);
      final matrix = rig.tool.ghostMatrix;
      final b = chair.definition.basePoint;

      // Turned clockwise and mirrored, armed idle, before any pointer event.
      rig.key(kR, held: [kShift]);
      rig.key(kM);
      expect(rig.tool.ghostVisible, isFalse, reason: 'no hover, no ghost');

      rig.down(pA, pointer: 21);
      expect(bytes(rig.tool.ghostPlacement), bytes(want(pA)),
          reason: 'set by the press, with no hover');
      paintOnce();
      expect(matrix.computations, 1, reason: 'one paint computes once');
      expect(identical(matrix.placement, rig.tool.ghostPlacement), isTrue);
      var (x, y) = apply(matrix.storage, b.x, b.y);
      expect(x, closeTo(gridOf(pA).x - origin.x, 1e-9));
      expect(y, closeTo(gridOf(pA).y - origin.y, 1e-9));
      // q=3 mirrored: local +x to +y, local +y to +x.
      expect([matrix.storage[0], matrix.storage[1]], [0.0, 1.0]);
      expect([matrix.storage[4], matrix.storage[5]], [1.0, 0.0]);

      rig.drag(pMid, pointer: 21);
      expect(bytes(rig.tool.ghostPlacement), bytes(want(pMid)));
      paintOnce();
      expect(matrix.computations, 2);

      // The up arrives at a point no move reported.
      rig.up(pB, pointer: 21);
      expect(bytes(rig.tool.ghostPlacement), bytes(want(pB)),
          reason: 'set by the release, not left at the drag');
      expect(bytes(rig.instances.single.transform), bytes(want(pB)),
          reason: 'the ghost sits where the instance landed');
      paintOnce();
      expect(matrix.computations, 3);
      expect(identical(matrix.placement, rig.tool.ghostPlacement), isTrue);
      (x, y) = apply(matrix.storage, b.x, b.y);
      expect(x, closeTo(gridOf(pB).x - origin.x, 1e-9));
      expect(y, closeTo(gridOf(pB).y - origin.y, 1e-9));
    });

    test('hides on pointer exit and on cancel', () {
      final rig = Rig();
      rig.hover(pA);
      expect(rig.tool.ghostVisible, isTrue);
      rig.notifications.clear();
      rig.tool.onPointerExit(rig.ctx);
      expect(rig.tool.ghostVisible, isFalse);
      expect(rig.notifications, hasLength(1), reason: 'the overlay repaints');
      var canvas = RecordingCanvas();
      rig.tool.paintWorldOverlay(canvas, origin, scale);
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600));
      expect(canvas.calls, isEmpty);

      rig.hover(pB);
      rig.tool.cancel(rig.ctx);
      expect(rig.tool.ghostVisible, isFalse);
      canvas = RecordingCanvas();
      rig.tool.paintWorldOverlay(canvas, origin, scale);
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600));
      expect(canvas.calls, isEmpty);
    });
  });

  group('keys', () {
    test('the eight placements are distinct: each turn and mirror is seen', () {
      final b = chair.definition.basePoint;
      final seen = <String>{};
      for (final m in [false, true]) {
        for (var q = 0; q < 4; q++) {
          seen.add(linear(placementTransform(
                  at: gridOf(pB), basePoint: b, quarterTurns: q, mirrored: m))
              .join(','));
        }
      }
      expect(seen, hasLength(8));
    });

    test('R turns the next placement one quarter turn counter-clockwise', () {
      final rig = Rig();
      rig.hover(pA);
      rig.notifications.clear();
      expect(rig.key(kR), KeyEventResult.handled);
      expect(rig.tool.quarterTurns, 1);
      expect(rig.notifications, [false], reason: 'the ghost repaints');
      rig.place(pA, pB);
      rig.expectPlaced(pB, 1, false, 'one counter-clockwise quarter turn');
      // Counter-clockwise: the local x axis maps to world +y.
      expect(linear(rig.instances.single.transform), [0.0, 1.0, -1.0, 0.0]);
    });

    test('Shift+R turns it clockwise', () {
      final rig = Rig();
      expect(rig.key(kR, held: [kShift]), KeyEventResult.handled);
      expect(rig.tool.quarterTurns, 3);
      rig.place(pA, pB);
      rig.expectPlaced(pB, -1, false, 'one clockwise quarter turn');
      expect(linear(rig.instances.single.transform), [0.0, -1.0, 1.0, 0.0]);
    });

    test('M toggles the mirror', () {
      final rig = Rig();
      expect(rig.key(kM), KeyEventResult.handled);
      expect(rig.tool.mirrored, isTrue);
      rig.place(pA, pB);
      rig.expectPlaced(pB, 0, true, 'mirrored');
      expect(rig.key(kM), KeyEventResult.handled);
      expect(rig.tool.mirrored, isFalse);
      rig.place(pA, pC);
      rig.expectPlaced(pC, 0, false, 'M again: not mirrored');
    });

    test('keys compose (R, R, M) and work mid-press; the tool keeps them', () {
      final rig = Rig();
      rig.key(kR);
      rig.key(kR);
      rig.key(kM);
      rig.place(pA, pB);
      rig.expectPlaced(pB, 2, true, 'R, R, M');
      // Mid-press: a Shift+R between the press and the release.
      rig.down(pA);
      rig.notifications.clear();
      expect(rig.key(kR, held: [kShift]), KeyEventResult.handled);
      expect(rig.notifications, [true], reason: 'repaints mid-press');
      expect(rig.tool.isMidShape, isTrue, reason: 'the press is kept');
      rig.drag(pMid);
      rig.up(pC);
      rig.expectPlaced(pC, 1, true, 'R, R, M, Shift+R');
      // Mid-press R from the identity: the turn applies to this placement.
      rig.key(kM);
      rig.key(kR);
      rig.down(pA);
      rig.key(kR);
      rig.up(pB);
      expect(rig.instances, hasLength(3));
      rig.expectPlaced(pB, 3, false, 'R mid-press');
      expect(rig.document.commands.undoDepth, 3);
    });

    test('Ctrl, Meta or Alt with R or M is ignored and changes nothing', () {
      final rig = Rig();
      rig.hover(pA);
      rig.notifications.clear();
      for (final (k, held) in [
        (kR, [kCtrl]),
        (kR, [kMeta]),
        (kR, [kAlt]),
        (kR, [kCtrl, kShift]),
        (kM, [kCtrl]),
        (kM, [kMeta]),
        (kM, [kAlt]),
      ]) {
        expect(rig.key(k, held: held), KeyEventResult.ignored,
            reason: '${held.map((h) => h.$1.keyLabel)} + ${k.$1.keyLabel}');
      }
      expect(rig.tool.quarterTurns, 0);
      expect(rig.tool.mirrored, isFalse);
      expect(rig.notifications, isEmpty);
      rig.place(pA, pB);
      rig.expectPlaced(pB, 0, false, 'no turn, no mirror');
    });

    test('a key repeat is consumed with no effect', () {
      final rig = Rig();
      rig.key(kR);
      rig.notifications.clear();
      expect(rig.repeat(kR), KeyEventResult.handled);
      expect(rig.repeat(kR), KeyEventResult.handled);
      expect(rig.repeat(kM), KeyEventResult.handled);
      expect(rig.tool.quarterTurns, 1);
      expect(rig.tool.mirrored, isFalse);
      expect(rig.notifications, isEmpty);
      rig.place(pA, pB);
      rig.expectPlaced(pB, 1, false, 'one step for one key-down');
    });

    test('Esc mid-press cancels: the remaining moves and the up place nothing',
        () {
      final rig = Rig();
      rig.key(kR);
      final seed = rig.document.handleSeed.current;
      rig.down(pA);
      expect(rig.key(kEsc), KeyEventResult.handled);
      expect(rig.tool.isMidShape, isFalse);
      rig.drag(pMid);
      rig.drag(pC);
      expectAt(rig.tool.ghostAt, gridOf(pA), 'the moves are ignored');
      rig.up(pB);
      expect(rig.instances, isEmpty);
      expect(rig.document.handleSeed.current, seed);
      expect(rig.document.commands.undoDepth, 0);
      // The next press places, still turned.
      rig.place(pA, pC);
      rig.expectPlaced(pC, 1, false, 'the next press places');
    });

    test('mid-press F and F3 bubble; W, Z, Ctrl+Z and Ctrl+F are swallowed',
        () {
      final rig = Rig();
      rig.down(pA);
      expect(rig.key(kF), KeyEventResult.ignored);
      expect(rig.key(kF3), KeyEventResult.ignored);
      expect(rig.key(kW), KeyEventResult.handled);
      expect(rig.key(kZ), KeyEventResult.handled);
      expect(rig.key(kZ, held: [kCtrl]), KeyEventResult.handled);
      expect(rig.key(kZ, held: [kMeta]), KeyEventResult.handled);
      expect(rig.key(kF, held: [kCtrl]), KeyEventResult.handled);
      expect(rig.repeat(kW), KeyEventResult.handled);
      expect(rig.tool.isMidShape, isTrue, reason: 'still pressed');
      rig.up(pB);
      rig.expectPlaced(pB, 0, false, 'the press still places');
    });

    test('armed, not pressed: every key but R and M bubbles', () {
      final rig = Rig();
      rig.hover(pA);
      for (final k in [kW, kEsc, kF, kF3, kZ]) {
        expect(rig.key(k), KeyEventResult.ignored, reason: k.$1.keyLabel);
      }
      expect(rig.key(kZ, held: [kCtrl]), KeyEventResult.ignored);
      expect(rig.key(kZ, held: [kMeta, kShift]), KeyEventResult.ignored);
      expect(rig.tool.ghostVisible, isTrue, reason: 'Esc is the shell\'s');
      expect(
          rig.tool.onKey(
              KeyUpEvent(
                  logicalKey: kR.$1,
                  physicalKey: kR.$2,
                  timeStamp: Duration.zero),
              rig.ctx),
          KeyEventResult.ignored);
    });

    test('idle (nothing armed) every key bubbles and changes nothing', () {
      final rig = Rig();
      rig.armed.value = null;
      rig.notifications.clear();
      for (final k in [kR, kM, kW, kEsc]) {
        expect(rig.key(k), KeyEventResult.ignored, reason: k.$1.keyLabel);
      }
      expect(rig.tool.quarterTurns, 0);
      expect(rig.tool.mirrored, isFalse);
      expect(rig.notifications, isEmpty);
    });
  });

  group('permissions', () {
    const all = DraftPermissions.all;
    DraftPermissions denying(Capability c) => DraftPermissions(
        transform: true,
        components: c != Capability.components,
        geometry: c != Capability.geometry,
        structure: c != Capability.structure);

    for (final denied in [
      Capability.structure,
      Capability.geometry,
      Capability.components,
    ]) {
      test(
          'a denied ${denied.name} allocates nothing and throws nothing; '
          'lifted, the next placement happens', () {
        final rig = Rig();
        rig.key(kR);
        rig.key(kM);
        rig.document.commands.permissions = denying(denied);
        final seed = rig.document.handleSeed.current;
        rig.place(pA, pB);
        expect(rig.document.handleSeed.current, seed,
            reason: 'no handle allocated');
        expect(rig.instances, isEmpty);
        expect(rig.symbolDefinitions, isEmpty);
        expect(rig.document.commands.undoDepth, 0);
        expect(rig.tool.isMidShape, isFalse);
        rig.document.commands.permissions = all;
        rig.place(pA, pB);
        rig.expectPlaced(pB, 1, true, 'placed once allowed');
        expect(rig.document.commands.undoDepth, 1);
      });
    }
  });

  testWidgets(
      'SP-T1 a finger held on the canvas presses after the hold-back, and '
      'places on its lift (press mode, spec 14t R-1, review F-3)',
      (tester) async {
    final rig = Rig();
    final tools = ToolController(initial: rig.tool, context: rig.ctx);
    addTearDown(tools.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: 800,
                height: 600,
                child: InteractionLayer(
                    tools: tools, child: const SizedBox.expand())))));
    final s = rig.camera.value.worldToScreen(pA);
    final g = await tester.startGesture(ui.Offset(s.x, s.y),
        pointer: 41, kind: ui.PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 150));
    expect(rig.tool.isMidShape, isTrue, reason: 'pressed, not yet placed');
    expect(rig.tool.ghostVisible, isTrue);
    expect(rig.instances, isEmpty);
    await g.up();
    expect(rig.instances, hasLength(1));
  });

  group('the camera (spec 09c D12)', () {
    /// A zoom focus far from every pointer the tests rest at, so the world
    /// point under the pointer moves.
    const focus = ui.Offset(90, 520);

    Vector2 under(Rig rig, ui.Offset s) =>
        rig.camera.value.screenToWorld(Vector2(s.dx, s.dy));

    /// A zoom by [factor] about [focus] moves the ghost to the resolved world
    /// point now under the resting pointer [s], and repaints once.
    void expectFollows(Rig rig, ui.Offset s, double factor, String reason) {
      final before = rig.tool.ghostAt.clone();
      rig.notifications.clear();
      rig.camera.zoomAt(focus, factor);
      final w = under(rig, s);
      expect(w.distanceTo(e0),
          greaterThan(kSnapAperturePixels / rig.camera.value.scale),
          reason: '$reason: E is outside the aperture');
      expect(gridOf(w) == before, isFalse,
          reason: '$reason: the zoom moves the point under the pointer');
      expectAt(rig.tool.ghostAt, gridOf(w), reason);
      expect(rig.notifications, [rig.tool.isMidShape],
          reason: '$reason: one repaint');
    }

    /// A camera change does nothing: the ghost's point and placement stay,
    /// nothing is notified, nothing throws.
    void expectInert(Rig rig, String reason) {
      final at = rig.tool.ghostAt.clone();
      final placement = rig.tool.ghostPlacement;
      rig.notifications.clear();
      expect(() => rig.camera.zoomAt(focus, 1.7), returnsNormally,
          reason: reason);
      expect(() => rig.camera.panBy(const ui.Offset(-37.5, 61.25)),
          returnsNormally,
          reason: reason);
      expectAt(rig.tool.ghostAt, at, reason);
      expect(rig.tool.ghostPlacement, same(placement), reason: reason);
      expect(rig.notifications, isEmpty, reason: '$reason: no repaint');
    }

    test(
        'a zoom about another point moves the ghost and its placement to the '
        'world point now under the pointer; a pan too', () {
      final rig = Rig();
      rig.key(kR);
      rig.key(kM);
      rig.hover(pA);
      final s = rig.at(pA).screen;
      expectAt(rig.tool.ghostAt, gridOf(pA), 'the hover');
      rig.notifications.clear();
      rig.camera.zoomAt(focus, 1.7);
      expect(rig.camera.value.scale, closeTo(scale * 1.7, 1e-12));
      final w = under(rig, s);
      expect(w.distanceTo(pA), greaterThan(1000),
          reason: 'the zoom is not about the pointer');
      expect(w.distanceTo(e0),
          greaterThan(kSnapAperturePixels / rig.camera.value.scale),
          reason: 'E is outside the aperture');
      expectAt(rig.tool.ghostAt, gridOf(w), 'the zoom');
      expect(rig.notifications, [false], reason: 'one repaint');
      final want = placementTransform(
          at: gridOf(w),
          basePoint: chair.definition.basePoint,
          quarterTurns: 1,
          mirrored: true);
      final t = rig.tool.ghostPlacement!;
      expect([
        t.a,
        t.b,
        t.c,
        t.d,
        t.e,
        t.f
      ], [
        want.a,
        want.b,
        want.c,
        want.d,
        want.e,
        want.f
      ], reason: 'the placement follows, turned and mirrored');

      rig.notifications.clear();
      rig.camera.panBy(const ui.Offset(-37.5, 61.25));
      expectAt(rig.tool.ghostAt, gridOf(under(rig, s)), 'the pan');
      expect(rig.notifications, [false]);
      // Mid-press, the ghost follows as well; the release places where the
      // up lands.
      rig.down(pB);
      expectFollows(rig, rig.at(pB).screen, 0.6, 'mid-press');
      final p = under(rig, rig.at(pB).screen);
      rig.up(p);
      expectAt(rig.placedAt(rig.instances.single), gridOf(p), 'placed');
    });

    test(
        'one camera listener while the ghost is shown, however many events; '
        'none before the first pointer event', () {
      final rig = Rig();
      expect(rig.camera.listeners, 0, reason: 'armed, no pointer yet');
      rig.hover(pA);
      rig.hover(pB);
      rig.down(pB);
      rig.drag(pMid);
      rig.up(pC);
      rig.hover(pA);
      expect(rig.camera.listeners, 1);
      rig.armed.value = toilet;
      expect(rig.camera.listeners, 1, reason: 're-armed while shown');
      rig.hover(pB);
      expect(rig.camera.listeners, 1);
    });

    test(
        'after the ghost hides (pointer exit) a camera change does nothing; '
        'a hover listens again', () {
      final rig = Rig();
      rig.hover(pA);
      rig.tool.onPointerExit(rig.ctx);
      expect(rig.camera.listeners, 0);
      expectInert(rig, 'hidden');
      // A re-arm while hidden does not listen: the ghost stays hidden.
      rig.armed.value = null;
      rig.armed.value = toilet;
      expect(rig.camera.listeners, 0, reason: 're-armed while hidden');
      expectInert(rig, 're-armed while hidden');
      rig.hover(pB);
      expect(rig.camera.listeners, 1);
      expectFollows(rig, rig.at(pB).screen, 0.75, 'shown again');
    });

    test(
        'after cancel (a hover, or a press and Esc) a camera change does '
        'nothing', () {
      final rig = Rig();
      rig.hover(pA);
      rig.tool.cancel(rig.ctx);
      expect(rig.camera.listeners, 0);
      expectInert(rig, 'cancelled hover');
      rig.down(pB);
      expect(rig.camera.listeners, 1);
      expect(rig.key(kEsc), KeyEventResult.handled);
      expect(rig.camera.listeners, 0);
      expectInert(rig, 'Esc mid-press');
    });

    test(
        'after a disarm a camera change does nothing; a re-arm listens again '
        'and puts the ghost under the pointer for the camera now', () {
      final rig = Rig();
      rig.hover(pA);
      final s = rig.at(pA).screen;
      rig.armed.value = null;
      expect(rig.camera.listeners, 0);
      expect(rig.tool.ghostPlacement, isNull, reason: 'idle: no placement');
      expectInert(rig, 'disarmed');
      rig.armed.value = toilet;
      expect(rig.camera.listeners, 1);
      final w = under(rig, s);
      expect(gridOf(w) == gridOf(pA), isFalse,
          reason: 'the camera moved while disarmed');
      expectAt(rig.tool.ghostAt, gridOf(w), 're-armed');
      final t = rig.tool.ghostPlacement!;
      final want = placementTransform(
          at: gridOf(w),
          basePoint: toilet.definition.basePoint,
          quarterTurns: 0,
          mirrored: false);
      expect([t.e, t.f], [want.e, want.f], reason: 'the placement follows');
      expectFollows(rig, s, 0.75, 'after the re-arm');
    });

    test(
        'a release with no move before it: a zoom puts the ghost under the '
        'release point, not the press', () {
      final rig = Rig();
      final sB = rig.at(pB).screen;
      rig.down(pB);
      rig.up(pC);
      final s = rig.at(pC).screen;
      expectAt(rig.placedAt(rig.instances.single), gridOf(pC), 'placed');
      expectFollows(rig, s, 1.7, 'under the release point');
      expect(gridOf(under(rig, sB)) == rig.tool.ghostAt, isFalse,
          reason: 'not under the press point');
    });

    test(
        'a re-arm from one entry to another while the ghost is shown '
        're-resolves it under the pointer: a snap change since the last '
        'event shows', () {
      final rig = Rig(objectSnap: true);
      // 75 mm from E: 3.75 px, inside the 200 mm aperture.
      final near = e0 + Vector2(60, -45);
      rig.key(kR);
      rig.hover(near);
      expectAt(rig.tool.ghostAt, e0, 'the hover snaps to E');
      // The fixture: the tool does not listen to F3, so only the re-arm can
      // move the ghost off E.
      rig.snap!.toggleObjectSnap();
      expectAt(rig.tool.ghostAt, e0, 'F3 alone moves nothing');
      rig.notifications.clear();
      rig.armed.value = toilet;
      expect(rig.camera.listeners, 1, reason: 'still listening');
      expectAt(rig.tool.ghostAt, gridOf(near), 're-armed: object snap off');
      expect(gridOf(near) == e0, isFalse);
      final want = placementTransform(
          at: gridOf(near),
          basePoint: toilet.definition.basePoint,
          quarterTurns: 1,
          mirrored: false);
      final t = rig.tool.ghostPlacement!;
      expect([
        t.a,
        t.b,
        t.c,
        t.d,
        t.e,
        t.f
      ], [
        want.a,
        want.b,
        want.c,
        want.d,
        want.e,
        want.f
      ], reason: 'the placement follows the re-resolved point');
      expect(rig.notifications, [false], reason: 'one repaint');
    });

    test(
        'dispose with a live camera removes the listener; a camera change '
        'after it does nothing and does not throw', () {
      final rig = Rig();
      rig.hover(pA);
      expect(rig.camera.listeners, 1);
      final at = rig.tool.ghostAt.clone();
      rig.tool.dispose();
      rig.disposed = true;
      expect(rig.camera.listeners, 0);
      // The camera reports (and swallows) a listener's error, so "does not
      // throw" alone cannot see a listener left behind; the count and the
      // ghost's point can.
      expect(() => rig.camera.zoomAt(focus, 1.7), returnsNormally);
      expectAt(rig.tool.ghostAt, at, 'nothing re-resolves after dispose');
    });
  });

  group('the wall attachment (spec 09c D6)', () {
    /// A point 0.37 along [r] and 160 mm (half the capture) into the room.
    Vector2 nearFace(FaceRun r) => onRun(r, r.length * 0.37, 160);

    test('the fixtures are not degenerate', () {
      expect(toilet.tags, contains(againstWallTag));
      expect(base600.tags, contains(againstWallTag));
      expect(island.tags, isNot(contains(againstWallTag)));
      final b = boxOfEntry(toilet)!;
      expect(toilet.definition.basePoint == b.backCentre, isFalse,
          reason: 'the toilet\'s base point is not its back-centre');
      for (final (deg, j, side) in attachCases) {
        final rig = Rig(walls: [attachWall(deg, j)]);
        final r = rig.runOn(side);
        expect(r.t.x.abs(), greaterThan(0.1),
            reason: '$deg°: not axis-aligned');
        expect(r.t.y.abs(), greaterThan(0.1),
            reason: '$deg°: not axis-aligned');
        expect(r.a.length, greaterThan(1e5), reason: 'far from the origin');
        expect(rig.camera.value.scale, isNot(1));
      }
    });

    test(
        'a tagged symbol attaches on hover and on release: the ghost and the '
        'instance take attachToWall\'s transform byte for byte (30° and '
        '−112.5°, either face, mirrored and not, turned)', () {
      for (final (deg, j, side) in attachCases) {
        for (final mirrored in [false, true]) {
          final why = '$deg° ${side.name}${mirrored ? ' mirrored' : ''}';
          final rig = Rig(walls: [attachWall(deg, j)]);
          rig.armed.value = toilet;
          rig.key(kR);
          if (mirrored) rig.key(kM);
          final run = rig.runOn(side);
          final u = run.length * 0.37;
          final p = onRun(run, u, 160);
          final want = rig.attachOf(toilet, p, mirrored: mirrored)!;
          // Hand arithmetic: the back-centre on the face at the pointer's
          // `u`, turned to `t`, mirrored about the box's centre.
          expect(identical(want.run, run), isTrue, reason: why);
          expect(want.q.distanceTo(onRun(run, u, 0)), lessThan(1e-6),
              reason: why);
          expect(
              partsOf(want.transform),
              partsOf(placementTransform(
                  at: want.q,
                  basePoint: boxOfEntry(toilet)!.backCentre,
                  rotation: (run.t.x, run.t.y),
                  mirrored: mirrored)),
              reason: why);

          rig.hover(p);
          expect(rig.tool.ghostAttachment, isNotNull, reason: why);
          expect(partsOf(rig.tool.ghostPlacement!), partsOf(want.transform),
              reason: '$why: the ghost');
          expect(partsOf(rig.tool.ghostPlacement!),
              isNot(partsOf(rig.freeOf(toilet, turns: 1, mirrored: mirrored))),
              reason: '$why: not the free placement');
          // Pressed away from the wall, released on it.
          rig.down(pA);
          expect(rig.tool.ghostAttachment, isNull, reason: '$why: free');
          rig.up(p);
          expect(
              partsOf(rig.instances.single.transform), partsOf(want.transform),
              reason: '$why: the instance');
          expect(rig.document.commands.undoDepth, 1, reason: why);
        }
      }
    });

    test(
        'the capture is kWallAttachPixels (16 px), not the snap aperture: '
        '300 mm off the face attaches at 0.05 px/mm, 330 mm does not', () {
      expect(kWallAttachPixels, 16.0);
      final rig = Rig(walls: [attachWall(30, Justification.left)]);
      rig.armed.value = toilet;
      final run = rig.runOn(FaceSide.left);
      rig.hover(onRun(run, 1500, 300));
      expect(rig.tool.ghostAttachment, isNotNull, reason: '300 < 320 mm');
      expect(300, greaterThan(edgeWorld), reason: 'premise: past 10 px');
      rig.hover(onRun(run, 1500, 330));
      expect(rig.tool.ghostAttachment, isNull, reason: '330 > 320 mm');
    });

    test(
        'an untagged symbol (the island) does not attach: the ghost and the '
        'instance are free (M-09c-a)', () {
      final rig = Rig(walls: [attachWall(30, Justification.left)]);
      rig.armed.value = island;
      rig.key(kR);
      final p = nearFace(rig.runOn(FaceSide.left));
      expect(rig.attachOf(island, p), isNotNull,
          reason: 'premise: a face would take its box');
      rig.hover(p);
      expect(rig.tool.ghostAttachment, isNull);
      final free = rig.freeOf(island, turns: 1);
      expect(partsOf(rig.tool.ghostPlacement!), partsOf(free));
      rig.down(p);
      rig.up(p);
      expect(partsOf(rig.instances.single.transform), partsOf(free));
    });

    test(
        'with object snap off (F3) nothing attaches; on, it does '
        '(M-09c-l)', () {
      for (final on in [false, true]) {
        final rig =
            Rig(objectSnap: on, walls: [attachWall(30, Justification.left)]);
        rig.armed.value = toilet;
        final p = nearFace(rig.runOn(FaceSide.left));
        final want = rig.attachOf(toilet, p)!;
        rig.hover(p);
        rig.down(p);
        rig.up(p);
        final t = rig.instances.single.transform;
        if (on) {
          expect(rig.tool.ghostAttachment, isNotNull);
          expect(partsOf(t), partsOf(want.transform));
        } else {
          expect(rig.tool.ghostAttachment, isNull);
          expect(
              partsOf(rig.tool.ghostPlacement!), partsOf(rig.freeOf(toilet)));
          expect(partsOf(t), partsOf(rig.freeOf(toilet)));
        }
      }
    });

    test('a tool given no wall faces never attaches (09b\'s behaviour)', () {
      final rig =
          Rig(walls: [attachWall(30, Justification.left)], faces: false);
      expect(rig.tool.faces, isNull);
      rig.armed.value = toilet;
      final runs = faceRunsOf(rig.document, rig.wallHandles.single);
      final p = nearFace(runs.singleWhere((r) => r.side == FaceSide.left));
      rig.hover(p);
      expect(rig.tool.ghostAttachment, isNull);
      expect(partsOf(rig.tool.ghostPlacement!), partsOf(rig.freeOf(toilet)));
    });

    test(
        'M while attached mirrors in place: the footprint stays, the '
        'transform is the mirrored attachment (M-09c-j)', () {
      for (final (deg, j, side) in attachCases) {
        final rig = Rig(walls: [attachWall(deg, j)]);
        rig.armed.value = toilet;
        final p = nearFace(rig.runOn(side));
        rig.hover(p);
        final p0 = rig.tool.ghostPlacement!;
        expect(partsOf(p0), partsOf(rig.attachOf(toilet, p)!.transform));
        rig.notifications.clear();
        rig.key(kM);
        expect(rig.notifications, [false], reason: '$deg°: one repaint');
        final p1 = rig.tool.ghostPlacement!;
        final want = rig.attachOf(toilet, p, mirrored: true)!;
        expect(partsOf(p1), partsOf(want.transform), reason: '$deg°');
        expect(p0.a * p0.d - p0.b * p0.c, greaterThan(0));
        expect(p1.a * p1.d - p1.b * p1.c, lessThan(0),
            reason: '$deg°: mirrored');
        // The same four corners, the mirror swapping left and right.
        final box = boxOfEntry(toilet)!;
        final f0 = footprint(box, p0), f1 = footprint(box, p1);
        for (final (i, k) in [(0, 1), (1, 0), (2, 3), (3, 2)]) {
          expect(f1[i].distanceTo(f0[k]), lessThan(1e-6),
              reason: '$deg°: corner $i in place');
        }
        rig.down(p);
        rig.up(p);
        expect(partsOf(rig.instances.single.transform), partsOf(want.transform),
            reason: '$deg°: placed mirrored');
        rig.key(kM);
        expect(partsOf(rig.tool.ghostPlacement!), partsOf(p0),
            reason: '$deg°: M again');
      }
    });

    test(
        'R and Shift+R while attached change the turn count only: the ghost '
        'does not turn; off the face the count applies (M-09c-k)', () {
      final rig = Rig(walls: [attachWall(-112.5, Justification.right)]);
      rig.armed.value = toilet;
      final p = nearFace(rig.runOn(FaceSide.right));
      rig.hover(p);
      final p0 = partsOf(rig.tool.ghostPlacement!);
      rig.key(kR);
      expect(rig.tool.quarterTurns, 1);
      expect(partsOf(rig.tool.ghostPlacement!), p0, reason: 'R');
      rig.key(kR);
      rig.key(kR);
      rig.key(kR, held: [kShift]);
      expect(rig.tool.quarterTurns, 2);
      expect(partsOf(rig.tool.ghostPlacement!), p0, reason: 'R, R, Shift+R');
      rig.down(p);
      rig.up(p);
      expect(partsOf(rig.instances.single.transform), p0,
          reason: 'placed unturned');
      // Off the face: the two quarter turns apply.
      rig.hover(pA);
      expect(rig.tool.ghostAttachment, isNull);
      expect(partsOf(rig.tool.ghostPlacement!),
          partsOf(rig.freeOf(toilet, turns: 2)));
      expectAt(rig.tool.ghostAt, gridOf(pA), 'free at the grid');
    });

    test(
        'the marker is the nearest glyph at the face point q, not at the '
        'raw or the resolved point', () {
      final rig = Rig(walls: [attachWall(30, Justification.left)]);
      rig.armed.value = toilet;
      final p = nearFace(rig.runOn(FaceSide.left));
      rig.hover(p);
      final q = rig.tool.ghostAttachment!.q;
      final canvas = RecordingCanvas();
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600));
      expect(canvas.named('drawRect'), isEmpty);
      final lines = canvas.named('drawLine').toList();
      expect(lines, hasLength(4), reason: 'the hourglass');
      final ends = [
        for (final l in lines) ...[
          l.positionalArguments[0] as ui.Offset,
          l.positionalArguments[1] as ui.Offset
        ]
      ];
      final cx = ends.map((o) => o.dx).reduce((a, b) => a + b) / 8;
      final cy = ends.map((o) => o.dy).reduce((a, b) => a + b) / 8;
      final sq = rig.camera.value.worldToScreen(q);
      expect(cx, closeTo(sq.x, 1e-9));
      expect(cy, closeTo(sq.y, 1e-9));
      // The glyph: top and bottom edges, then the two diagonals.
      const h = kSnapMarkerPixels / 2;
      for (final (o, dx, dy) in [
        (ends[0], -h, -h),
        (ends[1], h, -h),
        (ends[3], -h, h),
        (ends[4], -h, h),
        (ends[5], h, h),
        (ends[7], -h, -h),
      ]) {
        expect(o.dx, closeTo(sq.x + dx, 1e-9));
        expect(o.dy, closeTo(sq.y + dy, 1e-9));
      }
      for (final w in [p, rig.tool.ghostAt]) {
        final sw = rig.camera.value.worldToScreen(w);
        expect(sw.distanceTo(sq), greaterThan(5),
            reason: 'q is not the raw or the resolved point');
      }
    });

    test(
        'a camera zoom that brings the face within capture attaches the '
        'resting ghost (M-09c-ak)', () {
      final rig = Rig(walls: [attachWall(30, Justification.left)]);
      rig.armed.value = toilet;
      final run = rig.runOn(FaceSide.left);
      // 400 mm off the face: outside 320 mm, inside 640 mm.
      final p = onRun(run, run.length * 0.37, 400);
      rig.hover(p);
      expect(rig.tool.ghostAttachment, isNull, reason: 'premise: too far');
      final s = rig.at(p).screen;
      rig.notifications.clear();
      rig.camera.zoomAt(s, 0.5);
      final k = rig.camera.value.scale;
      expect(k, closeTo(scale / 2, 1e-15));
      final w = rig.camera.value.screenToWorld(Vector2(s.dx, s.dy));
      final want = rig.attachOf(toilet, w, k: k)!;
      expect(rig.tool.ghostAttachment, isNotNull);
      expect(partsOf(rig.tool.ghostPlacement!), partsOf(want.transform));
      expect(rig.notifications, [false]);
      // And back out: free again.
      rig.camera.zoomAt(s, 2);
      expect(rig.tool.ghostAttachment, isNull);
    });

    test(
        'a re-arm between a tagged and an untagged entry while the ghost '
        'rests near a face switches the attachment on and off', () {
      final rig = Rig(walls: [attachWall(-112.5, Justification.right)]);
      rig.armed.value = island;
      final p = nearFace(rig.runOn(FaceSide.right));
      rig.hover(p);
      expect(rig.tool.ghostAttachment, isNull, reason: 'the island: free');
      final s = rig.at(p).screen;
      final w = rig.camera.value.screenToWorld(Vector2(s.dx, s.dy));
      rig.armed.value = toilet;
      expect(rig.tool.ghostAttachment, isNotNull, reason: 'the toilet');
      expect(partsOf(rig.tool.ghostPlacement!),
          partsOf(rig.attachOf(toilet, w)!.transform));
      rig.armed.value = island;
      expect(rig.tool.ghostAttachment, isNull, reason: 'the island again');
      expect(partsOf(rig.tool.ghostPlacement!), partsOf(rig.freeOf(island)));
      // Hidden (no context to re-resolve with), a re-arm still drops the
      // tagged entry's attachment: the stored placement is the new entry's.
      rig.armed.value = toilet;
      expect(rig.tool.ghostAttachment, isNotNull);
      rig.tool.onPointerExit(rig.ctx);
      rig.armed.value = island;
      expect(rig.tool.ghostAttachment, isNull, reason: 'hidden re-arm');
      expect(partsOf(rig.tool.ghostPlacement!), partsOf(rig.freeOf(island)),
          reason: 'hidden re-arm');
    });

    test(
        'W-5: a unit placed right after another along the face snaps to it '
        'before the change stream delivers; one undo step each (M-09c-ap)', () {
      final rig = Rig(walls: [attachWall(30, Justification.left)]);
      rig.armed.value = base600;
      final run = rig.runOn(FaceSide.left);
      final bands = rig.bands!;
      final p1 = onRun(run, 1000, 200);
      rig.hover(p1);
      rig.down(p1);
      rig.up(p1);
      final first = rig.tool.ghostAttachment!;
      expect((first.q - run.a).dot(run.t), closeTo(1000, 1e-6));
      // Synchronously (no await: the document's change stream has not
      // delivered), a second unit 120 mm (inside the 200 mm edge capture)
      // to the right of the first's right side, mirrored and turned.
      rig.key(kM);
      rig.key(kR);
      final gen = bands.generation;
      // 250 mm: outside the edge capture (10 px), inside the attach capture
      // (16 px): attached, not snapped.
      rig.hover(onRun(run, 1000 + 600 + 250, 150));
      expect(
          (rig.tool.ghostAttachment!.q - run.a).dot(run.t), closeTo(1850, 1e-6),
          reason: 'beyond the edge capture: not snapped');
      final p2 = onRun(run, 1000 + 600 + 120, 150);
      rig.hover(p2);
      final second = rig.tool.ghostAttachment!;
      expect(bands.generation, gen, reason: 'no change delivered meanwhile');
      expect((second.q - run.a).dot(run.t), closeTo(1600, 1e-6),
          reason: 'its left side on the first\'s right side');
      rig.down(p2);
      rig.up(p2);
      expect(rig.instances, hasLength(2));
      expect(partsOf(rig.instances.last.transform), partsOf(second.transform));
      expect(rig.document.commands.undoDepth, 2);
      rig.document.commands.undo();
      expect(partsOf(rig.instances.single.transform), partsOf(first.transform),
          reason: 'one undo step took the second only');
      rig.document.commands.undo();
      expect(rig.instances, isEmpty);
    });

    test(
        'an attached placement refused by the permissions allocates nothing; '
        'lifted, it places the attached transform', () {
      final rig = Rig(walls: [attachWall(30, Justification.left)]);
      rig.armed.value = toilet;
      final p = nearFace(rig.runOn(FaceSide.left));
      rig.document.commands.permissions = const DraftPermissions(
          transform: true, components: true, geometry: true, structure: false);
      final seed = rig.document.handleSeed.current;
      final gen = rig.bands!.generation;
      rig.hover(p);
      rig.down(p);
      rig.up(p);
      expect(rig.tool.ghostAttachment, isNotNull, reason: 'premise');
      expect(rig.document.handleSeed.current, seed);
      expect(rig.instances, isEmpty);
      expect(rig.bands!.generation, gen, reason: 'nothing to see');
      rig.document.commands.permissions = DraftPermissions.all;
      rig.down(p);
      rig.up(p);
      expect(partsOf(rig.instances.single.transform),
          partsOf(rig.attachOf(toilet, p)!.transform));
    });
  });
}
