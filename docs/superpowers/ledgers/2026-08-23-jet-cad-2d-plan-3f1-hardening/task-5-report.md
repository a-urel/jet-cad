# Task 5 report — `TextKeySink` moves, and the text-cache invariants become assertions

## Step 1 — move `TextKeySink`

Created `packages/jet_cad_2d_flutter/test/support/text_key_sink.dart` holding
the class exactly as it stood at `test/rig/rig_support.dart:98-167` (doc
comment at 98-110, class at 111-167), with the imports the brief specified:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
```

In `test/rig/rig_support.dart`, deleted the doc comment and class and added:

```dart
export '../support/text_key_sink.dart';
```

**Deviation from the brief's literal snippet:** the brief showed both
`import '../support/text_key_sink.dart';` and
`export '../support/text_key_sink.dart';`. With both present, `flutter
analyze` reported the `import` line as `unused_import` — an ERROR in this
package — because `rig_support.dart` itself never references `TextKeySink`
directly, only re-exports it. Kept the `export` alone, which is what the
brief's own rationale requires ("The export keeps ... compiling unchanged")
and is what makes Step 2's "analyze clean" expectation achievable. Also
dropped `dart:typed_data` from `rig_support.dart`'s own imports — it was only
used by the removed class's `Float64List`/`Int32List` parameters and became
unused once the class moved.

## Step 2 — verify the move changed nothing

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/flutter_text_measurer_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart
00:00 +0: the same string in two colours is two entries, not one
00:00 +1: a repeat request lays out nothing and allocates no metrics
00:00 +2: eviction disposes the paragraph
00:00 +3: metrics are cap-height based and taken at the nominal size
00:00 +4: an empty string measures zero, not the negative float floor
00:00 +5: resetCounters zeroes the counters and keeps the cache warm
00:00 +6: TextKeySink keys the same triple this cache does
00:00 +7: measure disposes its probe and leaves no paragraph entry
00:00 +8: a metrics sweep does not evict drawn paragraphs
00:00 +9: the metrics map evicts on its own bound, and it is not the paragraph one
00:00 +10: the default metrics bound is not the paragraph bound
00:00 +11: clear empties both maps
00:00 +12: All tests passed!
```

```
$ flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```

Green, and analyze clean.

## Step 3 — write the failing invariant test

Created `packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart`
verbatim from the brief, with one necessary deviation: the brief's snippet
imported `package:vector_math/vector_math_64.dart hide Aabb2`, but nothing in
the file uses `Vector2` or any other vector_math symbol (`ViewportTransform`
and `Transform2` take plain doubles at the call sites used here). That import
was flagged `unused_import` (ERROR) by the IDE diagnostics and by
`flutter analyze`, so it was dropped.

## Step 4 — run it

```
$ CI=true flutter test test/invariants/text_cache_invariants_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart
00:00 +0: the default cache bounds hold 600 distinct keys the way they claim
00:00 +1: referenceWalk culls sub-threshold text at its own default
00:00 +2: All tests passed!
```

Both PASS, first try — the grid arithmetic in `sixHundredLabels` produced
`culledTextCount == 0` and `textOpCount == 600` as claimed; no fixture fix was
needed.

## Step 5 — fire mutants M12, M13, M14

Backed up before any mutation:

```
$ cp lib/src/flutter_text_measurer.dart /tmp/ftm.dart.bak
$ cp lib/src/reference_walk.dart /tmp/rw.dart.bak
```

### M12 — `metricsLimit` default → `kParagraphCacheLimit` (Plan 3f's survivor)

Edit (`lib/src/flutter_text_measurer.dart`):

```diff
-    this.metricsLimit = kMetricsCacheLimit,
+    this.metricsLimit = kParagraphCacheLimit,
```

Ran the **whole** Flutter suite under this mutant (not just the new file):

```
$ CI=true flutter test
...
00:02 +125 -1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim [E]
  Expected: <600>
    Actual: <512>

  package:matcher                                        expect
  package:flutter_test/src/widget_tester.dart 473:18     expect
  test/invariants/text_cache_invariants_test.dart 120:5  main.<fn>

...
00:02 +147 -2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart: the default metrics bound is not the paragraph bound [E]
  Expected: <0>
    Actual: <1>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/flutter_text_measurer_test.dart 230:5          main.<fn>

...
00:04 +299 -2: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart: the default metrics bound is not the paragraph bound
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
```

**Finding, stated honestly rather than forced to match the brief's
prediction:** two tests go red under M12, not one. `flutter_text_measurer_test.dart`'s
`the default metrics bound is not the paragraph bound` (added earlier, by
commit `645b027`, specifically to close Plan 3f's mutant-7 gap on the
*metrics* side) also catches this mutant — its own sweep of 513 distinct
metrics keys is enough to expose `metricsLimit == kParagraphCacheLimit`
directly. That test does not, and cannot, touch `liveParagraphCount` or
`paragraphEvictionCount` — it never calls `paragraphFor`. The new invariant
test in `text_cache_invariants_test.dart` is the one that reddens on the
*paragraph* side of the same mutant (`liveMetricsCount` reads 512 against an
expected 600), which is the half this task exists to close. Every other test
in the 301-test suite stays green under M12, so the mutant is caught from two
independent angles and the hole this task targets — the paragraph-cache half,
unreachable by any `RecordingDrawSink`/`TextKeySink`-based test — is closed.

