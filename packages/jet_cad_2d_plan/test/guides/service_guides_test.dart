// Alignment guides in service drags (alignment guides spec, "The delta:
// Move" and "Modes"; plan Task 8). Real pointer and key events go to the
// real ServiceTool of a real PlanController in service, over tables turned
// 30 degrees (one mirrored) around (6000, 4000), under a camera at scale
// 1.5, y flipped, off the origin. Every expectation is computed from the
// tables' transforms, not read back from the code under test.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolBox;
import 'package:jet_cad_2d_plan/src/guides/guide_solver.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_state.dart' show UnitGroup;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_fixture.dart' show serviceFixture;
import '../support/service_rig.dart';
import '../support/unit_fixtures.dart';

/// [tableSymbol]'s outline plus its two chairs, in definition space.
const _tableBox = SymbolBox(left: 300, right: 1500, front: -50, back: 1450);

/// Camera scale 1.5, y flipped, off the origin.
final ViewportTransform _camera = ViewportTransform(
    worldToScreenMatrix: const Transform2(1.5, 0, 0, -1.5, -7000, 9000));
const double _scale = 1.5;

/// One pixel, in world millimetres.
const double _px = 1 / _scale;

final double _rad30 = 30 * math.pi / 180;

/// The AABB of the table box through [t]: (minX, minY, maxX, maxY), point
/// by point.
List<double> _aabb(Transform2 t) {
  final pts = [
    t.transformPoint(Vector2(_tableBox.left, _tableBox.front)),
    t.transformPoint(Vector2(_tableBox.right, _tableBox.front)),
    t.transformPoint(Vector2(_tableBox.right, _tableBox.back)),
    t.transformPoint(Vector2(_tableBox.left, _tableBox.back)),
  ];
  return [
    pts.map((p) => p.x).reduce(math.min),
    pts.map((p) => p.y).reduce(math.min),
    pts.map((p) => p.x).reduce(math.max),
    pts.map((p) => p.y).reduce(math.max),
  ];
}

double _cx(List<double> b) => (b[0] + b[2]) / 2;
double _cy(List<double> b) => (b[1] + b[3]) / 2;

/// The press point of a table: its base point, inside its top.
Vector2 _grab(Transform2 t) => t.transformPoint(Vector2(900, 700));

List<double> _parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

final Transform2 _tA = placementAt(6000, 4000, _rad30);
final Transform2 _tB = placementAt(9000, 6800, math.pi / 2, mirrored: true);
final Transform2 _tC = placementAt(3400, 1800, _rad30);

/// Tables '1', '2', ... by [placements]; those in [hidden] sit on a hidden
/// layer, those in [floor] on a visible layer 'Floor' a test may hide.
String _planOf(List<Transform2> placements,
        {Set<int> hidden = const {}, Set<int> floor = const {}}) =>
    planText([fxKit()], (d) {
      final off = hidden.isEmpty ? null : addLayer(d, 'Off', visible: false);
      final on = floor.isEmpty ? null : addLayer(d, 'Floor');
      for (final (i, t) in placements.indexed) {
        final n = i + 1;
        final h = placeUnit(d, tableSymbol(),
            transform: t,
            layer: hidden.contains(n)
                ? off
                : floor.contains(n)
                    ? on
                    : null);
        addUnitLabel(d, h, '$n');
      }
    });

final class _Rig {
  _Rig(this.r) {
    r.c.camera.value = _camera;
    expect(r.c.camera.value.scale, closeTo(_scale, 1e-12), reason: 'premise');
    for (final n in r.doc.tree.nodes) {
      if (n is InstanceNode && n.parent == r.doc.rootHandle) {
        tables.add(n.handle);
      }
    }
    tables.sort((a, b) => a.value.compareTo(b.value));
    r.tool.addListener(() => notified++);
  }

  final ServiceRig r;
  final List<Handle> tables = [];
  int notified = 0;

  Transform2 transformOf(Handle h) => r.node(h).transform;
  GuideSolution get sol => r.tool.debugSolution;

  /// The drag's translation as the outlines follow it.
  Transform2 get preview => r.tool.selectionPreviewTransform!;

  ToolPointerEvent ev(Vector2 w,
          {int buttons = kPrimaryButton,
          bool alt = false,
          bool touch = false}) =>
      ToolPointerEvent(
        screen: r.screen(w),
        world: w.clone(),
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: alt,
        pickRadiusWorld: 6 / r.c.camera.value.scale,
        kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
        timeStamp: Duration.zero,
      );

