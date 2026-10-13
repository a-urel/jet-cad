// The README of packages/jet_cad_2d_flutter, its Example block verbatim.
// DraftDocument and SpatialIndex come from the engine, which the README says
// the snippet uses.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

Widget canvasFor(Size size) {
  final document = DraftDocument.empty(measurer: FlutterTextMeasurer());
  final index = SpatialIndex(document);
  final camera = CameraController(
      ViewportTransform.fit(document.extents.expandedBy(20), size));

  final canvas = DraftCanvas(document: document, index: index, camera: camera);
  return canvas;
}
