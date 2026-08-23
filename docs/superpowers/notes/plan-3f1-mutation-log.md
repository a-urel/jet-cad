# Plan 3f.1 mutation log — hardening before the picture cache

Seventeen named mutants, from
`docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md`'s
"Named mutants" table. **All seventeen fired, all seventeen killed. No
survivors.** Every edit was applied via `Edit`/manual patch after copying the
target file aside; every restore was a copy back from that backup, verified
`diff`-identical afterward. `git checkout` was never used to revert a mutant,
per the repository's own trap about that command silently discarding
uncommitted work.

Transcripts below are copied verbatim from the task reports named in each
section (`.superpowers/sdd/2026-08-23-jet-cad-2d-plan-3f1-hardening/task-N-report.md`);
none were re-run or re-synthesized for this log.

---

## M1 — `contextFor` reverts `lineweight` to `inherited.lineweight`

**Criteria:** 1, 5. **Task:** 2. **Target:**
`packages/jet_cad_2d/lib/src/document/style_resolver.dart`, the
`StyleContext(...)` return in `contextFor`.

```diff
-      lineweight: lineweight,
+      lineweight: inherited.lineweight,
```

**Command:** `CI=true dart test test/document/instance_style_test.dart`

```
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +0 -1: an INSERT imposes its concrete lineweight on a BYBLOCK child [E]
  Expected: <211>
    Actual: <25>
00:00 +2 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight [E]
  Expected: <191>
    Actual: <25>
...
Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
  test/document/instance_style_test.dart: an INSERT imposes its concrete lineweight on a BYBLOCK child
```

Reddened exactly the two tests the criteria table predicts, nothing else.
**KILLED.**

---

## M2 — `contextFor` reverts `transparency` to `inherited.transparency`

**Criteria:** 2, 6. **Task:** 2. **Target:** same file, same return block.

```diff
-      transparency: transparency,
+      transparency: inherited.transparency,
```

**Command:** `CI=true dart test test/document/instance_style_test.dart`

```
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +1 -1: an INSERT imposes its concrete transparency on a BYBLOCK child [E]
  Expected: <118>
    Actual: <255>
00:00 +3 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency [E]
  Expected: <167>
    Actual: <255>
...
Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
  test/document/instance_style_test.dart: an INSERT imposes its concrete transparency on a BYBLOCK child
```

**KILLED.**

---

## M3 — `contextFor` reverts `linetype` to `inherited.linetype`

**Criteria:** 3, 7. **Task:** 2. **Target:** same file, same return block.

```diff
-      linetype: linetype,
+      linetype: inherited.linetype,
```

**Command:** `CI=true dart test test/document/instance_style_test.dart`

```
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +2 -1: an INSERT imposes its concrete linetype on a BYBLOCK child [E]
  Expected: <42>
    Actual: <4>
00:00 +4 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype [E]
  Expected: <71>
    Actual: <4>
...
Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
  test/document/instance_style_test.dart: an INSERT imposes its concrete linetype on a BYBLOCK child
```

**KILLED.**

---

## M4 — `styleFor` drops the `ctx.linetypeScale ×` factor

**Criteria:** 4. **Task:** 3. **Target:** `style_resolver.dart`, `styleFor`'s
`ResolvedStyle(...)` construction.

```diff
-      linetypeScale:
-          ctx.linetypeScale * document.entities.linetypeScaleAt(slot),
+      linetypeScale: document.entities.linetypeScaleAt(slot),
```

**Command:**
`CI=true dart test test/document/instance_style_test.dart --plain-name "linetypeScale multiplies"`

```
00:00 +0: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0
00:00 +0 -1: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0 [E]
  Expected: <64.0>
    Actual: <2.0>

00:00 +0 -1: linetypeScale multiplies down the tree an INSERT at 1.0 leaves its child alone
00:00 +1 -1: Some tests failed.
```

Reddened reading `2.0` — the entity's own scale, with every enclosing INSERT's
contribution dropped — exactly as predicted. The no-op guard test stayed
green (it needed no INSERT-side contribution to distinguish). **KILLED.**

---

## M5 — `contextFor` drops the `inherited.linetypeScale ×` factor

**Criteria:** 4. **Task:** 3. **Target:** same file, `contextFor`'s
`StyleContext(...)` return.

```diff
-      linetypeScale: inherited.linetypeScale * node.linetypeScale,
+      linetypeScale: node.linetypeScale,
```

**Command:**
`CI=true dart test test/document/instance_style_test.dart --plain-name "linetypeScale multiplies"`

```
00:00 +0: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0
00:00 +0 -1: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0 [E]
  Expected: <64.0>
    Actual: <8.0>

00:00 +0 -1: linetypeScale multiplies down the tree an INSERT at 1.0 leaves its child alone
00:00 +1 -1: Some tests failed.
```