Restored:

```
$ cp /tmp/ftm.dart.bak lib/src/flutter_text_measurer.dart
$ diff /tmp/ftm.dart.bak lib/src/flutter_text_measurer.dart && echo "restored clean"
restored clean
```

### M13 — `paragraphLimit` default → `kMetricsCacheLimit`

Edit (`lib/src/flutter_text_measurer.dart`):

```diff
-    this.paragraphLimit = kParagraphCacheLimit,
+    this.paragraphLimit = kMetricsCacheLimit,
```

```
$ CI=true flutter test test/invariants/text_cache_invariants_test.dart
...
00:00 +0: the default cache bounds hold 600 distinct keys the way they claim
00:00 +0 -1: the default cache bounds hold 600 distinct keys the way they claim [E]
  Expected: <512>
    Actual: <600>

  package:matcher                                        expect
  package:flutter_test/src/widget_tester.dart 473:18     expect
  test/invariants/text_cache_invariants_test.dart 125:5  main.<fn>

00:00 +0 -1: referenceWalk culls sub-threshold text at its own default
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
```

`liveParagraphCount` read 600 (all inserts kept, none evicted) instead of
`kParagraphCacheLimit` (512) — exactly the wrong value the brief predicted.

Restored:

```
$ cp /tmp/ftm.dart.bak lib/src/flutter_text_measurer.dart
$ diff /tmp/ftm.dart.bak lib/src/flutter_text_measurer.dart && echo "restored clean"
restored clean
```

### M14 — `reference_walk.dart`'s `minTextCapPixels` default → `0.0`

Edit (`lib/src/reference_walk.dart`):

```diff
-  double minTextCapPixels = kMinTextCapPixels,
+  double minTextCapPixels = 0.0,
```

```
$ CI=true flutter test test/invariants/text_cache_invariants_test.dart
...
00:00 +0: the default cache bounds hold 600 distinct keys the way they claim
00:00 +1: referenceWalk culls sub-threshold text at its own default
00:00 +1 -1: referenceWalk culls sub-threshold text at its own default [E]
  Expected: ['BIG']
    Actual: ['TINY', 'BIG']
     Which: at location [0] is 'TINY' instead of 'BIG'
  TINY is 1 px of cap height against a 3.0 px default

  package:matcher                                        expect
  package:flutter_test/src/widget_tester.dart 473:18     expect
  test/invariants/text_cache_invariants_test.dart 154:5  main.<fn>

00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart: referenceWalk culls sub-threshold text at its own default
```

`drawn` read `['TINY', 'BIG']` — exactly the wrong value the brief predicted.

Restored:

```
$ cp /tmp/rw.dart.bak lib/src/reference_walk.dart
$ diff /tmp/rw.dart.bak lib/src/reference_walk.dart && echo "restored clean"
restored clean
$ diff /tmp/ftm.dart.bak lib/src/flutter_text_measurer.dart && echo "ftm also clean"
ftm also clean
```

## Step 6 — full suite, then commit

```
$ CI=true flutter test
...
00:04 +297 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks nothing the painter did not ask for
00:04 +298 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks nothing the painter did not ask for
00:04 +299 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks nothing the painter did not ask for
00:04 +300 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the comparison is not vacuous
00:04 +301 ~1: All tests passed!
```

```
$ flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 53 files (0 changed) in 0.10 seconds.
$ echo $?
0
```

(Format needed one real pass first — `dart format` without `--output=none`
was run once to actually rewrite `test/invariants/text_cache_invariants_test.dart`
and `test/rig/rig_support.dart` to the tool's canonical style; the check
above is the subsequent clean run.)

`git status --porcelain` before commit:

```
 M packages/jet_cad_2d_flutter/test/rig/rig_support.dart
?? packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart
?? packages/jet_cad_2d_flutter/test/support/text_key_sink.dart
```

No `analysis_options.yaml` changes appeared in `git status` at any point in
this task.

Committed as `a5ff5db` (message per the brief, verbatim).

## Summary

- `packages/jet_cad_2d_flutter/test/support/text_key_sink.dart` — new,
  `TextKeySink` moved verbatim from `rig_support.dart`.
- `packages/jet_cad_2d_flutter/test/rig/rig_support.dart` — class deleted,
  replaced with `export '../support/text_key_sink.dart';` (import omitted,
  see Step 1 deviation); `dart:typed_data` import dropped (now unused).
