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
  ///
  /// A non-finite [importedExtents] is written as absent — see
  /// [_isPersistable]. The guard lives here rather than in [Aabb2.toJson]
  /// because "no imported extents" is a header concept: `Aabb2` has no null to
  /// return, and every other caller of `Aabb2.toJson` wants the four numbers
  /// whatever they are.
  Map<String, Object?> toJson() => {
        'units': units.name,
        'scale': scale,
        'importedExtents': _persistable(importedExtents)?.toJson(),
        'customVariables': {
          for (final key in customVariables.keys.toList()..sort())
            key: customVariables[key],
        },
      };

  /// Applies the same [_isPersistable] filter as [toJson], so a document
  /// loaded from a file that names a non-finite box holds exactly what the
  /// next save would write. Without the symmetry the load would keep a box
  /// that save then drops, and `save(load(x)) == save(x)` would not hold.
  static DocumentHeader fromJson(Map<String, Object?> json) {
    final header = DocumentHeader()
      ..units = DrawingUnits.values.byName(json['units']! as String)
      ..scale = (json['scale']! as num).toDouble();
    final extents = json['importedExtents'];
    if (extents != null) {
      header.importedExtents = _persistable(Aabb2.fromJson(extents));
    }
    header.customVariables
        .addAll((json['customVariables']! as Map).cast<String, Object?>());
    return header;
  }

  static Aabb2? _persistable(Aabb2? box) =>
      box != null && _isPersistable(box) ? box : null;

  /// Whether [box] can survive a JSON round trip at all.
  ///
  /// [Aabb2.empty] — the package's own factory — is inverted infinities, and
  /// `importedExtents` is a public settable field, so `header.importedExtents
  /// = doc.extents` on an empty document lands one here directly. So does a
  /// DXF importer reading an absent or degenerate `$EXTMIN`/`$EXTMAX`.
  /// `jsonEncode` has no representation for an infinity or a NaN and throws
  /// [JsonUnsupportedObjectError] on one, which would take out the whole save.
  /// Absent is the truthful answer: a box that spans nothing, or that spans
  /// everything, is not extents read from a file.
  static bool _isPersistable(Aabb2 box) =>
      box.minX.isFinite &&
      box.minY.isFinite &&
      box.maxX.isFinite &&
      box.maxY.isFinite;
}
