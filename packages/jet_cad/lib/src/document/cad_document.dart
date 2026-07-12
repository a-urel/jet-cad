import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../kernel/kernel_bridge.dart';
import '../kernel/kernel_types.dart';
import 'codec.dart';
import 'doc_change.dart';
import 'entity.dart';
import 'operation.dart';
import 'undo.dart';

/// The semantic CAD document: entities, operation timeline, undo/redo.
/// Pure Dart — geometry lives on the other side of [KernelBridge].
///
/// State is defined by operations[0..head). One document owns exactly one
/// kernel session (spec contract); [dispose] releases it.
class CadDocument {
  CadDocument._(this._bridge, this._session, this._versions);

  final KernelBridge _bridge;
  final SessionHandle _session;
  final KernelVersionInfo _versions;

  final Map<EntityId, Entity> _entities = {};
  final List<Operation> _ops = [];
  int _head = 0;
  int _undoFloor = 0;
  int _nextOpId = 1;
  final Map<String, int> _nameCounters = {};

  static const int maxUndoDepth = 50;
  final Map<OpId, UndoRecord> _undoRecords = {};

  final StreamController<DocChange> _changes =
      StreamController<DocChange>.broadcast();

  static Future<CadDocument> create(KernelBridge bridge) async {
    final session = await bridge.createSession(const HeadlessTarget());
    final versions = await bridge.versionInfo();
    return CadDocument._(bridge, session, versions);
  }

  /// Restores document state from [CadDocumentCodec.encode] (or [save])
  /// output.
  ///
  /// When a `geometry` blob is present (written by [save]), the kernel
  /// session is restored from it via `restoreSession` — ids line up with the
  /// stored entities by the id-preserving restore contract. When absent and
  /// there are ops to replay, v1 has no fallback (true op replay is a
  /// parametric-phase feature) and this throws [StateError]. When absent
  /// with no ops, an empty document is returned unchanged.
  ///
  /// Pre-load operations are not undoable: [UndoRecord]s are in-memory only
  /// and don't survive persistence.
  ///
  /// Does not emit DocumentLoaded: no listener can exist before this factory
  /// returns. The event type is reserved for future non-factory load paths
  /// (Plan 2 restoreSession wiring).
  static Future<CadDocument> load(
      Map<String, Object?> json, KernelBridge bridge) async {
    final schema = json['schemaVersion'];
    if (schema != CadDocumentCodec.schemaVersion) {
      throw FormatException('unsupported schema version: $schema');
    }
    final entitiesJson = json['entities'];
    if (entitiesJson is! List) {
      throw FormatException(
          'entities must be a list, got: ${entitiesJson.runtimeType}');
    }
    final opsJson = json['ops'];
    if (opsJson is! List) {
      throw FormatException('ops must be a list, got: ${opsJson.runtimeType}');
    }
    final headJson = json['head'];
    if (headJson is! int) {
      throw FormatException(
          'head must be an int, got: ${headJson.runtimeType}');
    }
    if (headJson < 0 || headJson > opsJson.length) {
      throw FormatException(
          'head ($headJson) out of range for ${opsJson.length} ops');
    }

    final doc = await create(bridge);
    try {
      var i = 0;
      for (final e in entitiesJson) {
        try {
          final entity = Entity.fromJson((e as Map).cast<String, Object?>());
          doc._entities[entity.id] = entity;
        } catch (err) {
          throw FormatException(
              'corrupt document: bad entity at index $i: $err');
        }
        i++;
      }
      i = 0;
      var maxOpId = 0;
      for (final o in opsJson) {
        try {
          final op = Operation.fromJson((o as Map).cast<String, Object?>());
          doc._ops.add(op);
          if (op.id.value > maxOpId) maxOpId = op.id.value;
        } catch (err) {
          throw FormatException('corrupt document: bad op at index $i: $err');
        }
        i++;
      }
      doc._head = headJson;
      doc._undoFloor = doc._head;
      doc._nextOpId = maxOpId + 1;

      final geometry = json['geometry'];
      if (geometry != null) {
        await bridge.restoreSession(
            doc._session, KernelSnapshot(base64Decode(geometry as String)));
      } else if (doc._ops.isNotEmpty) {
        throw StateError(
            'document has no geometry blob; op replay is not supported in '
            'v1 (save() embeds geometry — use it)');
      }
      return doc;
    } catch (_) {
      await doc.dispose();
      rethrow;
    }
  }

