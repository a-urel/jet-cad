// The grip cache's one object provider (spec 2a P2: "grip cache (one
// provider, dispatching by typeIdOf, E1)"): each root-level group is asked
// of its own type's provider. Replaces the if-chain of today's ObjectGrips
// (jet_cad_floor_plan/lib/src/parametric/object_grips.dart). Task 10 adds
// the lock (no grips, not movable), Task 11 the guard.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class GripDispatch implements ObjectGripProvider {
  GripDispatch(this._catalog);

  final ParametricCatalog _catalog;
  final Map<String, ObjectGripProvider> _byType = {};

  void add(String typeId, ObjectGripProvider provider) =>
      _byType[typeId] = provider;

  /// Lets every provider go: a replaced plan's views reach none.
  void close() => _byType.clear();

  ObjectGripProvider? _of(DraftDocument d, Handle group) {
    if (_byType.isEmpty) return null;
    final typeId = _catalog.typeIdOf(d, group);
    return typeId == null ? null : _byType[typeId];
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) =>
      _of(d, group)?.gripsOf(d, group) ?? const [];

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(d, group)?.drag(d, group, grip, world);

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(d, group)?.preview(d, group, grip, world) ?? const [];

  @override
  bool movable(DraftDocument d, Handle group) =>
      _of(d, group)?.movable(d, group) ?? true;
}
