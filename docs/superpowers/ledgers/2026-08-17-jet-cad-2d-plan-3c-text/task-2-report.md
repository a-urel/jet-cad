# Task 2 report: `TextMetrics`, the measurer seam, and the metric model

## What I implemented

- New file `packages/jet_cad_2d/lib/src/document/text_metrics.dart`:
  - `kNominalTextPixels = 100.0` and `kCapHeightRatio = 0.7`, each with a doc
    comment explaining why (cache-key stability across sizes; `dart:ui`
    exposes no cap height).
  - `TextMetrics({advanceWidth, ascent, descent, capHeight})`, immutable, plus
    `TextMetrics.zero`.
  - `abstract class TextMeasurer { TextMetrics measure({required String text,
    required TextStyleRecord style}); }` — takes the record, not a `Handle`,
    per decision 3 in the task (a measurer is built before the document
    exists).
  - `InsertionPointMeasurer`, now returning `TextMetrics.zero` — kept its
    "declared lower bound, not a bug" doc-comment meaning.
  - `MetricModelMeasurer({advanceRatio = 0.55, ascentRatio = 0.8,
    descentRatio = 0.2, capRatio = kCapHeightRatio})`. Ascent/descent ratios
    differ by construction (0.8 vs 0.2) so no future consumer can get a
    correct answer by accident on a symmetric model.
  - **Departure from the brief's literal snippet, per the orchestrator's
    decision 1**: the memo is a `static final Map<(int length, double
    advanceRatio, double ascentRatio, double descentRatio, double capRatio),
    TextMetrics>`, keyed on the ratios as well as string length — not `Map<int,
    TextMetrics>` keyed on length alone. Two `MetricModelMeasurer`s built with
    different ratios now get independent cache entries instead of silently
    reading each other's memoized metrics.
  - `measure` uses `putIfAbsent`, so a repeat call for the same key returns
    the identical `TextMetrics` instance (decision 2: the query-allocation
    invariant test needs this, not just wants it).

- `packages/jet_cad_2d/lib/src/document/extents.dart`: deleted the old
  `TextMeasurer`/`InsertionPointMeasurer` (the four-argument,
  `Handle`-taking, `Aabb2`-returning versions) and imported the new ones from
  `text_metrics.dart`. `entityBounds`'s text/attrib case is stubbed to
  `return Aabb2(payload.pointAt(0), payload.pointAt(0));` with the comment
  `// Task 4 replaces this.`, exactly as the brief specifies. `entityBounds`'s
  own signature (`measurer: TextMeasurer`, `textStyle: Handle`) is unchanged —
  only its text-case body changed — so every call site keeps compiling
  unmodified.

- `packages/jet_cad_2d/lib/jet_cad_2d.dart`: added
  `export 'src/document/text_metrics.dart';` (`text_scalars.dart` was already
  exported from Task 0/1, so no change needed there).

