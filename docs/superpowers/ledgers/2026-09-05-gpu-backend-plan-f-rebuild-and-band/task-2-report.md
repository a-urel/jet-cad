# Task 2 report — the resident rebuilder

Commit: `061fa67` "feat(gpu): the resident rebuilder -- one schedule, five
triggers, and a frame that never waits"

## What was implemented

Followed the brief verbatim, in its own step order.

1. **`debugSetGpuAvailable`** appended to `lib/src/gpu/gpu_facade.dart` —
   pins/clears the cached GPU-availability answer, as the sole extra test
   seam Task 2 needs (`debugSetGpuFactory` can only force `false`).
2. **`test/support/recording_frame_painter.dart`** — `RecordingFramePainter`
   (a `ResidentFramePainter` that records instead of drawing),
   `FakeUploader` (a controllable `ResidentUploader` with a `gate` for
   in-flight control and a `failing` flag), and `zoomedAbout` (the
   scale-about-a-point camera builder used by the band test).
3. **`lib/src/gpu/resident_rebuilder.dart`** — `RebuildTrigger` enum,
   `ResidentFramePainter` interface, `ResidentUploader` typedef, the
   production `uploadResidentCollection`, and `ResidentRebuilder` itself:
   `noteFrame` (O(1), never walks — fires `initial`/`tables`/
   `devicePixelRatio`/`band` in that order), `markDirty` (coalesces into one
   post-frame callback), `_schedule`/`_run` (the post-frame callback: walk +
   classify synchronously, upload awaited), `rebuildNow` (public, does the
   walk/upload/swap), `inBand` (live-over-collection ratio), and `dispose`
   (idempotent, guarded).
4. **`lib/src/gpu/gpu_draw_backend.dart`** — `GpuDrawBackend implements
   ResidentFramePainter`, one new import, `@override` on `paint` and
   `dispose`. No other change to this file.
5. **`lib/jet_cad_2d_flutter.dart`** — one new export line for
   `resident_rebuilder.dart`.
6. **`test/gpu/resident_rebuilder_test.dart`** — the brief's 9 tests
   verbatim (import list trimmed, see below).
7. **`test/gpu/gpu_facade_test.dart`** — the brief's one added test appended.

## Deviation from the brief's literal text (both mechanical, not behavioural)

- `test/gpu/resident_rebuilder_test.dart`'s brief-given `import 'dart:ui';`
  triggered `flutter analyze`'s `unnecessary_import` lint (everything used
  from it — `Offset` — is already re-exported by `flutter_test`), which made
  `flutter analyze` exit 1. Removed that one import line; no other change.
  Re-ran the file's tests after removing it — all 9 still pass.
- `dart format --set-exit-if-changed .` reported 3 files changed (the
  brief's own line-wrapping in `resident_rebuilder.dart`,
  `resident_rebuilder_test.dart`, and `recording_frame_painter.dart` was not
  literally 80-column-clean as pasted). Ran `dart format` on exactly those
  three files, per the task instructions; no logic touched, only wrapping.

No other departure from the brief.

## TDD evidence

**RED** — `flutter test test/gpu/resident_rebuilder_test.dart` before
`resident_rebuilder.dart` existed:

```
Error: Method not found: 'ResidentRebuilder'.
Error: Undefined name 'RebuildTrigger'.
... (12 occurrences of RebuildTrigger, plus ResidentRebuilder)
00:00 +0 -1: Some tests failed.
```

