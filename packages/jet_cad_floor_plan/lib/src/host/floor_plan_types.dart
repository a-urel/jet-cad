// The host API's value types (spec 14b-2 H3, H6).

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color, StringCharacters;

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

/// A table's status as the host colours it in the selection mode (spec 14c
/// S5): a fill under the drafting, and an optional short caption. Not
/// document state: never saved, exported, printed or undone.
@immutable
final class TableStatus {
  /// [caption] is cut to [maxCaption] characters (grapheme clusters, R-12).
  TableStatus({required this.color, String? caption})
      : caption = caption?.characters.take(maxCaption).toString();

  /// The longest caption, in characters.
  static const int maxCaption = 12;

  /// The fill, drawn as given: a translucent colour lets the paper show.
  final Color color;

  final String? caption;

  @override
  bool operator ==(Object other) =>
      other is TableStatus && other.color == color && other.caption == caption;

  @override
  int get hashCode => Object.hash(color, caption);

  @override
  String toString() => 'TableStatus($color, $caption)';
}

/// What [FloorPlanController.restoreServiceLayout] did (spec 14d S2): the
/// numbers of the entries it applied and of those it dropped, in the
/// layout's order; an unnumbered table's is null, so a number may repeat
/// and the lengths are the counts.
@immutable
final class ServiceLayoutRestore {
  const ServiceLayoutRestore({required this.applied, required this.dropped});

  final List<String?> applied;
  final List<String?> dropped;

  @override
  String toString() => 'ServiceLayoutRestore(applied: $applied, '
      'dropped: $dropped)';
}
