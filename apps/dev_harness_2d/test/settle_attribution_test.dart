// Which frame the settle's numbers are read off.
//
// **The defect this file exists for.** A `FrameTiming` is delivered only after
// its frame has rasterised, and `pumpFrame` completes at
// `SchedulerBinding.endOfFrame` -- the frame's post-frame phase, *before* the
// scene rasterises. So the timings that arrive while frame *i* is being pumped
// belong to frame *i-1*. The settle used to register a fresh timings callback
// around each single `await pumpFrame()` and read `.last` out of it, which
// therefore reported the **previous** frame's `totalSpan` under the label "the
// frame that covered the viewport" -- and on correct code the covering frame is
// idle frame 2 (Ruling 15), so the published figure was the in-between frame:
// a composite blit that draws nothing and is essentially free. `settleMs` is
// the only time value criteria 3 and 4 are read off.
//
// **How the fake frames below model that.** `_FrameDriver.pump` renders frame
// *i* and, in the same call, reports frame *i-1*'s timing -- exactly the
// one-frame lag the engine has. Nothing here measures anything: the costs are
// chosen, not observed, so that attribution is the only thing under test. The
// device runs are Plan 3i's Tasks 12 and 13 and are not these tests.
//
// `runSettlePhase` and not `runTileZoomPhase` because the latter opens with
// `refuseDebugMode()` -- correctly, since a debug frame time means nothing --
// and `flutter test` is a debug build. The attribution under test is all in
// `runSettlePhase`, which is the production settle: `runTileZoomPhase` calls
// it with `() => cache.viewportCovered`.
import 'package:dev_harness_2d/measurement_rig.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `FrameTiming` whose `totalSpan` is exactly [ms] -- `rasterFinish` minus
/// `vsyncStart`, which is the only field any of these tests reads.
FrameTiming _timing(double ms, int frameNumber) {
  final us = (ms * 1000).round();
  return FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: us ~/ 2,
    rasterStart: us ~/ 2,
    rasterFinish: us,
    rasterFinishWallTime: us,
    frameNumber: frameNumber,
  );
}

/// Pumps frames that report their timings one frame late, the way the engine
/// does.
class _FrameDriver {
  _FrameDriver({required this.costMs, this.tailCostMs = 4.0});

  /// `totalSpan` of frame *i*, by ordinal. Frames past the end cost
  /// [tailCostMs].
  final List<double> costMs;
  final double tailCostMs;

  /// How many frames have been pumped.
  int pumped = 0;

  /// The ordinal of the next frame whose timing is still owed.
  int _delivered = 0;

  double costOf(int ordinal) =>
      ordinal < costMs.length ? costMs[ordinal] : tailCostMs;

  Future<void> pump() async {
    pumped++;
    // At most one frame in flight: pumping frame *i* is what lets frame *i-1*'s
    // timing arrive. The last frame pumped is therefore always still owed --
    // which is what `FrameTimingLog.drain` exists to collect.
    if (_delivered < pumped - 1) {
      final ordinal = _delivered++;
      SchedulerBinding.instance.platformDispatcher.onReportTimings!(
        <FrameTiming>[_timing(costOf(ordinal), ordinal)],
      );
    }
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the covering frame is the one reported, not the frame before it',
      () async {
    // Idle frame 2 covers -- the count Ruling 15 derives from
    // `kRestGateFrames = 2` -- and it is the expensive one. Frame 1 is the
    // in-between composite blit: cheap, and what the old attribution published.
    final driver = _FrameDriver(costMs: <double>[4.0, 90.0]);
    final log = FrameTimingLog()..arm();
    final SettleReport settle;
    try {
      settle = await runSettlePhase(
        log: log,
        pumpFrame: driver.pump,
        covered: () => driver.pumped >= 2,
        idleFrames: 5,
      );
    } finally {
      log.disarm();
    }

    expect(settle.frames, 2,
        reason: 'coverage was declared on the second idle frame');
    expect(settle.covered, isTrue);
    expect(settle.framesMissing, 0,
        reason: 'both settle frames must have reported a timing');
    expect(settle.coveringFrameMs, closeTo(90.0, 1e-9),
        reason: 'the covering frame cost 90ms; 4ms is the frame before it, '
            'which is what reading the arrival window rather than the ordinal '
            'reports');
  });

