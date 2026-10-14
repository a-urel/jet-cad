### Task 2: Engine seam E2, frozen objects and `probe` (spec E2)

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`, `lib/src/parametric/regeneration.dart`, `packages/jet_cad_2d/CHANGELOG.md`
- Create (test support): `packages/jet_cad_2d/test/parametric/support/frozen_clients.dart`
- Test: `packages/jet_cad_2d/test/parametric/frozen_test.dart`, `test/parametric/probe_test.dart`

(All paths below are under `packages/jet_cad_2d/` unless they start at the repository root.)

**Interfaces:**
- Consumes (existing engine code, read before editing). Line numbers are those of the branch point `6083906`. Task 1 shifts some of them by a few lines: one import and the E1 members in `parametric_system.dart`, and comment lines in `regeneration.dart`. Find each site by the code quoted here.
  - `_naming` / `_isObject` (`regeneration.dart:18-32`), the one object rule.
  - `_survey` (`regeneration.dart:217-294`), the only caller of `reach` and `references`. It is called by `drift()` (`parametric_system.dart` `drift`), `diagnostics()`, and `_run` (before: `regeneration.dart:939`; after: `:974`).
  - `_refused` (`:665-680`), `_written` (`:715-727`), `_cascade` (`:761-806`), `_run` (`:937-1062`), `_plan` (`:557-652`), `_storedBox` (`:315-327`).
  - `ParametricView` (`parametric_system.dart:377-483`), which reads only its survey.
  - `ParametricSystem` (`:548-702`): `_applying`, the guard that makes a client `execute` throw (`_expand`, `:680-690`).
  - Task 1's `ParametricCatalog.typeIdOf` (its doc comment gains one sentence here).
- Produces (exported from `package:jet_cad_2d/jet_cad_2d.dart`):
  - `ParametricSystem(DraftDocument document, ParametricCatalog catalog, {bool Function(Handle)? isFrozen})`.
  - `Object? ParametricSystem.probe(Handle object)`: the first error any of the object's hooks throws, or null. It mutates nothing.
- What the consumers (Tasks 10, 11) can rely on:
  - **A frozen object is a plain group to the system.**
    - It is not in any survey, view, regeneration (its own or a neighbour's), `drift()`, `diagnostics()` or `probe()`. No hook of its type is called for it.
    - Its children can be edited directly. Moving or deleting it is an ordinary group edit.
    - An edit that writes a new value of its type on it is refused (`StateError`, "would never be regenerated", spec 06 D5).
    - An object that references it sees a handle that is not a live object. A `cascade` referrer's edit is refused with `DanglingReferenceError`; an `orphan` referrer regenerates as an orphan.
    - `ParametricCatalog.names`, `objectsOf` and `typeIdOf` know nothing of freezing, and still answer for it.
  - **The predicate.** It must give the same answer for a handle throughout one `execute`, `drift()`, `diagnostics()` or `probe()`. Between them it may change.
  - **`probe(h)`** returns null, calling nothing, for a handle that is not a live, unfrozen object. A host probes only the unfrozen ones.

Plan decision, the exclusion lives in the object rule. `_naming` gains an optional `frozen` predicate, and answers null for a frozen root-level group. Each touch point then decides whether it reads the rule with or without the predicate:

| Touch point | Reads | Why |
|---|---|---|
| `_survey` (`regeneration.dart:225`) | with | It is the only caller of `reach` and `references`, and every map a view, the closure, the trigger, `_plan` and `_checkDangling` reads is built here. Excluding the object here excludes it everywhere downstream. Its component falls into `stray`, which `_written` reads. |
| `_run`, both surveys (`:939`, `:974`) | with | As above. |
| `_refused` (`:675`) | with | A frozen object's children are not generated children (they are not in `before.owned`). A child added into it, or one of its children edited, is a plain group's (spec E2, "treated as a plain group"). |
| `_written` (`:718`) | with | A new value written on a frozen object would never be regenerated: refused, as on any non-object (spec 06 D5). An unchanged component, as when the group is moved, equals its `stray` snapshot and passes. |
| `_cascade` (`:770`, `:774`) | unchanged | Every handle it asks about comes from the before-survey (`before.referrers`), which already excludes frozen objects, so the predicate cannot change an answer there. A mutant would be equivalent. |
| `_pageSeeds` (`:301-309`) | unchanged | It filters by `after.objects`. `pageKey` is a type-level hook, asked per type, not per object. |
| `drift()`, `diagnostics()` surveys | with | Spec E2: "every survey". |
| `diagnostics()`'s misplaced pass (`parametric_system.dart:632-643`) | without | A frozen object is a live object by the catalog's rule, not a misplaced component. Read with the predicate, it would be reported as `parametric.misplaced`. |
| `ParametricCatalog.names` / `objectsOf` / `typeIdOf` | without | The catalog knows no system. A host needs a frozen object's type to lock it and to show it (Task 10). |
| `_expand`'s fast path (`:685-688`) | unchanged | With only frozen objects in the document, the edit is wrapped, both surveys find nothing, and `_run` returns at `seeds.isEmpty`. That is correct, and costs only the two surveys. |

Plan decision, what `probe` runs. It runs every hook an edit, `drift()` or `diagnostics()` can call for one object, in an edit's order, not only `reach`, `references` and `generate`:
1. `reach` and `references` (the survey);
2. the type's `pageKey` of the root's page;
3. `placeBox` and `placeInput`, for a contributor;
4. `readBox`, for a reader;
5. `dissolves` and `generate`, through `_plan`'s dry run;
6. `diagnose`.

Why the wider set: if a type's code throws only in `dissolves`, `placeBox` or `readBox`, a probe limited to three hooks would never find the object. Task 11 would never freeze it, and every later edit near it would fail again. `_plan`, the dry run `drift()` already uses (`parametric_system.dart` `drift`), also counts a region or fill the object cannot plan (`_checkRegion`, `_ownBoundaryOf`). The Shared interfaces' "first error … or null" holds for the wider set.

Plan decision, isolation. `probe` first calls `reach` and `references` of every live, unfrozen object, once each. If one of them throws for another object, that object is left out of the probe's survey, as it will be once frozen. If one throws for `object`, that error is returned. So a broken neighbour's error is never reported as `object`'s. The cost:
- a probe is O(live objects): two passes of `reach` and `references`, then one object's other hooks;
- it is not on the frame or the edit path, and `debugReferenceCalls` counts two per object per probe;
- the cost pins (`reference_cost_test.dart`) never probe.

Note for Task 11 (not binding here): probing every object after a load is O(n²). For the load-time check, call `drift()` once first: it runs every live object's `reach`, `references`, `dissolves` and `generate` under the same guard. Probe object by object only when `drift()` throws.

- [ ] **Step 1: Write the test clients.** Create `test/parametric/support/frozen_clients.dart`:

```dart
// Test-only parametric types for spec 2a E2 (frozen objects, probe),
// written for E2 alone and sharing no code with clients.dart (Ruling 06-9).
// Each object carries a name. Every hook records its call as
// '<hook> <name>' ('pageKey tile' for the one type-level hook), and a call
// throws [HookFailure] while it is in [failingHooks].
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Every hook call, in call order.
final List<String> hookCalls = [];

