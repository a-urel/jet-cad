import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {});
    return;
  }

  test('model -> save -> load -> continue editing, against real OCCT',
      () async {
    final doc = await CadDocument.create(FfiKernelBridge(libPath));
    final a = await doc.makeBox(const Vec3(10, 10, 10));
    final b = await doc.makeBox(const Vec3(4, 4, 4));
    final c = await doc.booleanCombine(a, b, BoolOp.cut);
    final saved = await doc.save();
    await doc.dispose();

    final restored = await CadDocument.load(saved, FfiKernelBridge(libPath));
    expect(restored.canUndo, isFalse);
    expect(await restored.exportStep([c]), isNotEmpty);
    // Continue editing on restored geometry: new ids must not collide.
    final d = await restored.makeBox(const Vec3(1, 1, 1));
    expect(restored.entities[d], isNotNull);
    final e = await restored.booleanCombine(c, d, BoolOp.fuse);
    expect(await restored.exportStep([e]), isNotEmpty);
    await restored.dispose();
  });
}
