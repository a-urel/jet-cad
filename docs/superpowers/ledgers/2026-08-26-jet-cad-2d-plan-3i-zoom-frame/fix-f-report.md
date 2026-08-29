# Fix wave F — the measurement window, pinned

**Status: complete.** Commits `6f247fd`, `5f57372`, `f7febd2` on `main`, from
`d8d1332`. Territory: `apps/dev_harness_2d/` only, plus the mutation log.
`packages/jet_cad_2d_flutter/` and `packages/jet_cad_2d` untouched.
`macos/Runner.xcodeproj/project.pbxproj` untouched, `analysis_options.yaml`
untouched (`git status` verified clean of both before every commit; every
`git add` named explicit paths).

## Gate

```
apps/dev_harness_2d        CI=true flutter test --concurrency=1   56 passed  (baseline 49, +7 new)
apps/dev_harness_2d        CI=true flutter analyze                No issues found!
apps/dev_harness_2d        dart format --set-exit-if-changed      13 files (0 changed)
packages/jet_cad_2d_flutter CI=true flutter test                  413 passed, 1 skipped
packages/jet_cad_2d        CI=true dart test                      797 passed
```

## What changed

### 1. The window is created, at a fixed size, on every launch

`macos/Runner/MainFlutterWindow.swift` sets the **content** size to 1400x900
logical and centres the window. Content and not frame: the frame includes the
32-point title bar, so pinning the frame would have left Flutter a viewport 32
points short of the one named.

**This took two attempts, and the second one is the finding.** The obvious fix
— `setContentSize` in `awakeFromNib` — compiled, ran, and the app still printed
`window=800x600`. Instrumenting `setFrame(_:display:)` with
`Thread.callStackSymbols` named the culprit exactly:

```
JC-DEBUG setFrame (348.0, 158.0, 800.0, 632.0)
 2  AppKit  -[NSWindow _setFrameFromString:overrideTopLeft:...] + 1068
 3  AppKit  -[NSWindow restoreStateWithCoder:] + 1448
 4  AppKit  restorePersistentStateWithWindowRestoration + 1040
 5  AppKit  -[NSPersistentUIRestorer invokeRestoration:] + 568
```

macOS window state restoration runs **~1.4 s after the nib loads** — after
`awakeFromNib`, after the first Flutter frames — and puts the window back to
the frame the previous session left behind. The debug run showed
`awakeFromNib frame=(48, 6, 1400, 932)` and then, 1.4 s later,
`async frame=(348, 158, 800, 632)`. A restored frame is precisely "whatever the
operator last dragged"; a harness has to opt out of it rather than race it.

Two lines do that, and both are load-bearing:

- `self.isRestorable = false` — the window is excluded from restoration, so
  `restoreStateWithCoder:` never runs against it.
- `self.contentMinSize = self.contentMaxSize = 1400x900` — AppKit clamps every
  subsequent `setFrame:` to that range, so no later resize from any source,
  including an operator dragging an edge in the middle of a 240-frame script,
  can move the viewport under a measurement.

The `AppDelegate` returns `true` from `applicationSupportsSecureRestorableState`
and was left alone: that governs secure coding for restoration, not whether a
given window is restorable, and it is Flutter template code.

### 2. One constant, one source of truth

`kMeasurementViewport = Size(1400, 900)` in `lib/main.dart` replaces both
literal `Size(1600, 1200)`s (the app's starting camera fit, and the size handed
to `runTileZoomPhase`). Its doc comment records, in this order: what design
spec §5 pins (1600x1200 logical at dpr 2, with §5's memory predictions priced
against the 3200x2400 device rectangle); the arithmetic showing this machine
cannot provide it (desktop 1496x967, panel 3456x2234, so dpr 2 tops out at
1728x1117 and the height never reaches 1200 in any mode); that Ruling 20 is
where the human chose this size, having been shown the trade; and, set off as a
block quote so it cannot be skimmed past, that **every number taken at this
size is not comparable to the spec's priced predictions**, is not comparable to
any earlier figure from this harness either (those were taken at the nib
default of 800x600), and that §5's memory predictions remain untested.

