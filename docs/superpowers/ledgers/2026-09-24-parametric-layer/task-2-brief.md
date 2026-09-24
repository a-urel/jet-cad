### Task 2: The parametric system and planner

**Files:**
- Create: `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`
- Create: `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/component.dart`: add
  `bool isRegistered<T extends Component>() => _stores.containsKey(T);` to
  `ComponentRegistry`, next to `register` (Ruling 06-13)
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`: add
  `export 'src/parametric/parametric_system.dart';` in alphabetical order
- Create: `packages/jet_cad_2d/test/parametric/support/clients.dart`
- Create: `packages/jet_cad_2d/test/parametric/support/fixture.dart`
- Test: `packages/jet_cad_2d/test/parametric/regeneration_test.dart`

**Interfaces:**
- Consumes: `CommandDispatcher.expander` (Task 1).
- Produces, used by Tasks 3, 4 and 6–8:
  - `abstract class ParametricType<T extends Component>`:
    - `Capability get editCapability`;
    - `Aabb2 reach(T params, Transform2 toWorld)`;
    - `List<Generated> generate(ParametricView view, Handle self)`.
  - `final class Generated(EntityKind kind, GeometryPayload payload)`,
    which throws `ArgumentError` for `fill`.
  - `class GeneratedGeometryError implements Exception { final Handle
    handle; }`.
  - `final class ParametricView`, with:
    - `U? paramsOf<U extends Component>(Handle)`;
    - `Transform2 toWorld(Handle)`;
    - `List<Handle> neighbours(Handle)`.
  - `class ParametricCatalog`, with:
    - `void register<T extends Component>(String typeId,
      ComponentFactory<T> factory, ParametricType<T> type)`;
    - `void registerComponents(ComponentRegistry registry)`.
  - `class ParametricSystem`, with:
    - the constructor `ParametricSystem(DraftDocument document,
      ParametricCatalog catalog)`;
    - `void install()` and `void dispose()`;
    - `List<Handle> drift()`;
    - `List<Diagnostic> diagnostics()`.
  - `final class ParametricEdit extends DraftCommand`, created only by the
    expander.
  - `final class ParametricReplay extends DraftCommand`.

- [ ] **Step 1: Write the test clients.**

```dart
// packages/jet_cad_2d/test/parametric/support/clients.dart
// Test-only parametric types. RectType duplicates the app's BoxType on
// purpose (Ruling 06-9): a fixture must not share a bug with the code it
// checks.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

abstract class RectParams implements Component {
  double get width;
  double get height;
}

