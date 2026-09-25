// Spec 08 D4, D5, D17 (engine half): the per-type reference policy, the
// cascade inside the edit, the dangling-reference refusal, and
// `parametric.dangling` / `parametric.orphan`. Post A sits in a rotated
// group off the origin; every referrer's own group has a different rotated,
// translated transform; ClipRect C overlaps A's bottom-right corner, so A's
// bottom edge -- which each Pin copies -- is clipped (the two-hop shape).
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

const Handle hC = Handle(2000);
const Handle hP1 = Handle(3000);
const Handle hP2 = Handle(3100);
const Handle hQ = Handle(3200);
const Handle hT = Handle(3300);
const Handle hD = Handle(4000);

/// C over A's bottom-right corner: A's bottom edge keeps [0, ~1639] only.
final Transform2 atC = onA(1700, -300, 0.2);

final Transform2 p1At =
    Transform2.translation(8400, 1900).multiply(Transform2.rotation(-1.05));
final Transform2 p2At =
    Transform2.translation(5600, 4700).multiply(Transform2.rotation(2.3));
final Transform2 qAt =
    Transform2.translation(9300, 5200).multiply(Transform2.rotation(0.85));
final Transform2 tAt =
    Transform2.translation(6100, 900).multiply(Transform2.rotation(-2.6));

const Post postA = Post(2000, 1000);
const ClipRect rectC = ClipRect(400, 900);

List<Handle> drift(DraftDocument doc) => ParametricSystem(doc, catalog).drift();

/// The engine's own reference entries (`parametric.*`), in report order.
List<Diagnostic> references(DraftDocument doc) => [
      for (final d in ParametricSystem(doc, catalog).diagnostics())
        if (d.code == 'parametric.dangling' || d.code == 'parametric.orphan') d,
    ];

/// The select tool's delete of one object: its children, then its node.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// A, C (a [Trip] when [trip]), P1 (lines) and P2 (a region too) on A;
/// with [q], Pin Q on P1; with [tag], Tag T on A.
DraftDocument scene({bool trip = false, bool q = false, bool tag = false}) {
  final doc = paramDoc();
  doc.commands.execute(create(doc, hA, atA, postA));
  doc.commands.execute(trip
      ? create(doc, hC, atC, const Trip(400, 900))
      : create(doc, hC, atC, rectC));
  doc.commands.execute(create(doc, hP1, p1At, const Pin(hA, 450)));
  doc.commands
      .execute(create(doc, hP2, p2At, const Pin(hA, 1250, region: true)));
  if (q) doc.commands.execute(create(doc, hQ, qAt, const Pin(hP1, 0)));
  if (tag) doc.commands.execute(create(doc, hT, tAt, const Tag(hA)));
  return doc;
}

List<double> seg(Vector2 a, Vector2 b) => [a.x, a.y, b.x, b.y];

bool hasSegment(List<List<double>> segments, List<double> want) =>
    segments.any((s) => [
          for (var k = 0; k < 4; k++) (s[k] - want[k]).abs(),
        ].every((d) => d < 1e-6));

/// [r]'s four edges at [at], in world.
List<List<double>> worldEdges(RectParams r, Transform2 at) {
  final c = [for (final p in corners(r)) at.transformPoint(p)];
  return [for (var i = 0; i < 4; i++) seg(c[i], c[(i + 1) % 4])];
}

/// The orphan marker of a Tag at [at], in world.
List<double> worldMarker(Transform2 at) => seg(at.transformPoint(Vector2(0, 0)),
    at.transformPoint(Vector2(0, Tag.marker)));

/// [h]'s one child's stored coordinates.
List<double> storedCoords(DraftDocument doc, Handle h) => doc.geometry
    .read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!))
    .coords
    .toList();

bool hasFill(DraftDocument doc, Handle group) => kids(doc, group).any(
    (k) => doc.entities.kindAt(doc.entities.slotOf(k)!) == EntityKind.fill);

/// `canon(sortNodes: true)` without the handle seed, which undo never
/// lowers (it only rises, so no handle is reused): the delete's
/// regeneration of C adds a child, and undo removes it (06's
/// `canonForUndo`, `guards_test.dart`).
String state(DraftDocument doc) {
  final j = jsonDecode(canon(doc, sortNodes: true)) as Map<String, Object?>;
  expect(j.remove('handleSeed'), isNotNull);
  return jsonEncode(j);
}

