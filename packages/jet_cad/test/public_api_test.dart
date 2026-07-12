import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  test('the public surface is usable end-to-end from one import', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    final c = await doc.booleanCombine(a, b, BoolOp.cut);
    await doc.transform(
        [c], Matrix4.identity()..translateByVector3(Vector3(1.0, 0.0, 0.0)));
    await doc.undo();
    await doc.redo();
    final json = CadDocumentCodec.encode(doc);
    final restored = await CadDocument.load(json, FakeKernelBridge());
    expect(restored.head, doc.head);
    await doc.dispose();
    await restored.dispose();
  });
}