final class ClipRect implements RectParams {
  const ClipRect(this.width, this.height);
  static const String id = 'test.clipRect';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static ClipRect fromJson(Map<String, Object?> j) => ClipRect(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is ClipRect && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

/// Same shape, but its parameter edits need only `components` (spec D7).
final class SoftRect implements RectParams {
  const SoftRect(this.width, this.height);
  static const String id = 'test.softRect';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static SoftRect fromJson(Map<String, Object?> j) => SoftRect(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is SoftRect && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

enum TripMode { off, throwing, reentrant }

/// A rectangle whose generation can be made to throw, or to call back into
/// the dispatcher (G6–G8).
final class Trip implements RectParams {
  const Trip(this.width, this.height);
  static const String id = 'test.trip';
  static TripMode mode = TripMode.off;
  static DraftDocument? document;
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static Trip fromJson(Map<String, Object?> j) => Trip(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is Trip && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

RectParams? rectOf(ParametricView v, Handle h) =>
    v.paramsOf<ClipRect>(h) ?? v.paramsOf<SoftRect>(h) ?? v.paramsOf<Trip>(h);

List<Vector2> corners(RectParams p) => [
      Vector2(0, 0),
      Vector2(p.width, 0),
      Vector2(p.width, p.height),
      Vector2(0, p.height),
    ];

/// The open parameter interval of a->b strictly inside the convex quad [q],
/// or null. "Strictly": a segment lying on q's edge is outside.
(double, double)? insideInterval(Vector2 a, Vector2 b, List<Vector2> q) {
  const tol = Tolerance.standard;
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    area += u.x * v.y - v.x * u.y;
  }
  final s = area > 0 ? 1.0 : -1.0;
  final d = b - a;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    final e = v - u;
    final len = e.length;
    final f0 = s * (e.x * (a.y - u.y) - e.y * (a.x - u.x)) / len;
    final fd = s * (e.x * d.y - e.y * d.x) / len;
    if (fd.abs() <= tol.linear) {
      if (f0 <= tol.linear) return null;
      continue;
    }
    final t = (tol.linear - f0) / fd;
    if (fd > 0) {
      lo = math.max(lo, t);
    } else {
      hi = math.min(hi, t);
    }
  }
  return (hi - lo) * d.length > Tolerance.standard.linear ? (lo, hi) : null;
}

/// The rectangle [0,w]x[0,h] in local space, minus every neighbour's
/// interior: four edges in order, each split into ascending pieces.
List<Generated> clippedRect(ParametricView view, Handle self) {
  final p = rectOf(view, self)!;
  final toLocal = view.toWorld(self).invert();
  final quads = [
    for (final n in view.neighbours(self))
      if (rectOf(view, n) case final q?)
        [
          for (final c in corners(q))
            toLocal.transformPoint(view.toWorld(n).transformPoint(c)),
        ],
  ];
  final c = corners(p);
  final out = <Generated>[];
  for (var i = 0; i < 4; i++) {
    final a = c[i], b = c[(i + 1) % 4];
    final len = (b - a).length;
    var keep = <(double, double)>[(0, 1)];
    for (final q in quads) {
      final inside = insideInterval(a, b, q);
      if (inside == null) continue;
      keep = [
        for (final (lo, hi) in keep) ...[
          if ((math.min(hi, inside.$1) - lo) * len > Tolerance.standard.linear)
            (lo, math.min(hi, inside.$1)),
          if ((hi - math.max(lo, inside.$2)) * len > Tolerance.standard.linear)
            (math.max(lo, inside.$2), hi),
        ],
      ];
    }
    for (final (lo, hi) in keep) {
      out.add(Generated(
          EntityKind.line, linePayload(a + (b - a) * lo, a + (b - a) * hi)));
    }
  }
  return out;
}

Aabb2 rectReach(RectParams p, Transform2 toWorld) =>
    Aabb2.fromPoints([for (final c in corners(p)) toWorld.transformPoint(c)]);

final class RectType<T extends RectParams> extends ParametricType<T> {
  const RectType(this.editCapability);
  @override
  final Capability editCapability;
  @override
  Aabb2 reach(T params, Transform2 toWorld) => rectReach(params, toWorld);
  @override
  List<Generated> generate(ParametricView view, Handle self) =>
      clippedRect(view, self);
}

final class TripType extends ParametricType<Trip> {
  const TripType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Trip params, Transform2 toWorld) => rectReach(params, toWorld);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    switch (Trip.mode) {
      case TripMode.off:
        break;
      case TripMode.throwing:
        throw StateError('tripwire');
      case TripMode.reentrant:
        Trip.document!.commands.execute(
            SetComponentCommand<Trip>(self, const Trip(10, 10)));
    }
    return clippedRect(view, self);
  }
}

/// Generates one LINE and one ARC, in an order its parameter flips (M-06m).
final class Hinge implements Component {
  const Hinge(this.flip);
  static const String id = 'test.hinge';
  final bool flip;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'flip': flip};
  static Hinge fromJson(Map<String, Object?> j) => Hinge(j['flip']! as bool);
  @override
  bool operator ==(Object o) => o is Hinge && o.flip == flip;
  @override
  int get hashCode => flip.hashCode;
}

final class HingeType extends ParametricType<Hinge> {
  const HingeType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Hinge params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, 0)),
        toWorld.transformPoint(Vector2(100, 100)),
      ]);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final line = Generated(
        EntityKind.line, linePayload(Vector2(0, 0), Vector2(100, 0)));
    final arc =
        Generated(EntityKind.arc, arcPayload(Vector2(50, 50), 40, 0.3, 1.2));
    return view.paramsOf<Hinge>(self)!.flip ? [arc, line] : [line, arc];
  }
}

ParametricCatalog testCatalog() => ParametricCatalog()
  ..register<ClipRect>(
      ClipRect.id, ClipRect.fromJson, const RectType<ClipRect>(Capability.geometry))
  ..register<SoftRect>(SoftRect.id, SoftRect.fromJson,
      const RectType<SoftRect>(Capability.components))
  ..register<Trip>(Trip.id, Trip.fromJson, const TripType())
  ..register<Hinge>(Hinge.id, Hinge.fromJson, const HingeType());
