// Alignment guides while placing a symbol (alignment guides spec, "The
// delta: Place" and "Modes"; plan Task 7). Real pointer and key events go to
// the real plan.symbol of a real PlanController over a fx kit whose library
// holds a table, a side-chair table and an attaching shelf. The armed
// symbol is turned a quarter, the references are tables turned 30 degrees,
// all around (6000, 4000), under a camera at scale 2, y flipped, off the
// origin. Every expectation is computed from the symbols' definition boxes
// and the placement algebra by hand, not read back from the code under test.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show Catalog, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/guides/guide_solver.dart';
import 'package:jet_cad_2d_plan/src/tools/plan_symbol_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';
import '../support/harness.dart';
import '../support/symbol_fixtures.dart' show box, settle;
import '../support/unit_fixtures.dart';

// ---------------------------------------------------------------------------
// Geometry, computed independently of the code under test.

/// [tableSymbol]'s outline plus its chairs, in definition space; the base
/// point (900, 700) is the middle of its x range, so a mirror leaves the
/// box where it is.
const _tableX = (300.0, 1500.0), _tableY = (-50.0, 1450.0);

/// Camera scale 2, y flipped, off the origin.
final ViewportTransform _camera = ViewportTransform(
    worldToScreenMatrix: const Transform2(2, 0, 0, -2, -9000, 11000));
const double _scale = 2;

/// One pixel, in world millimetres.
const double _px = 1 / _scale;

final class _Box {
  _Box(this.minX, this.minY, this.maxX, this.maxY);

  final double minX, minY, maxX, maxY;
}

/// The AABB of the table's box through [t], corner by corner.
_Box _aabb(Transform2 t) {
  final pts = [
    t.transformPoint(Vector2(_tableX.$1, _tableY.$1)),
    t.transformPoint(Vector2(_tableX.$2, _tableY.$1)),
    t.transformPoint(Vector2(_tableX.$2, _tableY.$2)),
    t.transformPoint(Vector2(_tableX.$1, _tableY.$2)),
  ];
  return _Box(
    pts.map((p) => p.x).reduce(math.min),
    pts.map((p) => p.y).reduce(math.min),
    pts.map((p) => p.x).reduce(math.max),
    pts.map((p) => p.y).reduce(math.max),
  );
}

List<double> _parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// A turned 30 degrees, off the origin: the reference.
final Transform2 _tA = placementAt(6000, 4000, 30 * math.pi / 180);

/// Turned once (90 degrees counter-clockwise), the table's box around its
/// anchor is x +-750, y +-600: x' = -(y - 700), y' = x - 900.
const double _halfY = 600;

// ---------------------------------------------------------------------------
// The rig.

final LogicalKeyboardKey _r = LogicalKeyboardKey.keyR;
final LogicalKeyboardKey _m = LogicalKeyboardKey.keyM;

KeyDownEvent _down(LogicalKeyboardKey k, PhysicalKeyboardKey p) =>
    KeyDownEvent(logicalKey: k, physicalKey: p, timeStamp: Duration.zero);

KeyUpEvent _up(LogicalKeyboardKey k, PhysicalKeyboardKey p) =>
    KeyUpEvent(logicalKey: k, physicalKey: p, timeStamp: Duration.zero);

final class _Rig {
  _Rig(this.c, this.provider)
      : tool = c.toolFor('plan.symbol')! as PlanSymbolTool;

  final PlanController c;
  final PlanSymbolTool tool;
  final RecordingProvider provider;

  ToolContext get ctx => c.toolController.context;

  ToolPointerEvent ev(Vector2 w,
      {int buttons = 0, bool alt = false, bool touch = false}) {
    final cam = ctx.camera.value;
    final s = cam.worldToScreen(w);
    return ToolPointerEvent(
        screen: ui.Offset(s.x, s.y),
        world: w,
        pointer: 7,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: alt,
        pickRadiusWorld: kPickRadiusPixels / cam.scale,
        kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse);
  }

  void hover(Vector2 w, {bool alt = false, bool touch = false}) =>
      tool.onPointerMove(ev(w, alt: alt, touch: touch), ctx);