/// The calls that throw.
final Set<String> failingHooks = {};

/// What a tile's last `generate` read through its view.
typedef TileSight = ({
  List<Handle> neighbours,
  List<Handle> tiles,
  Tile? watched,
});

/// Each tile's last [TileSight], by its name.
final Map<String, TileSight> tileSights = {};

/// What each scope's last `generate` found placed in its field, by its name.
final Map<String, List<Handle>> scopeSights = {};

/// Clears every record and switch of this file; tests call it in `setUp`
/// and before the calls they look at.
void resetHooks() {
  hookCalls.clear();
  failingHooks.clear();
  tileSights.clear();
  scopeSights.clear();
  Tile.watch = null;
  Tile.reenter = null;
  Tile.reentries = 0;
}

final class HookFailure implements Exception {
  const HookFailure(this.call);

  final String call;

  @override
  bool operator ==(Object other) => other is HookFailure && other.call == call;

  @override
  int get hashCode => call.hashCode;

  @override
  String toString() => 'HookFailure($call)';
}

void _hook(String call) {
  hookCalls.add(call);
  if (failingHooks.contains(call)) throw HookFailure(call);
}

/// A named [w] x [h] rectangle from its group's origin.
abstract interface class NamedBox implements Component {
  String get name;
  double get w;
  double get h;
}

List<Vector2> boxCorners(NamedBox b) =>
    [Vector2(0, 0), Vector2(b.w, 0), Vector2(b.w, b.h), Vector2(0, b.h)];

Aabb2 worldBox(NamedBox b, Transform2 toWorld) => Aabb2.fromPoints(
    [for (final c in boxCorners(b)) toWorld.transformPoint(c)]);

/// [b]'s four edges, local, as LINEs.
List<Generated> boxEdges(NamedBox b) {
  final c = boxCorners(b);
  return [
    for (var i = 0; i < 4; i++)
      Generated(EntityKind.line, linePayload(c[i], c[(i + 1) % 4])),
  ];
}

/// [self]'s name, or its handle when the view has no [U] for it (a hook
/// called for an object the view does not hold, which no test expects).
String _nameOf<U extends NamedBox>(ParametricView view, Handle self) =>
    view.paramsOf<U>(self)?.name ?? self.toHex();

/// A plain object that reads its neighbours: its four edges, then one LINE
/// per neighbouring tile, from its origin to that tile's far corner (w, h),
/// so its output changes when a neighbour's size does. It may reference
/// another object ([ref], `cascade` policy).
final class Tile implements NamedBox {
  const Tile(this.name, this.w, this.h, {this.ref});

  static const String id = 'test.tile';

  /// Whose parameters the next `generate` reports in [TileSight.watched].
  static Handle? watch;

  /// The document the tile named 'N' executes on from its `generate`, while
  /// [reentries] is above zero; each execute takes one.
  static DraftDocument? reenter;
  static int reentries = 0;

  @override
  final String name;
  @override
  final double w;
  @override
  final double h;
  final Handle? ref;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() =>
      {'name': name, 'w': w, 'h': h, 'ref': ref?.toJson()};

  static Tile fromJson(Map<String, Object?> j) => Tile(j['name']! as String,
      (j['w']! as num).toDouble(), (j['h']! as num).toDouble(),
      ref: j['ref'] == null ? null : Handle.fromJson(j['ref']));

  @override
  bool operator ==(Object other) =>
      other is Tile &&
      other.name == name &&
      other.w == w &&
      other.h == h &&
      other.ref == ref;

  @override
  int get hashCode => Object.hash(name, w, h, ref);
}

final class TileType extends ParametricType<Tile> {
  const TileType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(Tile params, Transform2 toWorld) {
    _hook('reach ${params.name}');
    return worldBox(params, toWorld);
  }

  @override
  Iterable<Handle> references(Tile params) {
    _hook('references ${params.name}');
    final ref = params.ref;
    return ref == null ? const [] : [ref];
  }

  @override
  Object? pageKey(PageComponent? page) {
    _hook('pageKey tile');
    return null;
  }

