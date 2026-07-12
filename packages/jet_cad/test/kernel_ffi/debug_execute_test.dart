import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {
      markTestSkipped('native library not built');
    });
    return;
  }

  test('debugExecute round-trips a raw command', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    final result = await bridge.debugExecute(
      session,
      {'cmd': 'debugInitTexture', 'width': 32, 'height': 32},
    );
    expect(result['surfaceId'], isA<int>());
    expect(result['surfaceId'], greaterThan(0));
    await bridge.disposeSession(session);
  });

  test('debugExecute surfaces command errors as KernelException', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    await expectLater(
      bridge.debugExecute(session, {'cmd': 'noSuchCommand'}),
      throwsA(isA<KernelException>()),
    );
    await bridge.disposeSession(session);
  });
}