```

- [ ] **Step 2: Write the fixture.**

```dart
// packages/jet_cad_2d/test/parametric/support/fixture.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'clients.dart';

/// A's placement, and everything relational is placed relative to it, so
/// the whole scene is rotated and off the origin.
final Transform2 atA =
    Transform2.translation(7010, 3020).multiply(Transform2.rotation(math.pi / 6));
Transform2 onA(double x, double y, double turn) => atA
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

/// B pierces A's long top edge from inside: A's top edge splits in two (A
/// has 5 children), B's bottom edge is swallowed (B has 3).
final Transform2 atB = onA(800, 700, 0.3);

/// Far from everything, still rotated.
final Transform2 parked =
    Transform2.translation(19000, 11000).multiply(Transform2.rotation(-0.7));

const Handle hA = Handle(1000);
const Handle hB = Handle(2000);

final ParametricCatalog catalog = testCatalog();

DraftDocument paramDoc() {
  final doc = DraftDocument.empty();
  ParametricSystem(doc, catalog).install();
  return doc;
}

DraftCommand create<T extends Component>(
        DraftDocument doc, Handle h, Transform2 at, T params) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: at, children: const [])),
      SetComponentCommand<T>(h, params),
    ], label: 'Add object');

void pair(DraftDocument doc, {bool bFirst = false}) {
  final a = create(doc, hA, atA, const ClipRect(2000, 1000));
  final b = create(doc, hB, atB, const ClipRect(400, 900));
  for (final c in bFirst ? [b, a] : [a, b]) {
    doc.commands.execute(c);
  }
}

