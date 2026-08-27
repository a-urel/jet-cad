// The `tile zoom` phase's script is pinned by the spec (§5) and is not the
// implementer's to choose. These are unit tests of the script's *shape* --
// the constants and the focal-point formula -- not a measurement. Tasks 12
// and 13 drive the phase itself on a real device.
import 'dart:math' as math;

import 'package:dev_harness_2d/measurement_rig.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the pinned script is 40 in, 40 out, at 1.03', () {
    expect(kZoomSteps, 40);
    expect(kZoomFactor, closeTo(1.03, 1e-12));
    // The span each way, and the reason clause 3 is satisfied: a 3.26x span
    // cannot sit inside one power-of-two rebase step.
    expect(math.pow(kZoomFactor, kZoomSteps), greaterThan(2.0));
  });

  test('the focal point is off-centre', () {
    const viewport = Size(1600, 1200);
    expect(zoomFocusFor(viewport), const Offset(480, 840));
  });
}
