import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/cad_document.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

/// Fails snapshotBodies after [allowedSnapshots] successful calls.
class _SnapshotFailingBridge extends FakeKernelBridge {
  _SnapshotFailingBridge(this.allowedSnapshots);

  int allowedSnapshots;

  @override
  Future<KernelSnapshot> snapshotBodies(
      SessionHandle session, List<BodyId> bodies) {
    if (allowedSnapshots-- <= 0) {
      throw const KernelException('simulated snapshot failure');
    }
    return super.snapshotBodies(session, bodies);
  }
}

Future<int> _kernelBodyCount(FakeKernelBridge bridge, CadDocument doc) async {
  // saveSnapshot dumps every body in the fake session.
  final snapshot = await doc.debugSaveSnapshot();
  return (jsonDecode(utf8.decode(snapshot.bytes)) as List).length;
}

void main() {
  test('makeBox compensates when post-snapshot fails: no orphan kernel body',
      () async {
    final bridge = _SnapshotFailingBridge(0);
    final doc = await CadDocument.create(bridge);
    await expectLater(
      doc.makeBox(const Vec3(1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
    expect(doc.operations, isEmpty);
    expect(doc.entities, isEmpty);
    bridge.allowedSnapshots = 1000;
    expect(await _kernelBodyCount(bridge, doc), 0,
        reason: 'created body must be compensated away');
    await doc.dispose();
  });

  test('boolean compensates when post-snapshot fails: inputs restored',
      () async {
    // Allowed: 2 post-snapshots for the two makeBox calls, 1 pre-snapshot
    // for the boolean; the boolean's post-snapshot (4th call) fails.
    final bridge = _SnapshotFailingBridge(3);
    final doc = await CadDocument.create(bridge);
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    await expectLater(
      doc.booleanCombine(a, b, BoolOp.fuse),
      throwsA(isA<KernelException>()),
    );
    expect(doc.entities.containsKey(a), isTrue);
    expect(doc.entities.containsKey(b), isTrue);
    expect(doc.head, 2);
    bridge.allowedSnapshots = 1000;
    expect(await _kernelBodyCount(bridge, doc), 2,
        reason: 'a and b restored, boolean result deleted');
    final step = await doc.exportStep([a, b]);
    expect(step, isNotEmpty);
    await doc.dispose();
  });
}
