// The architecture kit's type and tool ids (spec 3a C2, umbrella A7): today's
// floor_planner.<type> (jet_cad_floor_plan/lib/src/parametric/catalog.dart:
// 27-39) under the kit's id. A type id is its component's codec type id.

/// The kit's parametric type ids.
abstract final class ArchitectureTypes {
  static const String box = 'architecture.box';
  static const String wall = 'architecture.wall';
  static const String opening = 'architecture.opening';
  static const String separator = 'architecture.separator';
  static const String room = 'architecture.room';
  static const String dimension = 'architecture.dimension';
}

/// The kit's tool ids; a tool's word is `tool:<id>`.
abstract final class ArchitectureTools {
  static const String box = 'architecture.box';
  static const String wall = 'architecture.wall';
  static const String door = 'architecture.door';
  static const String window = 'architecture.window';
  static const String gap = 'architecture.gap';
  static const String room = 'architecture.room';
  static const String separator = 'architecture.separator';
  static const String dimension = 'architecture.dimension';
}