  test('the settle frame moves the reported figure', () async {
    // The same script, with the covering frame made arbitrarily expensive. If
    // the reported figure is read off the frame before it, this reads 4.0 in
    // both arms and the settle figure is inert -- a number that cannot move is
    // not a measurement.
    Future<SettleReport> run(double coveringCost) async {
      final driver = _FrameDriver(costMs: <double>[4.0, coveringCost]);
      final log = FrameTimingLog()..arm();
      try {
        return await runSettlePhase(
          log: log,
          pumpFrame: driver.pump,
          covered: () => driver.pumped >= 2,
          idleFrames: 5,
        );
      } finally {
        log.disarm();
      }
    }

    final cheap = await run(9.0);
    final dear = await run(900.0);
    expect(cheap.coveringFrameMs, closeTo(9.0, 1e-9));
    expect(dear.coveringFrameMs, closeTo(900.0, 1e-9));
    expect(dear.coveringFrameMs - cheap.coveringFrameMs, closeTo(891.0, 1e-9),
        reason: 'the settle figure must track the settle frame');
  });

  test('wall clock over the settle is the sum, not the last frame', () async {
    // Criterion 4 is "wall clock to a covered viewport, from the first frame
    // after the gesture ends to the frame that covers it". A many-frame settle
    // is the denominator arm's shape, and the last frame alone is not it.
    final driver = _FrameDriver(costMs: <double>[5.0, 6.0, 90.0]);
    final log = FrameTimingLog()..arm();
    final SettleReport settle;
    try {
      settle = await runSettlePhase(
        log: log,
        pumpFrame: driver.pump,
        covered: () => driver.pumped >= 3,
        idleFrames: 6,
      );
    } finally {
      log.disarm();
    }

    expect(settle.frames, 3);
    expect(settle.coveringFrameMs, closeTo(90.0, 1e-9));
    expect(settle.wallMs, closeTo(101.0, 1e-9),
        reason: '5 + 6 + 90 over the three frames of the settle; the idle '
            'frames after coverage are not part of it');
  });

  test('the idle frames after coverage are not charged to the settle',
      () async {
    // Frames 4 and 5 are pumped -- a cache that keeps asking for frames after
    // it covers must still be exercised -- but they are after the settle and
    // their cost is not criterion 4's.
    final driver =
        _FrameDriver(costMs: <double>[5.0, 6.0, 500.0, 500.0], tailCostMs: 0.0);
    final log = FrameTimingLog()..arm();
    final SettleReport settle;
    try {
      settle = await runSettlePhase(
        log: log,
        pumpFrame: driver.pump,
        covered: () => driver.pumped >= 2,
        idleFrames: 5,
      );
    } finally {
      log.disarm();
    }

    expect(settle.frames, 2);
    expect(settle.wallMs, closeTo(11.0, 1e-9));
    expect(driver.pumped, greaterThanOrEqualTo(5),
        reason: 'the full idle budget is still pumped');
  });

  test('the last idle frame is drained rather than dropped', () async {
    // Coverage on the very last idle frame: its own timing cannot have arrived
    // by the time its pump returns, so without the drain it is absent and the
    // figure reads 0.0 -- a fast frame, which is how a dropped sample gets
    // published as a good one.
    final driver = _FrameDriver(costMs: <double>[1.0, 2.0, 3.0, 42.0]);
    final log = FrameTimingLog()..arm();
    final SettleReport settle;
    try {
      settle = await runSettlePhase(
        log: log,
        pumpFrame: driver.pump,
        covered: () => driver.pumped >= 4,
        idleFrames: 4,
      );
    } finally {
      log.disarm();
    }

    expect(settle.frames, 4);
    expect(settle.framesMissing, 0);
    expect(settle.coveringFrameMs, closeTo(42.0, 1e-9));
    expect(settle.wallMs, closeTo(48.0, 1e-9));
    expect(driver.pumped, 5, reason: 'one extra frame collected the last one');
  });