  /// Full persisted form: document state plus the kernel geometry blob.
  /// Pass the result to [load] to restore both the document and the kernel
  /// session that produced it.
  Future<Map<String, Object?>> save() async {
    final snapshot = await _bridge.saveSnapshot(_session);
    return {
      ...CadDocumentCodec.encode(this),
      'geometry': base64Encode(snapshot.bytes),
    };
  }

  Map<EntityId, Entity> get entities => UnmodifiableMapView(_entities);
  List<Operation> get operations => UnmodifiableListView(_ops);
  int get head => _head;
  bool get canUndo => _head > _undoFloor;
  bool get canRedo =>
      _head < _ops.length && _undoRecords.containsKey(_ops[_head].id);
  Stream<DocChange> get changes => _changes.stream;
  KernelVersionInfo get kernelVersions => _versions;

  Future<void> dispose() async {
    await _bridge.disposeSession(_session);
    await _changes.close();
  }

  /// Snapshot after a mutating kernel call; if the snapshot itself fails,
  /// roll the kernel back (best effort) so kernel and document never
  /// diverge, then rethrow.
  Future<KernelSnapshot> _snapshotOrCompensate(
    List<BodyId> bodies, {
    required Future<void> Function() compensate,
  }) async {
    try {
      return await _bridge.snapshotBodies(_session, bodies);
    } catch (_) {
      try {
        await compensate();
      } catch (_) {
        // Best effort: the original error is the one that matters.
      }
      rethrow;
    }
  }

  /// Whole-session kernel snapshot. Used by persistence (Task 9) and tests.
  Future<KernelSnapshot> debugSaveSnapshot() => _bridge.saveSnapshot(_session);

  OpId _newOpId() => OpId(_nextOpId++);

  String _nextName(String base) {
    final n = (_nameCounters[base] ?? 0) + 1;
    _nameCounters[base] = n;
    return '$base $n';
  }

  void _requireEntity(EntityId id, EntityKind kind) {
    final entity = _entities[id];
    if (entity == null) {
      throw ArgumentError('unknown entity: ${id.value}');
    }
    if (entity.kind != kind) {
      throw ArgumentError(
          'entity ${id.value} is a ${entity.kind.name}, expected a ${kind.name}');
    }
  }

  UndoRecord _requireUndoRecord(Operation op) {
    final record = _undoRecords[op.id];
    if (record == null) {
      throw StateError('no undo record for operation ${op.id.value}');
    }
    return record;
  }

  Map<EntityId, Entity> _entitiesFor(CreateResult r, String bodyName) => {
        r.body: Entity(id: r.body, kind: EntityKind.body, name: bodyName),
        for (final f in r.faces)
          f: Entity(id: f, kind: EntityKind.face, name: 'Face', parent: r.body),
        for (final e in r.edges)
          e: Entity(id: e, kind: EntityKind.edge, name: 'Edge', parent: r.body),
        for (final v in r.vertices)
          v: Entity(
              id: v, kind: EntityKind.vertex, name: 'Vertex', parent: r.body),
      };

  void _commit(
    Operation op,
    UndoRecord record, {
    required Map<EntityId, Entity> added,
    required List<EntityId> removed,
  }) {
    // A new operation while head < ops.length truncates the redo branch.
    if (_head < _ops.length) {
      for (final dropped in _ops.sublist(_head)) {
        _undoRecords.remove(dropped.id);
      }
      _ops.removeRange(_head, _ops.length);
    }
    for (final id in removed) {
      _entities.remove(id);
    }
    _entities.addAll(added);
    _ops.add(op);
    _head++;
    _undoRecords[op.id] = record;
    _enforceUndoBound();
    if (removed.isNotEmpty) _changes.add(EntitiesRemoved(removed));
    if (added.isNotEmpty) _changes.add(EntitiesAdded(added.keys.toList()));
    _changes.add(OperationCommitted(op));
  }

  void _enforceUndoBound() {
    // Called right after commit, so any redo-branch records were already
    // dropped by truncation: every record belongs to ops[_undoFloor.._head).
    // Evicting from the floor is therefore O(1) — never scan _ops here
    // (a scan makes every commit O(n) and the timeline O(n^2)).
    while (_undoRecords.length > maxUndoDepth && _undoFloor < _head) {
      _undoRecords.remove(_ops[_undoFloor].id);
      _undoFloor++;
    }
  }

