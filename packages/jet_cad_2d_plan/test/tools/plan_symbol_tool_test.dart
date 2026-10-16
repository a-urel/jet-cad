// Spec 09b D6, F-5, F-6, F-12, F-14, F-16 (ported to the plan library,
// Task 14): plan.symbol's pointer, snap, ghost, keys and permission check,
// driven directly with `ToolPointerEvent`s and `KeyEvent`s; spec 09c D12:
// the ghost follows a camera change (a wheel zoom, a pan). Ported from
// jet_cad_floor_plan's symbol_place_tool_test.dart, assertions unchanged;
// its wall attachment moves to sub-project 3 with the wall-face provider.
// Spec P3 "Attachment" (Task 14): the attachment through the registry.
//
// Fixtures (plan P-3): entries of the plan library's fixture library
// (every base point is off the origin); a camera at 0.05 px/mm with y up,
// centred far from the origin, so the snap aperture is 10 / 0.05 = 200 mm,
// not 10 mm; a page whose grid (25 mm, origin off every round number) moves
// every raw point; one line whose start E is the object snap target. The
// ghost is painted with a rebase origin far from zero.
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import 'package:jet_cad_2d_kit/authoring.dart' show Catalog, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/attach/attachment_registry.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_ghost.dart';
import 'package:jet_cad_2d_plan/src/tools/plan_symbol_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';
import '../support/symbol_fixtures.dart';
import '../support/test_kit.dart' show TestEdge;

final SymbolLibrary library =
    SymbolLibrary.decode(bytesOf(buildValidLibrary()));

PlanSymbol entry(String key) => PlanSymbol(
    kitId: 'fixture',
    names: KitNames.empty,
    entry: library.entries.singleWhere((e) => e.symbol.key == key));

/// Today's office chair: a symbol whose base point is off its leaves and
/// far (beyond the 200 mm aperture) from every snap point of its own
/// leaves, so a later placement near an earlier one lands on the grid, as
/// the asset's chair did. (Not the fixture sofa: its line's midpoint sits
/// 60 mm from its base point and catches the third placement of "keys
/// compose".)
final PlanSymbol chair = entry('fixture.armchair.single');

