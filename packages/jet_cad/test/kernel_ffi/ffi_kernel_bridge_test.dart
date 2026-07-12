import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {});
    return;
  }

  late FfiKernelBridge bridge;
  late SessionHandle session;

  setUp(() async {
    bridge = FfiKernelBridge(libPath);
    session = await bridge.createSession(const HeadlessTarget());
  });

  tearDown(() => bridge.disposeSession(session));

  test('versionInfo reports a real OCCT version', () async {
    final v = await bridge.versionInfo();
    expect(v.occtVersion, isNotEmpty);
    expect(v.kernelVersion, contains('jet_cad_native'));
  });

  test('makeBox returns real box topology', () async {
    final r = await bridge.makeBox(session, const Vec3(1, 2, 3));
    expect(r.faces, hasLength(6));
    expect(r.edges, hasLength(12));
    expect(r.vertices, hasLength(8));
  });

  test('kernel errors surface as KernelException', () async {
    await expectLater(
      bridge.makeBox(session, const Vec3(-1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
    await expectLater(
      bridge.extrude(session, const FaceId('nope'), 1),
      throwsA(isA<KernelException>()),
    );
  });

  test('boolean cut against real geometry: inputs consumed, remap total',
      () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final c = await bridge.booleanOp(session, a.body, b.body, BoolOp.fuse);
    expect(c.remap.mapping[a.body], [EntityId(c.body.value)]);
    final priorIds = 2 +
        a.faces.length +
        a.edges.length +
        a.vertices.length +
        b.faces.length +
        b.edges.length +
        b.vertices.length;
    expect(c.remap.mapping, hasLength(priorIds));
    await expectLater(
      bridge.booleanOp(session, a.body, c.body, BoolOp.cut),
      throwsA(isA<KernelException>()),
    );
  });

  test('STEP round-trip through real OCCT', () async {
    final a = await bridge.makeBox(session, const Vec3(2, 3, 4));
    final bytes = await bridge.exportStep(session, [a.body]);
    expect(utf8.decode(bytes.take(20).toList(), allowMalformed: true),
        contains('ISO-10303'));
    final imported = await bridge.importStep(session, bytes);
    expect(imported, isNotEmpty);
    expect(imported.first.faces.length, greaterThanOrEqualTo(6));
  });

  test('snapshot restore preserves ids against real kernel', () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final snap = await bridge.snapshotBodies(session, [a.body]);
    await bridge.deleteBodies(session, [a.body]);
    await expectLater(
      bridge.exportStep(session, [a.body]),
      throwsA(isA<KernelException>()),
    );
    await bridge.restoreBodies(session, snap);
    expect(await bridge.exportStep(session, [a.body]), isNotEmpty);
    final b = await bridge.makeBox(session, const Vec3(1, 1, 1));
    expect(b.body, isNot(a.body), reason: 'no id re-issue after restore');
  });

  test('commands are serialized per session (no interleaving crash)', () async {
    final futures = [
      for (var i = 0; i < 8; i++) bridge.makeBox(session, const Vec3(1, 1, 1)),
    ];
    final results = await Future.wait(futures);
    expect(results.map((r) => r.body.value).toSet(), hasLength(8));
  });

  test('full CadDocument flow runs against the real kernel', () async {
    final doc = await CadDocument.create(FfiKernelBridge(libPath));
    final a = await doc.makeBox(const Vec3(10, 10, 10));
    final b = await doc.makeBox(const Vec3(4, 4, 4));
    final c = await doc.booleanCombine(a, b, BoolOp.cut);
    final edge = doc.entities.values
        .firstWhere((e) => e.kind == EntityKind.edge && e.parent == c)
        .id as EdgeId;
    await doc.fillet([edge], 0.5);
    await doc.undo();
    await doc.redo();
    final step = await doc.exportStep([c]);
    expect(step, isNotEmpty);
    await doc.dispose();
  });

  test('commands enqueued after disposeSession throw StateError', () async {
    unawaited(bridge.disposeSession(session));
    await expectLater(
      bridge.makeBox(session, const Vec3(1, 1, 1)),
      throwsStateError,
    );
    // tearDown disposes again; disposeSession is idempotent (no-op).
  });
}
