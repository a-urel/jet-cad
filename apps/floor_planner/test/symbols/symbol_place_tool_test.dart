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
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:floor_planner/new_document.dart';
import 'package:floor_planner/symbols/symbol_component.dart';
import 'package:floor_planner/symbols/symbol_ghost.dart';
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_place_tool.dart';
import 'package:floor_planner/symbols/symbol_placer.dart';
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
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

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
  Rig({bool page = true, bool? objectSnap, double? step = gridStep}) {
    document = prepareDocument(const InsertionPointMeasurer());
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
    tool = SymbolPlaceTool(armed);
    tool.addListener(() => notifications.add(tool.isMidShape));
    addTearDown(() {
      if (!disposed) tool.dispose();
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
}
