# Task 3 report: `linetypeScale` composes multiplicatively

## Step 1 — failing test added

Appended the `linetypeScale multiplies down the tree` group verbatim (per the
brief) to `packages/jet_cad_2d/test/document/instance_style_test.dart`, after
`dart format` reflowed the two long lines. Diff:

```diff
diff --git a/packages/jet_cad_2d/test/document/instance_style_test.dart b/packages/jet_cad_2d/test/document/instance_style_test.dart
index 77f3a2e..a8bf184 100644
--- a/packages/jet_cad_2d/test/document/instance_style_test.dart
+++ b/packages/jet_cad_2d/test/document/instance_style_test.dart
@@ -249,4 +249,39 @@ void main() {
           25);
     });
   });
+
+  group('linetypeScale multiplies down the tree', () {
+    test('entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0', () {
+      final doc = DraftDocument.empty();
+      final inner = addDefinition(doc, const Handle(200), 'BOLT');
+      final outer = addDefinition(doc, const Handle(210), 'PLATE');
+      final child =
+          addByBlockLine(doc, inner, const Handle(201), linetypeScale: 2.0);
+      addInstance(doc, const Handle(300), outer, linetypeScale: 8.0);
+      addInstance(doc, const Handle(310), inner,
+          parent: const Handle(210), linetypeScale: 4.0);
+
+      // Exact. Every factor is a power of two, so the product is
+      // representable and `Tolerance` would only hide a wrong answer.
+      expect(
+          resolveThrough(doc, [const Handle(300), const Handle(310)], child)
+              .linetypeScale,
+          64.0);
+    });
+
+    test('an INSERT at 1.0 leaves its child alone', () {
+      // The default's no-op property, asserted rather than assumed: this is
+      // what makes every pre-3f.1 document resolve unchanged. The entity's own
+      // scale is still 2.0, never 1.0 -- the identity on both sides would
+      // prove nothing.
+      final doc = DraftDocument.empty();
+      final def = addDefinition(doc, const Handle(200), 'BOLT');
+      final child =
+          addByBlockLine(doc, def, const Handle(201), linetypeScale: 2.0);
+      addInstance(doc, const Handle(300), def);
+
+      expect(
+          resolveThrough(doc, [const Handle(300)], child).linetypeScale, 2.0);
+    });
+  });
 }
```

## Step 2 — run it and watch it fail

Command:

```
cd packages/jet_cad_2d && CI=true dart test test/document/instance_style_test.dart --plain-name "linetypeScale multiplies"
```

Verbatim output:

```
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0
00:00 +0 -1: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0 [E]
  Expected: <64.0>
    Actual: <2.0>

  package:matcher                               expect
  test/document/instance_style_test.dart 266:7  main.<fn>.<fn>

00:00 +0 -1: linetypeScale multiplies down the tree an INSERT at 1.0 leaves its child alone
00:00 +1 -1: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

Matches the brief exactly: the `64.0` test fails reading `2.0` (the entity's
own scale, context ignored); the no-op guard passes already.

## Step 3 — connect both ends

`contextFor` (in `StyleContext(...)` construction):

```diff
-      linetypeScale: inherited.linetypeScale,
+      // Multiplies, never substitutes. DXF's rule for a nested entity's
+      // effective linetype scale is a product, so nesting composes without a
+      // special case for depth: entity x every enclosing INSERT x the header's
+      // global scale, which `DraftPainter` applies at the far end.
+      linetypeScale: inherited.linetypeScale * node.linetypeScale,
```

`styleFor` (in `ResolvedStyle(...)` construction):

```diff
-      linetypeScale: document.entities.linetypeScaleAt(slot),
+      // Before Plan 3f.1 this read `document.entities.linetypeScaleAt(slot)`
+      // alone. `StyleContext.linetypeScale` was constructed, copied, compared
+      // and hashed, and no code path read it to produce a drawing — and no
+      // test could tell, because every linetypeScale literal in the repository
+      // was 1.0, the multiplicative identity.
+      linetypeScale:
+          ctx.linetypeScale * document.entities.linetypeScaleAt(slot),
```

Both applied verbatim from the brief.

## Step 4 — run the test and the full engine suite

Command:

```
cd packages/jet_cad_2d && CI=true dart test test/document/instance_style_test.dart
```

Output:

```
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +5: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +6: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +7: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +8: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0
00:00 +9: linetypeScale multiplies down the tree an INSERT at 1.0 leaves its child alone
00:00 +10: All tests passed!
```

Ten tests, all green, as the brief predicted.

Full engine suite:

```
cd packages/jet_cad_2d && CI=true dart test
```

Tail of output:

```
00:02 +788: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +789: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +790: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +791: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +791: All tests passed!
```

All 791 tests passed. The two FNV fingerprint tests in
`test/testing/generate_document_test.dart` were checked separately and did
not move:

```
cd packages/jet_cad_2d && CI=true dart test test/testing/generate_document_test.dart
```

```
00:00 +0: loading test/testing/generate_document_test.dart
00:00 +0: generateDocument is deterministic across calls
00:00 +1: the default document is the one Plan 2 measured, byte for byte
00:00 +2: defaults reproduce the Plan 2 corpus structurally too
...
00:00 +18: All tests passed!
```

`dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