  void down(Vector2 w) => r.tool.onPointerDown(ev(w), r.ctx);
  void move(Vector2 w, {bool alt = false, bool touch = false}) =>
      r.tool.onPointerMove(ev(w, alt: alt, touch: touch), r.ctx);
  void up(Vector2 w) => r.tool.onPointerUp(ev(w, buttons: 0), r.ctx);

  /// Presses at [from] and moves to [to] in two steps; the release is the
  /// caller's.
  void hold(Vector2 from, Vector2 to, {bool touch = false}) {
    down(from);
    move(from + (to - from) * 0.5, touch: touch);
    move(to, touch: touch);
  }

  KeyEventResult alt({required bool down}) {
    final e = down
        ? const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.altLeft,
            physicalKey: PhysicalKeyboardKey.altLeft,
            timeStamp: Duration.zero)
        : const KeyUpEvent(
            logicalKey: LogicalKeyboardKey.altLeft,
            physicalKey: PhysicalKeyboardKey.altLeft,
            timeStamp: Duration.zero);
    return r.tool.onKey(e, r.ctx);
  }

  /// The camera zoomed by [factor] about the screen point [about], so the
  /// world point under it stays put.
  void zoomAbout(Offset about, double factor) {
    final m = r.c.camera.value.worldToScreenMatrix;
    r.c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(
            m.a * factor,
            0,
            0,
            m.d * factor,
            about.dx + (m.e - about.dx) * factor,
            about.dy + (m.f - about.dy) * factor));
  }
}

_Rig _rigOf(String json, {void Function(ServiceRig r)? before}) {
  final r = ServiceRig(json, kits: [fxKit()]);
  addTearDown(r.dispose);
  before?.call(r);
  return _Rig(r);
}

/// The raw x translation that puts table B's box centre [offset] right of
/// table A's (world mm).
double _dxToAlign(Transform2 mover, Transform2 ref, double offset) =>
    _cx(_aabb(ref)) + offset - _cx(_aabb(mover));

