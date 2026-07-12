import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../document/entity.dart';
import 'kernel_bridge.dart';
import 'kernel_types.dart';

/// In-memory [KernelBridge] for tests and for consumers of jet_cad who need
/// to test their own document logic without a native build.
///
/// Honors the real shim's contracts: deterministic ids, remap tables from
/// every modeling op, id-preserving restore, KernelException on bad input.
/// It models topology counts only — no actual geometry.
class FakeKernelBridge implements KernelBridge {
  int _idCounter = 0;
  int _sessionCounter = 0;
  final Map<int, Map<String, _FakeBody>> _sessions = {};

  /// Every matrix passed to [transform], in call order. Lets document-layer
  /// tests assert what actually reached the kernel (e.g. undo's inverse).
  final List<Matrix4> transformLog = [];

  String _next(String prefix) => '$prefix${++_idCounter}';

  Map<String, _FakeBody> _session(SessionHandle s) =>
      _sessions[s.value] ??
      (throw KernelException('unknown session: ${s.value}'));

  _FakeBody _body(Map<String, _FakeBody> bodies, BodyId id) =>
      bodies[id.value] ?? (throw KernelException('unknown body: ${id.value}'));

  _FakeBody _newBody(Map<String, _FakeBody> bodies) {
    final body = _FakeBody(
      id: _next('b'),
      faces: [for (var i = 0; i < 6; i++) _next('f')],
      edges: [for (var i = 0; i < 12; i++) _next('e')],
      vertices: [for (var i = 0; i < 8; i++) _next('v')],
    );
    bodies[body.id] = body;
    return body;
  }

  CreateResult _result(_FakeBody b, [IdRemap remap = IdRemap.empty]) =>
      CreateResult(
        body: BodyId(b.id),
        faces: [for (final f in b.faces) FaceId(f)],
        edges: [for (final e in b.edges) EdgeId(e)],
        vertices: [for (final v in b.vertices) VertexId(v)],
        remap: remap,
      );

  @override
  Future<SessionHandle> createSession(RenderTarget target) async {
    final handle = ++_sessionCounter;
    _sessions[handle] = {};
    return SessionHandle(handle);
  }

  @override
  Future<void> disposeSession(SessionHandle session) async {
    _sessions.remove(session.value);
  }

  @override
  Future<KernelVersionInfo> versionInfo() async =>
      const KernelVersionInfo(kernelVersion: 'fake-1.0', occtVersion: 'none');

  @override
  Future<CreateResult> makeBox(SessionHandle session, Vec3 size) async {
    final bodies = _session(session);
    if (size.x <= 0 || size.y <= 0 || size.z <= 0) {
      throw const KernelException('box dimensions must be positive');
    }
    return _result(_newBody(bodies));
  }

  @override
  Future<CreateResult> extrude(
      SessionHandle session, FaceId face, double depth) async {
    final bodies = _session(session);
    final owner =
        bodies.values.where((b) => b.faces.contains(face.value)).firstOrNull;
    if (owner == null) {
      throw KernelException('unknown face: ${face.value}');
    }
    if (depth == 0) {
      throw const KernelException('extrude depth must be non-zero');
    }
    return _result(_newBody(bodies));
  }

  @override
  Future<CreateResult> booleanOp(
      SessionHandle session, BodyId a, BodyId b, BoolOp op) async {
    final bodies = _session(session);
    final bodyA = _body(bodies, a);
    final bodyB = _body(bodies, b);
    bodies.remove(a.value);
    bodies.remove(b.value);
    final result = _newBody(bodies);
    return _result(
      result,
      IdRemap({
        EntityId(bodyA.id): [EntityId(result.id)],
        EntityId(bodyB.id): [EntityId(result.id)],
        for (final sub in bodyA.subshapes.followedBy(bodyB.subshapes))
          EntityId(sub): const [],
      }),
    );
  }

