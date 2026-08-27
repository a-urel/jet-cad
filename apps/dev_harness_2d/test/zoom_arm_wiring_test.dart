// Whether an interleaved run's arms are the arms its transcript says they are.
//
// **The defect this file exists for.** `runInterleaved` had no production
// caller: `main.dart` ran `ZOOM_ARMS` repeats of one configuration and printed
// them as `R2 tile zoom arm 0..8` -- the exact shape and labelling of the n=9
// interleaved transcript criteria 4 and 8 call for -- while neither
// `debugRestBakeDisabled` nor `debugFullViewportQuery` was ever set. Every
// ratio a reader formed from that transcript would have read **1.00**, and the
// degenerate number would have landed in a document of record with nothing to
// contradict it. Ruling 14 built the two flags for exactly this; nothing
// flipped them.
//
// **What is tested here, and what is not.** The device runs are Plan 3i's
// Tasks 12 and 13 and are blocked on machine power, so no number appears in
// this file. What is testable without a device is everything that decides
// whether the numbers *mean* what the transcript claims: the arms alternate,
// the flag named by an arm's label is the flag actually set while that arm
// runs, each arm's label is distinguishable from the other's and from a plain
// repeat's, and the flags do not outlive the run.
import 'dart:async';

import 'package:dev_harness_2d/measurement_rig.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// A report with no measurement in it: these tests drive the wiring, and a
/// figure here would be a fabricated one.
ZoomReport _emptyReport() => ZoomReport.from(
      gestureMs: <double?>[],
      gestureBakes: 0,
      gestureLiveDraws: 0,
      settle: SettleReport(
        frames: 2,
        covered: true,
        coveringFrameMs: 0.0,
        wallMs: 0.0,
        framesMissing: 0,
      ),
    );

/// What one arm's callback saw: the label it was printed under, and the cache
/// flags as they stood *while the arm ran*.
class _Seen {
  _Seen(this.label, this.restBakeDisabled, this.fullViewportQuery);

  final String label;
  final bool restBakeDisabled;
  final bool fullViewportQuery;
}

