import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

/// The select tool's delete cascade for one group (select_tool.dart:654-682).
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

const DraftPermissions runtime = DraftPermissions.runtime;

/// G10's probe: a minimal parametric type whose `generate` can attempt one
/// reentrant `execute`, on a command unrelated to any parametric closure --
/// a geometry edit of a plain line owned by the root, not by [self] or any
/// of its neighbours. That is deliberate: unlike `Trip.reentrant` (which
/// sets a `Trip` on itself and so re-triggers its own regeneration, tripping
/// the *existing* `apply()` guard one level down, whether or not `drift()`
/// guards itself), this reentrant edit touches nothing the planner tracks,
/// so `_run` finds an empty seed set and returns without planning again. A
/// successful reentrant execute here would therefore actually land -- and
/// stay landed -- unless `drift()` itself is guarded (spec 06 D2, F5).
DraftDocument? _probeDoc;
Handle? _probeTarget;
bool _probeArmed = false;

final class ReentrantProbe implements Component {
  const ReentrantProbe(this.n);
  static const String id = 'test.reentrantProbe';
  final int n;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'n': n};
  static ReentrantProbe fromJson(Map<String, Object?> j) =>
      ReentrantProbe(j['n']! as int);
  @override
  bool operator ==(Object o) => o is ReentrantProbe && o.n == n;
  @override
  int get hashCode => n.hashCode;
}

final class ReentrantProbeType extends ParametricType<ReentrantProbe> {
  const ReentrantProbeType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(ReentrantProbe params, Transform2 toWorld) =>
      Aabb2.fromPoints([toWorld.transformPoint(Vector2(0, 0))]);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    if (_probeArmed) {
      _probeArmed = false;
      _probeDoc!.commands.execute(SetEntityGeometryCommand(
          _probeTarget!, linePayload(Vector2(9, 9), Vector2(8, 8))));
    }
    return const [];
  }
}

/// A `GroupNode`'s `children` is draw order, but draw order *is* ascending
/// handle value (D12; `tree.dart:586`'s own append-only `_link`), never the
/// list position. `RemoveNodeCommand`'s inverse (`AddNodeCommand`) re-links a
/// restored node at the *end* of its parent's `children` rather than back at
/// its old index (`tree.dart:557`) -- that is documented, pre-existing engine
/// behaviour, not something the parametric wrapper does. A delete-then-undo
/// round trip through the root therefore reorders the root's `children`
/// without changing anything observable. `enc`/`canon` (support/fixture.dart)
/// compare raw bytes and do not account for it, so it is normalised here,
/// once, for the two guards that undo a `RemoveNodeCommand`.
Object? _sortNodeChildren(Object? j) {
  if (j is Map<String, Object?>) {
    final nodes = j['nodes'];
    if (nodes is List) {
      for (final n in nodes) {
        final node = n as Map<String, Object?>;
        final children = node['children'];
        if (children is List) {
          children.sort((a, b) => (a as int).compareTo(b as int));
        }
      }
    }
  }
  return j;
}

/// [enc], with the root's child-node order normalised (see
/// [_sortNodeChildren]).
String encNodesSorted(DraftDocument d) =>
    jsonEncode(_sortNodeChildren(DraftDocumentCodec.encode(d)));

/// [canon], with the root's child-node order normalised (see
/// [_sortNodeChildren]) and, further, without `handleSeed`:
/// `HandleSeed.raiseTo` never moves backward (`handle.dart:75`), so once a
/// delete's regeneration lands a genuinely new entity (here, B's swallowed
/// edge reappearing), undoing that edit cannot lower the seed back to its
/// pre-edit value even though every node, entity and component is restored.
/// Used only for a before/after-undo comparison that crosses such a
/// regeneration.
String canonForUndo(DraftDocument d) {
  final j = _sortNodeChildren(jsonDecode(canon(d))) as Map<String, Object?>;
  j.remove('handleSeed');
  return jsonEncode(j);
}

