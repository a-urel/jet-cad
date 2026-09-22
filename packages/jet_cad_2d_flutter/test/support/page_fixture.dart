import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The spec's standard fixture: an off-origin A4 landscape at 1:50 in
/// metres, partly visible under a zoomed, panned camera.
PageComponent standardPage() => PageComponent(originX: 7350, originY: -1230);

CameraController standardCamera() => CameraController(ViewportTransform(
    worldToScreenMatrix:
        const Transform2(0.137, 0, 0, -0.137, -611.5, 412.25)));

const Size kChromeSize = Size(800, 600);

DraftDocument documentWithPage([PageComponent? page]) {
  final doc = DraftDocument.empty();
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, page ?? standardPage()));
  return doc;
}
