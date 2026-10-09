// Host embedding API, Slice 4, Task 3: the select tool's and the grip
// cache's gates (`SelectGates`) and `InteractionLayer.autofocus`. Every
// test runs under a rotated camera whose two axes scale differently (the
// camera of `selection_overlay_test.dart`'s "rotated, non-uniform" test), so
// its matrix's `b` and `c` differ, over the 03 grip scene, which sits near
// x = 7000, y = 3000: a line, arcs, a rotated root group and two turned
// instances of one definition.
//
// A line has no centre grip (`leafGrips`): the centre (`GripRole.move`) grip
// under test is the arc's.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter/material.dart'
    show
        Column,
        EditableText,
        Expanded,
        FocusManager,
        KeyEventResult,
        Listenable,
        Material,
        MaterialApp,
        SizedBox,
        TextField;
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        LogicalKeyboardKey,
        PhysicalKeyboardKey,
        SystemMouseCursors;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' as barrel;
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/canvas_palette.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart' show DragKind;
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/page_notifier.dart';
import 'package:jet_cad_2d_flutter/src/select_gates.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/snap_settings.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';
import 'support/spy_canvas.dart';

const Size kView = Size(800, 600);

SelectionKey k(Handle h) => SelectionKey.root(h);

/// Gates whose every answer a test sets, between any two events.
class TestGates extends SelectGates {
  TestGates();

  bool restricts = false;
  SelectionKey? Function(ToolPointerEvent e, ToolContext ctx)? picker;
  bool Function(DraftDocument d, SelectionKey key)? accepts;

  @override
  bool move = true;
  @override
  bool rotate = true;
  @override
  bool reshape = true;
  @override
  bool delete = true;
  @override
  bool idleKeys = true;

  @override
  bool get restrictsPick => restricts;

  @override
  SelectionKey? pick(ToolPointerEvent e, ToolContext ctx) =>
      picker?.call(e, ctx);

  @override
  bool bandAccepts(DraftDocument d, SelectionKey key) =>
      accepts?.call(d, key) ?? true;
}

/// Rotated by 0.3 rad, x scaled by 1.5 and y by -3.6 (flipped), with
/// [centre] in the middle of [kView]: `b != c`, so a transposed projection
/// lands tens of pixels off.
CameraController skewCamera({Vector2? centre}) {
  final c = centre ?? Vector2(7270, 3161);
  const s = 1.5;
  final linear =
      Transform2.rotation(0.3).multiply(Transform2.scale(s, -2.4 * s));
  final mid = linear.transformPoint(c);
  final w2s =
      Transform2.translation(kView.width / 2 - mid.x, kView.height / 2 - mid.y)
          .multiply(linear);
  expect((w2s.b - w2s.c).abs(), greaterThan(0.5),
      reason: 'the fixture is worthless with a symmetric matrix');
  return CameraController(ViewportTransform(worldToScreenMatrix: w2s));
}

