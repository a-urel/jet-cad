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
/// does, and -- when [backlogMs] is non-empty -- opens with a batch of timings
/// for frames that were pumped **before** the log was armed.
///
/// **The backlog is not decoration.** Without it this fixture models a stream
/// whose backlog is empty at `arm()`, which is the one case the device never
/// gives you: `main.dart`'s `runArm` pumps a camera-reset frame whose timing
/// cannot have arrived by the time its own pump returns, and the engine
/// batches its reports besides. A driver that only ever delivers frames it
/// pumped itself cannot reproduce a shifted stream, so it cannot fail on one.
class _FrameDriver {
  _FrameDriver({
    required this.costMs,
    this.tailCostMs = 4.0,
    this.backlogMs = const <double>[],
  });

  /// `totalSpan` of frame *i*, by ordinal. Frames past the end cost
  /// [tailCostMs].
  final List<double> costMs;
  final double tailCostMs;

  /// `totalSpan` of the frames pumped before the log was armed, oldest first.
  /// They are all delivered in one batch on the first [pump], which is where
  /// the engine would deliver them: after registration, at the head of the
  /// stream, in front of every frame the phase goes on to pump.
  final List<double> backlogMs;

  /// How many frames have been pumped.
  int pumped = 0;

  /// The ordinal of the next frame whose timing is still owed.
  int _delivered = 0;
  bool _backlogReported = false;

  /// Engine frame numbers are one sequence across both: the backlog takes
  /// `0 .. backlogMs.length - 1`, and post-arm ordinal *i* takes
  /// `backlogMs.length + i`. With no backlog this is the identity, which is
  /// what it was before backlogs existed.
  int get _frameNumberBase => backlogMs.length;

  double costOf(int ordinal) =>
      ordinal < costMs.length ? costMs[ordinal] : tailCostMs;

  void _report(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    SchedulerBinding.instance.platformDispatcher.onReportTimings!(timings);
  }

  List<FrameTiming> _takeBacklog() {
    if (_backlogReported) return const <FrameTiming>[];
    _backlogReported = true;
    return <FrameTiming>[
      for (var i = 0; i < backlogMs.length; i++) _timing(backlogMs[i], i),
    ];
  }

  Future<void> pump() async {
    pumped++;
    _report(_takeBacklog());
    // At most one frame in flight: pumping frame *i* is what lets frame *i-1*'s
    // timing arrive. The last frame pumped is therefore always still owed --
    // which is what `FrameTimingLog.drain` exists to collect.
    if (_delivered < pumped - 1) {
      final ordinal = _delivered++;
      _report(
        <FrameTiming>[_timing(costOf(ordinal), _frameNumberBase + ordinal)],
      );
    }
    await Future<void>.delayed(Duration.zero);
  }

  /// Delivers every timing still owed, without pumping anything.
  ///
  /// This is what a batch flush looks like from the framework's side while the
  /// rig is not pumping: the frames already rasterised report, and then the
  /// stream goes quiet. `FrameTimingLog.establishBaseline` waits for exactly
  /// that quiet, so a test hands this in as its `waitForBatch`.
  Future<void> flush() async {
    final owed = <FrameTiming>[..._takeBacklog()];
    while (_delivered < pumped) {
      final ordinal = _delivered++;
      owed.add(_timing(costOf(ordinal), _frameNumberBase + ordinal));
    }
    _report(owed);
    await Future<void>.delayed(Duration.zero);
  }
}

