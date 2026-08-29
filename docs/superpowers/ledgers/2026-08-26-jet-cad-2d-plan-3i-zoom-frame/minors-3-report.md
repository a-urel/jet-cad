# Batch closure — three Minor review findings, the declared-last-round batch

Repo: `/Users/ahmeturel/Projects/oss/jet-cad`, started at `750316b` on `main`.
Reviewer returned **no Blocking and no Major** for this round.

## Finding 1 — an ordering assumption nothing verifies

`apps/dev_harness_2d/lib/measurement_rig.dart`, `FrameTimingLog.establishBaseline`.

Replaced

```dart
_baselineFrameNumber = _reported.last.frameNumber;
```

with the observed maximum:

```dart
_baselineFrameNumber = _reported.fold<int>(0,
    (max, timing) => timing.frameNumber > max ? timing.frameNumber : max);
```

(`fold<int>` is explicit — `_baselineFrameNumber` is `int?`, and without the
type argument the assignment context infers `T = int?` for the fold, which
then fails to typecheck the `>` comparison against a nullable accumulator.)

Added a comment at the call site naming why this matters beyond its size:
this rig's governing decision (fix wave C, `progress.md`) was to build
attribution only on properties the rig can observe, which is why
`frameNumber`-anchored attribution was rejected in favour of the baseline
drain, with `frameNumber` kept only as a staleness filter on the drained
stream. A `.last` that assumed batch-delivery order is the same
unverified-assumption class, one line deep.

**Test added** — `apps/dev_harness_2d/test/settle_attribution_test.dart`,
`'the baseline rebases to the observed maximum, not the last-delivered
timing'`. Delivers one out-of-order batch (`frameNumber`s 3, 7, 5 — the true
maximum 7 buried in the middle, not last) through
`SchedulerBinding.instance.platformDispatcher.onReportTimings!`, then checks
that a straggler numbered 6 (above the `.last`-derived baseline of 5, below
the true maximum of 7) is dropped, not admitted. Reverting the fix to
`.last` makes this test fail: the wrong baseline (5) admits frame 6 as a
legitimate post-baseline frame, so `reportedFrames` becomes 1 instead of the
expected 0. This is a real differential test, not a restated constant.

## Finding 2 — M24's clause 4 justification did not carry its own conclusion

`docs/superpowers/notes/plan-3i-mutation-log.md`, M24 derivation, clause 4.

Corrected clause 4's justification: what orders stale keys strictly older
than visible ones is not "the frame that made a key stale changed the
camera" (true of every camera-moving frame, and does not by itself order
anything) but that `_restBake` runs only once `_restGateSteps >=
kRestGateFrames` — the quantised camera has held identical for two
consecutive frames, so the visible key set is fixed across them: every
visible held key carries the serial of frame N-1 or N-2, while any
off-viewport key was last visible no later than N-3.

Appended the caveat the reviewer named, without restructuring the section:
the visible key set is a function of camera *and* viewport (`paintFrame`
takes `viewport` from the widget), and `_gridFor` retires a generation only
on a scale change (`matchesScale`), not on a viewport-size change — verified
by reading `tile_cache.dart`'s `_gridFor` and `paintFrame`. A viewport that
shrinks and regrows at a fixed camera does not re-anchor, so a previously
off-viewport key can come back into the visible set carrying an old serial,
and clause 4 fails for it. Stated plainly that this does not reopen M24: the
consequence is bounded (an ordinary cache miss, the live fallback draws
correct pixels at a cost) and bands after the current one are already
unprotected by the stamp in both variants regardless.

No test — this is a documentation-only correction to a mutation-log
derivation; `packages/jet_cad_2d_flutter`'s behaviour is unchanged.

## Finding 3 — the arm abort did not read like the rest of the transcript

`apps/dev_harness_2d/lib/main.dart:490` area (`_driveR2`).

Wrapped the `kZoomMode` switch in `try`/`catch`, printing one labelled line
in the file's existing `!!! WARNING:`-style prefix convention —
`'!!! ARM ABORTED: $e'` — then `rethrow`. No behavioural change: the run
still ends, remaining arms are still lost, `finally` blocks inside
`runZoomCriterionArms` still restore both measurement flags, and earlier
arms' printed output still stands (Ruling 18's own check, already verified
at final review). Only the framing changed: an operator now sees a labelled
line before the bare `StateError`, instead of a transcript with every other
line prefixed and this one alone bare.

**No test added.** `_driveR2` is a private top-level function in `main.dart`
(Dart privacy is per-file, so no other library can call it, including test
files that already `import 'package:dev_harness_2d/main.dart'` for
`runZoomCriterionArms`). Exercising the new `try`/`catch` directly would
require extracting the switch into a separately-testable function — a
structural change this finding did not ask for and that the gate's own
carried concerns (`progress.md`) note is out of scope for a Minor. The change
is a print statement plus a `rethrow` with no branching logic of its own, so
there is no new decision for a test to distinguish; `flutter analyze`'s
unreachable-code and unused-catch-clause checks (both errors in this
package) already guard against the trivial ways this could be wrong (an
absorbed exception, an unused `catch` binding).

## Gate

### `apps/dev_harness_2d`

```
$ CI=true flutter test --concurrency=1
...
00:02 +33: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the baseline rebases to the observed maximum, not the last-delivered timing
...
00:16 +47: All tests passed!
```
(baseline 46 + 1 new test = 47, exactly.)

```
$ CI=true flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.6s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 11 files (0 changed) in 0.08 seconds.
```
(exit 0)

### `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:07 +413 ~1: All tests passed!
```
(matches baseline 413, 1 skip, exactly — untouched by this batch; only the
mutation-log doc references this package's source.)

```
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 73 files (0 changed) in 0.14 seconds.
```
(exit 0)

### `packages/jet_cad_2d`

```
$ CI=true dart test
...
00:03 +797: All tests passed!
```
(matches baseline 797, exactly — pure Dart, not touched.)

```
$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.24 seconds.
```
(exit 0)

## Working tree at the end

```
$ git status --porcelain
 M apps/dev_harness_2d/lib/main.dart
 M apps/dev_harness_2d/lib/measurement_rig.dart
 M apps/dev_harness_2d/test/settle_attribution_test.dart
 M docs/superpowers/notes/plan-3i-mutation-log.md
```

Only the four named paths changed; `analysis_options.yaml` untouched in all
three packages; `packages/jet_cad_2d` not touched at all.

## Commit

Staged and committed the four named paths (no `git add -A`). See git log for
the commit SHA.