/// [group]'s children, ascending.
List<Handle> kids(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// Each LINE child of [group], in world coordinates.
List<List<double>> worldSegments(DraftDocument doc, Handle group) {
  final m = doc.tree.accumulatedTransform(group);
  return [
    for (final k in kids(doc, group))
      () {
        final g = doc.geometry
            .read(doc.entities.geomIndexAt(doc.entities.slotOf(k)!))
            .coords;
        final a = m.transformPoint(Vector2(g[0], g[1]));
        final b = m.transformPoint(Vector2(g[2], g[3]));
        return [a.x, a.y, b.x, b.y];
      }(),
  ];
}

String enc(DraftDocument d) => DraftDocumentCodec.encodeToString(d);

/// Entities sorted by handle: slot order is history, not state (spec D11).
String canon(DraftDocument d) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

/// Decodes with the catalog's factories and installs a system.
DraftDocument reload(String s) {
  final doc = DraftDocumentCodec.decode(jsonDecode(s) as Map<String, Object?>,
      registerComponents: catalog.registerComponents);
  ParametricSystem(doc, catalog).install();
  return doc;
}
```

- [ ] **Step 3: Write the failing tests P1–P9.**

```dart
// packages/jet_cad_2d/test/parametric/regeneration_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

void expectWorld(DraftDocument doc, Handle g, Transform2 at, double w, double h) {
  final c = [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
      .map(at.transformPoint)
      .toList();
  final got = worldSegments(doc, g);
  expect(got, hasLength(4));
  for (var i = 0; i < 4; i++) {
    final want = [c[i].x, c[i].y, c[(i + 1) % 4].x, c[(i + 1) % 4].y];
    for (var k = 0; k < 4; k++) {
      expect(got[i][k], closeTo(want[k], 1e-9), reason: 'edge $i coord $k');
    }
  }
}

void main() {
  test('P1 the first object in an empty document generates (M-06q)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    expectWorld(doc, hA, parked, 2000, 1000);
    for (final k in kids(doc, hA)) {
      expect(doc.entities.kindAt(doc.entities.slotOf(k)!), EntityKind.line);
    }
  });

  test('P2 a width edit regenerates in place, keeping every child handle '
      '(M-06p)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    final before = kids(doc, hA);
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(3100, 450)));
    expect(kids(doc, hA), before);
    expectWorld(doc, hA, parked, 3100, 450);
  });

  test('P3 edit plus regeneration is one undo step; undo and redo restore '
      'both, with the same handles (M-06c)', () {
    final doc = paramDoc();
    pair(doc);
    expect(kids(doc, hA), hasLength(5));
    expect(kids(doc, hB), hasLength(3));
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400)));
    expect(doc.commands.undoDepth, depth + 1);
    final after = canon(doc);
    final handlesAfter = [...kids(doc, hA), ...kids(doc, hB)];
    expect(after, isNot(before));
    doc.commands.undo();
    expect(canon(doc), before);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    doc.commands.redo();
    expect(canon(doc), after);
    expect([...kids(doc, hA), ...kids(doc, hB)], handlesAfter);
  });

  test('P4 the summary says geometry, so the index sees new children '
      '(M-06h)', () {
    final doc = paramDoc();
    final index = SpatialIndex(doc);
    // A at width 500 does not reach B; at 2000 it does, and both re-clip.
    doc.commands.execute(create(doc, hA, atA, const ClipRect(500, 1000)));
    doc.commands.execute(create(doc, hB, atB, const ClipRect(400, 900)));
    expect(kids(doc, hA), hasLength(4));
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2000, 1000)));
    expect(kids(doc, hA), hasLength(5));
    for (final g in [hA, hB]) {
      for (final s in worldSegments(doc, g)) {
        final mid = Vector2((s[0] + s[2]) / 2, (s[1] + s[3]) / 2);
        final found = <Handle>{};
        index.forEachInRect(
            Aabb2(mid - Vector2(0.5, 0.5), mid + Vector2(0.5, 0.5)),
            const QueryFilter.all(),
            (slot) => found.add(doc.entities.handleAt(slot)));
        expect(found.intersection(kids(doc, g).toSet()), isNotEmpty,
            reason: 'a child of ${g.toHex()} at $mid');
      }
    }
    index.dispose();
  });

  test('P5 children are matched by kind, then ordinal (M-06m)', () {
    final doc = paramDoc();
    const h = Handle(3000);
    doc.commands.execute(create(doc, h, parked, const Hinge(false)));
    final before = kids(doc, h);
    doc.commands.execute(SetComponentCommand<Hinge>(h, const Hinge(true)));
    expect(kids(doc, h), before);
    for (final k in kids(doc, h)) {
      final slot = doc.entities.slotOf(k)!;
      final p = doc.geometry.read(doc.entities.geomIndexAt(slot));
      switch (doc.entities.kindAt(slot)) {
        case EntityKind.line:
          expect((p.coords.length, p.scalars.length), (4, 0));
        case EntityKind.arc:
          expect(p.scalars.length, 3);
        default:
          fail('unexpected kind');
      }
    }
  });

  test('P6 fast path: no parametric object, no parametric command, the '
      'command is returned as is', () {
    final doc = paramDoc();
    final add = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));
    expect(identical(doc.commands.expander!(add), add), isTrue);
    final box = create(doc, hA, parked, const ClipRect(10, 10));
    expect(doc.commands.expander!(box), isA<ParametricEdit>());
  });

  test('P7 a fill cannot be generated', () {
    expect(
        () => Generated(EntityKind.fill, linePayload(Vector2(1, 2), Vector2(3, 4))),
        throwsArgumentError);
  });

  test('P8 one system per document; dispose releases only its own slot', () {
    final doc = DraftDocument.empty();
    final s = ParametricSystem(doc, catalog)..install();
    expect(() => ParametricSystem(doc, catalog).install(), throwsStateError);
    s.dispose();
    expect(doc.commands.expander, isNull);
    final t = ParametricSystem(doc, catalog)..install();
    s.dispose();
    expect(doc.commands.expander, isNotNull, reason: 's no longer owns it');
    t.dispose();
  });

  test('P9 a ParametricEdit applies once (spec D9)', () {
    final doc = paramDoc();
    final edit = doc.commands.expander!(
        create(doc, hA, parked, const ClipRect(10, 10)));
    edit.apply(doc);
    expect(() => edit.apply(doc), throwsStateError);
  });

  test('P10 a second system over a populated document keeps its '
      'components (Ruling 06-13, M-06v)', () {
    final doc = paramDoc();
    pair(doc);
    final before = enc(doc);
    final second = ParametricSystem(doc, catalog);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    expect(second.drift(), isEmpty);
    expect(enc(doc), before);
  });
}
```

- [ ] **Step 4: Run the tests; they fail.**
  - Run: `cd packages/jet_cad_2d && CI=true dart test test/parametric`
  - Expected: compile errors, because nothing in `parametric/` exists.

- [ ] **Step 5: Implement `parametric_system.dart`.**

```dart
// packages/jet_cad_2d/lib/src/parametric/parametric_system.dart
import '../core/diagnostic.dart';
import '../core/handle.dart';
import '../core/tolerance.dart';
import '../document/command.dart';
import '../document/commands.dart';
import '../document/component.dart';
import '../document/draft_document.dart';
import '../document/drafting.dart';
import '../document/node.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';

