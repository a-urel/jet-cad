import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/recording_frame_painter.dart';

void main() {
  tearDown(() => registerResidentGpu(null));

  test('residentGpu falls back to vertices when no resident GPU is installed',
      () {
    registerResidentGpu(null);
    expect(registeredResidentGpu, isNull);
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
  });

  test(
      'residentGpu falls back to vertices when the installed one is '
      'unavailable', () {
    // MUTATION (M-G3): `resolveBackend` ignoring `available` -- a registered
    // GPU alone would then resolve to residentGpu, and this goes red.
    registerResidentGpu(FakeResidentGpu(available: false));
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
  });

  test('residentGpu resolves to itself when an available one is installed', () {
    registerResidentGpu(FakeResidentGpu());
    expect(
        resolveBackend(RenderBackend.residentGpu), RenderBackend.residentGpu);
  });

  test('availability is read at resolution, not captured at registration', () {
    final gpu = FakeResidentGpu(available: false);
    registerResidentGpu(gpu);
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
    gpu.available = true;
    expect(
        resolveBackend(RenderBackend.residentGpu), RenderBackend.residentGpu);
  });

  test('registering null clears the registration', () {
    final gpu = FakeResidentGpu();
    registerResidentGpu(gpu);
    expect(registeredResidentGpu, same(gpu));
    registerResidentGpu(null);
    expect(registeredResidentGpu, isNull);
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
  });

  test('the last registration wins', () {
    final first = FakeResidentGpu();
    final second = FakeResidentGpu(available: false);
    registerResidentGpu(first);
    registerResidentGpu(second);
    expect(registeredResidentGpu, same(second));
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
  });

  test('the default is unchanged by this plan', () {
    expect(defaultRenderBackend(), RenderBackend.vertices);
  });

  test('an explicit vertices or canvas request is never rerouted', () {
    for (final gpu in <ResidentGpu?>[
      null,
      FakeResidentGpu(available: false),
      FakeResidentGpu(),
    ]) {
      registerResidentGpu(gpu);
      expect(resolveBackend(RenderBackend.vertices), RenderBackend.vertices,
          reason: '$gpu');
      expect(resolveBackend(RenderBackend.canvas), RenderBackend.canvas,
          reason: '$gpu');
    }
  });
}