  @override
  bool dissolves(ParametricView view, Handle self) {
    _hook('dissolves ${_nameOf<Tile>(view, self)}');
    return false;
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    final name = _nameOf<Tile>(view, self);
    _hook('diagnose $name');
    return [
      Diagnostic(
          severity: DiagnosticSeverity.info,
          code: 'test.tile',
          message: name,
          handles: [self]),
    ];
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final name = _nameOf<Tile>(view, self);
    _hook('generate $name');
    final p = view.paramsOf<Tile>(self)!;
    if (Tile.reenter case final doc? when name == 'N' && Tile.reentries > 0) {
      Tile.reentries--;
      doc.commands.execute(SetComponentCommand<Tile>(
          self, Tile(p.name, p.w + 100, p.h, ref: p.ref)));
    }
    final neighbours = [
      for (final n in view.neighbours(self))
        if (view.paramsOf<Tile>(n) != null) n,
    ];
    final watch = Tile.watch;
    tileSights[name] = (
      neighbours: neighbours,
      tiles: view.objectsOf<Tile>(),
      watched: watch == null ? null : view.paramsOf<Tile>(watch),
    );
    final toLocal = view.toWorld(self).invert();
    return [
      ...boxEdges(p),
      for (final n in neighbours)
        Generated(
            EntityKind.line,
            linePayload(
                Vector2(0, 0),
                toLocal.multiply(view.toWorld(n)).transformPoint(Vector2(
                    view.paramsOf<Tile>(n)!.w, view.paramsOf<Tile>(n)!.h)))),
    ];
  }
}

/// A place contributor (spec 10 D16): its place box is its world box.
final class Plate implements NamedBox {
  const Plate(this.name, this.w, this.h);

  static const String id = 'test.plate';

  @override
  final String name;
  @override
  final double w;
  @override
  final double h;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {'name': name, 'w': w, 'h': h};

  static Plate fromJson(Map<String, Object?> j) => Plate(j['name']! as String,
      (j['w']! as num).toDouble(), (j['h']! as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is Plate && other.name == name && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(name, w, h);
}

final class PlateType extends ParametricType<Plate> {
  const PlateType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(Plate params, Transform2 toWorld) {
    _hook('reach ${params.name}');
    return worldBox(params, toWorld);
  }

  @override
  Iterable<Handle> references(Plate params) {
    _hook('references ${params.name}');
    return const [];
  }

  @override
  bool get contributesPlace => true;

  @override
  Aabb2? placeBox(ParametricView view, Handle self) {
    _hook('placeBox ${_nameOf<Plate>(view, self)}');
    final p = view.paramsOf<Plate>(self);
    return p == null ? null : worldBox(p, view.toWorld(self));
  }

  /// The world box as a record: equal exactly when the box is.
  @override
  Object placeInput(ParametricView view, Handle self) {
    _hook('placeInput ${_nameOf<Plate>(view, self)}');
    final b = worldBox(view.paramsOf<Plate>(self)!, view.toWorld(self));
    return (b.minX, b.minY, b.maxX, b.maxY);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _hook('generate ${_nameOf<Plate>(view, self)}');
    return boxEdges(view.paramsOf<Plate>(self)!);
  }
}

/// A place reader (spec 10 D16) with a [w] x [h] field: its four field
/// edges, then one LINE per contributor placed in the field, across that
/// contributor's place box. Its reach is empty, so no spatial relation finds
/// it; only the trigger does.
final class Scope implements NamedBox {
  const Scope(this.name, this.w, this.h);

  static const String id = 'test.scope';

  @override
  final String name;
  @override
  final double w;
  @override
  final double h;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {'name': name, 'w': w, 'h': h};

  static Scope fromJson(Map<String, Object?> j) => Scope(j['name']! as String,
      (j['w']! as num).toDouble(), (j['h']! as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is Scope && other.name == name && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(name, w, h);
}

final class ScopeType extends ParametricType<Scope> {
  const ScopeType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(Scope params, Transform2 toWorld) {
    _hook('reach ${params.name}');
    return Aabb2.empty();
  }

  @override
  Iterable<Handle> references(Scope params) {
    _hook('references ${params.name}');
    return const [];
  }

  @override
  bool get readsPlaces => true;

  @override
  Aabb2 readBox(Scope params, Transform2 toWorld, Aabb2 stored) {
    _hook('readBox ${params.name}');
    return stored.union(worldBox(params, toWorld));
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final name = _nameOf<Scope>(view, self);
    _hook('generate $name');
    final p = view.paramsOf<Scope>(self)!;
    final placed = view.placedIn(worldBox(p, view.toWorld(self)));
    scopeSights[name] = placed;
    final toLocal = view.toWorld(self).invert();
    return [
      ...boxEdges(p),
      for (final h in placed)
        if (view.placeBoxOf(h) case final b?)
          Generated(
              EntityKind.line,
              linePayload(toLocal.transformPoint(Vector2(b.minX, b.minY)),
                  toLocal.transformPoint(Vector2(b.maxX, b.maxY)))),
    ];
  }
}

ParametricCatalog frozenCatalog() => ParametricCatalog()
  ..register<Tile>(Tile.id, Tile.fromJson, const TileType())
  ..register<Plate>(Plate.id, Plate.fromJson, const PlateType())
  ..register<Scope>(Scope.id, Scope.fromJson, const ScopeType());

const Handle hF = Handle(1000);
const Handle hN = Handle(2000);
const Handle hR = Handle(2500);
const Handle hS = Handle(3000);
const Handle hP = Handle(3100);
const Handle hQ = Handle(3200);

Transform2 _on(Transform2 base, double x, double y, double turn) => base
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

final Transform2 atF = Transform2.translation(7010, 3020)
    .multiply(Transform2.rotation(math.pi / 6));

/// N pierces F's top edge from inside: each is the other's neighbour.
final Transform2 atN = _on(atF, 800, 700, 0.3);

/// Far from everything.
final Transform2 atR =
    Transform2.translation(19000, 11000).multiply(Transform2.rotation(-0.7));

/// S, P and Q are far from F and N. P and Q overlap each other, both inside
/// S's 3000 x 2000 field.
final Transform2 atS =
    Transform2.translation(-4200, 8800).multiply(Transform2.rotation(0.4));
final Transform2 atP = _on(atS, 400, 300, 0.2);
final Transform2 atQ = _on(atS, 700, 500, -0.3);

DraftCommand place<T extends Component>(
        DraftDocument doc, Handle h, Transform2 at, T params) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: at, children: const [])),
      SetComponentCommand<T>(h, params),
    ], label: 'Add object');

