# Plan 3f.1 — final whole-branch review fix wave

Applied directly on `main`, no worktree. Seven findings from the final
reviewer, addressed in order. Every command below is a verbatim transcript
from this session — none synthesized.

---

## 1. M12/M13 mislabeling — reproduced independently, then fixed in three places

**Reproduction.** Copied `flutter_text_measurer.dart` aside, fired each
mutant, ran the invariants file, restored from the copy (never `git
checkout`).

```
$ cp packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart /tmp/ftm.bak
```

**M12** (`metricsLimit` defaults to `kParagraphCacheLimit`):

```diff
-    this.metricsLimit = kMetricsCacheLimit,
+    this.metricsLimit = kParagraphCacheLimit,
```

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/text_cache_invariants_test.dart
...
00:00 +0: the default cache bounds hold 600 distinct keys the way they claim
00:00 +0 -1: the default cache bounds hold 600 distinct keys the way they claim [E]
  Expected: <600>
    Actual: <512>

  package:matcher                                        expect
  package:flutter_test/src/widget_tester.dart 473:18     expect
  test/invariants/text_cache_invariants_test.dart 127:5  main.<fn>

00:00 +0 -1: referenceWalk culls sub-threshold text at its own default
00:00 +1 -1: Some tests failed.

Failing tests:
  .../test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
```

Line 127 is `expect(measurer.liveMetricsCount, kDistinctLabels)` — the
**metrics** assertion. Confirms the task's claim exactly: M12 reddens this
file from the metrics side, not the paragraph side.

Restored:

```
$ cp /tmp/ftm.bak packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart
$ diff /tmp/ftm.bak packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart && echo "RESTORED OK"
RESTORED OK
```

**M13** (`paragraphLimit` defaults to `kMetricsCacheLimit`):

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
  test/invariants/text_cache_invariants_test.dart 132:5  main.<fn>

00:00 +0 -1: referenceWalk culls sub-threshold text at its own default
00:00 +1 -1: Some tests failed.

Failing tests:
  .../test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
```

Line 132 is `expect(measurer.liveParagraphCount, kParagraphCacheLimit)` — the
**paragraph** assertion. Confirms M13, not M12, is what discriminates the new
file's unique contribution.

Restored and diffed clean the same way:

```
$ cp /tmp/ftm.bak packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart
$ diff /tmp/ftm.bak packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart && echo RESTORED
RESTORED
```

(Baseline check, unmutated file, same single-file command, for contrast —
both tests pass: `00:00 +2: All tests passed!`.)

**Corrected in three places** (before → after):

**(a) `docs/superpowers/notes/plan-3f1-mutation-log.md`, M12's section.**

Before:
> This task's own `text_cache_invariants_test.dart` is the one that reddens
> on the *paragraph* side of the same mutant (`liveMetricsCount` 512 against
> an expected 600) — the half this task exists to close.

After:
> This task's own `text_cache_invariants_test.dart` also reddens from the
> *metrics* side of the same mutant, at `expect(measurer.liveMetricsCount,
> kDistinctLabels)` (`Expected: <600> Actual: <512>`) — **not** the paragraph
> side, as an earlier version of this entry claimed. That earlier wording
> named `liveMetricsCount` and called it the paragraph side in the same
> clause, which was wrong: `liveMetricsCount` is the metrics counter under
> any name. What this mutant actually shows is that the metrics half is
> covered twice over, by two independent tests reading two independent
> counters (`liveMetricsCount` here, and the sibling file's own eviction
> pin) — it is not evidence that this task's unique contribution, the
> paragraph half, is gated. **M13**, below, is the mutant that proves that:
> it fails only at `liveParagraphCount`, and nothing before this task ever
> called `paragraphFor`.

**(b) `docs/superpowers/notes/2026-08-23-plan-3f1-results.md`, criterion-12
row.**

Before: "...reddens **two** tests suite-wide: this one on the paragraph side
(`liveMetricsCount` 512 vs 600) and `flutter_text_measurer_test.dart`'s ...
on the metrics side..."

After: "...reddens **two** tests suite-wide, **both from the metrics side**:
this one at `liveMetricsCount` (512 vs 600) and
`flutter_text_measurer_test.dart`'s ... . (An earlier version of this row
called this test's failure "the paragraph side"; that was wrong ...) **M13**
... is what proves the paragraph half is gated ..."

