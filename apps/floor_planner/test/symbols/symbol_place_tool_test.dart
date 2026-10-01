// Spec 09b D6, F-5, F-6, F-14, plan 09b Task 6: the placement tool's
// pointer, snap and ghost, driven directly with `ToolPointerEvent`s.
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
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/services.dart' show MouseCursor, SystemMouseCursors;
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
  Rig({bool page = true}) {
    document = prepareDocument(const InsertionPointMeasurer());
    if (page) {
      document.commands.execute(SetComponentCommand<PageComponent>(
          document.rootHandle,
          PageComponent(
              originX: gridOriginX,
              originY: gridOriginY,
              gridStepMm: gridStep)));
    }
    document.commands.execute(addDrafted(
        document, EntityKind.line, linePayload(e0, e0 + Vector2(1200, 700))));
    document.commands.clearHistory();
    index = SpatialIndex(document);
    final linear = Transform2.scale(scale, -scale);
    final mid = linear.transformPoint(Vector2(76000, -41000));
    camera = CameraController(ViewportTransform(
        worldToScreenMatrix:
            Transform2.translation(400 - mid.x, 300 - mid.y).multiply(linear)));
    selection = SelectionController(document);
    pages = PageNotifier(document);
    ctx = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: pages);
    armed = CountingNotifier(chair);
    tool = SymbolPlaceTool(armed);
    tool.addListener(() => notifications.add(tool.isMidShape));
    addTearDown(() {
      if (!disposed) tool.dispose();
      armed.dispose();
      pages.dispose();
      selection.dispose();
      camera.dispose();
      index.dispose();
    });
  }

  late final DraftDocument document;
  late final SpatialIndex index;
  late final CameraController camera;
  late final SelectionController selection;
  late final PageNotifier pages;
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

void main() {
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
}