/// Arms [log] and drains whatever the engine owed before it was armed, the way
/// `runTileZoomPhase` does -- with [driver] standing in for the engine's batch
/// flush, so no test has to sleep through a real [kTimingBatchWindow].
Future<void> _armAndBaseline(FrameTimingLog log, _FrameDriver driver,
    {int framesPerRound = 2}) async {
  log.arm();
  await log.establishBaseline(
    driver.pump,
    framesPerRound: framesPerRound,
    batchWindow: Duration.zero,
    waitForBatch: (_) => driver.flush(),
  );
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
    // Non-null in both arms: the two `closeTo`s above already fail on a hole,
    // so the `!`s here cannot be what a broken attribution trips over.
    expect(dear.coveringFrameMs! - cheap.coveringFrameMs!, closeTo(891.0, 1e-9),
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
    expect(settle.coveringFrameMs, isNull,
        reason: 'the field carries the hole. `0.0` here is a *fast frame*, '
            'and a reader who takes this field without also reading '
            'framesMissing would publish the fastest number in the run as '
            "criterion 3's settle");
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

  // --- The backlog: what `arm()` alone does not do. ----------------------

  test('the baseline drains what arming did not, and rebases the ordinals',
      () async {
    // Three frames pumped before `arm()`: the camera reset `main.dart`'s
    // `runArm` does, plus whatever batch the engine was still holding. Every
    // one of them reports *after* registration.
    final driver = _FrameDriver(
      backlogMs: <double>[111.0, 222.0, 333.0],
      costMs: <double>[1.0, 1.0],
    );
    final log = FrameTimingLog();
    try {
      expect(log.baselineEstablished, isFalse);
      await _armAndBaseline(log, driver);

      expect(log.baselineEstablished, isTrue);
      expect(log.pumpedFrames, 0,
          reason: 'ordinal 0 must be the next frame pumped, not the fourth '
              'frame of somebody else\'s backlog');
      expect(log.reportedFrames, 0,
          reason: 'and nothing may already be sitting at that ordinal');
      expect(log.sawBacklog, isFalse);

      // A straggler from before the baseline, arriving after the reset: it is
      // dropped by frame number rather than taking ordinal 0.
      SchedulerBinding.instance.platformDispatcher.onReportTimings!(
        <FrameTiming>[_timing(999.0, 0)],
      );
      expect(log.reportedFrames, 0);
      expect(log.sawBacklog, isFalse);
    } finally {
      log.disarm();
    }
  });

  test(
      'the baseline rebases to the observed maximum, not the last-delivered '
      'timing', () async {
    // The engine gives no delivery-order guarantee within a batch. This
    // batch arrives with its true maximum frame number (7) buried in the
    // middle, and a smaller one (5) last -- the shape that distinguishes
    // `_reported.fold` (the maximum) from `_reported.last` (whatever the
    // batch happened to end with).
    final log = FrameTimingLog()..arm();
    var batchDelivered = false;
    try {
      await log.establishBaseline(
        () async {}, // Nothing to pump: this test drives delivery directly.
        framesPerRound: 1,
        batchWindow: Duration.zero,
        waitForBatch: (_) async {
          if (batchDelivered) return;
          batchDelivered = true;
          SchedulerBinding.instance.platformDispatcher.onReportTimings!(
            <FrameTiming>[_timing(1.0, 3), _timing(1.0, 7), _timing(1.0, 5)],
          );
        },
      );
      expect(log.baselineEstablished, isTrue);

      // Frame 6 predates the true maximum (7) but postdates the last-in-batch
      // entry (5). A `.last`-derived baseline would wrongly admit it as a
      // post-baseline frame; the maximum-derived baseline must still drop it
      // as a pre-baseline straggler.
      SchedulerBinding.instance.platformDispatcher.onReportTimings!(
        <FrameTiming>[_timing(999.0, 6)],
      );
      expect(log.reportedFrames, 0,
          reason: 'frame 6 is below the observed maximum (7) and must be '
              'dropped, not admitted because it exceeds the last-delivered '
              'entry (5)');
    } finally {
      log.disarm();
    }
  });

  test('a backlog reported after arming does not take the settle ordinals',
      () async {
    // The Blocking defect, one frame over. Costs 1.0 are the baseline frames;
    // the settle is 4.0 then 90.0, and coverage is on the second idle frame
    // (Ruling 15). Without the baseline, ordinal 0 of the settle is the
    // backlog's third entry and the published figure is a frame from before
    // the phase began.
    final driver = _FrameDriver(
      backlogMs: <double>[111.0, 222.0, 333.0],
      costMs: <double>[1.0, 1.0, 4.0, 90.0],
      tailCostMs: 3.0,
    );
    final log = FrameTimingLog();
    final SettleReport settle;
    // Counted here rather than off the log, so this predicate says the same
    // thing whether or not the ordinals were rebased.
    var idlePumps = 0;
    try {
      await _armAndBaseline(log, driver);
      settle = await runSettlePhase(
        log: log,
        pumpFrame: () async {
          idlePumps++;
          await driver.pump();
        },
        covered: () => idlePumps >= 2,
        idleFrames: 5,
      );
    } finally {
      log.disarm();
    }

    expect(settle.frames, 2);
    expect(settle.framesMissing, 0);
    expect(settle.coveringFrameMs, closeTo(90.0, 1e-9),
        reason: 'the covering frame. 333.0 is the backlog, 1.0 is a baseline '
            'frame, and 4.0 is the composite blit before it');
    expect(settle.wallMs, closeTo(94.0, 1e-9));
  });

  test('a backlog reported after arming does not pad the gesture window',
      () async {
    // The same shift, read off the other window: a sample padded at the head
    // with somebody else's cheap frames and truncated at the tail is one whose
    // p95 reads low.
    const gestureFrames = 2 * kZoomSteps;
    const backlogCost = 2.0;
    final costs = <double>[
      1.0, 1.0, // the two baseline frames
      1.0, 1.0, // the two warm-up frames
      for (var i = 0; i < gestureFrames - 1; i++) 10.0,
      77.0, // the last gesture frame
    ];
    final driver = _FrameDriver(
      backlogMs: <double>[for (var i = 0; i < 4; i++) backlogCost],
      costMs: costs,
      tailCostMs: 3.0,
    );
    final log = FrameTimingLog();
    final List<double?> gestureMs;
    try {
      await _armAndBaseline(log, driver);
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
    expect(report.gestureFrameMs.length, gestureFrames);
    expect(report.gestureFrameMs.first, closeTo(10.0, 1e-9),
        reason: 'the first gesture frame, not a backlog frame and not a '
            'baseline or warm-up frame');
    expect(report.gestureFrameMs.last, closeTo(77.0, 1e-9),
        reason: 'the last gesture frame, which a shifted window truncates');
    expect(report.gestureFrameMs.where((v) => v == backlogCost), isEmpty,
        reason: 'no frame from before the phase may appear in the sample');
    expect(report.gestureFrameMs.where((v) => v == 1.0), isEmpty,
        reason: 'and no baseline or warm-up frame either');
  });

  test('a backlog after the baseline is refused rather than published',
      () async {
    // `reportedFrames <= pumpedFrames` is what makes ordinal k the k-th frame
    // pumped: a frame reports only after it has rasterised, and it cannot
    // rasterise before it was pumped. More timings than pumps means frames
    // this log never pumped are in the stream, and every ordinal past them is
    // off by an amount nothing here can recover -- which is exactly the state
    // that published a composite blit as a settle, undetected.
    final driver = _FrameDriver(costMs: <double>[1.0, 1.0, 5.0, 6.0]);
    final log = FrameTimingLog();
    try {
      await _armAndBaseline(log, driver);
      expect(log.sawBacklog, isFalse);

      // Two frames this log never pumped, of the shape a late engine batch
      // has. Their frame numbers are past the baseline, so the frame-number
      // filter does not catch them -- the invariant is what does.
      SchedulerBinding.instance.platformDispatcher.onReportTimings!(
        <FrameTiming>[_timing(7.0, 9000), _timing(8.0, 9001)],
      );

      expect(log.sawBacklog, isTrue,
          reason: 'two timings across zero pumped frames');
      expect(() => log.msAt(0), throwsStateError,
          reason: 'a shifted stream yields no figure, loudly, rather than a '
              'plausible one quietly');
      expect(() => log.msRange(0, 2), throwsStateError);
    } finally {
      log.disarm();
    }
  });

  test('a stream that never goes quiet is refused, not measured', () async {
    // An engine that keeps reporting frames the rig never pumped never lets
    // the baseline establish itself. There is no ordinal to hand back, so
    // there is no figure -- and a rig that prints one anyway is the failure
    // this whole file exists for.
    var phantomFrameNumber = 9000;
    final log = FrameTimingLog()..arm();
    try {
      await expectLater(
        log.establishBaseline(
          () async {},
          framesPerRound: 1,
          batchWindow: Duration.zero,
          maxRounds: 3,
          waitForBatch: (_) async {
            SchedulerBinding.instance.platformDispatcher.onReportTimings!(
              <FrameTiming>[_timing(5.0, phantomFrameNumber++)],
            );
          },
        ),
        throwsStateError,
      );
      expect(log.baselineEstablished, isFalse);
    } finally {
      log.disarm();
    }
  });
}
