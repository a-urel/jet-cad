# Task 7 report: The harness draws text, and measures it

Commit: `e371a13` — `feat(harness): arm C draws text, and SPIKE_TEXT puts
labels it must patch in the corpus`

## What was implemented

Wired everything Tasks 1–6 landed in `jet_cad_2d_flutter` into the harness's
arm C:

- **`main.dart`**
  - `kSpikeText` (`SPIKE_TEXT`, `String.fromEnvironment`, `'false'` default,
    throws on anything else — `kSpikeFills`'s shape).
  - `kPatchedLabelCount = 8`, `kPatchedLabelHeight = 600.0`.
  - `_addPatchedLabels(doc, entityCount)`: adds 8 labels (`'ROOM 1'` ..
    `'ROOM 8'`), each immediately followed (higher handle) by a lineweight-100
    solid stroke through its middle, spaced along x in the corridor
    `_addFillRegions` already uses.
  - `spikeDocument({..., bool? text})`: `withText = text ?? kSpikeText`; when
    on, `generateDocument` gets `labelFraction: 0.02`,
    `attributedInstanceFraction: 0.2` (harnessDocument's own fractions), and
    `_addPatchedLabels` runs after.
  - `GpuSpikeApp(..., drawText: kDrawText)` in `main()`.
- **`gpu_arm.dart`**
  - `GpuSpikeApp` gained `required this.drawText`.
  - `_buildResidentGeometry`: `DraftPainter(..., drawText: widget.drawText)`
    (was hard-coded `true`); `dpr` read once from `MediaQuery` and reused for
    the collector, `classifyTextPatches` and `ResidentGeometry.create`;
    `GeometryCollector(..., measurer: harnessMeasurer, textStyleOf:
    widget.document.textStyleOf)`; `classifyTextPatches` run and timed
    (`classifyWatch`); `ResidentGeometry.create(..., texts: collector.texts,
    patches: patchList, devicePixelRatio: dpr, maxPatchWidth: (widget.viewport
    .width * dpr).round(), maxPatchHeight: (widget.viewport.height *
    dpr).round())`; `GpuDrawBackend(geometry, collectionCamera, measurer:
    harnessMeasurer, textStyleOf: widget.document.textStyleOf)`.
  - New `GpuSpikeState` fields: `textOps`, `patches`, `subBufferBytes`,
    `patchTargetBytes`, `classifyMs`.
  - `GSPIKE collect+upload` line grows: `textOps=N patches=P subBuffer=X.XX MB
    patchTargets=Y.YY MB classify=Z.Z ms`.
  - `GpuArmPainter.paint`: `backend.paint(canvas, camera.value, size,
    devicePixelRatio)` replaces the `render` + `drawImageRect` pair; ownership
    comment rewritten for `1 + P` handles per frame, Controller ruling R6-2
    cited, nothing disposed (Task 9's job to measure the churn).
  - `GpuPhaseReport` gained `patchesRendered`/`patchesClipped`/
    `patchesOffscreen` (default 0), read right after each phase from
    `state.backend`'s counters (describe the phase's **last frame only**) and
    printed as a new `GSPIKE C residentGpu (jet_cad_2d_flutter) | <phase> |
    patches rendered=R clipped=C offscreen=O` line beside the existing `gpu
    submits=` line, for arm C only.
  - `GSPIKE note` rewritten: no more "text: Plan E's job"; states arm C draws
    text through the compositor, reports label/patch counts, and names
    `DRAW_TEXT=false` as criterion 11's control.
  - Section comment at the top of the file: "What arm C still does not draw"
    rewritten to say nothing is left undrawn since Plan E, and that what
    remains unwired into this harness is `DraftCanvas`'s own tiled/blit path
    drawing *through* the backend, which is Plan F's job.
  - `import 'main.dart' show harnessMeasurer;` added — `gpu_arm.dart` needed
    the harness's one `FlutterTextMeasurer` instance and `main.dart` already
    imports `gpu_arm.dart`; Dart permits the two-file cycle and `flutter
    analyze` confirms it (see Concerns for why I didn't use
    `widget.document.textMeasurer` instead).
- **`.vscode/launch.json`**: two new configurations after the fills pair —
  `2d: GPU spike -- text ON (criterion 11, DRAW_TEXT=true)` and `2d: GPU spike
  -- text ON, DRAW_TEXT=false (criterion 11 control)` — both
  `SPIKE_TEXT=true`, the second adds `DRAW_TEXT=false`, each with a comment
  saying the pair is read as a difference.
- **`apps/dev_harness_2d/test/spike_text_test.dart`**: new, see below.

## Deviation from the brief, and why (read before trusting the first test)

The brief's Step 1 test, copied verbatim, asserted:

```dart
expect(_textCount(spikeDocument(entityCount: _kEntities)), 0);
expect(_textCount(spikeDocument(entityCount: _kEntities, text: false)), 0);
```

This cannot pass for **any** implementation of `spikeDocument`, because
`generateDocument` (`packages/jet_cad_2d/lib/src/testing/generate_document.dart`,
untouched by this task) has *always* added a small unconditional baseline of
plain, contentless `EntityKind.text` entities to its root-level content,
independent of `labelFraction`:

```dart
final baseTextCount = math.min(300, rootEntityCount ~/ 100);
final textCount = labelFraction > 0 ? 0 : baseTextCount;   // NOT 0 when labelFraction == 0
```

Confirmed by git archaeology (`git log -S baseTextCount`): this is the
*original* formula (`textCount = math.min(300, rootEntityCount ~/ 100)`,
unconditional) from before `labelFraction` was ever added in commit
`2f18a02`; that commit's own doc comment says turning `labelFraction` off
"reduces to the original formula exactly" — i.e. to `baseTextCount`, not to
zero. I verified this empirically with a scratch test replicating
`spikeDocument`'s exact `generateDocument` call (`entityCount: 2000,
definitionCount: 20, instanceCount: 200, ..., labelFraction: 0,
attributedInstanceFraction: 0`): it returns **16** text entities, matching
the RED failure I saw (`Actual: <16>` against `Expected: <0>`).

This is true of `harnessDocument()` too (same `labelFraction: kTextCorpus ?
0.02 : 0` pattern) — the measurement corpus has always carried this baseline,
`TEXT` define or not. It predates Plan E entirely and is unrelated to
`SPIKE_TEXT`.

I could not fix this in `jet_cad_2d` (explicitly out of scope — "pure Dart,
UNTOUCHED" per the task's own context, and no task-7 file list names it), and
there is no `spikeDocument`-side parameter that reaches zero either (the only
lever, `labelFraction`, either yields `baseTextCount` at 0 or a positive
`labelCount` at any value above 0 — never zero for `rootEntityCount >= 100`).

I rewrote the first test's assertion to test the same underlying claim
("SPIKE_TEXT is inert at its default") the way `spike_fill_scale_test.dart`
already tests inertness for `SPIKE_FILL_SCALE` — by comparing the default
call against the explicit-off call for equality, not against a literal
absolute value — plus an explicit check that neither document carries any of
`_addPatchedLabels`'s own `'ROOM '`-prefixed labels. This preserves exactly
what "inert at default" needs to mean (turning the flag off two different
ways gives the same document, and adds none of the Task-7 content) without
asserting something the shared corpus generator has never been true of. The
second test (`patches.length >= kPatchedLabelCount`) is untouched, exactly as
given, and the brief's "do not lower the assertion" instruction was honoured
there.

I judged this the right call under Auto Mode rather than stopping to ask,
because the finding is unambiguous (git-verified, empirically reproduced) and
the fix is small, local to the new test file, and does not touch
`jet_cad_2d`, the defines, the constants, `_addPatchedLabels`, or any other
verbatim requirement. Flagging clearly here so the reviewer can independently
verify the git-archaeology claim and the empirical measurement.

## TDD evidence

**RED** — `flutter test test/spike_text_test.dart` against the brief's
literal test code, before any implementation:

```
test/spike_text_test.dart:20:62: Error: No named parameter with the name 'text'.
test/spike_text_test.dart:24:56: Error: No named parameter with the name 'text'.
test/spike_text_test.dart:43:49: Error: Undefined name 'kPatchedLabelCount'.
00:00 +0 -1: Some tests failed.
```

After implementing `spikeDocument`'s `text` parameter and `kPatchedLabelCount`
but before adjusting the first test's assertion (compile succeeded, ran):

```
00:00 +0: SPIKE_TEXT is inert at its default
00:00 +0 -1: SPIKE_TEXT is inert at its default [E]
  Expected: <0>
    Actual: <16>
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/spike_text_test.dart 19:5                      main.<fn>
00:00 +0 -1: with text on, the corpus carries labels, and some are patched
00:00 +1 -1: Some tests failed.
```

**GREEN** — after the documented deviation:

```
00:00 +0: SPIKE_TEXT is inert at its default
00:00 +1: with text on, the corpus carries labels, and some are patched
00:00 +2: All tests passed!
```

## Measured patch count

`kPatchedLabelHeight = 600.0` (the brief's own value) worked without needing
to be raised — the brief's amendment note anticipated the labels might be
culled at the fitted camera and allowed raising the height if so; they were
not. A debug run of the second test printed:

```
MEASURED patches.length=37 textCount=54
```

37 patches (>= `kPatchedLabelCount = 8`), 54 total resident labels (16 base
floor texts + ~30 vocabulary labels from `labelFraction: 0.02` + 8 patched
labels). Every one of `_addPatchedLabels`'s 8 deliberate patches is
comfortably covered; no adjustment to `kPatchedLabelHeight` was needed.

## Gates

### `packages/jet_cad_2d_flutter`

```
$ flutter test
...
00:08 +617: All tests passed!
```
Exit 0.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)
```
Exit 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```
Exit 0.

### `packages/jet_cad_2d`

```
$ dart test
...
00:03 +798: All tests passed!
```
Exit 0.

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```
Exit 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
```
Exit 0.

### `apps/dev_harness_2d`

```
$ flutter test --concurrency=1
...
00:16 +77: All tests passed!
```
Exit 0.

```
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
```
Exit 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 20 files (0 changed) in 0.04 seconds.
```
Exit 0.

(First `dart format` run, before formatting, printed `Changed lib/gpu_arm.dart`,
`Changed lib/main.dart`, `Changed test/spike_text_test.dart` — `Formatted 20
files (3 changed)`, exit 1 — expected for hand-written code; `dart format .`
fixed it, confirmed by the zero-changed re-run above.)

## `git status --short` before commit

```
 M .vscode/launch.json
 M apps/dev_harness_2d/lib/gpu_arm.dart
 M apps/dev_harness_2d/lib/main.dart
?? apps/dev_harness_2d/test/spike_text_test.dart
```

No `analysis_options.yaml` touched.

## Files changed

- `apps/dev_harness_2d/lib/main.dart` (modified)
- `apps/dev_harness_2d/lib/gpu_arm.dart` (modified)
- `apps/dev_harness_2d/test/spike_text_test.dart` (new)
- `.vscode/launch.json` (modified)

## Self-review

- **Completeness**: every define (`kSpikeText`), constant
  (`kPatchedLabelCount`, `kPatchedLabelHeight`), function
  (`_addPatchedLabels`), `spikeDocument` signature change, `GpuSpikeApp
  (drawText:)`, `GpuSpikeState` fields (`textOps`, `patches`,
  `subBufferBytes`, `patchTargetBytes`, `classifyMs`), both GSPIKE line
  changes (`collect+upload` and the new per-phase patches line), the GSPIKE
  note rewrite, the top-of-file section comment rewrite, both launch.json
  entries, and the test file are all present. Checked each against the brief
  line by line.
- **Quality**: comments follow the file's own long-form reasoned style;
  every comment I touched is true of the code as committed (checked
  specifically for lingering "Plan E's job" language — none remains).
- **Discipline**: nothing added beyond the brief except the one import
  (`main.dart show harnessMeasurer`, required to reach the brief's own
  `harnessMeasurer` reference from `gpu_arm.dart`) and the test-assertion
  deviation documented above.
- **Testing**: the harness test asserts `patches.length >=
  kPatchedLabelCount` after a real `DraftPainter.paint` at the fitted camera,
  unmodified from the brief; output is pristine (all three gates print `All
  tests passed!` / `No issues found!` / `0 changed`, pasted above, not
  synthesised).

## Concerns

1. **The Step 1 test deviation** (see above) — the most significant thing to
   verify independently. I'm confident in the git-archaeology and empirical
   evidence, but this is exactly the kind of judgment call a reviewer should
   re-check rather than take on faith.
2. **The `gpu_arm.dart` → `main.dart` import** creates a two-file circular
   import (`main.dart` already imports `gpu_arm.dart`). Dart permits this
   (confirmed: `flutter analyze` reports no issues, and all tests import and
   run cleanly) and it was the most direct way to reach `harnessMeasurer`,
   which the brief explicitly names as the value to pass — the alternative
   (`widget.document.textMeasurer as FlutterTextMeasurer`, the same measurer
   by construction since `spikeDocument` builds the document on
   `harnessMeasurer`) would avoid the cycle but deviates further from the
   brief's literal `measurer: harnessMeasurer` wording. Flagging so the
   reviewer can judge which is preferable; I judged the cycle harmless and
   the closer match to the brief's exact code worth it.
3. Did not run the harness app itself (`flutter run`), per instructions —
   that is Task 9's device run.

## Fix round 1 (Ruling R7-1)

Commit: `e2e811a` — `test(harness): the deliberate labels are the patches, by
construction (Ruling R7-1)`

Reviewer findings addressed:

1. **[Important, R7-1]** `spike_text_test.dart`'s
   `patches.length >= kPatchedLabelCount` passed even with
   `_addPatchedLabels`'s call site deleted, because this corpus's vocabulary
   labels (`labelFraction: 0.02`) contribute 29 incidental patches of their
   own (measured: 37 total = 29 + `kPatchedLabelCount` 8). Added, on top of
   the untouched count-floor assertion: collect `collector.texts` indices
   whose `.text.startsWith('ROOM ')` (the deliberate labels' own marker —
   plain floor texts carry the empty string, vocabulary labels have no
   `'ROOM'` entry), assert there are exactly `kPatchedLabelCount` of them, and
   assert every one of those indices is in `patches.map((p) => p.textIndex)`.
   The test's comment names the mutation this catches (deleting
   `if (withText) _addPatchedLabels(doc);`) and the 29-incidental-patch reason
   the raw count alone could not catch it.
2. **[Minor]** Dropped `import 'main.dart' show harnessMeasurer;` from
   `gpu_arm.dart` (the only two uses of that import). `GeometryCollector`'s
   collector now takes `widget.document.textMeasurer` directly (matches the
   abstract `TextMeasurer?` parameter, no cast). `GpuDrawBackend`'s call now
   takes `widget.document.textMeasurer as FlutterTextMeasurer` with a
   one-line comment that the cast is safe by construction — every document
   `GpuSpikeApp` is handed comes from `spikeDocument()`, built on
   `harnessMeasurer`. Confirmed nothing else from `main.dart` was reached
   through that import (`grep -n harnessMeasurer gpu_arm.dart` showed only
   the import and these two call sites before the fix).
3. **[Minor]** `_addPatchedLabels(DraftDocument doc, int entityCount)` never
   read `entityCount`; removed the parameter and updated the one call site
   (`_addPatchedLabels(doc)`).

### Mutation verification (new, for finding 1)

Restoring the exact regression the reviewer described — commenting out
`if (withText) _addPatchedLabels(doc);` in `spikeDocument` — turns the
strengthened test red:

```
00:00 +1 -1: with text on, the corpus carries labels, and some are patched [E]
  Expected: <8>
    Actual: <0>
  every deliberate patched label reached the collector
```

Reverted immediately after (confirmed via `git diff --stat` showing only the
intended fix-3 change to `main.dart` remained).

### Covering test

```
$ cd apps/dev_harness_2d && flutter test --concurrency=1 test/spike_text_test.dart
...
00:00 +0: SPIKE_TEXT is inert at its default
00:00 +1: with text on, the corpus carries labels, and some are patched
00:00 +2: All tests passed!
```
Exit 0.

### All three gates, re-run after the fixes

```
$ cd apps/dev_harness_2d && flutter test --concurrency=1
...
00:15 +77: All tests passed!
```
Exit 0.

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.4s)
```
Exit 0.

```
$ cd apps/dev_harness_2d && dart format --output=none --set-exit-if-changed .
Formatted 20 files (0 changed) in 0.03 seconds.
```
Exit 0.

```
$ cd packages/jet_cad_2d_flutter && flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```
Exit 0. (Requested per the review even though this diff touches nothing in
`jet_cad_2d_flutter` — the removed import and the two measurer call sites are
entirely inside `apps/dev_harness_2d`; `packages/jet_cad_2d` and
`packages/jet_cad_2d_flutter`'s own full test suites were already green after
the initial commit and nothing in this fix round could have changed that.)

### `git status --short` before commit

```
 M apps/dev_harness_2d/lib/gpu_arm.dart
 M apps/dev_harness_2d/lib/main.dart
 M apps/dev_harness_2d/test/spike_text_test.dart
```

No `analysis_options.yaml` touched.
