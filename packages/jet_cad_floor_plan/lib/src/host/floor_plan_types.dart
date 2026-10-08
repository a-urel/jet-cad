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
      {required this.number,
      required this.seats,
      required this.symbolKey,
      this.visible = true});

  /// The table's number, or null while it has none.
  final String? number;

  /// How many it seats: its symbol's.
  final int seats;

  /// The library key of its symbol, or null for a hand-made one.
  final String? symbolKey;

  /// Whether the plan draws it: false for a table on a hidden layer (zone
  /// spec Z24), which the view neither shows nor lets anyone pick, so a
  /// host counts it as unplaced (Z18).
  final bool visible;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTable &&
      other.number == number &&
      other.seats == seats &&
      other.symbolKey == symbolKey &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(number, seats, symbolKey, visible);

  @override
  String toString() =>
      'FloorPlanTable($number, $seats, $symbolKey, visible: $visible)';
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

/// What a long press on a table does in the selection mode (spec 14d S7).
enum FloorPlanLongPress {
  /// Adds the table to the selection or removes it (umbrella decision 9).
  toggleSelection,

  /// Reports the table to `FloorPlanView.onTableContextMenu`, as a
  /// secondary click does; a touch screen then has no multiple selection.
  contextMenu,
}

/// A problem with the plan's table numbers (spec 14a T15), as a value the
/// host words, or asks `FloorPlanStrings.numberingWarning` to (spec 14d
/// L6). Never a handle (D18).
sealed class NumberingWarning {
  const NumberingWarning();
}

/// [count] live tables carry [number].
final class DuplicateNumber extends NumberingWarning {
  const DuplicateNumber({required this.number, required this.count});

  final String number;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is DuplicateNumber &&
      other.number == number &&
      other.count == count;

  @override
  int get hashCode => Object.hash(number, count);

  @override
  String toString() => 'DuplicateNumber($number, $count)';
}

/// A live table carries no number. Two of one symbol read alike: the host
/// sees how many there are.
final class Unnumbered extends NumberingWarning {
  const Unnumbered({required this.seats, required this.symbolKey});

  final int seats;
  final String? symbolKey;

  @override
  bool operator ==(Object other) =>
      other is Unnumbered &&
      other.seats == seats &&
      other.symbolKey == symbolKey;

  @override
  int get hashCode => Object.hash(seats, symbolKey);

  @override
  String toString() => 'Unnumbered($seats, $symbolKey)';
}

/// A group of tables the host merged (table-groups spec G1): in the
/// selection mode its members are framed, labelled, selected and moved as
/// one. Addressed by the host's group id, the key of
/// `FloorPlanController.setTableGroups`. Not document state: never saved,
/// exported, printed or undone.
@immutable
final class TableGroup {
  /// [members] are table numbers, each trimmed, a blank one dropped (G2).
  /// [label] is trimmed, a blank one meaning none, then cut to [maxLabel]
  /// characters (grapheme clusters, R-12).
  TableGroup({required Set<String> members, String? label})
      : members = Set.unmodifiable(<String>{
          for (final m in members)
            if (m.trim().isNotEmpty) m.trim()
        }),
        label = switch (label?.trim()) {
          null || '' => null,
          final l => l.characters.take(maxLabel).toString(),
        };

  /// The longest label, in characters.
  static const int maxLabel = 24;

  /// The member numbers, trimmed, none blank; unmodifiable. A number with
  /// no live table is kept and resolves once such a table exists (G2).
  final Set<String> members;

  /// The host's text for the group's chip, or null for its numbers (G3).
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is TableGroup &&
      other.label == label &&
      setEquals(other.members, members);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(members), label);

  @override
  String toString() => 'TableGroup($members, $label)';
}