/// `GripRig`'s wiring (selection, outlines, grips, snap, page, tool, in the
/// shell's order), with [toolGates] on the select tool and [cacheGates] on
/// the grip cache. The shell gives both the same object; a test that gives
/// only one proves that layer's own gate.
final class GatedRig {
  GatedRig(this.document, {this.toolGates, this.cacheGates})
      : index = SpatialIndex(document),
        selection = SelectionController(document),
        camera = skewCamera() {
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines, gates: cacheGates);
    snap = SnapSettings(objectSnap: false);
    page = PageNotifier(document);
    tool = SelectTool(gates: toolGates);
    context = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page,
        snap: snap,
        grips: grips);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final SelectGates? toolGates, cacheGates;
  final SpatialIndex index;
  final SelectionController selection;
  final CameraController camera;
  late final OutlineCache outlines;
  late final GripCache grips;
  late final SnapSettings snap;
  late final PageNotifier page;
  late final SelectTool tool;
  late final ToolContext context;
  late final ToolController tools;

  Offset at(double x, double y) => screenOf(camera, x, y);

  void down(Offset p) => tool.onPointerDown(pointerAt(camera, p), context);
  void moveTo(Offset p) => tool.onPointerMove(pointerAt(camera, p), context);
  void up(Offset p) =>
      tool.onPointerUp(pointerAt(camera, p, buttons: 0), context);
  void hover(Offset p) =>
      tool.onPointerMove(pointerAt(camera, p, buttons: 0), context);

  /// Press at [from], one move to [to] (past the slop), release at [to].
  void drag(Offset from, Offset to) {
    down(from);
    moveTo(to);
    up(to);
  }

  void click(Offset p) {
    down(p);
    up(p);
  }

  KeyEventResult key(
          LogicalKeyboardKey logical, PhysicalKeyboardKey physical) =>
      tool.onKey(
          KeyDownEvent(
              physicalKey: physical,
              logicalKey: logical,
              timeStamp: Duration.zero),
          context);

  KeyEventResult escape() =>
      key(LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);
  KeyEventResult deleteKey() =>
      key(LogicalKeyboardKey.delete, PhysicalKeyboardKey.delete);
  KeyEventResult backspace() =>
      key(LogicalKeyboardKey.backspace, PhysicalKeyboardKey.backspace);

  /// The rotation grip's centre where the cache's box puts it, whether or
  /// not it is shown.
  Offset rotationGrip() =>
      rotationGripOf(grips.box!, camera.value.worldToScreenMatrix, grips.frame)
          .centre;

  /// One frame of the selection overlay, recorded.
  List<RecordedCall> paint([SelectionOverlayPainter? painter]) {
    final spy = SpyCanvas();
    (painter ?? overlay()).paint(spy, kView);
    return spy.calls;
  }

  SelectionOverlayPainter overlay() => SelectionOverlayPainter(
        selection: selection,
        tools: tools,
        camera: camera,
        outlines: outlines,
        paper: PaperPalette.light,
        repaint: Listenable.merge([selection, tools, camera, outlines, grips]),
      );

  void dispose() {
    tools.dispose();
    grips.dispose();
    outlines.dispose();
    page.dispose();
    snap.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

GatedRig gatedRig(DraftDocument d,
    {SelectGates? toolGates, SelectGates? cacheGates}) {
  final rig = GatedRig(d, toolGates: toolGates, cacheGates: cacheGates);
  addTearDown(rig.dispose);
  return rig;
}

/// The two wirings a gate test runs under: the shell's (one gates object on
/// the tool and the cache) and the tool's alone, which proves the tool's
/// own gate where the cache would otherwise hide a grip from it.
enum Wiring { both, toolOnly }

GatedRig wired(GripScene s, TestGates g, Wiring w) =>
    gatedRig(s.document, toolGates: g, cacheGates: w == Wiring.both ? g : null);

/// The line's midpoint: on its body, on no grip (a line has none there).
const lineBody = (7070.0, 3040.0);

/// The line's first vertex: a stretch grip.
const lineEnd = (7010.0, 3020.0);

/// The positive arc's centre: its move (centre) grip, off its body.
const arcCentre = (7050.0, 3200.0);

List<RecordedCall> rawPoints(List<RecordedCall> calls, int argb) => [
      for (final c in calls)
        if (c.name == 'drawRawPoints' && c.color?.toARGB32() == argb) c,
    ];

final int kGrip = PaperPalette.light.grip.toARGB32();
final int kGripMove = PaperPalette.light.gripMove.toARGB32();
final int kGripHot = PaperPalette.light.gripHot.toARGB32();

void main() {
  test('the barrel exports SelectGates, and all is every gate open', () {
    const all = barrel.SelectGates.all;
    expect(identical(all, SelectGates.all), isTrue);
    expect(all.restrictsPick, isFalse);
    expect(all.move && all.rotate && all.reshape && all.delete, isTrue);
    expect(all.idleKeys, isTrue);
    final s = gripScene();
    expect(all.bandAccepts(s.document, k(s.line)), isTrue);
  });

  test(
      'SelectGates.all and no gates are byte for byte the same across a '
      'band, every drag kind, Escape and Delete', () {
    List<String> run(SelectGates? gates) {
      final s = gripScene();
      final r = gatedRig(s.document, toolGates: gates, cacheGates: gates);
      final out = <String>[];
      void record(String step) {
        final keys = r.selection.keys.map((k) => k.target.value).toList()
          ..sort();
        out.add('$step | ${r.document.commands.undoDepth} | $keys | '
            '${snapshot(r.document)}');
      }

      // A window band over the whole scene.
      r.drag(r.at(6990, 2980), r.at(7580, 3360));
      expect(r.selection.keys, hasLength(greaterThan(5)), reason: 'premise');
      record('band');
      // A body move of the line.
      r.selection.replace([k(s.line)]);
      r.drag(r.at(lineBody.$1, lineBody.$2),
          r.at(lineBody.$1, lineBody.$2) + const Offset(40, 25));
      record('move');
      // A centre grip move of the arc.
      r.selection.replace([k(s.arcPos)]);
      r.drag(r.at(arcCentre.$1, arcCentre.$2),
          r.at(arcCentre.$1, arcCentre.$2) + const Offset(-30, 18));
      record('centre');
      // A reshape of the line's first vertex (moved above).
      r.selection.replace([k(s.line)]);
      final end = payloadOf(r.document, s.line).coords;
      r.drag(
          r.at(end[0], end[1]), r.at(end[0], end[1]) + const Offset(22, -35));
      record('reshape');
      // A rotate.
      final grip = r.rotationGrip();
      r.drag(grip, grip + const Offset(-45, 38));
      record('rotate');
      // Escape clears, Delete deletes.
      r.escape();
      record('escape');
      r.selection.replace([k(s.circle)]);
      r.deleteKey();
      record('delete');
      expect(r.document.commands.undoDepth, 5,
          reason: 'every drag and the delete executed one command');
      return out;
    }

    final none = run(null);
    final all = run(SelectGates.all);
    expect(all, none);
  });

  test(
      'a gate change is read at the next press and hit test, with nothing '
      'rebuilt or notified', () {
    final s = gripScene();
    final g = TestGates();
    final r = gatedRig(s.document, toolGates: g, cacheGates: g);
    var notified = 0;
    r.grips.addListener(() => notified++);
    r.selection.replace([k(s.line)]);
    notified = 0;
    final m = r.camera.value.worldToScreenMatrix;
    final end = r.at(lineEnd.$1, lineEnd.$2);

    g.reshape = false;
    expect(r.grips.hitTest(end, m), -1);
    g.reshape = true;
    expect(r.grips.hitTest(end, m), greaterThanOrEqualTo(0));

    g.move = false;
    final body = r.at(lineBody.$1, lineBody.$2);
    r.drag(body, body + const Offset(40, 25));
    expect(r.document.commands.undoDepth, 0);
    g.move = true;
    expect(notified, 0, reason: 'no gate change notified or rebuilt anything');
    r.drag(body, body + const Offset(40, 25));
    expect(r.document.commands.undoDepth, 1);
  });

  test(
      'gatesChanged resets the hot grip and notifies once, and rebuilds '
      'nothing', () {
    final s = gripScene();
    final g = TestGates();
    final r = gatedRig(s.document, toolGates: g, cacheGates: g);
    r.selection.replace([k(s.line)]);
    final grips = r.grips.grips;
    r.grips.hot = 1;
    var notified = 0;
    r.grips.addListener(() => notified++);
    g.reshape = false;
    r.grips.gatesChanged();
    expect(r.grips.hot, -1);
    expect(notified, 1);
    expect(identical(r.grips.grips, grips), isTrue);
    expect(r.grips.grips, hasLength(2), reason: 'still listed, not drawn');
  });

  // T3-a.
  test(
      'a window and a crossing band select only the keys the gates accept '
      '(T3-a)', () {
    for (final mode in const ['window', 'crossing']) {
      for (final accept in const [false, true]) {
        final s = gripScene();
        final g = TestGates();
        if (!accept) {
          g.accepts =
              (d, key) => key.target == s.instA || key.target == s.instB;
        }
        final r = gatedRig(s.document, toolGates: g, cacheGates: g);
        final a = r.at(6990, 2980), b = r.at(7580, 3360);
        // The world band is the box of the two corners: either order names
        // it, and the screen x order picks the mode.
        final (from, to) =
            (mode == 'window') == (b.dx >= a.dx) ? (a, b) : (b, a);
        r.drag(from, to);
        final keys = r.selection.keys.toSet();
        if (accept) {
          expect(
              keys,
              containsAll(
                  [k(s.line), k(s.arcPos), k(s.group), k(s.instA), k(s.instB)]),
              reason: 'premise ($mode): the band covers them all');
        } else {
          expect(keys, {k(s.instA), k(s.instB)}, reason: mode);
        }
      }
    }
  });

  // T3-b.
  test(
      'the pick override answers presses and hovers alike; a null pick '
      'neither selects nor hovers (T3-b)', () {
    final s = gripScene();
    final g = TestGates();
    final r = gatedRig(s.document, toolGates: g, cacheGates: g);
    final p = r.at(lineBody.$1, lineBody.$2);
    // Premise: the topmost hit there is the line.
    r.hover(p);
    expect(r.selection.hover, k(s.line));
    r.click(p);
    expect(r.selection.keys, {k(s.line)});
    r.selection.clear();

    g
      ..restricts = true
      ..picker = (e, ctx) => k(s.instB);
    r.hover(p);
    expect(r.selection.hover, k(s.instB), reason: 'the hover');
    r.click(p);
    expect(r.selection.keys, {k(s.instB)}, reason: 'the press');

    r.selection.clear();
    g.picker = (e, ctx) => null;
    r.hover(p);
    expect(r.selection.hover, isNull, reason: 'the hover');
    r.click(p);
    expect(r.selection.keys, isEmpty, reason: 'the press');
  });

  // T3-c.
  test(
      'under move: false a centre grip drag and a body drag change nothing '
      'and show no move cursor; under move: true both move (T3-c)', () {
    for (final w in Wiring.values) {
      for (final open in const [false, true]) {
        final s = gripScene();
        final g = TestGates()..move = open;
        final r = wired(s, g, w);
        final before = snapshot(r.document);
        final m = r.camera.value.worldToScreenMatrix;

        // The arc's centre grip.
        r.selection.replace([k(s.arcPos)]);
        final centre = r.at(arcCentre.$1, arcCentre.$2);
        if (w == Wiring.both) {
          expect(r.grips.hitTest(centre, m) >= 0, open,
              reason: 'the centre grip is hit only under move');
          final calls = r.paint();
          expect(rawPoints(calls, kGripMove), hasLength(open ? 1 : 0),
              reason: 'the centre grip is drawn only under move');
          expect(rawPoints(calls, kGrip), hasLength(1),
              reason: 'the stretch grips stay');
        }
        // Checked before the up too: the up's re-read of the gate (S-9h)
        // would hide a drag that started.
        r.down(centre);
        r.moveTo(centre + const Offset(-30, 18));
        expect(r.tool.dragKind == DragKind.move, open,
            reason: '$w, move $open: the centre grip starts a move');
        r.up(centre + const Offset(-30, 18));
        expect(r.document.commands.undoDepth, open ? 1 : 0,
            reason: '$w, move $open: the centre grip');
        if (!open) expect(snapshot(r.document), before);

        // The line's body.
        r.selection.replace([k(s.line)]);
        final body = r.at(lineBody.$1, lineBody.$2);
        r.hover(body);
        expect(r.tool.cursor == SystemMouseCursors.move, open,
            reason: '$w, move $open: the move cursor');
        r.down(body);
        r.moveTo(body + const Offset(40, 25));
        expect(r.tool.dragKind, open ? DragKind.move : isNull,
            reason: '$w, move $open: the body starts a move, or stays a click');
        r.up(body + const Offset(40, 25));
        expect(r.document.commands.undoDepth, open ? 2 : 0,
            reason: '$w, move $open: the body');
        if (!open) expect(snapshot(r.document), before);
      }
    }
  });

  // T3-d.
  test(
      'under rotate: false the rotation grip is neither drawn nor hit, and '
      'a drag from its place rotates nothing (T3-d)', () {
    for (final w in Wiring.values) {
      for (final open in const [false, true]) {
        final s = gripScene();
        final g = TestGates()..rotate = open;
        final r = wired(s, g, w);
        r.selection.replace([k(s.line)]);
        final before = snapshot(r.document);
        final grip = r.rotationGrip();
        if (w == Wiring.both) {
          final discs = r.paint().where((c) => c.name == 'drawCircle');
          expect(discs, hasLength(open ? 1 : 0), reason: 'the disc');
          expect(r.grips.rotatable, open);
        }
        r.down(grip);
        if (w == Wiring.both) {
          expect(r.tool.pressClass == PressClass.rotationGrip, open,
              reason: 'the press class');
        }
        final to = grip + const Offset(-45, 38);
        r.moveTo(to);
        // Before the up: its re-read of the gate (S-9h) would hide a drag
        // that started.
        expect(r.tool.dragKind == DragKind.rotate, open,
            reason: '$w, rotate $open: the drag kind');
        r.up(to);
        expect(r.document.commands.undoDepth, open ? 1 : 0,
            reason: '$w, rotate $open');
        if (!open) expect(snapshot(r.document), before);
      }
    }
  });

  // T3-e.
  test(
      'under reshape: false no stretch grip is drawn or hit, and a drag from '
      'one never reshapes; the centre grips stay under move (T3-e)', () {
    for (final w in Wiring.values) {
      for (final open in const [false, true]) {
        final s = gripScene();
        final g = TestGates()..reshape = open;
        final r = wired(s, g, w);
        r.selection.replace([k(s.line), k(s.arcPos)]);
        final m = r.camera.value.worldToScreenMatrix;
        final end = r.at(lineEnd.$1, lineEnd.$2);
        if (w == Wiring.both) {
          final i = r.grips.hitTest(end, m);
          expect(i >= 0, open,
              reason: 'the end grip is hit only under reshape');
          final calls = r.paint();
          expect(rawPoints(calls, kGrip), hasLength(open ? 1 : 0),
              reason: 'the stretch grips');
          expect(rawPoints(calls, kGripMove), hasLength(1),
              reason: "the arc's centre grip, under move");
          // A hot stretch grip is drawn only while its role is live.
          final hot =
              r.grips.grips.indexWhere((ref) => ref.grip.role != GripRole.move);
          r.grips.hot = hot;
          expect(rawPoints(r.paint(), kGripHot), hasLength(open ? 1 : 0),
              reason: 'the hot stretch grip');
          r.grips.hot = -1;
        }
        final before = payloadOf(r.document, s.line).coords;
        final length = math.sqrt(math.pow(before[2] - before[0], 2) +
            math.pow(before[3] - before[1], 2));
        final to = end + const Offset(22, -35);
        r.down(end);
        r.moveTo(to);
        expect(r.tool.dragKind == DragKind.reshape, open,
            reason: '$w, reshape $open: the drag kind');
        r.up(to);
        final after = payloadOf(r.document, s.line).coords;
        final now = math.sqrt(math.pow(after[2] - after[0], 2) +
            math.pow(after[3] - after[1], 2));
        if (open) {
          expect(now, isNot(closeTo(length, 1e-6)), reason: 'reshaped');
        } else {
          expect(now, closeTo(length, 1e-9),
              reason: '$w: a move or nothing, never a reshape');
        }
      }
    }
  });

  // T3-f.
  test('under delete: false Delete and Backspace remove nothing (T3-f)', () {
    for (final open in const [false, true]) {
      for (final backspace in const [false, true]) {
        final s = gripScene();
        final g = TestGates()..delete = open;
        final r = gatedRig(s.document, toolGates: g, cacheGates: g);
        r.selection.replace([k(s.line), k(s.instA)]);
        final before = snapshot(r.document);
        final result = backspace ? r.backspace() : r.deleteKey();
        final why = 'delete $open, backspace $backspace';
        if (open) {
          expect(result, KeyEventResult.handled, reason: why);
          expect(r.document.entities.slotOf(s.line), isNull, reason: why);
          expect(r.document.tree[s.instA], isNull, reason: why);
        } else {
          expect(result, KeyEventResult.ignored, reason: why);
          expect(snapshot(r.document), before, reason: why);
          expect(r.selection.keys, {k(s.line), k(s.instA)}, reason: why);
        }
      }
    }
  });

  // T3-g.
  test(
      "under idleKeys: false idle Escape and Delete are ignored and keep the "
      "selection; a drag's Escape still cancels it (T3-g)", () {
    for (final open in const [false, true]) {
      final s = gripScene();
      final g = TestGates()..idleKeys = open;
      final r = gatedRig(s.document, toolGates: g, cacheGates: g);
      r.selection.replace([k(s.line)]);
      final before = snapshot(r.document);

      // A drag's Escape is the drag's either way.
      final body = r.at(lineBody.$1, lineBody.$2);
      r.down(body);
      r.moveTo(body + const Offset(40, 25));
      expect(r.tool.dragKind, DragKind.move);
      expect(r.escape(), KeyEventResult.handled);
      expect(r.tool.phase, ToolPhase.idle, reason: 'the drag is cancelled');
      expect(snapshot(r.document), before);

      final escape = r.escape();
      expect(escape, open ? KeyEventResult.handled : KeyEventResult.ignored);
      expect(r.selection.keys, open ? isEmpty : {k(s.line)});

      r.selection.replace([k(s.line)]);
      final delete = r.deleteKey();
      expect(delete, open ? KeyEventResult.handled : KeyEventResult.ignored);
      expect(r.document.entities.slotOf(s.line) == null, open);
      if (!open) {
        expect(snapshot(r.document), before);
        expect(r.selection.keys, {k(s.line)});
      }
    }
  });

  // T3-h.
  test(
      'a gate closed between the slop and the up cancels the drag: no '
      'command, the document byte-identical (T3-h)', () {
    for (final kind in const [
      DragKind.move,
      DragKind.reshape,
      DragKind.rotate
    ]) {
      for (final close in const [true, false]) {
        final s = gripScene();
        final g = TestGates();
        final r = gatedRig(s.document, toolGates: g, cacheGates: g);
        r.selection.replace([k(s.line)]);
        final before = snapshot(r.document);
        final from = switch (kind) {
          DragKind.move => r.at(lineBody.$1, lineBody.$2),
          DragKind.reshape => r.at(lineEnd.$1, lineEnd.$2),
          _ => r.rotationGrip(),
        };
        final to = from + const Offset(-35, 28);
        r.down(from);
        r.moveTo(to);
        expect(r.tool.dragKind, kind, reason: 'premise');
        if (close) {
          switch (kind) {
            case DragKind.move:
              g.move = false;
            case DragKind.reshape:
              g.reshape = false;
            case DragKind.rotate:
              g.rotate = false;
            case DragKind.band:
              break;
          }
        }
        r.up(to);
        expect(r.tool.phase, ToolPhase.idle);
        expect(r.document.commands.undoDepth, close ? 0 : 1,
            reason: '$kind, closed $close');
        if (close) {
          expect(snapshot(r.document), before, reason: '$kind');
          expect(r.selection.keys, {k(s.line)});
        }
      }
    }
  });

  // T3-j.
  test(
      "a closed role's buffer is neither reallocated nor filled across "
      'frames (T3-j)', () {
    final s = gripScene();
    final g = TestGates();
    final r = gatedRig(s.document, toolGates: g, cacheGates: g);
    r.selection.replace([k(s.line), k(s.arcPos)]);
    // ONE painter across every frame: the buffers live on it.
    final painter = r.overlay();
    Float32List stretch(List<RecordedCall> calls) =>
        rawPoints(calls, kGrip).single.args[1] as Float32List;

    final buffer = stretch(r.paint(painter));
    expect(buffer.length, 2 * 5, reason: 'the line 2, the arc 3');
    final first = Float32List.fromList(buffer);

    Offset pan = const Offset(37, -23);
    for (var frame = 0; frame < 4; frame++) {
      final open = frame.isOdd;
      g.reshape = open;
      final m = r.camera.value.worldToScreenMatrix;
      r.camera.value = ViewportTransform(
          worldToScreenMatrix:
              Transform2(m.a, m.b, m.c, m.d, m.e + pan.dx, m.f + pan.dy));
      pan = -pan * 1.5;
      final calls = r.paint(painter);
      if (open) {
        expect(identical(stretch(calls), buffer), isTrue,
            reason: 'frame $frame: the same buffer, not a new one');
        final want = [
          for (final ref in r.grips.grips)
            if (ref.grip.role != GripRole.move) ref.grip,
        ];
        for (var i = 0; i < want.length; i++) {
          final p = r.at(want[i].x, want[i].y);
          expect(buffer[2 * i], closeTo(p.dx, 1e-3));
          expect(buffer[2 * i + 1], closeTo(p.dy, 1e-3));
        }
      } else {
        expect(rawPoints(calls, kGrip), isEmpty, reason: 'frame $frame');
        expect(rawPoints(calls, kGripMove), hasLength(1));
        if (frame == 0) {
          expect(buffer, first,
              reason: 'a closed role is not projected: its buffer keeps the '
                  "last open frame's points under the panned camera");
        }
      }
    }
  });

  // T3-i.
  for (final autofocus in const [true, false]) {
    testWidgets(
        'InteractionLayer(autofocus: $autofocus) beside a host field that '
        'autofocuses: ${autofocus ? 'the layer' : 'the field'} has the '
        'focus; a press on the layer takes it (T3-i)', (tester) async {
      final rig = InteractionRig(DraftDocument.empty(), skewCamera());
      addTearDown(rig.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      // The layer is built first, so with autofocus it claims the scope's
      // focus before the field asks for it.
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: Column(children: [
            Expanded(
              child: InteractionLayer(
                tools: rig.tools,
                autofocus: autofocus,
                child: const SizedBox.expand(),
              ),
            ),
            const TextField(autofocus: true),
          ]),
        ),
      ));
      await tester.pump();
      final field =
          tester.widget<EditableText>(find.byType(EditableText)).focusNode;
      final primary = FocusManager.instance.primaryFocus;
      if (autofocus) {
        expect(primary?.debugLabel, 'InteractionLayer');
        expect(field.hasPrimaryFocus, isFalse);
      } else {
        expect(field.hasPrimaryFocus, isTrue);
      }
      await tester.tapAt(tester.getCenter(find.byType(InteractionLayer)));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'InteractionLayer',
          reason: 'the pointer-down request is unchanged');
      expect(field.hasPrimaryFocus, isFalse);
    });
  }
}