  @override
  Future<CreateResult> fillet(
      SessionHandle session, List<EdgeId> edges, double radius) async {
    final bodies = _session(session);
    if (edges.isEmpty) {
      throw const KernelException('fillet needs at least one edge');
    }
    if (radius <= 0) {
      throw const KernelException('fillet radius must be positive');
    }
    final owner = bodies.values
        .where((b) => b.edges.contains(edges.first.value))
        .firstOrNull;
    if (owner == null) {
      throw KernelException('unknown edge: ${edges.first.value}');
    }
    for (final e in edges) {
      if (!owner.edges.contains(e.value)) {
        throw KernelException('edge not on body ${owner.id}: ${e.value}');
      }
    }
    final mapping = <EntityId, List<EntityId>>{};
    final newFaces = <String>[];
    for (final e in edges) {
      owner.edges.remove(e.value);
      final face = _next('f');
      owner.faces.add(face);
      newFaces.add(face);
      mapping[EntityId(e.value)] = [EntityId(face)];
    }
    return CreateResult(
      body: BodyId(owner.id),
      faces: [for (final f in newFaces) FaceId(f)],
      edges: const [],
      vertices: const [],
      remap: IdRemap(mapping),
    );
  }

  @override
  Future<void> transform(
      SessionHandle session, List<BodyId> bodies, Matrix4 matrix) async {
    final all = _session(session);
    for (final b in bodies) {
      _body(all, b);
    }
    transformLog.add(matrix.clone());
    // The fake tracks no coordinates; validation is the whole job.
  }

  @override
  Future<List<CreateResult>> importStep(
      SessionHandle session, Uint8List bytes) async {
    final bodies = _session(session);
    if (bytes.isEmpty) {
      throw const KernelException('empty STEP payload');
    }
    return [_result(_newBody(bodies))];
  }

  @override
  Future<Uint8List> exportStep(
      SessionHandle session, List<BodyId> bodies) async {
    final all = _session(session);
    for (final b in bodies) {
      _body(all, b);
    }
    final ids = [for (final b in bodies) b.value].join(',');
    return Uint8List.fromList(utf8.encode('FAKE-STEP:$ids'));
  }

  @override
  Future<Uint8List> snapshotBodies(
      SessionHandle session, List<BodyId> bodies) async {
    final all = _session(session);
    final dump = [for (final b in bodies) _body(all, b).toJson()];
    return Uint8List.fromList(utf8.encode(jsonEncode(dump)));
  }

  @override
  Future<void> restoreBodies(SessionHandle session, Uint8List snapshot) async {
    final bodies = _session(session);
    final dump = jsonDecode(utf8.decode(snapshot)) as List;
    for (final entry in dump) {
      final body = _FakeBody.fromJson((entry as Map).cast<String, Object?>());
      bodies[body.id] = body; // id-preserving by construction
    }
  }

  @override
  Future<void> deleteBodies(SessionHandle session, List<BodyId> bodies) async {
    final all = _session(session);
    for (final b in bodies) {
      all.remove(b.value);
    }
  }

  @override
  Future<KernelSnapshot> saveSnapshot(SessionHandle session) async {
    final bodies = _session(session);
    final dump = [for (final b in bodies.values) b.toJson()];
    return KernelSnapshot(Uint8List.fromList(utf8.encode(jsonEncode(dump))));
  }

  @override
  Future<void> restoreSession(
      SessionHandle session, KernelSnapshot snapshot) async {
    final bodies = _session(session)..clear();
    final dump = jsonDecode(utf8.decode(snapshot.bytes)) as List;
    for (final entry in dump) {
      final body = _FakeBody.fromJson((entry as Map).cast<String, Object?>());
      bodies[body.id] = body;
    }
  }
}

class _FakeBody {
  final String id;
  final List<String> faces;
  final List<String> edges;
  final List<String> vertices;

  _FakeBody({
    required this.id,
    required this.faces,
    required this.edges,
    required this.vertices,
  });

  Iterable<String> get subshapes =>
      faces.followedBy(edges).followedBy(vertices);

  Map<String, Object?> toJson() =>
      {'id': id, 'faces': faces, 'edges': edges, 'vertices': vertices};

  factory _FakeBody.fromJson(Map<String, Object?> json) => _FakeBody(
        id: json['id']! as String,
        faces: List<String>.from(json['faces']! as List),
        edges: List<String>.from(json['edges']! as List),
        vertices: List<String>.from(json['vertices']! as List),
      );
}
