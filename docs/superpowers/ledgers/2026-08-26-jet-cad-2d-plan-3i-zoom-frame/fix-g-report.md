# Fix wave G — the measurement window size is selectable at run time

**Status: complete.** Commits `db8fe8e` (code, tests, README) and `9a36fec`
(M29 in the mutation log). Territory respected: `apps/dev_harness_2d/` only,
plus the mutation log the brief asked for. `packages/jet_cad_2d_flutter/` and
`packages/jet_cad_2d` untouched.

## Why

Criteria 2 and 4 were measured at 1400x900 (Ruling 20). **Criterion 9 cannot be
scored there**: it re-measures Plan 3h's `tile pan` and `tile hold` against 3h's
own recorded figures, and 3h ran at the nib default of 800x600 because nothing
in the harness set a window size until 2026-08-28. A larger viewport means more
tiles, more bakes and more work per pan frame, so the first 500,000-entity run
reading `tile pan` p95 = 23.16 ms against 3h's 19.86 / 15.99 / 13.43 ms is the
viewport change and not a regression. The confound is removable by one run at
3h's viewport, which is now one `export` away.

## The mechanism, and why this one

**An environment variable, `JC_WINDOW`, read on the Swift side via
`ProcessInfo.processInfo.environment`, paired with a `--dart-define` of the
same name on the Dart side.**

This was the first candidate in the brief's order and it worked, so the
launch-argument and `defaults write` routes were not needed. It works because
`flutter run`'s desktop launcher (`DesktopDevice.startApp` →
`_processManager.start(command, environment: _computeEnvironment(...))`) passes
only the engine-switch variables explicitly and leaves `includeParentEnvironment`
at its default of true, so the parent shell's environment reaches the app
process intact. Verified on the real app, not inferred: the Swift side prints
`R2 app-run: JC_WINDOW=<raw>` before it sizes the window, and that line carried
the requested value.

The name is the same on both sides deliberately, so one line in the shell feeds
both:

```sh
export JC_WINDOW=800x600
flutter run -d macos --profile --dart-define=JC_WINDOW=$JC_WINDOW ...
```

Two parsers over one string is still two parsers, and they can still be given
different values by a careless command line. `reportR2Window`'s mismatch
warning is the only thing that catches that, and it is unchanged and still
fires on every `RUN_R2` run — `kMeasurementViewport` is now the parsed request
rather than a literal, so the warning compares the window the app really got
against the size Dart was told to expect.

## What changed

- `lib/main.dart`: `kWindowRequestName`, `kDefaultWindowRequest`,
  `kMinWindowSide` / `kMaxWindowSide`, `parseMeasurementViewport`, and
  `kMeasurementViewport` becomes a `final` parsed from
  `String.fromEnvironment(kWindowRequestName, defaultValue: '1400x900')`. The
  one downstream `const zoomViewport = kMeasurementViewport` becomes `final`.
  The long doc comment now carries the spec's 1600x1200, this display's limit,
  Ruling 20, and criterion 9's need for 800x600.
- `macos/Runner/MainFlutterWindow.swift`: the pinned literal becomes
  `measurementContentSize()`, which reads the same variable, parses it by the
  same rules, and `fatalError`s on anything it cannot read.
- `test/measurement_viewport_test.dart`: five new tests (below). `linesFrom`
  hoisted to file scope so both groups can use it.
- `README.md`: a "The measurement window" section with the paired invocation.

Refusal rules, identical on both sides: exactly `WIDTHxHEIGHT`, a lower-case
`x`, whole logical pixels, each side in [100, 10000]. `800X600` and
`800.0x600.0` are refusals, not near-misses. The range exists because AppKit
places what it can and clamps the rest, so `4x4` and `100000x900` would each
quietly become some other window and the run would measure that one.

## Tests

`apps/dev_harness_2d` **61** (baseline 56, +5), `packages/jet_cad_2d_flutter`
**413 with 1 skip** (baseline). `flutter analyze` and `dart format` clean.

New tests, all in `test/measurement_viewport_test.dart`:

