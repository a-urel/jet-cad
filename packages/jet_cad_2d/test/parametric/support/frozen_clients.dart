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
          handle: h,
          parent: doc.rootHandle,
          transform: at,
          children: const [])),
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
