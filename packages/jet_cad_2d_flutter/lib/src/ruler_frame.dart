import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerEvent;
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'camera_controller.dart';
import 'canvas_palette.dart';
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
    required this.chrome,
    required this.child,
  });

  final CameraController camera;
  final ValueListenable<PageComponent?> page;

  /// The bars' and the corner's colours, handed to their painters (dark
  /// theme spec D5).
  final ChromePalette chrome;
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

  void _point(Offset? at) {
    if (mounted) pointer.value = at;
  }

  /// The marked position: a precise pointer's, none for a finger.
  static Offset? _cursorAt(PointerEvent e) =>
      e.kind == PointerDeviceKind.touch ? null : e.localPosition;

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
                          page: widget.page,
                          chrome: widget.chrome,
                          repaint: _cornerRepaint),
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
                        chrome: widget.chrome,
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
                        chrome: widget.chrome,
                        repaint: _repaint,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  // A pointer that went down before this frame was replaced
                  // keeps sending its moves to the old, detached listener
                  // (spec 14c: a host replaced the plan mid-drag): the
                  // disposed notifier is not written then.
                  child: MouseRegion(
                    onExit: (_) => _point(null),
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      // A finger is not a cursor (spec 14t R-10): it marks
                      // nothing and clears the mark.
                      onPointerHover: (e) => _point(_cursorAt(e)),
                      onPointerMove: (e) => _point(_cursorAt(e)),
                      onPointerCancel: (_) => _point(null),
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
