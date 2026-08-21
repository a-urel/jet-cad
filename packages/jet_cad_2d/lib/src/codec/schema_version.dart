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
/// and the version check at `json_codec.dart:103` is what makes it.
const int kSchemaVersion = 5;

class SchemaVersionError implements Exception {
  final Object? found;
  const SchemaVersionError(this.found);

  @override
  String toString() => found == null
      ? 'SchemaVersionError: document has no schemaVersion'
      : 'SchemaVersionError: unsupported schemaVersion $found '
          '(this build writes $kSchemaVersion)';
}
