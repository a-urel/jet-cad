import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_facade.dart';

void main() {
  tearDown(() => debugSetGpuFactory(null));

  test('residentGpu falls back to vertices where there is no GPU', () {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
  });

  test('the default is unchanged by this plan', () {
    expect(defaultRenderBackend(), RenderBackend.vertices);
  });

  test('an explicit vertices request is never rerouted', () {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    expect(resolveBackend(RenderBackend.vertices), RenderBackend.vertices);
    expect(resolveBackend(RenderBackend.canvas), RenderBackend.canvas);
  });
}