**(c) `packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart`
header, last sentence.**

Before: "Firing mutant 7 again reddens both files, each from its own side of
the cache."

After: "Firing mutant 7 again reddens both files, but from the *same* side
of the cache — the metrics side, at `liveMetricsCount` in each. That is real
evidence the metrics half is doubly covered, not that this file's own
paragraph half is gated; mutant 13 ... is the one that proves that, since
nothing before this file ever called `paragraphFor`."

---

## 2. Spec's M10 mapping and the criterion-11 carve-out

- `docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md`,
  Named-mutants table: `M10 | ... | 9, 11` → `M10 | ... | 9, 10`.
- Preamble ("Failable criteria"), before: "Seventeen. Sixteen of them are
  claims a test makes ... **Criterion 17 is the exception and is stated as
  one**..." After: "Seventeen. Fifteen of them are claims a test makes ...
  **Criteria 11 and 17 are the exceptions, and both are stated as
  measurements**: 11 is `git status --short
  packages/jet_cad_2d_flutter/test/golden` ... and 17 is whether an
  instrument works in an environment..."
- Confirmed (no change needed) the results note already carries the correct
  mapping: row 9 cites mutant M10, row 10 cites mutants M10/M11, each with
  its own transcript — verified by direct read, not assumed.

---

## 3. Recorded gap — INSERT's own ATTRIBs do not see the INSERT's style

Verified the mechanism directly:
`packages/jet_cad_2d/lib/src/index/container_index.dart:207-224` folds an
instance's own leaves into the enclosing container's leaf list;
`packages/jet_cad_2d_flutter/lib/src/reference_walk.dart:88-99` mirrors the
same fold. Added a new bullet to the results note's "What this plan did not
close" section stating the mechanism, both file locations, why the
differential suite is structurally blind to it (painter and oracle agree,
both wrong the same way), and that it predates this plan (already true for
`color`/`layer`) but this plan quadruples the affected surface. **No code
changed.**

---

## 4. Test-count derivation corrected

Verified via git history:

```
$ git grep -n "77[7-8] tests" ... (checked STATUS.md at d113d2d)
docs (STATUS.md at commit d113d2d): "777 tests, all pass"
```

```
$ git log --oneline 486c1b7..c078677
c078677 docs: Plan 3f.1 implementation plan — eight tasks
76e134c docs: Plan 3f.1 spec — name the sink criterion 12 needs
1802680 docs: Plan 3f.1 spec — corrections from three independent reviews
9dd69bc docs: Plan 3f.1 design — hardening before the picture cache
a29e5fb chore: update macOS deployment target to 12.0 and exclude build directories from analyzer
62b0f1b docs: archive the Plan 3f ledger
bce35c7 docs: the rig's follow-up gets a permanent home, and the default audit is named
```

```
$ git show 25b9873:packages/jet_cad_2d/test/codec/instance_style_codec_test.dart | grep -c "  test("
4
```

Before: "793 engine tests (778 pre-existing + Task 1's net +3 + Task 2's net
+8 + Task 3's net +2 + Task 4's net +2)..."

After: "793 engine tests (777 pre-existing — the count `STATUS.md` records
at `d113d2d`, Plan 3f's last commit; the seven commits from `bce35c7`
through `c078677` that follow it are docs/config only and move no test — +
Task 1's net +4, `instance_style_codec_test.dart` being a new file with four
tests at `25b9873` + Task 2's net +8 + Task 3's net +2 + Task 4's net +2)..."

777 + 4 + 8 + 2 + 2 = 793 — same total, now derived from the correct terms,
and the 777 figure now cross-checks against `STATUS.md` without
contradiction.

---

## 5. `TextKeySink` justification corrected; move kept

Verified: `rig_support.dart:13` now reads `export
'../support/text_key_sink.dart';` — a re-export, not a declaration — and
both real readers still import `rig_support.dart`, not the new file
directly:

```
$ grep -n "^import" test/flutter_text_measurer_test.dart test/rig/paint_microbench_test.dart
test/flutter_text_measurer_test.dart:5:import 'rig/rig_support.dart';
test/rig/paint_microbench_test.dart:21:import 'rig_support.dart';
```

