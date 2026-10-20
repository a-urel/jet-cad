// A host's name for one object of the plan (spec D8): opaque, and equal to
// another reference to the same object, in this controller or in one that
// loaded the saved plan.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;
import 'package:meta/meta.dart';

/// One placed object of the plan: a unit, a placed symbol or an object of a
/// kit's type. Read from `PlanController.objectDetails` or a
/// `PlanObjectDetail`, never made by a host.
///
/// It names the object by its persisted handle, so it survives a save and a
/// load, and two references to one object are `==`. It carries no handle a
/// host can read. A reference whose object is gone (deleted, or the plan
/// replaced) names nothing: the controller answers it with null or false.
@immutable
final class PlanObjectRef {
  /// The reference to [handle]. For the library only.
  @internal
  const PlanObjectRef.of(this.handle);

  /// The wrapped handle. For the library only: a host never receives one.
  @internal
  final Handle handle;

  @override
  bool operator ==(Object other) =>
      other is PlanObjectRef && other.handle == handle;

  @override
  int get hashCode => handle.hashCode;

  @override
  String toString() => 'PlanObjectRef(${handle.value})';
}
