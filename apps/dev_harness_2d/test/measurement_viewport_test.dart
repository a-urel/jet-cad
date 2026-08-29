// The measurement viewport, and the two things that must follow from it.
//
// Plan 3i's design spec §5 pins the measurement viewport at 1600x1200 logical
// at `devicePixelRatio` 2 and prices every memory prediction against the
// 3200x2400 device rectangle that implies. The harness never created that
// window -- `MainFlutterWindow` took the frame straight from the nib and set
// it back unchanged, so a smoke run printed `window=800x600` -- while the code
// fitted its camera to `Size(1600, 1200)` and handed the zoom phase the same.
// The code assumed a window it never created. Ruling 20 records that
// 1600x1200 is unreachable on this display and that the human chose 1400x900.
//
// Two defects follow from a viewport that is a constant rather than a
// measured fact, and both are tested here:
//
//  * `runR2Rig`'s own zoom step anchored at a hardcoded `Offset(800, 600)`,
//    which is the viewport centre at 1600x1200 and nowhere else. At 1400x900
//    it is off-centre and low-right; at 800x600 it is the bottom-right
//    corner. The anchor has to come from the viewport actually in use.
//  * the window-size warning fired only inside the `ZOOM_ARMS > 0` branch, so
//    a plain `RUN_R2` run at the wrong window said nothing at all.
import 'dart:async';

import 'package:dev_harness_2d/main.dart';
import 'package:dev_harness_2d/measurement_rig.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Every line [body] prints, captured.
List<String> linesFrom(void Function() body) {
  final lines = <String>[];
  runZoned(body,
      zoneSpecification:
          ZoneSpecification(print: (_, __, ___, line) => lines.add(line)));
  return lines;
}

