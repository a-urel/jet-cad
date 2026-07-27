import 'package:meta/meta.dart';

import '../core/handle.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'component.dart';
import 'tables.dart';
import 'tree.dart';

/// What a command is allowed to change.
///
/// The split is only possible because leaves carry no transform: moving an
/// instance and editing geometry are already distinct operations.
enum Capability {
  /// Move or rotate an instance or group.
  transform,

  /// Edit component data.
  components,

  /// Change coordinates, add or remove entities.
  geometry,

  /// Change the tree, definitions, or groups.
  structure,
}

@immutable
class DraftPermissions {
  final bool transform;
  final bool components;
  final bool geometry;
  final bool structure;

  const DraftPermissions({
    required this.transform,
    required this.components,
    required this.geometry,
    required this.structure,
  });

  static const DraftPermissions all = DraftPermissions(
      transform: true, components: true, geometry: true, structure: true);

  /// A point-of-sale runtime: staff may move a table and change its
  /// properties, but cannot draw walls or alter a block definition.
  static const DraftPermissions runtime = DraftPermissions(
      transform: true, components: true, geometry: false, structure: false);

  static const DraftPermissions readOnly = DraftPermissions(
      transform: false, components: false, geometry: false, structure: false);

  bool allows(Capability capability) => switch (capability) {
        Capability.transform => transform,
        Capability.components => components,
        Capability.geometry => geometry,
        Capability.structure => structure,
      };
}

class PermissionDeniedError implements Exception {
  final Capability capability;
  final String label;
  const PermissionDeniedError(this.capability, this.label);

  @override
  String toString() =>
      'PermissionDeniedError: "$label" needs ${capability.name}';
}

/// Everything a command may touch — and nothing more.
///
/// Commands land before the document type does, so this interface — rather
/// than a concrete `DraftDocument` — is the seam a command is written
/// against. That lets this task be tested against a small fake, and it
/// states exactly what a command is allowed to touch.
abstract class CommandTarget {
  EntityStore get entities;
  GeometryStore get geometry;
  DocumentTree get tree;
  DocumentTables get tables;
  ComponentRegistry get components;
  HandleSeed get handleSeed;

  /// Marks derived state stale: working extents, cached world transforms, and
  /// any index built over the stores. Derived state is never persisted, so this
  /// is the only bookkeeping a mutation owes it.
  void invalidateDerived();
}

@immutable
class CommandResult {
  final DraftCommand inverse;
  final Set<Handle> touched;
  const CommandResult({required this.inverse, required this.touched});
}

/// A single reversible mutation.
///
/// Undo is a plain value diff — there is no kernel and therefore no snapshot,
/// which is why an inverse can be an ordinary command carrying a payload.
abstract class DraftCommand {
  Capability get capability;

  /// Short, human-readable, and used in [DocChange] events.
  String get label;

  /// Applies the change and returns its inverse plus the handles it touched.
  /// Must either complete fully or leave the target unmutated.
  CommandResult apply(CommandTarget target);
}
