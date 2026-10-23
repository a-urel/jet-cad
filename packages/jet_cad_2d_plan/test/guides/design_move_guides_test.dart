// Alignment guides in design moves (alignment guides spec, "The delta" and
// "Priority against the existing chain"; plan Task 6). Real pointer events
// go to the real plan.select of a real PlanController (tool_events.dart's
// driving, with Shift, Alt and touch added) over tables turned 30 and 90
// degrees and one mirrored, all around (6000, 4000), under a camera at
// scale 1.5, y flipped, off the origin. Every expectation is computed from
// the tables' transforms, not read back from the code under test.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Color, Offset;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, CatalogPolyline, CatalogSymbol, CatalogUnit, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/attach/attachment_registry.dart';
import 'package:jet_cad_2d_plan/src/guides/guide_painter.dart';
import 'package:jet_cad_2d_plan/src/guides/guide_references.dart';
import 'package:jet_cad_2d_plan/src/guides/guide_solver.dart';
import 'package:jet_cad_2d_plan/src/guides/plan_move_guides.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_2d_plan/src/tools/move_resolver.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';
import '../support/harness.dart';
import '../support/symbol_fixtures.dart' show box;
import '../support/unit_fixtures.dart';

// ---------------------------------------------------------------------------
// Geometry, computed independently of the code under test.

/// [tableSymbol]'s outline plus its two chairs, in definition space.
const _tableBox = SymbolBox(left: 300, right: 1500, front: -50, back: 1450);

/// The wall shelf's outline, in definition space (symbol_fixtures `box`).
const _shelfBox = SymbolBox(left: 150, right: 1750, front: 210, back: 960);

/// Camera scale 1.5, y flipped, off the origin.
final ViewportTransform _camera = ViewportTransform(
    worldToScreenMatrix: const Transform2(1.5, 0, 0, -1.5, -7000, 9000));
const double _scale = 1.5;

/// One pixel, in world millimetres.
const double _px = 1 / _scale;

final class _Box {
  _Box(this.minX, this.minY, this.maxX, this.maxY);

  final double minX, minY, maxX, maxY;
}

/// The AABB of [box]'s four corners through [t], point by point.
_Box _aabb(Transform2 t, [SymbolBox box = _tableBox]) {
  final pts = [
    t.transformPoint(Vector2(box.left, box.front)),
    t.transformPoint(Vector2(box.right, box.front)),
    t.transformPoint(Vector2(box.right, box.back)),
    t.transformPoint(Vector2(box.left, box.back)),
  ];
  return _Box(
    pts.map((p) => p.x).reduce(math.min),
    pts.map((p) => p.y).reduce(math.min),
    pts.map((p) => p.x).reduce(math.max),
    pts.map((p) => p.y).reduce(math.max),
  );
}

/// A point on a table's top edge, clear of its chairs: the press point.
Vector2 _grab(Transform2 t, [Vector2? def]) =>
    t.transformPoint(def ?? Vector2(1400, 1100));

List<double> _parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

Transform2 _shifted(Transform2 t, double dx, double dy) =>
    Transform2.translation(dx, dy).multiply(t);

/// [v] snapped to the grid of [step] anchored at [origin].
double _snap(double v, double origin, double step) =>
    origin + ((v - origin) / step).roundToDouble() * step;

const double _gridOriginX = -7425, _gridOriginY = -5250;

// ---------------------------------------------------------------------------
// The rig.

/// The last solution as it stood, copied (the painter's is reused).
final class _Seen {
  _Seen(GuideSolution s)
      : capturedX = s.capturedX,
        capturedY = s.capturedY,
        kindX = s.kindX,
        kindY = s.kindY,
        refX = s.refX,
        refY = s.refY,
        dx = s.dx,
        dy = s.dy,
        lines = [for (var i = 0; i < 4 * s.lineCount; i++) s.lines[i]],
        marks = [for (var i = 0; i < 4 * s.markCount; i++) s.marks[i]];

  final bool capturedX, capturedY;
  final GuideKind? kindX, kindY;
  final Handle? refX, refY;
  final double dx, dy;
  final List<double> lines, marks;

  int get lineCount => lines.length ~/ 4;
}

/// Pointer events for one tool under its context's camera.
final class _Driver {
  _Driver(this.tool, this.ctx);

  final Tool tool;
  final ToolContext ctx;

  ToolPointerEvent ev(Vector2 w,
      {int buttons = 0,
      bool shift = false,
      bool alt = false,
      bool touch = false}) {
    final cam = ctx.camera.value;
    final s = cam.worldToScreen(w);
    return ToolPointerEvent(
        screen: Offset(s.x, s.y),
        world: w,
        pointer: 7,
        buttons: buttons,
        shift: shift,
        control: false,
        meta: false,
        alt: alt,
        pickRadiusWorld: kPickRadiusPixels / cam.scale,
        kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse);
  }

  void tap(Vector2 w) {
    tool.onPointerMove(ev(w), ctx);
    tool.onPointerDown(ev(w, buttons: kPrimaryButton), ctx);
    tool.onPointerUp(ev(w), ctx);
  }

  void press(Vector2 w) {
    tool.onPointerMove(ev(w), ctx);
    tool.onPointerDown(ev(w, buttons: kPrimaryButton), ctx);
  }

