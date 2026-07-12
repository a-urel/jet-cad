import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

/// Contract every KernelBridge implementation must satisfy.
void runKernelBridgeContract(KernelBridge Function() createBridge) {
  late KernelBridge bridge;
  late SessionHandle session;

  setUp(() async {
    bridge = createBridge();
    session = await bridge.createSession(const HeadlessTarget());
  });

  tearDown(() => bridge.disposeSession(session));

  test('contract: commands on an unknown session fail as KernelException',
      () async {
    await expectLater(
      bridge.makeBox(const SessionHandle(999999), const Vec3(1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
  });

  test('contract: makeBox produces a body with subshapes and unique ids',
      () async {
    final r = await bridge.makeBox(session, const Vec3(1, 2, 3));
    final all = <String>{
      r.body.value,
      ...r.faces.map((f) => f.value),
      ...r.edges.map((e) => e.value),
      ...r.vertices.map((v) => v.value),
    };
    expect(all.length, 1 + r.faces.length + r.edges.length + r.vertices.length);
    expect(r.faces, isNotEmpty);
    expect(r.edges, isNotEmpty);
  });

  test('contract: boolean consumes inputs, remap covers all prior ids',
      () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final c = await bridge.booleanOp(session, a.body, b.body, BoolOp.fuse);
    final prior = <EntityId>{
      a.body,
      b.body,
      ...a.faces,
      ...a.edges,
      ...a.vertices,
      ...b.faces,
      ...b.edges,
      ...b.vertices,
    };
    expect(c.remap.mapping.keys.toSet(), prior);
    expect(c.remap.mapping[a.body], isNotEmpty);
    await expectLater(
      bridge.exportStep(session, [a.body]),
      throwsA(isA<KernelException>()),
    );
  });

  test('contract: fillet keeps body id and maps each edge to >=1 new face',
      () async {
    final box = await bridge.makeBox(session, const Vec3(10, 10, 10));
    final edge = box.edges.first;
    final r = await bridge.fillet(session, [edge], 0.5);
    expect(r.body, box.body);
    expect(r.remap.mapping[edge], isNotEmpty);
    expect(r.faces, isNotEmpty);
  });

  test('contract: fillet result subshapes are consistent', () async {
    final box = await bridge.makeBox(session, const Vec3(10, 10, 10));
    final edge = box.edges.first;
    final r = await bridge.fillet(session, [edge], 0.5);
    expect(r.faces, isNotEmpty);
    // Everything the kernel reports as newly created/present in the result
    // must be a live subshape, not something the remap says was consumed:
    // no id returned in faces/edges/vertices should also be a remap key
    // (a remap key names an OLD id that no longer resolves).
    final resultIds = <EntityId>{...r.faces, ...r.edges, ...r.vertices};
    for (final id in resultIds) {
      expect(r.remap.mapping.keys, isNot(contains(id)));
    }
  });

  test('contract: rigid transform succeeds; scale is rejected', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    // Pure translation: rigid, must succeed.
    final translation = Matrix4.identity()
      ..translateByVector3(Vector3(5, 0, 0));
    await bridge.transform(session, [box.body], translation);
    // Anisotropic scale diag(2,1,1): not rigid, must be rejected.
    final scale = Matrix4.identity()..scaleByVector3(Vector3(2, 1, 1));
    await expectLater(
      bridge.transform(session, [box.body], scale),
      throwsA(isA<KernelException>()),
    );
  });

  test('contract: boolean common produces a result body', () async {
    final a = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final c = await bridge.booleanOp(session, a.body, b.body, BoolOp.common);
    expect(c.body.value, isNotEmpty);
    expect(c.remap.mapping[a.body], isNotEmpty);
    expect(c.remap.mapping[b.body], isNotEmpty);
  });

  test('contract: snapshotBodies/restoreBodies is id-preserving', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final snap = await bridge.snapshotBodies(session, [box.body]);
    await bridge.deleteBodies(session, [box.body]);
    await bridge.restoreBodies(session, snap);
    expect(await bridge.exportStep(session, [box.body]), isNotEmpty);
  });

  test('contract: saveSnapshot/restoreSession round-trips a whole session',
      () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final snapshot = await bridge.saveSnapshot(session);

    final second = createBridge();
    final s2 = await second.createSession(const HeadlessTarget());
    await second.restoreSession(s2, snapshot);
    expect(await second.exportStep(s2, [a.body, b.body]), isNotEmpty);
    final c = await second.makeBox(s2, const Vec3(3, 3, 3));
    expect(c.body, isNot(a.body));
    expect(c.body, isNot(b.body));
    await second.disposeSession(s2);
  });

  test('contract: deleteBodies is idempotent', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    await bridge.deleteBodies(session, [box.body]);
    await bridge.deleteBodies(session, [box.body]); // no throw
  });

  test('contract: fillet mints non-empty edges and vertices', () async {
    final box = await bridge.makeBox(session, const Vec3(10, 10, 10));
    final result = await bridge.fillet(session, [box.edges.first], 1.0);
    expect(result.edges, isNotEmpty,
        reason: 'fillet creates new arc edges on the rounded surface');
    expect(result.vertices, isNotEmpty,
        reason: 'fillet creates new vertices on the rounded surface');
  });

  test('contract: concurrent disposeSession calls both complete', () async {
    final s = await bridge.createSession(const HeadlessTarget());
    final first = bridge.disposeSession(s);
    final second = bridge.disposeSession(s);
    await Future.wait([first, second]);
    await expectLater(
      bridge.makeBox(s, const Vec3(1, 1, 1)),
      throwsA(anyOf(isA<KernelException>(), isA<StateError>())),
    );
  });
}
