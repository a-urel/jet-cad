import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

void main() {
  late FakeKernelBridge bridge;
  late SessionHandle session;

  setUp(() async {
    bridge = FakeKernelBridge();
    session = await bridge.createSession(const HeadlessTarget());
  });

  test('makeBox returns box topology with deterministic ids', () async {
    final r = await bridge.makeBox(session, const Vec3(1, 1, 1));
    expect(r.faces, hasLength(6));
    expect(r.edges, hasLength(12));
    expect(r.vertices, hasLength(8));
    expect(r.body.value, startsWith('b'));

    final bridge2 = FakeKernelBridge();
    final s2 = await bridge2.createSession(const HeadlessTarget());
    final r2 = await bridge2.makeBox(s2, const Vec3(1, 1, 1));
    expect(r2.body, r.body, reason: 'ids are deterministic per bridge');
  });

  test('booleanOp consumes inputs and reports remap', () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final c = await bridge.booleanOp(session, a.body, b.body, BoolOp.fuse);

    expect(c.remap.mapping[a.body], [EntityId(c.body.value)]);
    expect(c.remap.mapping[b.body], [EntityId(c.body.value)]);
    expect(c.remap.mapping[a.faces.first], isEmpty);

    await expectLater(
      bridge.booleanOp(session, a.body, c.body, BoolOp.cut),
      throwsA(isA<KernelException>()),
      reason: 'body a was consumed',
    );
  });

  test('fillet replaces edges with new faces on the same body', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final edge = box.edges.first;
    final r = await bridge.fillet(session, [edge], 0.1);
    expect(r.body, box.body);
    expect(r.faces, hasLength(1));
    expect(r.remap.mapping[edge], hasLength(1));
  });

  test('snapshot and restore preserve ids', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final snapshot = await bridge.snapshotBodies(session, [box.body]);
    await bridge.deleteBodies(session, [box.body]);
    await expectLater(
      bridge.exportStep(session, [box.body]),
      throwsA(isA<KernelException>()),
    );

    await bridge.restoreBodies(session, snapshot);
    final step = await bridge.exportStep(session, [box.body]);
    expect(step, isNotEmpty, reason: 'body restored under its original id');
  });

  test('invalid inputs throw KernelException without corrupting state',
      () async {
    await expectLater(
      bridge.extrude(session, const FaceId('nope'), 5),
      throwsA(isA<KernelException>()),
    );
    await expectLater(
      bridge.makeBox(session, const Vec3(-1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
    await expectLater(
      bridge.importStep(session, Uint8List(0)),
      throwsA(isA<KernelException>()),
    );
  });
}
