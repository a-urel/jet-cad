import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'viewport_controller.dart';

/// Composites the OCCT-rendered texture and translates pointer input into
/// [ViewportController] camera/selection calls.
///
/// Navigation (desktop CAD defaults, v1): primary drag orbits, secondary
/// drag pans, scroll wheel zooms, primary click (≤ 4 px slop) picks.
/// No toolbars, no styling opinions — hosts build their own UI around it.
class JetCadViewport extends StatefulWidget {
  const JetCadViewport({super.key, required this.controller});

  final ViewportController controller;

  @override
  State<JetCadViewport> createState() => _JetCadViewportState();
}

class _JetCadViewportState extends State<JetCadViewport> {
  static const double _tapSlop = 4.0;
  static const double _zoomPerScrollUnit = 200.0;

  Offset? _downPosition;
  int _downButtons = 0;
  Offset _lastPosition = Offset.zero;
  bool _dragging = false;

  void _onPointerDown(PointerDownEvent event) {
    _downPosition = event.localPosition;
    _downButtons = event.buttons;
    _lastPosition = event.localPosition;
    _dragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _downPosition;
    if (down == null) return;
    if (!_dragging) {
      if ((event.localPosition - down).distance <= _tapSlop) return;
      _dragging = true;
      if (_downButtons & kPrimaryMouseButton != 0) {
        widget.controller.orbitStart(down);
      }
    }
    if (_downButtons & kPrimaryMouseButton != 0) {
      widget.controller.orbitTo(event.localPosition);
    } else if (_downButtons & kSecondaryMouseButton != 0) {
      widget.controller.panBy(event.localPosition - _lastPosition);
    }
    _lastPosition = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downPosition;
    _downPosition = null;
    if (down == null || _dragging) return;
    if (_downButtons & kPrimaryMouseButton != 0) {
      widget.controller.selectAt(event.localPosition);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      widget.controller
          .zoomBy(math.exp(-event.scrollDelta.dy / _zoomPerScrollUnit));
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller.handleLayout(constraints.biggest, devicePixelRatio);
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerSignal: _onPointerSignal,
          behavior: HitTestBehavior.opaque,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final textureId = widget.controller.textureId;
              if (textureId == null) {
                return const ColoredBox(color: Color(0xFF1E1E24));
              }
              // GL framebuffer rows are bottom-up (spike finding) — flip so
              // the scene's up is the screen's up.
              return Transform.flip(
                flipY: true,
                child: Texture(textureId: textureId),
              );
            },
          ),
        );
      },
    );
  }
}