The Swift constant and the Dart constant point at each other by name. They are
in different languages and cannot share a definition; the doc comment on each
says the other must hold the same size, and `reportR2Window` makes a divergence
between them print a warning on every run rather than sit silent.

### 3. The R2 zoom anchor is derived

`measurement_rig.dart` gains `r2ZoomAnchorFor(Size) => centre` and
`runR2ZoomStep`, and `runR2Rig` gains a **required** `viewport` parameter that
feeds it. The old hardcoded `Offset(800, 600)` was the centre of 1600x1200 and
of nothing else: at 800x600 — the size every figure this harness has ever
produced was actually taken at — it is the bottom-right *corner*, so R2's zoom
phase was dragging the document across the screen rather than scaling about a
centre, touching a different tile working set, for every recorded run.

`viewport` is required rather than defaulted for M25's reason: a default would
let a call site keep measuring at a viewport it is not in, silently.
`main.dart` passes the **real** window (deriving from `kMeasurementViewport`
there would reintroduce the hardcoded anchor under a new name), and
`integration_test/frame_timing_test.dart` passes the widget test's own view
size.

### 4. The window check fires on every RUN_R2 run

`warnIfZoomViewportMismatch` was called from one place: the
`tileCache != null && kZoomArms > 0` branch. `kZoomArms` defaults to 0, so the
commonest run there is — a plain `RUN_R2=true`, which is Plan 3i's Task 12
command line — printed its window size and said nothing about it being wrong.

The window line and the warning are now emitted together by `reportR2Window`,
called unconditionally. Welding them is deliberate and is what makes the
guarantee testable: `_driveR2` is private and everything below it opens with
`refuseDebugMode()`, so no unit test can asserta call site's *position*. It can
assert that the function every run calls to print `R2 app-run: window=` also
warns — and a mutant then has to reach into that function to silence the plain
path, which is in range of an assertion. See M28.

Still a warning and not a throw: the reasoning in the function's own doc
comment is unchanged. Hoisting changes when it fires, not what it does. The
message text was generalised from "tile zoom phase run at window=" to
"measurement run at window=", because it no longer speaks only for that phase.

## Tests

`apps/dev_harness_2d/test/measurement_viewport_test.dart`, 7 tests.

**The anchor**, at 1400x900 and 800x600 — deliberately not at 1600x1200, where
a hardcoded constant and a derived centre are the same point and the test would
pass under the mutant. Two shapes:

- `r2ZoomAnchorFor(viewport) == centre`, per size.
- `the step holds the viewport centre still at <size>`: drives `runR2ZoomStep`
  and reads the anchor **off the camera's own behaviour**. `zoomAt(p, f)` holds
  the world point under `p` fixed, so a composition of them holds it fixed too;
  whatever point the script actually zoomed about is the one point that did not
  move. This never mentions the formula, so a call site that bypasses the
  formula dies too.

  The fixture is far from the identity: scale 0.08, y flipped, **both**
  off-diagonal skew terms non-zero, origin ~5e6 units out. It asserts the
  script really moved the camera (`scale` lands at 0.947 of its start, because
  60 steps of 1.03 and 60 of 0.97 do not compose to 1) and that the *old*
  anchor's world point moved by >100 units against a 1e-3 tolerance — so
  "nothing moved" is not a way to pass.

**The warning**, three tests: a wrong size warns; the pinned size prints the
window line and does not warn; and a wrong size warns in a configuration where
no zoom arm will ever run.

## Mutations

Both new, both dead. M26 was the highest taken; M27 and M28 were free.
Procedure for each: `cp` the file(s) aside, mutate with `python3`/`perl`, run,
restore by `cp`, `diff` to prove the restore empty, run again. Never
`git checkout`. Full entries with verbatim transcripts are in
`docs/superpowers/notes/plan-3i-mutation-log.md`.

