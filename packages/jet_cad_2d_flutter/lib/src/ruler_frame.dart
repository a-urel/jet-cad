import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'camera_controller.dart';
import 'chrome_style.dart';
import 'ruler_painter.dart';

/// Two ruler bars and a corner around a drawing area (spec D11). Each bar
/// is exactly co-extensive with the child on its own axis. A translucent
/// `Listener` over the child feeds [RulerFrameState.pointer]; the child's
/// own listeners still receive every event.
class RulerFrame extends StatefulWidget {
  const RulerFrame({
    super.key,
    required this.camera,
    required this.page,
    required this.child,
  });

  final CameraController camera;
  final ValueListenable<PageComponent?> page;
  final Widget child;

  @override
  State<RulerFrame> createState() => RulerFrameState();
}

class RulerFrameState extends State<RulerFrame> {
  /// The pointer's position in the child's coordinates, or null.
  final ValueNotifier<Offset?> pointer = ValueNotifier<Offset?>(null);
  late final Listenable _repaint =
      Listenable.merge([widget.camera, widget.page, pointer]);
  late final Listenable _cornerRepaint = widget.page;

  @override
  void dispose() {
    pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SizedBox(
            height: kRulerThickness,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: kRulerThickness,
                  height: kRulerThickness,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('ruler-corner'),
                      painter: RulerCornerPainter(
                          page: widget.page, repaint: _cornerRepaint),
                    ),
                  ),
                ),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('ruler-top'),
                      painter: RulerPainter(
                        axis: RulerAxis.horizontal,
                        camera: widget.camera,
                        page: widget.page,
                        pointer: pointer,
                        repaint: _repaint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: kRulerThickness,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('ruler-left'),
                      painter: RulerPainter(
                        axis: RulerAxis.vertical,
                        camera: widget.camera,
                        page: widget.page,
                        pointer: pointer,
                        repaint: _repaint,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MouseRegion(
                    onExit: (_) => pointer.value = null,
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerHover: (e) => pointer.value = e.localPosition,
                      onPointerMove: (e) => pointer.value = e.localPosition,
                      onPointerCancel: (_) => pointer.value = null,
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