typedef FrozenScene = ({
  DraftDocument doc,
  ParametricSystem system,
  Set<Handle> frozen,
});

/// An installed system over a new document, reading [FrozenScene.frozen]
/// (empty: nothing is frozen while the scene is built). With [tiles], F
/// (2000 x 1000) and N (400 x 900); with [places], S (3000 x 2000), P
/// (600 x 500) and Q (300 x 300).
FrozenScene frozenScene({bool tiles = true, bool places = false}) {
  final frozen = <Handle>{};
  final doc = DraftDocument.empty();
  final system =
      ParametricSystem(doc, frozenCatalog(), isFrozen: frozen.contains)
        ..install();
  if (tiles) {
    doc.commands.execute(place(doc, hF, atF, const Tile('F', 2000, 1000)));
    doc.commands.execute(place(doc, hN, atN, const Tile('N', 400, 900)));
  }
  if (places) {
    doc.commands.execute(place(doc, hS, atS, const Scope('S', 3000, 2000)));
    doc.commands.execute(place(doc, hP, atP, const Plate('P', 600, 500)));
    doc.commands.execute(place(doc, hQ, atQ, const Plate('Q', 300, 300)));
  }
  return (doc: doc, system: system, frozen: frozen);
}

/// [g]'s children, ascending.
List<Handle> childrenOf(DraftDocument doc, Handle g) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == g) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// Each child of [g] with its stored coordinates.
Map<Handle, List<double>> geometryOf(DraftDocument doc, Handle g) => {
      for (final k in childrenOf(doc, g))
        k: doc.geometry
            .read(doc.entities.geomIndexAt(doc.entities.slotOf(k)!))
            .coords
            .toList(),
    };

