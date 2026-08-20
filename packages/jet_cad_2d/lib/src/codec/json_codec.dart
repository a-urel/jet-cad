import 'dart:convert';

import '../core/diagnostic.dart';
import '../core/handle.dart';
import '../document/command.dart';
import '../document/draft_document.dart';
import '../document/header.dart';
import '../document/node.dart';
import '../document/tables.dart';
import '../document/text_metrics.dart';
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
        'definitions': [
          for (final d in doc.tree.definitions)
            d.copyWith(children: doc.tree.childNodesOf(d.children)).toJson(),
        ],
        'root': doc.rootHandle.toJson(),
        'nodes': [
          for (final n in doc.tree.nodes)
            switch (n) {
              GroupNode() => n
                  .copyWith(children: doc.tree.childNodesOf(n.children))
                  .toJson(),
              InstanceNode() => n.toJson(),
            },
        ],
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

  /// [diagnostics], when supplied, receives every diagnostic import produces —
  /// currently only [DocumentTree.repairCycles]'s reports of a dropped
  /// definition-cycle back edge. The repair itself always happens; passing no
  /// list only means the caller is not told what was dropped, so a caller that
  /// needs to surface data loss to a user must pass one.
  static DraftDocument decode(
    Map<String, Object?> json, {
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all,
    int undoLimit = 200,
    List<Diagnostic>? diagnostics,
  }) {
    // Both ends, not just the future one. A declared `0`, or a negative
    // version, is not a document this package ever wrote; accepting it would
    // parse the file as v1 and only fail — if at all — somewhere deeper in,
    // with a FormatException that names a field rather than the version.
    final version = json['schemaVersion'];
    if (version is! int || version < 1 || version > kSchemaVersion) {
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
    // Not `diagnostics?.addAll(_loadTree(...))`: `?.` short-circuits on the
    // *receiver*, so with no diagnostics list that would skip calling
    // _loadTree entirely rather than merely skip recording its result.
    final treeDiagnostics = _loadTree(doc, json);
    diagnostics?.addAll(treeDiagnostics);
    _loadEntities(doc, json['entities']);

    doc.components
        .loadJson((json['components']! as Map).cast<String, Object?>());
    doc.rawData.loadJson((json['rawData']! as Map).cast<String, Object?>());
    // The file's declared seed is a floor, not the sole source of truth: every
    // handle actually read above raises the seed as it is read (see
    // _loadTables, _loadTree, _loadEntities), so a file whose declared seed
    // undercounts what it actually contains still cannot reissue a live
    // handle.
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
    List<Diagnostic>? diagnostics,
  }) =>
      decode(
        (jsonDecode(source) as Map).cast<String, Object?>(),
        measurer: measurer,
        permissions: permissions,
        undoLimit: undoLimit,
        diagnostics: diagnostics,
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
    // **Not** dead defensive code, whatever it looks like: `decode` starts
    // from `DraftDocument.empty()`, which is not empty. It seeds layer 0 at
    // handle 1, linetypes 2-4 and text style 5. Without these clears the
    // file's own copies of those records collide with the seeded ones and
    // this method throws DuplicateHandleError — on the ByLayer linetype at
    // handle 2, since linetypes load first — for every real document. Do not
    // "simplify" them away.
    doc.tables.layers.clear();
    doc.tables.linetypes.clear();
    doc.tables.textStyles.clear();
    doc.tables.patterns.clear();
    doc.tables.dimStyles.clear();
    doc.tables.appIds.clear();
    for (final r in tables['linetypes']! as List) {
      final record =
          LinetypeRecord.fromJson((r as Map).cast<String, Object?>());
      doc.tables.linetypes.add(record);
      doc.handleSeed.raiseTo(record.handle);
    }
    for (final r in tables['layers']! as List) {
      final record = LayerRecord.fromJson((r as Map).cast<String, Object?>());
      doc.tables.layers.add(record);
      doc.handleSeed.raiseTo(record.handle);
    }
    for (final r in tables['textStyles']! as List) {
      final record =
          TextStyleRecord.fromJson((r as Map).cast<String, Object?>());
      doc.tables.textStyles.add(record);
      doc.handleSeed.raiseTo(record.handle);
    }
    for (final r in tables['patterns']! as List) {
      final record = PatternRecord.fromJson((r as Map).cast<String, Object?>());
      doc.tables.patterns.add(record);
      doc.handleSeed.raiseTo(record.handle);
    }
    for (final r in tables['dimStyles']! as List) {
      final record =
          DimStyleRecord.fromJson((r as Map).cast<String, Object?>());
      doc.tables.dimStyles.add(record);
      doc.handleSeed.raiseTo(record.handle);
    }
    for (final r in tables['appIds']! as List) {
      final record = AppIdRecord.fromJson((r as Map).cast<String, Object?>());
      doc.tables.appIds.add(record);
      doc.handleSeed.raiseTo(record.handle);
    }
  }

  /// Returns whatever [DocumentTree.repairCycles] reported, for the caller to
  /// forward into its own `diagnostics` out-parameter.
  static List<Diagnostic> _loadTree(
      DraftDocument doc, Map<String, Object?> json) {
    // **Not** dead defensive code, for the same reason as in `_loadTables`:
    // `DraftDocument.empty()` seeds a synthetic root node at handle 17.
    // Without this clear that node survives into the loaded document — the
    // file's own root is a different handle, so nothing overwrites it — and
    // the next save emits a stray root nobody asked for. Do not remove it.
    doc.tree.clear();
    for (final d in json['definitions']! as List) {
      final definition = Definition.fromJson(d);
      doc.tree.addDefinition(definition);
      doc.handleSeed.raiseTo(definition.handle);
    }
    // Unchecked, then repaired: a file may contain a cycle, and import
    // diagnoses and recovers rather than failing mid-parse.
    for (final n in json['nodes']! as List) {
      final node = Node.fromJson(n);
      doc.tree.addNodeUnchecked(node);
      doc.handleSeed.raiseTo(node.handle);
    }
    final diagnostics = doc.tree.repairCycles();
    doc.tree.setRoot(Handle.fromJson(json['root']));
    return diagnostics;
  }

  static void _loadEntities(DraftDocument doc, Object? json) {
    // These two, unlike the clears in `_loadTables` and `_loadTree`, really
    // are redundant today: `DraftDocument.empty()` seeds no entities and no
    // geometry, so both stores are already empty here. They are kept so that
    // all three loaders start from the same stated precondition rather than
    // each depending on a different reading of what "empty" means.
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
      doc.handleSeed.raiseTo(record.handle);
    }
  }
}