void main() {
  /// A camera that is nothing like the identity: a 0.08 scale, the y axis
  /// flipped, a skew in both off-diagonal terms, and an origin six million
  /// units out -- the corpus's own neighbourhood. An anchor test whose camera
  /// is the identity at the origin passes for the wrong reason, because every
  /// screen point is then its own world point.
  CameraController farFromIdentityCamera() => CameraController(
        ViewportTransform(
          worldToScreenMatrix:
              Transform2(0.08, 0.011, -0.006, -0.08, -361000.0, 498000.0),
        ),
      );

  Vector2 worldUnder(CameraController camera, Offset screen) =>
      camera.value.screenToWorld(Vector2(screen.dx, screen.dy));

  group('the R2 zoom anchor is the centre of the viewport it is given', () {
    // Two sizes, and neither of them is the 1600x1200 the old hardcoded
    // `Offset(800, 600)` happened to be the centre of. A test at one size
    // only is the degenerate fixture this repo's CLAUDE.md names as its
    // dominant failure mode: at 1600x1200 a hardcoded constant and a derived
    // centre are indistinguishable.
    for (final viewport in const <Size>[Size(1400, 900), Size(800, 600)]) {
      test('$viewport', () {
        expect(r2ZoomAnchorFor(viewport),
            Offset(viewport.width / 2, viewport.height / 2));
      });
    }

    // The formula above is only worth as much as the call site that uses it,
    // and `runR2Rig` cannot be unit tested -- it opens with
    // `refuseDebugMode()` and `flutter test` is a debug build. So the zoom
    // step is driven directly, and the anchor is read off the camera's own
    // behaviour rather than off the constant: `zoomAt(p, f)` fixes the world
    // point under `p`, so a composition of them fixes it too. Whatever point
    // the script actually zoomed about is the one point that did not move.
    for (final viewport in const <Size>[Size(1400, 900), Size(800, 600)]) {
      test('the step holds the viewport centre still at $viewport', () async {
        final camera = farFromIdentityCamera();
        final centre = Offset(viewport.width / 2, viewport.height / 2);
        final centreBefore = worldUnder(camera, centre);
        // The old hardcoded anchor, watched as a control. It is a different
        // point from the centre at both sizes above.
        const hardcoded = Offset(800, 600);
        final hardcodedBefore = worldUnder(camera, hardcoded);

        var frames = 0;
        await runR2ZoomStep(
          camera: camera,
          viewport: viewport,
          pumpFrame: () async => frames++,
        );

        expect(frames, 120, reason: 'the R2 zoom step is 120 frames');
        // The camera really moved: 60 steps of 1.03 and 60 of 0.97 compose to
        // 0.947, not to 1, so this is not a script that did nothing.
        expect(camera.value.scale,
            closeTo(farFromIdentityCamera().value.scale * 0.9470, 1e-3));

        final centreAfter = worldUnder(camera, centre);
        expect(centreAfter.x, closeTo(centreBefore.x, 1e-3));
        expect(centreAfter.y, closeTo(centreBefore.y, 1e-3));

        // And the control moved, by a margin five orders of magnitude wider
        // than the tolerance above -- so "nothing moved" cannot be why this
        // test passes.
        final hardcodedAfter = worldUnder(camera, hardcoded);
        expect((hardcodedAfter - hardcodedBefore).length, greaterThan(100.0),
            reason: 'at $viewport the hardcoded Offset(800, 600) is not the '
                'centre, so it must not be the fixed point');
      });
    }
  });

  group('every RUN_R2 run reports its window, and warns when it is wrong', () {
    test('a window that is not the pinned size warns', () {
      final lines = linesFrom(() => reportR2Window(
          const Size(800, 600), const Size(1400, 900),
          devicePixelRatio: 2.0)).join('\n');
      expect(lines, contains('R2 app-run: window=800x600'));
      expect(lines, contains('WARNING'));
      expect(lines, contains('1400x900'));
    });

    test('the pinned size warns about nothing', () {
      final lines = linesFrom(() => reportR2Window(
          kMeasurementViewport, kMeasurementViewport,
          devicePixelRatio: 2.0)).join('\n');
      // The window line still prints -- it is the anchor the warning hangs
      // off, and a run that stopped printing it would take the warning's
      // "every run" guarantee with it.
      expect(lines, contains('R2 app-run: window='));
      expect(lines, isNot(contains('WARNING')));
    });

    // The warning and the window line are emitted by one function precisely so
    // that no call site can keep the line and lose the warning -- which is
    // what the `ZOOM_ARMS > 0` branch used to do.
    test('a wrong window warns even where no zoom arm will ever run', () {
      final lines = linesFrom(() => reportR2Window(
          const Size(1728, 1117), kMeasurementViewport,
          devicePixelRatio: 2.0)).join('\n');
      expect(lines, contains('WARNING'));
    });
  });

  group('the measurement window size is selectable, and refuses nonsense', () {
    // The size is selectable because no single size can serve every criterion
    // this plan scores. The design spec pins 1600x1200, which Ruling 20
    // established this display cannot produce; criteria 2 and 4 were taken at
    // the 1400x900 the human chose instead; and criterion 9 re-measures Plan
    // 3h's `tile pan` and `tile hold` against 3h's own recorded figures, which
    // were taken at the nib default of 800x600 because nothing in the harness
    // set a window size until 2026-08-28. A larger viewport means more tiles,
    // more bakes and more work per pan frame, so comparing 3h's numbers with a
    // 1400x900 run measures the viewport change and calls it a regression.
    // One run at 800x600 removes the confound; the request is how it is asked
    // for.
    test('a request is honoured, at sizes a constant could not be', () {
      // Three sizes and not one: at 1400x900 alone a parser that returned the
      // default and a parser that read its argument are indistinguishable.
      expect(parseMeasurementViewport('800x600'), const Size(800, 600));
      expect(parseMeasurementViewport('1400x900'), const Size(1400, 900));
      expect(parseMeasurementViewport('1728x1117'), const Size(1728, 1117));
    });

    test('asking for nothing is 1400x900, exactly as before', () {
      // These tests run with no `JC_WINDOW` define, so this is the real
      // default path and not a restatement of the parser. Criteria 2 and 4
      // are already measured at this size; a run that asks for nothing must
      // stay reproducible against them.
      expect(kMeasurementViewport, const Size(1400, 900));
      expect(parseMeasurementViewport(kDefaultWindowRequest),
          const Size(1400, 900));
    });

    // The house rule, and the reason for it, is `parseZoomMode`'s: a define
    // that silently falls back to its default writes one run into the table
    // under a heading the command line claimed and the run did not use. A
    // measurement that silently ran at a size nobody asked for is the exact
    // failure this whole area exists to prevent -- and here it is worse than
    // for `ZOOM_MODE`, because the Swift side reads its own copy of the same
    // request, so a fallback on one side of the language boundary and not the
    // other is a run whose camera fit and whose window disagree.
    test('a malformed request throws rather than falling back', () {
      for (final raw in const <String>[
        '', // the empty define
        '800', // one number
        '800x', // half a pair
        'x600',
        '800x600x2', // three
        '800X900', // capital X: not the separator
        'eight hundred by six hundred',
        '800.0x600.0', // logical pixels are whole
        '-800x600',
      ]) {
        expect(() => parseMeasurementViewport(raw), throwsStateError,
            reason: 'JC_WINDOW="$raw" must stop the session');
      }
    });

    test('an absurd request throws too', () {
      // A size out of range is not a typo the operator will notice in the
      // transcript: AppKit clamps a window it cannot place on the screen, so
      // `4x4` and `100000x900` would both silently become some other size and
      // the run would measure it.
      for (final raw in const <String>[
        '4x4',
        '0x0',
        '100000x900',
        '1400x100000',
      ]) {
        expect(() => parseMeasurementViewport(raw), throwsStateError,
            reason: 'JC_WINDOW="$raw" must stop the session');
      }
    });

    // The two sides of the language boundary are configured separately --
    // `--dart-define` reaches Dart only and `MainFlutterWindow.swift` is what
    // sizes the window -- so `reportR2Window`'s warning is the only thing that
    // catches them disagreeing. It has to keep working against a
    // `kMeasurementViewport` that is no longer a literal.
    test('a window that does not match the request still warns', () {
      final lines = linesFrom(() => reportR2Window(
          const Size(1400, 900), parseMeasurementViewport('800x600'),
          devicePixelRatio: 2.0)).join('\n');
      expect(lines, contains('R2 app-run: window=1400x900'));
      expect(lines, contains('WARNING'));
      expect(lines, contains('800x600'));
    });
  });
}
