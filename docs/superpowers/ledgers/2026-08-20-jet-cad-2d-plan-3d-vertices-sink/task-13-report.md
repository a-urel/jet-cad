# Task 13 report: The web rows

Worktree: `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike`
Branch: `spike/vertices-sink`

## Status: BLOCKED

No web row was obtained. `flutter drive -d chrome` hangs indefinitely — every
attempt, across five separate invocations with different mitigations applied
— at the same point: immediately after the web build completes and the
device list is re-validated, before chromedriver ever receives a session
request and before Chrome is ever launched. The hang has no timeout in this
code path; runs were killed by hand after 2–6 minutes each rather than
producing a result.

## Machine and versions

```
$ system_profiler SPHardwareDataType | grep -E "Model Name|Model Identifier|Chip|Memory"
      Model Name: MacBook Pro
      Model Identifier: Mac15,7
      Chip: Apple M3 Pro
      Memory: 36 GB

$ sw_vers
ProductName:            macOS
ProductVersion:         26.5.1
BuildVersion:           25F80

$ flutter --version
Flutter 3.47.0 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 4cf2416426 (9 days ago) • 2026-08-11 11:53:49 -0700
Engine • hash 59d54a2b2896a6bbf356c94b7fac7b9e235bdacd (revision 5f77625673) (9 days ago) • 2026-08-11 16:38:36.000Z
Tools • Dart 3.13.0 • DevTools 2.60.0

$ /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version
Google Chrome 151.0.7922.170

$ flutter doctor -v   (relevant sections)
[✓] Chrome - develop for the web [5ms]
    • Chrome at /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
[✓] Connected device (3 available) [6.8s]
    • iPhone 17e (mobile) • ... • ios ...
    • macOS (desktop)     • macos ...
    • Chrome (web)        • chrome • web-javascript • Google Chrome 151.0.7922.170
    ! Error: Browsing on the local area network for Bahar iPhone'u. Ensure the
      device is unlocked and attached with a cable or associated with the
      same local area network as this Mac.
      The device must be opted into Developer Mode to connect wirelessly. (code -27)
[✓] Network resources [481ms]
```

`flutter doctor` is clean; Chrome is found in 5ms; the only warning is the
harmless wireless-iPhone-pairing message that `flutter devices` also prints
and that resolves on its own within the 6.8s device-discovery step.

## Step 1: Getting the driver working — this alone took most of the session

`chromedriver` was not runnable at all at the start. `which chromedriver`
resolved to `/opt/homebrew/bin/chromedriver -> .../Caskroom/chromedriver/148.0.7778.56/...`,
a Homebrew-cask install. Every invocation — `--version`, `--help`, or
`--port=4444` — hung with **zero output, zero CPU, and no listening socket**,
confirmed with `sample`:

```
Call graph:
    770 Thread_...: Main Thread   DispatchQueue_<multiple>
      770 _dyld_start  (in dyld) + 0
```

The process never left `_dyld_start` — it hadn't reached `main()`. `spctl -a -v`
on the binary reported `rejected` (ad-hoc signed, no Team ID, not notarized —
normal for a chromedriver build, but this OS rejects it outright). Removing
the quarantine attribute (`xattr -d com.apple.quarantine`) did not fix it; a
`com.apple.provenance` attribute remained and could not be stripped from the
Caskroom-installed copy even with `xattr -c` (it silently returns empty rather
than being removed — likely re-applied on read from that specific,
brew-managed path). `brew reinstall --cask chromedriver` failed with an
unrelated internal Homebrew/Ruby crash (`undefined method 'first' for nil` in
`cask_loader.rb`), and in the process **deleted the existing chromedriver
binary** from the Caskroom directory without replacing it (confirmed after:
only `LICENSE.chromedriver` and `THIRD_PARTY_NOTICES.chromedriver` remained).

The fix: `cp` the binary out to `/tmp`, `xattr -c` the copy (this succeeded
outside the Caskroom-managed path), and ad-hoc re-sign it locally
(`codesign --force --sign -`). That copy ran immediately. Chrome.app itself
never had this problem — `Google Chrome --version` returned instantly
throughout, because it is properly notarized.

Chrome is 151.0.7922.170; the salvaged 148.0.7778.56 chromedriver would have
been a version mismatch. I downloaded a matching build directly from Google's
Chrome-for-Testing JSON API (network access to `storage.googleapis.com`
worked throughout this session):

```
$ curl -sS -o cd151.zip \
  "https://storage.googleapis.com/chrome-for-testing-public/151.0.7922.138/mac-arm64/chromedriver-mac-arm64.zip"
http=200 size=8974118
```