String encoded(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

/// The recorded calls of the object named [name].
List<String> callsOf(String name) => [
      for (final c in hookCalls)
        if (c.endsWith(' $name')) c,
    ];
```

- [ ] **Step 2: Write the frozen-object tests.** Create `test/parametric/frozen_test.dart`:

```dart
// Spec 2a E2: a frozen object is left out of every survey, view and
// regeneration and is a plain group to the system; no hook of its type is
// called for it. F and N overlap and each reads the other; P and Q are
// place contributors that S reads. Every object sits off the origin at a
// rotation, and each test first shows the relation the freeze then cuts.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/frozen_clients.dart';

void main() {
  setUp(resetHooks);

  test(
      'E2-1 an edit of a neighbour calls no hook of a frozen object, which '
      'keeps its geometry and is in no view', () {
    final s = frozenScene();
    // Fixture: F and N see each other, four edges and one tick each.
    expect(childrenOf(s.doc, hF), hasLength(5));
    expect(childrenOf(s.doc, hN), hasLength(5));
    s.frozen.add(hF);
    final kept = geometryOf(s.doc, hF);
    resetHooks();
    Tile.watch = hF;
    s.doc.commands
        .execute(SetComponentCommand<Tile>(hN, const Tile('N', 450, 950)));
    // M-E2a, M-E2b, M-E2c: F's reach or generate is called.
    expect(callsOf('F'), isEmpty);
    expect(geometryOf(s.doc, hF), kept);
    final sight = tileSights['N']!;
    expect(sight.neighbours, isEmpty);
    expect(sight.tiles, [hN]);
    expect(sight.watched, isNull);
    expect(childrenOf(s.doc, hN), hasLength(4), reason: 'its tick to F is gone');

    // Positive control: unfrozen, F is N's neighbour again, regenerates,
    // and its tick follows N's new size.
    s.frozen.remove(hF);
    resetHooks();
    s.doc.commands
        .execute(SetComponentCommand<Tile>(hN, const Tile('N', 500, 980)));
    expect(callsOf('F'), contains('generate F'));
    expect(geometryOf(s.doc, hF), isNot(kept));
  });

  test(
      'E2-2 a place reader does not read a frozen contributor, whose hooks '
      'are not called', () {
    final s = frozenScene(tiles: false, places: true);
    expect(childrenOf(s.doc, hS), hasLength(6), reason: 'fixture: S reads P, Q');
    s.frozen.add(hP);
    resetHooks();
    s.doc.commands
        .execute(SetComponentCommand<Plate>(hQ, const Plate('Q', 350, 320)));
    expect(hookCalls, contains('generate S'), reason: "Q's place changed");
    // M-E2a, M-E2b: S finds P placed. M-E2c: P's reach or place box is
    // asked in the before-view.
    expect(scopeSights['S'], [hQ]);
    expect(callsOf('P'), isEmpty);
    expect(childrenOf(s.doc, hS), hasLength(5));
  });

  test(
      'E2-3 a frozen object is a plain group: its children are edited '
      'directly, and it moves without regenerating', () {
    final s = frozenScene();
    final child = childrenOf(s.doc, hF).first;
    final moved = linePayload(Vector2(15, 25), Vector2(1985.5, 30.25));
    // Positive control: a live object's child is generated (spec 06 D6).
    expect(
        () => s.doc.commands.execute(SetEntityGeometryCommand(child, moved)),
        throwsA(isA<GeneratedGeometryError>()));
    s.frozen.add(hF);
    // M-E2d: refused as a generated child.
    s.doc.commands.execute(SetEntityGeometryCommand(child, moved));
    expect(
        s.doc.geometry
            .read(s.doc.entities.geomIndexAt(s.doc.entities.slotOf(child)!))
            .coords,
        moved.coords);
    resetHooks();
    s.doc.commands.execute(TransformNodeCommand(
        hF, atF.multiply(Transform2.translation(-300, 450))));
    expect(callsOf('F'), isEmpty);
  });

  test(
      'E2-4 a new value of its type written on a frozen object is refused, '
      'and nothing changes', () {
    final s = frozenScene();
    s.frozen.add(hF);
    final before = encoded(s.doc);
    final depth = s.doc.commands.undoDepth;
    // M-E2e: the write lands, and would never be regenerated.
    expect(
        () => s.doc.commands
            .execute(SetComponentCommand<Tile>(hF, const Tile('F', 2600, 1000))),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('would never be regenerated'))));
    expect(encoded(s.doc), before);
    expect(s.doc.commands.undoDepth, depth);
  });

  test('E2-5 drift() neither lists a frozen object nor calls it', () {
    final s = frozenScene();
    s.frozen.add(hF);
    // F's tick still reads N's old size: F is stale.
    s.doc.commands
        .execute(SetComponentCommand<Tile>(hN, const Tile('N', 450, 950)));
    resetHooks();
    // M-E2f: drift's survey holds F, and lists it.
    expect(s.system.drift(), isEmpty);
    expect(callsOf('F'), isEmpty);
    // Positive control: unfrozen, F is stale and N would draw its tick to F
    // again.
    s.frozen.remove(hF);
    expect(s.system.drift(), [hF, hN]);
  });

  test(
      'E2-6 diagnostics() reports nothing of a frozen object and calls none '
      'of its hooks', () {
    final s = frozenScene();
    // Positive control: one entry per live tile.
    expect([for (final d in s.system.diagnostics()) d.handles], [
      [hF],
      [hN],
    ]);
    s.frozen.add(hF);
    resetHooks();
    final report = s.system.diagnostics();
    // M-E2g: F's diagnose runs. M-E2h: F is reported misplaced.
    expect([for (final d in report) d.code], ['test.tile']);
    expect(report.single.handles, [hN]);
    expect(callsOf('F'), isEmpty);
  });

  test(
      'E2-7 a cascade referrer of a frozen object sees a dead handle: its '
      'edit is refused as dangling', () {
    final s = frozenScene();
    s.doc.commands
        .execute(place(s.doc, hR, atR, const Tile('R', 300, 250, ref: hF)));
    s.frozen.add(hF);
    final before = encoded(s.doc);
    final depth = s.doc.commands.undoDepth;
    // M-E2a: F is still a live referent, and the edit lands.
    expect(
        () => s.doc.commands.execute(SetComponentCommand<Tile>(
            hR, const Tile('R', 320, 250, ref: hF))),
        throwsA(isA<DanglingReferenceError>()
            .having((e) => e.object, 'object', hR)
            .having((e) => e.referent, 'referent', hF)));
    expect(encoded(s.doc), before);
    expect(s.doc.commands.undoDepth, depth);
    // Positive control: unfrozen, the same edit lands.
    s.frozen.remove(hF);
    s.doc.commands.execute(
        SetComponentCommand<Tile>(hR, const Tile('R', 320, 250, ref: hF)));
    expect(s.doc.components.get<Tile>(hR), const Tile('R', 320, 250, ref: hF));
  });
}
```

- [ ] **Step 3: Write the probe tests.** Create `test/parametric/probe_test.dart`:

```dart
// Spec 2a E2: probe runs one live object's hooks in isolation, returns the
// first error or null, and changes nothing.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/frozen_clients.dart';

/// The recorded calls, without the survey's reach and references of every
/// object.
List<String> beyondSurvey() => [
      for (final c in hookCalls)
        if (!c.startsWith('reach ') && !c.startsWith('references ')) c,
    ];

