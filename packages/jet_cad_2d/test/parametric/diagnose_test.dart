import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

/// DG1's client: a clipped rectangle that reports one entry, naming itself
/// then its neighbours, while it has any (spec 07 D12).
final class OverlapType extends ParametricType<ClipRect> {
  const OverlapType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(ClipRect params, Transform2 toWorld) =>
      rectReach(params, toWorld);
  @override
  List<Generated> generate(ParametricView view, Handle self) =>
      clippedRect(view, self);
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    final n = view.neighbours(self);
    return [
      if (n.isNotEmpty) overlap(self, n),
    ];
  }
}

Diagnostic overlap(Handle self, List<Handle> neighbours) => Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'test.overlap',
      message: '${self.toHex()} overlaps ${neighbours.length}',
      handles: [self, ...neighbours],
    );

/// DG2's two components: the same client under two types, so the store
/// order (type by type) is not the handle order.
final class Tag implements Component {
  const Tag(this.n);
  static const String id = 'test.tag';
  final int n;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'n': n};
  static Tag fromJson(Map<String, Object?> j) => Tag(j['n']! as int);
  @override
  bool operator ==(Object o) => o is Tag && o.n == n;
  @override
  int get hashCode => n.hashCode;
}

final class Mark implements Component {
  const Mark(this.n);
  static const String id = 'test.mark';
  final int n;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'n': n};
  static Mark fromJson(Map<String, Object?> j) => Mark(j['n']! as int);
  @override
  bool operator ==(Object o) => o is Mark && o.n == n;
  @override
  int get hashCode => n.hashCode;
}

Diagnostic tagged(String typeId, Handle self) => Diagnostic(
      severity: DiagnosticSeverity.info,
      code: 'test.tagged',
      message: '$typeId on ${self.toHex()}',
      handles: [self],
    );

/// Always reports one entry; never asks for neighbours; generates nothing.
final class TagType<T extends Component> extends ParametricType<T> {
  const TagType(this.typeId);
  final String typeId;
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(T params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, 0)),
        toWorld.transformPoint(Vector2(10, 10)),
      ]);
  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) =>
      [tagged(typeId, self)];
}

/// DG3's probe: a `diagnose` that, when armed, edits a plain root line --
/// a command no parametric closure tracks, so it would land and stay landed
/// unless `diagnostics()` itself guards re-entry (the reasoning of G10).
DraftDocument? _probeDoc;
Handle? _probeTarget;
bool _probeArmed = false;

/// DG4: the same edit, from the probe's `reach`, which `diagnostics()` runs
/// through its survey.
bool _reachArmed = false;

void _probeEdit() => _probeDoc!.commands.execute(SetEntityGeometryCommand(
    _probeTarget!,
    linePayload(Vector2(19009.5, 11008.25), Vector2(19108.75, 11031))));

final class ProbeType extends ParametricType<Tag> {
  const ProbeType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Tag params, Transform2 toWorld) {
    if (_reachArmed) {
      _reachArmed = false;
      _probeEdit();
    }
    return Aabb2.fromPoints([toWorld.transformPoint(Vector2(0, 0))]);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    if (_probeArmed) {
      _probeArmed = false;
      _probeEdit();
    }
    return const [];
  }
}

/// DG5's client (the Task 3 review's scenario): the lower object's
/// `diagnose` runs a whole nested `diagnostics()` pass; the higher one's
/// then calls `execute` in the outer pass, after the inner pass has ended.
ParametricSystem? _nestSystem;
bool _nestArmed = false;
bool _nestDone = false;

final class NestType extends ParametricType<Tag> {
  const NestType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Tag params, Transform2 toWorld) =>
      Aabb2.fromPoints([toWorld.transformPoint(Vector2(0, 0))]);
  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    if (self == hA && _nestArmed) {
      _nestArmed = false;
      _nestSystem!.diagnostics();
      _nestDone = true;
    } else if (self == hB && _nestDone) {
      _nestDone = false;
      _probeEdit();
    }
    return const [];
  }
}