/// Today's toilet: the second symbol a re-arm swaps to.
final PlanSymbol toilet = entry('fixture.nightstand.single');

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
  /// so the drag uses the zoom-adaptive one. [attachments], [canRotate]
  /// and [canMirror] are handed to the tool.
  Rig(
      {bool page = true,
      bool? objectSnap,
      double? step = gridStep,
      AttachmentRegistry? attachments,
      bool Function()? canRotate,
      bool Function()? canMirror}) {
    document = DraftDocument.empty(measurer: const InsertionPointMeasurer());
    PageComponent.register(document.components);
    registerKitComponents(document.components);
    document.header.units = DrawingUnits.millimeters;
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
    tool = PlanSymbolTool(armed,
        attachments: attachments, canRotate: canRotate, canMirror: canMirror);
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
  late final PlanSymbolTool tool;
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
final class CountingNotifier extends ValueNotifier<PlanSymbol?> {
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
        basePoint: chair.entry.definition.basePoint,
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

final class _ServicesStub implements PlanServices {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('a provider factory read the services');
}

List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

void main() {
  // The tool reads HardwareKeyboard.instance (F-12, `_hasModifier`), which
  // needs a bound ServicesBinding even in plain unit tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the fixtures are not degenerate', () {
    for (final e in [chair, toilet]) {
      final b = e.entry.definition.basePoint;
      expect(b.x != 0 || b.y != 0, isTrue,
          reason: '${e.component.key} base point');
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
      rig.tool.paintWorldOverlay(canvas, origin, scale, PaperPalette.light);
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600),
          PaperPalette.light);
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
      expect(rig.tool.ghostPath, same(ghostPathFor(chair.entry)));
      rig.notifications.clear();
      rig.armed.value = toilet;
      expect(rig.notifications, [false]);
      expect(rig.tool.ghostPath, same(ghostPathFor(toilet.entry)));
      rig.up(pA);
      expect(rig.instances, isEmpty, reason: 'the old press places nothing');
      rig.down(pB, pointer: 9);
      rig.up(pB, pointer: 9);
      final def = rig.instances.single.definition;
      expect(rig.document.components.get<SymbolComponent>(def)!.key,
          toilet.component.key);
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
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600),
          PaperPalette.light);
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
      rig.tool.paintWorldOverlay(canvas, origin, scale, PaperPalette.light);
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
      final b = chair.entry.definition.basePoint;
      final want = gridOf(pB);
      final (x, y) = apply(m, b.x, b.y);
      expect(x, closeTo(want.x - origin.x, 1e-9));
      expect(y, closeTo(want.y - origin.y, 1e-9));
      final draw = canvas.named('drawPath').single.positionalArguments;
      expect(draw[0], same(ghostPathFor(chair.entry)));
      final paint = draw[1] as ui.Paint;
      expect(paint.strokeWidth, closeTo(kPreviewStrokePixels / scale, 1e-12));
      expect(paint.color.toARGB32(), PaperPalette.light.preview.toARGB32());
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
      rig.tool.paintWorldOverlay(first, origin, scale, PaperPalette.light);
      rig.hover(pC);
      final second = RecordingCanvas();
      rig.tool.paintWorldOverlay(second, origin, scale, PaperPalette.light);
      Object? arg(RecordingCanvas c, String name, int i) =>
          c.named(name).single.positionalArguments[i];
      expect(arg(second, 'drawPath', 0), same(arg(first, 'drawPath', 0)));
      expect(arg(second, 'drawPath', 1), same(arg(first, 'drawPath', 1)));
      expect(arg(second, 'transform', 0), same(arg(first, 'transform', 0)));
      expect(rig.tool.ghostPath, same(ghostPathFor(chair.entry)));
      // The reused storage now holds the second placement.
      final m = arg(second, 'transform', 0) as Float64List;
      final b = chair.entry.definition.basePoint;
      final (x, y) = apply(m, b.x, b.y);
      expect(x, closeTo(gridOf(pC).x - origin.x, 1e-9));
      expect(y, closeTo(gridOf(pC).y - origin.y, 1e-9));
    });

    test(
        'the placement is computed on events, never in a paint (spec D5, '
        'W-15): hover, R, M and a re-arm each set it; repeated paints pass '
        'the stored transform and compute nothing', () {
      final rig = Rig();
      Transform2 want(PlanSymbol e, Vector2 p, int turns, bool mirrored) =>
          placementTransform(
              at: gridOf(p),
              basePoint: e.entry.definition.basePoint,
              quarterTurns: turns,
              mirrored: mirrored);
      void paints(int n) {
        for (var i = 0; i < n; i++) {
          rig.tool.paintWorldOverlay(
              RecordingCanvas(), origin, scale, PaperPalette.light);
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
      final tb = toilet.entry.definition.basePoint;
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
          basePoint: chair.entry.definition.basePoint,
          quarterTurns: 3,
          mirrored: true);
      List<double> bytes(Transform2? t) =>
          t == null ? const [] : [t.a, t.b, t.c, t.d, t.e, t.f];
      void paintOnce() => rig.tool.paintWorldOverlay(
          RecordingCanvas(), origin, scale, PaperPalette.light);
      final matrix = rig.tool.ghostMatrix;
      final b = chair.entry.definition.basePoint;

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
      rig.tool.paintWorldOverlay(canvas, origin, scale, PaperPalette.light);
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600),
          PaperPalette.light);
      expect(canvas.calls, isEmpty);

      rig.hover(pB);
      rig.tool.cancel(rig.ctx);
      expect(rig.tool.ghostVisible, isFalse);
      canvas = RecordingCanvas();
      rig.tool.paintWorldOverlay(canvas, origin, scale, PaperPalette.light);
      rig.tool.paintOverlay(canvas, rig.camera.value, const ui.Size(800, 600),
          PaperPalette.light);
      expect(canvas.calls, isEmpty);
    });
  });

  group('keys', () {
    test('the eight placements are distinct: each turn and mirror is seen', () {
      final b = chair.entry.definition.basePoint;
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
          basePoint: chair.entry.definition.basePoint,
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
          basePoint: toilet.entry.definition.basePoint,
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
          basePoint: toilet.entry.definition.basePoint,
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

  // Dark theme spec D5 "Tools", Task 3 (M-DT-8): the ghost and the snap
  // marker take the overlay's paper set, handed to each paint method. The
  // page is Blueprint and the set is `forPaper(page.background)`, as the
  // planner picks it; White is the control, on the same tool right after.
  group('the paper set (dark theme M-DT-8)', () {
    /// The document's page colour, as the planner reads it.
    int paperArgb(Rig rig) => rig.document.components
        .get<PageComponent>(rig.document.rootHandle)!
        .background;

    Rig blueprintRig() {
      final rig = Rig();
      rig.document.commands.execute(SetComponentCommand<PageComponent>(
          rig.document.rootHandle,
          rig.pages.value!.copyWith(background: 0xFF1F3A5F)));
      expect(paperArgb(rig), 0xFF1F3A5F, reason: 'premise');
      // 75 mm from E: the ghost snaps there and the marker shows.
      rig.hover(e0 + Vector2(60, -45));
      expect(rig.tool.ghostVisible, isTrue, reason: 'premise');
      return rig;
    }

    test(
        'on Blueprint the ghost (paintWorldOverlay) is 0xFFC857 and the '
        'marker (paintOverlay) 0x5FD68F; on White the light set', () {
      final rig = blueprintRig();
      final paper = PaperPalette.forPaper(paperArgb(rig));
      for (final (p, ghost, snap) in [
        (paper, 0xFFFFC857, 0xFF5FD68F),
        (PaperPalette.forPaper(0xFFFFFFFF), 0xFFE8A11E, 0xFF2E9E5B),
      ]) {
        final world = RecordingCanvas();
        rig.tool.paintWorldOverlay(world, origin, scale, p);
        // The Paint is the tool's own and is recoloured per frame: read it
        // now.
        final drawn = [
          for (final c in world.calls)
            if (c.memberName == #drawPath || c.memberName == #drawLine)
              (c.positionalArguments.last as ui.Paint).color.toARGB32(),
        ];
        expect(drawn, [ghost, ghost, ghost],
            reason: 'the outline and the base-point cross');
        final screen = RecordingCanvas();
        rig.tool
            .paintOverlay(screen, rig.camera.value, const ui.Size(800, 600), p);
        final marker = screen.named('drawRect').single;
        expect(
            (marker.positionalArguments[1] as ui.Paint).color.toARGB32(), snap,
            reason: 'the endpoint square');
      }
    });

    test('its marker Paint is a field: the same object on the next frame', () {
      final rig = blueprintRig();
      ui.Paint markerPaint(PaperPalette p) {
        final c = RecordingCanvas();
        rig.tool.paintOverlay(c, rig.camera.value, const ui.Size(800, 600), p);
        return c.named('drawRect').single.positionalArguments[1] as ui.Paint;
      }

      expect(
          identical(
              markerPaint(PaperPalette.dark), markerPaint(PaperPalette.light)),
          isTrue);
    });
  });

  group('attachment through the registry (spec P3)', () {
    /// The demo's shelves: each attaches to a test edge or corner.
    PlanSymbol shelf([String key = 'demo.shelf.wall']) => PlanSymbol(
        kitId: 'demo',
        names: KitNames.empty,
        entry:
            SymbolLibrary.decode(encodeLibrary(Catalog(kit: 'demo', symbols: [
          box('demo.shelf.wall', 'Wall shelf', 'Storage', ['shelf'],
              attachTo: ['test-edge', 'test-corner'], base: (950, 410)),
          box('demo.shelf.high', 'High shelf', 'Storage', ['high'],
              attachTo: ['test-edge'], base: (720.25, 515.5)),
        ]))).entries.singleWhere((e) => e.symbol.key == key));

    ({Rig rig, RecordingProvider edge, PlanAttachmentRegistry registry})
        attachRig(
            {bool rotate = true,
            Attachment? Function(AttachmentQuery)? answer}) {
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      final edge = RecordingProvider('test-edge', answer ?? (_) => null);
      registry.add('demo', (_) => edge, _ServicesStub());
      final rig = Rig(attachments: registry, canRotate: () => rotate);
      addTearDown(registry.dispose);
      return (rig: rig, edge: edge, registry: registry);
    }

    test(
        'AT-8 an armed symbol with no attachTo never asks; with attachTo, '
        'the query carries the footprint, the free placement, the raw '
        'pointer and the captures in world units', () {
      final r = attachRig();
      r.rig.hover(pB);
      expect(r.edge.queries, isEmpty,
          reason: 'the armchair attaches to nothing');
      final s = shelf();
      r.rig.armed.value = s;
      r.rig.hover(pA);
      final q = r.edge.queries.last;
      // M-AT8a: the snapped point passed as the pointer.
      expect(q.pointer, pA);
      expect(gridOf(pA) == pA, isFalse, reason: 'premise: the grid moves it');
      // M-AT8b: kAttachPixels written as the snap aperture.
      expect(q.capture, closeTo(16 / scale, 1e-9));
      expect(q.edgeCapture, closeTo(kSnapAperturePixels / scale, 1e-9));
      final box = boxOfEntry(s.entry)!;
      expect([
        q.footprint.minX,
        q.footprint.minY,
        q.footprint.maxX,
        q.footprint.maxY
      ], [
        box.left,
        box.front,
        box.right,
        box.back
      ]);
      expect(
          partsOf(q.current),
          partsOf(placementTransform(
              at: gridOf(pA), basePoint: s.entry.definition.basePoint)));
      expect(q.mirrored, isFalse);
      expect(q.mayRotate, isTrue);
      expect(q.exclude, isEmpty);
      expect(q.keep, isNull);
    });

    test(
        'AT-9 attached: the ghost and the release use the attachment\'s '
        'transform verbatim, and the marker is drawn at its marker', () {
      final turned = Transform2.translation(81000.5, -36000.25)
          .multiply(Transform2.rotation(-1.1));
      final marker = Vector2(80990.75, -35810.5);
      final r = attachRig(answer: (_) => attachment(turned, marker, 'run-7'));
      r.rig.armed.value = shelf();
      r.rig.hover(pB);
      expect(partsOf(r.rig.tool.ghostPlacement!), partsOf(turned));
      final screen = RecordingCanvas();
      r.rig.tool.paintOverlay(screen, r.rig.camera.value,
          const ui.Size(800, 600), PaperPalette.light);
      final s = r.rig.camera.value.worldToScreen(marker);
      // The nearest glyph: four lines, the first along its top edge from
      // (−h, −h) to (h, −h) around the marker (snap_marker.dart:57-60).
      final lines = screen.named('drawLine').toList();
      expect(lines, hasLength(4));
      const h = kSnapMarkerPixels / 2;
      final start = lines.first.positionalArguments[0] as ui.Offset;
      // M-AT9b: the attached marker drawn at the snapped point.
      expect(start.dx, closeTo(s.x - h, 1e-9));
      expect(start.dy, closeTo(s.y - h, 1e-9));
      r.rig.place(pA, pB);
      // M-AT9: the release ignores the attachment (places freely).
      expect(partsOf(r.rig.instances.single.transform), partsOf(turned));
    });

    test('AT-10 object snap off: nothing is asked (today\'s rule)', () {
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      addTearDown(registry.dispose);
      final edge = RecordingProvider('test-edge', (_) => null);
      registry.add('demo', (_) => edge, _ServicesStub());
      final rig = Rig(attachments: registry, objectSnap: false);
      rig.armed.value = shelf();
      rig.hover(pA);
      // M-AT10: the `_rawObjectSnap` test dropped.
      expect(edge.queries, isEmpty);
    });

    test(
        'AT-11 hysteresis: each query keeps the last answer; a re-arm '
        'clears it', () {
      final a = attachment(Transform2.translation(80000.5, -36000.5),
          Vector2(80000.5, -36000.5), 'face');
      final r = attachRig(answer: (_) => a);
      r.rig.armed.value = shelf();
      r.rig.hover(pA);
      expect(r.edge.queries.last.keep, isNull);
      r.rig.hover(pB);
      // M-AT11a: `keep: previous` written `keep: null`.
      expect(r.edge.queries.last.keep, same(a));
      // A re-arm with the ghost shown asks again at once, for the new
      // symbol, with no keep.
      final asked = r.edge.queries.length;
      r.rig.armed.value = shelf('demo.shelf.high');
      expect(r.edge.queries.length, asked + 1);
      // M-AT11b: `_onArmed` keeps the previous symbol's attachment.
      expect(r.edge.queries.last.keep, isNull);
    });

    test(
        'AT-12 rotate refused: mayRotate is false and the current transform '
        'unturned whatever R stored; M mirrors in place', () {
      var rotate = true;
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      addTearDown(registry.dispose);
      final edge = RecordingProvider('test-edge', (_) => null);
      registry.add('demo', (_) => edge, _ServicesStub());
      final rig = Rig(attachments: registry, canRotate: () => rotate);
      final s = shelf();
      rig.armed.value = s;
      rig.key(kR);
      rig.hover(pA);
      expect(edge.queries.last.mayRotate, isTrue);
      expect(linear(edge.queries.last.current), [0.0, 1.0, -1.0, 0.0],
          reason: 'one quarter turn');
      rotate = false;
      rig.tool.gatesChanged();
      // M-AT12: mayRotate passed as true.
      expect(edge.queries.last.mayRotate, isFalse);
      expect(linear(edge.queries.last.current), [1.0, 0.0, 0.0, 1.0]);
      rig.key(kM);
      expect(edge.queries.last.mirrored, isTrue);
      expect(linear(edge.queries.last.current), [-1.0, 0.0, 0.0, 1.0]);
    });

    test(
        'AT-20 the test kit\'s edge through the registry: its hysteresis '
        'sees the keep it made (capture 320 mm at first, its edge capture '
        '200 mm once attached), and the release commits its answer', () {
      // The edge 150 mm above pA: inside both reaches.
      final y = pA.y + 150;
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      addTearDown(registry.dispose);
      final edge = TestEdge(y: y);
      registry.add('test', (_) => edge, _ServicesStub());
      final rig = Rig(attachments: registry);
      final s = shelf();
      rig.armed.value = s;
      final front = boxOfEntry(s.entry)!.front;
      expect(front, isNot(0), reason: 'premise: the footprint off the origin');

      rig.hover(pA);
      var a = rig.tool.ghostAttachment!;
      expect(a.token, same(edge));
      expect(partsOf(a.transform), [1.0, 0.0, 0.0, 1.0, pA.x, y - front]);
      expect([a.marker.x, a.marker.y], [pA.x, y]);
      // M mirrors in place on the edge; the release commits it.
      rig.key(kM);
      expect(partsOf(rig.tool.ghostPlacement!),
          [-1.0, 0.0, 0.0, 1.0, pA.x, y - front]);
      rig.down(pA);
      rig.up(pA);
      expect(partsOf(rig.instances.single.transform),
          [-1.0, 0.0, 0.0, 1.0, pA.x, y - front]);

      // 250 mm off the edge: beyond the edge capture the kept answer
      // allows. M-AT20 (the registry asks every provider without the keep,
      // its maker too) and M-AT11a (the tool asks with no keep) leave it
      // attached at the 320 mm capture.
      final off = Vector2(pA.x + 37.5, y - 250);
      rig.hover(off);
      expect(rig.tool.ghostAttachment, isNull, reason: 'kept: 250 > 200');
      // Asked again with no keep, the same pointer is within the capture.
      rig.hover(off);
      a = rig.tool.ghostAttachment!;
      expect(partsOf(a.transform), [-1.0, 0.0, 0.0, 1.0, off.x, y - front]);
      expect(reported, isEmpty);
    });

    test('AT-13 a throwing provider: the ghost places freely', () {
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      addTearDown(registry.dispose);
      registry.add(
          'demo', (_) => ThrowingProvider('test-edge'), _ServicesStub());
      final rig = Rig(attachments: registry);
      final s = shelf();
      rig.armed.value = s;
      rig.hover(pA);
      expect(rig.tool.ghostAttachment, isNull);
      expect(
          partsOf(rig.tool.ghostPlacement!),
          partsOf(placementTransform(
              at: gridOf(pA), basePoint: s.entry.definition.basePoint)));
      expect(reported.single.code, KitDiagnosticCode.hookFailed);
    });
  });
}
