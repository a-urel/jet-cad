// Spatial dependencies (spec 10 D16): place contributors (Slab, Rod), place
// readers (Lens) and the trigger that regenerates, in the edit, every reader
// whose read box touches the before or after place box of a contributor in
// the edit's spatial core. Every object sits in its own rotated group off
// the origin; fields and rectangles have fractional coordinates.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

const Slab slab = Slab(20.25, 30.5, 800.5, 400.75);
const Lens lens = Lens(100.5, 50.25, 2000.5, 1500.75);

/// R on A's frame, turned, off the origin.
final Transform2 atR = onA(3000.5, 500.25, 0.2);

/// R's world field.
Aabb2 field() => lensField(lens, atR);

List<Handle> drift(DraftDocument doc) => ParametricSystem(doc, catalog).drift();

int calls(Handle h) => generateCalls[h] ?? 0;

/// [p] turned by [turn] with its first corner on ([x], [y]), in world.
Transform2 cornerAt(Slab p, double x, double y, double turn) =>
    Transform2.translation(x, y)
        .multiply(Transform2.rotation(turn))
        .multiply(Transform2.translation(-p.x, -p.y));

/// The next double after [x] towards [up] (up or down), for an exact touch.
double nextAfter(double x, {required bool up}) {
  final b = ByteData(8)..setFloat64(0, x);
  final bits = b.getInt64(0);
  b.setInt64(0, (x >= 0) == up ? bits + 1 : bits - 1);
  return b.getFloat64(0);
}

/// [p] turned by [turn], its first corner at height [y], moved along x until
/// its world box's `minX` equals [minX] exactly.
Transform2 touchingAt(Slab p, double minX, double y, double turn) {
  var x = minX;
  x += minX - slabBox(p, cornerAt(p, x, y, turn)).minX;
  for (var i = 0; i < 10000; i++) {
    final m = slabBox(p, cornerAt(p, x, y, turn)).minX;
    if (m == minX) return cornerAt(p, x, y, turn);
    x = nextAfter(x, up: m < minX);
  }
  throw StateError('no exact touch at $minX');
}

/// The world box of [box] mapped by [m].
Aabb2 worldBox(List<double> coords, Transform2 m) => Aabb2.fromPoints([
      for (var i = 0; i + 1 < coords.length; i += 2)
        m.transformPoint(Vector2(coords[i], coords[i + 1])),
    ]);

List<double> coordsOf(DraftDocument doc, Handle k) => doc.geometry
    .read(doc.entities.geomIndexAt(doc.entities.slotOf(k)!))
    .coords
    .toList();

EntityKind kindOf(DraftDocument doc, Handle k) =>
    doc.entities.kindAt(doc.entities.slotOf(k)!);

/// The place boxes Lens [r] draws (its POLYLINE children), in world,
/// ascending by child handle.
List<Aabb2> listedBoxes(DraftDocument doc, Handle r) => [
      for (final k in kids(doc, r))
        if (kindOf(doc, k) == EntityKind.polyline)
          worldBox(coordsOf(doc, k), doc.tree.accumulatedTransform(r)),
    ];

/// The Rod segments Lens [r] draws (its LINE children), in world.
List<List<double>> listedSegments(DraftDocument doc, Handle r) {
  final m = doc.tree.accumulatedTransform(r);
  return [
    for (final k in kids(doc, r))
      if (kindOf(doc, k) == EntityKind.line)
        () {
          final c = coordsOf(doc, k);
          final a = m.transformPoint(Vector2(c[0], c[1]));
          final b = m.transformPoint(Vector2(c[2], c[3]));
          return [a.x, a.y, b.x, b.y];
        }(),
  ];
}

Matcher boxNear(Aabb2 e) => isA<Aabb2>()
    .having((b) => b.minX, 'minX', closeTo(e.minX, 1e-6))
    .having((b) => b.minY, 'minY', closeTo(e.minY, 1e-6))
    .having((b) => b.maxX, 'maxX', closeTo(e.maxX, 1e-6))
    .having((b) => b.maxY, 'maxY', closeTo(e.maxY, 1e-6));

/// Lens [r]'s read box as the engine forms it: its world field and the
/// world box of its stored children's points.
Aabb2 readBoxOf(DraftDocument doc, Handle r, Lens p) {
  final m = doc.tree.accumulatedTransform(r);
  var stored = Aabb2.empty();
  for (final k in kids(doc, r)) {
    stored = stored.union(worldBox(coordsOf(doc, k), m));
  }
  return stored.union(lensField(p, m));
}

/// 07 D10's neighbour predicate: reach overlap by more than the tolerance
/// on both axes.
bool neighbours(Aabb2 a, Aabb2 b) {
  const tol = Tolerance.standard;
  return a.minX < b.maxX - tol.linear &&
      b.minX < a.maxX - tol.linear &&
      a.minY < b.maxY - tol.linear &&
      b.minY < a.maxY - tol.linear;
}

Aabb2 slabReach(Slab p, Transform2 at) => const SlabType().reach(p, at);

Aabb2 rodBox(Rod p, Transform2 at) {
  final (a, b) = p.worldEnds(at);
  return Aabb2.fromPoints([a, b]);
}