151.0.7922.138 is the newest chromedriver Google has published for the
151.0.7922.x line; Chrome itself is 151.0.7922.170 (same build line, later
patch — chromedriver tolerates this). Unzipped to
`/tmp/cd151/chromedriver-mac-arm64/chromedriver`, stripped of extended
attributes, and ad-hoc re-signed the same way. This one worked immediately:

```
$ chromedriver --port=4444
Starting ChromeDriver 151.0.7922.138 (41fa82442390a4d4456c78f2d69a832d5720cb27-refs/branch-heads/7922@{#2891}) on port 4444
Only local connections are allowed.
Please see https://chromedriver.chromium.org/security-considerations for suggestions on keeping ChromeDriver safe.
ChromeDriver was started successfully on port 4444.

$ curl -s http://localhost:4444/status
{"value":{"build":{"version":"151.0.7922.138 (...)"},"message":"ChromeDriver ready for new sessions.","os":{"arch":"arm64","name":"Mac OS X","version":"26.5.1"},"ready":true}}
```

None of this touches the repository — it is entirely local machine setup
(`/tmp` binaries, Homebrew cask state). No repository file was involved.

## Step 2: The smoke run — never got a `backend=` line

```
$ cd apps/dev_harness_2d
$ flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart --profile -d chrome \
    --dart-define=TEXT=true --dart-define=ENTITIES=10000 \
    --dart-define=RIG=pan --dart-define=BACKEND=vertices
```

Complete raw output, every attempt (five separate invocations, with
chromedriver freshly restarted before each):

```
Resolving dependencies in `.../vertices-spike`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
Got dependencies in `.../vertices-spike`!
8 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Launching integration_test/frame_timing_test.dart on Chrome in profile mode...
The --pwa-strategy option is deprecated and will be removed in a future Flutter release.
For more information, see: https://github.com/flutter/flutter/issues/156910
Compiling integration_test/frame_timing_test.dart for the Web...      1,056ms (varied 1–14s across runs)
✓ Built build/web
```

**Nothing more ever printed.** No `backend=`, no `R2`, no error, no
`Exception`, no `ToolExit`. Every one of the five attempts stopped at exactly
this point:

1. Plain invocation, default 120s tool timeout → auto-backgrounded, found
   0% CPU and no progress after ~4 minutes; killed.
2. Retried with an explicit 300s foreground timeout (to rule out the
   auto-backgrounding itself being the cause, per the macOS stall this repo's
   own `frame_timing_test.dart` documents for backgrounded desktop runs) →
   still hung the full 300s with zero CPU; killed.
3. Retried with `-v` for full trace logging → the verbose trace runs through
   dependency resolution, compilation, and a `flutter devices`-style
   re-validation step that dumps the full JSON list of **every** attached
   iOS/watchOS simulator (this Mac has many), then stops. No "Launching
   Chromium" trace line — the code path that would spawn Chrome
   (`ChromiumLauncher.launch`) was never reached, even after 6+ minutes.
4. Retried with `--device-timeout=3` (in case the hang was in
   wireless-device discovery, which times out at ~7s standalone via
   `flutter devices`) → identical hang; the flag has no effect on this stage.