part 'regeneration.dart';

/// What one parametric type contributes (spec 06 D3). Behaviour lives here,
/// outside the document, which stays data only.
abstract class ParametricType<T extends Component> {
  const ParametricType();

  /// The capability a change of `T`'s value needs (spec D7).
  Capability get editCapability;

  /// The world region this object's generation depends on and affects,
  /// from parameters and the group's accumulated transform only.
  Aabb2 reach(T params, Transform2 toWorld);

  /// This object's entities, in the group's local space, from its own
  /// parameters and its neighbours' — never from generated geometry.
  List<Generated> generate(ParametricView view, Handle self);
}

/// One generated entity (spec D3). Never a fill: `SetEntityGeometryCommand`
/// rejects a fill's payload, and regions are out of scope.
final class Generated {
  Generated(this.kind, this.payload) {
    if (kind == EntityKind.fill) {
      throw ArgumentError.value(
          kind, 'kind', 'a fill cannot be generated (spec 06 D3)');
    }
  }

  final EntityKind kind;
  final GeometryPayload payload;
}

/// A direct edit of a generated entity (spec D6). Propagates like
/// `PermissionDeniedError`; the UI never offers the edit.
class GeneratedGeometryError implements Exception {
  const GeneratedGeometryError(this.handle);

  final Handle handle;

  @override
  String toString() => 'GeneratedGeometryError: ${handle.toHex()} is '
      'generated by a parametric object and cannot be edited directly';
}

/// Read-only access for [ParametricType.generate].
final class ParametricView {
  ParametricView._(this._target, this._neighbours);

  final CommandTarget _target;
  final Map<Handle, List<Handle>> _neighbours;

  U? paramsOf<U extends Component>(Handle h) => _target.components.get<U>(h);

  /// The accumulated transform: group-local to world.
  Transform2 toWorld(Handle h) => _worldOf(_target, h);

  /// Ascending handles of the objects whose reach overlaps [h]'s.
  List<Handle> neighbours(Handle h) => _neighbours[h] ?? const [];
}

/// The parametric types an application knows, independent of any document
/// (Ruling 06-1): `DraftDocumentCodec.decode` needs the factories before
/// the document exists.
class ParametricCatalog {
  final List<_Registration<Component>> _types = [];

  void register<T extends Component>(String typeId,
      ComponentFactory<T> factory, ParametricType<T> type) {
    _types.add(_Registration<T>(typeId, factory, type));
  }

  /// Pass as `DraftDocumentCodec.decode(…, registerComponents: …)`.
  void registerComponents(ComponentRegistry registry) {
    for (final t in _types) {
      t.registerInto(registry);
    }
  }
}

/// Regenerates parametric objects inside the edit that changes them (spec
/// 06 D1, D2, D4). One per document; takes the dispatcher's expander slot.
class ParametricSystem {
  ParametricSystem(this.document, this.catalog) {
    catalog.registerComponents(document.components);
  }

  final DraftDocument document;
  final ParametricCatalog catalog;

  bool _applying = false;

  List<_Registration<Component>> get _types => catalog._types;

  void install() {
    if (document.commands.expander != null) {
      throw StateError('the dispatcher already has an expander (spec 06 D2)');
    }
    document.commands.expander = _expand;
  }

  /// Releases the slot only if it is still this system's own tear-off.
  void dispose() {
    if (document.commands.expander == _expand) {
      document.commands.expander = null;
    }
  }

  /// Handles whose regeneration would change anything (spec D10). A dry
  /// run: reserves no handle, mutates nothing.
  List<Handle> drift() {
    final s = _survey(document, _types);
    final view = ParametricView._(document, s.neighbours);
    return [
      for (final h in s.objects.keys)
        if (_plan(document, [h], s, view).isNotEmpty) h,
    ];
  }

  /// One diagnostic per parametric component on a holder that is not a
  /// root-level group: it is not regenerated (spec D5).
  List<Diagnostic> diagnostics() => [
        for (final t in _types)
          for (final h in t.handles(document))
            if (!_isObject(document, _types, h))
              Diagnostic(
                severity: DiagnosticSeverity.warning,
                code: 'parametric.misplaced',
                message: '${t.typeId} on ${h.toHex()}, which is not a '
                    'root-level group, is not regenerated',
                handles: [h],
              ),
      ];

