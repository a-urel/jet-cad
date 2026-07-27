import '../geometry/aabb2.dart';

/// Drawing units, mirroring DXF `$INSUNITS` for the values this engine cares
/// about.
enum DrawingUnits { unitless, millimeters, centimeters, meters, inches, feet }

/// Document-wide stored settings.
class DocumentHeader {
  DrawingUnits units = DrawingUnits.unitless;
  double scale = 1.0;

  /// Extents exactly as they were read from an imported file, preserved so
  /// `$EXTMIN`/`$EXTMAX` survive a round-trip.
  ///
  /// This is **not** the document's working extents. Working extents are
  /// derived and recomputed, because a text entity's contribution comes from a
  /// font- and platform-dependent layout; persisting them would make the same
  /// document serialize differently on two machines and break both the
  /// determinism guarantee and the round-trip property test.
  Aabb2? importedExtents;

  /// Header variables this engine does not model, preserved verbatim.
  final Map<String, Object?> customVariables = {};

  DocumentHeader();

  /// Key order is fixed, and [customVariables] emits its keys sorted, because
  /// serialization must be byte-deterministic.
  Map<String, Object?> toJson() => {
        'units': units.name,
        'scale': scale,
        'importedExtents': importedExtents?.toJson(),
        'customVariables': {
          for (final key in customVariables.keys.toList()..sort())
            key: customVariables[key],
        },
      };

  static DocumentHeader fromJson(Map<String, Object?> json) {
    final header = DocumentHeader()
      ..units = DrawingUnits.values.byName(json['units']! as String)
      ..scale = (json['scale']! as num).toDouble();
    final extents = json['importedExtents'];
    if (extents != null) header.importedExtents = Aabb2.fromJson(extents);
    header.customVariables
        .addAll((json['customVariables']! as Map).cast<String, Object?>());
    return header;
  }
}