```
$ grep -n "TextKeySink" test/invariants/text_cache_invariants_test.dart
99: // `RecordingDrawSink` or a `TextKeySink` would leave `liveParagraphCount`
```
(comment only — no import). Confirms neither new invariants file imports
`TextKeySink`.

Corrected in the spec (`:413-417`) and added a new bullet to the results
note's "What this plan did not close" section: the move is kept, but is
currently inert — both real readers still reach the class through
`rig_support.dart`'s re-export, and no import path changed.

---

## 6. `addLayer`'s remove narrowed

`packages/jet_cad_2d/test/document/instance_style_test.dart`:

```diff
-  doc.tables.layers.remove(handle);
+  // Only layer 0 is pre-seeded (`tables.dart:509`), and only it needs
+  // replacing. An unguarded remove would silently overwrite a genuine
+  // accidental duplicate instead of failing on it.
+  if (handle == ReservedHandles.layerZero) doc.tables.layers.remove(handle);
```

---

## 7. Two small corrections

**(a)** Added the missing `addDefinition(doc, const Handle(210), 'PLATE')`
to the BYLAYER group's `fixture()` in
`packages/jet_cad_2d/test/document/instance_style_test.dart`, so `Handle(210)`
— used both as instance `300`'s definition and as instance `310`'s parent —
actually exists as a definition.

**(b)** Measured directly:

```
$ grep -rn "linetypeScale: 1\.0" packages/jet_cad_2d/lib packages/jet_cad_2d/test packages/jet_cad_2d_flutter/lib packages/jet_cad_2d_flutter/test | wc -l
94
```

Narrowed to what each sentence actually scopes to (`jet_cad_2d` only, per
defect 3's own text "in `jet_cad_2d`"), confirmed against the pre-plan
commit:

```
$ git grep -n "linetypeScale" c078677 -- packages/jet_cad_2d/lib packages/jet_cad_2d/test | wc -l
83
$ git grep -n "linetypeScale: 1\.0" c078677 -- packages/jet_cad_2d/lib packages/jet_cad_2d/test | wc -l
53
```

83 matches defect 3's existing "83 lines" claim exactly; 53 (not 54) is the
literal-`1.0` count — matching the anti-degenerate rule's already-correct
"Fifty-three", and confirming defect 3's "54" was the wrong one of the two.
Verified today's (post-plan) `jet_cad_2d`-only count is unchanged at 53,
confirming no fixture this plan wrote used the literal 1.0, as the
anti-degenerate rule requires.

Standardized all three places on **53 lines** (not "fixtures" — some of the
53 are `lib/` defaults, not test fixtures at all):
- `instance_style_codec_test.dart:13`: "fifty-four fixtures" → "fifty-three
  lines — every line in `jet_cad_2d`'s `lib/` and `test/` that already wrote
  the literal `linetypeScale: 1.0` before this plan."
- Spec defect-3 (`:93`): "54 of those are the literal `1.0`" → "53 of
  those...".
- Spec anti-degenerate rule (`:677`): "Fifty-three fixtures in this
  repository already wrote `1.0`" → "Fifty-three lines in `jet_cad_2d`'s
  `lib/` and `test/` already wrote the literal `1.0` (Defect 3, above)..."
  (number was already right; noun and scope corrected to match).

---

## Full gate, run after all fixes

```
$ cd packages/jet_cad_2d && CI=true dart test
...
00:03 +793: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 112 files (0 changed) in 0.20 seconds.

$ cd ../jet_cad_2d_flutter && CI=true flutter test
...
00:04 +304 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)

$ dart format --output=none --set-exit-if-changed .
Formatted 54 files (0 changed) in 0.10 seconds.
```

```
$ git status --short
 M docs/superpowers/notes/2026-08-23-plan-3f1-results.md
 M docs/superpowers/notes/plan-3f1-mutation-log.md
 M docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md
 M packages/jet_cad_2d/test/codec/instance_style_codec_test.dart
 M packages/jet_cad_2d/test/document/instance_style_test.dart
 M packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart

$ git status --short packages/jet_cad_2d_flutter/test/golden
(empty)
```

No `analysis_options.yaml` touched. Six files modified, all documentation or
test files; no production code changed (findings 1–5, 7 are doc/test-only
corrections; findings 6–7a are narrow test-fixture hardening).
