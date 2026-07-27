import 'dart:convert';

import '../core/handle.dart';
import '../document/command.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/header.dart';
import '../document/node.dart';
import '../document/tables.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'schema_version.dart';

/// Reads and writes the canonical document format.
///
/// Deterministic by construction: every `toJson` builds its map in a fixed key
/// order and every collection is emitted in ascending-handle order, so no
/// sorting happens here. The ordering discipline lives in the model, where it
/// is testable.
class DraftDocumentCodec {
  static const List<String> _knownKeys = [
    'schemaVersion',
    'header',
    'tables',
    'definitions',
    'root',
    'nodes',
    'entities',
    'components',
    'rawData',
    'handleSeed',
  ];

  static Map<String, Object?> encode(DraftDocument doc) => {
        'schemaVersion': kSchemaVersion,
        'header': doc.header.toJson(),
        'tables': {
          'layers': [for (final r in doc.tables.layers.records) r.toJson()],
          'linetypes': [
            for (final r in doc.tables.linetypes.records) r.toJson(),
          ],
          'textStyles': [
            for (final r in doc.tables.textStyles.records) r.toJson(),
          ],
          'patterns': [for (final r in doc.tables.patterns.records) r.toJson()],
          'dimStyles': [
            for (final r in doc.tables.dimStyles.records) r.toJson(),
          ],
          'appIds': [for (final r in doc.tables.appIds.records) r.toJson()],
        },
        'definitions': [for (final d in doc.tree.definitions) d.toJson()],
        'root': doc.rootHandle.toJson(),
        'nodes': [for (final n in doc.tree.nodes) n.toJson()],
        'entities': [
          // Ascending slot order, which is ascending insertion order and is
          // stable across a save/load cycle.
          for (final slot in doc.entities.liveSlots)
            {
              'record': doc.entities.read(slot).toJson(),
              // Inline, because a slot is not durable state.
              'geometry':
                  doc.geometry.read(doc.entities.geomIndexAt(slot)).toJson(),
            },
        ],
        'components': doc.components.toJson(),
        'rawData': doc.rawData.toJson(),
        'handleSeed': doc.handleSeed.current.toJson(),
        // Anything a newer build wrote, written back untouched.
        ...doc.unknownDocumentFields,
      };

  static String encodeToString(DraftDocument doc) => jsonEncode(encode(doc));

  static DraftDocument decode(
    Map<String, Object?> json, {
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) {
    final version = json['schemaVersion'];
    if (version is! int || version > kSchemaVersion) {
      throw SchemaVersionError(version);
    }

    final doc = DraftDocument.empty(
      measurer: measurer,
      permissions: permissions,
      undoLimit: undoLimit,
    );

    for (final key in json.keys) {
      if (!_knownKeys.contains(key)) doc.unknownDocumentFields[key] = json[key];
    }

    _loadHeader(doc, json['header']);
    _loadTables(doc, json['tables']);
    _loadTree(doc, json);
    _loadEntities(doc, json['entities']);

    doc.components
        .loadJson((json['components']! as Map).cast<String, Object?>());
    doc.rawData.loadJson((json['rawData']! as Map).cast<String, Object?>());
    doc.handleSeed.raiseTo(Handle.fromJson(json['handleSeed']));

    doc.invalidateDerived();
    // A loaded document has no history: the stacks describe edits to a
    // document that is now gone.
    doc.commands.notifyLoaded();
    return doc;
  }

  static DraftDocument decodeString(
    String source, {
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) =>
      decode(
        (jsonDecode(source) as Map).cast<String, Object?>(),
        measurer: measurer,
        permissions: permissions,
        undoLimit: undoLimit,
      );

  static void _loadHeader(DraftDocument doc, Object? json) {
    final header =
        DocumentHeader.fromJson((json! as Map).cast<String, Object?>());
    doc.header
      ..units = header.units
      ..scale = header.scale
      ..importedExtents = header.importedExtents
      ..customVariables.addAll(header.customVariables);
  }

  static void _loadTables(DraftDocument doc, Object? json) {
    final tables = (json! as Map).cast<String, Object?>();
    doc.tables.layers.clear();
    doc.tables.linetypes.clear();
    doc.tables.textStyles.clear();
    doc.tables.patterns.clear();
    doc.tables.dimStyles.clear();
    doc.tables.appIds.clear();
    for (final r in tables['linetypes']! as List) {
      doc.tables.linetypes
          .add(LinetypeRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['layers']! as List) {
      doc.tables.layers
          .add(LayerRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['textStyles']! as List) {
      doc.tables.textStyles
          .add(TextStyleRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['patterns']! as List) {
      doc.tables.patterns
          .add(PatternRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['dimStyles']! as List) {
      doc.tables.dimStyles
          .add(DimStyleRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['appIds']! as List) {
      doc.tables.appIds
          .add(AppIdRecord.fromJson((r as Map).cast<String, Object?>()));
    }
  }

  static void _loadTree(DraftDocument doc, Map<String, Object?> json) {
    doc.tree.clear();
    for (final d in json['definitions']! as List) {
      doc.tree.addDefinition(Definition.fromJson(d));
    }
    // Unchecked, then repaired: a file may contain a cycle, and import
    // diagnoses and recovers rather than failing mid-parse.
    for (final n in json['nodes']! as List) {
      doc.tree.addNodeUnchecked(Node.fromJson(n));
    }
    doc.tree.repairCycles();
    doc.tree.setRoot(Handle.fromJson(json['root']));
  }

  static void _loadEntities(DraftDocument doc, Object? json) {
    doc.entities.clear();
    doc.geometry.clear();
    for (final e in json! as List) {
      final entry = (e as Map).cast<String, Object?>();
      final record = EntityRecord.fromJson(entry['record']);
      final payload = GeometryPayload.fromJson(entry['geometry']);
      // The stored slot is discarded: whatever slot the payload lands in is
      // what the restored record points at.
      final geomIndex = doc.geometry.add(payload);
      doc.entities.add(record.copyWith(geomIndex: geomIndex));
    }
  }
}
