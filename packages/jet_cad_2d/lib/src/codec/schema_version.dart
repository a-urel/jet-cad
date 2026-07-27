/// The document schema this build writes.
///
/// Bump it whenever the on-disk shape changes, and add a migration for the
/// previous value. An unversioned document is not readable: guessing at the
/// shape of a file that never declared one is how silent corruption starts.
const int kSchemaVersion = 1;

class SchemaVersionError implements Exception {
  final Object? found;
  const SchemaVersionError(this.found);

  @override
  String toString() => found == null
      ? 'SchemaVersionError: document has no schemaVersion'
      : 'SchemaVersionError: unsupported schemaVersion $found '
          '(this build writes $kSchemaVersion)';
}