- **M27** — restore the hardcoded `Offset(800, 600)` anchor at the call site
  inside `runR2ZoomStep`. **RED**, two tests, one per viewport size. The
  failures are 62 world units off at 1400x900 and 265 at 800x600, against a
  1e-3 tolerance — and the growth between the two sizes is the defect stated
  numerically: the gap between the corner and the centre widens as the window
  shrinks.
- **M28** — drop `warnIfZoomViewportMismatch` from `reportR2Window` and put it
  back inside `main.dart`'s `kZoomArms > 0` branch (two files). **RED**, two
  tests. The mutant's `Actual` line is the 2026-08-29 smoke run's own output
  verbatim: `R2 app-run: window=800x600 dpr=2.0`, with nothing beside it.

## The real-app functional check

```sh
cd apps/dev_harness_2d
caffeinate -dimsu env CI=true flutter run -d macos --profile \
  --dart-define=TILES=on --dart-define=ENTITIES=5000 --dart-define=RUN_R2=true \
  > /tmp/jc-window-check.log 2>&1
```

- `flutter: R2 app-run: window=1400x900 dpr=2.0`
- reached `flutter: R2 app-run: done`
- nothing thrown, no `!!! WARNING` line, no exception anywhere in the log

**No number from this run is recorded here or anywhere else.** It was a
functional check of the window, not a measurement.

## Concerns

**1. A backgrounded harness window hangs the run, forever, silently. This is
the one that will cost a measurement session.**

`flutter run -d macos` printed `Failed to foreground app; open returned 1`, and
the run then stopped dead after `R2 app-run: driving started` — no window line,
no error, no progress. It sat there for **over ten minutes**. Running
`osascript -e 'tell application "dev_harness_2d" to activate'` unblocked it and
it completed normally in seconds.

The mechanism: `_pumpFrame` is `scheduleFrame()` then `await endOfFrame`, and
macOS stops driving frames for an occluded window, so `endOfFrame` never
completes and the whole script blocks on the first pump. It happened on the
first run of this fix and again on the instrumented run; both needed the
`activate`. **This is indistinguishable from a slow run** — there is no
timeout, no message, and the transcript's last line is a phase that started.
An operator who launches a tiles-on device run and switches to another window
while it warms up can lose the session to it.

Two things would help, neither in this wave's scope: an `activate` (or
`NSApp.activate(ignoringOtherApps:)` from the Swift side) as part of the launch
recipe, and a watchdog around `_pumpFrame` that prints something after a few
seconds of no frame instead of blocking mutely.

**2. The app does not exit after `R2 app-run: done`.** Known, and stated in
this wave's brief, but it is not written down in the harness itself. There is
no `exit()`, and `flutter run` stays attached, so any recipe that waits for the
process to end waits forever. Every run here was launched detached and killed
after `done` appeared in the log.

**3. Two constants must agree across a language boundary.**
`kMeasurementContentSize` in Swift and `kMeasurementViewport` in Dart both say
1400x900 and neither can reference the other. A silent divergence is possible
in principle; in practice `reportR2Window` now warns on every run when the real
window is not `kMeasurementViewport`, so a divergence prints rather than
hiding. That is the mitigation, and it is why the warning had to be hoisted out
of the arms branch before this was safe.

**4. The integration test's R2 row now anchors at its own view's centre.**
`integration_test/frame_timing_test.dart` passes `tester.view.physicalSize /
devicePixelRatio` — 800x600 — so its zoom anchor moved from the bottom-right
corner to (400, 300). That is the correct gesture, but it means the widget-test
R2 row is **not** comparable to any previously recorded widget-test R2 row. It
is the same class of break Ruling 20 already records for the app-run rows, and
it should be labelled the same way if that row is ever re-taken.

**5. §5's memory predictions remain untested, and criterion 9 is a cross-
viewport comparison.** Unchanged by this wave — it is Ruling 20's own recorded
consequence — but it now has a home in the code, in `kMeasurementViewport`'s
doc comment, rather than only in a progress file.