This is the expected failure per Step 4 ("FAIL — `ResidentRebuilder`,
`ResidentFramePainter` undefined").

**GREEN** — `flutter test test/gpu/resident_rebuilder_test.dart
test/gpu/gpu_facade_test.dart` after Step 5's implementation:

```
00:00 +0: ... the first frame marks initial and does not walk; the post-frame callback does
00:00 +1: ... the first frame marks initial and does not walk; the post-frame callback does
00:00 +2: ... the first frame marks initial and does not walk; the post-frame callback does
00:00 +3: ... the first frame marks initial and does not walk; the post-frame callback does
00:00 +4: ... three marks before the frame ends are one rebuild, named for the first
00:00 +5: ... a mark during an upload in flight queues exactly one more
00:00 +6: ... the band is read as live over collection
00:00 +7: ... the table revision counter triggers a rebuild, and the new collection carries the new revision
00:00 +8: ... a device pixel ratio change triggers a rebuild whose half-widths follow it
00:00 +9: ... an edited label draws the new string: the text list is not stale across a rebuild
00:00 +10: ... a failed upload falls back for good: no backend, no retry
00:00 +11: ... a painter that lands after dispose is disposed, not installed
00:00 +12: All tests passed!
```

(the `+0..+3` block is `flutter test`'s per-fold reprinting of the same
test name across the file's `main()` invocation phases — no duplicate test
runs; the resident_rebuilder file alone shows 9 distinct tests, confirmed
again below after the import fix.)

**Re-run after removing the `dart:ui` import** —
`flutter test test/gpu/resident_rebuilder_test.dart`:

```
00:00 +0: the first frame marks initial and does not walk; the post-frame callback does
00:00 +1: three marks before the frame ends are one rebuild, named for the first
00:00 +2: a mark during an upload in flight queues exactly one more
00:00 +3: the band is read as live over collection
00:00 +4: the table revision counter triggers a rebuild, and the new collection carries the new revision
00:00 +5: a device pixel ratio change triggers a rebuild whose half-widths follow it
00:00 +6: an edited label draws the new string: the text list is not stale across a rebuild
00:00 +7: a failed upload falls back for good: no backend, no retry
00:00 +8: a painter that lands after dispose is disposed, not installed
00:00 +9: All tests passed!
```

All 9 rebuilder tests pass, including the band test, the in-flight-queue
test, the failed-upload test, and the dispose-during-upload test — each
carries the brief's own named mutation comment (M-F1 .. M-F13) that the
assertion is built to catch.

## Full package gate (Step 7)

```
$ flutter test
...
00:09 +639 ~1: All tests passed!
$ echo $?
0
```

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
$ echo $?
0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 106 files (0 changed) in 0.16 seconds.
$ echo $?
0
```

`git status --short` before staging showed no `analysis_options.yaml`
changes.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/resident_rebuilder.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_facade.dart` (added
  `debugSetGpuAvailable`)
- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`
  (`implements ResidentFramePainter`, import, two `@override`)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (export)
- `packages/jet_cad_2d_flutter/test/support/recording_frame_painter.dart`
  (new)
- `packages/jet_cad_2d_flutter/test/gpu/resident_rebuilder_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/gpu/gpu_facade_test.dart` (one test
  added)

## Self-review

- **Completeness**: all 7 files from the brief's file list exist with the
  content specified; all 9 rebuilder tests plus the 1 facade test are
  present and green.
- **Quality**: `GpuDrawBackend`'s change is exactly the three lines the
  brief called for (interface, import, two `@override`s) — diffed and
  confirmed no incidental change to its `paint`/`dispose` bodies.
  `gpu_facade.dart`'s change is purely additive (one function appended
  after `debugSetGpuFactory`, as specified).
- **Discipline**: `packages/jet_cad_2d` untouched;
  `vertices_draw_sink.dart`/`canvas_draw_sink.dart` untouched; no shader
  touched; nothing landed beyond the 7 files the brief names; `git status`
  after staging shows exactly those 7 and nothing else (confirmed the
  staged set with `git status --short` before commit).
- **Testing**: every test in the brief is present verbatim (module-level
  logic unchanged); the only edit to test *code* was the removal of one
  redundant import in `resident_rebuilder_test.dart`, which does not touch
  any assertion, mutation-comment, or scenario. Output is pristine — no
  print/debug noise beyond the framework's own `flutter test` progress
  lines.

## Concerns

None. The two mechanical fixes (dropping the unnecessary `dart:ui` import,
and running `dart format` on the three brief-pasted files) were both
required by the "task ends green" gate and changed no behaviour — verified
by re-running the affected tests after each fix.

---

## Fix report — round 1

**Finding (Important, plan-mandated):** `test/gpu/resident_rebuilder_test.dart:83-84`
— the M-F6 mutation comment claimed dropping `markDirty`'s coalescing guard
(`if (_inFlightTrigger != null || _scheduled) return;`) would make
`rebuilds` read 4, but it does not: all three post-frame callbacks land in
the same phase, the first `_run` clears `_pending` synchronously, and
callbacks 2 and 3 hit `_run`'s `trigger == null` early return before
`rebuildNow` ever runs — `rebuilds` stays 2 regardless. The comment
overstated what the test covers; nothing actually witnessed the guard.

### What changed

1. **`lib/src/gpu/resident_rebuilder.dart`** — added a public counter,
   incremented once per post-frame callback registered:

   ```dart
   /// Post-frame callbacks registered. One per coalesced rebuild; a value
   /// above [landed] means marks were not coalesced.
   int schedules = 0;
   ```

   and `schedules++;` as the first statement of `_schedule()`.

2. **`test/gpu/resident_rebuilder_test.dart`** — in "three marks before the
   frame ends are one rebuild, named for the first", added
   `expect(r.schedules, 2, reason: 'one schedule for initial, one for the
   three coalesced marks');` after the existing `rebuilds == 2` check, and
   rewrote the mutation comment to name the actual failure mode:

   ```dart
   // MUTATION (M-F6): drop markDirty's early return -> three callbacks are
   // registered and schedules reads 4; rebuilds stays 2 only because
   // _run's pending re-check absorbs the extra callbacks.
   ```

### Mutation fired by hand

Backed up `resident_rebuilder.dart` to `/tmp/resident_rebuilder.dart.bak`,
then removed `markDirty`'s guard line
(`if (_inFlightTrigger != null || _scheduled) return;`), leaving:

```dart
void markDirty(RebuildTrigger trigger) {
  if (_disposed || _uploadFailed) return;
  _pending ??= trigger;
  _schedule();
}
```

`flutter test test/gpu/resident_rebuilder_test.dart` — RED, exactly on the
new assertion:

```
00:00 +1: three marks before the frame ends are one rebuild, named for the first
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═══════════════════════════
The following TestFailure was thrown running a test:
Expected: <2>
  Actual: <4>
one schedule for initial, one for the three coalesced marks
...
00:00 +8 -1: Some tests failed.

Failing tests:
  .../test/gpu/resident_rebuilder_test.dart: three marks before the frame ends are one rebuild, named for the first
```

`rebuilds` (checked just above) stayed green at 2, as predicted — only
`schedules` (4 vs. expected 2) caught the mutation, confirming the fix
closes the exact gap the reviewer named.

Restored the file with `cp /tmp/resident_rebuilder.dart.bak
lib/src/gpu/resident_rebuilder.dart`, then diffed it back to the
pre-mutation content (guard and `schedules++` both present) before
re-running.

### Covering tests, re-run after restore

`flutter test test/gpu/resident_rebuilder_test.dart test/gpu/gpu_facade_test.dart`:

```
00:00 +9: a painter that lands after dispose is disposed, not installed
00:00 +12: All tests passed!
```

All 9 rebuilder tests plus the 3 facade tests green.

### Package gates (re-run)

```
$ flutter test
...
00:08 +639 ~1: All tests passed!
TEST EXIT: 0
```

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
ANALYZE EXIT: 0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 106 files (0 changed) in 0.15 seconds.
FORMAT EXIT: 0
```

`git status --short` before staging showed only the two intended files
changed; no `analysis_options.yaml`.

### Commit

`97eccb9` "test(gpu): the coalescing guard has a witness -- a schedules
counter" — 2 files changed, 11 insertions(+), 1 deletion(-).

### Concerns

None.