  DraftCommand _expand(DraftCommand command) {
    if (_applying) {
      throw StateError('execute() inside a parametric regeneration '
          '(spec 06 D2): generate() must not mutate');
    }
    if (!_types.any((t) => t.handles(document).isNotEmpty) &&
        !_setsParametric(command)) {
      return command;
    }
    return ParametricEdit._(this, command);
  }

  bool _setsParametric(DraftCommand c) => c is CompoundCommand
      ? c.children.any(_setsParametric)
      : _types.any((t) => t.owns(c));

  Set<Capability> _editCapabilitiesOf(DraftCommand c) => c is CompoundCommand
      ? {for (final child in c.children) ..._editCapabilitiesOf(child)}
      : {
          for (final t in _types)
            if (t.owns(c)) t.type.editCapability,
        };
}

/// An edit and its regeneration, as one command (spec D4). Created only by
/// the expander, once per `execute`, and applied once (spec D9).
final class ParametricEdit extends DraftCommand {
  ParametricEdit._(this._system, this.inner);

  final ParametricSystem _system;
  final DraftCommand inner;
  bool _applied = false;
  bool _geometryChanged = false;

  @override
  String get label => inner.label;

  /// The triggering edit's authority plus each parametric type's
  /// `editCapability`; the regeneration adds none of its own (spec D7).
  @override
  Set<Capability> get capabilities =>
      {...inner.capabilities, ..._system._editCapabilitiesOf(inner)};

  /// Read by the dispatcher after [apply]: `geometry` whenever the plan
  /// changed geometry, so the index does not skip it (spec D9).
  @override
  Capability get capability =>
      _geometryChanged && inner.capability.index < Capability.geometry.index
          ? Capability.geometry
          : inner.capability;

  @override
  CommandResult apply(CommandTarget target) {
    if (_applied) {
      throw StateError('a ParametricEdit applies once (spec 06 D9)');
    }
    _applied = true;
    _system._applying = true;
    try {
      return _run(this, target);
    } finally {
      _system._applying = false;
    }
  }
}

/// The concrete inverse of a [ParametricEdit]: undo and redo replay it and
/// never regenerate. Its own inverse is again a `ParametricReplay` with the
/// same [capabilities], so redo is authorised exactly as undo (spec D7).
final class ParametricReplay extends DraftCommand {
  ParametricReplay(this.replay, Set<Capability> capabilities)
      : capabilities = Set.unmodifiable(capabilities);

  final CompoundCommand replay;

  @override
  final Set<Capability> capabilities;

  @override
  Capability get capability => replay.capability;

  @override
  String get label => replay.label;

  @override
  CommandResult apply(CommandTarget target) {
    final r = replay.apply(target);
    return CommandResult(
      inverse: ParametricReplay(r.inverse as CompoundCommand, capabilities),
      touched: r.touched,
    );
  }
}

/// One registered type, with `T` captured so the untyped system can call it.
final class _Registration<T extends Component> {
  _Registration(this.typeId, this.factory, this.type);

  final String typeId;
  final ComponentFactory<T> factory;
  final ParametricType<T> type;

  /// Ruling 06-13: `register` replaces the store, wiping every component
  /// of `T`, so a type already registered is left alone.
  void registerInto(ComponentRegistry r) {
    if (!r.isRegistered<T>()) r.register<T>(typeId, factory);
  }
  bool has(CommandTarget t, Handle h) => t.components.get<T>(h) != null;
  Iterable<Handle> handles(CommandTarget t) => t.components.withComponent<T>();
  bool owns(DraftCommand c) => c is SetComponentCommand<T>;
  DraftCommand detach(Handle h) => SetComponentCommand<T>(h, null);
  Aabb2 reachOf(CommandTarget t, Handle h) =>
      type.reach(t.components.get<T>(h) as T, _worldOf(t, h));
  List<Generated> generate(ParametricView v, Handle h) => type.generate(v, h);
}
```

- [ ] **Step 6: Implement `regeneration.dart`.**

```dart
// packages/jet_cad_2d/lib/src/parametric/regeneration.dart
part of 'parametric_system.dart';

int _byValue(Handle a, Handle b) => a.value.compareTo(b.value);

/// Group-local to world for a parametric object. Mutant M-06g returns the
/// identity here.
Transform2 _worldOf(CommandTarget t, Handle h) =>
    t.tree.accumulatedTransform(h);

