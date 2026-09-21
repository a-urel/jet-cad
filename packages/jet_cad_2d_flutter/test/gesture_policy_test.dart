import 'package:flutter/gestures.dart' show kMiddleMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  test('wheelZooms: a mouse-kind scroll zooms, 1.1 per notch, middle drag', () {
    const p = GesturePolicy.wheelZooms;
    expect(p.mouseWheel, ScrollSignalAction.zoom);
    expect(p.wheelZoomStep, 1.1);
    expect(p.panButtons, kMiddleMouseButton);
  });

  test('wheelPans: a mouse-kind scroll pans; the rest is the same', () {
    const p = GesturePolicy.wheelPans;
    expect(p.mouseWheel, ScrollSignalAction.pan);
    expect(p.wheelZoomStep, GesturePolicy.wheelZooms.wheelZoomStep);
    expect(p.panButtons, GesturePolicy.wheelZooms.panButtons);
  });

  // The half of `forPlatform()` the VM can reach (spec, M-01q). The other
  // half -- `kIsWeb` and the `dart:ui_web` import -- is compile-time and is
  // covered by criterion 12's look in Chrome/Safari and in Firefox.
  test('forBrowser: Firefox gets wheelPans, every other engine wheelZooms', () {
    expect(
        GesturePolicy.forBrowser(firefox: true), same(GesturePolicy.wheelPans));
    expect(GesturePolicy.forBrowser(firefox: false),
        same(GesturePolicy.wheelZooms));
  });

  test('forPlatform on the VM is wheelZooms', () {
    expect(GesturePolicy.forPlatform(), same(GesturePolicy.wheelZooms));
  });
}