- Mechanical fallout, not in the brief's file list but required to reach
  green (the brief's Step 5 explicitly predicts these errors): `extents.dart`
  now only *imports* (does not *export*) `text_metrics.dart`, so two files
  that referenced `TextMeasurer`/`InsertionPointMeasurer` by name purely
  through their `import 'extents.dart'` needed a direct import added:
  - `lib/src/document/draft_document.dart`: added `import 'text_metrics.dart';`.
  - `lib/src/codec/json_codec.dart`: added
    `import '../document/text_metrics.dart';`, and removed its now-unused
    `import '../document/extents.dart';` (it never called `entityBounds`
    directly, only referenced the measurer types).
  `container_index.dart` and `spatial_index.dart` needed no changes — they
  pass `measurer: doc.textMeasurer` by value, never naming `TextMeasurer` as a
  type literal, so Dart's type inference didn't need the import.

## TDD evidence

**RED** — `cd packages/jet_cad_2d && dart test test/document/text_metrics_test.dart`:

```
Failed to load "test/document/text_metrics_test.dart":
test/document/text_metrics_test.dart:13:15: Error: Method not found: 'MetricModelMeasurer'.
test/document/text_metrics_test.dart:16:53: Error: Undefined name 'kNominalTextPixels'.
...
```

Failed for the right reason: the test file referenced symbols
(`MetricModelMeasurer`, `kNominalTextPixels`, `TextMetrics`) that did not
exist yet, and called `InsertionPointMeasurer().measure(text:, style:)` with
the new two-argument shape against the still-old four-argument
implementation (`Required named parameter 'height' must be provided`).

**GREEN** — after implementing `text_metrics.dart`, moving the seam in
`extents.dart`, exporting it from `jet_cad_2d.dart`, and fixing the two
import fallout sites:

- `dart analyze` → `No issues found!`
- `dart test` → `+675: All tests passed!` (full engine suite, not just the
  new file)
- `dart format --output=none --set-exit-if-changed .` → clean after
  formatting the two new files (the formatter re-wrapped the record-typed map
  key and one long test name; re-ran format then the exit-code check, both
  clean)

I also confirmed `packages/jet_cad_2d_flutter` (the sibling package that
consumes `jet_cad_2d`) still analyzes clean, since nothing there yet
implements the old `TextMeasurer` interface (`grep` found no
`implements TextMeasurer` outside `text_metrics.dart` itself, and no
`TextMeasurer`/`InsertionPointMeasurer` references anywhere under
`packages/jet_cad_2d_flutter` or `packages/jet_cad`).

## Test file

`packages/jet_cad_2d/test/document/text_metrics_test.dart` has four tests:

1. The metric model is deterministic and its ascent differs from its
   descent — from the brief, checks every ratio→metric multiplication.
2. `measure` returns the identical instance on a repeat call — from the
   brief, checks `identical(a, b)`; would fail if `measure` allocated fresh
   each time.
3. **Added beyond the brief's snippet**, directly implementing decision 1:
   "the memo is keyed by ratios, not only by string length" — builds two
   `MetricModelMeasurer`s with different `advanceRatio`s, measures the same
   two-character string on both, and asserts the two `advanceWidth`s differ.
   This is the test the orchestrator's brief said Task 4 would need; I wrote
   it now since the memo's key shape is a Task 2 decision, not a Task 4 one,
   and a length-only key would pass every test in the brief's own snippet
   while still being wrong.
4. The insertion-point measurer is a declared lower bound — from the brief,
   checks `same(TextMetrics.zero)` (identity, not equality).

## Self-review

- **Completeness**: every symbol the brief's interface list names exists
  with the exact signature named (`TextMetrics`, `TextMetrics.zero`,
  `TextMeasurer.measure({text, style})`, `InsertionPointMeasurer`,
  `MetricModelMeasurer` with its four named ratio parameters and defaults,
  both constants). The stub in `entityBounds` matches the brief's exact
  code and comment.
- **Naming**: matches the brief verbatim; no renames.
- **YAGNI**: did not implement any geometry-building logic in `entityBounds`
  (that is Task 3/4's job, as the orchestrator's decision 4 explicitly warns
  against duplicating). Did not add anything to `MetricModelMeasurer` beyond
  what the brief and decisions require (no extra fields, no configurability
  the task didn't ask for).
- **Would each test fail if the implementation were wrong?** Checked each
  by construction: ratio math is asserted with `closeTo` against literal
  expected values (test 1); memoization is asserted via `identical` (test 2);
  the ratio-keyed memo is asserted by forcing a cache key collision under a
  length-only keying scheme and checking the results differ (test 3); the
  lower-bound singleton is asserted via `same` (test 4). None of the four
  would pass under a naive or partially-wrong implementation.
- **Doc comments**: written to explain why (cache-key stability, the
  `dart:ui` cap-height gap, why the measurer takes a record and not a
  handle, why ascent/descent must differ), following the codebase's
  established style.

## Concerns

- None blocking. The one thing worth flagging to whoever picks up Task 3/4:
  the memo in `MetricModelMeasurer` is a `static final` shared across every
  instance of the class (matching the brief's own snippet, which also uses
  a `static` cache) — it is unbounded and never evicted, which is fine for
  test-only use but would not be an appropriate pattern to copy verbatim
  into a real font-backed measurer without a bound or an LRU policy. That
  measurer does not exist yet, so this is a note for later, not a defect
  here.
- `entityBounds`'s `measurer` and `textStyle` parameters are now unused
  inside the text/attrib case body (only used by the other cases' shared
  signature). `dart analyze` does not flag unused named parameters, and
  removing them would break every call site for no benefit before Task 4
  needs them again, so I left the signature untouched as the brief intends.

## Files changed

- `packages/jet_cad_2d/lib/src/document/text_metrics.dart` (new)
- `packages/jet_cad_2d/test/document/text_metrics_test.dart` (new)
- `packages/jet_cad_2d/lib/src/document/extents.dart`
- `packages/jet_cad_2d/lib/jet_cad_2d.dart`
- `packages/jet_cad_2d/lib/src/document/draft_document.dart`
- `packages/jet_cad_2d/lib/src/codec/json_codec.dart`

Commit: `2a868b9 feat(jet_cad_2d): add the TextMetrics seam and a deterministic metric model`
