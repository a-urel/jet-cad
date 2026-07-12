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
}