  void tap(Vector2 w) {
    tool.onPointerMove(ev(w), ctx);
    tool.onPointerDown(ev(w, buttons: kPrimaryButton), ctx);
    tool.onPointerUp(ev(w), ctx);
  }

  KeyEventResult key(LogicalKeyboardKey k, PhysicalKeyboardKey p) =>
      tool.onKey(_down(k, p), ctx);

  void turn() =>
      expect(key(_r, PhysicalKeyboardKey.keyR), KeyEventResult.handled);

  void mirror() =>
      expect(key(_m, PhysicalKeyboardKey.keyM), KeyEventResult.handled);

  /// Holds Alt in the hardware state and tells the tool, as the shell does.
  KeyEventResult altDown() {
    final e = _down(LogicalKeyboardKey.altLeft, PhysicalKeyboardKey.altLeft);
    HardwareKeyboard.instance.handleKeyEvent(e);
    return tool.onKey(e, ctx);
  }

  KeyEventResult altUp() {
    final e = _up(LogicalKeyboardKey.altLeft, PhysicalKeyboardKey.altLeft);
    HardwareKeyboard.instance.handleKeyEvent(e);
    return tool.onKey(e, ctx);
  }

  GuideSolution get sol => tool.debugSolution;

  void arm(String id) => expect(c.armSymbol(c.symbolById(id)!), isTrue);

  Handle get newest {
    final handles = [
      for (final n in c.document.tree.nodes)
        if (n is InstanceNode) n.handle,
    ]..sort((a, b) => a.value.compareTo(b.value));
    return handles.last;
  }

  Transform2 transformOf(Handle h) =>
      (c.document.tree[h]! as InstanceNode).transform;

  List<Handle> get placed => [
        for (final n in c.document.tree.nodes)
          if (n is InstanceNode) n.handle,
      ]..sort((a, b) => a.value.compareTo(b.value));
}

PlanKit _kit(RecordingProvider provider) => PlanKit(
      id: 'fx',
      version: '1.0.0',
      symbols: [
        SymbolLibrarySource(
            label: 'fx',
            read: () async => encodeLibrary(Catalog(kit: 'fx', symbols: [
                  tableSymbol(),
                  sideChairTable,
                  box('fx.shelf.wall', 'Wall shelf', 'Storage', ['shelf'],
                      attachTo: ['test-edge'], base: (950, 410)),
                ]))),
      ],
      attachments: [(_) => provider],
    );

/// A plan with one table A, the table armed, object snap off, grid off.
Future<_Rig> _rig(
    {String armed = 'fx.table.two@1',
    bool objectSnap = false,
    bool grid = false}) async {
  final provider = RecordingProvider('test-edge', (_) => null);
  final text = planText([_kit(provider)], (d) {
    placeUnit(d, tableSymbol(), transform: _tA);
    d.commands.execute(SetComponentCommand<PageComponent>(
        d.rootHandle,
        d.components
            .get<PageComponent>(d.rootHandle)!
            .copyWith(snapToGrid: grid, gridStepMm: 100)));
  });
  final c = controllerFor(kits: [_kit(provider)], json: text);
  c.toolController.context.camera.value = _camera;
  await settle();
  if (c.snap.objectSnap != objectSnap) c.snap.toggleObjectSnap();
  expect(c.snap.objectSnap, objectSnap, reason: 'premise: object snap');
  final r = _Rig(c, provider);
  r.arm(armed);
  return r;
}

