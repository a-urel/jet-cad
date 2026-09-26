// The dissolve verdict (spec 10 D15): a parametric type may answer that an
// object of the edit's closure is deleted instead of regenerated. The
// planner removes its children and node and detaches its component inside
// the same edit, one undo step. Fuse F sits in a rotated group off the
// origin; ClipRect C, in another rotated group, starts beside it and is
// moved over F's centre.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

const Handle hF = Handle(1000); // the Fuse
const Handle hC = Handle(2000); // the ClipRect

/// F on A's frame (turned, off the origin), its rectangle off its own
/// origin: centre (600.75, 220.125) in F's local space.
const Fuse fuse = Fuse(150.5, -80.25, 900.5, 600.75);
const ClipRect clip = ClipRect(700.5, 500.25);

/// C beside F: no reach overlap.
final Transform2 atC = onA(2500.25, 1200.5, -0.35);

/// F's world centre.
Vector2 fuseCentre() => atA.transformPoint(fuse.centre);

/// C turned 0.7 with its own centre on [p], in world.
Transform2 clipCentredOn(Vector2 p) => Transform2.translation(p.x, p.y)
    .multiply(Transform2.rotation(0.7))
    .multiply(Transform2.translation(-clip.width / 2, -clip.height / 2));

/// C over F's centre.
Transform2 covering() => clipCentredOn(fuseCentre());

/// C over F's far corner (local (1051, 520.5)), pushed 100.25 further out
/// on both of F's axes: it overlaps F's reach but not F's centre.
Transform2 corner() => clipCentredOn(
    atA.transformPoint(fuse.corners[2] + Vector2(100.25, 100.25)));

/// Whether [p] (world) lies inside C placed at [at].
bool inClip(Transform2 at, Vector2 p) {
  final q = at.invert().transformPoint(p);
  return q.x > 0 && q.x < clip.width && q.y > 0 && q.y < clip.height;
}

Aabb2 fuseReach() => const FuseType().reach(fuse, atA);
Aabb2 clipReach(Transform2 at) =>
    const RectType<ClipRect>(Capability.geometry).reach(clip, at);

/// F's world rectangle strictly overlaps [b] on both axes by more than the
/// engine's neighbour tolerance.
bool neighbours(Aabb2 a, Aabb2 b) {
  const tol = Tolerance.standard;
  return a.minX < b.maxX - tol.linear &&
      b.minX < a.maxX - tol.linear &&
      a.minY < b.maxY - tol.linear &&
      b.minY < a.maxY - tol.linear;
}

List<Handle> drift(DraftDocument doc) => ParametricSystem(doc, catalog).drift();

int calls(Handle h) => generateCalls[h] ?? 0;
int asked(Handle h) => Fuse.dissolvesCalls[h] ?? 0;

/// F first, then C: the root lists F before C.
DraftDocument scene() {
  final doc = paramDoc();
  doc.commands.execute(create(doc, hF, atA, fuse));
  doc.commands.execute(create(doc, hC, atC, clip));
  return doc;
}

List<Handle> rootChildren(DraftDocument doc) =>
    (doc.tree[doc.rootHandle]! as GroupNode).children;

/// F's node, component and children are all gone.
void expectDissolved(DraftDocument doc) {
  expect(doc.tree[hF], isNull, reason: 'node');
  expect(doc.components.get<Fuse>(hF), isNull, reason: 'component');
  expect(kids(doc, hF), isEmpty, reason: 'children');
}

/// The select tool's delete of one object: its children, then its node.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// Every command inside [c], compounds and replays opened.
Iterable<DraftCommand> flatten(DraftCommand c) sync* {
  yield c;
  if (c is CompoundCommand) {
    for (final k in c.children) {
      yield* flatten(k);
    }
  } else if (c is ParametricReplay) {
    yield* flatten(c.replay);
  }
}

/// The values of every `SetComponentCommand<Fuse>` on F inside [c].
List<Fuse?> fuseSets(DraftCommand c) => [
      for (final k in flatten(c))
        if (k is SetComponentCommand<Fuse> && k.handle == hF) k.value,
    ];