void main() {
  setUp(resetHooks);

  test('E2-P1 a healthy object: null, its own hooks only, nothing changes',
      () {
    final s = frozenScene(places: true);
    final before = encoded(s.doc);
    final state = s.doc.commands.stateId;
    final depth = s.doc.commands.undoDepth;
    resetHooks();
    expect(s.system.probe(hN), isNull);
    // M-E2p-plan: neither dissolves nor generate runs.
    expect(beyondSurvey(),
        ['pageKey tile', 'dissolves N', 'generate N', 'diagnose N']);
    expect(encoded(s.doc), before);
    expect(s.doc.commands.stateId, state);
    expect(s.doc.commands.undoDepth, depth);
    expect(s.doc.commands.canRedo, isFalse);
  });

  for (final (call, object) in [
    ('reach N', hN),
    ('references N', hN),
    ('pageKey tile', hN),
    ('dissolves N', hN),
    ('generate N', hN),
    ('diagnose N', hN),
    ('placeBox Q', hQ),
    ('placeInput Q', hQ),
    ('readBox S', hS),
  ]) {
    test('E2-P2 the error is returned, nothing changes: $call', () {
      final s = frozenScene(places: true);
      final before = encoded(s.doc);
      final state = s.doc.commands.stateId;
      resetHooks();
      failingHooks.add(call);
      // M-E2p-catch: the error escapes. M-E2p-page, M-E2p-place,
      // M-E2p-input, M-E2p-read, M-E2p-plan, M-E2p-diag: that hook is not
      // run.
      expect(s.system.probe(object), HookFailure(call));
      expect(encoded(s.doc), before);
      expect(s.doc.commands.stateId, state);
    });
  }

  test("E2-P3 a broken neighbour's error is not reported as another's", () {
    final s = frozenScene();
    for (final call in ['reach F', 'references F']) {
      resetHooks();
      failingHooks.add(call);
      // M-E2p-iso: the probe's survey keeps F and throws its error for N.
      expect(s.system.probe(hN), isNull, reason: call);
      expect(s.system.probe(hF), HookFailure(call), reason: call);
    }
  });

  test('E2-P4 a hook that executes is refused, and nothing changes', () {
    final s = frozenScene();
    final before = encoded(s.doc);
    final state = s.doc.commands.stateId;
    final depth = s.doc.commands.undoDepth;
    Tile.reenter = s.doc;
    Tile.reentries = 1;
    // M-E2p-guard: unguarded, N's generate executes an edit that lands.
    expect(
        s.system.probe(hN),
        isA<StateError>()
            .having((e) => e.message, 'message', contains('must not mutate')));
    expect(encoded(s.doc), before);
    expect(s.doc.commands.stateId, state);
    expect(s.doc.commands.undoDepth, depth);
  });

  test('E2-P5 a frozen object, or no object, is not probed', () {
    final s = frozenScene();
    s.frozen.add(hF);
    resetHooks();
    // M-E2p-live: F, frozen, is probed by the catalog's rule.
    expect(s.system.probe(hF), isNull);
    expect(hookCalls, isEmpty);
    for (final h in [
      s.doc.rootHandle,
      childrenOf(s.doc, hN).first,
      const Handle(987654),
    ]) {
      expect(s.system.probe(h), isNull, reason: h.toHex());
    }
    expect(hookCalls, isEmpty);
  });
}
```

- [ ] **Step 4: Run the tests and see them fail.** Run: `cd packages/jet_cad_2d && dart test test/parametric/frozen_test.dart test/parametric/probe_test.dart`. Expected: compilation fails in `support/frozen_clients.dart` because `ParametricSystem` has no named parameter `isFrozen`, and in `probe_test.dart` because `probe` is undefined. Quote the first error line.

- [ ] **Step 5: The object rule.** In `lib/src/parametric/regeneration.dart`:
  - Replace `_naming` and `_isObject` (`:10-32`) with:

```dart
/// The registration that names [h]'s object in [t], or null: the engine's
/// one object rule (spec D5, as amended by fix/live-object-rule). Null
/// unless [h] is a `GroupNode` whose parent is the root; null when [frozen]
/// answers true for [h] (spec 2a E2: a frozen object is a plain group to the
/// system that froze it); otherwise the **last** registration, in [types]'
/// (catalog) order, whose component [h] carries, or null when it carries
/// none. A root-level group carrying two registered types is the later one's
/// object; the earlier component is a stray ([_Survey.stray]). [_isObject],
/// [_survey] and `ParametricCatalog.names` all read this; the catalog passes
/// no [frozen]. O(types).
_Registration<Component>? _naming(
    CommandTarget t, List<_Registration<Component>> types, Handle h,
    [bool Function(Handle)? frozen]) {
  final node = t.tree[h];
  if (node is! GroupNode || node.parent != t.tree.root) return null;
  if (frozen != null && frozen(h)) return null;
  for (var i = types.length - 1; i >= 0; i--) {
    if (types[i].has(t, h)) return types[i];
  }
  return null;
}

/// A root-level group carrying a registered parametric component (spec D5),
/// not frozen ([_naming]).
bool _isObject(
        CommandTarget t, List<_Registration<Component>> types, Handle h,
        [bool Function(Handle)? frozen]) =>
    _naming(t, types, h, frozen) != null;
