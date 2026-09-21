import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The drawing area: a [CameraGestureDetector] over a [DraftCanvas].
///
/// Tiles off, `backend` unset (spec D6): a floor plan is 500-5,000
/// entities, and the resident backend cannot run on web, which this product
/// targets. Neither is a default a later sub-project may flip without a
/// measurement.
class PlannerView extends StatefulWidget {
  const PlannerView({
    super.key,
    required this.document,
    required this.index,
    required this.camera,
    required this.policy,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final GesturePolicy policy;

  @override
  State<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends State<PlannerView> {
  /// Ruling 01-2: the camera is fitted once, to the size the view really
  /// got, before the canvas under it has listened to anything.
  bool _fitted = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (!_fitted &&
              constraints.biggest.width > 0 &&
              constraints.biggest.height > 0) {
            _fitted = true;
            widget.camera.value = ViewportTransform.fit(
                widget.document.extents, constraints.biggest);
          }
          return CameraGestureDetector(
            camera: widget.camera,
            policy: widget.policy,
            child: DraftCanvas(
              document: widget.document,
              index: widget.index,
              camera: widget.camera,
              tiles: false,
            ),
          );
        },
      );
}