void main() {
  tearDown(() {
    Trip.mode = TripMode.off;
    Trip.document = null;
  });

  test(
      'G1 a direct edit of a generated line is refused, and nothing '
      'changes (M-06j)', () {
    final doc = paramDoc();
    pair(doc);
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    final k = kids(doc, hA).first;
    expect(
        () => doc.commands.execute(SetEntityGeometryCommand(
            k, linePayload(Vector2(1, 2), Vector2(3, 4)))),
        throwsA(isA<GeneratedGeometryError>()
            .having((e) => e.handle, 'handle', k)));
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
  });

  test('G2 adding an entity into a parametric group is refused', () {
    final doc = paramDoc();
    pair(doc);
    final depth = doc.commands.undoDepth;
    final add = AddEntityCommand(
        record: draftRecord(doc.handleSeed.next(), hA, EntityKind.line),
        payload: linePayload(Vector2(1, 2), Vector2(3, 4)));
    expect(() => doc.commands.execute(add),
        throwsA(isA<GeneratedGeometryError>()));
    expect(kids(doc, hA), hasLength(5));
    expect(doc.commands.undoDepth, depth);
  });

  test(
      'G3 delete detaches the component, the neighbour regrows, undo '
      'brings all back (M-06k)', () {
    final doc = paramDoc();
    pair(doc);
    final before = canonForUndo(doc);
    doc.commands.execute(deleteObject(doc, hA));
    expect(doc.components.get<ClipRect>(hA), isNull);
    expect(doc.tree[hA], isNull);
    expect(kids(doc, hB), hasLength(4));
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);
    doc.commands.undo();
    expect(canonForUndo(doc), before);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
  });

  test(
      'G4 runtime: a geometry-type edit is refused; a components-type '
      'edit, its undo and its redo all succeed (M-06i)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const ClipRect(2000, 1000)));
    doc.commands.execute(create(doc, hB, atB, const SoftRect(400, 900)));
    expect(kids(doc, hB), hasLength(3));
    doc.commands.permissions = runtime;
    expect(
        () => doc.commands.execute(
            SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400))),
        throwsA(isA<PermissionDeniedError>()));
    final before = canon(doc);
    doc.commands
        .execute(SetComponentCommand<SoftRect>(hB, const SoftRect(300, 1500)));
    final after = canon(doc);
    expect(after, isNot(before));
    doc.commands.undo();
    expect(canon(doc), before);
    doc.commands.redo();
    expect(canon(doc), after);
  });

  test('G5 runtime: a move regenerates the neighbour; a delete is refused', () {
    final doc = paramDoc();
    pair(doc);
    doc.commands.permissions = runtime;
    doc.commands.execute(TransformNodeCommand(hA, parked));
    expect(kids(doc, hB), hasLength(4));
    doc.commands.undo();
    expect(kids(doc, hB), hasLength(3));
    expect(() => doc.commands.execute(deleteObject(doc, hA)),
        throwsA(isA<PermissionDeniedError>()));
  });

  test(
      'G6 a throwing generate during a delete leaves everything as it '
      'was, component included (M-06r)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const ClipRect(2000, 1000)));
    doc.commands.execute(create(doc, hB, atB, const Trip(400, 900)));
    final before = encNodesSorted(doc);
    Trip.mode = TripMode.throwing;
    expect(
        () => doc.commands.execute(deleteObject(doc, hA)),
        throwsA(
            isA<StateError>().having((e) => e.message, 'message', 'tripwire')));
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    expect(encNodesSorted(doc), before);
  });

  test('G7 a failed plan reserves no handle: handleSeed unchanged (M-06t)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const ClipRect(2000, 1000)));
    doc.commands.execute(create(doc, hB, parked, const Trip(400, 900)));
    final before = enc(doc);
    Trip.mode = TripMode.throwing;
    // A (lower handle) is planned first and would gain a child; then B's
    // generate throws.
    expect(() => doc.commands.execute(TransformNodeCommand(hB, atB)),
        throwsStateError);
    expect(enc(doc), before, reason: 'handleSeed is in the bytes');
  });

  test(
      'G8 generate calling execute fails loudly; history unchanged '
      '(M-06s)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hB, parked, const Trip(400, 900)));
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    Trip.document = doc;
    Trip.mode = TripMode.reentrant;
    expect(
        () => doc.commands
            .execute(SetComponentCommand<Trip>(hB, const Trip(500, 900))),
        throwsStateError);
    expect(doc.commands.undoDepth, depth);
    expect(enc(doc), before);
  });

  test(
      'G9 un-parametric: detaching the component regrows old neighbours '
      '(Ruling 06-4)', () {
    final doc = paramDoc();
    pair(doc);
    doc.commands.execute(SetComponentCommand<ClipRect>(hA, null));
    expect(kids(doc, hB), hasLength(4));
    expect(kids(doc, hA), hasLength(5), reason: 'A is plain lines now');
  });

  test(
      'G10 drift() guards re-entry like apply() does: a client generate '
      'calling execute during the dry run throws, and nothing is mutated '
      '(F5)', () {
    final doc = DraftDocument.empty();
    final probeCatalog = ParametricCatalog()
      ..register<ReentrantProbe>(ReentrantProbe.id, ReentrantProbe.fromJson,
          const ReentrantProbeType());
    final system = ParametricSystem(doc, probeCatalog)..install();
    _probeDoc = doc;
    doc.commands.execute(create(doc, hA, parked, const ReentrantProbe(1)));
    final plainLine = addDrafted(
        doc, EntityKind.line, linePayload(Vector2(1, 2), Vector2(3, 4)));
    doc.commands.execute(plainLine);
    _probeTarget = plainLine.record.handle;
    final before = enc(doc);
    _probeArmed = true;
    expect(() => system.drift(), throwsStateError);
    expect(_probeArmed, isFalse,
        reason: "generate() never ran, so this doesn't probe anything");
    expect(enc(doc), before);
    system.dispose();
    _probeDoc = null;
    _probeTarget = null;
  });
}
