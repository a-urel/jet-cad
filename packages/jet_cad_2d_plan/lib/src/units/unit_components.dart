// A host's data and colour on a unit (spec 2b S2 "Per-unit data"), on the
// unit's **instance** node, placed or generated: ported from
// jet_cad_floor_plan's table_data_component.dart and
// table_color_component.dart. A generated unit keeps both while it keeps
// its handle (E5) and loses them when its row drops it.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d`, the
// kit's swatch and `unit_label.dart` only.
import 'dart:convert' show jsonEncode;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show PlanSwatch, planSwatchNamed;

import 'unit_label.dart' show isControlCodeUnit;

/// At most this many keys on one unit (E-6).
const int kUnitDataMaxKeys = 32;

/// A key's longest length, in characters of `[a-z0-9_.-]` (E-6).
const int kUnitDataMaxKeyLength = 64;

/// A value's longest length, in UTF-16 code units (E-6).
const int kUnitDataMaxValueLength = 1024;

final RegExp _key = RegExp('^[a-z0-9_.-]{1,$kUnitDataMaxKeyLength}\$');

/// Why [data] is outside the limits (E-6), or null when it is within them:
/// at most [kUnitDataMaxKeys] keys; each key 1 to [kUnitDataMaxKeyLength]
/// characters of `[a-z0-9_.-]`; each value at most
/// [kUnitDataMaxValueLength] UTF-16 code units, none of them a control
/// character ([isControlCodeUnit], the unit labels' rule: below U+0020,
/// or U+007F to U+009F). An empty map is within them, and so is an empty
/// value (spec point S-6). The one test the component's constructor and the
/// controller share.
String? unitDataProblem(Map<String, String> data) {
  if (data.length > kUnitDataMaxKeys) {
    return 'has ${data.length} keys; at most $kUnitDataMaxKeys';
  }
  for (final MapEntry(:key, :value) in data.entries) {
    if (!_key.hasMatch(key)) {
      return 'key "$key" is not 1 to $kUnitDataMaxKeyLength characters '
          'of [a-z0-9_.-]';
    }
    if (value.length > kUnitDataMaxValueLength) {
      return 'the value of "$key" has ${value.length} code units; at most '
          '$kUnitDataMaxValueLength';
    }
    if (value.codeUnits.any(isControlCodeUnit)) {
      return 'the value of "$key" has a control character';
    }
  }
  return null;
}

/// The host's data on one unit (E-6): `{"data": {key: value}}`, keys
/// written sorted.
///
/// Immutable and value-equal. Made by the constructor, always within the
/// limits and never empty (an empty map is no component); or read by
/// [fromJson], which **never throws**: a payload outside the limits or of
/// another shape is [kept] verbatim, written back as read, and reads as
/// empty [data] (spec point S-2: the engine's preserve-unknown store holds
/// only unregistered types, and a throwing factory would refuse the whole
/// plan). `UnitIndex.diagnostics` reports such a unit as
/// `unit.invalid_data` (S-3).
final class UnitData implements Component {
  static const String componentTypeId = 'jetcad.unit_data';

  /// [data], its keys sorted. Throws [ArgumentError] (not an `assert`: a
  /// release build must refuse too) when [data] is empty or outside the
  /// limits ([unitDataProblem]).
  factory UnitData(Map<String, String> data) {
    if (data.isEmpty) {
      throw ArgumentError.value(
          data, 'data', 'is empty: an empty map is no component');
    }
    if (unitDataProblem(data) case final problem?) {
      throw ArgumentError.value(data, 'data', problem);
    }
    return UnitData._(_sorted(data), null);
  }

  UnitData._(this.data, this.kept)
      : _encoded = kept == null ? null : jsonEncode(kept);

  /// The unit's data, its keys in ascending order; unmodifiable. Empty
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
  static UnitData fromJson(Map<String, Object?> json) {
    final raw = json['data'];
    if (json.length == 1 && raw is Map && raw.isNotEmpty) {
      final data = <String, String>{};
      for (final MapEntry(:key, :value) in raw.entries) {
        if (key is! String || value is! String) return _keep(json);
        data[key] = value;
      }
      if (unitDataProblem(data) == null) {
        return UnitData._(_sorted(data), null);
      }
    }
    return _keep(json);
  }

  static UnitData _keep(Map<String, Object?> json) => UnitData._(
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
    if (other is! UnitData) return false;
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
  String toString() => isKept ? 'UnitData(kept: $_encoded)' : 'UnitData($data)';
}

/// The colour of one unit (PC-4): `{"color": name}`.
///
/// Immutable and value-equal. Made by the constructor from a palette entry;
/// or read by [fromJson], which **never throws**: a payload of another shape
/// than `{"color": String}` is [kept] verbatim and written back as read
/// (the engine's preserve-unknown store holds only unregistered types, and
/// a throwing factory would refuse the whole plan), and a name this release
/// does not know is stored as read in [name] and reads as no [swatch].
/// `UnitIndex.diagnostics` reports both as `unit.invalid_colour`.
final class UnitColour implements Component {
  static const String componentTypeId = 'jetcad.unit_colour';

  /// The colour [swatch], stored by its name (never its index: a palette
  /// reordered or extended breaks no file).
  UnitColour(PlanSwatch swatch) : this._(swatch.name, null);

  UnitColour._(this.name, this.kept)
      : _encoded = jsonEncode(kept ?? {'color': name});

  /// The stored name: a palette entry's, or a name this release does not
  /// know, as read. Null when the payload was [kept].
  final String? name;

  /// The payload as read, when it was not `{"color": String}`: written back
  /// exactly as read. Unmodifiable, all the way down. Null otherwise.
  final Map<String, Object?>? kept;

  /// The payload's encoding, its equality.
  final String _encoded;

  /// Whether the payload was kept verbatim (and reads as no colour).
  bool get isKept => kept != null;

  /// The palette entry named [name]; null when the payload was [kept] or
  /// the name is not one this release knows.
  PlanSwatch? get swatch => planSwatchNamed(name);

  @override
  String get typeId => componentTypeId;

  /// [kept] as read, or `{"color": name}`.
  @override
  Map<String, Object?> toJson() => kept ?? {'color': name};

  /// The payload's colour when it is exactly `{"color": String}`, whatever
  /// the string; otherwise the payload kept verbatim. Never throws.
  static UnitColour fromJson(Map<String, Object?> json) {
    final raw = json['color'];
    if (json.length == 1 && raw is String) {
      return UnitColour._(raw, null);
    }
    return UnitColour._(null, _frozen(json) as Map<String, Object?>);
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
  bool operator ==(Object other) =>
      other is UnitColour && other._encoded == _encoded;

  @override
  int get hashCode => _encoded.hashCode;

  @override
  String toString() => 'UnitColour($_encoded)';
}

/// Registers [UnitData] and [UnitColour]. **Once per registry**: a second
/// registration replaces the stores and drops every unit's data and
/// colour.
void registerUnitComponents(ComponentRegistry registry) {
  registry.register<UnitData>(UnitData.componentTypeId, UnitData.fromJson);
  registry.register<UnitColour>(
      UnitColour.componentTypeId, UnitColour.fromJson);
}