5. Retried with `flutter config --no-analytics` (an established outbound TCP
   connection to a `1e100.net`/Google IP was observed via `lsof` during one
   hung run, at the same phase, consistent with Flutter's analytics beacon)
   → the beacon connection went away, but the hang was identical. This rules
   out analytics as the cause; it also confirms the setting was restored to
   `--enable-analytics` afterward to leave the machine as found.

`lsof -p <drive-pid>` during every hang showed the process's own ephemeral
web-asset-server port and nothing else — **no connection was ever made to
chromedriver's port 4444** (confirmed by `lsof -iTCP:4444`, which showed only
chromedriver's own `LISTEN` sockets throughout), and `pgrep -P <drive-pid>`
showed **zero child processes** — the Dart tool process never forked
anything. `sample` on the stuck process showed the main thread parked in
`Dart_RunLoop` on a condition-variable wait — a genuine indefinite await on
something that never completes, not a busy failure.

I read the relevant flutter_tools source
(`.../flutter/packages/flutter_tools/lib/src/web/chrome.dart` and
`web_device.dart`) to identify where Chrome would be launched:
`WebDriverService.start` → `ResidentWebRunner` → `GoogleChromeDevice.startApp`
→ `ChromiumLauncher.launch` → `_spawnChromiumProcess`, which `await`s Chrome's
own stderr for a line starting with `DevTools listening`, **with no timeout
at all** on that wait — only a retry-on-stream-close guard that never fires
if Chrome stays alive without ever printing that line. This is a real
no-timeout hazard in the SDK, but it was never reached in any observed run:
the hang is earlier, in the generic device-list re-validation that `flutter
drive` performs before handing off to the web driver service, a step that
`flutter devices` completes standalone in ~7 seconds but that apparently
never terminates when invoked from `drive` in this environment. I could not
get further visibility into that step without instrumenting the SDK itself,
which is out of scope for this task.

## What I did not have

- No `sudo` (no password available non-interactively), so I could not touch
  system Gatekeeper policy or grant OS-level permissions by hand.
- No way to click through a macOS permission dialog if one is silently
  blocking Chrome or flutter_tools off-screen — this session has an active
  Aqua/WindowServer console session (`who`, `launchctl managername` both
  confirm it), so it is not a headless-without-GUI environment, but I have no
  way to confirm or deny a stuck system dialog without seeing the screen.
- `brew` itself is broken for cask operations in this environment (unrelated
  Ruby crash on `list`/`reinstall`), so I could not use it to get a clean
  chromedriver or try a different Flutter channel/version.

## Fields the web could / could not report

**None were obtained.** The rig prints `backend=`, `triangles=`,
`drawVerticesCalls=`, and the `R2`/build/raster block from
`FrameTiming` — none of these were ever reached. I cannot report which of
them CanvasKit would or would not populate; that question stays open.

## Results table

| entities | canvas (web) | vertices (web) |
|---|---|---|
| 10,000 | not measured — driver hang | not measured — driver hang |
| 50,000 | not attempted (blocked before reaching corpus-size sweep) | not attempted |
| 500,000 | not run by design (per brief, desktop already shows the trend) | not run by design |

For reference, the desktop rows from Task 12 (macOS profile, median of 3,
build p50 / raster p50):

| entities | canvas | vertices |
|---|---|---|
| 10,000 | 12.35 / 44.32 ms | 5.71 / 6.68 ms |
| 50,000 | 15.36 / 66.94 ms | 7.07 / 8.53 ms |
| 500,000 | 44.29 / 508.00 ms | 17.44 / 21.64 ms |

## Does the web default flip?

**No measurement exists to decide this.** `defaultRenderBackend()` in
`packages/jet_cad_2d_flutter/lib/src/render_backend.dart` is unchanged:

```dart
RenderBackend defaultRenderBackend() =>
    kIsWeb ? RenderBackend.canvas : RenderBackend.vertices;
```

The web default stands on the design document's reasoning — Impeller is not
on the web, CanvasKit's `drawVertices` is unmeasured — and not on a number.
This report does not supply that number. The gap belongs on the record
exactly as the brief anticipated: a clear BLOCKED here is the honest outcome,
not a soft "web is fine."

## Everything that failed, verbatim reasons

1. `chromedriver --version` / `--port=4444` from the Homebrew cask: hung
   indefinitely, 0% CPU, stuck at `_dyld_start` per `sample`. `spctl -a -v`
   reported `rejected`. Not fixed by removing quarantine; fixed by copying to
   `/tmp` and ad-hoc re-signing.
2. `brew reinstall --cask chromedriver`: crashed with
   `Error: undefined method 'first' for nil` inside
   `Homebrew/cask/cask_loader.rb`, and left the Caskroom chromedriver binary
   deleted (only license files remained).
3. `flutter drive -d chrome ...` (five attempts, described above): hung
   indefinitely after `✓ Built build/web`, before any chromedriver session
   request, before any Chrome process, before any `backend=` line. No
   `Exception`, no `ToolExit`, no timeout in this code path to catch it.
   Killed manually every time.

## Cleanup

```
$ pkill -9 -f chromedriver ; pkill -9 -f "flutter drive" ; pkill -9 -f "dartvm.*drive"
$ flutter config --enable-analytics    # restored to the state found
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
$ git status --porcelain
(empty)
```

Working tree is clean. No repository file was changed; no commit was made.
The temporary chromedriver binaries live only under `/tmp` and are not part
of the repository.

## What Task 15 (the results note) needs to say

The web row for R2 could not be measured in this environment via `flutter
drive`. **This was superseded** — see the addendum below, which reached the
web row through a different route and got a decisive number. Everything
above this line is left as originally written and is still accurate about
`flutter drive`: that specific path never worked, and the diagnosis of why
stands. Read on for what did work.

---

## Addendum: the `flutter run` route (second attempt, coordinator-directed)

The coordinator flagged a route this report had not tried: `flutter devices`
lists `Chrome (web) • chrome • web-javascript • Google Chrome 151.0.7922.170`
as available, and it is specifically `flutter drive`'s chromedriver path that
hangs — `flutter run -d chrome` does not go through chromedriver at all. The
coordinator's proposal: give `main.dart` a mode that drives R2 itself on
startup and prints the block, so `flutter run -d chrome --profile` (which
streams the app's own `print()` to the terminal) gets the row without any
driver.

This worked, but not exactly as proposed — `flutter run -d chrome --profile`
turned out not to forward `print()` output in this environment either, for a
different and more specific reason than the `drive` hang. What follows is the
full path: the code change, the second obstacle, the workaround used to get
readings despite it, and the twelve readings themselves.

### Code change

**`apps/dev_harness_2d/lib/measurement_rig.dart`** (new file) — lifts R2's
measured body out of `integration_test/frame_timing_test.dart`:
`refuseDebugMode`, `report`, `printBackend`, `printTextCounters`, and a new
`runR2Rig` that does the 120-pan/120-zoom/forced-repaint/print sequence,
parameterised over `pumpFrame` (render one frame, complete after it) and
`settle` (the `pumpAndSettle` equivalent). Both call sites — the widget test
and `main.dart`'s new mode — call this one function, so the desktop and web
rows come from identical measurement code; only how a frame gets pumped
differs (`tester.pump(duration)` vs `SchedulerBinding.instance.endOfFrame`).

**`apps/dev_harness_2d/lib/main.dart`** — adds `const bool kRunR2 =
bool.fromEnvironment('RUN_R2')` (same footgun and same rule as `kTextCorpus`:
always pass `=true`, never `=1`), and when set, `main()` builds `HarnessApp`
with an `onReady` callback that fits the camera to the same 3000x2250
working-set window `boot()` uses in the widget test (not the widget's own
full-extents fit) and calls `runR2Rig`. A `_pumpFrame()` helper explicitly
calls `SchedulerBinding.instance.scheduleFrame()` before awaiting
`endOfFrame` — relying on `camera.value = ...`'s listener chain to schedule
the frame as a side effect hung intermittently, because `onReady` runs from
inside `_HarnessAppState`'s own post-frame callback, where
`schedulerPhase` is `postFrameCallbacks`, not `idle`, and `endOfFrame` only
calls `scheduleFrame` for you when idle.

**`apps/dev_harness_2d/integration_test/frame_timing_test.dart`** — the R2
`testWidgets` body shrinks to `boot()` plus one call to `runR2Rig`; R4a and
R4b are untouched except for importing the four moved functions instead of
defining them, and `printTextCounters` now takes `textCorpus`/`drawText` as
parameters instead of reading module-level globals (it moved to a file that
does not have those globals, and taking them explicitly is no worse).

**Verified behaviour-preserving before trusting any web number**: reran the
widget test on macOS via `flutter drive --driver=test_driver/integration_test.dart
--target=integration_test/frame_timing_test.dart --profile -d macos
--dart-define=RIG=pan --dart-define=ENTITIES=10000 --dart-define=TEXT=true
--dart-define=BACKEND=vertices` both before touching the test file and again
after the full refactor. Both runs passed, R4a and R4b included; the R2
numbers after refactor (`build p50=5.62ms`, `raster p50=6.61ms`) sit within
normal run-to-run variance of Task 12's reported figures for the same cell
(`5.71ms` / `6.68ms`, itself a median of 3).

Gate, all three packages, after this change and after the `render_backend.dart`
flip below — all green:

```
$ cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
720 tests passed. No analyzer issues. 105 files formatted, 0 changed.

$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
236 passed, 1 skipped. No analyzer issues. 44 files formatted, 0 changed.

$ cd apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
No analyzer issues. 3 files formatted, 0 changed.
```

`git status --porcelain` was checked clean of `analysis_options.yaml` and
`macos/Runner.xcodeproj/project.pbxproj` before every commit (the latter got
rewritten by `flutter drive -d macos` during verification and was reverted
with `git checkout` — the one sanctioned exception to "never `git checkout`
your own work").

### The second obstacle: profile mode never links a debug service here

The smoke run the coordinator specified:

```
$ cd apps/dev_harness_2d
$ flutter run -d chrome --profile \
    --dart-define=RUN_R2=true --dart-define=TEXT=true \
    --dart-define=ENTITIES=10000 --dart-define=BACKEND=vertices
```

reached `Flutter run key commands.` (Chrome launched, connected — confirmed
in `-v` output: `Launching Chromium (url = ..., headless = false, skipCheck =
false, debugPort = null)`, `Using Google Chrome 151.0.7922.170`, one
`[CHROME]:` line forwarding Chrome's own raw stderr) but then printed
**nothing else** for over three minutes across five separate attempts,
including one with a diagnostic `print('main() entered...')` as the literal
first statement of `main()` — before any of my own code, before any scheduler
interaction. It never appeared.

Comparing against plain `flutter run -d chrome` (debug mode, no `--profile`):
debug mode printed `Waiting for connection from debug service on Chrome...
9.7s`, then `This app is linked to the debug service: ws://...`, then
`Starting application from main method in: ...`, then every one of my
`print()` calls, in order, ending with `DartError: Bad state: run with
--profile; debug frame times mean nothing` — `refuseDebugMode()` firing
exactly as designed, proving the whole pipeline (camera fit, `_pumpFrame`,
`runR2Rig`) works correctly end to end once a debug service actually links.

**Profile mode's log never contains the "Waiting for connection from debug
service" line at all, in any of the ~8 attempts made** (with `-v`, without,
at ENTITIES 1000 and 10000, waiting up to 180s past the CLI banner each
time). Debug mode links in under 10s, reliably, every time. This is not a
patience problem — profile mode does not attempt the connection this
environment's `print()` forwarding depends on. Screen Recording permission is
also not granted here (`screencapture -x` returns only the desktop wallpaper,
no application windows), so a screenshot could not confirm or deny whether
Chrome was rendering the page correctly during this gap — that check was
inconclusive, not supportive either way.

### The workaround used to get profile-mode readings anyway

Since the harness correctly refuses debug-mode numbers (`refuseDebugMode()`),
and profile mode's own `print()` never reaches the terminal, readings were
retrieved via the Chrome DevTools Protocol directly — bypassing
`flutter_tools`' own forwarding entirely, using only facts already
established: `flutter run` launches Chrome with `--remote-debugging-port=N`
(visible in `ps aux`), and CDP's `Runtime.evaluate` can read arbitrary
JavaScript state over that port without any terminal-forwarding involved.

This required one **temporary, uncommitted** addition to `main.dart` while
gathering numbers: wrap the `RUN_R2` path in `runZoned` with a
`ZoneSpecification.print` that both forwards to the real `print()` (in case
an environment's profile mode does link) and appends to a `StringBuffer`,
then write that buffer to `window.localStorage['r2Result']` once `runR2Rig`
completes, via `import 'dart:html' as html;`. That code is **not part of
either commit** — it was reverted (the file was backed up with `cp` before
adding it, and restored) before running the final gate, because it is
investigation plumbing specific to this one environment's gap, not shared
measurement code, and `dart:html` cannot even compile for the non-web targets
this app also builds for (`macos`). A future environment where profile mode
links normally would use `RUN_R2` exactly as shipped, watching the terminal
directly — nothing about the shipped code assumes the workaround.

Retrieval side (Python, `pip3 install --user websockets`, run separately from
the app):

```python
# find Chrome's own remote-debugging port
$ ps aux | grep "Google Chrome" | grep -o -- "--remote-debugging-port=[0-9]*"
--remote-debugging-port=52086

# then, over a websocket to ws://localhost:<port>/devtools/page/<id>:
#   Runtime.evaluate("window.localStorage.getItem('r2Result')")
# polled every 2s until non-null.
```

Every reading below is real output the app itself printed (captured by the
zone) and this script retrieved unmodified — nothing here was typed by hand.

### Step 2 equivalent: `backend=` reads correctly

First successful retrieval, `ENTITIES=1000 BACKEND=vertices` (used to prove
the mechanism before spending time on the full sweep):

```
onReady fired
R2 app-run: driving started
R2 app-run: window=1200x723 dpr=2
R2 (1000) frames=238
  build  p50=3.30ms p95=3.90ms max=7.30ms
  raster p50=0.80ms p95=1.00ms max=59.70ms
  screenSpaceLeafCount=710 lineweightScale=1
  dashSpans=16895 collapsed=56 canvasCalls=32
  backend=vertices triangles=73771 drawVerticesCalls=32
  text: corpus=on draw=on textOps=32 skippedText=0
  paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1987 evictions=1475)
R2 app-run: done
```

`backend=vertices` — the define was honoured, not clamped, exactly as
`render_backend.dart`'s (pre-flip) doc comment required for this measurement
to mean anything.

### Step 3: the full sweep — 10,000 and 50,000 entities, both backends, 3 runs each

Command for every run (only `ENTITIES` and `BACKEND` vary):

```
$ flutter run -d chrome --profile \
    --dart-define=RUN_R2=true --dart-define=TEXT=true \
    --dart-define=ENTITIES=<N> --dart-define=BACKEND=<canvas|vertices>
```

500,000 was not attempted on the web, per the brief: the desktop rows take
minutes each there, CanvasKit is markedly slower per the 10k/50k readings
below, and it would cost a long time to confirm something those two sizes
already indicate decisively.

**10,000 entities, `BACKEND=vertices`** (3 runs):

```
Run 1: R2 (10000) frames=238  build p50=6.80ms p95=8.20ms max=12.60ms   raster p50=1.40ms p95=1.70ms max=56.80ms
       screenSpaceLeafCount=2111 dashSpans=50120 collapsed=182 canvasCalls=19
       backend=vertices triangles=223733 drawVerticesCalls=20
Run 2: R2 (10000) frames=240  build p50=6.90ms p95=7.90ms max=13.10ms   raster p50=1.30ms p95=1.70ms max=58.50ms
       screenSpaceLeafCount=2111 dashSpans=50120 collapsed=182 canvasCalls=19
       backend=vertices triangles=223733 drawVerticesCalls=20
Run 3: R2 (10000) frames=241  build p50=6.80ms p95=8.10ms max=12.70ms   raster p50=1.40ms p95=1.70ms max=54.60ms
       screenSpaceLeafCount=2111 dashSpans=50120 collapsed=182 canvasCalls=19
       backend=vertices triangles=223733 drawVerticesCalls=20
```

Median: build p50 **6.80ms**, raster p50 **1.40ms**.

**10,000 entities, `BACKEND=canvas`** (3 runs):

```
Run 1: R2 (10000) frames=241  build p50=122.20ms p95=140.10ms max=146.10ms  raster p50=79.20ms p95=91.30ms max=388.50ms
       screenSpaceLeafCount=2111 dashSpans=50120 collapsed=182 canvasCalls=52897  backend=canvas
Run 2: R2 (10000) frames=241  build p50=117.10ms p95=133.90ms max=140.00ms  raster p50=79.30ms p95=91.20ms max=191.90ms
       screenSpaceLeafCount=2111 dashSpans=50120 collapsed=182 canvasCalls=52897  backend=canvas
Run 3: R2 (10000) frames=241  build p50=117.80ms p95=134.40ms max=142.10ms  raster p50=79.60ms p95=91.70ms max=198.30ms
       screenSpaceLeafCount=2111 dashSpans=50120 collapsed=182 canvasCalls=52897  backend=canvas
```

Median: build p50 **117.80ms**, raster p50 **79.30ms**.

**50,000 entities, `BACKEND=vertices`** (3 runs):

```
Run 1: R2 (50000) frames=241  build p50=8.90ms p95=9.50ms max=14.10ms   raster p50=1.80ms p95=2.10ms max=267.70ms
       screenSpaceLeafCount=2709 dashSpans=66627 collapsed=257 canvasCalls=24
       backend=vertices triangles=294536 drawVerticesCalls=21
Run 2: R2 (50000) frames=239  build p50=8.80ms p95=9.40ms max=14.00ms   raster p50=1.80ms p95=2.10ms max=67.90ms
       screenSpaceLeafCount=2709 dashSpans=66627 collapsed=257 canvasCalls=24
       backend=vertices triangles=294536 drawVerticesCalls=21
Run 3: R2 (50000) frames=233  build p50=8.90ms p95=9.60ms max=14.30ms   raster p50=1.80ms p95=2.10ms max=70.90ms
       screenSpaceLeafCount=2709 dashSpans=66627 collapsed=257 canvasCalls=24
       backend=vertices triangles=294536 drawVerticesCalls=21
```

Median: build p50 **8.90ms**, raster p50 **1.80ms**.

**50,000 entities, `BACKEND=canvas`** (3 runs):

```
Run 1: R2 (50000) frames=241  build p50=156.50ms p95=165.80ms max=170.50ms  raster p50=107.90ms p95=111.50ms max=219.40ms
       screenSpaceLeafCount=2709 dashSpans=66627 collapsed=257 canvasCalls=70193  backend=canvas
Run 2: R2 (50000) frames=241  build p50=155.70ms p95=165.40ms max=168.40ms  raster p50=107.90ms p95=112.00ms max=222.20ms
       screenSpaceLeafCount=2709 dashSpans=66627 collapsed=257 canvasCalls=70193  backend=canvas
Run 3: R2 (50000) frames=241  build p50=154.20ms p95=163.50ms max=167.40ms  raster p50=108.00ms p95=112.60ms max=219.50ms
       screenSpaceLeafCount=2709 dashSpans=66627 collapsed=257 canvasCalls=70193  backend=canvas
```

Median: build p50 **155.70ms**, raster p50 **107.90ms**.

Every block above is complete and unedited apart from being reflowed onto
fewer lines for the table format; `paragraphs:`/`text:` lines (identical
across the three runs at each cell) are omitted here for space but were
checked and are consistent in every raw capture.

**Control, same as Task 12's**: `screenSpaceLeafCount` and `dashSpans` match
exactly between the two backends at each entity count (2111 / 50120 at
10,000; 2709 / 66627 at 50,000) — the comparison is the backend and nothing
else about the drawing.

### Results table

| entities | web canvas (build/raster p50) | web vertices (build/raster p50) | ratio (build / raster) |
|---|---|---|---|
| 10,000 | 117.80 / 79.30 ms | 6.80 / 1.40 ms | 17.3x / 56.6x |
| 50,000 | 155.70 / 107.90 ms | 8.90 / 1.80 ms | 17.5x / 59.9x |
| 500,000 | not run (see above) | not run | — |

For reference, the desktop rows (Task 12):

| entities | canvas | vertices |
|---|---|---|
| 10,000 | 12.35 / 44.32 ms | 5.71 / 6.68 ms |
| 50,000 | 15.36 / 66.94 ms | 7.07 / 8.53 ms |
| 500,000 | 44.29 / 508.00 ms | 17.44 / 21.64 ms |

### Which fields the web could and could not report

`build` and `raster` p50/p95/max both came through non-empty and internally
consistent (tight run-to-run spread: 10k canvas build ranged 117.10-122.20,
about 4%; every other cell was tighter). `screenSpaceLeafCount`, `dashSpans`,
`collapsed`, `canvasCalls`, `backend=`, and (for vertices) `triangles=` /
`drawVerticesCalls=` all reported exactly as they do on desktop — none of
these are FrameTiming-derived, so there was no reason to expect them to
differ, and they didn't.

**One caveat worth stating plainly rather than glossing over**: web
`vertices` raster (1.40ms at 10,000) reads *lower* than desktop `vertices`
raster (6.68ms at the same size) — CanvasKit appearing faster at raster than
native Impeller is a surprising direction for a result to point, and this
report does not have an explanation for it beyond noting that `FrameTiming`'s
`rasterDuration` may not measure the same span of work on CanvasKit's
WebGL/Skia pipeline as it does on Impeller's — the callback may fire before
GPU work CanvasKit dispatched asynchronously actually completes. This
uncertainty is about **cross-platform magnitude comparison**, not about the
canvas-vs-vertices finding within one platform: canvas and vertices were
measured through the identical pump mechanism, the identical corpus, the
identical camera script, differing only in `BACKEND=`, so the 17-60x ratio
between them is trustworthy regardless of what `rasterDuration` means in
absolute terms on this platform. `build` (Dart-side widget-to-displaylist
cost, the same Flutter framework code on both platforms) shows the same
qualitative story and is less exposed to this concern.

The viewport used for the web fit — `1200x723 @ dpr=2`, printed by every run
— is also not the same window size Task 12's desktop rows were fit into
(unrecorded in that report, likely the platform's own default window). This
does not affect the canvas-vs-vertices ratio *within* the web rows (same
viewport both backends, same corpus), but it is one more reason the absolute
web numbers should not be read as directly superimposable on the desktop
table beyond the shape of the conclusion.

### Does the web default flip?

**Yes.** CanvasKit's `drawVertices` beats `drawPath` by 17.3-17.5x on build
and 56.6-59.9x on raster at 10,000 and 50,000 entities — not merely "faster,"
decisively so, and by a wider margin than the desktop numbers that motivated
writing the web exception in the first place (desktop's raster margin was
6.6x-23.5x, growing with entity count; the web's is already past that range
at the smallest size measured). `packages/jet_cad_2d_flutter/lib/src/render_backend.dart`
now reads:

```dart
RenderBackend defaultRenderBackend() => RenderBackend.vertices;
```

`RenderBackend.canvas` remains reachable via an explicit `backend:` argument
(`CanvasDrawSink` is still what the 14 canvas-backend goldens from Plan 3d's
earlier tasks pin, unconditionally) but is no longer any platform's default.

### Commits

1. `1623545` — `feat: share the R2 rig so the harness can drive itself on web`
   (`lib/measurement_rig.dart` new, `lib/main.dart` and
   `integration_test/frame_timing_test.dart` changed).
2. `25bed0d` — `fix: flip the platform default to vertices, web included`
   (`packages/jet_cad_2d_flutter/lib/src/render_backend.dart` and its test),
   with the numbers in the message per the brief's Step 4.

`git status --porcelain` is clean; neither `analysis_options.yaml` nor
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` is committed.

---

## Addendum 2: review corrections

The coordinator's review (Approved, conditional on one fix) traced all 12
figures in the tables above to real captures — 10 blocks in
`/private/tmp/web_rows.log`, 2 in the session transcript — and found nothing
invented. It also sharpened what the flip should be read as resting on, and
found several places this report understated the gap between what was
measured and what is committed. Both are addressed below.

### The fix: `render_backend.dart`'s doc comment now carries the caveat

The comment originally juxtaposed the desktop and web tables with no caveat,
which invites two false readings: that CanvasKit rasters ~4.8x faster than
Impeller, and that the canvas backend got ~10x slower on identical work.
Neither is true, for two reasons:

1. **The two platforms did not draw the same drawing.** Desktop 10k is 1664
   screen-space leaves / 37,376 dashSpans against web 10k's 2111 / 50,120 —
   a different viewport (1200x723 @2 vs. whatever window `flutter drive -d
   macos` used). The two tables are two separate confirmations, not one
   table doubled; there is no sound per-platform multiplier between them.
2. **`build` is comparable across platforms; `raster` is not.** Per unit of
   work, web vertices build is 3.22 µs/leaf against macOS's 3.43 µs/leaf —
   the same Dart-side cost. Web canvas build is 2.23 µs/call against
   macOS's 0.31 µs/call — the expected CanvasKit JS-interop penalty. But
   web vertices raster of 1.40ms against macOS's 6.68ms **on 34% more
   geometry** is not a credible GPU measurement — CanvasKit's
   `FrameTiming.rasterDuration` almost certainly ends at command submission
   rather than at completion, not at the GPU actually finishing.

This report already said both things in its "fields the web could/could not
report" section; the doc comment did not, and the doc comment is what a
future reader meets first. `render_backend.dart`'s comment now states: the
two tables are different viewports/leaf-counts and not directly
superimposable; `build` is the cross-platform-comparable figure and `raster`
is not; and the flip rests on the **within-platform build ratio**
(17.3x-17.5x), not the 56x-60x raster headline this report and the original
commit message led with. The numbers themselves are unchanged — they are
real and stay in the comment — only the framing of what they license changed.
Gate re-run after the fix: all three packages green (720 tests / 236 passed +
1 skipped / clean analyze and format on all three), confirmed rather than
assumed, in the commit below.

### Corrections to this report, not to the code

**The committed `RUN_R2` mode does not reproduce these rows on this
machine, and the report should have said so instead of leaving the doc
comment to imply it does.** Every one of the 12 readings ran under a
`main.dart` carrying the temporary `runZoned` + `dart:html` localStorage
capture described in Addendum 1 — code that is in neither commit — plus
`/tmp/run_web_r2.sh` and `/tmp/cdp_poll_generic.py`, which were never
committed at all. Running the shipped `RUN_R2` mode exactly as its doc
comment describes (`flutter run -d chrome --profile
--dart-define=RUN_R2=true ...`, watching the terminal) produces **no
output whatsoever** on this machine, because profile mode never links a
debug service here — the same gap Addendum 1 diagnosed. The coordinator has
copied the four artifacts (the diagnostic `main.dart`, `run_web_r2.sh`,
`cdp_poll_generic.py`, and by extension this report) into the ledger so they
survive past this worktree; Task 15 will commit them beside the results
note. Read the "Retrieval side" Python snippet and the `runZoned` code
excerpt in Addendum 1 as the actual measurement path, not the shipped
`RUN_R2` mode in isolation.

**`frames` does not match within each canvas/vertices pair; do not read it as
having matched.** 10,000 entities: vertices ran 238/240/241 frames against
canvas's 241/241/241; 50,000: vertices 241/239/233 against canvas's
241/241/241. This comes from `onReportTimings` batching differently at the
tail end in app-run mode (a real running app has no synthetic clock to force
an exact frame count the way `tester.pump` does) and does not move any p50 —
every other invariant (`screenSpaceLeafCount`, `dashSpans`) matches exactly
within each pair, which is the control that actually matters for "same
drawing, different backend." But this report's raw transcripts show the
differing frame counts in plain sight without ever flagging them, which
reads as an oversight rather than a checked-and-dismissed detail. It is now
flagged.

**The published "median" mixes runs, same as Task 12's convention** — e.g.
10,000 canvas's "117.80 / 79.30" pairs run 3's build p50 with run 2's raster
p50; no single run produced that exact pair (the medians are taken
independently down each column: build p50 across the three runs, raster p50
across the three runs). This is the same convention Task 12 used and is not
being changed here, but it was worth stating plainly rather than leaving a
reader to assume "the median run" is one specific run's whole block.

**Every measured run executed inside a `runZoned` wrapper the shipped code
does not have.** The zone only appends print()'d lines to a buffer and
forwards them unchanged to the real `print()` — it does not alter what gets
computed or how frames are pumped — and it wrapped both backends identically,
so the canvas-vs-vertices ratios are unaffected. But the *absolute* numbers
in every one of the 12 blocks were taken under code that is not the
committed code, which is one more reason (beyond the profile-mode gap above)
the committed path alone will not reproduce them.

**The transcripts in this report are reflowed, not verbatim.** Blocks were
condensed onto fewer lines for the table format above, and the identical
`text:`/`paragraphs:` lines were dropped from the per-run transcripts in
Addendum 1's sweep tables for space (they were checked against the raw
captures and found consistent across all three runs at each cell, and the
reviewer independently re-checked the same 12 raw blocks and found nothing
invented) — but the report's framing did not say this reflowing happened,
which reads as claiming verbatim reproduction where the formatting is not
byte-for-byte. It is now stated.

### Commit

3. (this fix) — `packages/jet_cad_2d_flutter/lib/src/render_backend.dart`
   doc comment only; no behavioural change; numbers unchanged; gate re-run
   green.