  Future<BodyId> makeBox(Vec3 size) async {
    final result = await _bridge.makeBox(_session, size);
    final post = await _snapshotOrCompensate(
      [result.body],
      compensate: () => _bridge.deleteBodies(_session, [result.body]),
    );
    final added = _entitiesFor(result, _nextName('Box'));
    _commit(
      MakeBoxOp(
        id: _newOpId(),
        size: size,
        outputs: [result.body],
        remap: result.remap,
      ),
      UndoRecord(
        postSnapshot: post,
        postBodies: [result.body],
        entitiesAfter: added,
      ),
      added: added,
      removed: const [],
    );
    return result.body;
  }

  Future<BodyId> extrude(FaceId face, double depth) async {
    _requireEntity(face, EntityKind.face);
    final result = await _bridge.extrude(_session, face, depth);
    final post = await _snapshotOrCompensate(
      [result.body],
      compensate: () => _bridge.deleteBodies(_session, [result.body]),
    );
    final added = _entitiesFor(result, _nextName('Extrude'));
    _commit(
      ExtrudeOp(
        id: _newOpId(),
        face: face,
        depth: depth,
        outputs: [result.body],
        remap: result.remap,
      ),
      UndoRecord(
        postSnapshot: post,
        postBodies: [result.body],
        entitiesAfter: added,
      ),
      added: added,
      removed: const [],
    );
    return result.body;
  }

  Future<BodyId> booleanCombine(BodyId a, BodyId b, BoolOp op) async {
    _requireEntity(a, EntityKind.body);
    _requireEntity(b, EntityKind.body);
    if (a == b) {
      throw ArgumentError('boolean operands must be distinct bodies');
    }
    final pre = await _bridge.snapshotBodies(_session, [a, b]);
    final result = await _bridge.booleanOp(_session, a, b, op);
    final post = await _snapshotOrCompensate(
      [result.body],
      compensate: () async {
        await _bridge.deleteBodies(_session, [result.body]);
        await _bridge.restoreBodies(_session, pre);
      },
    );
    final removed = result.remap.mapping.keys.toList();
    final before = <EntityId, Entity>{
      for (final id in removed)
        if (_entities[id] != null) id: _entities[id]!,
    };
    final added = _entitiesFor(result, _nextName('Boolean'));
    _commit(
      BooleanCombineOp(
        id: _newOpId(),
        a: a,
        b: b,
        op: op,
        outputs: [result.body],
        remap: result.remap,
      ),
      UndoRecord(
        preSnapshot: pre,
        preBodies: [a, b],
        postSnapshot: post,
        postBodies: [result.body],
        entitiesBefore: before,
        entitiesAfter: added,
      ),
      added: added,
      removed: removed,
    );
    return result.body;
  }

  Future<List<FaceId>> fillet(List<EdgeId> edges, double radius) async {
    if (edges.isEmpty) {
      throw ArgumentError('fillet needs at least one edge');
    }
    for (final e in edges) {
      _requireEntity(e, EntityKind.edge);
    }
    final body = _entities[edges.first]!.parent!;
    for (final e in edges) {
      if (_entities[e]!.parent != body) {
        throw ArgumentError('fillet edges must belong to a single body');
      }
    }
    final pre = await _bridge.snapshotBodies(_session, [body]);
    final result = await _bridge.fillet(_session, edges, radius);
    final post = await _snapshotOrCompensate(
      [result.body],
      compensate: () async {
        await _bridge.deleteBodies(_session, [result.body]);
        await _bridge.restoreBodies(_session, pre);
      },
    );
    final removed = result.remap.mapping.keys.toList();
    final before = <EntityId, Entity>{
      for (final id in removed)
        if (_entities[id] != null) id: _entities[id]!,
    };
    // The real kernel's fillet doesn't just create new faces — it also
    // introduces new edges and vertices where the rounded surface meets the
    // rest of the body. Kernel subshapes without a matching Entity are
    // unselectable, so all three kinds must be materialized here.
    final added = <EntityId, Entity>{
      for (final f in result.faces)
        f: Entity(
            id: f, kind: EntityKind.face, name: 'Face', parent: result.body),
      for (final e in result.edges)
        e: Entity(
            id: e, kind: EntityKind.edge, name: 'Edge', parent: result.body),
      for (final v in result.vertices)
        v: Entity(
            id: v,
            kind: EntityKind.vertex,
            name: 'Vertex',
            parent: result.body),
    };
    _commit(
      FilletOp(
        id: _newOpId(),
        edges: edges,
        radius: radius,
        outputs: [
          result.body,
          ...result.faces,
          ...result.edges,
          ...result.vertices,
        ],
        remap: result.remap,
      ),
      UndoRecord(
        preSnapshot: pre,
        preBodies: [body],
        postSnapshot: post,
        postBodies: [result.body],
        entitiesBefore: before,
        entitiesAfter: added,
      ),
      added: added,
      removed: removed,
    );
    return result.faces;
  }

