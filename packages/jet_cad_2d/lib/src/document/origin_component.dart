import 'component.dart';

/// Where a handle's identity came from.
///
/// One of only two places the engine may name a foreign format; the other is
/// `GroupNode.exportAsDxfGroup`.
enum SourceKind { native, dxf, ifc }

/// The original identifier a record carried in the file it was imported from.
///
/// Renumbering handles on import silently breaks references inside preserved
/// raw data, so the original is kept rather than discarded. Export reuses it
/// when present and mints a new identifier otherwise, which is what makes
/// merging two files safe.
///
/// Registered as **internal**: it is engine bookkeeping and is never written to
/// a foreign format as extended data.
class OriginComponent implements Component {
  static const String componentTypeId = 'jetcad.origin';

  final SourceKind source;

  /// A DXF handle in hex, or an IFC GlobalId.
  final String id;

  const OriginComponent({required this.source, required this.id});

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'source': source.name, 'id': id};

  static OriginComponent fromJson(Map<String, Object?> json) => OriginComponent(
        source: SourceKind.values.byName(json['source']! as String),
        id: json['id']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is OriginComponent && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);

  @override
  String toString() => 'OriginComponent(${source.name}:$id)';
}