  void move(Vector2 w,
          {bool shift = false, bool alt = false, bool touch = false}) =>
      tool.onPointerMove(
          ev(w, buttons: kPrimaryButton, shift: shift, alt: alt, touch: touch),
          ctx);

  void up(Vector2 w,
          {bool shift = false, bool alt = false, bool touch = false}) =>
      tool.onPointerUp(ev(w, shift: shift, alt: alt, touch: touch), ctx);

  /// Press at [from], eight moves to [to], [beforeUp], a release.
  void drag(Vector2 from, Vector2 to,
      {bool shift = false,
      bool alt = false,
      bool touch = false,
      void Function()? beforeUp}) {
    press(from);
    for (var i = 1; i <= 8; i++) {
      move(from + (to - from) * (i / 8), shift: shift, alt: alt, touch: touch);
    }
    beforeUp?.call();
    up(to, shift: shift, alt: alt, touch: touch);
  }
}

final class _Rig {
  _Rig(this.c, this.tables, this.lines)
      : d = _Driver(c.toolController.active, c.toolController.context);

  final PlanController c;
  final _Driver d;

  /// The placed tables, ascending by handle: the order they were placed.
  final List<Handle> tables;

  /// The root lines (walls), ascending by handle.
  final List<Handle> lines;

  Transform2 transformOf(Handle h) =>
      (c.document.tree[h]! as InstanceNode).transform; // the live transform

  PlanMoveGuides get guides => c.debugMoveGuides;

  /// The selection {[h]}.
  void select(Handle h) => c.selection.replace([SelectionKey.root(h)]);
}

/// A plan over the fx kit: [placements] (a symbol and a transform each,
/// ascending handles), [extra] to add walls and the like, the page grid
/// [grid] on (step 100) or off, object snap on or off.
_Rig _rig(List<(CatalogSymbol, Transform2)> placements,
    {bool grid = false,
    bool objectSnap = false,
    void Function(DraftDocument d)? extra}) {
  final text = planText([fxKit()], (d) {
    for (final (s, t) in placements) {
      placeUnit(d, s, transform: t);
    }
    extra?.call(d);
    d.commands.execute(SetComponentCommand<PageComponent>(
        d.rootHandle,
        d.components
            .get<PageComponent>(d.rootHandle)!
            .copyWith(snapToGrid: grid, gridStepMm: 100)));
  });
  final c = controllerFor(kits: [fxKit()], json: text);
  c.toolController.context.camera.value = _camera;
  if (!objectSnap) c.snap.toggleObjectSnap();
  expect(c.snap.objectSnap, objectSnap, reason: 'premise: object snap');
  c.selectTool('plan.select');
  final doc = c.document;
  final tables = [
    for (final n in doc.tree.nodes)
      if (n is InstanceNode && n.parent == doc.rootHandle) n.handle,
  ]..sort((a, b) => a.value.compareTo(b.value));
  final lines = linesOfDoc(doc);
  return _Rig(c, tables, lines);
}

List<Handle> linesOfDoc(DraftDocument d) {
  final e = d.entities;
  return [
    for (final s in e.liveSlots)
      if (e.kindAt(s) == EntityKind.line && e.ownerAt(s) == d.rootHandle)
        e.handleAt(s),
  ]..sort((a, b) => a.value.compareTo(b.value));
}

final double _rad30 = 30 * math.pi / 180;

/// A turned 30 degrees: the reference.
final Transform2 _tA = placementAt(6000, 4000, _rad30);

/// B turned 90 degrees: the mover.
final Transform2 _tB = placementAt(9000, 6800, math.pi / 2);

/// C mirrored and turned: a second reference, away from the others.
final Transform2 _tC = placementAt(3400, 1800, 0.2, mirrored: true);

_Rig _standard({bool grid = false, bool objectSnap = false}) =>
    _rig([(tableSymbol(), _tA), (tableSymbol(), _tB), (tableSymbol(), _tC)],
        grid: grid, objectSnap: objectSnap);

/// What one drag of table B did.
typedef _Out = ({Transform2 b, _Seen? seen, Vector2 from, Vector2 to});