`dart format --output=none --set-exit-if-changed .`:

First run flagged the appended test group's formatting (long line wraps);
applied `dart format test/document/instance_style_test.dart`, then reran:

```
Formatted 112 files (0 changed) in 0.20 seconds.
```
exit code 0 — clean.

## Step 5 — fire mutants M4 and M5

Per the non-negotiable, the file was copied aside before mutating and
restored from the copy afterward (`git checkout` was never used):

```
cp lib/src/document/style_resolver.dart /tmp/.../scratchpad/style_resolver.dart.bak
```

### M4 — `styleFor` reverts to `linetypeScale: document.entities.linetypeScaleAt(slot)`

Edit applied:

```diff
-      linetypeScale:
-          ctx.linetypeScale * document.entities.linetypeScaleAt(slot),
+      linetypeScale: document.entities.linetypeScaleAt(slot),
```

Command: `CI=true dart test test/document/instance_style_test.dart --plain-name "linetypeScale multiplies"`

Output:

```
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0
00:00 +0 -1: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0 [E]
  Expected: <64.0>
    Actual: <2.0>

  package:matcher                               expect
  test/document/instance_style_test.dart 266:7  main.<fn>.<fn>

00:00 +0 -1: linetypeScale multiplies down the tree an INSERT at 1.0 leaves its child alone
00:00 +1 -1: Some tests failed.
```

M4 killed: the `64.0` test reddens reading `2.0`, exactly as the brief
predicted; the no-op guard test still passed.

Restored from the backup copy:

```
cp /tmp/.../scratchpad/style_resolver.dart.bak lib/src/document/style_resolver.dart
```

`diff` against the backup confirmed byte-identical restoration.

### M5 — `contextFor` reverts to `linetypeScale: node.linetypeScale`

Edit applied:

```diff
-      linetypeScale: inherited.linetypeScale * node.linetypeScale,
+      linetypeScale: node.linetypeScale,
```

Command: `CI=true dart test test/document/instance_style_test.dart --plain-name "linetypeScale multiplies"`

Output:

```
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0
00:00 +0 -1: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0 [E]
  Expected: <64.0>
    Actual: <8.0>

  package:matcher                               expect
  test/document/instance_style_test.dart 266:7  main.<fn>.<fn>

00:00 +0 -1: linetypeScale multiplies down the tree an INSERT at 1.0 leaves its child alone
00:00 +1 -1: Some tests failed.
```

M5 killed: the `64.0` test reddens reading `8.0` (dropping the outer INSERT's
factor, keeping only the inner INSERT's `4.0 x` the entity's own `2.0`),
exactly as the brief predicted; the no-op guard test still passed.

Restored from the backup copy, confirmed byte-identical, then reran the full
`instance_style_test.dart` suite to confirm all ten tests green again:

```
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +5: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +6: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +7: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +8: linetypeScale multiplies down the tree entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0
00:00 +9: linetypeScale multiplies down the tree an INSERT at 1.0 leaves its child alone
00:00 +10: All tests passed!
```

## Step 6 — Flutter suite

`git status --short packages/jet_cad_2d_flutter/test/golden` before the run:
empty (no output).

Command:

```
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

Tail of output:

```
00:04 +295 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon closes the path
00:04 +296 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon with fewer than 3 points draws nothing
00:04 +297 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle draws a filled circle
00:04 +298 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:04 +299 ~1: All tests passed!
```

299 tests, all passed, no failures (the `~1` markers are pre-existing skips
unrelated to this change, present on every run of this suite).

`git status --short packages/jet_cad_2d_flutter/test/golden` after the run:

```
(no output)
```

Empty — no PNG regenerated, no golden moved.

Full repo `git status --short` after all runs:

```
 M packages/jet_cad_2d/lib/src/document/style_resolver.dart
 M packages/jet_cad_2d/test/document/instance_style_test.dart
```

Only the two intended files touched; `analysis_options.yaml` was not
rewritten this run, so there was nothing to leave unstaged.

## Step 7 — commit

Committed exactly the two files above with the commit message from the brief
(verbatim).