void main() {
  /// Runs [criterion]'s arms against a real [TileCache], recording the flag
  /// state observed inside each arm.
  Future<(List<_Seen>, TileCache)> drive(
    ZoomCriterion criterion, {
    required int repeats,
  }) async {
    final cache = TileCache();
    final labels = <String>[];
    final flags = <(bool, bool)>[];
    await runZoomCriterionArms(
      criterion: criterion,
      repeats: repeats,
      entities: 50000,
      cache: cache,
      runArm: () async {
        // Read inside the arm, not after it: a flag flipped after the phase
        // ran would label the arm correctly and measure the other one.
        flags.add((cache.debugRestBakeDisabled, cache.debugFullViewportQuery));
        return _emptyReport();
      },
      emit: (label, report) => labels.add(label),
    );
    expect(labels.length, flags.length,
        reason: 'one label emitted per arm run, in arm order');
    return (
      <_Seen>[
        for (var i = 0; i < flags.length; i++)
          _Seen(labels[i], flags[i].$1, flags[i].$2),
      ],
      cache,
    );
  }

  test('criterion 4 alternates its arms and flips only its own flag', () async {
    final (seen, cache) = await drive(ZoomCriterion.four, repeats: 3);

    expect(seen.length, 6, reason: 'three repeats of two arms');
    expect(
      <bool>[for (final s in seen) s.restBakeDisabled],
      <bool>[false, true, false, true, false, true],
      reason: 'rest bake on for the numerator, off for the denominator, '
          'alternating -- never all of one arm and then all of the other',
    );
    expect(
      seen.every((s) => !s.fullViewportQuery),
      isTrue,
      reason: "criterion 8's flag has no business being set in criterion 4's "
          'run: an arm is a whole configuration',
    );
    expect(cache.debugRestBakeDisabled, isFalse,
        reason: 'the flags do not outlive the run');
  });

  test('criterion 8 alternates its arms and flips only its own flag', () async {
    final (seen, cache) = await drive(ZoomCriterion.eight, repeats: 2);

    expect(seen.length, 4);
    expect(
      <bool>[for (final s in seen) s.fullViewportQuery],
      <bool>[false, true, false, true],
    );
    expect(seen.every((s) => !s.restBakeDisabled), isTrue);
    expect(cache.debugFullViewportQuery, isFalse);
  });

  test('every arm is labelled with the flag it actually ran at', () async {
    final (seen, _) = await drive(ZoomCriterion.four, repeats: 2);

    for (final s in seen) {
      final claimed = s.label.contains('debugRestBakeDisabled=true');
      expect(claimed, s.restBakeDisabled,
          reason: 'the label claims $claimed and the cache ran at '
              '${s.restBakeDisabled}: ${s.label}');
    }
  });

  test("criterion 8's denominator names whose M4 it is", () async {
    final (seen, _) = await drive(ZoomCriterion.eight, repeats: 1);

    expect(seen[1].label, contains("Plan 3h's M4"),
        reason: 'mutant numbering is per-plan and M4/M5 collide between the '
            "3h and 3i logs, so the arm's own label has to say which");
    expect(seen[0].label, isNot(contains('M4')));
  });

  test('no two arms of a run share a label', () async {
    final (seen, _) = await drive(ZoomCriterion.four, repeats: 3);

    expect(seen.map((s) => s.label).toSet().length, seen.length,
        reason: 'repeat and side both appear, so every arm of the transcript '
            'is attributable on its own line');
    expect(seen[0].label, contains('repeat 1/3'));
    expect(seen[0].label, contains('arm A'));
    expect(seen[1].label, contains('repeat 1/3'));
    expect(seen[1].label, contains('arm B'));
    expect(seen[4].label, contains('repeat 3/3'));
  });

  test('a plain repeat cannot be read as an interleaved arm', () {
    final plain = zoomPlainLabel(repeat: 0, repeats: 9, entities: 50000);
    final armA = zoomArmLabel(ZoomArm.restBakeOn,
        repeat: 0, repeats: 9, entities: 50000);
    final armB = zoomArmLabel(ZoomArm.restBakeOff,
        repeat: 0, repeats: 9, entities: 50000);

    expect(armA, contains('arm A'));
    expect(armB, contains('arm B'));
    // The old output was `R2 tile zoom arm 0`, which reads as one of these.
    expect(plain, isNot(matches(RegExp(r'arm [AB0-9]'))));
    expect(plain, contains('NOT an interleaved arm'));
    expect(plain, contains('criterion 2 only'));
    expect(plain, contains('debugRestBakeDisabled=false'));
    expect(plain, contains('debugFullViewportQuery=false'));
  });

  test('every printed line of a report carries its arm label', () {
    final label = zoomArmLabel(ZoomArm.fullViewportQuery,
        repeat: 4, repeats: 9, entities: 500000);
    final lines = <String>[];
    runZoned(
      () => printZoomReport(
        label,
        ZoomReport.from(
          gestureMs: <double?>[for (var i = 0; i < 2 * kZoomSteps; i++) 5.0],
          gestureBakes: 0,
          gestureLiveDraws: 0,
          settle: SettleReport(
            frames: 2,
            covered: true,
            coveringFrameMs: 8.0,
            wallMs: 13.0,
            framesMissing: 0,
          ),
        ),
      ),
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, line) => lines.add(line),
      ),
    );

    expect(lines, isNotEmpty);
    for (final line in lines) {
      expect(line, startsWith(label),
          reason: 'an indented continuation line under the wrong heading is a '
              'number attributed to the wrong arm');
    }
    // Both time figures print, and neither can be read as the other.
    expect(lines.join('\n'), contains('settleWallMs=13.00'));
    expect(lines.join('\n'), contains('coveringFrameMs=8.00'));
  });

  test('a short sample and an uncovered settle both shout', () {
    final lines = <String>[];
    runZoned(
      () => printZoomReport(
        'label',
        ZoomReport.from(
          gestureMs: <double?>[
            for (var i = 0; i < 2 * kZoomSteps; i++) i < 3 ? null : 5.0,
          ],
          gestureBakes: 0,
          gestureLiveDraws: 0,
          settle: SettleReport(
            frames: kIdleFrames,
            covered: false,
            coveringFrameMs: 5.0,
            wallMs: 150.0,
            framesMissing: 1,
          ),
        ),
      ),
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, line) => lines.add(line),
      ),
    );

    final text = lines.join('\n');
    expect(text, contains('never covered'));
    expect(text, contains('SHORT SAMPLE'));
    expect(text, contains('gesture 3 of ${2 * kZoomSteps}'));
  });
}