/// The place-box and read-box calls [edit] makes (spec 10 D16.6).
(int, int) counted(void Function() edit) {
  final p = debugPlaceBoxCalls, r = debugReadBoxCalls;
  edit();
  return (debugPlaceBoxCalls - p, debugReadBoxCalls - r);
}

/// The select tool's delete of one object: its children, then its node.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// A root LINE, owned by no object.
DraftCommand rootLine(DraftDocument doc) => AddEntityCommand(
    record: draftRecord(doc.handleSeed.next(), doc.rootHandle, EntityKind.line),
    payload:
        linePayload(Vector2(-4000.25, 9000.5), Vector2(-3500.75, 9300.25)));

/// Exact: the same bits, for a premise that a box did not move at all.
bool sameBox(Aabb2 a, Aabb2 b) =>
    a.minX == b.minX &&
    a.minY == b.minY &&
    a.maxX == b.maxX &&
    a.maxY == b.maxY;

/// Exact: the same six entries.
bool sameTransform(Transform2 a, Transform2 b) =>
    a.a == b.a &&
    a.b == b.b &&
    a.c == b.c &&
    a.d == b.d &&
    a.e == b.e &&
    a.f == b.f;

/// SD7's per-object oracle: a component whose type records, from
/// `diagnostics()`, what `view.neighbours(h)` answers for every handle in
/// [_OracleType.of]. A diagnostics view never calls `placedIn`, so each list
/// is the per-object `neighboursOf` search.
final class _Oracle implements Component {
  const _Oracle();
  static const String id = 'test.sd7.oracle';
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => const {};
  static _Oracle fromJson(Map<String, Object?> j) => const _Oracle();
  @override
  bool operator ==(Object o) => o is _Oracle;
  @override
  int get hashCode => id.hashCode;
}

final class _OracleType extends ParametricType<_Oracle> {
  _OracleType();
  final List<Handle> of = [];
  final Map<Handle, List<Handle>> seen = {};
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(_Oracle params, Transform2 toWorld) => Aabb2.empty();
  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    for (final h in of) {
      seen[h] = List.of(view.neighbours(h));
    }
    return const [];
  }
}

/// SD7's grid: neighbour_cost_test.dart's spread grid (20 columns, every
/// other object raised a little, at the corpus's far origin turned 30°),
/// spaced for the Slab's 2 mm reach instead of a 1,000 mm segment's. Each
/// object is turned by 0.25 × (i mod 4) rather than 0.01 × (i mod 3): the
/// world reaches then differ in width, so sorting them by `maxX` is not the
/// same order as by `minX` (a sweep keyed on the wrong end goes red).
final Transform2 far = Transform2.translation(4500000, 1200000)
    .multiply(Transform2.rotation(math.pi / 6));
Transform2 slabCell(int i) => far
    .multiply(Transform2.translation(
        2.25 * (i % 20) + 0.125, 1.75 * (i ~/ 20) + 0.0625 * (i % 2)))
    .multiply(Transform2.rotation(0.25 * (i % 4)));

/// [p] turned by [turn], its reach's `minX` equal to [minX] exactly, its
/// group's origin at height [y].
Transform2 reachStartingAt(Slab p, double minX, double y, double turn) {
  Transform2 at(double x) =>
      Transform2.translation(x, y).multiply(Transform2.rotation(turn));
  var x = minX;
  x += minX - slabReach(p, at(x)).minX;
  for (var i = 0; i < 10000; i++) {
    final m = slabReach(p, at(x)).minX;
    if (m == minX) return at(x);
    x = nextAfter(x, up: m < minX);
  }
  throw StateError('no reach starting at $minX');
}

/// A test-local type with both roles (SD8).
final class _BothType extends ParametricType<Slab> {
  const _BothType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Slab params, Transform2 toWorld) => Aabb2.empty();
  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
  @override
  bool get contributesPlace => true;
  @override
  bool get readsPlaces => true;
}

