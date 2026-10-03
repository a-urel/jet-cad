// The tables of a plan (spec 14a T1, T2, T6, T15): every live, root-level
// instance of a servable symbol, its number read from its `TABLE` label,
// and the diagnostics a plan's numbering can raise.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../symbols/seating_component.dart';
import '../symbols/symbol_component.dart';
import 'table_label.dart';

/// One table (T1, T15).
final class TableInfo {
  const TableInfo({
    required this.instance,
    required this.definition,
    required this.label,
    required this.number,
    required this.seats,
    required this.symbolKey,
  });

  final Handle instance;
  final Handle definition;

  /// The `TABLE` ATTRIB the number is read from: the lowest-handle one when
  /// there are several (T2), null when the table is unnumbered.
  final Handle? label;

  /// The label's text, trimmed; null when unnumbered.
  final String? number;

  /// The definition's [SeatingComponent] (T3).
  final int seats;

  /// The definition's [SymbolComponent] key, null for a hand-made one.
  final String? symbolKey;

  @override
  String toString() => 'TableInfo(${instance.toHex()}, $number, $seats)';
}

/// The tables and the servable instances that are not tables, in one pass.
final class TableSurvey {
  TableSurvey._(this.tables, this.nested, this.extraLabels);

  /// Live, root-level, servable instances, ascending by handle (T1).
  final List<TableInfo> tables;

  /// Servable instances not at the root: not tables in v1 (T1).
  final List<Handle> nested;

  /// Per table with several `TABLE` labels, the ones after the first.
  final Map<Handle, List<Handle>> extraLabels;

  /// O(nodes + entities). At document-change rate, never per frame.
  factory TableSurvey.of(DraftDocument doc) {
    final labels = <Handle, List<(Handle, String)>>{};
    final entities = doc.entities;
    for (final slot in entities.liveSlots) {
      if (entities.kindAt(slot) != EntityKind.attrib) continue;
      if (entities.tagAt(slot) != kTableLabelTag) continue;
      (labels[entities.ownerAt(slot)] ??= [])
          .add((entities.handleAt(slot), entities.textAt(slot)));
    }
    final tables = <TableInfo>[];
    final nested = <Handle>[];
    final extra = <Handle, List<Handle>>{};
    // `tree.nodes` is ascending by handle (its contract), so both lists
    // are too.
    for (final node in doc.tree.nodes) {
      if (node is! InstanceNode) continue;
      if (doc.tree.definition(node.definition) == null) continue;
      final seating = doc.components.get<SeatingComponent>(node.definition);
      if (seating == null) continue;
      if (node.parent != doc.rootHandle) {
        nested.add(node.handle);
        continue;
      }
      final own = labels[node.handle]
        ?..sort((a, b) => a.$1.value.compareTo(b.$1.value));
      if (own != null && own.length > 1) {
        extra[node.handle] = [for (final l in own.skip(1)) l.$1];
      }
      tables.add(TableInfo(
        instance: node.handle,
        definition: node.definition,
        label: own?.first.$1,
        number: own?.first.$2.trim(),
        seats: seating.seats,
        symbolKey: doc.components.get<SymbolComponent>(node.definition)?.key,
      ));
    }
    return TableSurvey._(List.unmodifiable(tables), List.unmodifiable(nested),
        Map.unmodifiable(extra));
  }

  /// The numbered tables carrying [number] (trimmed, exact `==`, T4).
  List<TableInfo> withNumber(String number) {
    final n = number.trim();
    return [
      for (final t in tables)
        if (t.number == n) t
    ];
  }

  /// Every number in use, one per numbered table.
  Iterable<String> get numbers => [
        for (final t in tables)
          if (t.number != null) t.number!
      ];

  /// The plan's numbering diagnostics (T15), in a stable order: duplicates
  /// by first appearance, then per table ascending.
  List<Diagnostic> diagnostics() {
    final out = <Diagnostic>[];
    final byNumber = <String, List<Handle>>{};
    for (final t in tables) {
      if (t.number != null) (byNumber[t.number!] ??= []).add(t.instance);
    }
    for (final MapEntry(key: number, value: handles) in byNumber.entries) {
      if (handles.length < 2) continue;
      out.add(Diagnostic(
        severity: DiagnosticSeverity.warning,
        code: TableDiagnosticCodes.duplicateNumber,
        message: 'Number $number is used by ${handles.length} tables',
        handles: handles,
      ));
    }
    for (final t in tables) {
      if (t.label == null) {
        out.add(Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: TableDiagnosticCodes.unnumbered,
          message: 'Table ${t.instance.toHex()} has no number',
          handles: [t.instance],
        ));
      }
      final more = extraLabels[t.instance];
      if (more != null) {
        out.add(Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: TableDiagnosticCodes.extraLabel,
          message: 'Table ${t.instance.toHex()} has ${more.length + 1} '
              'number labels; the first is used',
          handles: [t.instance, ...more],
        ));
      }
    }
    for (final h in nested) {
      out.add(Diagnostic(
        severity: DiagnosticSeverity.info,
        code: TableDiagnosticCodes.nested,
        message: '${h.toHex()} is inside a group and is not a table',
        handles: [h],
      ));
    }
    return out;
  }
}

/// The codes [TableSurvey.diagnostics] raises.
abstract final class TableDiagnosticCodes {
  static const String duplicateNumber = 'table.duplicate_number';
  static const String unnumbered = 'table.unnumbered';
  static const String extraLabel = 'table.extra_label';
  static const String nested = 'table.nested';
}

/// The live tables of [doc] (T15).
List<TableInfo> tablesOf(DraftDocument doc) => TableSurvey.of(doc).tables;

/// The numbering diagnostics of [doc] (T15).
List<Diagnostic> tableDiagnostics(DraftDocument doc) =>
    TableSurvey.of(doc).diagnostics();
