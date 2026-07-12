import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/cad_document.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  late FakeKernelBridge bridge;
  late CadDocument doc;

  setUp(() async {
    bridge = FakeKernelBridge();
    doc = await CadDocument.create(bridge);
  });

  tearDown(() => doc.dispose());

  test('undo/redo of makeBox restores the same ids', () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    expect(doc.canUndo, isTrue);

    await doc.undo();
    expect(doc.head, 0);
    expect(doc.entities, isEmpty);
    expect(doc.canUndo, isFalse);
    expect(doc.canRedo, isTrue);
    expect(doc.operations, hasLength(1), reason: 'timeline keeps the op');

    await doc.redo();
    expect(doc.head, 1);
    expect(doc.entities.containsKey(body), isTrue,
        reason: 'id-preserving restore');
    expect(doc.canRedo, isFalse);
  });

  test('undo of boolean restores both consumed bodies', () async {
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    final c = await doc.booleanCombine(a, b, BoolOp.fuse);

    await doc.undo();
    expect(doc.entities.containsKey(a), isTrue);
    expect(doc.entities.containsKey(b), isTrue);
    expect(doc.entities.containsKey(c), isFalse);

    await doc.redo();
    expect(doc.entities.containsKey(a), isFalse);
    expect(doc.entities.containsKey(c), isTrue);
  });

  test('undo of transform applies the inverse via the bridge', () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    final m = Matrix4.identity()..translateByVector3(Vector3(5.0, 0.0, 0.0));
    await doc.transform([body], m);
    expect(doc.head, 2);

    await doc.undo();
    expect(doc.head, 1);
    expect(doc.entities.containsKey(body), isTrue,
        reason: 'transform undo never touches entities');
    expect(bridge.transformLog, hasLength(2));
    final product = bridge.transformLog[1] * m as Matrix4;
    expect(product.isIdentity(), isTrue,
        reason: 'undo must apply the inverse of the original matrix');

    await doc.redo();
    expect(bridge.transformLog, hasLength(3));
    expect(bridge.transformLog[2].storage, m.storage);
  });

  test('new command after undo truncates the redo branch', () async {
    await doc.makeBox(const Vec3(1, 1, 1));
    await doc.makeBox(const Vec3(2, 2, 2));
    await doc.undo();
    expect(doc.canRedo, isTrue);

    await doc.makeBox(const Vec3(3, 3, 3));
    expect(doc.canRedo, isFalse);
    expect(doc.operations, hasLength(2));
    expect(doc.head, 2);
  });

  test('chained booleans remap across generations (A -> C -> D)', () async {
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    final c = await doc.booleanCombine(a, b, BoolOp.fuse);
    final e = await doc.makeBox(const Vec3(3, 3, 3));
    final d = await doc.booleanCombine(c, e, BoolOp.cut);

    expect(doc.entities.containsKey(d), isTrue);
    expect(doc.entities.containsKey(c), isFalse);
    expect(doc.entities.containsKey(a), isFalse);

    await doc.undo(); // back to C + E
    expect(doc.entities.containsKey(c), isTrue);
    expect(doc.entities.containsKey(e), isTrue);
    expect(doc.entities.containsKey(d), isFalse);

    await doc.undo(); // undoes makeBox E
    expect(doc.entities.containsKey(e), isFalse);
    expect(doc.entities.containsKey(c), isTrue);

    await doc.redo();
    await doc.redo(); // forward to D again
    expect(doc.entities.containsKey(d), isTrue,
        reason: 'redo across generations needs id-preserving restore');
    expect(doc.entities.containsKey(c), isFalse);
  });

  test('undo depth is bounded at maxUndoDepth', () async {
    for (var i = 0; i < CadDocument.maxUndoDepth + 5; i++) {
      await doc.makeBox(const Vec3(1, 1, 1));
    }
    var undone = 0;
    while (doc.canUndo) {
      await doc.undo();
      undone++;
    }
    expect(undone, CadDocument.maxUndoDepth);
    expect(() => doc.undo(), throwsStateError);
  });
}