- `packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart`
  — new, two tests: the 600-label cache-bounds invariant (`CanvasDrawSink`
  over a real `Canvas`, bare `FlutterTextMeasurer`) and the
  `referenceWalk` sub-threshold cull invariant (`vector_math_64` import
  omitted, see Step 3 deviation).
- Full suite: 301 tests, all green. `flutter analyze`: clean. `dart format
  --set-exit-if-changed`: clean.
- M12 (Plan 3f's actual survivor) reddens two tests across the whole suite:
  the pre-existing `flutter_text_measurer_test.dart` test (metrics-side) and
  the new `text_cache_invariants_test.dart` test (paragraph-side, the half
  this task was written to close). M13 and M14 each redden exactly the new
  file, at exactly the predicted wrong values. All three mutants were
  restored by copying back from `/tmp/ftm.dart.bak` / `/tmp/rw.dart.bak`,
  never via `git checkout`.

## Fix round 1 of 5

Two findings from the coordinator, both about written claims rather than
behaviour; the tests themselves were not touched.

### Finding 1 (critical) — a committed comment stated something false

`test/invariants/text_cache_invariants_test.dart:12-14` claimed, in present
tense, that "no test in that file [`flutter_text_measurer_test.dart`] ever
pushed past 512 distinct metrics keys." That is false: `the default metrics
bound is not the paragraph bound` (lines 209-237, landed by Plan 3f's remedy
commit `645b027`) constructs a bare `FlutterTextMeasurer()`, sweeps
`kParagraphCacheLimit + 1` = 513 distinct strings through `measure()`, and
asserts `metricsEvictionCount == 0` and `liveMetricsCount ==
kParagraphCacheLimit + 1`. This is the same test whose M12 failure this task
already recorded in Step 5 above (`the default metrics bound is not the
paragraph bound [E] Expected: <0> Actual: <1>`) — so the file's own commit
history contradicted its own header comment.

**Before:**

```
// Plan 3f's mutant 7 (`metricsLimit` defaulting to `kParagraphCacheLimit`)
// passed all 297 tests in the suite it shipped with. Nine of the twelve
// constructions in `flutter_text_measurer_test.dart` are already bare, so bare
// construction was never the missing half: **no test in that file ever pushed
// past 512 distinct metrics keys**, so nothing it asserted was sensitive to
// `metricsLimit` at any value. This file supplies the other half.
```

**After:**

```
// Plan 3f's mutant 7 (`metricsLimit` defaulting to `kParagraphCacheLimit`)
// passed all 297 tests in the suite it was fired against. Nine of the twelve
// constructions in `flutter_text_measurer_test.dart` were already bare, so
// bare construction was never the missing half. Plan 3f's remedy
// (`645b027`) closed one side of it: a bare measurer swept past 512
// distinct strings through `measure()` and pinned `metricsEvictionCount`.
// That test never calls `paragraphFor`, never runs a painter, and asserts
// `liveParagraphCount == 0` outright — it closes the metrics half and
// leaves the paragraph half exactly as untested as before. This file
// closes that half: a real paint through `CanvasDrawSink` fills both maps
// at once, and the 600-into-512 eviction arithmetic is pinned
// behaviourally rather than restated. Firing mutant 7 again reddens both
// files, each from its own side of the cache.
```

The rewritten paragraph narrows the file's claim to what it actually adds
(the paragraph-cache half, proved behaviourally by a real paint) instead of a
present-tense claim about the sibling file that this task's own mutation
transcript already disproved. The first paragraph (rig prints, these assert)
was left as-is per the coordinator's instruction — it was accurate.

### Finding 2 (minor) — a citation was off by one line

The second test's comment cited `test/support/fixtures.dart:184` for where
`referenceToRecording` re-declares `minTextCapPixels = kMinTextCapPixels` and
always passes it on. Checked the current file: the default-parameter
declaration is at line 183 (`[ViewportTransform? camera, double
minTextCapPixels = kMinTextCapPixels]) {`); line 184 is the following
statement (`final view = camera ?? ...`). Corrected the citation from `:184`
to `:183`. The underlying claim — that `referenceToRecording` shadows the
parameter and always forwards it — was already true and is unchanged.

### Verification

```
$ CI=true flutter test test/invariants/text_cache_invariants_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart
00:00 +0: the default cache bounds hold 600 distinct keys the way they claim
00:00 +1: referenceWalk culls sub-threshold text at its own default
00:00 +2: All tests passed!
```

```
$ flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 53 files (0 changed) in 0.10 seconds.
$ echo $?
0
```

`git diff` on the file confirmed the change touched only the two comment
blocks — no test logic, imports, or assertions changed.

Committed as `e39f295` (message: the file justified its own existence with
a false claim about `flutter_text_measurer_test.dart`, and 3f's own remedy
commit already disproved it; the corrected claim narrows the file's
contribution to the paragraph-cache half it actually closes. Also fixed an
off-by-one line citation into `fixtures.dart`).
