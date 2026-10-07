import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart';

/// `installResidentGpu()` (spec S4, M-G4): what it registers with
/// `jet_cad_2d_flutter`'s registry, and that the registration follows the
/// platform probe rather than a value captured at install.
void main() {
  tearDown(() {
    registerResidentGpu(null);
    debugSetGpuAvailable(null);
    debugSetGpuFactory(null);
  });

  test('installs a ResidentGpu where there was none', () {
    expect(registeredResidentGpu, isNull);
    installResidentGpu();
    expect(registeredResidentGpu, isNotNull);
  });

  test(
      "the installed GPU's availability follows the probe, flipped after "
      'install', () {
    installResidentGpu();
    final gpu = registeredResidentGpu!;
    // Flipped AFTER install, both ways: a value captured at install time
    // would read the same in both halves.
    debugSetGpuAvailable(true);
    expect(gpu.available, isTrue);
    expect(
        resolveBackend(RenderBackend.residentGpu), RenderBackend.residentGpu);
    // MUTATION (M-G4): `available` hard-coded to true -- red here.
    debugSetGpuAvailable(false);
    expect(gpu.available, isFalse);
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
  });

  test('with a factory that throws, the installed GPU is unavailable', () {
    installResidentGpu();
    debugSetGpuFactory(() => throw StateError('no gpu'));
    expect(registeredResidentGpu!.available, isFalse);
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
  });

  test('upload returns null, not a throw, where the GPU factory throws',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = generateDocument(40, dashedFraction: 0.5, measurer: measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0);
    const viewport = Size(300, 200);
    final collection = ResidentCollection.collect(
        document: doc,
        painter: painter,
        live: ViewportTransform.fit(doc.extents, viewport),
        devicePixelRatio: 1.0,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        lineweightScale: 1.0,
        measurer: measurer,
        textStyleOf: doc.textStyleOf);
    expect(collection.instanceCount, greaterThan(0),
        reason: 'anti-vacuity: there is geometry to upload');

    installResidentGpu();
    // A counting factory: the probe is the first thing
    // `ResidentGeometry.create` does, so a consulted factory is the evidence
    // that `upload` reached `uploadResidentCollection` and `create`. No fake
    // can go further: `create`'s next steps need a real `GpuContext` and a
    // loaded shader library, which no test can construct.
    var probes = 0;
    debugSetGpuFactory(() {
      probes++;
      throw StateError('no gpu');
    });
    expect(probes, 0, reason: 'install itself does not probe');
    final painterOut = await registeredResidentGpu!.upload(collection, viewport,
        measurer: measurer, textStyleOf: doc.textStyleOf);
    expect(painterOut, isNull,
        reason: 'uploadResidentCollection: ResidentGeometry.create gives '
            'null with no GPU, and the rebuilder falls back on null');
    // MUTATION (MU1): `upload` returning `Future.value(null)` without
    // calling `uploadResidentCollection` -- null all the same, but the
    // factory is never consulted.
    expect(probes, 1, reason: 'upload went through ResidentGeometry.create');
  });

  test('installing twice registers one, the same instance', () {
    installResidentGpu();
    final first = registeredResidentGpu;
    installResidentGpu();
    expect(registeredResidentGpu, same(first));
  });

  test('install replaces another registration', () {
    final other = _OtherGpu();
    registerResidentGpu(other);
    installResidentGpu();
    expect(registeredResidentGpu, isNot(same(other)));
    expect(registeredResidentGpu, isNotNull);
  });
}

class _OtherGpu implements ResidentGpu {
  @override
  bool get available => true;

  @override
  Future<ResidentFramePainter?> upload(
          ResidentCollection collection, Size viewport,
          {required FlutterTextMeasurer measurer,
          required TextStyleRecord Function(Handle) textStyleOf}) async =>
      null;
}