```

  - `_survey` (`:217`): the signature becomes `_Survey _survey(CommandTarget t, List<_Registration<Component>> types, [bool Function(Handle)? frozen]) {`. At `:225`, `if (identical(_naming(t, types, h), r)) {` becomes `if (identical(_naming(t, types, h, frozen), r)) {`. Above the function, add:

```dart
/// A survey of [t]'s live objects. An object [frozen] answers true for
/// (spec 2a E2) is named by no registration here, so its component is a
/// [_Survey.stray], none of its hooks is called, and no view built over the
/// survey holds it.
```

  - `_Survey.stray`'s comment (`:128-134`) gains: `/// A frozen object's component (spec 2a E2) is one too.`
  - `_refused` (`:665-680`): add a last parameter, `bool Function(Handle)? frozen` (required positional, nullable). At `:675`, `_isObject(t, types, t.entities.ownerAt(slot))` becomes `_isObject(t, types, t.entities.ownerAt(slot), frozen)`. Its comment gains: `/// A frozen object (spec 2a E2) is a plain group: a child added into it, or one of its children edited, is not refused.`
  - `_written` (`:715-727`): add the same last parameter. At `:718`, `if (_isObject(t, types, h)) continue;` becomes `if (_isObject(t, types, h, frozen)) continue;`. Its comment gains: `/// A frozen object (spec 2a E2) is not a live group here, so a new value of its type written on it is refused; an unchanged one (the group moved) equals its stray snapshot and is not.`
  - `_cascade` is unchanged. Its comment gains: `/// It reads no frozen predicate: every handle it asks about is a key or a value of the before-survey's referrers, which holds no frozen object.`
  - `_run` (`:937-962`, `:974`):

```dart
CommandResult _run(ParametricEdit edit, CommandTarget t) {
  final types = edit._system._types;
  // Spec 2a E2: one predicate for the whole edit, both surveys and both
  // guards.
  final frozen = edit._system._frozen;
  final before = _survey(t, types, frozen);
  final r0 = edit.inner.apply(t);

  final refused = _refused(t, types, before, r0.touched, frozen);
```

  Further down:
  - `if (_written(t, types, before, r0.touched) case (final h, final r)?) {` becomes `if (_written(t, types, before, r0.touched, frozen) case (final h, final r)?) {`;
  - `after = _survey(t, types);` becomes `after = _survey(t, types, frozen);`.

  Nothing else in `_run` changes.

- [ ] **Step 6: The system.** In `lib/src/parametric/parametric_system.dart`:
  - Replace the constructor and add the field (`:548-554`):

```dart
/// Regenerates parametric objects inside the edit that changes them (spec
/// 06 D1, D2, D4). One per document; takes the dispatcher's expander slot.
class ParametricSystem {
  /// [isFrozen] (spec 2a E2) names the objects this system leaves alone. A
  /// frozen object is in no survey, so in no view, no regeneration (its own
  /// or a neighbour's), [drift], [diagnostics] or [probe], and no hook of its
  /// type is called for it. It is a plain group to this system, as a group
  /// carrying an unregistered type is: its children can be edited directly;
  /// moving or deleting it is an ordinary group edit; an edit that writes a
  /// new value of its type on it is refused (spec 06 D5); an object that
  /// references it sees a handle that is not a live object, so a `cascade`
  /// referrer's edit is refused with [DanglingReferenceError] and an
  /// `orphan` one regenerates as an orphan. The catalog's queries
  /// ([ParametricCatalog.names], [ParametricCatalog.objectsOf],
  /// [ParametricCatalog.typeIdOf]) know nothing of it.
  ///
  /// The predicate must give the same answer for a handle throughout one
  /// `execute`, [drift], [diagnostics] or [probe]; between them it may change
  /// (a host freezes an object whose type's code failed). Null freezes
  /// nothing. It is called once per registered component per survey: keep it
  /// a set lookup.
  ParametricSystem(this.document, this.catalog,
      {bool Function(Handle)? isFrozen})
      : _frozen = isFrozen {
    catalog.registerComponents(document.components);
  }

  final DraftDocument document;
  final ParametricCatalog catalog;
  final bool Function(Handle)? _frozen;
```

  - `drift()`: `final s = _survey(document, _types);` becomes `final s = _survey(document, _types, _frozen);`.
  - `diagnostics()`: `final s = _survey(document, _types);` becomes `final s = _survey(document, _types, _frozen);`. The misplaced pass keeps `_isObject(document, _types, h)`, with this comment above `final misplaced = [`:

```dart
    // The catalog's rule, without the frozen predicate: a frozen object is a
    // live object left alone (spec 2a E2), not a misplaced component.
```

  - Add after `diagnostics()` (before `_unresolved`):

```dart
  /// Runs [object]'s hooks once, in isolation, and returns the first error
  /// any of them throws, or null (spec 2a E2). Mutates nothing. It is
  /// guarded like [drift], so a hook that calls `execute` gets the guard's
  /// `StateError`, which is returned.
  ///
  /// The hooks are every one an edit, [drift] or [diagnostics] can call for
  /// one object, in an edit's order:
  /// - its `reach` and `references`, in the survey;
  /// - its type's `pageKey` of the root's page;
  /// - `placeBox` and `placeInput`, for a contributor;
  /// - `readBox`, for a reader;
  /// - `dissolves` and `generate`, through the planner's dry run (so a
  ///   region or a fill it cannot plan counts too);
  /// - then `diagnose`.
  ///
  /// Each runs with a view over a survey of this system's live objects, as
  /// an edit's after-view.
  ///
  /// In isolation: another live object whose own `reach` or `references`
  /// throws is left out of that survey, as it will be once frozen, so its
  /// error is never reported as [object]'s. Finding them takes one `reach`
  /// and one `references` call per live object before the survey's own. A
  /// probe is O(live objects), and is on neither the frame nor the edit path.
  ///
  /// Null, with no hook called, for a handle that is not a live object of
  /// this system: not a root-level group named by a registered type, or
  /// frozen.
  Object? probe(Handle object) {
    final registration = _naming(document, _types, object, _frozen);
    if (registration == null) return null;
    final was = _applying;
    _applying = true;
    try {
      final broken = <Handle>{};
      for (final r in _types) {
        for (final h in r.handles(document)) {
          if (!identical(_naming(document, _types, h, _frozen), r)) continue;
          try {
            r.reachOf(r.componentOf(document, h), _worldOf(document, h));
            r.referencesOf(document, h).toList();
          } catch (error) {
            if (h == object) return error;
            broken.add(h);
          }
        }
      }
      final frozen = _frozen;
      final s = _survey(
          document,
          _types,
          broken.isEmpty
              ? frozen
              : (Handle h) =>
                  broken.contains(h) || (frozen != null && frozen(h)));
      final view = ParametricView._(document, s);
      final type = registration.type;
      type.pageKey(view.page);
      if (type.contributesPlace && view.placeBoxOf(object) != null) {
        type.placeInput(view, object);
      }
      if (type.readsPlaces) {
        registration.readBoxOf(s.params[object]!, s.toWorld[object]!,
            _storedBox(document, s, object));
      }
      _plan(document, [object], s, view);
      registration.diagnose(view, object);
      return null;
    } catch (error) {
      return error;
    } finally {
      _applying = was;
    }
  }
```

  - `ParametricCatalog.typeIdOf`'s comment (Task 1) gains: `/// A frozen object (spec 2a E2) still answers its type id: the catalog knows no ParametricSystem.`

- [ ] **Step 7: The CHANGELOG.** In `CHANGELOG.md`, under `## Unreleased` (Task 1), add a bullet after the last one:

```markdown
- `ParametricSystem(document, catalog, isFrozen: …)` leaves a frozen
  object out of every survey, view, regeneration, `drift()` and
  `diagnostics()`, as a plain group, and calls none of its type's hooks
  for it. `ParametricSystem.probe(handle)` runs one live object's hooks in
  isolation, changing nothing, and returns the first error, or null.
```

- [ ] **Step 8: Run the new tests.** Run: `cd packages/jet_cad_2d && dart test test/parametric/frozen_test.dart test/parametric/probe_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 9: The engine's gate and the allocation invariant.** Run, one at a time:
  - `cd packages/jet_cad_2d && dart format .`
  - `cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart`. Expected: `All tests passed!`.
  - `cd packages/jet_cad_2d && dart test`. Expected: the only failures are the `packages/jet_cad_2d` lines of `tool/ci/standing_failures.txt`. Every existing parametric test passes with `isFrozen` absent: the cost pins (`neighbour_cost_test.dart`, `reference_cost_test.dart`) and the live-object rule (`live_object_rule_test.dart`) unchanged.
  - `cd packages/jet_cad_2d && dart analyze`. Expected: `No issues found!`.
  - `cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .`. Expected: exit 0.

- [ ] **Step 10: The dependents, unchanged.** `jet_cad_floor_plan` runs the parametric system on every edit. Run, one at a time:
  - `cd packages/jet_cad_floor_plan && flutter test`
  - `cd packages/jet_cad_2d_flutter && flutter test`
  - `cd packages/jet_cad_2d_kit && flutter test`

  Expected for each: the same result as on clean `main`. The only failures are the lines `tool/ci/standing_failures.txt` lists for that package. Afterwards, `git status --short` shows only this task's files; leave any rewritten `analysis_options.yaml` unstaged.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/parametric/parametric_system.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart packages/jet_cad_2d/CHANGELOG.md packages/jet_cad_2d/test/parametric/support/frozen_clients.dart packages/jet_cad_2d/test/parametric/frozen_test.dart packages/jet_cad_2d/test/parametric/probe_test.dart
git commit -m "$(cat <<'EOF'
feat(engine): frozen objects and ParametricSystem.probe (2a E2)

A ParametricSystem takes an isFrozen predicate. A frozen object is left
out of every survey, so of every view, regeneration, drift() and
diagnostics(), and is a plain group to the system; none of its type's
hooks is called for it. probe(handle) runs one live object's hooks in
isolation, under the regeneration guard, and returns the first error or
null; a broken neighbour is left out of its survey.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check.** Run these on the committed files only. For each mutation:
  1. apply the edit;
  2. run the named test with `cd packages/jet_cad_2d && dart test <file> --name '<id>'`;
  3. see it red, and quote the failing expectation line;
  4. `git checkout -- <file>`;
  5. `git diff --quiet -- <file>`, which must exit 0.

  The mutations, all in `lib/src/parametric/`:
  - M-E2a (`regeneration.dart`): delete `if (frozen != null && frozen(h)) return null;` from `_naming` → every test of `frozen_test.dart` red (`E2-1` to `E2-7`); quote `E2-1` and `E2-7`.
  - M-E2b (`regeneration.dart`): in `_run`, `after = _survey(t, types, frozen);` becomes `after = _survey(t, types);` → `E2-1` red (`generate F`).
  - M-E2c (`regeneration.dart`): in `_run`, `final before = _survey(t, types, frozen);` becomes `final before = _survey(t, types);` → `E2-1` red (`reach F`).
  - M-E2d (`regeneration.dart`): in `_refused`, `_isObject(t, types, t.entities.ownerAt(slot), frozen)` becomes `_isObject(t, types, t.entities.ownerAt(slot))` → `E2-3` red.
  - M-E2e (`regeneration.dart`): in `_written`, `_isObject(t, types, h, frozen)` becomes `_isObject(t, types, h)` → `E2-4` red.
  - M-E2f (`parametric_system.dart`): in `drift()`, `_survey(document, _types, _frozen)` becomes `_survey(document, _types)` → `E2-5` red.
  - M-E2g (`parametric_system.dart`): in `diagnostics()`, `_survey(document, _types, _frozen)` becomes `_survey(document, _types)` → `E2-6` red.
  - M-E2h (`parametric_system.dart`): in `diagnostics()`'s misplaced pass, `!_isObject(document, _types, h)` becomes `!_isObject(document, _types, h, _frozen)` → `E2-6` red.
  - M-E2p-live (`parametric_system.dart`): in `probe`, `_naming(document, _types, object, _frozen)` becomes `_naming(document, _types, object)` → `E2-P5` red.
  - M-E2p-iso (`parametric_system.dart`): in `probe`, the `_survey(...)` call's third argument becomes `_frozen` → `E2-P3` red.
  - M-E2p-guard (`parametric_system.dart`): in `probe`, delete `_applying = true;` → `E2-P4` red.
  - M-E2p-catch (`parametric_system.dart`): in `probe`, the outer `catch (error) { return error; }` becomes `catch (error) { rethrow; }` → `E2-P2` red (every row).
  - M-E2p-page (`parametric_system.dart`): delete `type.pageKey(view.page);` → `E2-P2 … pageKey tile` red.
  - M-E2p-place (`parametric_system.dart`): `if (type.contributesPlace && view.placeBoxOf(object) != null) {` becomes `if (false) {` → `E2-P2 … placeBox Q` and `… placeInput Q` red.
  - M-E2p-input (`parametric_system.dart`): delete `type.placeInput(view, object);` (keep the condition's `placeBoxOf` call by writing the `if` with an empty body) → `E2-P2 … placeInput Q` red.
  - M-E2p-read (`parametric_system.dart`): delete the `if (type.readsPlaces) { … }` block → `E2-P2 … readBox S` red.
  - M-E2p-plan (`parametric_system.dart`): delete `_plan(document, [object], s, view);` → `E2-P1` and `E2-P2 … dissolves N` / `… generate N` red.
  - M-E2p-diag (`parametric_system.dart`): delete `registration.diagnose(view, object);` → `E2-P2 … diagnose N` red.

  For a row of `E2-P2`, pass its full name: `--name 'E2-P2 the error is returned, nothing changes: pageKey tile'`.

---