/// A world point far to the right of A, so no x alignment can interfere,
/// whose turned table's top edge ends [off] pixels above A's top.
Vector2 _aboveTop(_Box a, double off) =>
    Vector2(a.maxX + 3000.25, a.maxY - _halfY + off * _px);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('premise: one table off the origin, a camera at scale 2', () async {
    final r = await _rig();
    expect(r.placed, hasLength(1));
    expect(_camera.scale, closeTo(2, 1e-12));
    expect(_tA.e.abs() + _tA.f.abs(), greaterThan(1000));
    expect(r.c.alignmentGuides.on, isTrue);
    expect(r.tool.quarterTurns, 0);
  });

  test(
      'PG-1 hovering 4 px off A\'s top edge snaps the turned ghost\'s box top '
      'to it; the placed instance has exactly the ghost\'s transform',
      () async {
    final r = await _rig();
    r.turn();
    final a = _aabb(_tA);
    final raw = _aboveTop(a, 4);
    r.hover(raw);
    expect(r.sol.capturedY, isTrue);
    expect(r.sol.capturedX, isFalse);
    expect(r.sol.kindY, GuideKind.edge);
    expect(r.sol.refY, r.placed.single);
    // The anchor: y moved onto the guide, x is the chain's, bit for bit.
    expect(r.tool.ghostAt.y, closeTo(a.maxY - _halfY, 1e-9));
    expect(r.tool.ghostAt.x, raw.x);
    // The ghost's box top is A's top.
    final ghost = r.tool.ghostPlacement!;
    expect(_aabb(ghost).maxY, closeTo(a.maxY, 1e-9));
    final expected =
        placementAt(r.tool.ghostAt.x, r.tool.ghostAt.y, math.pi / 2);
    for (final (i, v) in _parts(expected).indexed) {
      expect(_parts(ghost)[i], closeTo(v, 1e-9), reason: 'part $i');
    }
    final before = _parts(ghost);
    r.tool.onPointerDown(r.ev(raw, buttons: kPrimaryButton), r.ctx);
    r.tool.onPointerUp(r.ev(raw), r.ctx);
    expect(r.placed, hasLength(2));
    // The commit is the preview, to the bit (P-3).
    expect(_parts(r.transformOf(r.newest)), before);
    // Not the unguided anchor.
    expect(
        r.transformOf(r.newest).f, isNot(closeTo(expected.f + 4 * _px, 1e-6)));
  });

  test(
      'PG-2 7 px away captures nothing and equals the guides-off ghost; a '
      'fingertip\'s 10 px aperture captures the same pointer', () async {
    final on = await _rig();
    final off = await _rig();
    off.c.alignmentGuides.toggle();
    for (final r in [on, off]) {
      r.turn();
    }
    final raw = _aboveTop(_aabb(_tA), 7);
    on.hover(raw);
    off.hover(raw);
    expect(on.sol.capturedY, isFalse);
    expect(on.sol.lineCount, 0);
    expect(_parts(on.tool.ghostPlacement!), _parts(off.tool.ghostPlacement!));
    expect(on.tool.ghostAt.y, off.tool.ghostAt.y);
    // Positive control: the same pointer, as a fingertip.
    on.hover(raw, touch: true);
    expect(on.sol.capturedY, isTrue);
    expect(on.tool.ghostAt.y, closeTo(_aabb(_tA).maxY - _halfY, 1e-9));
  });

  test(
      'PG-3 R with no pointer move re-solves: the new box captures a '
      'different edge', () async {
    final r = await _rig();
    final a = _aabb(_tA);
    // Unturned the box is x +-600, y +-750: its top lands 150 mm + 2 px past
    // A's top. Turned, y +-600: 2 px.
    final raw = _aboveTop(a, 2);
    r.hover(raw);
    expect(r.sol.capturedY, isFalse, reason: 'premise: unturned misses');
    expect(r.tool.ghostAt.y, raw.y);
    r.turn();
    expect(r.sol.capturedY, isTrue);
    expect(r.sol.kindY, GuideKind.edge);
    expect(r.tool.ghostAt.y, closeTo(a.maxY - _halfY, 1e-9));
    expect(_aabb(r.tool.ghostPlacement!).maxY, closeTo(a.maxY, 1e-9));
  });

  test(
      'PG-4 M with no pointer move re-solves: a mirrored side-chair table '
      'swaps its box about the anchor', () async {
    final r = await _rig(armed: 'fx.table.side@1');
    r.turn();
    final a = _aabb(_tA);
    // Turned once, the side-chair table's y extent about the anchor is
    // [-600, 950] unmirrored, [-950, 600] mirrored: its top is 950 or 600
    // above the anchor.
    final raw = Vector2(a.maxX + 3000.25, a.maxY - 600 + 2 * _px);
    r.hover(raw);
    expect(r.sol.capturedY, isFalse, reason: 'premise: unmirrored misses');
    r.mirror();
    expect(r.sol.capturedY, isTrue);
    expect(r.tool.ghostAt.y, closeTo(a.maxY - 600, 1e-9));
    expect(r.tool.mirrored, isTrue);
    // Mirrored back: uncaptured again, the anchor is the pointer.
    r.mirror();
    expect(r.sol.capturedY, isFalse);
    expect(r.tool.ghostAt.y, raw.y);
  });

  test(
      'PG-5 Alt held places as guides-off does; pressing and releasing Alt '
      'with no pointer move re-solves at once', () async {
    final on = await _rig();
    final off = await _rig();
    off.c.alignmentGuides.toggle();
    for (final r in [on, off]) {
      r.turn();
    }
    final raw = _aboveTop(_aabb(_tA), 3);
    // Alt on the event itself.
    on.hover(raw, alt: true);
    off.hover(raw);
    expect(on.sol.capturedY, isFalse);
    expect(_parts(on.tool.ghostPlacement!), _parts(off.tool.ghostPlacement!));
    // Alt off the event: captured again.
    on.hover(raw);
    expect(on.sol.capturedY, isTrue);
    // The key alone, no pointer move.
    expect(on.altDown(), KeyEventResult.ignored);
    try {
      expect(on.sol.capturedY, isFalse);
      expect(_parts(on.tool.ghostPlacement!), _parts(off.tool.ghostPlacement!));
      expect(on.tool.ghostAt.y, raw.y);
    } finally {
      expect(on.altUp(), KeyEventResult.ignored);
    }
    expect(on.sol.capturedY, isTrue);
    expect(on.tool.ghostAt.y, closeTo(_aabb(_tA).maxY - _halfY, 1e-9));
  });

  test(
      'PG-6 with Alt held R does nothing, as today, and the ghost stays '
      'unguided', () async {
    final r = await _rig();
    final raw = _aboveTop(_aabb(_tA), 2);
    r.hover(raw);
    r.altDown();
    try {
      expect(r.key(_r, PhysicalKeyboardKey.keyR), KeyEventResult.ignored);
      expect(r.tool.quarterTurns, 0);
      expect(r.sol.capturedY, isFalse);
      expect(r.tool.ghostAt.y, raw.y);
    } finally {
      r.altUp();
    }
  });

  test(
      'PG-7 toggling the setting mid-hover re-solves with no pointer move; '
      're-arming another symbol re-solves too', () async {
    final r = await _rig();
    r.turn();
    final a = _aabb(_tA);
    final raw = _aboveTop(a, 3);
    r.hover(raw);
    expect(r.sol.capturedY, isTrue);
    r.c.alignmentGuides.toggle();
    expect(r.sol.capturedY, isFalse);
    expect(r.tool.ghostAt.y, raw.y);
    expect(_aabb(r.tool.ghostPlacement!).maxY, closeTo(raw.y + _halfY, 1e-9));
    r.c.alignmentGuides.toggle();
    expect(r.sol.capturedY, isTrue);
    expect(r.tool.ghostAt.y, closeTo(a.maxY - _halfY, 1e-9));
    // The side-chair table, turned the same: its top is 950 mm above the
    // anchor, so the table's capture is gone on the same pointer.
    r.arm('fx.table.side@1');
    expect(r.tool.quarterTurns, 1);
    expect(r.sol.capturedY, isFalse);
    expect(r.tool.ghostAt.y, raw.y);
    // And back.
    r.arm('fx.table.two@1');
    expect(r.sol.capturedY, isTrue);
    expect(r.tool.ghostAt.y, closeTo(a.maxY - _halfY, 1e-9));
  });

  test(
      'PG-8 placing two tables in a row: the second sees the first as a '
      'reference', () async {
    final r = await _rig();
    r.turn();
    // The first lands far from A, uncaptured.
    final first = Vector2(-4000.5, -2500.25);
    r.tap(first);
    expect(r.placed, hasLength(2));
    final firstHandle = r.newest;
    final firstBox = _aabb(r.transformOf(firstHandle));
    // The second, 2 px off the first's top, well to its right.
    final second = Vector2(first.x + 4000, first.y + 2 * _px);
    r.hover(second);
    expect(r.sol.capturedY, isTrue);
    expect(r.sol.refY, firstHandle);
    expect(r.tool.ghostAt.y, closeTo(first.y, 1e-9));
    expect(_aabb(r.tool.ghostPlacement!).maxY, closeTo(firstBox.maxY, 1e-9));
    r.tap(second);
    expect(r.placed, hasLength(3));
    expect(_aabb(r.transformOf(r.newest)).maxY, closeTo(firstBox.maxY, 1e-9));
  });

  test(
      'PG-10 with grid snap on, a y capture leaves x on the grid, equal to '
      'the guides-off x', () async {
    final on = await _rig(grid: true);
    final off = await _rig(grid: true);
    off.c.alignmentGuides.toggle();
    for (final r in [on, off]) {
      r.turn();
    }
    final a = _aabb(_tA);
    final raw = Vector2(a.maxX + 3000.123456789, a.maxY - _halfY + 3 * _px);
    on.hover(raw);
    off.hover(raw);
    expect(on.sol.capturedY, isTrue);
    expect(on.sol.capturedX, isFalse);
    expect(on.tool.ghostAt.x, off.tool.ghostAt.x);
    expect(on.tool.ghostAt.x, isNot(raw.x), reason: 'premise: grid moved x');
    expect(on.tool.ghostAt.y, closeTo(a.maxY - _halfY, 1e-9));
    // The jump from the capture is at most half a step plus the aperture.
    expect((on.tool.ghostAt.y - off.tool.ghostAt.y).abs(),
        lessThanOrEqualTo(50 + 6 * _px + 1e-9));
  });

  test(
      'PG-9 a wall-attaching symbol: the attachment is asked on the '
      'unguided transform; attached it is taken verbatim and no guide is '
      'painted', () async {
    final r = await _rig(armed: 'fx.shelf.wall@1', objectSnap: true);
    final a = _aabb(_tA);
    // The shelf unturned: box y [-200, 550] about the anchor.
    final raw = Vector2(a.maxX + 3000.25, a.maxY - 550 + 2 * _px);
    r.hover(raw);
    expect(r.sol.capturedY, isTrue, reason: 'premise: the guide captures');
    expect(r.tool.ghostAt.y, closeTo(a.maxY - 550, 1e-9));
    // The query's current is the free placement at the raw pointer.
    final current = r.provider.queries.last.current;
    final unguided = placementAt(raw.x, raw.y, 0, baseX: 950, baseY: 410);
    for (final (i, v) in _parts(unguided).indexed) {
      expect(_parts(current)[i], closeTo(v, 1e-9), reason: 'part $i');
    }

    final canvas = _CountingCanvas();
    r.tool.paintOverlay(
        canvas, _camera, const ui.Size(800, 600), PaperPalette.light);
    expect(canvas.calls['drawRawPoints'], 1, reason: 'the guide is painted');

    final wall = Transform2.translation(5200.5, 4100.25)
        .multiply(Transform2.rotation(-0.35));
    r.provider.answer = (_) => attachment(wall, raw, 'w');
    r.hover(raw + Vector2(1, 0));
    expect(r.tool.ghostAttachment, isNotNull);
    expect(_parts(r.tool.ghostPlacement!), _parts(wall));
    final attachedCanvas = _CountingCanvas();
    r.tool.paintOverlay(
        attachedCanvas, _camera, const ui.Size(800, 600), PaperPalette.light);
    expect(attachedCanvas.calls['drawRawPoints'], isNull,
        reason: 'attached: no guide');
    r.tap(raw + Vector2(1, 0));
    expect(_parts(r.transformOf(r.newest)), _parts(wall));
  });
}

/// Counts the canvas calls by method name.
final class _CountingCanvas implements ui.Canvas {
  final Map<String, int> calls = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    final key = name.substring(8, name.length - 2); // Symbol("name")
    calls[key] = (calls[key] ?? 0) + 1;
    return null;
  }
}