/// Presses on B, drags to [to] and releases; [guides] false toggles them
/// off first. [seen] is the solution just before the release.
_Out _dragB(_Rig r, Vector2 to,
    {Vector2? from,
    bool guides = true,
    bool shift = false,
    bool alt = false,
    bool touch = false,
    Handle? mover}) {
  final b = mover ?? r.tables[1];
  final start = from ?? _grab(r.transformOf(b));
  if (!guides) r.c.alignmentGuides.toggle();
  r.select(b);
  _Seen? seen;
  r.d.drag(start, to,
      shift: shift,
      alt: alt,
      touch: touch,
      beforeUp: () => seen = _Seen(r.guides.debugSolution));
  return (b: r.transformOf(b), seen: seen, from: start, to: to);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('premise: three tables off the origin, a camera at scale 1.5', () {
    final r = _standard();
    expect(r.tables, hasLength(3));
    expect(_camera.scale, closeTo(1.5, 1e-12));
    final a = _aabb(_tA), b = _aabb(_tB);
    // Tables clear of each other: a drag in these tests moves B alone.
    expect(a.maxX < b.minX || b.maxX < a.minX || a.maxY < b.minY, isTrue);
    for (final t in [_tA, _tB, _tC]) {
      expect(t.e.abs() + t.f.abs(), greaterThan(1000), reason: 'off origin');
    }
    expect(r.c.alignmentGuides.on, isTrue);
  });

  test(
      'DG-1 a drag to 3 px from table A\'s left edge snaps B\'s box to it '
      'exactly; the commit is the preview; one undo restores B with ==, '
      'a redo gives the guided one', () {
    final r = _standard();
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final tB0 = r.transformOf(r.tables[1]);
    final from = _grab(tB0);
    final to =
        from + Vector2(a.minX - b0.minX - 3 * _px, a.maxY + 1000 - b0.minY);
    final out = _dragB(r, to, from: from);
    final seen = out.seen!;
    // Captured on x alone, to A's edge, drawn once.
    expect(seen.capturedX, isTrue);
    expect(seen.capturedY, isFalse);
    expect(seen.kindX, GuideKind.edge);
    expect(seen.refX, r.tables[0]);
    expect(seen.dx, closeTo(3 * _px, 1e-9));
    expect(seen.lineCount, 1);
    // The line: vertical (axis 0) at A's left edge, from A's bottom to B's
    // top as it ended.
    final bEnd = _aabb(out.b);
    expect(seen.lines[0], 0);
    expect(seen.lines[1], closeTo(a.minX, 1e-9));
    expect(seen.lines[2], closeTo(a.minY, 1e-9));
    expect(seen.lines[3], closeTo(bEnd.maxY, 1e-9));
    // The box landed on A's edge, y as the pointer left it.
    expect(bEnd.minX, closeTo(a.minX, 1e-9));
    expect(bEnd.minY, closeTo(a.maxY + 1000, 1e-9));
    // The commit is the preview: the target was raw + the captured offset.
    expect(out.b.e - tB0.e, closeTo(to.x + seen.dx - from.x, 1e-9));
    expect(out.b.f - tB0.f, closeTo(to.y - from.y, 1e-9));
    // One command: one undo restores the exact transform, a redo the guided.
    final guided = _parts(out.b);
    r.c.undo();
    expect(_parts(r.transformOf(r.tables[1])), _parts(tB0));
    r.c.redo();
    expect(_parts(r.transformOf(r.tables[1])), guided);
  });

  test(
      'DG-2 the same drag 7 px away captures nothing and equals the drag '
      'with the guides off (differential)', () {
    Vector2 target(_Rig r) {
      final a = _aabb(_tA), b0 = _aabb(_tB);
      return _grab(r.transformOf(r.tables[1])) +
          Vector2(a.minX - b0.minX - 7 * _px, a.maxY + 1000 - b0.minY);
    }

    final on = _standard();
    final off = _standard();
    final guided = _dragB(on, target(on));
    final plain = _dragB(off, target(off), guides: false);
    expect(guided.seen!.capturedX, isFalse);
    expect(guided.seen!.capturedY, isFalse);
    expect(guided.seen!.lineCount, 0);
    expect(_parts(guided.b), _parts(plain.b));
    // A positive control: the guides were on in the first run and 3 px
    // would have captured (DG-1).
    expect(on.c.alignmentGuides.on, isTrue);
    expect(off.c.alignmentGuides.on, isFalse);
  });

  test('DG-3 a fingertip\'s aperture is 10 px: 7 px away captures', () {
    final r = _standard();
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final to = _grab(r.transformOf(r.tables[1])) +
        Vector2(a.minX - b0.minX - 7 * _px, a.maxY + 1000 - b0.minY);
    final out = _dragB(r, to, touch: true);
    expect(out.seen!.capturedX, isTrue);
    expect(_aabb(out.b).minX, closeTo(a.minX, 1e-9));
  });

  test(
      'DG-4 grid mixing: with grid snap on, an x capture lands on A\'s edge '
      'and y stays on the grid; the jump is at most half a step plus the '
      'aperture', () {
    final on = _standard(grid: true);
    final off = _standard(grid: true);
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final from = _grab(on.transformOf(on.tables[1]));
    // The base is the press snapped to the grid.
    final base = Vector2(
        _snap(from.x, _gridOriginX, 100), _snap(from.y, _gridOriginY, 100));
    expect((base - from).length, greaterThan(5), reason: 'premise: off grid');
    final to = Vector2(base.x + (a.minX - 2 * _px - b0.minX),
        base.y + a.maxY + 1000 - b0.minY);
    final guided = _dragB(on, to, from: from);
    final plain = _dragB(off, to, from: from, guides: false);
    expect(guided.seen!.capturedX, isTrue);
    expect(guided.seen!.capturedY, isFalse, reason: 'premise: x only');
    expect(_aabb(guided.b).minX, closeTo(a.minX, 1e-9));
    // y: the chain's, a whole number of steps.
    final tB0 = _tB;
    final dy = guided.b.f - tB0.f;
    expect(dy, closeTo((dy / 100).roundToDouble() * 100, 1e-9));
    expect(guided.b.f, plain.b.f, reason: 'y equals the unguided drag');
    // The jump when the capture switches on.
    final jump = (guided.b.e - plain.b.e).abs();
    expect(jump, lessThanOrEqualTo(50 + 6 * _px + 1e-9));
    expect(jump, greaterThan(0), reason: 'the capture changed x');
  });

  test(
      'DG-5 an off-grid press: the base is the snapped press, and the '
      'guided edge still lands exactly', () {
    final r = _standard(grid: true);
    final a = _aabb(_tA), b0 = _aabb(_tB);
    // A press whose snapped base differs from the raw press by tens of mm
    // on both axes.
    final from = _grab(r.transformOf(r.tables[1]));
    final base = Vector2(
        _snap(from.x, _gridOriginX, 100), _snap(from.y, _gridOriginY, 100));
    expect((base.x - from.x).abs(), greaterThan(10));
    final to = Vector2(base.x + (a.minX - 1.5 * _px - b0.minX),
        base.y + a.maxY + 1000 - b0.minY);
    final out = _dragB(r, to, from: from);
    expect(out.seen!.capturedX, isTrue);
    expect(_aabb(out.b).minX, closeTo(a.minX, 1e-9));
  });

  test(
      'DG-6 spacing recheck reads the chain\'s y: a between capture whose '
      'row stops overlapping once the grid moves y is dropped; the same '
      'drag with y left alone keeps it', () {
    // L = A, R = C' on the right at 2400 mm; B between with 2 mm off.
    _Rig build(double rawYPhase) {
      final r0 = _rig([(tableSymbol(), _tA), (tableSymbol(), _tB)], grid: true);
      final a = _aabb(_tA), b0 = _aabb(_tB);
      final from = _grab(r0.transformOf(r0.tables[1]));
      final baseY = _snap(from.y, _gridOriginY, 100);
      // raw y puts B.minY a sliver (20 mm) below A's top.
      var rawY = a.maxY - 20 - b0.minY + baseY;
      // Tweak A's y so that rawY sits [rawYPhase] past a grid line.
      final phase = (rawY - _gridOriginY) % 100;
      final slide = ((rawYPhase - phase) % 100 + 100) % 100;
      final tA = _shifted(_tA, 0, slide);
      final a2 = _aabb(tA);
      rawY = a2.maxY - 20 - b0.minY + baseY;
      final cBox0 = _aabb(_tC);
      // C' right of A with a gap of 2400, its y range covering B's.
      var tC = _tC;
      tC =
          _shifted(tC, a2.maxX + 2400 - cBox0.minX, a2.maxY - 100 - cBox0.minY);
      return _rig(
          [(tableSymbol(), tA), (tableSymbol(), _tB), (tableSymbol(), tC)],
          grid: true);
    }

    Vector2 to(_Rig r) {
      final a = _aabb(r.transformOf(r.tables[0]));
      final c = _aabb(r.transformOf(r.tables[2]));
      final b0 = _aabb(_tB);
      final from = _grab(r.transformOf(r.tables[1]));
      final base = Vector2(
          _snap(from.x, _gridOriginX, 100), _snap(from.y, _gridOriginY, 100));
      // B.minX 2 mm short of centring in the gap: o = +2.
      final minXWanted = (a.maxX + c.minX - (b0.maxX - b0.minX)) / 2 - 2;
      final rawY = a.maxY - 20 - b0.minY + base.y;
      return Vector2(base.x + (minXWanted - b0.minX), rawY);
    }

    // Phase 70: the grid pulls y +30, B.minY ends 10 above A's top: the row
    // no longer holds.
    final moved = build(70);
    final movedTo = to(moved);
    final shift = _snap(movedTo.y, _gridOriginY, 100) - movedTo.y;
    expect(shift, closeTo(30, 1e-6), reason: 'premise: the grid moves y 30');
    final guided = _dragB(moved, movedTo);
    final plain = _dragB(build(70), movedTo, guides: false);
    expect(guided.seen!.capturedX, isFalse,
        reason: 'the spacing capture is dropped');
    expect(_parts(guided.b), _parts(plain.b));

    // Phase 0: the grid leaves y; the row holds; B is centred in the gap.
    final kept = build(0);
    final keptTo = to(kept);
    expect(_snap(keptTo.y, _gridOriginY, 100) - keptTo.y, closeTo(0, 1e-6),
        reason: 'premise: the grid leaves y');
    final held = _dragB(kept, keptTo);
    expect(held.seen!.capturedX, isTrue);
    expect(held.seen!.kindX, GuideKind.between);
    final a = _aabb(kept.transformOf(kept.tables[0]));
    final c = _aabb(kept.transformOf(kept.tables[2]));
    final b = _aabb(held.b);
    expect(b.minX - a.maxX, closeTo(c.minX - b.maxX, 1e-9));
    expect(held.seen!.marks, hasLength(8), reason: 'two gap marks');
  });

  test(
      'DG-7 guides beat a pointer object snap: a wall endpoint 3 px from '
      'the pointer does not pull x off the guide, on three moves 1 px '
      'apart; y keeps the object snap', () {
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final from = _grab(_tB);
    final to =
        from + Vector2(a.minX - b0.minX - 2 * _px, a.maxY + 1000 - b0.minY);
    // The wall's end: 3 px from the pointer, x short of the guide's x.
    final end = to + Vector2(-1.0 * _px, 2.8 * _px);
    expect((end - to).length, closeTo(3 * _px, 0.3 * _px));
    _Rig build() =>
        _rig([(tableSymbol(), _tA), (tableSymbol(), _tB), (tableSymbol(), _tC)],
            objectSnap: true,
            extra: (d) => addLine(d, end, end + Vector2(2500, 0)));

    final r = build();
    final tB0 = r.transformOf(r.tables[1]);
    r.select(r.tables[1]);
    r.d.press(from);
    // Three moves, 1 px apart: each gives B.minX == A.minX on the preview.
    for (final k in [-1, 0, 1]) {
      final p = to + Vector2(k * _px, 0);
      r.d.move(p);
      final s = r.guides.debugSolution;
      expect(s.capturedX, isTrue, reason: 'move $k');
      final minX = b0.minX + (p.x + s.dx - from.x);
      expect(minX, closeTo(a.minX, 1e-9), reason: 'move $k lands on the guide');
    }
    r.d.up(to);
    final guided = r.transformOf(r.tables[1]);
    expect(_aabb(guided).minX, closeTo(a.minX, 1e-9));
    // y: the object snap's (the wall's end), not the pointer's.
    expect(guided.f - tB0.f, closeTo(end.y - from.y, 1e-9));

    // A control: without guides the wall's end wins on both axes.
    final off = build();
    final plain = _dragB(off, to, guides: false);
    expect(plain.b.e - _tB.e, closeTo(end.x - from.x, 1e-9));
    expect(plain.b.f - _tB.f, closeTo(end.y - from.y, 1e-9));
  });

  test(
      'DG-8 Shift: a mostly horizontal drag keeps y at the base exactly and '
      'draws no y line, though y would have captured', () {
    final r = _standard();
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final tB0 = r.transformOf(r.tables[1]);
    final from = _grab(tB0);
    // The pointer ends 1.5 mm off A's top edge on y (a capture if free) and
    // 2 mm off its left edge on x.
    final to =
        from + Vector2(a.minX - b0.minX - 2 * _px, a.maxY + 1.5 - b0.minY);
    expect((to.x - from.x).abs(), greaterThan((to.y - from.y).abs()),
        reason: 'premise: mostly horizontal');
    final out = _dragB(r, to, from: from, shift: true);
    expect(out.seen!.capturedX, isTrue);
    expect(out.seen!.capturedY, isFalse);
    for (var i = 0; i < out.seen!.lineCount; i++) {
      expect(out.seen!.lines[4 * i], 0, reason: 'only vertical lines');
    }
    expect(out.b.f, tB0.f, reason: 'y is the base\'s, exactly');
    expect(_aabb(out.b).minX, closeTo(a.minX, 1e-9));

    // Unpinned (no Shift) the same pointer captures y.
    final free = _standard();
    final loose = _dragB(free, to, from: from);
    expect(loose.seen!.capturedY, isTrue, reason: 'positive control');
  });

  test('DG-9 Alt held: the move equals the guides-off move', () {
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final on = _standard();
    final off = _standard();
    final to = _grab(_tB) +
        Vector2(a.minX - b0.minX - 2 * _px, a.maxY + 1000 - b0.minY);
    final alt = _dragB(on, to, alt: true);
    final plain = _dragB(off, to, guides: false);
    expect(alt.seen!.lineCount, 0);
    expect(_parts(alt.b), _parts(plain.b));
    // Positive control: without Alt the capture is there.
    final held = _dragB(_standard(), to);
    expect(held.seen!.capturedX, isTrue);
  });

  test(
      'DG-10 setting off: with the canvas allowance off nothing captures '
      'and the move is the guides-off move', () {
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final r = _standard();
    final off = _standard();
    final to = _grab(_tB) +
        Vector2(a.minX - b0.minX - 2 * _px, a.maxY + 1000 - b0.minY);
    r.c.alignmentGuidesAllowed = false;
    expect(r.c.alignmentGuides.on, isFalse);
    final out = _dragB(r, to);
    final plain = _dragB(off, to, guides: false);
    expect(out.seen!.lineCount, 0);
    expect(_parts(out.b), _parts(plain.b));
  });

  test(
      'DG-11 toggled mid-drag with no pointer move: the preview falls back '
      'to the chain\'s point at once, and comes back on the next toggle', () {
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final r = _standard();
    final from = _grab(_tB);
    final to =
        from + Vector2(a.minX - b0.minX - 2 * _px, a.maxY + 1000 - b0.minY);
    r.select(r.tables[1]);
    r.d.press(from);
    for (var i = 1; i <= 8; i++) {
      r.d.move(from + (to - from) * (i / 8));
    }
    final s = r.guides.debugSolution;
    expect(s.capturedX, isTrue, reason: 'premise: a capture is shown');
    expect(s.lineCount, 1);
    r.c.alignmentGuides.toggle();
    expect(r.c.alignmentGuides.on, isFalse);
    expect(s.capturedX, isFalse);
    expect(s.lineCount, 0, reason: 'nothing drawn after the toggle');
    r.c.alignmentGuides.toggle();
    expect(s.capturedX, isTrue, reason: 'back on, re-targeted');
    expect(s.lineCount, 1);
    r.d.up(to);
  });

  test(
      'DG-12 a selection of a table and a wall line moves as it does with '
      'the guides off; so does one of a table and a group', () {
    final a = _aabb(_tA), b0 = _aabb(_tB);
    final to = _grab(_tB) +
        Vector2(a.minX - b0.minX - 2 * _px, a.maxY + 1000 - b0.minY);
    Handle? group;
    void walls(DraftDocument d) {
      addLine(d, Vector2(2000.5, 900.25), Vector2(3100.75, 1300.5));
      // A root group (a wall's shape) holding a line of its own.
      group = d.handleSeed.next();
      d.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: group!,
            parent: d.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        AddEntityCommand(
            record: draftRecord(d.handleSeed.next(), group!, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(
                Vector2(2200.5, 1900.25), Vector2(2900.75, 1800.5))),
      ], label: 'group'));
    }

    _Rig build() =>
        _rig([(tableSymbol(), _tA), (tableSymbol(), _tB), (tableSymbol(), _tC)],
            extra: walls);

    for (final withGroup in [false, true]) {
      final on = build();
      final off = build();
      final other = withGroup ? group! : on.lines.first;
      final otherOff = withGroup ? group! : off.lines.first;
      on.c.selection
          .replace([SelectionKey.root(on.tables[1]), SelectionKey.root(other)]);
      off.c.selection.replace(
          [SelectionKey.root(off.tables[1]), SelectionKey.root(otherOff)]);
      off.c.alignmentGuides.toggle();
      var onSeen = 0;
      on.d.drag(_grab(_tB), to,
          beforeUp: () => onSeen = on.guides.debugSolution.lineCount);
      off.d.drag(_grab(_tB), to);
      expect(onSeen, 0, reason: 'not eligible (group: $withGroup)');
      expect(_parts(on.transformOf(on.tables[1])),
          _parts(off.transformOf(off.tables[1])),
          reason: 'group: $withGroup');
      // The selection really moved with the table.
      expect(on.transformOf(on.tables[1]).e, isNot(_tB.e));
    }

    // A positive control: the table alone, the same drag, captures.
    final alone = _dragB(build(), to);
    expect(alone.seen!.capturedX, isTrue);
  });

  test(
      'DG-13 a plan whose only other objects are seats and walls draws no '
      'guide and moves as it does with the guides off', () {
    final seat = CatalogSymbol(
      key: 'fx.seat.plain',
      name: 'Test seat',
      category: 'Tests',
      tags: const ['seat'],
      unit: const CatalogUnit(kind: UnitKinds.seat, capacity: 1),
      base: (400, 300),
      shapes: const [
        CatalogPolyline([(200, 100), (600, 100), (600, 500), (200, 500)],
            closed: true),
      ],
    );
    // A seat turned 30 degrees whose box edge is 2 mm from B's after the
    // drag below; and a wall.
    final seatBoxDef =
        const SymbolBox(left: 200, right: 600, front: 100, back: 500);
    var tSeat = placementAt(6000, 4000, _rad30);
    final b0 = _aabb(_tB);
    final to = _grab(_tB) + Vector2(-2500, -2300);
    final bEnd =
        _Box(b0.minX - 2500, b0.minY - 2300, b0.maxX - 2500, b0.maxY - 2300);
    final sb = _aabb(tSeat, seatBoxDef);
    tSeat = _shifted(tSeat, bEnd.minX - 2 * _px - sb.minX, 0);
    _Rig build() => _rig([(seat, tSeat), (tableSymbol(), _tB)],
        extra: (d) => addLine(d, Vector2(1000, 100), Vector2(2000, 150)));

    final on = build();
    final off = build();
    final mover = on.tables[1];
    final guided = _dragB(on, to, mover: mover);
    final plain = _dragB(off, to, mover: off.tables[1], guides: false);
    expect(guided.seen!.lineCount, 0);
    expect(guided.seen!.capturedX, isFalse);
    expect(_parts(guided.b), _parts(plain.b));
  });

  test(
      'DG-14 a wall-attaching symbol over a wall: the attachment\'s '
      'transform is committed and no guide is drawn', () {
    final lib =
        SymbolLibrary.decode(encodeLibrary(Catalog(kit: 'demo', symbols: [
      box('demo.shelf.wall', 'Wall shelf', 'Storage', ['shelf'],
          attachTo: ['test-edge'], base: (950, 410)),
      box('demo.table.free', 'Table', 'Dining', ['table'], base: (950, 410)),
    ])));
    SymbolEntry entry(String key) =>
        lib.entries.singleWhere((e) => e.symbol.key == key);

    final doc = DraftDocument.empty();
    registerKitComponents(doc.components);
    doc.header.units = DrawingUnits.millimeters;
    // A free symbol turned 90 degrees (the reference), a shelf turned 30
    // degrees and mirrored (the mover), both around (6000, 4000).
    final tFree = placementAt(6000, 4000, math.pi / 2, baseX: 950, baseY: 410);
    final tShelf =
        placementAt(9500, 7000, _rad30, mirrored: true, baseX: 950, baseY: 410);
    doc.commands.execute(placeSymbol(doc, entry('demo.table.free'),
        at: Vector2.zero(), transform: tFree));
    doc.commands.execute(placeSymbol(doc, entry('demo.shelf.wall'),
        at: Vector2.zero(), transform: tShelf));
    final nodes = [
      for (final n in doc.tree.nodes)
        if (n is InstanceNode) n.handle,
    ]..sort((a, b) => a.value.compareTo(b.value));
    final free = nodes[0], shelf = nodes[1];
    expect((doc.tree[shelf]! as InstanceNode).transform.e, tShelf.e,
        reason: 'premise: placed by the transform');

    final index = SpatialIndex(doc);
    final selection = SelectionController(doc);
    final camera = CameraController(_camera);
    final snap = SnapSettings();
    final ctx = ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap);
    final registry = PlanAttachmentRegistry(report: (_) {});
    Attachment? Function(AttachmentQuery q)? answer;
    registry.add(
        'demo',
        (_) => RecordingProvider('test-edge', (q) => answer?.call(q)),
        _NoServices());
    final locked = ValueNotifier<Set<Handle>>(const {});
    final units = UnitIndexCache(doc,
        catalog: ParametricCatalog(),
        locks: LockSet.scan(doc, (_) => true),
        locked: locked);
    final settings = PlanGuideSettings();
    final guides = PlanMoveGuides(
        references: GuideReferenceCache(doc, units: () => units),
        settings: settings,
        strokePixels: () => 1,
        movable: (h) => doc.tree[h] is InstanceNode);
    final tool = SelectTool(
        moveResolver: PlanMoveResolver(
            attachments: () => registry, canRotate: () => true),
        moveAdjuster: guides);
    addTearDown(() {
      tool.dispose();
      registry.dispose();
      units.dispose();
      locked.dispose();
      settings.dispose();
      snap.dispose();
      selection.dispose();
      index.dispose();
      camera.dispose();
    });

    final a = _aabb(tFree, _shelfBox), s0 = _aabb(tShelf, _shelfBox);
    final from = tShelf.transformPoint(Vector2(950, 585));
    final to =
        from + Vector2(a.minX - s0.minX - 2 * _px, a.maxY + 1000 - s0.minY);
    final d = _Driver(tool, ctx);

    // Without an attachment the guide is there ...
    selection.replace([SelectionKey.root(shelf)]);
    var lines = -1;
    d.drag(from, to, beforeUp: () => lines = guides.debugSolution.lineCount);
    expect(lines, 1, reason: 'positive control: the guide is drawn');
    final plainShelf = (doc.tree[shelf]! as InstanceNode).transform;
    expect(_aabb(plainShelf, _shelfBox).minX, closeTo(a.minX, 1e-9));
    doc.commands.undo();

    // ... and with one that wins, the attachment replaces the move.
    final placed = attachment(Transform2.translation(8000.5, 6000.25),
        Vector2(8010.25, 6020.5), 'face');
    answer = (_) => placed;
    var attachedLines = -1;
    selection.replace([SelectionKey.root(shelf)]);
    d.drag(from, to,
        beforeUp: () => attachedLines = guides.debugSolution.lineCount);
    expect(attachedLines, 0, reason: 'suppressed: no guide for the event');
    expect(_parts((doc.tree[shelf]! as InstanceNode).transform),
        _parts(placed.transform));
    expect(free, isNot(shelf));
  });

  test(
      'DG-15 an uncaptured axis keeps the chain\'s value bit for bit, '
      'object-snapped or not; the captured axis is raw + the offset', () {
    final doc = unitPlan();
    final a = placeUnit(doc, tableSymbol(), transform: _tA);
    final b = placeUnit(doc, tableSymbol(), transform: _tB);
    final index = SpatialIndex(doc);
    final selection = SelectionController(doc);
    final camera = CameraController(_camera);
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final locked = ValueNotifier<Set<Handle>>(const {});
    final units = UnitIndexCache(doc,
        catalog: ParametricCatalog(),
        locks: LockSet.scan(doc, (_) => true),
        locked: locked);
    final settings = PlanGuideSettings();
    final guides = PlanMoveGuides(
        references: GuideReferenceCache(doc, units: () => units),
        settings: settings,
        strokePixels: () => 1,
        movable: (h) => doc.tree[h] is InstanceNode);
    addTearDown(() {
      units.dispose();
      locked.dispose();
      settings.dispose();
      selection.dispose();
      index.dispose();
      camera.dispose();
    });
    // y values for which raw + (chain - raw) is not the chain's value: only
    // a target that is never recomputed survives (premise, in doubles).
    const rawY = 1.7295576608016034, chainY = 240.60325381162752;
    expect(rawY + (chainY - rawY), isNot(chainY), reason: 'premise');
    final ab = _aabb(_tA), bb = _aabb(_tB);
    final base = _grab(_tB);
    final raw = Vector2(base.x + (ab.minX - 2 * _px - bb.minX), rawY);
    final target = Vector2(raw.x + 31.5, chainY);
    guides.begin(ctx, {b});
    guides.adjust(ctx,
        raw: raw,
        base: base,
        orthoBase: null,
        objectSnapped: true,
        touch: false,
        alt: false,
        target: target);
    final s = guides.debugSolution;
    expect(s.capturedX, isTrue);
    expect(s.refX, a);
    expect(s.capturedY, isFalse, reason: 'premise: x only');
    expect(target.x, raw.x + s.dx, reason: 'the guide replaces x');
    expect(target.y, chainY, reason: 'bit for bit, not raw + (chain - raw)');
    guides.end();
  });

  // -------------------------------------------------------------------------
  // The painter.

  group('GuidePainter', () {
    final turned = Transform2.translation(300, 200)
        .multiply(Transform2.rotation(0.52))
        .multiply(Transform2.scale(1.5, -1.5))
        .multiply(Transform2.translation(-5000, -3500));

    Offset screen(Transform2 m, double x, double y) =>
        Offset(m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f);

    ui.Canvas canvas() => ui.Canvas(ui.PictureRecorder());

    test(
        'a line overhangs 8 px past each end along its own screen direction '
        'under a rotated camera', () {
      final s = GuideSolution()
        ..lines.setAll(0, [0, 5000, 3000, 4000])
        ..lineCount = 1;
      final p = GuidePainter()
        ..paint(canvas(), turned, s,
            color: const Color(0xFFE0218A), strokePixels: 1);
      final p0 = screen(turned, 5000, 3000), p1 = screen(turned, 5000, 4000);
      final len = (p1 - p0).distance;
      final dir = (p1 - p0) / len;
      final f = p.debugPoints;
      expect(f[0], closeTo(p0.dx - 8 * dir.dx, 1e-3));
      expect(f[1], closeTo(p0.dy - 8 * dir.dy, 1e-3));
      expect(f[2], closeTo(p1.dx + 8 * dir.dx, 1e-3));
      expect(f[3], closeTo(p1.dy + 8 * dir.dy, 1e-3));
      // A rotated camera makes the line diagonal: neither end shares an
      // axis with the other.
      expect((f[0] - f[2]).abs(), greaterThan(1));
      expect((f[1] - f[3]).abs(), greaterThan(1));
      // Everything after is a degenerate segment.
      for (var i = 4; i < f.length; i += 4) {
        expect(f[i], f[i + 2]);
        expect(f[i + 1], f[i + 3]);
      }
    });

    test(
        'a gap mark is a segment across the gap with a 4 px tick at each '
        'end, perpendicular on screen', () {
      final s = GuideSolution()
        ..marks.setAll(0, [0, 2000, 3000, 4500])
        ..markCount = 1;
      final p = GuidePainter()
        ..paint(canvas(), turned, s,
            color: const Color(0xFFE0218A), strokePixels: 1);
      final g0 = screen(turned, 2000, 4500), g1 = screen(turned, 3000, 4500);
      final f = p.debugPoints;
      expect(f[0], closeTo(g0.dx, 1e-3));
      expect(f[1], closeTo(g0.dy, 1e-3));
      expect(f[2], closeTo(g1.dx, 1e-3));
      expect(f[3], closeTo(g1.dy, 1e-3));
      final dir = (g1 - g0) / (g1 - g0).distance;
      for (var k = 1; k <= 2; k++) {
        final o = 4 * k;
        final centre = Offset((f[o] + f[o + 2]) / 2, (f[o + 1] + f[o + 3]) / 2);
        final want = k == 1 ? g0 : g1;
        expect(centre.dx, closeTo(want.dx, 1e-3), reason: 'tick $k centre');
        expect(centre.dy, closeTo(want.dy, 1e-3));
        final t = Offset(f[o + 2] - f[o], f[o + 3] - f[o + 1]);
        expect(t.distance, closeTo(8, 1e-3), reason: 'tick $k: 4 px each way');
        expect(t.dx * dir.dx + t.dy * dir.dy, closeTo(0, 1e-3),
            reason: 'tick $k is perpendicular');
      }
    });

    test('a shorter solution after a longer one leaves nothing stale', () {
      final p = GuidePainter();
      final s = GuideSolution()
        ..lines.setAll(0, [0, 5000, 3000, 4000, 1, 3500, 2000, 6000])
        ..lineCount = 2;
      p.paint(canvas(), turned, s,
          color: const Color(0xFFE0218A), strokePixels: 1);
      expect(p.debugPoints[4], isNot(p.debugPoints[6]), reason: 'premise');
      s.lineCount = 1;
      p.paint(canvas(), turned, s,
          color: const Color(0xFFE0218A), strokePixels: 1);
      expect(p.debugPoints[4], p.debugPoints[6]);
      expect(p.debugPoints[5], p.debugPoints[7]);
    });

    test('a full solution fits the list: 16 lines and 16 marks', () {
      final s = GuideSolution()
        ..lineCount = kGuideCapacity
        ..markCount = kGuideCapacity;
      for (var i = 0; i < kGuideCapacity; i++) {
        s.lines.setAll(4 * i, [i.isEven ? 0 : 1, 5000.0 + i, 3000, 4000]);
        s.marks.setAll(4 * i, [i.isEven ? 0 : 1, 2000, 3000, 4500.0 + i]);
      }
      final p = GuidePainter()
        ..paint(canvas(), turned, s,
            color: const Color(0xFFE0218A), strokePixels: 1);
      expect(p.debugPoints, isA<Float32List>());
      expect(p.debugPoints.length, 4 * (kGuideCapacity + 3 * kGuideCapacity));
    });
  });
}

final class _NoServices implements PlanServices {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('a provider factory read the services');
}
