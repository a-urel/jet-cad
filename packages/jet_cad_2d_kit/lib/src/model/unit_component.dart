// The service unit (spec K2, umbrella A6): a symbol definition that carries
// one is served -- a table, a seat -- with its capacity and how its label is
// formed. On a definition's handle. Replaces jet_cad_floor_plan's
// SeatingComponent.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'json_fields.dart';
import 'kit_ids.dart';

/// How a placed unit's label is formed.
enum UnitLabelling {
  /// The plan gives a placed unit the next free number (a table).
  numbered,

  /// A kit's type sets the label (a seat in a row).
  assigned,
}

/// The unit kinds the contract names. Others are allowed.
abstract final class UnitKinds {
  static const String table = 'table';
  static const String seat = 'seat';
}

/// A served unit: its [kind], its [capacity] and its [labelling].
@immutable
final class UnitComponent implements Component {
  /// Throws [ArgumentError] when [kind] breaks K2's kind pattern or
  /// [capacity] is below 1.
  UnitComponent({
    required this.kind,
    required this.capacity,
    this.labelling = UnitLabelling.numbered,
  }) {
    if (!isKind(kind)) {
      throw ArgumentError.value(kind, 'kind',
          'must be lower-case letters and digits joined by single hyphens');
    }
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'must be at least 1');
    }
  }

  static const String componentTypeId = 'jetcad.unit';

  final String kind;
  final int capacity;
  final UnitLabelling labelling;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'capacity': capacity,
        'kind': kind,
        'labelling': labelling.name,
      };

  /// Throws [FormatException] for a missing or mistyped field or an unknown
  /// labelling, and the constructor's [ArgumentError] for a bad value.
  static UnitComponent fromJson(Map<String, Object?> json) {
    const t = 'UnitComponent';
    final name = field<String>(json, 'labelling', t);
    final labelling = UnitLabelling.values.asNameMap()[name];
    if (labelling == null) {
      throw FormatException('$t: "labelling" is not a labelling: $name');
    }
    return UnitComponent(
      kind: field<String>(json, 'kind', t),
      capacity: field<int>(json, 'capacity', t),
      labelling: labelling,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UnitComponent &&
      other.kind == kind &&
      other.capacity == capacity &&
      other.labelling == labelling;

  @override
  int get hashCode => Object.hash(kind, capacity, labelling);

  @override
  String toString() => 'UnitComponent($kind, $capacity, ${labelling.name})';
}
