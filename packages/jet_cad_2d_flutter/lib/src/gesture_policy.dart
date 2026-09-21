import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter/gestures.dart' show kMiddleMouseButton;

import 'gesture_policy_platform_stub.dart'
    if (dart.library.js_interop) 'gesture_policy_platform_web.dart';

/// What a bare scroll signal does to the camera.
enum ScrollAction { pan, zoom }

/// The per-platform half of camera gestures, as a value the widget is given
/// rather than a `kIsWeb` it reads.
///
/// `kIsWeb` is a compile-time constant: a widget that branched on it inline
/// could never run its web arm under a `flutter test` on macOS, and no
/// mutation planted there could go red. So the widget takes one of these,
/// tests pass [wheelZooms] and [wheelPans] explicitly, and [forPlatform] is
/// the one place the constant appears.
///
/// There is exactly one behavioural field. A `PointerPanZoom*` sequence
/// (desktop trackpads) pans and zooms under every policy; a
/// `PointerScaleEvent` (browser pinch, ctrl+wheel on Windows and Linux
/// browsers) zooms under every policy; a `PointerScrollEvent` of
/// `kind: trackpad` (Chromium and WebKit browsers, by the engine's
/// heuristic) pans under every policy. Only a `kind: mouse` scroll signal
/// with no modifier is a question, and [mouseWheel] answers it.
@immutable
class GesturePolicy {
  const GesturePolicy({
    required this.mouseWheel,
    this.wheelZoomStep = 1.1,
    this.panButtons = kMiddleMouseButton,
  });

  /// What a `PointerScrollEvent` of any kind other than trackpad, with no
  /// modifier held, means.
  final ScrollAction mouseWheel;

  /// Multiplicative step per wheel notch on the `PointerScrollEvent` zoom
  /// path. A `PointerScaleEvent` carries its own factor and ignores this.
  final double wheelZoomStep;

  /// The `PointerEvent.buttons` mask a drag must intersect to pan.
  final int panButtons;

  /// Desktop embedders and Chromium/WebKit browsers: the wheel zooms.
  ///
  /// On desktop the trackpad never arrives as a scroll signal (it is a
  /// `PointerPanZoom*` sequence), so a scroll signal is a wheel. In a
  /// Chromium or WebKit browser the engine tags a trackpad scroll
  /// `kind: trackpad` and the widget pans it before this field is consulted.
  static const wheelZooms = GesturePolicy(mouseWheel: ScrollAction.zoom);

  /// Firefox: every wheel event is `kind: mouse` because the engine's
  /// heuristic cannot tell a trackpad there, so the wheel pans -- zooming on
  /// it would take pan-by-scroll away from every Firefox trackpad user.
  static const wheelPans = GesturePolicy(mouseWheel: ScrollAction.pan);

  /// The browser question, answered. Pure, and tested on the VM.
  static GesturePolicy forBrowser({required bool firefox}) =>
      firefox ? wheelPans : wheelZooms;

  /// The policy for the platform this code is running on.
  ///
  /// **The only place `kIsWeb` appears in this package's gesture code.**
  /// `isFirefoxBrowser` comes from a conditional import: `dart:ui_web` on
  /// web, `false` elsewhere.
  factory GesturePolicy.forPlatform() =>
      kIsWeb ? forBrowser(firefox: isFirefoxBrowser()) : wheelZooms;
}