/// A root-level group carrying a registered parametric component (spec D5).
bool _isObject(
    CommandTarget t, List<_Registration<Component>> types, Handle h) {
  final node = t.tree[h];
  return node is GroupNode &&
      node.parent == t.tree.root &&
      types.any((r) => r.has(t, h));
}

/// Everything the planner reads about the parametric objects at one moment.
final class _Survey {
  _Survey(this.objects, this.neighbours, this.children, this.owned);

  /// Live objects, ascending, with their registration.
  final Map<Handle, _Registration<Component>> objects;

  /// Each object's neighbours, ascending (spec D3).
  final Map<Handle, List<Handle>> neighbours;

  /// Each object's children, ascending.
  final Map<Handle, List<Handle>> children;

  /// Every child of a live object, to its owner: the set G of spec D4.
  final Map<Handle, Handle> owned;
}

_Survey _survey(CommandTarget t, List<_Registration<Component>> types) {
  final found = <Handle, _Registration<Component>>{};
  for (final r in types) {
    for (final h in r.handles(t)) {
      if (_isObject(t, types, h)) found[h] = r;
    }
  }
  final order = found.keys.toList()..sort(_byValue);
  final objects = {for (final h in order) h: found[h]!};
  final reach = {for (final h in order) h: objects[h]!.reachOf(t, h)};
  const tol = Tolerance.standard;
  bool overlap(Aabb2 a, Aabb2 b) =>
      a.minX < b.maxX - tol.linear &&
      b.minX < a.maxX - tol.linear &&
      a.minY < b.maxY - tol.linear &&
      b.minY < a.maxY - tol.linear;
  final neighbours = {
    for (final a in order)
      a: [
        for (final b in order)
          if (b != a && overlap(reach[a]!, reach[b]!)) b,
      ],
  };
  final children = <Handle, List<Handle>>{};
  final owned = <Handle, Handle>{};
  for (final slot in t.entities.liveSlots) {
    final owner = t.entities.ownerAt(slot);
    if (!objects.containsKey(owner)) continue;
    final h = t.entities.handleAt(slot);
    (children[owner] ??= []).add(h);
    owned[h] = owner;
  }
  for (final list in children.values) {
    list.sort(_byValue);
  }
  return _Survey(objects, neighbours, children, owned);
}

/// Seeds plus their neighbours before and after, as a sorted list of live
/// objects (spec D4 step 6). One hop: generation reads parameters only.
List<Handle> _closure(Set<Handle> seeds, _Survey before, _Survey after) => {
      ...seeds,
      for (final s in seeds) ...?before.neighbours[s],
      for (final s in seeds) ...?after.neighbours[s],
    }.where(after.objects.containsKey).toList()
      ..sort(_byValue);

bool _samePayload(GeometryPayload a, GeometryPayload b) {
  if (a.coords.length != b.coords.length ||
      a.scalars.length != b.scalars.length) {
    return false;
  }
  for (var i = 0; i < a.coords.length; i++) {
    if (a.coords[i] != b.coords[i]) return false;
  }
  for (var i = 0; i < a.scalars.length; i++) {
    if (a.scalars[i] != b.scalars[i]) return false;
  }
  return true;
}

/// Plans, and does not apply, the commands that bring [closure] up to date
/// (spec D4 step 7). New children get **reserved** handles above the seed,
/// which is not advanced: `AddEntityCommand.apply` raises it when the add
/// lands.
List<DraftCommand> _plan(CommandTarget t, List<Handle> closure, _Survey s,
    ParametricView view) {
  var reserved = t.handleSeed.current.value;
  final out = <DraftCommand>[];
  for (final h in closure) {
    final generated = s.objects[h]!.generate(view, h);
    final byKind = <EntityKind, List<Handle>>{};
    for (final c in s.children[h] ?? const <Handle>[]) {
      (byKind[t.entities.kindAt(t.entities.slotOf(c)!)] ??= []).add(c);
    }
    final used = <EntityKind, int>{};
    for (final g in generated) {
      final i = used[g.kind] ?? 0;
      used[g.kind] = i + 1;
      final existing = byKind[g.kind];
      if (existing != null && i < existing.length) {
        final slot = t.entities.slotOf(existing[i])!;
        if (!_samePayload(
            t.geometry.peek(t.entities.geomIndexAt(slot)), g.payload)) {
          out.add(SetEntityGeometryCommand(existing[i], g.payload));
        }
      } else {
        out.add(AddEntityCommand(
            record: draftRecord(Handle.checked(++reserved), h, g.kind),
            payload: g.payload));
      }
    }
    final surplus = [
      for (final e in byKind.entries) ...e.value.skip(used[e.key] ?? 0),
    ]..sort(_byValue);
    for (final c in surplus) {
      out.add(RemoveEntityCommand(c));
    }
  }
  return out;
}