Reddened reading `8.0` — the inner INSERT's `4.0 ×` the entity's own `2.0`,
with the outer INSERT's `8.0` dropped from the chain. `64.0` differs from
every partial product (`2.0`, `8.0`, `32.0`) and from the sum (`14.0`), so the
distinct wrong values from M4 and M5 confirm the two multiplications are
independently load-bearing. **KILLED.**

---

## M6 — `contextFor` uses `node.layer` for the BYLAYER lookup

**Criteria:** 5, 6, 7. **Task:** 2. **Target:** `style_resolver.dart`, the
layer-record fetch immediately below the "One lookup, not four" comment.

```diff
-      final record = document.tables.layers[layer];
+      final record = document.tables.layers[node.layer];
```

(`layer` is the already-substituted effective layer; `node.layer` is the
INSERT's own, pre-substitution value.)

**Command:** `CI=true dart test test/document/instance_style_test.dart`

```
00:00 +3 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight [E]
  Expected: <191>
    Actual: <13>

00:00 +3 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency [E]
  Expected: <167>
    Actual: <246>

00:00 +3 -3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype [E]
  Expected: <71>
    Actual: <70>

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
```

Reddened all three BYLAYER tests, and only those three — the three
"imposes its concrete X" tests (which never take the BYLAYER path) stayed
green. **KILLED.**

---

## M7 — the BYLAYER arm for `transparency` passes the sentinel through

**Criteria:** 6. **Task:** 2. **Target:** `style_resolver.dart`'s
`transparency` switch.

```diff
 final transparency = switch (node.transparency) {
   kByBlock => inherited.transparency,
-  kByLayer => record?.transparency ?? inherited.transparency,
+  kByLayer => node.transparency,
   _ => node.transparency,
 };
```

**Command:** `CI=true dart test test/document/instance_style_test.dart`

```
00:00 +4 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency [E]
  Expected: <167>
    Actual: <255>

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
```

Reddened exactly `BYLAYER ... transparency`, nothing else. **KILLED.**

---

## M8 — the BYLAYER arm for `linetype` passes the sentinel through

**Criteria:** 7. **Task:** 2. **Target:** `style_resolver.dart`'s `linetype`
nested-conditional.

```diff
 final linetype = node.linetype == ReservedHandles.byBlockLinetype
     ? inherited.linetype
     : node.linetype == ReservedHandles.byLayerLinetype
-        ? (record?.linetype ?? inherited.linetype)
+        ? node.linetype
         : node.linetype;
```

**Command:** `CI=true dart test test/document/instance_style_test.dart`

```
00:00 +5 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype [E]
  Expected: <71>
    Actual: <2>

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
```

Reddened exactly `BYLAYER ... linetype`, nothing else. **KILLED.**

---

## M9 — the `kLineweightDefault` arm is dropped

**Criteria:** 8. **Task:** 2. **Target:** `style_resolver.dart`'s `lineweight`
switch — the `concrete()` guard removed, raw values used directly.

```diff
-int concrete(int value) =>
-    value == kLineweightDefault ? inherited.lineweight : value;
 final lineweight = switch (node.lineweight) {
   kByBlock => inherited.lineweight,
-  kByLayer => concrete(record?.lineweight ?? inherited.lineweight),
-  _ => concrete(node.lineweight),
+  kByLayer => record?.lineweight ?? inherited.lineweight,
+  _ => node.lineweight,
 };
```

**Command:** `CI=true dart test test/document/instance_style_test.dart`

```
00:00 +6 -1: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT [E]
  Expected: <25>
    Actual: <-3>

00:00 +6 -2: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup [E]
  Expected: <25>
    Actual: <-3>

Failing tests:
  test/document/instance_style_test.dart: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
  test/document/instance_style_test.dart: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
```

Reddened exactly both `kLineweightDefault` tests. **KILLED.**

---

## M10 — v6 `fromJson` defaults `linetype` to `byLayerLinetype`

**Criteria:** 9, 11. **Task:** 1 (first fired), re-fired independently in
Task 4. **Target:** `packages/jet_cad_2d/lib/src/document/node.dart`,
`InstanceNode.fromJson`.

```diff
 linetype: json['linetype'] == null
-    ? ReservedHandles.byBlockLinetype
+    ? ReservedHandles.byLayerLinetype
     : Handle.fromJson(json['linetype']),
```

**Command (Task 1):**
`CI=true dart test test/codec/instance_style_codec_test.dart`

```
00:00 +1 -1: the four fields are absent-tolerant and default to the no-op values [E]
  Expected: <3>
    Actual: <2>
```

**Command (Task 4, after the v5-bit-identity fixture was added):**
`CI=true dart test test/codec/instance_style_codec_test.dart`

```
00:00 +1 -1: the four fields are absent-tolerant and default to the no-op values [E]
  Expected: <3>
    Actual: <2>

00:00 +3 -2: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer [E]
  Expected: <4>
    Actual: <71>

Failing tests:
  test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
  test/codec/instance_style_codec_test.dart: the four fields are absent-tolerant and default to the no-op values
```

`Expected: <4>` is `ReservedHandles.continuousLinetype`'s raw handle value;
`Actual: <71>` is the fixture's STRUCT layer's linetype leaking through the
BYLAYER substitution — exactly the resolution consequence the spec names for
this mutant. `Expected: <3> Actual: <2>` on the sibling test is
`byBlockLinetype` vs `byLayerLinetype` by raw handle value. **KILLED**, on
both the migration criterion (9) and, as a bonus, the round-trip default
criterion's absent-tolerance case.

---

## M11 — `InstanceNode.toJson` omits `linetypeScale`

**Criteria:** 10. **Task:** 1. **Target:** `node.dart`, `toJson`.

```diff
       'linetype': linetype.toJson(),
-      'linetypeScale': linetypeScale,
     };
```

**Command:** `CI=true dart test test/codec/instance_style_codec_test.dart`

```
00:00 +0 -1: an instance round-trips all four style fields at non-default values [E]
  Expected: <4.0>
    Actual: <1.0>

Failing tests: (three more downstream failures in the same run, all
consequences of this test's assertion order — the round-trip test is the one
that must redden, and it does)
```

The dropped field silently defaults back to `1.0` (the multiplicative
identity) on read. **KILLED.**

---

## M12 — `metricsLimit` defaults to `kParagraphCacheLimit` (Plan 3f's own survivor)

**Criteria:** 12. **Task:** 5. **Target:**
`packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart`, the
`FlutterTextMeasurer` constructor.

```diff
-    this.metricsLimit = kMetricsCacheLimit,
+    this.metricsLimit = kParagraphCacheLimit,
```

**Command:** `CI=true flutter test` (whole Flutter suite, not just the new
file — this mutant's own history is that it survived a suite when tested too
narrowly)

```
00:02 +125 -1: .../test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim [E]
  Expected: <600>
    Actual: <512>

00:02 +147 -2: .../test/flutter_text_measurer_test.dart: the default metrics bound is not the paragraph bound [E]
  Expected: <0>
    Actual: <1>

00:04 +299 -2: Some tests failed.

Failing tests:
  .../test/flutter_text_measurer_test.dart: the default metrics bound is not the paragraph bound
  .../test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
```

**Reddens two tests, not one — reported honestly rather than trimmed to match
the single-test prediction.** `flutter_text_measurer_test.dart`'s
`the default metrics bound is not the paragraph bound` (added by Plan 3f's own
remedy `645b027`) catches the *metrics*-side symptom directly, because its own
sweep of 513 distinct metrics keys is already past the mutated bound. It
cannot and does not touch `liveParagraphCount` — it never calls `paragraphFor`.
This task's own `text_cache_invariants_test.dart` also reddens from the
*metrics* side of the same mutant, at `expect(measurer.liveMetricsCount,
kDistinctLabels)` (`Expected: <600> Actual: <512>`) — **not** the paragraph
side, as an earlier version of this entry claimed. That earlier wording named
`liveMetricsCount` and called it the paragraph side in the same clause, which
was wrong: `liveMetricsCount` is the metrics counter under any name. What this
mutant actually shows is that the metrics half is covered twice over, by two
independent tests reading two independent counters (`liveMetricsCount` here,
and the sibling file's own eviction pin) — it is not evidence that this task's
unique contribution, the paragraph half, is gated. **M13**, below, is the
mutant that proves that: it fails only at `liveParagraphCount`, and nothing
before this task ever called `paragraphFor`. Every other test in the
301-test suite (at the time this mutant was fired) stayed green. **KILLED**,
from two independent angles.

---

## M13 — `paragraphLimit` defaults to `kMetricsCacheLimit`

**Criteria:** 12. **Task:** 5. **Target:** same file, same constructor.

```diff
-    this.paragraphLimit = kParagraphCacheLimit,
+    this.paragraphLimit = kMetricsCacheLimit,
```

**Command:**
`CI=true flutter test test/invariants/text_cache_invariants_test.dart`

```
00:00 +0 -1: the default cache bounds hold 600 distinct keys the way they claim [E]
  Expected: <512>
    Actual: <600>

Failing tests:
  .../test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
```

`liveParagraphCount` read 600 (every insert kept, nothing evicted) instead of
the paragraph limit's 512. **KILLED.**

---

## M14 — `reference_walk.dart`'s `minTextCapPixels` default becomes `0.0`

**Criteria:** 13. **Task:** 5. **Target:**
`packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`, `referenceWalk`'s
parameter default.

```diff
-  double minTextCapPixels = kMinTextCapPixels,
+  double minTextCapPixels = 0.0,
```

**Command:**
`CI=true flutter test test/invariants/text_cache_invariants_test.dart`

```
00:00 +1 -1: referenceWalk culls sub-threshold text at its own default [E]
  Expected: ['BIG']
    Actual: ['TINY', 'BIG']
     Which: at location [0] is 'TINY' instead of 'BIG'
  TINY is 1 px of cap height against a 3.0 px default

Failing tests:
  .../test/invariants/text_cache_invariants_test.dart: referenceWalk culls sub-threshold text at its own default
```

**KILLED.**

---

## M15 — `draft_painter.dart`'s `_drawText` keeps `_culledText++` but drops the `return`

**Criteria:** 14. **Task:** 6. **Target:**
`packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`, `_drawText`, around
line 869.

```diff
 if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
   _culledText++;
-  return;
 }
```

**Command:**
`CI=true flutter test test/invariants/frame_accounting_test.dart`

```
00:00 +0 -1: text accounting closes: drawn + culled + skipped is every text leaf [E]
  Expected: <4>
    Actual: <5>

Failing tests:
  .../test/invariants/frame_accounting_test.dart: text accounting closes: drawn + culled + skipped is every text leaf
```

Without the `return`, the culled leaf falls through into the drawn path below
and is double-counted, so the sum exceeds the document's true text-leaf count.
**KILLED**, and only this test — the other two frame-accounting tests stayed
green.

---

## M16 — a painter text counter is not reset between paints

**Criteria:** 15. **Task:** 6. **Target:** same file, top of `paint()`.

```diff
 void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
   _skippedText = 0;
   _culledText = 0;
-  _textOps = 0;
   _skippedDeepInstances = 0;
```

**Command:**
`CI=true flutter test test/invariants/frame_accounting_test.dart`

```
00:00 +1 -1: a repeated frame is a repeated frame [E]
  Expected: (int, int, int, int):<(2, 1, 1, 0)>
    Actual: (int, int, int, int):<(4, 1, 1, 0)>

Failing tests:
  .../test/invariants/frame_accounting_test.dart: a repeated frame is a repeated frame
```

`textOpCount` accumulates across the two identical paints (2 + 2 = 4) while
the correctly-reset counters (`culledTextCount`, `skippedTextCount`,
`screenSpaceLeafCount`) stay unchanged. **KILLED**, and only this test.

---

## M17 — `VerticesDrawSink.text` drops the first delegated call

**Criteria:** 16. **Task:** 6. **Target:**
`packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`, `text()`.

```diff
+  int _frameTextOps = 0; // mutation counter
   @override
   void text(String text, Handle style, ResolvedStyle resolved) {
     _flushBeforeUnbatchable();
-    _fallback?.text(text, style, resolved);
+    if (_frameTextOps++ != 0) _fallback?.text(text, style, resolved);
   }
```

**Command:**
`CI=true flutter test test/invariants/frame_accounting_test.dart`

```
00:00 +2 -1: the vertices backend loses no text on the way through its fallback [E]
  Expected: <2>
    Actual: <1>

Failing tests:
  .../test/invariants/frame_accounting_test.dart: the vertices backend loses no text on the way through its fallback
```

The fixture draws two text ops; the guard drops the first delegated call, so
`canvasCallCount` (1) falls short of `textOpCount` (2). **KILLED**, and only
this test.

---

## Tally

| Category | Count | Which |
|---|---:|---|
| Killed | 17 | M1–M17 |
| Survivors | 0 | — |
| Restatements | 0 | — |
| Unmeasurable | 0 | — |

All seventeen named mutants were fired and all seventeen were killed by the
exact criterion each maps to in the spec's own table, with the reddened test
set matching the prediction in every case except M12 and M10, where the
transcript shows **more** tests reddening than the minimum predicted — both
recorded above as extra evidence, not trimmed to fit the narrower claim.

Unlike Plan 3f's mutation log, this plan's own seventeen mutants carry no
survivor. The prior plan's three survivor rows (M7's own defaulting bug,
caught only after being audited following its neighbors' pattern) were the
direct motivation for this plan's Decision 6 — moving the two structural
invariants this plan wrote into always-on tests sized from the bound under
test, rather than leaving them printed in a suite that does not run by
default.