void main() {
  test(
      'premise: tables off the origin, B mirrored and turned 90, a camera at scale 1.5',
      () {
    expect(_aabb(_tA)[0], greaterThan(3000));
    expect(_tB.a * _tB.d - _tB.b * _tB.c, lessThan(0), reason: 'B is mirrored');
    // No y pair of B at dy 0 comes within the aperture of A or C: only x
    // can capture in the tests that drag B along x.
    final b = _aabb(_tB);
    for (final other in [_tA, _tC]) {
      final o = _aabb(other);
      for (final m in [b[1], _cy(b), b[3]]) {
        for (final p in [o[1], _cy(o), o[3]]) {
          expect((m - p).abs(), greaterThan(8 / _scale));
        }
      }
    }
  });

  testWidgets(
      'SG-snap dragging table 2 to 5 px of table 1\'s centre line snaps its '
      'centre exactly; one undo restores it exactly (M-SG-8-offset, '
      'M-SG-8-release)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final a = g.tables[0], b = g.tables[1];
    final before = _parts(g.transformOf(b));
    final dx = _dxToAlign(_tB, _tA, 5 * _px);
    final from = _grab(_tB);

    g.hold(from, from + Vector2(dx, 0));
    expect(g.sol.capturedX, isTrue);
    expect(g.sol.capturedY, isFalse);
    expect(g.sol.kindX, GuideKind.centre);
    expect(g.sol.refX, a);
    final snapped = dx - 5 * _px;
    expect(g.preview.e, closeTo(snapped, 1e-9));
    expect(g.preview.f, 0);
    g.up(from + Vector2(dx, 0));

    final after = _parts(g.transformOf(b));
    expect(after.sublist(0, 4), before.sublist(0, 4));
    expect(after[4], closeTo(before[4] + snapped, 1e-9));
    expect(after[5], before[5]);
    expect(_cx(_aabb(g.transformOf(b))), closeTo(_cx(_aabb(_tA)), 1e-9));
    final detail = g.r.c.unitDetails.firstWhere((d) => d.unit.label == '2');
    expect(detail.center!.dx, closeTo(_cx(_aabb(_tA)), 1e-9));
    expect(g.r.layouts, 1);
    expect(g.r.moved, [
      [b]
    ]);
    expect(g.r.doc.commands.undoDepth, 1, reason: 'one command per drag');

    g.r.doc.commands.undo();
    expect(_parts(g.transformOf(b)), before, reason: 'exact (==)');
    g.r.doc.commands.redo();
    expect(_parts(g.transformOf(b)), after, reason: 'redo gives the guided');
  });

  testWidgets(
      'SG-self the dragged table is no reference to itself: a drag that '
      'returns within the aperture of its own start commits the raw delta '
      '(M-SG-8-moving)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final b = g.tables[1];
    final before = _parts(g.transformOf(b));
    final from = _grab(_tB);
    g.down(from);
    g.move(from + Vector2(200, 150)); // past the slop: the drag begins
    final back = from + Vector2(2.5, 1.5); // 3.75 and 2.25 px from the start
    g.move(back);
    expect(g.sol.capturedX, isFalse);
    expect(g.sol.capturedY, isFalse);
    expect(g.preview.e, closeTo(2.5, 1e-9));
    expect(g.preview.f, closeTo(1.5, 1e-9));
    g.up(back);
    final after = _parts(g.transformOf(b));
    expect(after[4], closeTo(before[4] + 2.5, 1e-9));
    expect(after[5], closeTo(before[5] + 1.5, 1e-9));
  });

  testWidgets(
      'SG-zoom a camera zoom mid-drag with no pointer move re-solves at the '
      'new scale: a 5 px capture is lost when 5 px become 10; release '
      'commits the raw delta (M-SG-8-camera)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final b = g.tables[1];
    final before = _parts(g.transformOf(b));
    final dx = _dxToAlign(_tB, _tA, 5 * _px);
    final from = _grab(_tB);
    final to = from + Vector2(dx, 0);
    final raw = to.x - from.x; // the pointer's delta, bit for bit
    g.hold(from, to);
    expect(g.sol.capturedX, isTrue, reason: 'premise: captured at 1.5');
    final notified = g.notified;

    g.zoomAbout(g.r.screen(to), 2); // scale 3: 5 px at 1.5 are 10 px now
    expect(g.notified, greaterThan(notified), reason: 'the tool re-solved');
    expect(g.sol.capturedX, isFalse);
    expect(g.preview.e, raw, reason: 'exactly the raw delta');
    g.up(to);
    expect(g.transformOf(b).e, closeTo(before[4] + dx, 1e-9));
  });

  testWidgets(
      'SG-zoom-out the other way: a capture is gained when the camera zooms '
      'out until the gap fits the aperture', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final dx = _dxToAlign(_tB, _tA, 8 * _px);
    final from = _grab(_tB);
    final to = from + Vector2(dx, 0);
    g.hold(from, to);
    expect(g.sol.capturedX, isFalse, reason: 'premise: 8 px > 6 px');
    g.zoomAbout(g.r.screen(to), 0.5); // 8 px become 4
    expect(g.sol.capturedX, isTrue);
    expect(g.preview.e, closeTo(dx - 8 * _px, 1e-9));
    g.up(to);
  });

  testWidgets(
      'SG-zoom-off with the guides off at the drag start nothing listens: a '
      'camera change mid-drag leaves the translation exactly as it was '
      '(M-SG-8-off)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    g.r.c.alignmentGuides.toggle();
    expect(g.r.c.alignmentGuides.on, isFalse);
    final b = g.tables[1];
    final before = _parts(g.transformOf(b));
    final from = _grab(_tB);
    final to = from + Vector2(_dxToAlign(_tB, _tA, 2 * _px), 40);
    g.hold(from, to);
    final e = g.preview.e, f = g.preview.f;
    expect(g.sol.lineCount, 0);
    final notified = g.notified;

    // A pan, so the world point under the pointer would move.
    g.r.c.camera.value = ViewportTransform(
        worldToScreenMatrix: const Transform2(1.5, 0, 0, -1.5, -6000, 8000));
    expect(g.notified, notified, reason: 'nothing listened');
    expect(g.preview.e, e);
    expect(g.preview.f, f);
    g.up(to);
    expect(g.transformOf(b).e, closeTo(before[4] + e, 1e-9));
  });

  testWidgets(
      'SG-pan a floor drag pans and never solves; the camera is moved by '
      'the pointer, not by the guides', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final floor = Vector2(12000, 1000);
    final before = g.r.c.camera.value.worldToScreenMatrix.e;
    g.hold(floor, floor + Vector2(300, 0));
    expect(g.r.tool.selectionPreviewTransform, isNull);
    expect(g.sol.lineCount + g.sol.markCount, 0);
    expect(g.r.c.camera.value.worldToScreenMatrix.e, isNot(before));
    g.up(floor);
    expect(g.r.layouts, 0);
  });

  testWidgets(
      'SG-cancel a second finger cancels the drag and takes the camera '
      'listener off: a later camera change neither throws nor reaches the '
      'tool (M-SG-8-reset)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final b = g.tables[1];
    final before = _parts(g.transformOf(b));
    final from = _grab(_tB);
    final to = from + Vector2(_dxToAlign(_tB, _tA, 5 * _px), 0);
    g.hold(from, to);
    expect(g.sol.capturedX, isTrue, reason: 'premise');

    g.r.tool.cancel(g.r.ctx);
    expect(g.r.tool.selectionPreviewTransform, isNull);
    final notified = g.notified;
    g.zoomAbout(g.r.screen(to), 2);
    g.r.c.alignmentGuides.toggle();
    g.r.c.alignmentGuides.toggle();
    expect(g.notified, notified);
    expect(g.sol.lineCount, 0, reason: 'cancel clears the guide');
    g.up(to);
    expect(_parts(g.transformOf(b)), before);
    expect(g.r.layouts, 0);
    expect(g.r.moved, isEmpty);
  });

  testWidgets(
      'SG-dispose the session going away mid-drag takes the listeners off: '
      'a camera change or a toggle afterwards does not throw '
      '(M-SG-8-dispose)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final from = _grab(_tB);
    g.hold(from, from + Vector2(_dxToAlign(_tB, _tA, 5 * _px), 0));
    expect(g.sol.capturedX, isTrue, reason: 'premise');
    final settings = g.r.c.alignmentGuides;

    // Leaving service drops the session after the next frame.
    g.r.c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    g.r.c.camera.value = ViewportTransform(
        worldToScreenMatrix: const Transform2(2, 0, 0, -2, 0, 100));
    settings.toggle();
    settings.toggle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'SG-toggle the guides switched off mid-drag give the raw delta, and '
      'on again the capture; Alt does the same without a pointer move '
      '(M-SG-8-settings, M-SG-8-alt)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final dx = _dxToAlign(_tB, _tA, 5 * _px);
    final from = _grab(_tB);
    final raw = (from + Vector2(dx, 0)).x - from.x;
    g.hold(from, from + Vector2(dx, 0));
    final snapped = dx - 5 * _px;
    expect(g.preview.e, closeTo(snapped, 1e-9));

    g.r.c.alignmentGuides.toggle();
    expect(g.preview.e, closeTo(raw, 1e-9));
    expect(g.sol.lineCount, 0);
    g.r.c.alignmentGuides.toggle();
    expect(g.preview.e, closeTo(snapped, 1e-9));
    expect(g.sol.capturedX, isTrue);

    expect(g.alt(down: true), KeyEventResult.ignored);
    expect(g.preview.e, closeTo(raw, 1e-9), reason: 'Alt, no pointer move');
    expect(g.sol.lineCount, 0);
    g.alt(down: false);
    expect(g.preview.e, closeTo(snapped, 1e-9));
    expect(g.sol.capturedX, isTrue);

    // Released with Alt held: the raw delta is what commits.
    g.alt(down: true);
    final before = g.transformOf(g.tables[1]).e;
    g.up(from + Vector2(dx, 0));
    g.alt(down: false);
    expect(g.transformOf(g.tables[1]).e, closeTo(before + raw, 1e-9));
  });

  testWidgets(
      'SG-alt-pointer a move with Alt held in its event suspends the guides '
      'until a move without it (M-SG-8-alt-event)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final dx = _dxToAlign(_tB, _tA, 5 * _px);
    final from = _grab(_tB);
    final to = from + Vector2(dx, 0);
    g.hold(from, to);
    expect(g.sol.capturedX, isTrue, reason: 'premise');
    g.move(to, alt: true);
    expect(g.sol.lineCount, 0);
    expect(g.preview.e, to.x - from.x);
    g.move(to);
    expect(g.sol.capturedX, isTrue);
  });

  testWidgets(
      'SG-touch a finger captures within 10 px, a mouse within 6 '
      '(M-SG-8-aperture)', (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC]));
    final dx = _dxToAlign(_tB, _tA, 8 * _px);
    final from = _grab(_tB);
    g.hold(from, from + Vector2(dx, 0), touch: true);
    expect(g.sol.capturedX, isTrue, reason: '8 px, a finger');
    g.move(from + Vector2(dx, 0), touch: false);
    expect(g.sol.capturedX, isFalse, reason: '8 px, a mouse');
  });

  testWidgets(
      'SG-equal-spacing the middle of three tables in a row, off by 3 mm, '
      'captures the equal gap and draws two marks (M-SG-8-between)',
      (tester) async {
    final row = [
      placementAt(3000, 4000, _rad30),
      placementAt(6000, 4000, _rad30),
      placementAt(9000, 4000, _rad30),
    ];
    final g = _rigOf(_planOf(row));
    final mid = g.tables[1];
    final from = _grab(row[1]);
    g.down(from);
    g.move(from + Vector2(300, 0)); // past the slop: the drag begins
    g.move(from + Vector2(3, 0));
    expect(g.sol.capturedX, isTrue);
    expect(g.sol.kindX, GuideKind.between);
    expect(g.sol.markCount, 2);
    expect(g.preview.e, closeTo(0, 1e-9), reason: 'back to the equal gap');
    g.up(from + Vector2(3, 0));
    expect(g.transformOf(mid).e, closeTo(row[1].e, 1e-9));
  });

  testWidgets(
      'SG-group a group of two tables, one on a hidden layer: the moving box '
      'is the visible member\'s, and only it moves (Review Focus 3)',
      (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC], hidden: {3}));
    g.r.c.setUnitGroups({
      'g': UnitGroup(members: {'2', '3'})
    });
    final b = g.tables[1], c = g.tables[2];
    final cBefore = _parts(g.transformOf(c));
    final dx = _dxToAlign(_tB, _tA, 5 * _px);
    final from = _grab(_tB);
    // C, B's hidden group mate, sits far to the left of B: a box that
    // counted it would not align on A at all.
    g.hold(from, from + Vector2(dx, 0));
    expect(g.sol.capturedX, isTrue);
    expect(g.sol.refX, g.tables[0]);
    g.up(from + Vector2(dx, 0));
    expect(_cx(_aabb(g.transformOf(b))), closeTo(_cx(_aabb(_tA)), 1e-9));
    expect(_parts(g.transformOf(c)), cBefore, reason: 'hidden: it stays');
  });

  testWidgets(
      'SG-hidden a unit hidden between the press and the drag has no box: '
      'the drag draws no guide and moves as today (Review Focus 3, P-11)',
      (tester) async {
    final g = _rigOf(_planOf([_tA, _tB, _tC], floor: {2}));
    final b = g.tables[1];
    final before = _parts(g.transformOf(b));
    // A raw delta that, were an unset box (a point at the origin) moved by
    // it, would sit 2 mm off table 1's centre line: a drag wrongly made
    // eligible would capture it.
    final dx = _cx(_aabb(_tA)) + 2;
    final from = _grab(_tB);
    g.down(from);
    // The layer is hidden under the finger, before the drag begins.
    final layer = g.r.doc.tables.layers.byName('Floor')!;
    g.r.doc.commands.permissions = DraftPermissions.all;
    g.r.doc.commands.execute(SetLayerCommand(layer.copyWith(visible: false)));
    g.move(from + Vector2(dx, 0) * 0.5);
    g.move(from + Vector2(dx, 0));
    expect(g.r.tool.selectionPreviewTransform, isNotNull,
        reason: 'premise: the drag began');
    expect(g.sol.lineCount + g.sol.markCount, 0);
    expect(g.preview.e, (from + Vector2(dx, 0)).x - from.x,
        reason: 'the raw delta');
    g.up(from + Vector2(dx, 0));
    expect(g.transformOf(b).e, closeTo(before[4] + dx, 1e-9));
  });

  testWidgets(
      'SG-seat the seats of a dragged unit stay put, and a row\'s seats are '
      'no reference: a table 3 mm off a seat\'s centre line captures '
      'nothing (M-SG-8-seats)', (tester) async {
    final f = serviceFixture();
    final r = ServiceRig(f.json);
    addTearDown(r.dispose);
    final g = _Rig(r);
    final table = f.table;
    final seat = f.seatsA[2];
    final seatBox = r.worldBox(seat);
    final tableBox = r.worldBox(table);
    final seatsBefore = [
      for (final s in [...f.seatsA, ...f.seatsB]) _parts(r.node(s).transform)
    ];
    final tableBefore = _parts(r.node(table).transform);
    // Raw delta putting the table's centre 3 mm right of the seat's.
    final dx = (seatBox.minX + seatBox.maxX) / 2 +
        3 -
        (tableBox.minX + tableBox.maxX) / 2;
    final from = r.inside(table);
    g.hold(from, from + Vector2(dx, 0));
    expect(g.sol.capturedX, isFalse, reason: 'a seat is no reference');
    expect(g.preview.e, closeTo(dx, 1e-9));
    g.up(from + Vector2(dx, 0));
    expect(r.node(table).transform.e, closeTo(tableBefore[4] + dx, 1e-9));
    expect([
      for (final s in [...f.seatsA, ...f.seatsB]) _parts(r.node(s).transform)
    ], seatsBefore);
  });
}