/// Every child handle of [groups].
Map<Handle, List<Handle>> childHandles(
        DraftDocument doc, List<Handle> groups) =>
    {for (final g in groups) g: kids(doc, g)};

void expectGone(DraftDocument doc, Handle h) {
  expect(doc.tree[h], isNull, reason: '${h.toHex()} node');
  expect(doc.components.get<Post>(h), isNull, reason: '${h.toHex()} Post');
  expect(doc.components.get<Pin>(h), isNull, reason: '${h.toHex()} Pin');
  expect(kids(doc, h), isEmpty, reason: '${h.toHex()} children');
}

/// Counts `doc.changes` events. The stream is asynchronous: read [count]
/// after `pumpEventQueue()`.
final class ChangeCount {
  ChangeCount(DraftDocument doc) {
    doc.changes.listen((_) => count++);
  }
  int count = 0;
}

/// A `cascade`-policy client naming two referents (Ruling 08-5's order).
final class Brace implements Component {
  const Brace(this.a, this.b);
  static const String id = 'test.brace';
  final Handle a, b;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'a': a.toJson(), 'b': b.toJson()};
  static Brace fromJson(Map<String, Object?> j) =>
      Brace(Handle.fromJson(j['a']), Handle.fromJson(j['b']));
  @override
  bool operator ==(Object o) => o is Brace && o.a == a && o.b == b;
  @override
  int get hashCode => Object.hash(a, b);
}

final class BraceType extends ParametricType<Brace> {
  const BraceType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Brace params, Transform2 toWorld) => Aabb2.empty();
  @override
  Iterable<Handle> references(Brace params) => [params.a, params.b];
  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
}

final ParametricCatalog braceCatalog = testCatalog()
  ..register<Brace>(Brace.id, Brace.fromJson, const BraceType());

/// [scene]'s encoding, edited by [edit] over its entity list, then loaded.
DraftDocument loadedScene(
    void Function(Map<String, Object?> j, List<Map<String, Object?>> e) edit) {
  final j = jsonDecode(enc(scene())) as Map<String, Object?>;
  edit(j, [for (final e in j['entities']! as List) e as Map<String, Object?>]);
  return reload(jsonEncode(j));
}

Map<String, Object?> recordOf(Map<String, Object?> e) =>
    e['record']! as Map<String, Object?>;

Map<String, Object?> geometryOf(Map<String, Object?> e) =>
    e['geometry']! as Map<String, Object?>;

/// P2's region's entity of [kind] (`fill` or `polyline`) in [entities].
Map<String, Object?> p2Region(
        List<Map<String, Object?>> entities, String kind) =>
    entities.firstWhere((e) =>
        recordOf(e)['owner'] == hP2.value && recordOf(e)['kind'] == kind);