/// The first touched handle that edits a generated entity, removes one
/// while its group lives, or adds one into a live object (spec D6).
Handle? _refused(CommandTarget t, List<_Registration<Component>> types,
    _Survey before, Set<Handle> touched) {
  for (final h in touched.toList()..sort(_byValue)) {
    final owner = before.owned[h];
    if (owner != null) {
      if (_isObject(t, types, owner)) return h;
      continue;
    }
    final slot = t.entities.slotOf(h);
    if (slot != null && _isObject(t, types, t.entities.ownerAt(slot))) {
      return h;
    }
  }
  return null;
}

/// Undoes [r] after a failure; if that fails too, the target is in an
/// unknown state and the caller must know it.
void _undoInner(CommandTarget t, String label, CommandResult r, Object cause) {
  try {
    r.inverse.apply(t);
  } catch (rollbackError) {
    throw StateError('"$label": $cause, and undoing the edit then threw '
        '($rollbackError); the target is partially mutated and nothing was '
        'recorded in history');
  }
}

/// Spec D4 steps 1–9.
CommandResult _run(ParametricEdit edit, CommandTarget t) {
  final types = edit._system._types;
  final before = _survey(t, types);
  final r = edit.inner.apply(t);

  final refused = _refused(t, types, before, r.touched);
  if (refused != null) {
    _undoInner(t, edit.label, r, GeneratedGeometryError(refused));
    throw GeneratedGeometryError(refused);
  }

  final after = _survey(t, types);
  // Ruling 06-3: only objects that were live before the edit.
  final lost = [
    for (final h in before.objects.keys)
      if (!after.objects.containsKey(h) && t.tree[h] == null) h,
  ];
  final cleanup = [for (final h in lost) before.objects[h]!.detach(h)];
  final seeds = <Handle>{
    for (final h in r.touched) ...[
      // Ruling 06-4: a handle that was an object seeds too.
      if (after.objects.containsKey(h) || before.objects.containsKey(h)) h,
      if (before.owned[h] case final owner?) owner,
    ],
    ...lost,
  };
  if (seeds.isEmpty && cleanup.isEmpty) return r;

  final List<DraftCommand> plan;
  try {
    plan = _plan(t, _closure(seeds, before, after), after,
        ParametricView._(t, after.neighbours));
  } catch (error) {
    _undoInner(t, edit.label, r, error);
    rethrow;
  }
  edit._geometryChanged = plan.isNotEmpty;

  final inverses = <DraftCommand>[];
  final touched = <Handle>{...r.touched};
  for (final c in [...cleanup, ...plan]) {
    final CommandResult applied;
    try {
      applied = c.apply(t);
    } catch (error) {
      try {
        for (final i in inverses.reversed) {
          i.apply(t);
        }
      } catch (rollbackError) {
        throw StateError('"${edit.label}": regeneration threw ($error) and '
            'its rollback threw ($rollbackError); the target is partially '
            'mutated and nothing was recorded in history');
      }
      _undoInner(t, edit.label, r, error);
      rethrow;
    }
    inverses.add(applied.inverse);
    touched.addAll(applied.touched);
  }

  return CommandResult(
    inverse: ParametricReplay(
      CompoundCommand([
        if (inverses.isNotEmpty)
          CompoundCommand(inverses.reversed.toList(), label: 'Regenerate'),
        r.inverse,
      ], label: edit.label),
      edit.capabilities,
    ),
    touched: touched,
  );
}
```

If `dart analyze` flags an unused import in the part's host (for example
`draft_document.dart` or `node.dart`), keep only what is referenced.
`GroupNode` comes from `node.dart`. `DraftDocument` is used by
`ParametricSystem.document`.

- [ ] **Step 7: Run P1–P10; they pass.** Paste the output. Then run the
  engine line and the render line.
- [ ] **Step 8: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/parametric packages/jet_cad_2d/lib/jet_cad_2d.dart packages/jet_cad_2d/test/parametric
git commit -m "$(cat <<'EOF'
feat(engine): the parametric system and planner (spec 06 D1-D9)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

