// The host API's value types (spec 14b-2 H3, H6).

import 'package:flutter/foundation.dart';

/// The two built-in modes (umbrella decision 2, spec 14b-2 H1).
enum FloorPlanMode {
  /// Today's editor: palette, tools, the Table section, on the designed
  /// plan.
  design,

  /// The canvas alone, under `runtime` permissions, on a service copy of
  /// the plan: nothing done here reaches the design.
  selection,
}

/// One table of the active plan, as a host sees it: never a handle
/// (umbrella D18).
@immutable
final class FloorPlanTable {
  const FloorPlanTable(
      {required this.number, required this.seats, required this.symbolKey});

  /// The table's number, or null while it has none.
  final String? number;

  /// How many it seats: its symbol's.
  final int seats;

  /// The library key of its symbol, or null for a hand-made one.
  final String? symbolKey;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTable &&
      other.number == number &&
      other.seats == seats &&
      other.symbolKey == symbolKey;

  @override
  int get hashCode => Object.hash(number, seats, symbolKey);

  @override
  String toString() => 'FloorPlanTable($number, $seats, $symbolKey)';
}

/// What Export hands the host (spec 14b-2 H6): the bytes and what to call
/// them. The host stores them as it likes.
@immutable
final class FloorPlanExport {
  const FloorPlanExport(
      {required this.bytes, required this.fileName, required this.mimeType});

  final Uint8List bytes;

  /// `<exportName>.pdf` or `<exportName>.png`.
  final String fileName;

  /// `application/pdf` or `image/png`.
  final String mimeType;
}