  test('a settle that never covers says so', () async {
    final driver = _FrameDriver(costMs: <double>[7.0, 7.0, 7.0]);
    final log = FrameTimingLog()..arm();
    final SettleReport settle;
    try {
      settle = await runSettlePhase(
        log: log,
        pumpFrame: driver.pump,
        covered: () => false,
        idleFrames: 3,
      );
    } finally {
      log.disarm();
    }

    expect(settle.covered, isFalse);
    expect(settle.frames, 3, reason: 'the whole idle budget, as a floor');
    expect(settle.wallMs, closeTo(21.0, 1e-9));
  });

  test('a frame that never reports is a hole, not a zero', () async {
    // A driver that stops reporting altogether: the drain gives up after its
    // bound rather than hanging, and the shortfall is counted rather than
    // being averaged in as a free frame.
    final log = FrameTimingLog()..arm();
    final SettleReport settle;
    try {
      settle = await runSettlePhase(
        log: log,
        pumpFrame: () async {},
        covered: () => true,
        idleFrames: 3,
      );
    } finally {
      log.disarm();
    }

    expect(settle.frames, 1);
    expect(settle.framesMissing, 1);
    expect(settle.wallMs, 0.0);
  });

  test('the gesture window excludes the warm-up frames and keeps its tail',
      () async {
    // The whole phase's shape, without the parts `runTileZoomPhase` cannot run
    // in a debug build: two warm-up frames, a gesture, then a settle. The warm-
    // ups are the cheapest frames in the phase (a no-op repaint of a covered
    // generation) and the tail frames are among the dearest, so a sample padded
    // at the head and truncated at the tail is one whose p95 reads low.
    const gestureFrames = 2 * kZoomSteps;
    final costs = <double>[
      1.0, 1.0, // the two warm-up frames
      for (var i = 0; i < gestureFrames - 1; i++) 10.0,
      77.0, // the last gesture frame
    ];
    final driver = _FrameDriver(costMs: costs, tailCostMs: 3.0);
    final log = FrameTimingLog()..arm();
    final List<double?> gestureMs;
    try {
      for (var i = 0; i < kZoomWarmUpFrames; i++) {
        await log.pump(driver.pump);
      }
      final gestureStart = log.pumpedFrames;
      for (var i = 0; i < gestureFrames; i++) {
        await log.pump(driver.pump);
      }
      await runSettlePhase(
        log: log,
        pumpFrame: driver.pump,
        covered: () => true,
        idleFrames: 2,
      );
      gestureMs = log.msRange(gestureStart, gestureStart + gestureFrames);
    } finally {
      log.disarm();
    }

    final report = ZoomReport.from(
      gestureMs: gestureMs,
      gestureBakes: 0,
      gestureLiveDraws: 0,
      settle: SettleReport(
        frames: 1,
        covered: true,
        coveringFrameMs: 3.0,
        wallMs: 3.0,
        framesMissing: 0,
      ),
    );

    expect(report.gestureFramesMissing, 0);
    expect(report.gestureFrameMs.length, gestureFrames,
        reason: 'the 80-entry claim, enforced by the ordinal window');
    expect(report.gestureFrameMs.first, closeTo(10.0, 1e-9),
        reason: 'the first gesture frame, not a 1ms warm-up frame');
    expect(report.gestureFrameMs.last, closeTo(77.0, 1e-9),
        reason: 'the last gesture frame, which the old registration dropped');
    expect(report.gestureFrameMs.where((v) => v == 1.0), isEmpty,
        reason: 'no warm-up frame may appear in the gesture sample');
  });

  test('a short sample is counted, and length plus missing is the script',
      () async {
    // `gestureFrameMs.length + gestureFramesMissing == 2 * kZoomSteps` is the
    // invariant that makes the 80-entry claim enforced rather than asserted.
    final report = ZoomReport.from(
      gestureMs: <double?>[
        for (var i = 0; i < 2 * kZoomSteps; i++) i.isEven ? 10.0 : null,
      ],
      gestureBakes: 0,
      gestureLiveDraws: 0,
      settle: SettleReport(
        frames: 2,
        covered: true,
        coveringFrameMs: 9.0,
        wallMs: 12.0,
        framesMissing: 0,
      ),
    );

    expect(report.gestureFrameMs.length + report.gestureFramesMissing,
        2 * kZoomSteps);
    expect(report.gestureFramesMissing, kZoomSteps);
  });
}