/// The capability of each `CommandApplied` that [run] causes.
Future<List<Capability>> appliedCapabilities(
    DraftDocument doc, void Function() run) async {
  await pumpEventQueue();
  final out = <Capability>[];
  final sub = doc.changes.listen((c) {
    if (c is CommandApplied) out.add(c.capability);
  });
  run();
  await pumpEventQueue();
  await sub.cancel();
  return out;
}

void main() {
  setUp(() {
    generateCalls.clear();
    Fuse.dissolvesCalls.clear();
  });
  tearDown(() {
    Fuse.fault = false;
  });

  test(
      'DV1 a dissolving object is removed and its component detached in the '
      'edit, one undo step; undo restores every handle; the guard and the '
      'cleanup are untouched; drift() names a loaded one', () async {
    // Premises: C starts beside F; the corner placement overlaps F's reach
    // but not its centre; the covering one holds the centre. F is off the
    // origin and turned.
    expect(neighbours(fuseReach(), clipReach(atC)), isFalse);
    expect(neighbours(fuseReach(), clipReach(corner())), isTrue);
    expect(inClip(corner(), fuseCentre()), isFalse);
    expect(inClip(covering(), fuseCentre()), isTrue);
    expect(fuseCentre().length, greaterThan(1000));

    final doc = scene();
    final handles = kids(doc, hF);
    // A region (fill, boundary) and a LINE.
    expect(handles, hasLength(3));
    expect(
        [for (final k in handles) doc.entities.kindAt(doc.entities.slotOf(k)!)],
        [EntityKind.fill, EntityKind.polyline, EntityKind.line]);
    expect(rootChildren(doc), [hF, hC]);
    expect(drift(doc), isEmpty);
    final initial = canon(doc);

    // 06 D6: a caller's removal of one of F's children while F lives is
    // still refused.
    expect(() => doc.commands.execute(RemoveEntityCommand(handles.last)),
        throwsA(isA<GeneratedGeometryError>()));
    expect(canon(doc), initial);

    // Control: C over F's corner. F is in the closure (C's neighbour), is
    // asked, answers false and regenerates.
    final a0 = asked(hF), g0 = calls(hF);
    doc.commands.execute(TransformNodeCommand(hC, corner()));
    expect(asked(hF), a0 + 1);
    expect(calls(hF), g0 + 1);
    expect(kids(doc, hF), handles);
    expect(doc.components.get<Fuse>(hF), fuse);
    expect(drift(doc), isEmpty);
    doc.commands.undo();
    expect(canon(doc), initial);

    // C over F's centre: F dissolves in the move, one undo step, and is not
    // generated.
    final before = canon(doc, sortNodes: true);
    final depth = doc.commands.undoDepth;
    final a1 = asked(hF), g1 = calls(hF);
    final caps = await appliedCapabilities(
        doc, () => doc.commands.execute(TransformNodeCommand(hC, covering())));
    expectDissolved(doc);
    expect(asked(hF), a1 + 1);
    expect(calls(hF), g1, reason: 'a dissolving object is not generated');
    expect(doc.tree[hC], isNotNull);
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect(caps, [Capability.geometry],
        reason: 'the plan removed entities: the index must hear it');
    expect(drift(doc), isEmpty);
    final after = canon(doc, sortNodes: true);

    // Undo restores the state and every child handle; F's node is linked
    // last among the root's children (D15), so the states are compared with
    // the root's order normalised. Draw order follows the handles.
    doc.commands.undo();
    expect(canon(doc, sortNodes: true), before);
    expect(kids(doc, hF), handles);
    expect(doc.components.get<Fuse>(hF), fuse);
    expect(rootChildren(doc), [hC, hF]);
    expect(drift(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc, sortNodes: true), after);
    expectDissolved(doc);
    doc.commands.undo();
    doc.purge();
    expect(canon(doc, sortNodes: true), before);
    expect(kids(doc, hF), handles);
    expect(drift(doc), isEmpty);

    // Exactly one detach, planned by the dissolve: the move's replay
    // restores F's component once, and its redo detaches it once. Planned
    // on a copy through the expander, so the inverse can be read.
    final copy = reload(enc(doc));
    final edit = copy.commands.expander!(TransformNodeCommand(hC, covering()))
        as ParametricEdit;
    final undoReplay = edit.apply(copy).inverse;
    expectDissolved(copy);
    expect(fuseSets(undoReplay), [fuse]);
    final redoReplay = undoReplay.apply(copy).inverse;
    expect(copy.components.get<Fuse>(hF), fuse);
    expect(fuseSets(redoReplay), [null]);

    // The parameter edit: `burnt` dissolves F the same way, one undo step.
    final depth2 = doc.commands.undoDepth;
    final a2 = asked(hF), g2 = calls(hF);
    doc.commands.execute(SetComponentCommand<Fuse>(
        hF, const Fuse(150.5, -80.25, 900.5, 600.75, burnt: true)));
    expectDissolved(doc);
    expect(asked(hF), a2 + 1);
    expect(calls(hF), g2);
    expect(doc.commands.undoDepth, depth2 + 1);
    expect(drift(doc), isEmpty);
    doc.commands.undo();
    expect(canon(doc, sortNodes: true), before);
    expect(kids(doc, hF), handles);
    expect(doc.components.get<Fuse>(hF), fuse);

    // 06 D8: the select tool's delete of F is a loss, not a dissolve. F is
    // not asked, and its component is detached once, by the cleanup.
    // Planned on a copy through the expander, so the inverse can be read.
    final copy2 = reload(enc(doc));
    Fuse.dissolvesCalls.clear();
    final delete =
        copy2.commands.expander!(deleteObject(copy2, hF)) as ParametricEdit;
    final deleteReplay = delete.apply(copy2).inverse;
    expectDissolved(copy2);
    expect(asked(hF), 0, reason: 'a lost object is not asked');
    expect(fuseSets(deleteReplay), [fuse], reason: 'detached once');

    // 06 D7: the dissolve inherits the triggering move's authority. Only
    // what the move itself needs is allowed, transform; the removals need
    // geometry and structure, the detach components.
    final ruled = scene();
    final ruledBefore = canon(ruled, sortNodes: true);
    ruled.commands.permissions = const DraftPermissions(
        transform: true, components: false, geometry: false, structure: false);
    ruled.commands.execute(TransformNodeCommand(hC, covering()));
    expectDissolved(ruled);
    ruled.commands.undo();
    expect(canon(ruled, sortNodes: true), ruledBefore);
    expect(kids(ruled, hF), handles);
    ruled.commands.redo();
    expectDissolved(ruled);

    // A `dissolves` that throws rolls the edit back: bytes, history and
    // `doc.changes` as they were.
    final faulty = scene();
    final bytes = enc(faulty);
    final faultyDepth = faulty.commands.undoDepth;
    await pumpEventQueue();
    var changes = 0;
    final sub = faulty.changes.listen((_) => changes++);
    Fuse.fault = true;
    expect(
        () => faulty.commands.execute(TransformNodeCommand(hC, covering())),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', 'fuse fault')));
    await pumpEventQueue();
    await sub.cancel();
    Fuse.fault = false;
    expect(enc(faulty), bytes);
    expect(faulty.commands.undoDepth, faultyDepth);
    expect(changes, 0);
    expect(faulty.components.get<Fuse>(hF), fuse);

    // A loaded document holding a burnt Fuse with its children: drift()
    // names it, and changes nothing.
    final edited = jsonDecode(enc(scene())) as Map<String, Object?>;
    ((edited['components']! as Map)[Fuse.id]! as Map)['${hF.value}'] =
        const Fuse(150.5, -80.25, 900.5, 600.75, burnt: true).toJson();
    final loaded = reload(jsonEncode(edited));
    final loadedBytes = enc(loaded);
    expect(loaded.components.get<Fuse>(hF)!.burnt, isTrue);
    expect(kids(loaded, hF), handles);
    expect(drift(loaded), [hF]);
    expect(enc(loaded), loadedBytes, reason: 'a dry run');
  });
}
