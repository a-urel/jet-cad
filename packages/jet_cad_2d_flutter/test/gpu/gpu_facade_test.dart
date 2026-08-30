import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_facade.dart';

void main() {
  tearDown(() => debugSetGpuFactory(null));

  test('reports the platform context when no factory is injected', () {
    // On the test host Flutter GPU is not enabled, so this is false. The
    // assertion that matters is that it *answers* rather than throwing.
    expect(() => gpuAvailable(), returnsNormally);
  });

  test('a factory that throws makes the backend unavailable, once', () {
    var calls = 0;
    debugSetGpuFactory(() {
      calls++;
      throw StateError('no gpu');
    });
    expect(gpuAvailable(), isFalse);
    expect(gpuAvailable(), isFalse);
    expect(calls, 1,
        reason: 'the probe is cached: a platform without Flutter GPU must not '
            'pay a throwing call per frame');
  });
}