void main() {
  setUp(() {
    generateCalls.clear();
    Post.watch = [];
    Post.seen.clear();
  });
  tearDown(() {
    Trip.mode = TripMode.off;
  });

  test(
      'CS1 deleting Post A with the select tool\'s compound cascades P1 and '
      'P2 in the same edit: one undo step; undo, redo, and undo then purge '
      'restore the state and every child handle', () async {
    final doc = scene();
    expect(drift(doc), isEmpty);
    // Not degenerate: C clips A, so P1 copies a clipped edge; P2 carries a
    // region, whose fill the cascade must leave to its boundary.
    final p1 = worldSegments(doc, hP1);
    expect(p1, hasLength(1));
    expect(
        hasSegment(
            p1,
            seg(atA.transformPoint(Vector2(0, 0)),
                atA.transformPoint(Vector2(2000, 0)))),
        isFalse);
    expect(hasFill(doc, hP2), isTrue);
    final cBefore = worldSegments(doc, hC);
    expect(cBefore, isNot(hasLength(4)), reason: 'A clips C');
    final handles = childHandles(doc, [hA, hC, hP1, hP2]);
    for (final h in [hA, hC, hP1, hP2]) {
      expect(handles[h], isNotEmpty, reason: h.toHex());
    }
    final before = state(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(deleteObject(doc, hA));
    // A listener-driven cascade would run here.
    await pumpEventQueue();
    for (final h in [hA, hP1, hP2]) {
      expectGone(doc, h);
    }
    // C regenerated: nothing clips it any more.
    final cNow = worldSegments(doc, hC);
    expect(cNow, hasLength(4));
    for (final e in worldEdges(rectC, atC)) {
      expect(hasSegment(cNow, e), isTrue);
    }
    expect(drift(doc), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    final after = state(doc);

    doc.commands.undo();
    expect(state(doc), before);
    expect(childHandles(doc, [hA, hC, hP1, hP2]), handles);
    doc.commands.redo();
    expect(state(doc), after);
    doc.commands.undo();
    doc.purge();
    expect(state(doc), before);
    expect(childHandles(doc, [hA, hC, hP1, hP2]), handles);
    expect(drift(doc), isEmpty);
  });

  test(
      'CS2 a transitive cascade: Q on P1 on A; deleting A removes P1 and '
      'then Q in the same edit; one step; undo restores all four', () async {
    final doc = scene(q: true);
    // Not degenerate: Q draws a line to P1's origin.
    final q = worldSegments(doc, hQ);
    expect(q, hasLength(1));
    expect(
        hasSegment(
            q,
            seg(qAt.transformPoint(Vector2(0, 0)),
                p1At.transformPoint(Vector2(0, 0)))),
        isTrue);
    final handles = childHandles(doc, [hA, hP1, hP2, hQ]);
    final before = state(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(deleteObject(doc, hA));
    await pumpEventQueue();
    for (final h in [hA, hP1, hP2, hQ]) {
      expectGone(doc, h);
    }
    expect(drift(doc), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);

    doc.commands.undo();
    expect(state(doc), before);
    expect(childHandles(doc, [hA, hP1, hP2, hQ]), handles);
  });

  test(
      'CS3 an orphan-policy Tag on A is kept when A goes, regenerates to its '
      'marker in the same edit, and is reported parametric.orphan once',
      () async {
    final doc = scene(tag: true);
    // Not degenerate: T copies A's clipped bottom edge while A lives.
    final t0 = worldSegments(doc, hT);
    expect(t0, hasLength(1));
    expect(hasSegment(t0, worldSegments(doc, hP1).single), isTrue);
    expect(hasSegment(t0, worldMarker(tAt)), isFalse);
    expect(references(doc), isEmpty);
    final before = state(doc);
    final depth = doc.commands.undoDepth;
    generateCalls.clear();

    doc.commands.execute(deleteObject(doc, hA));
    await pumpEventQueue();
    expect(doc.tree[hT], isA<GroupNode>());
    expect(doc.components.get<Tag>(hT), const Tag(hA));
    expect(generateCalls[hT], 1, reason: 'regenerated in the same edit');
    final t = kids(doc, hT);
    expect(t, hasLength(1));
    expect(storedCoords(doc, t.single), tagMarker.coords.toList());
    final world = worldSegments(doc, hT);
    expect(hasSegment(world, worldMarker(tAt)), isTrue);
    // The Pins went, the Tag stayed.
    expectGone(doc, hP1);
    expectGone(doc, hP2);
    expect(drift(doc), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    final report = references(doc);
    expect(report, hasLength(1));
    expect(report.single.code, 'parametric.orphan');
    expect(report.single.severity, DiagnosticSeverity.warning);
    expect(report.single.handles, [hT, hA]);

    doc.commands.undo();
    expect(state(doc), before);
    expect(references(doc), isEmpty);
  });

  test(
      'LV1 (Task 1 I-1) the view hides a referent lost in this edit: an '
      'orphan Tag never sees its deleted Post, whose component is detached '
      'only after the plan, nor draws it at the world origin', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands.execute(create(doc, hT, tAt, const Tag(hA)));
    // Not degenerate: T copies A's whole bottom edge while A lives.
    expect(
        hasSegment(
            worldSegments(doc, hT),
            seg(atA.transformPoint(Vector2(0, 0)),
                atA.transformPoint(Vector2(2000, 0)))),
        isTrue);

    doc.commands.execute(deleteObject(doc, hA));
    final world = worldSegments(doc, hT);
    expect(world, hasLength(1));
    expect(hasSegment(world, worldMarker(tAt)), isTrue);
    // Task 1's probe: A's bottom edge, drawn with the identity transform.
    expect(hasSegment(world, [0, 0, 2000, 0]), isFalse);
    expect(doc.components.get<Post>(hA), isNull);
    expect(drift(doc), isEmpty);
  });

  test(
      'CS4 a bare RemoveNodeCommand of A: P1\'s and P2\'s leaves and nodes '
      'are removed; A\'s own leaves remain (06\'s recorded debt)', () {
    final doc = scene();
    final aKids = kids(doc, hA);
    expect(aKids, isNotEmpty);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(RemoveNodeCommand(hA));
    expectGone(doc, hP1);
    expectGone(doc, hP2);
    expect(doc.tree[hA], isNull);
    expect(doc.components.get<Post>(hA), isNull);
    expect(kids(doc, hA), aKids, reason: '06 debt: A\'s leaves stay');
    expect(doc.commands.undoDepth, depth + 1);
  });

  test(
      'CS5 a neighbour whose generate throws after the cascade: the delete '
      'is refused, and the bytes, the Pins\' children, the undo depth and '
      'doc.changes are unchanged', () async {
    final doc = scene(trip: true);
    expect(drift(doc), isEmpty);
    final handles = childHandles(doc, [hA, hC, hP1, hP2]);
    // The root's child order is normalised (06's convention); the seed is
    // compared too: nothing was added.
    final before = canon(doc, sortNodes: true);
    final depth = doc.commands.undoDepth;
    await pumpEventQueue();
    final changes = ChangeCount(doc);
    Trip.mode = TripMode.throwing;

    expect(
        () => doc.commands.execute(deleteObject(doc, hA)),
        throwsA(
            isA<StateError>().having((e) => e.message, 'message', 'tripwire')));
    await pumpEventQueue();
    expect(canon(doc, sortNodes: true), before);
    expect(childHandles(doc, [hA, hC, hP1, hP2]), handles);
    expect(doc.components.get<Pin>(hP1), const Pin(hA, 450));
    expect(doc.commands.undoDepth, depth);
    expect(changes.count, 0);

    // Control: disarmed, the same delete lands and is counted.
    Trip.mode = TripMode.off;
    doc.commands.execute(deleteObject(doc, hA));
    await pumpEventQueue();
    expect(changes.count, 1);
    expectGone(doc, hP1);
  });

  test(
      'CS6 A\'s component detached: A stops being an object though its '
      'node stays, and P1 and P2 cascade in the same edit', () {
    final doc = scene();
    final before = state(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(SetComponentCommand<Post>(hA, null));
    expect(doc.tree[hA], isA<GroupNode>());
    expectGone(doc, hP1);
    expectGone(doc, hP2);
    expect(drift(doc), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    doc.commands.undo();
    expect(state(doc), before);
  });

  test(
      'CS7 A re-parented under another root group: A stops being an object '
      'and P1 and P2 cascade in the same edit', () {
    final doc = scene();
    final g = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: g,
        parent: doc.rootHandle,
        transform: parked,
        children: const [])));
    final before = state(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(CompoundCommand([
      RemoveNodeCommand(hA),
      AddNodeCommand(
          GroupNode(handle: hA, parent: g, transform: atA, children: const [])),
    ], label: 'Re-parent'));
    expect(doc.tree[hA]!.parent, g);
    expect(doc.components.get<Post>(hA), postA, reason: 'misplaced, kept');
    expectGone(doc, hP1);
    expectGone(doc, hP2);
    expect(drift(doc), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    doc.commands.undo();
    expect(state(doc), before);
  });

  test(
      'DR1 an edit naming a root LINE, a plain group or a deleted object as '
      'a Pin\'s host is refused, and nothing changes; the same edit on a Tag '
      'is accepted and reported parametric.orphan', () async {
    final doc = scene(tag: true);
    final line = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7200.5, 2100.25), Vector2(7300.75, 2210.5)));
    doc.commands.execute(line);
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: parked,
        children: const [])));
    doc.commands.execute(create(doc, hD, parked, const Post(600, 300)));
    doc.commands.execute(deleteObject(doc, hD));
    expect(doc.tree[hD], isNull);
    await pumpEventQueue();
    final changes = ChangeCount(doc);

    for (final x in [line.record.handle, group, hD]) {
      final before = enc(doc);
      final depth = doc.commands.undoDepth;
      expect(
          () =>
              doc.commands.execute(SetComponentCommand<Pin>(hP1, Pin(x, 450))),
          throwsA(isA<DanglingReferenceError>()
              .having((e) => e.object, 'object', hP1)
              .having((e) => e.referent, 'referent', x)),
          reason: x.toHex());
      await pumpEventQueue();
      expect(enc(doc), before, reason: x.toHex());
      expect(doc.commands.undoDepth, depth, reason: x.toHex());
      expect(changes.count, 0, reason: x.toHex());
    }

    for (final (i, x) in [line.record.handle, group, hD].indexed) {
      final depth = doc.commands.undoDepth;
      doc.commands.execute(SetComponentCommand<Tag>(hT, Tag(x)));
      await pumpEventQueue();
      expect(changes.count, i + 1);
      expect(doc.commands.undoDepth, depth + 1);
      final t = kids(doc, hT);
      expect(t, hasLength(1));
      expect(storedCoords(doc, t.single), tagMarker.coords.toList());
      expect(drift(doc), isEmpty);
      final report = references(doc);
      expect(report, hasLength(1), reason: x.toHex());
      expect(report.single.code, 'parametric.orphan');
      expect(report.single.handles, [hT, x]);
    }
  });

  test(
      'DR2 a file whose P1 names a missing host loads unchanged; '
      'diagnostics() reports parametric.dangling; drift() names P1; an '
      'unrelated edit is not refused', () {
    // P1 hangs off P2 here, so no other object stores anything of P1's
    // (a Post would store a tick for it).
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands.execute(create(doc, hC, atC, rectC));
    doc.commands
        .execute(create(doc, hP2, p2At, const Pin(hA, 1250, region: true)));
    doc.commands.execute(create(doc, hP1, p1At, const Pin(hP2, 450)));
    expect(worldSegments(doc, hP1), hasLength(1),
        reason: 'not degenerate: P1 stores a line to P2');
    expect(drift(doc), isEmpty);
    final missing = Handle(doc.handleSeed.current.value + 1000);

    final edited = jsonDecode(enc(doc)) as Map<String, Object?>;
    ((edited['components']! as Map)[Pin.id]! as Map)['${hP1.value}'] =
        Pin(missing, 450).toJson();
    final text = jsonEncode(edited);
    final loaded = reload(text);
    expect(jsonEncode(DraftDocumentCodec.encode(loaded)), text);
    expect(loaded.components.get<Pin>(hP1), Pin(missing, 450));

    final report = references(loaded);
    expect(report, hasLength(1));
    expect(report.single.code, 'parametric.dangling');
    expect(report.single.severity, DiagnosticSeverity.error);
    expect(report.single.handles, [hP1, missing]);
    expect(drift(loaded), [hP1]);

    final depth = loaded.commands.undoDepth;
    loaded.commands.execute(addDrafted(loaded, EntityKind.line,
        linePayload(Vector2(7210.5, 2150.25), Vector2(7390.75, 2290.5))));
    loaded.commands.execute(TransformNodeCommand(hC, onA(1600, -250, 0.25)));
    expect(loaded.commands.undoDepth, depth + 2);
    expect(drift(loaded), [hP1]);
    expect(references(loaded).single.handles, [hP1, missing]);
  });
  test(
      'CS8 (Task 2 review I-1) a detached host with no neighbour: the plan '
      'is empty, but the cascade removed entities, so the edit reports '
      'geometry and the spatial index drops P1\'s children', () async {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands
        .execute(create(doc, hP1, p1At, const Pin(hA, 450, region: true)));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    // P1's region's right edge, in world: nothing of A's is near it.
    final probe = p1At.transformPoint(Vector2(50, 25));
    final hit = HitPath();
    expect(index.pickInto(probe, 2.0, QueryFilter.picking(), hit), isTrue);
    expect(kids(doc, hP1), contains(hit.entity));
    await pumpEventQueue();
    final changes = <CommandApplied>[];
    doc.changes.listen((c) {
      if (c is CommandApplied) changes.add(c);
    });

    doc.commands.execute(SetComponentCommand<Post>(hA, null));
    await pumpEventQueue();
    expectGone(doc, hP1);
    expect(changes.single.capability, isNot(Capability.components));
    expect(index.pickInto(probe, 2.0, QueryFilter.picking(), hit), isFalse);
  });

  test(
      'CS9 (Task 2 review I-2) a cascade command that throws after an '
      'earlier referrer\'s removals applied: the delete is refused, and the '
      'document, the history and doc.changes are as before', () async {
    // A second fill, owned by the root, names P2's boundary: once P2's own
    // fill is gone, removing the boundary is refused (it cannot rebuild
    // that pair), after P1 and P2's fill have already been removed.
    final doc = loadedScene((j, entities) {
      final copy = jsonDecode(jsonEncode(p2Region(entities, 'fill')))
          as Map<String, Object?>;
      final seed = j['handleSeed']! as int;
      recordOf(copy)['handle'] = seed + 1;
      recordOf(copy)['owner'] = j['root'];
      (j['entities']! as List).add(copy);
      j['handleSeed'] = seed + 1;
    });
    expect(doc.validate().map((d) => d.code),
        contains('fill.boundary_foreign_owner'));
    expect(kids(doc, hP1), isNotEmpty);
    final before = canon(doc, sortNodes: true);
    final depth = doc.commands.undoDepth;
    await pumpEventQueue();
    final changes = ChangeCount(doc);

    expect(
        () => doc.commands.execute(deleteObject(doc, hA)),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            startsWith('cannot remove boundary'))));
    await pumpEventQueue();
    expect(canon(doc, sortNodes: true), before);
    expect(doc.commands.undoDepth, depth);
    expect(changes.count, 0);
  });

  test(
      'CS10 (Task 2 review m-1) a loaded region whose boundary cannot be '
      'filled (open), or whose fill names no boundary: the cascade removes '
      'the fill first, so deleting A lands; one step; undo is exact', () async {
    final open = loadedScene((j, entities) {
      final g = geometryOf(p2Region(entities, 'polyline'));
      final coords = g['coords']! as List;
      g['coords'] = coords.sublist(0, coords.length - 2);
    });
    final missing = loadedScene((j, entities) {
      geometryOf(p2Region(entities, 'fill'))['scalars'] = [-7];
    });
    expect(missing.validate().map((d) => d.code),
        contains('fill.boundary_missing'));
    for (final (name, doc) in [('open', open), ('missing', missing)]) {
      expect(hasFill(doc, hP2), isTrue, reason: name);
      final before = state(doc);
      final depth = doc.commands.undoDepth;

      doc.commands.execute(deleteObject(doc, hA));
      for (final h in [hA, hP1, hP2]) {
        expectGone(doc, h);
      }
      expect(doc.commands.undoDepth, depth + 1, reason: name);
      final after = state(doc);
      doc.commands.undo();
      expect(state(doc), before, reason: name);
      doc.commands.redo();
      expect(state(doc), after, reason: name);
    }
  });

  test(
      'CS11 (Task 2 review m-3; Task 2 re-review m1) the cascade removes a '
      'referrer\'s subtree as the select tool does: a nested group under P1, '
      'with its own leaf, and an instance under P1 go too; validate() stays '
      'clean; undo is exact', () {
    final doc = scene();
    final definition = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: definition,
        name: 'Stool',
        basePoint: Vector2(35.5, -12.25),
        children: const []));
    final instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: instance,
        parent: hP1,
        transform: Transform2.translation(-240, 95)
            .multiply(Transform2.rotation(-0.35)),
        definition: definition,
        layer: ReservedHandles.layerZero)));
    final nested = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: nested,
        parent: hP1,
        transform:
            Transform2.translation(120, -80).multiply(Transform2.rotation(0.6)),
        children: const [])));
    final leaf = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: draftRecord(leaf, nested, EntityKind.line),
        payload: linePayload(Vector2(10.5, 20.25), Vector2(310.75, 45.5))));
    expect(doc.validate(), isEmpty);
    expect(drift(doc), isEmpty);
    final before = state(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(deleteObject(doc, hA));
    expectGone(doc, hP1);
    expect(doc.tree[nested], isNull);
    expect(doc.tree[instance], isNull);
    expect(doc.entities.slotOf(leaf), isNull);
    expect(doc.validate(), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    doc.commands.undo();
    expect(state(doc), before);
    expect(doc.tree[nested]!.parent, hP1);
    expect(doc.tree[instance]!.parent, hP1);
    expect(doc.entities.ownerAt(doc.entities.slotOf(leaf)!), nested);
  });

  test(
      'CS12 (Task 2 re-review m2) a loaded region whose fill sits in a group '
      'nested under P2 and whose boundary is P2\'s own: every fill of the '
      'doomed subtree goes before any boundary, so deleting A lands in one '
      'step, validate() shows nothing new, undo and redo are exact', () {
    final doc = loadedScene((j, entities) {
      final seed = j['handleSeed']! as int;
      final nested = seed + 1;
      final nodes = j['nodes']! as List;
      final p2 = nodes
          .cast<Map<String, Object?>>()
          .firstWhere((n) => n['handle'] == hP2.value);
      (p2['children']! as List).add(nested);
      nodes.add({
        'type': 'group',
        'handle': nested,
        'parent': hP2.value,
        'transform': [0.8, 0.6, -0.6, 0.8, 140.5, -65.25],
        'visible': true,
        'children': <int>[],
        'exportAsDxfGroup': false,
      });
      recordOf(p2Region(entities, 'fill'))['owner'] = nested;
      j['handleSeed'] = nested;
    });
    final fill = doc.entities.handleAt(doc.entities.liveSlots
        .firstWhere((s) => doc.entities.kindAt(s) == EntityKind.fill));
    final nested = doc.entities.ownerAt(doc.entities.slotOf(fill)!);
    expect(doc.tree[nested]!.parent, hP2);
    expect(hasFill(doc, hP2), isFalse);
    expect(kids(doc, hP2), isNotEmpty, reason: 'the boundary stays in P2');
    final diagnosed = {for (final d in doc.validate()) d.code};
    final before = state(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(deleteObject(doc, hA));
    for (final h in [hA, hP1, hP2]) {
      expectGone(doc, h);
    }
    expect(doc.tree[nested], isNull);
    expect(doc.entities.slotOf(fill), isNull);
    expect({for (final d in doc.validate()) d.code}.difference(diagnosed),
        isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    final after = state(doc);
    doc.commands.undo();
    expect(state(doc), before);
    expect(doc.entities.ownerAt(doc.entities.slotOf(fill)!), nested);
    doc.commands.redo();
    expect(state(doc), after);
  });

  test(
      'DR3 (Task 2 review m-2) Ruling 08-5\'s order: the lowest dead '
      'referent of the lowest seed is the one refused', () {
    final doc = DraftDocument.empty();
    ParametricSystem(doc, braceCatalog).install();
    final line = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7200.5, 2100.25), Vector2(7300.75, 2210.5)));
    doc.commands.execute(line);
    final low = line.record.handle;
    final high = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: high,
        parent: doc.rootHandle,
        transform: parked,
        children: const [])));
    expect(low.value, lessThan(high.value));
    const h1 = Handle(6000), h2 = Handle(6100);
    // A refused create still raises the handle seed (06: `AddNodeCommand`
    // raises it and its rollback does not lower it): compared without it.
    String bytes() {
      final j = jsonDecode(enc(doc)) as Map<String, Object?>;
      expect(j.remove('handleSeed'), isNotNull);
      return jsonEncode(j);
    }

    final before = bytes();

    // One seed: declared high first, refused on low.
    expect(
        () => doc.commands.execute(create(doc, h1, tAt, Brace(high, low))),
        throwsA(isA<DanglingReferenceError>()
            .having((e) => e.object, 'object', h1)
            .having((e) => e.referent, 'referent', low)));
    // Two seeds, the higher one first in the command: the lower is refused.
    expect(
        () => doc.commands.execute(CompoundCommand([
              create(doc, h2, qAt, Brace(low, low)),
              create(doc, h1, tAt, Brace(high, high)),
            ], label: 'Two')),
        throwsA(isA<DanglingReferenceError>()
            .having((e) => e.object, 'object', h1)
            .having((e) => e.referent, 'referent', high)));
    expect(bytes(), before);
    expect(doc.tree[h1], isNull);
    expect(doc.tree[h2], isNull);
  });

  test(
      'LV2 (the broader paramsOf rule) a Post re-parented under a plain '
      'group is no object, and its orphan Tag sees it gone in drift() too: '
      'drift() is empty and parametric.orphan names it', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands.execute(create(doc, hT, tAt, const Tag(hA)));
    final g = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: g,
        parent: doc.rootHandle,
        transform: parked,
        children: const [])));
    expect(hasSegment(worldSegments(doc, hT), worldMarker(tAt)), isFalse);

    doc.commands.execute(CompoundCommand([
      RemoveNodeCommand(hA),
      AddNodeCommand(
          GroupNode(handle: hA, parent: g, transform: atA, children: const [])),
    ], label: 'Re-parent'));
    // The Post keeps its component on a nested group: misplaced, not live.
    expect(doc.components.get<Post>(hA), postA);
    expect(hasSegment(worldSegments(doc, hT), worldMarker(tAt)), isTrue);
    expect(drift(doc), isEmpty);
    final report = references(doc);
    expect(report.single.code, 'parametric.orphan');
    expect(report.single.handles, [hT, hA]);
  });
}
