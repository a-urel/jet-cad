// Whether `ZOOM_MODE=criterion8`'s arms are pointed at a phase where the
// mutation they alternate can actually be observed.
//
// **The defect this file exists for (Ruling 21).** Criterion 8's arms were
// wired around `runTileZoomPhase`, flipping `TileCache.debugFullViewportQuery`
// between them. That flag modifies exactly one thing -- the live fallback's
// query extent in `TileCache.paintFrame` -- and in the zoom phase every frame
// is a *moving* frame, which blits the carry-over composite and returns before
// the fallback can run. A full n=9 interleaved run at 500,000 entities
// completed cleanly, printed `gestureLiveDraws=0` in all eighteen arms, and
// measured nothing: arm A p95 1.69 1.86 1.78 2.06 ... against arm B p95 1.77
// 1.68 1.74 1.73 ..., indistinguishable. The log is kept as
// `KEEP_c8_DEGENERATE_run.log`.
//
// This is the 1.00 `zoom_arm_wiring_test.dart` exists to prevent, arriving
// through a different door: not "the flag was never flipped" but "the flag was
// flipped on code that never runs".
//
// Plan 3h's criterion 3 -- which criterion 8 re-measures at n=7-9 interleaved
// -- was measured on the **`tile pan` phase**. That is where the live fallback
// runs and where Plan 3h's M4 bites. So criterion 8's arms alternate around
// `runTilePanArm`, and the statistic an arm produces is `tile pan` p95.
//
// **What is tested here, and what is not.** `runTilePanArm` itself refuses to
// run outside a profile build and needs a painted widget to bake a tile, so no
// number from a device appears in this file. What is testable is everything
// that decides whether the device's numbers *mean* what the transcript claims:
// the arms alternate whole arms, the flag named by an arm's label is the flag
// actually set while that arm runs, half the arms genuinely run with it set,
// every line of every report is attributable to its arm, and the report shouts
// when the pan it measured never ran the fallback at all.
import 'dart:async';

import 'package:dev_harness_2d/measurement_rig.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// A report with no measurement in it: these tests drive the wiring, and a
/// figure here would be a fabricated one. The two counters that decide whether
/// an arm measured anything are parameters so a test can say which case it is
/// exercising.
PanArmReport _report({
  List<double?> panMs = const <double?>[],
  int panLiveDraws = 10,
  int tilesAfterPurge = 0,
  int warmBakes = 12,
}) =>
    PanArmReport(
      warmFrames: 13,
      warmBakes: warmBakes,
      tilesAfterPurge: tilesAfterPurge,
      holdMs: const <double?>[],
      holdBakes: 0,
      holdLiveDraws: 0,
      panMs: panMs,
      panBakes: 14,
      panBakeFrames: 14,
      panMaxBakesInAFrame: 1,
      panBlits: 1582,
      panCarryOverBlits: 0,
      panLiveDraws: panLiveDraws,
      panNewEvictions: 0,
      liveTiles: 26,
      tileBytes: 27262976,
    );

/// What one arm's callback saw: the label it was printed under, and
/// `debugFullViewportQuery` as it stood *while the arm ran*.
class _Seen {
  _Seen(this.label, this.fullViewportQuery, this.restBakeDisabled);

  final String label;
  final bool fullViewportQuery;
  final bool restBakeDisabled;
}

