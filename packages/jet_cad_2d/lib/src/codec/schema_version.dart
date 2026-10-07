/// The document schema this build writes.
///
/// Bump it whenever the on-disk shape changes, and add a migration for the
/// previous value. An unversioned document is not readable: guessing at the
/// shape of a file that never declared one is how silent corruption starts.
///
/// 4: `EntityRecord.toJson` gained `text`, `tag`, `textStyle` and
/// `textAttrs`; `EntityRecord.fromJson` defaults all four when absent, which
/// is the whole of the v3->v4 migration.
///
/// 5: `EntityKind.fill`. The JSON shape is unchanged -- a fill is an ordinary
/// entity and `kind` is written by name -- but a v4 reader must refuse a
/// document containing one rather than fail inside `EntityKind.values.byName`,
/// and the version check at `json_codec.dart:104` is what makes it.
///
/// 6: `InstanceNode.toJson` gained `lineweight`, `transparency`, `linetype`
/// and `linetypeScale`; `fromJson` defaults all four to their no-op values
/// (BYBLOCK, BYBLOCK, BYBLOCK-linetype, 1.0) when absent, which is the whole
/// of the v5->v6 migration. The bump exists for the **reader**: without it a
/// v5 build would load a v6 file, silently drop four fields, and render a
/// different drawing. With it, that build refuses the file and says why.
///
/// 7: `DocumentHeader.toJson` gained `currentLayer` (the layer new drawing
/// goes to); `fromJson` defaults it to layer 0 when absent. The same version
/// carries the `jet_cad.object_layer` component, a parametric object's layer
/// (spec 12b D2), whose absence also means layer 0. Defaulting both is the
/// whole of the v6->v7 migration. The bump exists for the reader, as 6's
/// did: without it a v6 build would load a v7 file, drop the current layer
/// and every object's layer, and draw every object on layer 0. With it, that
/// build refuses the file and says why.
///
/// 8: `PageComponent.toJson` gained `decimalSeparator`; `fromJson` defaults
/// it to `point` when absent, which is the whole of the v7->v8 migration.
/// The bump exists for the reader, as 6's and 7's did: without it a v7 build
/// would load a v8 file and drop the separator; every room or dimension an
/// edit regenerates would then print `.` beside the others' `,`. With it,
/// that build refuses the file and says why.
const int kSchemaVersion = 8;

class SchemaVersionError implements Exception {
  final Object? found;
  const SchemaVersionError(this.found);

  @override
  String toString() => found == null
      ? 'SchemaVersionError: document has no schemaVersion'
      : 'SchemaVersionError: unsupported schemaVersion $found '
          '(this build writes $kSchemaVersion)';
}