1. `a request is honoured, at sizes a constant could not be` — three sizes, not
   one: at 1400x900 alone a parser that read its argument and one that returned
   the default are indistinguishable.
2. `asking for nothing is 1400x900, exactly as before` — the real default path,
   since the suite runs with no define.
3. `a malformed request throws rather than falling back` — nine strings.
4. `an absurd request throws too` — four out-of-range strings.
5. `a window that does not match the request still warns` — the mismatch
   warning against a `kMeasurementViewport` that is no longer a literal.

## M29 — killed

`M28` was the highest taken; `M29` was free. The mutant returns
`const Size(1400, 900)` where the parser throws. **Red, two tests.** Full
verbatim RED and restored-GREEN transcripts, and the reasoning about which
tests deliberately stay green, are in
`docs/superpowers/notes/plan-3i-mutation-log.md`. Restored by `cp` from a
scratchpad copy; `diff` empty. No `git checkout` anywhere.

The Swift half is unreachable from a Dart test, so it was fired against the
already-built profile binary rather than claimed:

```
$ JC_WINDOW=800X600 build/macos/Build/Products/Profile/dev_harness_2d.app/Contents/MacOS/dev_harness_2d
dev_harness_2d/MainFlutterWindow.swift:82: Fatal error: JC_WINDOW must be WIDTHxHEIGHT in whole logical pixels, each side between 100 and 10000; got "800X600"
```

## Real-app confirmation — functional only, no number recorded

Both runs: `TILES=on ENTITIES=5000 RUN_R2=true`, `flutter run -d macos
--profile`, foregrounded by `osascript` until the window line appeared, then
killed. **No figure from either run is a measurement and none is recorded
anywhere.**

Default, `/tmp/jc-win-default.log` (nothing asked for):

```
R2 app-run: JC_WINDOW=1400x900
flutter: R2 app-run: window=1400x900 dpr=2.0
flutter: R2 app-run: done
```

Requested, `/tmp/jc-win-800.log` (`export JC_WINDOW=800x600`, plus
`--dart-define=JC_WINDOW=$JC_WINDOW`):

```
R2 app-run: JC_WINDOW=800x600
flutter: R2 app-run: window=800x600 dpr=2.0
flutter: R2 app-run: done
```

Both reached `R2 app-run: done`. Neither log contains `WARNING` or any
exception. The first line of each pair is the Swift side reporting the request
it received, which is what makes the environment-variable route observable
rather than assumed.

## Concerns

1. **Two flags for one intent.** The Dart side is a compile-time
   `--dart-define` and the Swift side a run-time environment variable, and
   nothing forces them equal. `export JC_WINDOW=...` once and referencing
   `$JC_WINDOW` in the define makes the shell the single source, and the
   mismatch warning catches a slip — but it catches it *after* the run has
   started, in the transcript, not before. An operator who ignores the warning
   still gets a labelled-wrong number. This is the price of the language
   boundary; the alternative (Dart reading the environment via `dart:io`) would
   break the harness's web target, which `_driveR2`'s own doc comment still
   contemplates.
2. **Swift refuses by `fatalError`, so a malformed request crashes the app
   rather than printing a Dart `StateError`.** That is loud and correct for a
   measurement harness, but the message reaches the operator as a Swift crash
   line in the `flutter run` log, above where they will be looking. Verified to
   appear (above), but it is not the same shape of failure as every other
   define in this harness.
3. **`int.tryParse` on the Dart side accepts a leading `+` and surrounding
   whitespace, Swift's `Int(_:)` does not.** So `JC_WINDOW=" 800x600"` would
   refuse on the Swift side and parse on the Dart side. The window would never
   exist, so no measurement can result — the app dies first — but the two
   parsers are not byte-for-byte identical and a future reader should not
   assume they are.
4. **Criterion 9's re-run is not done.** This wave built and verified the
   mechanism at 5,000 entities as a functional check. The 500,000-entity run at
   `JC_WINDOW=800x600` that actually removes the confound is still to be taken,
   and its result must be reported against 3h's figures with the viewport
   stated beside it.