void main() {
  setUp(() {
    generateCalls.clear();
    Slab.placeCalls.clear();
  });

  test(
      'SD1 a contributor moved into a reader\'s field regenerates the '
      'reader; placedIn is by place box, closed, and skips a non-finite '
      'box', () {
    const hS = Handle(1000), hR = Handle(2000), hT = Handle(3000);
    const hNaN = Handle(4000), hInf = Handle(5000);
    final f = field();

    // Two loaded Slabs whose first corners lie below and left of R's
    // field: one with a NaN far corner, one with an infinite one. Loaded:
    // added before the system is installed, so nothing is generated for
    // them.
    final doc = DraftDocument.empty();
    final system = ParametricSystem(doc, catalog);
    const nan = Slab(10.5, 20.25, double.nan, 300.5);
    const inf = Slab(10.5, 20.25, double.infinity, 300.5);
    final atNaN = cornerAt(nan, f.minX - 400.25, f.minY - 300.5, 0.3);
    final atInf = cornerAt(inf, f.minX - 600.75, f.minY - 500.25, 0.3);
    doc.commands.execute(create(doc, hNaN, atNaN, nan));
    doc.commands.execute(create(doc, hInf, atInf, inf));
    system.install();
    // Premises: the infinite Slab's box would touch the field; neither
    // loaded Slab's reach does, so a reach-based placedIn (M-10cand) is
    // caught by S alone.
    expect(slabBox(inf, atInf).intersects(f), isTrue);
    expect(slabReach(inf, atInf).intersects(f), isFalse);
    expect(slabReach(nan, atNaN).intersects(f), isFalse);
    expect(slabBox(inf, atInf).maxX, double.infinity);
    expect(slabBox(nan, atNaN).minX.isNaN, isTrue);

    doc.commands.execute(create(doc, hR, atR, lens));
    expect(kids(doc, hR), isEmpty, reason: 'a non-finite box is not placed');
    expect(drift(doc), isEmpty);

    // A Rod inside the field: R draws its segment.
    const rod = Rod(0.5, 0.25, 500.75, 200.5);
    final atT = Transform2.translation(f.minX + 400.5, f.minY + 300.25)
        .multiply(Transform2.rotation(0.35));
    doc.commands.execute(create(doc, hT, atT, rod));
    final (ta, tb) = rod.worldEnds(atT);
    final segment = [ta.x, ta.y, tb.x, tb.y];
    expect(listedSegments(doc, hR), [
      [for (final v in segment) closeTo(v, 1e-6)],
    ]);
    expect(listedBoxes(doc, hR), isEmpty);
    expect(drift(doc), isEmpty);

    // S parked far away.
    doc.commands.execute(create(doc, hS, parked, slab));
    expect(listedBoxes(doc, hR), isEmpty);

    // Moved until only its rectangle, not its reach, overlaps the field.
    final t1 = cornerAt(slab, f.minX - 300.25, f.center.y, 0.15);
    expect(slabBox(slab, t1).intersects(f), isTrue);
    expect(slabReach(slab, t1).intersects(readBoxOf(doc, hR, lens)), isFalse,
        reason: 'the reach misses the read box');
    expect(slabReach(slab, t1).intersects(f), isFalse);
    doc.commands.execute(TransformNodeCommand(hS, t1));
    expect(listedBoxes(doc, hR), [boxNear(slabBox(slab, t1))]);
    expect(listedSegments(doc, hR), hasLength(1));
    expect(drift(doc), isEmpty);

    // Moved to the far side, its box exactly touching the field.
    final t2 = touchingAt(slab, f.maxX, f.center.y, 0.15);
    final b2 = slabBox(slab, t2);
    expect(b2.minX, f.maxX, reason: 'touching, exactly');
    expect(b2.minY < f.maxY && b2.maxY > f.minY, isTrue);
    doc.commands.execute(TransformNodeCommand(hS, t2));
    expect(listedBoxes(doc, hR), [boxNear(b2)],
        reason: 'a box that only touches is listed');
    expect(listedSegments(doc, hR), hasLength(1));
    expect(drift(doc), isEmpty);
    // Neither loaded Slab was touched.
    expect(doc.components.get<Slab>(hNaN)!.w.isNaN, isTrue);
    expect(doc.components.get<Slab>(hInf), inf);
    expect(doc.tree.accumulatedTransform(hInf).e, atInf.e);
  });

  test(
      'SD2 a contributor moved out of a reader\'s field regenerates '
      'the reader (its before box)', () {
    const hR = Handle(1000), hS = Handle(2000);
    final f = field();
    final doc = paramDoc();
    doc.commands.execute(create(doc, hR, atR, lens));
    final t0 = cornerAt(slab, f.minX + 400.25, f.minY + 350.5, 0.15);
    doc.commands.execute(create(doc, hS, t0, slab));
    expect(listedBoxes(doc, hR), [boxNear(slabBox(slab, t0))]);
    expect(drift(doc), isEmpty);

    // Moved clear of the field and of its old box: its after box misses
    // R's read box, so only its before box finds R.
    final t1 = cornerAt(slab, f.maxX + 600.5, f.minY + 350.5, 0.15);
    final read = readBoxOf(doc, hR, lens);
    expect(slabBox(slab, t1).intersects(read), isFalse);
    expect(slabBox(slab, t0).intersects(read), isTrue);
    final r0 = calls(hR);
    doc.commands.execute(TransformNodeCommand(hS, t1));
    expect(calls(hR), r0 + 1);
    expect(listedBoxes(doc, hR), isEmpty);
    expect(drift(doc), isEmpty);
  });

  test(
      'SD3 a contributor moved far regenerates the reader it left '
      '(the before-view)', () {
    const hR = Handle(1000), hS = Handle(2000);
    final f = field();
    final doc = paramDoc();
    doc.commands.execute(create(doc, hR, atR, lens));
    final t0 = cornerAt(slab, f.minX + 700.75, f.minY + 500.25, -0.25);
    doc.commands.execute(create(doc, hS, t0, slab));
    expect(listedBoxes(doc, hR), [boxNear(slabBox(slab, t0))]);

    // 60 m away, turned.
    final t1 = Transform2.translation(60000.5, -1500.25)
        .multiply(Transform2.rotation(0.4))
        .multiply(t0);
    expect(slabBox(slab, t1).minX - f.maxX, greaterThan(50000));
    doc.commands.execute(TransformNodeCommand(hS, t1));
    expect(listedBoxes(doc, hR), isEmpty);
    expect(drift(doc), isEmpty);
  });

  test(
      'SD4 the two-hop: a seed that changes a neighbouring '
      'contributor\'s place box at a far end regenerates the reader there', () {
    const hW = Handle(1000), hX = Handle(2000), hR = Handle(3000);
    const w = Slab(10.5, 20.25, 3000.5, 300.75);
    const clip = ClipRect(400.5, 300.25);
    final atW = onA(-3000.5, -2000.25, 0.1);
    final wb = slabBox(w, atW);
    // R beyond W's far end: its field misses W's box, not W's grown box.
    const lensW = Lens(0.5, 0.25, 900.5, 600.75);
    final atRW = Transform2.translation(wb.maxX + 500.25, wb.maxY - 800.5)
        .multiply(Transform2.rotation(0.25));
    final fw = lensField(lensW, atRW);
    // X centred on W's first corner (its reach) when on W, far otherwise.
    final corner = atW.transformPoint(w.corners[0]);
    final onW = Transform2.translation(corner.x, corner.y)
        .multiply(Transform2.rotation(0.7))
        .multiply(Transform2.translation(-clip.width / 2, -clip.height / 2));
    final away = Transform2.translation(wb.minX - 5000.5, wb.minY - 4000.25)
        .multiply(Transform2.rotation(0.7));
    Aabb2 clipReach(Transform2 at) =>
        const RectType<ClipRect>(Capability.geometry).reach(clip, at);

    final doc = paramDoc();
    doc.commands.execute(create(doc, hW, atW, w));
    doc.commands.execute(create(doc, hX, away, clip));
    doc.commands.execute(create(doc, hR, atRW, lensW));
    expect(kids(doc, hR), isEmpty);
    expect(drift(doc), isEmpty);

    // Premises: X's before and after boxes (its reach: it is no
    // contributor) miss R's read box; X on W is W's neighbour; W's place
    // box misses R's read box before and touches it after, grown.
    final read = readBoxOf(doc, hR, lensW);
    expect(clipReach(away).intersects(read), isFalse);
    expect(clipReach(onW).intersects(read), isFalse);
    expect(neighbours(clipReach(onW), slabReach(w, atW)), isTrue);
    expect(neighbours(clipReach(away), slabReach(w, atW)), isFalse);
    expect(wb.intersects(read), isFalse);
    expect(slabBox(w, atW, grown: true).intersects(read), isTrue);

    // X onto W: W's box grows by 1,000 mm at its far end too, and R, two
    // hops from X, follows.
    doc.commands.execute(TransformNodeCommand(hX, onW));
    expect(listedBoxes(doc, hR), [boxNear(slabBox(w, atW, grown: true))]);
    expect(drift(doc), isEmpty);

    // X off W (the plan's direction): W's box shrinks by 1,000 mm and R
    // drops it. X's after box misses R's read box; its before box cannot
    // (R now stores W's grown box, which holds W's reach, which X
    // overlapped).
    expect(clipReach(away).intersects(readBoxOf(doc, hR, lensW)), isFalse);
    expect(fw.intersects(wb), isFalse);
    doc.commands.execute(TransformNodeCommand(hX, away));
    expect(listedBoxes(doc, hR), isEmpty);
    expect(drift(doc), isEmpty);
  });

  test('SD5 two readers touched by one contributor both regenerate', () {
    const hR1 = Handle(1000), hR2 = Handle(2000), hS = Handle(3000);
    const lens2 = Lens(-50.25, 30.75, 1500.5, 1200.25);
    final f1 = field();
    final atR2 = Transform2.translation(f1.maxX - 600.5, f1.maxY - 500.25)
        .multiply(Transform2.rotation(-0.3));
    final f2 = lensField(lens2, atR2);
    final doc = paramDoc();
    doc.commands.execute(create(doc, hR1, atR, lens));
    doc.commands.execute(create(doc, hR2, atR2, lens2));
    doc.commands.execute(create(doc, hS, parked, slab));
    expect(kids(doc, hR1), isEmpty);
    expect(kids(doc, hR2), isEmpty);

    // S into the overlap of both fields.
    final t1 =
        cornerAt(slab, f1.maxX - 500.75, math.max(f1.minY, f2.minY), 0.2);
    final b1 = slabBox(slab, t1);
    expect(b1.intersects(f1), isTrue);
    expect(b1.intersects(f2), isTrue);
    expect(hR1.value, lessThan(hR2.value));
    doc.commands.execute(TransformNodeCommand(hS, t1));
    expect(listedBoxes(doc, hR1), [boxNear(b1)]);
    expect(listedBoxes(doc, hR2), [boxNear(b1)]);
    expect(drift(doc), isEmpty);
  });

  test(
      'SD7 the bulk pass gives every object the lists neighboursOf '
      'gives, with fewer than n²/4 overlap tests on a spread layout', () {
    const n = 200;
    const tol = Tolerance.standard;
    const tile = Slab(0.5, 0.25, 0.75, 0.5);
    final oracleType = _OracleType();
    final cat = testCatalog()
      ..register<_Oracle>(_Oracle.id, _Oracle.fromJson, oracleType);
    final doc = DraftDocument.empty();
    ParametricSystem(doc, cat).install();

    // 196 Slabs on the grid, and two pairs far from it, whose reaches meet
    // at the predicate's bound: P overlaps along x by one ulp, not more
    // than the tolerance (no neighbours); Q by two ulps, more than it
    // (neighbours). Their y ranges overlap by far more.
    const grid = n - 4;
    final at = <Transform2>[for (var i = 0; i < grid; i++) slabCell(i)];
    final p1 = Transform2.translation(4500200.25, 1200100.5)
        .multiply(Transform2.rotation(0.3));
    final p1Reach = slabReach(tile, p1);
    final p2 = reachStartingAt(
        tile, nextAfter(p1Reach.maxX, up: false), 1200100.75, -0.2);
    final q1 = Transform2.translation(4500200.25, 1200200.5)
        .multiply(Transform2.rotation(0.3));
    final q1Reach = slabReach(tile, q1);
    final q2 = reachStartingAt(
        tile,
        nextAfter(nextAfter(q1Reach.maxX, up: false), up: false),
        1200200.75,
        -0.2);
    at.addAll([p1, p2, q1, q2]);
    final slabs = [for (var i = 0; i < n; i++) doc.handleSeed.next()];
    doc.commands.execute(CompoundCommand([
      for (var i = 0; i < n; i++) ...[
        AddNodeCommand(GroupNode(
            handle: slabs[i],
            parent: doc.rootHandle,
            transform: at[i],
            children: const [])),
        SetComponentCommand<Slab>(slabs[i], tile),
      ],
    ], label: 'Slabs'));
    final hL = doc.handleSeed.next();
    final atL = Transform2.translation(4500400.5, 1200300.25)
        .multiply(Transform2.rotation(0.2));
    const lensL = Lens(0.5, 0.25, 50.5, 40.75);
    doc.commands.execute(create(doc, hL, atL, lensL));
    final hO = doc.handleSeed.next();
    doc.commands.execute(create(doc, hO, parked, const _Oracle()));
    oracleType.of.addAll([...slabs, hL, hO]);

    // Moved into the Lens's field: grid object 150.
    final moved = slabs[150];
    final fL = lensField(lensL, atL);
    final to = cornerAt(tile, fL.minX + 10.25, fL.minY + 12.5, 0.15);
    expect(slabBox(tile, to).intersects(fL), isTrue);
    expect(kids(doc, hL), isEmpty);

    // Premises, from the world reaches computed here: the grid is spread
    // (every object has a handful of neighbours, before and after the
    // move; the moved one too); P is one ulp deep and no pair, Q two ulps
    // deep and one; the pairs meet nothing else.
    List<Handle> expected(Handle h, Transform2 Function(Handle) atOf) => [
          for (final o in slabs)
            if (o != h &&
                neighbours(slabReach(tile, atOf(h)), slabReach(tile, atOf(o))))
              o,
        ];
    Transform2 before(Handle h) => at[slabs.indexOf(h)];
    Transform2 after(Handle h) => h == moved ? to : before(h);
    for (final atOf in [before, after]) {
      final lists = {for (final h in slabs) h: expected(h, atOf)};
      final gridCounts = [for (final h in slabs.take(grid)) lists[h]!.length];
      expect(gridCounts.where((c) => c == 0), hasLength(atOf == after ? 1 : 0),
          reason: 'only the moved object, once moved, has none');
      expect(gridCounts.reduce(math.max), inInclusiveRange(4, 12));
      expect(lists[slabs[grid]], isEmpty);
      expect(lists[slabs[grid + 1]], isEmpty);
      expect(lists[slabs[grid + 2]], [slabs[grid + 3]]);
      expect(lists[slabs[grid + 3]], [slabs[grid + 2]]);
    }
    expect(expected(moved, before), isNotEmpty);
    final p2Reach = slabReach(tile, p2), q2Reach = slabReach(tile, q2);
    expect(p2Reach.minX, lessThan(p1Reach.maxX));
    expect(p1Reach.maxX - p2Reach.minX, lessThanOrEqualTo(tol.linear));
    expect(q1Reach.maxX - q2Reach.minX, greaterThan(tol.linear));
    expect(q1Reach.maxX - q2Reach.minX, lessThan(2 * tol.linear));

    Slab.placeCalls.clear();
    final tests0 = debugOverlapTests;
    doc.commands.execute(TransformNodeCommand(moved, to));
    final tests = debugOverlapTests - tests0;
    print('SD7 n=$n overlap tests in the edit: $tests '
        '(n²/4 = ${n * n ~/ 4})');
    expect(tests, lessThan(n * n ~/ 4));
    expect(listedBoxes(doc, hL), [boxNear(slabBox(tile, to))],
        reason: 'the Lens regenerated');

    // The after-view's calls: the last call's view, one call per Slab.
    final view = Slab.placeCalls.last.view;
    final seen = {
      for (final c in Slab.placeCalls)
        if (identical(c.view, view)) c.self: c.neighbours,
    };
    expect(seen.keys.toSet(), slabs.toSet());
    expect(Slab.placeCalls.where((c) => identical(c.view, view)), hasLength(n));

    ParametricSystem(doc, cat).diagnostics();
    expect(oracleType.seen.keys.toSet(), {...slabs, hL, hO});
    for (final h in slabs) {
      expect(seen[h], oracleType.seen[h], reason: h.toHex());
      expect(seen[h], expected(h, after), reason: h.toHex());
      expect(() => seen[h]!.add(h), throwsUnsupportedError);
    }
    expect(oracleType.seen[hL], isEmpty);
    expect(oracleType.seen[hO], isEmpty);
    expect(ParametricSystem(doc, cat).drift(), isEmpty);
  });

  test(
      'SD8 the catalog refuses a type that both contributes and '
      'reads', () {
    final refusing = ParametricCatalog();
    expect(
        () => refusing.register<Slab>(
            'test.both', Slab.fromJson, const _BothType()),
        throwsA(isA<ArgumentError>()));
    final bare = DraftDocument.empty();
    refusing.registerComponents(bare.components);
    expect(bare.components.isRegistered<Slab>(), isFalse,
        reason: 'the refused type is not registered');

    final roles = ParametricCatalog()
      ..register<Slab>(Slab.id, Slab.fromJson, const SlabType())
      ..register<Lens>(Lens.id, Lens.fromJson, const LensType());
    final doc = DraftDocument.empty();
    roles.registerComponents(doc.components);
    expect(doc.components.isRegistered<Slab>(), isTrue);
    expect(doc.components.isRegistered<Lens>(), isTrue);
  });

  test(
      'SD5b placedIn lists two contributors of one kind in ascending '
      'handle order, not in creation order', () {
    const hR = Handle(1000), hS1 = Handle(3000), hS2 = Handle(4000);
    const slab2 = Slab(-40.75, 15.5, 600.25, 300.5);
    final f = field();
    final doc = paramDoc();
    doc.commands.execute(create(doc, hR, atR, lens));
    // The higher handle first, then the lower: both inside the field, their
    // boxes apart, so the order R draws them in is visible.
    final t2 = cornerAt(slab2, f.minX + 1200.5, f.minY + 900.25, -0.2);
    final t1 = cornerAt(slab, f.minX + 300.25, f.minY + 250.75, 0.15);
    final b1 = slabBox(slab, t1), b2 = slabBox(slab2, t2);
    expect(b1.intersects(f) && b2.intersects(f), isTrue);
    expect(b1.intersects(b2), isFalse);
    expect(neighbours(slabReach(slab, t1), slabReach(slab2, t2)), isFalse);
    doc.commands.execute(create(doc, hS2, t2, slab2));
    expect(listedBoxes(doc, hR), [boxNear(b2)]);
    doc.commands.execute(create(doc, hS1, t1, slab));
    // Two POLYLINE children, matched by index in generation order: the
    // first (lower handle) holds the lower-handle Slab's box.
    expect(listedBoxes(doc, hR), [boxNear(b1), boxNear(b2)]);
    expect(drift(doc), isEmpty);
  });

  test(
      'SD6 the trigger\'s counts: no seeds, no call; a '
      'non-contributor edit, no call; a contributor edit, one place box per '
      'contributor of K live before and one per contributor live after, and '
      'one read box per live reader; the first placedIn, c minus the after '
      'boxes already held', () {
    const hR = Handle(1000), hFar = Handle(2000), hS = Handle(3000);
    const hS4 = Handle(4000), hT = Handle(5000), hC = Handle(6000);
    const hS2 = Handle(7000);
    const rod = Rod(0.5, 0.25, 700.75, 300.5);
    const clip = ClipRect(400.5, 300.25);
    final t0 = onA(-6000.5, -4000.25, 0.35);
    final atS4 = onA(-3000.5, 6000.25, 0.5);
    final atT = onA(9000.5, -6000.25, 0.1);
    final atC = onA(-2000.25, 5000.5, -0.2);
    final atC1 = onA(-2600.75, 5400.25, 0.3);
    final atS2 = onA(-9000.75, -1000.5, -0.15);
    Aabb2 clipReach(Transform2 at) => rectReach(clip, at);

    /// Two Lenses, R at [atR] and one parked, and contributors S, S4 and T
    /// and the ClipRect C, all far from each other.
    DraftDocument scene() {
      final doc = paramDoc();
      doc.commands.execute(create(doc, hR, atR, lens));
      doc.commands.execute(create(doc, hFar, parked, lens));
      doc.commands.execute(create(doc, hS, t0, slab));
      doc.commands.execute(create(doc, hS4, atS4, slab));
      doc.commands.execute(create(doc, hT, atT, rod));
      doc.commands.execute(create(doc, hC, atC, clip));
      return doc;
    }

    {
      // A fixture where no reader regenerates: every Lens far from the edit.
      final doc = scene();
      final fields = [field(), lensField(lens, parked)];
      final t1 = onA(-6300.25, -3700.75, 0.45);
      // Premises: both Lenses are empty, so a read box is a field; no Slab
      // box meets a Lens field; no edited object has a contributor
      // neighbour, before or after.
      expect(kids(doc, hR), isEmpty);
      expect(kids(doc, hFar), isEmpty);
      for (final b in [
        slabBox(slab, t0),
        slabBox(slab, t1),
        slabBox(slab, atS2),
      ]) {
        for (final f in fields) {
          expect(b.intersects(f), isFalse);
        }
      }
      final others = [
        slabReach(slab, atS4),
        rectReach(clip, atC),
        rectReach(clip, atC1),
        rodBox(rod, atT),
      ];
      for (final a in [
        slabReach(slab, t0),
        slabReach(slab, t1),
        slabReach(slab, atS2),
      ]) {
        for (final o in others) {
          expect(neighbours(a, o), isFalse);
        }
      }
      for (final c in [clipReach(atC), clipReach(atC1)]) {
        for (final o in [
          slabReach(slab, t0),
          slabReach(slab, atS4),
          rodBox(rod, atT),
        ]) {
          expect(neighbours(c, o), isFalse);
        }
      }
      final r0 = calls(hR), far0 = calls(hFar);

      // No seeds: the early return.
      expect(counted(() => doc.commands.execute(rootLine(doc))), (0, 0));
      // A ClipRect moved: K holds no contributor, so L is empty.
      expect(
          counted(() => doc.commands.execute(TransformNodeCommand(hC, atC1))),
          (0, 0));
      // S moved: its before and its after box; one read box per Lens.
      expect(counted(() => doc.commands.execute(TransformNodeCommand(hS, t1))),
          (2, 2));
      // S2 added: its after box only.
      expect(counted(() => doc.commands.execute(create(doc, hS2, atS2, slab))),
          (1, 2));
      // S2 deleted: its before box only.
      expect(
          counted(() => doc.commands.execute(deleteObject(doc, hS2))), (1, 2));
      expect(calls(hR), r0, reason: 'no reader regenerates');
      expect(calls(hFar), far0);
      expect(drift(doc), isEmpty);
    }
    {
      // Separately, a fixture where a reader regenerates: S into R's field.
      final doc = scene();
      final f = field();
      final t1 = cornerAt(slab, f.minX + 400.25, f.minY + 350.5, 0.15);
      expect(slabBox(slab, t1).intersects(f), isTrue);
      for (final o in [slabReach(slab, atS4), rectReach(clip, atC)]) {
        expect(neighbours(slabReach(slab, t1), o), isFalse);
      }
      expect(neighbours(slabReach(slab, t1), rodBox(rod, atT)), isFalse);
      expect(kids(doc, hR), isEmpty);
      final r0 = calls(hR), far0 = calls(hFar);
      // c: the live contributors after the edit, S, S4 and T.
      const c = 3;
      expect(counted(() => doc.commands.execute(TransformNodeCommand(hS, t1))),
          (2 + (c - 1), 2));
      expect(calls(hR), r0 + 1, reason: 'R regenerated');
      expect(calls(hFar), far0);
      expect(listedBoxes(doc, hR), [boxNear(slabBox(slab, t1))]);
      expect(drift(doc), isEmpty);
    }
  });

  test(
      'SD9 an unchanged neighbour in K adds nothing: a contributor '
      'moved away from a reader, whose unchanged neighbour touches the '
      'reader, regenerates no reader', () {
    for (final exact in [true, false]) {
      generateCalls.clear();
      const hR = Handle(1000), hN = Handle(2000), hS = Handle(3000);
      final f = field();
      final rod = Rod(0.5, 0.25, 1500.75, 900.5, exact: exact);
      // N from inside R's field, up and right out of it.
      final atN = Transform2.translation(f.maxX - 300.25, f.maxY - 200.5)
          .multiply(Transform2.rotation(0.3));
      final nb = rodBox(rod, atN);
      // S's first corner half a millimetre above N's box: its reach overlaps
      // N's; its rectangle, turned by 0.25, lies wholly above it.
      final t0 = cornerAt(slab, nb.maxX - 400.25, nb.maxY + 0.5, 0.25);
      final t1 = cornerAt(slab, nb.maxX + 1100.5, nb.maxY + 2500.25, 0.25);

      final doc = paramDoc();
      doc.commands.execute(create(doc, hR, atR, lens));
      doc.commands.execute(create(doc, hN, atN, rod));
      doc.commands.execute(create(doc, hS, t0, slab));
      expect(listedSegments(doc, hR), hasLength(1), reason: 'R draws N');
      expect(listedBoxes(doc, hR), isEmpty);
      expect(drift(doc), isEmpty);

      // Premises: N is S's neighbour before the move and not after; N's box
      // touches R's read box; S's before and after boxes miss it.
      final read = readBoxOf(doc, hR, lens);
      expect(neighbours(slabReach(slab, t0), rodBox(rod, atN)), isTrue);
      expect(neighbours(slabReach(slab, t1), rodBox(rod, atN)), isFalse);
      expect(nb.intersects(read), isTrue);
      expect(slabBox(slab, t0).intersects(read), isFalse);
      expect(slabBox(slab, t1).intersects(read), isFalse);

      final r0 = calls(hR);
      doc.commands.execute(TransformNodeCommand(hS, t1));
      if (exact) {
        expect(calls(hR), r0, reason: 'N unchanged adds nothing');
      } else {
        // The control: with the default place input N always counts as
        // changed, and its box finds R.
        expect(calls(hR), r0 + 1);
      }
      expect(listedSegments(doc, hR), hasLength(1));
      expect(drift(doc), isEmpty);
    }
  });

  test(
      'SD10 a document with no live reader makes no place-box call on a '
      'contributor edit', () {
    const hS = Handle(1000), hT = Handle(2000), hR = Handle(3000);
    const rod = Rod(0.5, 0.25, 700.75, 300.5);
    final t0 = onA(-6000.5, -4000.25, 0.35);
    final t1 = onA(-6300.25, -3700.75, 0.45);
    final doc = paramDoc();
    doc.commands.execute(create(doc, hS, t0, slab));
    doc.commands.execute(create(doc, hT, onA(9000.5, -6000.25, 0.1), rod));
    expect(counted(() => doc.commands.execute(TransformNodeCommand(hS, t1))),
        (0, 0));
    expect(counted(() => doc.commands.execute(TransformNodeCommand(hS, t0))),
        (0, 0));
    expect(drift(doc), isEmpty);

    // A Lens far away: the same move makes SD6's calls.
    doc.commands.execute(create(doc, hR, parked, lens));
    final f = lensField(lens, parked);
    expect(slabBox(slab, t0).intersects(f), isFalse);
    expect(slabBox(slab, t1).intersects(f), isFalse);
    expect(counted(() => doc.commands.execute(TransformNodeCommand(hS, t1))),
        (2, 1));
    expect(kids(doc, hR), isEmpty);
    expect(drift(doc), isEmpty);

    // One edit that deletes the only Lens and moves S: the reader check
    // reads the after-survey, which holds no reader, so no place box is
    // asked although the before-survey held one.
    expect(
        counted(() => doc.commands.execute(CompoundCommand([
              deleteObject(doc, hR),
              TransformNodeCommand(hS, t0),
            ], label: 'Delete R, move S'))),
        (0, 0));
    expect(doc.tree[hR], isNull);
    expect(sameTransform(doc.tree.accumulatedTransform(hS), t0), isTrue);
    expect(drift(doc), isEmpty);
  });

  test(
      'SD11 the diagonal flip: a contributor whose segment changes '
      'inside an unchanged box regenerates the reader it splits, with the '
      'default placeInput and with an override', () {
    const hR = Handle(1000), hT = Handle(2000);
    final f = field();
    // A quarter turn with exact entries, off the origin at a binary fraction,
    // so both diagonals map to one world box, bit for bit.
    final atT = Transform2(0, 1, -1, 0, (f.center.x * 4).roundToDouble() / 4,
        (f.center.y * 4).roundToDouble() / 4);
    for (final exact in [false, true]) {
      generateCalls.clear();
      final from = Rod(0, 0, 10, 10, exact: exact);
      final to = Rod(0, 10, 10, 0, exact: exact);
      // Premises: the box is unchanged, exactly, and inside R's field; the
      // segment is not.
      expect(sameBox(rodBox(from, atT), rodBox(to, atT)), isTrue);
      expect(rodBox(from, atT).intersects(f), isTrue);
      final (a0, b0) = from.worldEnds(atT);
      final (a1, b1) = to.worldEnds(atT);
      expect([a0.x, a0.y, b0.x, b0.y], isNot(equals([a1.x, a1.y, b1.x, b1.y])));

      final doc = paramDoc();
      doc.commands.execute(create(doc, hR, atR, lens));
      doc.commands.execute(create(doc, hT, atT, from));
      expect(listedSegments(doc, hR), [
        [
          for (final v in [a0.x, a0.y, b0.x, b0.y]) closeTo(v, 1e-6)
        ],
      ]);

      final r0 = calls(hR);
      doc.commands.execute(SetComponentCommand<Rod>(hT, to));
      expect(calls(hR), r0 + 1, reason: 'exact: $exact');
      expect(listedSegments(doc, hR), [
        [
          for (final v in [a1.x, a1.y, b1.x, b1.y]) closeTo(v, 1e-6)
        ],
      ]);
      expect(drift(doc), isEmpty);
    }
  });
  test(
      'SD11b an exact contributor moved into, across and out of a reader\'s '
      'field regenerates the reader each time: its input is its world '
      'segment, read from each view\'s snapshot transform', () {
    const hR = Handle(1000), hT = Handle(2000);
    final f = field();
    const rod = Rod(0.5, 0.25, 500.75, 200.5, exact: true);
    final inside = Transform2.translation(f.minX + 400.5, f.minY + 300.25)
        .multiply(Transform2.rotation(0.35));
    final across = Transform2.translation(f.minX + 900.25, f.minY + 700.75)
        .multiply(Transform2.rotation(-0.45));
    final out = Transform2.translation(f.maxX + 1500.75, f.minY + 300.25)
        .multiply(Transform2.rotation(0.35));
    List<Matcher> seg(Transform2 at) {
      final (a, b) = rod.worldEnds(at);
      return [
        for (final v in [a.x, a.y, b.x, b.y]) closeTo(v, 1e-6)
      ];
    }

    final doc = paramDoc();
    doc.commands.execute(create(doc, hR, atR, lens));
    doc.commands.execute(create(doc, hT, parked, rod));
    expect(kids(doc, hR), isEmpty);
    // Premises: parked and out, T's box misses R's read box; inside and
    // across, it lies in the field; the component never changes, so only
    // the transform tells the two views' inputs apart.
    final read = readBoxOf(doc, hR, lens);
    expect(rodBox(rod, parked).intersects(read), isFalse);
    expect(rodBox(rod, out).intersects(read), isFalse);
    expect(rodBox(rod, inside).intersects(f), isTrue);
    expect(rodBox(rod, across).intersects(f), isTrue);
    expect(sameTransform(inside, across), isFalse);

    for (final (at, listed) in [
      (inside, [seg(inside)]),
      (across, [seg(across)]),
      (out, <List<Matcher>>[]),
    ]) {
      final r0 = calls(hR);
      doc.commands.execute(TransformNodeCommand(hT, at));
      expect(doc.components.get<Rod>(hT), rod);
      expect(calls(hR), r0 + 1, reason: 'R regenerates');
      expect(listedSegments(doc, hR), listed);
      expect(drift(doc), isEmpty);
    }
  });
}