void main() {
  test(
      'DG1 a client reports while its rotated neighbour overlaps it: gone '
      'after a move away, back on undo', () {
    final doc = DraftDocument.empty();
    final catalog = ParametricCatalog()
      ..register<ClipRect>(ClipRect.id, ClipRect.fromJson, const OverlapType());
    final system = ParametricSystem(doc, catalog)..install();
    doc.commands.execute(create(doc, hA, atA, const ClipRect(2000, 1000)));
    expect(system.diagnostics(), isEmpty, reason: 'A alone has no neighbour');
    doc.commands.execute(create(doc, hB, atB, const ClipRect(400, 900)));
    final overlapping = [
      overlap(hA, [hB]),
      overlap(hB, [hA]),
    ];
    final before = enc(doc);
    final segments = [worldSegments(doc, hA), worldSegments(doc, hB)];
    expect(system.diagnostics(), overlapping);
    expect(enc(doc), before, reason: 'diagnostics() mutates nothing');

    doc.commands.execute(TransformNodeCommand(hB, parked));
    expect(system.diagnostics(), isEmpty);

    doc.commands.undo();
    // The overlap is back (the handle seed never goes back, so no bytes).
    expect([worldSegments(doc, hA), worldSegments(doc, hB)], segments);
    expect(system.diagnostics(), overlapping);
    system.dispose();
  });

  test(
      'DG2 entries come out misplaced first, then by ascending handle '
      'whatever the registration and creation order, with no neighbour '
      'search', () {
    const h1 = Handle(1000), h2 = Handle(2000), h3 = Handle(3000);
    final doc = DraftDocument.empty();
    // Mark is registered first and holds the highest handle, so walking
    // the stores type by type gives 2000, 3000, 1000.
    final catalog = ParametricCatalog()
      ..register<Mark>(Mark.id, Mark.fromJson, const TagType<Mark>(Mark.id))
      ..register<Tag>(Tag.id, Tag.fromJson, const TagType<Tag>(Tag.id));
    final system = ParametricSystem(doc, catalog)..install();
    // Created highest first.
    doc.commands.execute(create(doc, h3, parked, const Mark(3)));
    doc.commands.execute(create(doc, h1, onA(-4000, 2500, 0.4), const Tag(1)));
    doc.commands
        .execute(create(doc, h2, onA(3000, -6000, -1.1), const Mark(2)));
    // A misplaced Tag on a plain line whose handle is above every object's:
    // it still comes first.
    final line = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));
    doc.commands.execute(line);
    final misplaced = line.record.handle;
    expect(misplaced.value, greaterThan(h3.value));
    doc.commands.execute(SetComponentCommand<Tag>(misplaced, const Tag(9)));

    debugOverlapTests = 0;
    final d = system.diagnostics();
    expect(debugOverlapTests, 0,
        reason: 'no client asked for neighbours, so none were computed');
    expect(d.first.code, 'parametric.misplaced');
    expect(d.first.handles, [misplaced]);
    expect(d.skip(1).toList(), [
      tagged(Tag.id, h1),
      tagged(Mark.id, h2),
      tagged(Mark.id, h3),
    ]);
    system.dispose();
  });

  test(
      'DG3 a diagnose that calls execute throws StateError and changes '
      'nothing; the guard is released afterwards', () {
    final doc = DraftDocument.empty();
    final catalog = ParametricCatalog()
      ..register<Tag>(Tag.id, Tag.fromJson, const ProbeType());
    final system = ParametricSystem(doc, catalog)..install();
    _probeDoc = doc;
    doc.commands.execute(create(doc, hA, parked, const Tag(1)));
    final plainLine = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(19001.5, 11002.25), Vector2(19044.5, 11090)));
    doc.commands.execute(plainLine);
    _probeTarget = plainLine.record.handle;
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    _probeArmed = true;
    expect(system.diagnostics, throwsStateError);
    expect(_probeArmed, isFalse,
        reason: 'diagnose() never ran, so this probes nothing');
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
    // The guard is released: an ordinary edit still lands.
    doc.commands.execute(SetEntityGeometryCommand(_probeTarget!,
        linePayload(Vector2(19003.5, 11004.25), Vector2(19050.5, 11070))));
    expect(doc.commands.undoDepth, depth + 1);
    system.dispose();
    _probeDoc = null;
    _probeTarget = null;
  });

  /// A catalog of [type] on [Tag], a document with one plain root line
  /// (the probe's target) and objects at [hA] and [hB], both rotated.
  (DraftDocument, ParametricSystem) probeDoc(ParametricType<Tag> type) {
    final doc = DraftDocument.empty();
    final catalog = ParametricCatalog()
      ..register<Tag>(Tag.id, Tag.fromJson, type);
    final system = ParametricSystem(doc, catalog)..install();
    _probeDoc = doc;
    final plainLine = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(19001.5, 11002.25), Vector2(19044.5, 11090)));
    doc.commands.execute(plainLine);
    _probeTarget = plainLine.record.handle;
    doc.commands.execute(create(doc, hA, parked, const Tag(1)));
    doc.commands.execute(create(doc, hB, atA, const Tag(2)));
    return (doc, system);
  }

  test(
      'DG4 a reach that calls execute during diagnostics() throws StateError '
      'and changes nothing: the survey is inside the guard', () {
    final (doc, system) = probeDoc(const ProbeType());
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    _reachArmed = true;
    expect(system.diagnostics, throwsStateError);
    expect(_reachArmed, isFalse,
        reason: 'reach() never ran armed, so this probes nothing');
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
    system.dispose();
    _probeDoc = null;
    _probeTarget = null;
  });

  test(
      'DG5 a nested diagnostics() from a diagnose leaves the outer pass '
      'guarded: a later diagnose calling execute throws, nothing lands', () {
    final (doc, system) = probeDoc(const NestType());
    _nestSystem = system;
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    _nestArmed = true;
    expect(system.diagnostics, throwsStateError);
    expect(_nestArmed, isFalse, reason: 'the inner pass never ran');
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
    // Released once the outer pass ends: an ordinary edit still lands.
    _probeEdit();
    expect(doc.commands.undoDepth, depth + 1);
    system.dispose();
    _nestSystem = null;
    _nestDone = false;
    _probeDoc = null;
    _probeTarget = null;
  });
}
