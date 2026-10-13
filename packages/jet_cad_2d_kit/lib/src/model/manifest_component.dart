// The plan manifest (spec K2, umbrella A8): on a plan's root, the plan
// format and, per kit the plan uses, the version that last saved it.
// Defined here; the plan library writes and checks it (sub-project 2).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:collection';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'json_fields.dart';
import 'kit_ids.dart';

/// A plan's format and its kits' versions, on its root.
@immutable
final class ManifestComponent implements Component {
  /// Throws [ArgumentError] when [format] is below 1, a key of [kits] is not
  /// a kit id or a version is empty. [kits] is copied, sorted by kit id.
  ManifestComponent({this.format = 1, required Map<String, String> kits})
      : kits = Map.unmodifiable(SplayTreeMap<String, String>.of(kits)) {
    if (format < 1) {
      throw ArgumentError.value(format, 'format', 'must be at least 1');
    }
    for (final MapEntry(:key, :value) in this.kits.entries) {
      if (!isKitId(key)) {
        throw ArgumentError.value(key, 'kits', 'names a kit id it is not');
      }
      if (value.trim().isEmpty) {
        throw ArgumentError.value(
            value, 'kits', 'gives the kit "$key" an empty version');
      }
    }
  }

  static const String componentTypeId = 'jetcad.manifest';

  final int format;

  /// Kit id → the kit's version that last saved the plan, sorted by id.
  final Map<String, String> kits;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'format': format,
        'kits': {...kits}
      };

  static ManifestComponent fromJson(Map<String, Object?> json) {
    const t = 'ManifestComponent';
    final raw = field<Map<Object?, Object?>>(json, 'kits', t);
    final kits = <String, String>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (key is! String || value is! String) {
        throw FormatException('$t: "kits" maps $key to $value; both must be '
            'strings');
      }
      kits[key] = value;
    }
    return ManifestComponent(format: field<int>(json, 'format', t), kits: kits);
  }

  @override
  bool operator ==(Object other) {
    if (other is! ManifestComponent ||
        other.format != format ||
        other.kits.length != kits.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in kits.entries) {
      if (other.kits[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      format,
      Object.hashAll(
          [for (final e in kits.entries) Object.hash(e.key, e.value)]));

  @override
  String toString() => 'ManifestComponent(format $format, $kits)';
}