void main() {
  /// Runs criterion 8's arms around a pan-phase callback against a real
  /// [TileCache], recording the flag state observed inside each arm.
  Future<(List<_Seen>, TileCache)> drive({required int repeats}) async {
    final cache = TileCache();
    final labels = <String>[];
    final flags = <(bool, bool)>[];
    await runCriterionArms<PanArmReport>(
      criterion: ZoomCriterion.eight,
      repeats: repeats,
      entities: 500000,
      cache: cache,
      phase: 'tile pan',
      runArm: () async {
        // Read inside the arm, not after it: a flag flipped after the phase
        // ran would label the arm correctly and measure the other one.
        flags.add((cache.debugFullViewportQuery, cache.debugRestBakeDisabled));
        return _report();
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

  test('criterion 8 alternates whole arms around the pan phase', () async {
    final (seen, cache) = await drive(repeats: 3);

    expect(seen.length, 6, reason: 'three repeats of two arms');
    expect(
      <bool>[for (final s in seen) s.fullViewportQuery],
      <bool>[false, true, false, true, false, true],
      reason: 'narrow query for the numerator, Plan 3h M4 for the '
          'denominator, alternating -- never all of one arm and then all of '
          'the other, because session drift then lands entirely on whichever '
          'arm ran last',
    );
    expect(seen.every((s) => !s.restBakeDisabled), isTrue,
        reason: "criterion 4's flag has no business being set here");
    expect(cache.debugFullViewportQuery, isFalse,
        reason: 'the flag does not outlive the run');
  });

  test('half the arms actually run with the flag set', () async {
    // The Ruling 21 assertion, stated as a count rather than as a sequence: a
    // driver that stopped flipping the flag would still alternate two
    // callbacks, still print two labels per repeat, and still measure one
    // configuration twice.
    final (seen, _) = await drive(repeats: 4);

    final set = seen.where((s) => s.fullViewportQuery).length;
    expect(set, 4,
        reason: 'four of the eight arms are the denominator and must run '
            'with debugFullViewportQuery=true; $set did. Every arm at the '
            'same flag state is a ratio of 1.00 by construction');
    expect(seen.where((s) => !s.fullViewportQuery).length, 4);
  });

  test('the flag an arm ran at is the flag its label claims', () async {
    final (seen, _) = await drive(repeats: 2);

    for (final s in seen) {
      final claimed = s.label.contains('debugFullViewportQuery=true');
      expect(claimed, s.fullViewportQuery,
          reason: 'the label claims $claimed and the cache ran at '
              '${s.fullViewportQuery}: ${s.label}');
    }
  });

  test('every arm names the pan phase, its criterion and its repeat', () async {
    final (seen, _) = await drive(repeats: 3);

    for (final s in seen) {
      expect(s.label, contains('tile pan'),
          reason: 'a transcript that says `tile zoom` is the degenerate run: '
              'the zoom phase has no live fallback for the flag to modify');
      expect(s.label, isNot(contains('tile zoom')));
      expect(s.label, contains('c8'));
    }
    expect(seen.map((s) => s.label).toSet().length, seen.length,
        reason: 'every arm of the transcript is attributable on its own line');
    expect(seen[0].label, contains('repeat 1/3'));
    expect(seen[0].label, contains('arm A'));
    expect(seen[1].label, contains('arm B'));
    expect(seen[1].label, contains("Plan 3h's M4"));
    expect(seen[4].label, contains('repeat 3/3'));
  });

  test('the zoom driver still says tile zoom', () {
    // Criterion 4's numbers are already taken and its transcript must stay
    // reproducible: re-pointing criterion 8 must not rename criterion 4's
    // phase.
    expect(
      zoomArmLabel(ZoomArm.restBakeOn,
          repeat: 0, repeats: 4, entities: 50000, phase: 'tile zoom'),
      startsWith('R2 tile zoom c4 repeat 1/4 arm A '
          '[debugRestBakeDisabled=false]'),
    );
  });

  test('every printed line of a pan arm report carries its arm label', () {
    final label = zoomArmLabel(ZoomArm.fullViewportQuery,
        repeat: 4, repeats: 9, entities: 500000, phase: 'tile pan');
    final lines = _capture(() => printPanArmReport(
          label,
          _report(panMs: <double?>[for (var i = 0; i < 120; i++) 1.0 + i / 60]),
        ));

    expect(lines, isNotEmpty);
    for (final line in lines) {
      expect(line, startsWith(label),
          reason: 'an indented continuation line under the wrong heading is a '
              'number attributed to the wrong arm');
    }
    final text = lines.join('\n');
    // The statistic criterion 8 is defined on, and the control beside it.
    expect(text, contains('tile pan frames=120'));
    expect(text, contains('tile hold'));
    expect(text, contains('p95='));
  });

  test('the pan p95 is the statistic, and it is the p95 of the pan', () {
    // 120 frames, 1.00 .. 2.98 ms in 0.0166 steps; index (120*0.95).floor()
    // == 114, matching `report`'s own quantile so a pan arm and an R2 `tile
    // pan` block can be read against each other.
    final ms = <double?>[for (var i = 0; i < 120; i++) 1.0 + i / 60];
    final r = _report(panMs: ms);
    expect(r.panFrameMs.length, 120);
    expect(r.panFramesMissing, 0);
    expect(r.panP95Ms, closeTo(1.0 + 114 / 60, 1e-9));
  });

  test('a pan that never ran the live fallback shouts', () {
    // Ruling 21, caught by the instrument itself. `debugFullViewportQuery`
    // modifies the live fallback's query extent and nothing else, so an arm
    // whose pan never ran the fallback measured the same code as its
    // counterpart, whatever the flag said.
    final text = _capture(() => printPanArmReport(
          'L',
          _report(
            panMs: <double?>[for (var i = 0; i < 120; i++) 1.0],
            panLiveDraws: 0,
          ),
        )).join('\n');
    expect(text, contains('liveDraws=0'));
    expect(text, contains('Ruling 21'));
    expect(text, contains('WARNING'));

    final healthy = _capture(() => printPanArmReport(
          'L',
          _report(panMs: <double?>[for (var i = 0; i < 120; i++) 1.0]),
        )).join('\n');
    expect(healthy, isNot(contains('WARNING')));
  });

  test('an arm that inherited a warm generation shouts', () {
    // The failure the 2026-08-29 check run found and the purge exists to
    // remove: every arm after the first panned over the tiles the previous
    // arm's pan had baked, so it blitted where the measurement expects it to
    // bake. `bakes=14 liveDraws=10 p95=14.01ms` in arm A repeat 1, then
    // `bakes=0 liveDraws=0 blits=1600` in all three arms after it.
    final full = <double?>[for (var i = 0; i < 120; i++) 1.0];
    final inherited = _capture(() => printPanArmReport(
          'L',
          _report(panMs: full, tilesAfterPurge: 26, warmBakes: 0),
        )).join('\n');
    expect(inherited, contains('did not start from a purged cache'));
    expect(inherited, contains('tilesAfterPurge=26'));

    // A purge that emptied the cache but a warm that then baked nothing is the
    // same defect seen from the other end, and shouts too.
    final noBakes = _capture(() => printPanArmReport(
          'L',
          _report(panMs: full, warmBakes: 0),
        )).join('\n');
    expect(noBakes, contains('did not start from a purged cache'));

    final cold =
        _capture(() => printPanArmReport('L', _report(panMs: full))).join('\n');
    expect(cold, isNot(contains('WARNING')));
  });

  test('a short pan sample shouts rather than publishing its p95', () {
    final text = _capture(() => printPanArmReport(
          'L',
          _report(
            panMs: <double?>[
              for (var i = 0; i < 120; i++) i < 7 ? null : 1.0,
            ],
          ),
        )).join('\n');
    expect(text, contains('SHORT SAMPLE'));
    expect(text, contains('pan 7'));
  });

  test('the pan step is the historical one unless PAN_STEP scales it', () {
    // The arm and R2's own `tile pan` must step identically or criterion 8's
    // arms are not comparable with the block criterion 9 reads.
    expect(tilePanStep(double.nan), const Offset(-7, -3));
    final scaled = tilePanStep(15.231546211727816);
    expect(scaled.distance, closeTo(15.231546211727816, 1e-9));
    expect(scaled.dx / scaled.dy, closeTo(-7 / -3, 1e-9));
  });
}

/// Everything [body] prints, one entry per line.
List<String> _capture(void Function() body) {
  final lines = <String>[];
  runZoned(body,
      zoneSpecification:
          ZoneSpecification(print: (_, __, ___, line) => lines.add(line)));
  return lines;
}
