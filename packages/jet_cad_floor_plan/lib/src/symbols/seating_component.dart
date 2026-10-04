// The seating component (spec 14 S1): a symbol definition that carries one
// is servable -- a table, a booth, a bar stool, a place the restaurant
// serves -- and says how many it seats. Attached to a definition's handle,
// beside its [SymbolComponent].
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// How many people a servable symbol seats (spec 14 S1, R-1, R-2).
///
/// A **new component type**, not a field on `SymbolComponent`: an older
/// build preserves an unknown component type verbatim and would drop an
/// unknown field (spec 14 F-5), so adding it needs no schema bump.
///
/// Immutable and value-equal; [toJson] has one fixed key. Not a parametric
/// type: it generates nothing.
class SeatingComponent implements Component {
  static const String componentTypeId = 'jetcad.seating';

  /// Registers the type. **Once per registry**: `register` replaces the
  /// store for the type, so a second call drops every live seating
  /// component.
  static void register(ComponentRegistry registry) =>
      registry.register<SeatingComponent>(componentTypeId, fromJson);

  final int seats;

  /// Throws [ArgumentError] (not an `assert`: a release build must refuse
  /// too) when [seats] is below 1.
  SeatingComponent({required this.seats}) {
    if (seats < 1) {
      throw ArgumentError.value(seats, 'seats', 'must be at least 1');
    }
  }

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'seats': seats};

  /// Throws [FormatException] when `seats` is missing or not an integer,
  /// and [ArgumentError] when it is below 1.
  static SeatingComponent fromJson(Map<String, Object?> json) {
    final seats = json['seats'];
    if (seats is! int) {
      throw const FormatException('SeatingComponent: "seats" is not an int');
    }
    return SeatingComponent(seats: seats);
  }

  @override
  bool operator ==(Object other) =>
      other is SeatingComponent && other.seats == seats;

  @override
  int get hashCode => seats.hashCode;

  @override
  String toString() => 'SeatingComponent($seats)';
}
