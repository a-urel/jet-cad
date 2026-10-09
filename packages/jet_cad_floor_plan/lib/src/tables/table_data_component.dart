// A host's data on a table (host embedding API spec E-6): string keys and
// values a host links the table to its own records by, stored with the plan
// on the table's **instance** node, so it follows the table through a move,
// a turn and a renumbering, and leaves with it on a delete (the table
// system's expander, E-9 gate 3).
//
// Internal: no handle and no component type crosses the host barrel
// (invariant 5); a host reads it as `FloorPlanTableDetail.data` and writes
// it with `FloorPlanController.setTableData`.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'dart:convert' show jsonEncode;

import 'package:jet_cad_2d/jet_cad_2d.dart';

/// At most this many keys on one table (E-6).
const int kTableDataMaxKeys = 32;

/// A key's longest length, in characters of `[a-z0-9_.-]` (E-6).
const int kTableDataMaxKeyLength = 64;

/// A value's longest length, in UTF-16 code units (E-6).
const int kTableDataMaxValueLength = 1024;

final RegExp _key = RegExp('^[a-z0-9_.-]{1,$kTableDataMaxKeyLength}\$');

/// Why [data] is outside the limits (E-6), or null when it is within them:
/// at most [kTableDataMaxKeys] keys; each key 1 to [kTableDataMaxKeyLength]
/// characters of `[a-z0-9_.-]`; each value at most
/// [kTableDataMaxValueLength] UTF-16 code units, none of them a control
/// character (the table numbers' rule, `tableNumberProblem`: below U+0020,
/// or U+007F to U+009F). An empty map is within them, and so is an empty
/// value (spec point S-6). The one test the component's constructor and the
/// controller share.
String? tableDataProblem(Map<String, String> data) {
  if (data.length > kTableDataMaxKeys) {
    return 'has ${data.length} keys; at most $kTableDataMaxKeys';
  }
  for (final MapEntry(:key, :value) in data.entries) {
    if (!_key.hasMatch(key)) {
      return 'key "$key" is not 1 to $kTableDataMaxKeyLength characters '
          'of [a-z0-9_.-]';
    }
    if (value.length > kTableDataMaxValueLength) {
      return 'the value of "$key" has ${value.length} code units; at most '
          '$kTableDataMaxValueLength';
    }
    for (final u in value.codeUnits) {
      if (u < 0x20 || (u >= 0x7F && u <= 0x9F)) {
        return 'the value of "$key" has a control character';
      }
    }
  }
  return null;
}

/// The host's data on one table (E-6): `{"data": {key: value}}`, keys
/// written sorted.
///
/// Immutable and value-equal. Made by the constructor, always within the
/// limits and never empty (an empty map is no component); or read by
/// [fromJson], which **never throws**: a payload outside the limits or of
/// another shape is [kept] verbatim, written back as read, and reads as
/// empty [data] (spec point S-2: the engine's preserve-unknown store holds
/// only unregistered types, and a throwing factory would refuse the whole
/// plan). `TableSurvey.diagnostics` reports such a table as
/// `table.invalid_data` (S-3).
final class FloorPlanTableData implements Component {
  static const String componentTypeId = 'jetcad.table_data';

  /// Registers the type. **Once per registry**: `register` replaces the
  /// store for the type, so a second call drops every live table's data.
  static void register(ComponentRegistry registry) =>
      registry.register<FloorPlanTableData>(componentTypeId, fromJson);

  /// [data], its keys sorted. Throws [ArgumentError] (not an `assert`: a
  /// release build must refuse too) when [data] is empty or outside the
  /// limits ([tableDataProblem]).
  factory FloorPlanTableData(Map<String, String> data) {
    if (data.isEmpty) {
      throw ArgumentError.value(
          data, 'data', 'is empty: an empty map is no component');
    }
    if (tableDataProblem(data) case final problem?) {
      throw ArgumentError.value(data, 'data', problem);
    }
    return FloorPlanTableData._(_sorted(data), null);
  }

  FloorPlanTableData._(this.data, this.kept)
      : _encoded = kept == null ? null : jsonEncode(kept);

  /// The table's data, its keys in ascending order; unmodifiable. Empty
  /// when the payload was [kept].
  final Map<String, String> data;

  /// The payload as read, when it was not data within the limits: written
  /// back exactly as read. Unmodifiable, all the way down. Null otherwise.
  final Map<String, Object?>? kept;

  /// [kept]'s encoding, its equality.
  final String? _encoded;

  /// Whether the payload was kept verbatim (and reads as empty [data]).
  bool get isKept => kept != null;

  @override
  String get typeId => componentTypeId;

  /// [kept] as read, or `{"data": {...}}` with the keys sorted.
  @override
  Map<String, Object?> toJson() => kept ?? {'data': data};

  /// The payload's data when it is exactly `{"data": {key: value}}`, every
  /// value a string, within the limits and not empty (re-sorted: a
  /// hand-edited file is canonicalised on its next save); otherwise the
  /// payload kept verbatim. Never throws.
  static FloorPlanTableData fromJson(Map<String, Object?> json) {
    final raw = json['data'];
    if (json.length == 1 && raw is Map && raw.isNotEmpty) {
      final data = <String, String>{};
      for (final MapEntry(:key, :value) in raw.entries) {
        if (key is! String || value is! String) return _keep(json);
        data[key] = value;
      }
      if (tableDataProblem(data) == null) {
        return FloorPlanTableData._(_sorted(data), null);
      }
    }
    return _keep(json);
  }

  static FloorPlanTableData _keep(Map<String, Object?> json) =>
      FloorPlanTableData._(
          const <String, String>{}, _frozen(json) as Map<String, Object?>);

  static Map<String, String> _sorted(Map<String, String> data) {
    final keys = data.keys.toList()..sort();
    return Map.unmodifiable({for (final k in keys) k: data[k]!});
  }

  /// A deep, unmodifiable copy of a decoded JSON value, its maps' key
  /// order kept.
  static Object? _frozen(Object? value) => switch (value) {
        Map() => Map<String, Object?>.unmodifiable({
            for (final MapEntry(:key, :value) in value.entries)
              key as String: _frozen(value),
          }),
        List() =>
          List<Object?>.unmodifiable([for (final v in value) _frozen(v)]),
        _ => value,
      };

  @override
  bool operator ==(Object other) {
    if (other is! FloorPlanTableData) return false;
    if (isKept || other.isKept) return other._encoded == _encoded;
    if (other.data.length != data.length) return false;
    for (final MapEntry(:key, :value) in data.entries) {
      if (other.data[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      _encoded?.hashCode ??
      Object.hashAll([
        for (final MapEntry(:key, :value) in data.entries) ...[key, value]
      ]);

  @override
  String toString() => isKept
      ? 'FloorPlanTableData(kept: $_encoded)'
      : 'FloorPlanTableData($data)';
}
