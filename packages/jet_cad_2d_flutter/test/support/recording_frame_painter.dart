import 'dart:async';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// A `ResidentFramePainter` that draws nothing and remembers being asked.
/// Stands in for `GpuDrawBackend`, which cannot be constructed without a
/// live GPU (`resident_geometry.dart`'s own doc comment on `create`).
class RecordingFramePainter implements ResidentFramePainter {
  RecordingFramePainter(this.collection);
  final ResidentCollection collection;
  int paints = 0;
  bool disposed = false;
  ViewportTransform? lastCamera;
  Size? lastViewport;
  double? lastDpr;

  @override
  void paint(
      Canvas canvas, ViewportTransform camera, Size viewport, double dpr) {
    paints++;
    lastCamera = camera;
    lastViewport = viewport;
    lastDpr = dpr;
  }

  @override
  void dispose() => disposed = true;
}

/// An uploader the test controls: hands back a [RecordingFramePainter] over
/// the collection it was given, `null` while [failing], or throws while
/// [throwing] -- the fallback's other cause: an escape from the walk, the
/// classifier or the upload itself, rather than a clean `null`.
/// [gate], when set, holds the upload in flight until the test completes it.
class FakeUploader {
  bool failing = false;
  bool throwing = false;
  Completer<void>? gate;
  final List<ResidentCollection> collections = <ResidentCollection>[];
  final List<RecordingFramePainter> painters = <RecordingFramePainter>[];

  Future<ResidentFramePainter?> call(
      ResidentCollection collection, Size viewport) async {
    collections.add(collection);
    final g = gate;
    if (g != null) await g.future;
    if (throwing) throw StateError('upload exploded');
    if (failing) return null;
    final p = RecordingFramePainter(collection);
    painters.add(p);
    return p;
  }
}

/// [base] scaled by [s] about [centre], in screen space -- the same
/// composition `text_order_test.dart`'s `_scaled` uses.
ViewportTransform zoomedAbout(ViewportTransform base, Offset centre, double s) {
  final m = Transform2.translation(centre.dx, centre.dy)
      .multiply(Transform2.scale(s, s))
      .multiply(Transform2.translation(-centre.dx, -centre.dy))
      .multiply(base.worldToScreenMatrix);
  return ViewportTransform(worldToScreenMatrix: m);
}