  Future<void> transform(List<BodyId> bodies, Matrix4 matrix) async {
    for (final b in bodies) {
      _requireEntity(b, EntityKind.body);
    }
    if (matrix.determinant().abs() < 1e-12) {
      throw ArgumentError('transform matrix must be invertible');
    }
    await _bridge.transform(_session, bodies, matrix);
    _commit(
      TransformOp(
        id: _newOpId(),
        bodies: bodies,
        matrix: matrix,
        outputs: List<EntityId>.from(bodies),
        remap: IdRemap.empty,
      ),
      const UndoRecord(),
      added: const {},
      removed: const [],
    );
  }

  Future<List<BodyId>> importStep(Uint8List bytes) async {
    final results = await _bridge.importStep(_session, bytes);
    final bodyIds = [for (final r in results) r.body];
    final post = await _snapshotOrCompensate(
      bodyIds,
      compensate: () => _bridge.deleteBodies(_session, bodyIds),
    );
    final added = <EntityId, Entity>{
      for (final r in results) ..._entitiesFor(r, _nextName('Import')),
    };
    _commit(
      ImportStepOp(
        id: _newOpId(),
        stepBytes: bytes,
        outputs: List<EntityId>.from(bodyIds),
        remap: IdRemap.empty,
      ),
      UndoRecord(
        postSnapshot: post,
        postBodies: bodyIds,
        entitiesAfter: added,
      ),
      added: added,
      removed: const [],
    );
    return bodyIds;
  }

  Future<Uint8List> exportStep(List<BodyId> bodies) async {
    for (final b in bodies) {
      _requireEntity(b, EntityKind.body);
    }
    return await _bridge.exportStep(_session, bodies);
  }

  Future<void> undo() async {
    if (!canUndo) {
      throw StateError('nothing to undo');
    }
    final op = _ops[_head - 1];
    final record = _requireUndoRecord(op);
    if (op is TransformOp) {
      await _bridge.transform(_session, op.bodies, Matrix4.inverted(op.matrix));
    } else {
      if (record.postBodies.isNotEmpty) {
        await _bridge.deleteBodies(_session, record.postBodies);
      }
      if (record.preSnapshot != null) {
        await _bridge.restoreBodies(_session, record.preSnapshot!);
      }
    }
    final removed = record.entitiesAfter.keys.toList();
    for (final id in removed) {
      _entities.remove(id);
    }
    _entities.addAll(record.entitiesBefore);
    _head--;
    if (removed.isNotEmpty) _changes.add(EntitiesRemoved(removed));
    if (record.entitiesBefore.isNotEmpty) {
      _changes.add(EntitiesAdded(record.entitiesBefore.keys.toList()));
    }
    _changes.add(UndoPerformed(op));
  }

  Future<void> redo() async {
    if (!canRedo) {
      throw StateError('nothing to redo');
    }
    final op = _ops[_head];
    final record = _requireUndoRecord(op);
    if (op is TransformOp) {
      await _bridge.transform(_session, op.bodies, op.matrix);
    } else {
      if (record.preBodies.isNotEmpty) {
        await _bridge.deleteBodies(_session, record.preBodies);
      }
      if (record.postSnapshot != null) {
        await _bridge.restoreBodies(_session, record.postSnapshot!);
      }
    }
    final removed = record.entitiesBefore.keys.toList();
    for (final id in removed) {
      _entities.remove(id);
    }
    _entities.addAll(record.entitiesAfter);
    _head++;
    if (removed.isNotEmpty) _changes.add(EntitiesRemoved(removed));
    if (record.entitiesAfter.isNotEmpty) {
      _changes.add(EntitiesAdded(record.entitiesAfter.keys.toList()));
    }
    _changes.add(RedoPerformed(op));
  }
}
