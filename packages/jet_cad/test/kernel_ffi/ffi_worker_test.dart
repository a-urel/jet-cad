import 'package:flutter/foundation.dart';
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

  test('bridge survives a burst of sequential commands', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 50; i++) {
      await bridge.makeBox(session, const Vec3(1, 1, 1));
    }
    stopwatch.stop();
    // Not a perf assertion — just a visibility line in the transcript to
    // compare against the old Isolate.run path.
    debugPrint('50 makeBox commands: ${stopwatch.elapsedMilliseconds} ms');
    await bridge.disposeSession(session);
    await bridge.shutdown();
  });

  test('commands after shutdown throw StateError', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    await bridge.disposeSession(session);
    await bridge.shutdown();
    await expectLater(
      bridge.createSession(const HeadlessTarget()),
      throwsA(isA<StateError>()),
    );
  });

  test('shutdown is idempotent', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    await bridge.disposeSession(session);
    await bridge.shutdown();
    await bridge.shutdown();
  });

  test('parallel sessions on one worker stay isolated', () async {
    final bridge = FfiKernelBridge(libPath);
    final a = await bridge.createSession(const HeadlessTarget());
    final b = await bridge.createSession(const HeadlessTarget());
    final boxA = await bridge.makeBox(a, const Vec3(1, 1, 1));
    await expectLater(
      bridge.exportStep(b, [boxA.body]),
      throwsA(isA<KernelException>()),
      reason: 'body ids are session-scoped',
    );
    await bridge.disposeSession(a);
    await bridge.disposeSession(b);
    await bridge.shutdown();
  });
}
