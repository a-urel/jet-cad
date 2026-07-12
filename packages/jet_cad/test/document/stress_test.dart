import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  test('5000 operations do not blow up quadratically', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 5000; i++) {
      await doc.makeBox(const Vec3(1, 1, 1));
    }
    stopwatch.stop();
    expect(doc.operations, hasLength(5000));
    expect(doc.entities, hasLength(5000 * 27));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
    await doc.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
