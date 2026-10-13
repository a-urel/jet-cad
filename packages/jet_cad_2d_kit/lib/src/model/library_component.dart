// The library component (spec K2, K3): on a library's root, the kit whose
// symbols the library holds and the library format.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'json_fields.dart';
import 'kit_ids.dart';

/// A library's kit and format, on its root.
@immutable
final class LibraryComponent implements Component {
  /// Throws [ArgumentError] when [kit] is not a kit id or [format] is below
  /// 1. A format above 1 is constructed and refused by the validator.
  LibraryComponent({required this.kit, this.format = 1}) {
    if (!isKitId(kit)) {
      throw ArgumentError.value(kit, 'kit', 'must be a kit id');
    }
    if (format < 1) {
      throw ArgumentError.value(format, 'format', 'must be at least 1');
    }
  }

  static const String componentTypeId = 'jetcad.library';

  final String kit;
  final int format;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'format': format, 'kit': kit};

  static LibraryComponent fromJson(Map<String, Object?> json) {
    const t = 'LibraryComponent';
    return LibraryComponent(
      kit: field<String>(json, 'kit', t),
      format: field<int>(json, 'format', t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryComponent && other.kit == kit && other.format == format;

  @override
  int get hashCode => Object.hash(kit, format);

  @override
  String toString() => 'LibraryComponent($kit, format $format)';
}
