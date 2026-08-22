# Plan 3f — Text Wiring and Level of Detail — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a document built the ordinary way draw text, stop the painter and the sink from keeping two paragraph caches, and skip laying out text too small to read.

**Architecture:** The document becomes the single owner of the `TextMeasurer`; `DraftCanvas` borrows it and refuses a document that carries one which cannot lay out paragraphs. `FlutterTextMeasurer`'s single `(text, styleHandle, argb)` cache splits into a colour-free metrics map and a coloured paragraph map with separate bounds and separate eviction counters, so a full `extents` sweep cannot evict what the paint path had warm. `DraftPainter._drawText` gains an early return that culls text whose on-screen cap height is below a threshold, placed **before** the `measure()` call because after it no layout is saved.

**Tech Stack:** Dart 3.13, Flutter 3.47.1, `package:test`, `flutter_test`, `dart:ui` `Paragraph`/`ParagraphBuilder`.

**Spec:** [docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md](../specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md) — binding authority. Read it before Task 1. Where this plan and the spec disagree, the spec wins and the disagreement is a ruling to record.

**Branch:** `main`, worked directly, no worktree. Same arrangement as Plan 3e.

## Global Constraints

Copied verbatim from the spec's own Global Constraints section. Every task's requirements implicitly include all of these.

- The frame path allocates nothing per entity in steady state, and O(1) per flush.
- Draw order is ascending handle value, stable across undo, save, load and purge.
- Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.
- Never commit `analysis_options.yaml`. Also never commit `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`, which `flutter drive` rewrites.
- Never synthesize test output.
- Never `git checkout` a file to revert a mutation — copy it aside and restore from the copy in a `finally`.
- Code, comments and commit messages in English.
- Every task ends green on all three packages: test, analyze, format.
- **This plan may not amend `CLAUDE.md`.** A gate passable by editing the rule it is measured against is not a gate.

### Every task ends green

```sh
cd packages/jet_cad_2d          && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter  && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d          && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**`CI=true` is not decoration.** Without it `dart test` blocks for minutes at roughly 0% CPU on Dart's analytics phone-home. Plan 3e lost several agent runs to this before a reviewer found it.

After any `flutter pub get`, run `git status` and confirm no `analysis_options.yaml` is modified.

---

## File Structure

**Modified — `packages/jet_cad_2d_flutter/lib/src/`**

| file | responsibility after this plan |
|---|---|
| `flutter_text_measurer.dart` | two maps, two bounds, two constructor parameters, per-map eviction counters, a disposed metrics probe |
| `draft_canvas.dart` | resolves the sink's measurer from the document, refuses a document without a real one, forwards `minTextCapPixels`, no longer disposes the cache |
| `draft_painter.dart` | the LOD early return, `culledTextCount`, `kMinTextCapPixels`, `minTextCapPixels` |
| `reference_walk.dart` | the same LOD rule, derived independently, behind a new `minTextCapPixels` parameter |

**Modified — tests and harness**

`test/flutter_text_measurer_test.dart`, `test/canvas_draw_sink_test.dart`, `test/draft_canvas_test.dart`, `test/render_backend_test.dart`, `test/frame_path_seam_test.dart`, `test/text_paint_test.dart`, `test/draft_painter_root_test.dart`, `test/differential_test.dart`, `test/support/fixtures.dart`, `test/support/sink_comparison.dart`, `test/rig/paint_microbench_test.dart`, `test/golden/dash_ladder_golden_test.dart`, `test/golden/fill_ladder_golden_test.dart`, `apps/dev_harness_2d/lib/main.dart`, `apps/dev_harness_2d/lib/measurement_rig.dart`, `apps/dev_harness_2d/integration_test/frame_timing_test.dart`, `STATUS.md`.

**Created**

`test/golden/text_lod_ladder_golden_test.dart` and six PNGs, `test/text_lod_test.dart`, `docs/superpowers/notes/2026-08-22-plan-3f-results.md`, `docs/superpowers/notes/plan-3f-mutation-log.md`.

**Untouched: the whole of `packages/jet_cad_2d`.** A task that believes it needs an engine change has found a design problem, not a licence. Record it as a ruling and raise it.

---

## Task 1: STATUS.md renumbering, 3f to 3g

**Files:**
- Modify: `STATUS.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing in code. It clears a naming collision — every later task writes "3f" meaning *this* plan, and `STATUS.md` currently uses "3f" for the picture cache.

**Why this is not `sed`.** `STATUS.md` holds fourteen occurrences of `3f`. Three of them are prose *about the previous renumbering* and rewriting them destroys the history that explains why the numbers moved. One more splits rather than renumbers.

- [ ] **Step 1: List the fourteen and classify each**

Run:

```bash
grep -n "3f" STATUS.md
```

Expected: fourteen lines, at `:270`, `:365`, `:371`, `:436`, `:622`, `:633`, `:635`, `:692`, `:697`, `:700`, `:743`, `:748`, `:752`, `:754`.

Write the classification into the task report as a table — line, quoted text, and one of `renumber` / `prose, leave` / `split`. The three at `:622`, `:633` and `:635` are `prose, leave`: they read "fills is 3e and the picture cache is 3f" and "every `3d`/`3e`/`3f` above was swept", which are statements about what happened when the vertices sink took the 3d slot. `:436` is `split`: "Whole-drawing thrash → the picture cache's text LOD (Plan 3f)" names an item this plan takes, so it becomes "Plan 3f" meaning text LOD, while the picture cache around it becomes 3g.

- [ ] **Step 2: Renumber the ten**

Edit each `renumber` line so `3f` reads `3g`, and change the section heading `### Plan 3f — the definition/tile picture cache` to `### Plan 3g — the definition/tile picture cache`.

- [ ] **Step 3: Add a note beside the prose lines**

Immediately after the paragraph containing `:633`, add:

```markdown
**Renumbered again on 2026-08-22.** Text wiring and text LOD were split out of
the picture cache and took the `3f` slot, so **the picture cache is now 3g**.
The sentence above describes the *earlier* move and is left as written: it is
the record of why the numbers shifted the first time, not a statement about the
current numbering.
```

- [ ] **Step 4: Add the Plan 3f section**

Under `## Roadmap after 3d`, before the 3g section, add:

```markdown
### Plan 3f — text wiring and level of detail

In flight. Spec:
[docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md](docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md).
Plan:
[docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md](docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md).

Two defects: a document built the ordinary way carries `InsertionPointMeasurer`
and draws no text without reporting anything, and the painter and the sink read
different measurers. Plus text LOD, which is the one of Plan 3g's four
subsystems that depends on none of the other three.
```

- [ ] **Step 5: Verify no stale reference remains**

Run:

```bash
grep -n "3f" STATUS.md | grep -v "text wiring\|text LOD\|Renumbered again\|Plan 3f — text\|plan-3f"
```

Expected: exactly the three `prose, leave` lines and nothing else.

- [ ] **Step 6: Commit**

```bash
git add STATUS.md
git commit -m "docs: the picture cache is 3g; text wiring and LOD take 3f"
```

---

## Task 2: FlutterTextMeasurer splits into two caches

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart`
- Test: `packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces, and every later task depends on these exact names:
  - `const int kParagraphCacheLimit = 512;` (unchanged)
  - `const int kMetricsCacheLimit = 8192;` (new)
  - `FlutterTextMeasurer({int paragraphLimit = kParagraphCacheLimit, int metricsLimit = kMetricsCacheLimit})` — **`limit:` is gone**
  - `int layoutCount` — unchanged meaning
  - `int paragraphEvictionCount` — **replaces `evictionCount`**
  - `int metricsEvictionCount` — new
  - `int get liveParagraphCount` — unchanged meaning, now the paragraph map's length
  - `int get liveMetricsCount` — new
  - `void resetCounters()` — zeroes all three counts, touches neither map
  - `void clear()` — disposes every paragraph and empties both maps
  - `Paragraph paragraphFor(String, Handle, TextStyleRecord, int)` — unchanged signature
  - `TextMetrics measure({required String text, required TextStyleRecord style})` — unchanged signature

**Why 8192.** The spec requires `kMetricsCacheLimit` to exceed the corpus's distinct `(text, styleHandle)` count, expected to be about 4,020 — 4,000 unique `ATTRnnnnn` strings plus the twenty distinct labels Ruling 17 pins. 8192 is that with room. **Task 8 measures the real number and writes it into the constant's doc comment.** Until then the doc comment says the figure is derived, not measured.

- [ ] **Step 1: Write the failing tests**

Add to `packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart`:

```dart
  test('measure disposes its probe and leaves no paragraph entry', () {
    final m = FlutterTextMeasurer();
    m.measure(text: 'WC', style: _style);
    expect(m.layoutCount, 1);
    // The probe is built at kMetricsProbeArgb, which ACI 7 (white) is not, so
    // keeping it would hold two entries per string and halve the paragraph
    // cache's effective capacity.
    expect(m.liveParagraphCount, 0);
    expect(m.liveMetricsCount, 1);
  });

  test('a metrics sweep does not evict drawn paragraphs', () {
    // Row 10 of the exit gate, at unit scale: a full extents recomputation
    // walks every string in the document with no LOD protection. Before the
    // split it would have walked straight through the paragraph cache.
    final m = FlutterTextMeasurer(paragraphLimit: 4, metricsLimit: 1024);
    for (final t in ['A', 'B', 'C', 'D']) {
      m.paragraphFor(t, const Handle(7), _style, 0xFFFFFFFF);
    }
    expect(m.liveParagraphCount, 4);

    for (var i = 0; i < 200; i++) {
      m.measure(text: 'SWEEP$i', style: _style);
    }
    expect(m.paragraphEvictionCount, 0);
    expect(m.liveParagraphCount, 4);

    final layoutsBefore = m.layoutCount;
    for (final t in ['A', 'B', 'C', 'D']) {
      m.paragraphFor(t, const Handle(7), _style, 0xFFFFFFFF);
    }
    expect(m.layoutCount, layoutsBefore,
        reason: 'the sweep must leave the drawn set warm');
  });

  test('the metrics map evicts on its own bound, and it is not the paragraph one',
      () {
    final m = FlutterTextMeasurer(paragraphLimit: 512, metricsLimit: 2);
    m.measure(text: 'A', style: _style);
    m.measure(text: 'B', style: _style);
    m.measure(text: 'C', style: _style);
    expect(m.metricsEvictionCount, 1);
    expect(m.paragraphEvictionCount, 0);
    expect(m.liveMetricsCount, 2);
  });

  test('clear empties both maps', () {
    final m = FlutterTextMeasurer();
    m.paragraphFor('WC', const Handle(7), _style, 0xFFFFFFFF);
    m.measure(text: 'STAIR', style: _style);
    expect(m.liveParagraphCount, 1);
    expect(m.liveMetricsCount, 1);
    m.clear();
    expect(m.liveParagraphCount, 0);
    expect(m.liveMetricsCount, 0);
  });
```

And change the two existing call sites that use the old names — `flutter_text_measurer_test.dart:33` and `:37`:

```dart
    final m = FlutterTextMeasurer(paragraphLimit: 2);
```

```dart
    expect(m.paragraphEvictionCount, 1);
```

and `:91`:

```dart
    expect(measurer.paragraphEvictionCount, 0);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/flutter_text_measurer_test.dart
```

Expected: compile errors — `paragraphLimit` and `metricsLimit` are not named parameters, `paragraphEvictionCount`, `metricsEvictionCount` and `liveMetricsCount` are not defined.

- [ ] **Step 3: Rewrite the measurer**

Replace the body of `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart` from `const int kParagraphCacheLimit` to the end of the file with:

```dart
/// The paragraph cache's entry ceiling.
///
/// **Owned by Plan 3c Task 9 and moves at most once, under Ruling 4.** A
/// paragraph holds native glyph memory, so this bound is about memory, and it
/// is sized against what one *frame* draws.
const int kParagraphCacheLimit = 512;

/// The metrics cache's entry ceiling.
///
/// **A different number for a different reason, and deliberately not shared
/// with [kParagraphCacheLimit].** A [TextMetrics] is four doubles, so this
/// bound is not about memory; it exists so the map is not unbounded. It is
/// sized against what a full `DraftDocument.extents` sweep *touches*, which is
/// every text entity in the document, because level of detail deliberately does
/// not apply on the query path.
///
/// The rig corpus is expected to hold about 4,020 distinct
/// `(text, styleHandle)` pairs — 4,000 unique `ATTRnnnnn` strings and the
/// twenty distinct labels Ruling 17 pins — and this is that with room. **That
/// figure is derived from the corpus generator, not yet measured;** Plan 3f
/// Task 8 replaces this sentence with the measured count.
///
/// Raising this does not spend Ruling 4's single permitted raise. Ruling 4
/// names [kParagraphCacheLimit] and the zero-new-layouts paint row.
const int kMetricsCacheLimit = 8192;

/// The colour a metrics-only request is built with.
///
/// A `ui.Paragraph` bakes its colour at [ParagraphBuilder.pushStyle] time, so a
/// paragraph must be built to read metrics off it — but colour cannot change
/// metrics, so the one built for a metrics request is built at this declared
/// colour and disposed immediately. See [FlutterTextMeasurer.measure].
const int kMetricsProbeArgb = 0xFF000000;

/// Lays a string out once, at [kNominalTextPixels], behind two caches.
///
/// **Layout is size-independent by design.** Height, rotation, width factor and
/// oblique angle are transforms applied to the laid-out box afterwards — see
/// `text_geometry.dart` — so the only inputs that can change a layout are the
/// string, the font and the colour a paragraph is baked with. That is why this
/// class needs no scale-band invalidation axis at all.
///
/// **Two maps, because one key cannot serve both callers.** `ui.Paragraph`
/// bakes its colour, so a drawn paragraph is genuinely keyed by
/// `(text, styleHandle, argb)`. [TextMetrics] is not: colour cannot change
/// metrics. A single map keyed on the wide tuple lays every coloured string out
/// twice — once at [kMetricsProbeArgb] for [measure] and once at the entity's
/// colour for [paragraphFor] — and, worse, lets a full `extents` sweep evict
/// every paragraph the paint path had warm. Splitting them is what makes one
/// shared measurer safe.
class FlutterTextMeasurer implements TextMeasurer {
  FlutterTextMeasurer({
    this.paragraphLimit = kParagraphCacheLimit,
    this.metricsLimit = kMetricsCacheLimit,
  });

  /// Paragraph entries kept before the least-recently-touched one is evicted.
  final int paragraphLimit;

  /// Metrics entries kept before the least-recently-touched one is evicted.
  final int metricsLimit;

  /// Real `ParagraphBuilder.build()` calls since construction, whether the
  /// paragraph was kept or was a disposed metrics probe.
  int layoutCount = 0;

  /// Paragraph entries evicted since construction.
  ///
  /// Split from [metricsEvictionCount] because the two cost different things:
  /// this one released native glyph memory and guarantees a future re-layout,
  /// that one dropped four doubles. Ruling 54 is about exactly this — a blended
  /// number hides which half moved.
  int paragraphEvictionCount = 0;

  /// Metrics entries evicted since construction.
  int metricsEvictionCount = 0;

  /// The paragraph most recently evicted, already [Paragraph.dispose]d.
  ///
  /// Debug-only surface for the disposal assertion: a bound on the *entry
  /// count* says nothing about the native glyph memory an evicted `Paragraph`
  /// held unless eviction actually released it.
  Paragraph? debugLastEvicted;

  /// Live entries in the paragraph cache — native paragraphs, which is what
  /// Plan 3c's "peak live paragraphs" row means.
  int get liveParagraphCount => _paragraphs.length;

  /// Live entries in the metrics cache.
  int get liveMetricsCount => _metrics.length;

  /// Zeroes all three counters without touching either map.
  ///
  /// It deliberately leaves the entries alone. The counters are per-
  /// measurement; the caches are the thing being measured, and a reset that
  /// cleared them would guarantee the next frame lays everything out again —
  /// the opposite of the steady state every text row is about.
  void resetCounters() {
    layoutCount = 0;
    paragraphEvictionCount = 0;
    metricsEvictionCount = 0;
  }

  /// Insertion-ordered so the first key is always the least recently touched.
  final LinkedHashMap<_ParagraphKey, _ParagraphEntry> _paragraphs =
      LinkedHashMap<_ParagraphKey, _ParagraphEntry>();

  final LinkedHashMap<_MetricsKey, _MetricsEntry> _metrics =
      LinkedHashMap<_MetricsKey, _MetricsEntry>();

  /// Mutated in place and reused so a lookup never allocates a key object of
  /// its own — only a miss allocates the immutable key an inserted entry keeps.
  /// Never stored: anything read out by probing with it is copied into a return
  /// value before its fields are next overwritten.
  final _ParagraphKey _paragraphProbe = _ParagraphKey('', Handle.none, 0);
  final _MetricsKey _metricsProbe = _MetricsKey('', Handle.none);

  /// The paragraph for [text] set in [style] at [argb], laid out once and
  /// cached under `(text, styleHandle, argb)` thereafter.
  ///
  /// [styleHandle] and [style] are deliberately separate: the cache key is the
  /// handle, not the record's field values, so [style] only matters on a miss,
  /// when it supplies the `fontFamily` a fresh layout is built with.
  Paragraph paragraphFor(
      String text, Handle styleHandle, TextStyleRecord style, int argb) {
    _paragraphProbe
      ..text = text
      ..styleHandle = styleHandle
      ..argb = argb;
    final hit = _paragraphs[_paragraphProbe];
    if (hit != null) {
      _paragraphs.remove(hit.key);
      _paragraphs[hit.key] = hit;
      return hit.paragraph;
    }
    final paragraph = _layOut(text, style, argb);
    if (_paragraphs.length >= paragraphLimit) _evictOldestParagraph();
    final key = _ParagraphKey(text, styleHandle, argb);
    // Unreachable by construction: this line is only reached after an exact-key
    // miss, and `measure` never inserts here. A displaced entry would be a
    // `Paragraph` dropped without `dispose()` — a native leak — so the
    // invariant is asserted rather than handled, because handling it would be
    // dead code and a mutation of dead code is equivalent by construction.
    assert(!_paragraphs.containsKey(key));
    _paragraphs[key] = _ParagraphEntry(key, paragraph);
    return paragraph;
  }

  /// Metrics for [text] in [style], cached colour-free.
  ///
  /// **This does not consult the paragraph map, and that is a decision.** That
  /// map is keyed on `(text, styleHandle, argb)` and cannot be queried on the
  /// narrow pair without either a linear scan or a third reverse index. Neither
  /// is needed: `DraftPainter._drawText` calls this *before* it calls
  /// `DrawSink.text`, and `DrawSink.text` is the only route to [paragraphFor],
  /// so at first sight of a string the paragraph map has nothing to find. A
  /// probe could only pay after a metrics eviction, and [metricsLimit] is sized
  /// above the corpus's whole distinct-key count so that does not happen.
  ///
  /// The paragraph built here is **disposed**, not kept. ACI 7 resolves to
  /// white (`resolved_style.dart`), so [kMetricsProbeArgb]'s black is almost
  /// never the drawn colour; keeping it would hold two paragraph entries per
  /// distinct string and halve this cache's effective capacity.
  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) {
    _metricsProbe
      ..text = text
      ..styleHandle = style.handle;
    final hit = _metrics[_metricsProbe];
    if (hit != null) {
      _metrics.remove(hit.key);
      _metrics[hit.key] = hit;
      return hit.metrics;
    }
    final probe = _layOut(text, style, kMetricsProbeArgb);
    final metrics = _metricsOf(probe);
    probe.dispose();
    if (_metrics.length >= metricsLimit) _evictOldestMetrics();
    final key = _MetricsKey(text, style.handle);
    _metrics[key] = _MetricsEntry(key, metrics);
    return metrics;
  }

  Paragraph _layOut(String text, TextStyleRecord style, int argb) {
    // Layout is always at kNominalTextPixels — never the entity's effective
    // height. Height, rotation, width factor and oblique angle are all
    // transforms applied afterwards, so only the string and the style may
    // affect layout; passing an effective size here would silently destroy the
    // cache and break the claim that text needs no scale-band axis.
    final builder = ParagraphBuilder(ParagraphStyle(
      fontFamily: style.fontFamily,
      fontSize: kNominalTextPixels,
      textAlign: TextAlign.left,
    ))
      ..pushStyle(TextStyle(
          color: Color(argb),
          fontFamily: style.fontFamily,
          fontSize: kNominalTextPixels))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ParagraphConstraints(width: double.infinity));
    layoutCount++;
    return paragraph;
  }

  TextMetrics _metricsOf(Paragraph paragraph) {
    final lines = paragraph.computeLineMetrics();
    return TextMetrics(
      // `longestLine` is -FLT_MAX, not 0, for a paragraph with no lines, and
      // -FLT_MAX is finite — so this shares `ascent`'s and `descent`'s guard
      // rather than relying on an isFinite check downstream.
      // `MetricModelMeasurer` returns 0.0 here and the two must agree: the
      // differential oracle assumes the seam's two implementations are
      // interchangeable.
      advanceWidth: lines.isEmpty ? 0 : paragraph.longestLine,
      ascent: lines.isEmpty ? 0 : lines.first.ascent,
      descent: lines.isEmpty ? 0 : lines.first.descent,
      // dart:ui exposes no cap height; the declared ratio stands in for it.
      capHeight: kCapHeightRatio * kNominalTextPixels,
    );
  }

  void _evictOldestParagraph() {
    final oldestKey = _paragraphs.keys.first;
    final evicted = _paragraphs.remove(oldestKey)!;
    evicted.paragraph.dispose();
    debugLastEvicted = evicted.paragraph;
    paragraphEvictionCount++;
  }

  void _evictOldestMetrics() {
    _metrics.remove(_metrics.keys.first);
    metricsEvictionCount++;
  }

  /// Disposes every cached paragraph and empties both maps.
  ///
  /// **The application calls this, not the widget.** The document owns the
  /// measurer, two canvases over one document share it, and a canvas that
  /// cleared on dispose would wipe its sibling's cache. A `Paragraph` holds
  /// native glyph memory that outlives the Dart object referencing it until
  /// [Paragraph.dispose] runs, so whoever constructed this object has to reach
  /// every live entry when the document is retired.
  void clear() {
    for (final entry in _paragraphs.values) {
      entry.paragraph.dispose();
    }
    _paragraphs.clear();
    _metrics.clear();
  }
}

/// `(text, styleHandle, argb)`. Mutable so [FlutterTextMeasurer._paragraphProbe]
/// can reuse one instance as a lookup key across calls; every key actually
/// *stored* is a separate, never-mutated-again instance built on a miss.
class _ParagraphKey {
  _ParagraphKey(this.text, this.styleHandle, this.argb);

  String text;
  Handle styleHandle;
  int argb;

  @override
  bool operator ==(Object other) =>
      other is _ParagraphKey &&
      other.text == text &&
      other.styleHandle == styleHandle &&
      other.argb == argb;

  @override
  int get hashCode => Object.hash(text, styleHandle, argb);
}

/// `(text, styleHandle)`. Mutable for the same reason [_ParagraphKey] is.
///
/// A record key would be the obvious spelling and is the wrong one: building
/// one per lookup was measured at roughly 41 `_Record` allocations per pick and
/// broke `query_allocation_test`. See `MetricModelMeasurer`'s doc comment.
class _MetricsKey {
  _MetricsKey(this.text, this.styleHandle);

  String text;
  Handle styleHandle;

  @override
  bool operator ==(Object other) =>
      other is _MetricsKey &&
      other.text == text &&
      other.styleHandle == styleHandle;

  @override
  int get hashCode => Object.hash(text, styleHandle);
}

class _ParagraphEntry {
  _ParagraphEntry(this.key, this.paragraph);

  final _ParagraphKey key;
  final Paragraph paragraph;
}

class _MetricsEntry {
  _MetricsEntry(this.key, this.metrics);

  final _MetricsKey key;

  /// The same instance on every hit: the pick path measures per candidate and a
  /// fresh object per call breaks `query_allocation_test`.
  final TextMetrics metrics;
}
```

- [ ] **Step 4: Run the measurer tests**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/flutter_text_measurer_test.dart
```

Expected: PASS, all tests in the file.

- [ ] **Step 5: Run the whole widget suite and expect known breakage**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

Expected: `test/rig/paint_microbench_test.dart` fails to compile on `evictionCount`. It is skipped at suite level by the `rig` tag, so the suite may pass while `flutter analyze` fails. **Do not fix it here** — Task 3 owns it. Record the failure in the report.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart \
        packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart
git commit -m "feat: split the text cache into colour-free metrics and coloured paragraphs"
```

---

## Task 3: every reader of the eviction counter moves with it

**Files:**
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart:145-159`, `:218`
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart:265`, `:323`
- Modify: `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart:150-160`, `:285-305`
- Audit: `packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart:98-99`

**Interfaces:**
- Consumes: `paragraphEvictionCount`, `metricsEvictionCount`, `liveMetricsCount` from Task 2.
- Produces: `printTextCounters(DraftPainter painter, CanvasDrawSink sink, {required bool textCorpus, required bool drawText, required int layoutsBefore, required int paragraphEvictionsBefore, required int metricsEvictionsBefore})` — Task 8 adds `culledText=` to the same function.

**The `paint_microbench_test.dart` case is not mechanical.** Its fixture builds two measurers on purpose and explains why in a comment that this plan makes false. That comment is the design's own falsified premise and must be rewritten, not deleted.

- [ ] **Step 1: Update the rig printer**

In `apps/dev_harness_2d/lib/measurement_rig.dart`, replace the signature and second print of `printTextCounters`:

```dart
void printTextCounters(DraftPainter painter, CanvasDrawSink sink,
    {required bool textCorpus,
    required bool drawText,
    required int layoutsBefore,
    required int paragraphEvictionsBefore,
    required int metricsEvictionsBefore}) {
  final m = sink.measurer;
  print('  text: corpus=${textCorpus ? "on" : "off"} '
      'draw=${drawText ? "on" : "off"} '
      'textOps=${painter.textOpCount} '
      'skippedText=${painter.skippedTextCount}');
  // Two eviction numbers, not one. A paragraph eviction released native glyph
  // memory and guarantees a future re-layout; a metrics eviction dropped four
  // doubles. Ruling 54: a blended number hides which half moved.
  print('  paragraphs: newLayouts=${m.layoutCount - layoutsBefore} '
      'newParagraphEvictions=${m.paragraphEvictionCount - paragraphEvictionsBefore} '
      'newMetricsEvictions=${m.metricsEvictionCount - metricsEvictionsBefore} '
      'liveParagraphs=${m.liveParagraphCount} '
      'liveMetrics=${m.liveMetricsCount}');
}
```

- [ ] **Step 2: Update every caller of it in the same file**

At `measurement_rig.dart:217-218` and at every other `evictionsBefore` capture in the file, replace the single capture with two and pass both through:

```dart
    final layoutsBefore = sink.measurer.layoutCount;
    final paragraphEvictionsBefore = sink.measurer.paragraphEvictionCount;
    final metricsEvictionsBefore = sink.measurer.metricsEvictionCount;
```

```dart
    printTextCounters(painter, sink,
        textCorpus: textCorpus,
        drawText: drawText,
        layoutsBefore: layoutsBefore,
        paragraphEvictionsBefore: paragraphEvictionsBefore,
        metricsEvictionsBefore: metricsEvictionsBefore);
```

Run `grep -n "evictionCount\|evictionsBefore" apps/dev_harness_2d/lib/measurement_rig.dart` and confirm every hit is one of the new names.

- [ ] **Step 3: Update the integration test**

In `apps/dev_harness_2d/integration_test/frame_timing_test.dart`, at both `:265` and `:323`, replace

```dart
    final evictionsBefore = app.sink.measurer.evictionCount;
```

with

```dart
    final paragraphEvictionsBefore = app.sink.measurer.paragraphEvictionCount;
    final metricsEvictionsBefore = app.sink.measurer.metricsEvictionCount;
```

and pass both to `printTextCounters`.

- [ ] **Step 4: Collapse the microbench to one measurer and rewrite its comment**

In `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart`, replace the two-measurer block and its comment with:

```dart
      // One measurer, because production has one. The document owns it and
      // `DraftCanvas` borrows it for the sink, so the painter's metrics
      // requests and the sink's drawn paragraphs land in the same object —
      // metrics in its colour-free map, paragraphs in its coloured one. Before
      // Plan 3f these were two `FlutterTextMeasurer`s with two caches, and this
      // rig built two to match; that wiring is gone.
      final measurer = FlutterTextMeasurer();
```

Replace every `sinkMeasurer` and `docMeasurer` in the file with `measurer`, and replace the counter prints at `:298-305` with:

```dart
          print('      newLayouts=${measurer.layoutCount - layoutsBefore} '
              'newParagraphEvictions='
              '${measurer.paragraphEvictionCount - paragraphEvictionsBefore}');
          print('      cache: layouts=${measurer.layoutCount} '
              'paragraphEvictions=${measurer.paragraphEvictionCount} '
              'metricsEvictions=${measurer.metricsEvictionCount} '
              'liveParagraphs=${measurer.liveParagraphCount} '
              'liveMetrics=${measurer.liveMetricsCount}');
```

with the captures above the measured region updated to match.

- [ ] **Step 5: Audit the sink test**

Run:

```bash
grep -n "layoutCount\|liveParagraphCount\|evictionCount" packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart
```

Expected: `:98` reads `layoutCount` and `:99` reads `liveParagraphCount`. Both keep their names and meanings, so **no change**. Say so in the report rather than leaving it unmentioned.

- [ ] **Step 6: Verify everything compiles, including the tagged rig**

Run:

```bash
cd packages/jet_cad_2d_flutter && flutter analyze && CI=true flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart --plain-name "text paint at 50000"
cd ../../apps/dev_harness_2d && flutter analyze
```

Expected: analyze clean in both, and the microbench prints one cache's numbers.

- [ ] **Step 7: Commit**

```bash
git add apps/dev_harness_2d/lib/measurement_rig.dart \
        apps/dev_harness_2d/integration_test/frame_timing_test.dart \
        packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart
git commit -m "refactor: report paragraph and metrics evictions apart"
```

---

## Task 4: the document owns the measurer

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:120-123`, `:135-140`, `:175-184`
- Modify: `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart:112`, `:180`, `:282`
- Modify: `packages/jet_cad_2d_flutter/test/render_backend_test.dart:9`, `:69`
- Modify: `packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart:39`
- Modify: `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart:22`
- Modify: `packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart:46`
- Modify: `apps/dev_harness_2d/lib/main.dart:140-160`, `:406-425`

**Interfaces:**
- Consumes: `FlutterTextMeasurer` from Task 2.
- Produces: `DraftCanvas` now throws `ArgumentError` at `_attach()` when `document.textMeasurer is! FlutterTextMeasurer`. `apps/dev_harness_2d/lib/main.dart` gains a library-level `final FlutterTextMeasurer harnessMeasurer`.

**The refusal is unconditional — it does not consult `drawText`.** `drawText: false` is a measurement flag, not a licence to carry a measurer that computes the wrong extents. A conditional guard would also force `CanvasDrawSink` to hold a throwaway measurer for its typed field, which is the second cache coming back.

- [ ] **Step 1: Write the failing tests**

Add to `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`:

```dart
  testWidgets('refuses a document whose measurer cannot lay out paragraphs',
      (tester) async {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(ViewportTransform.fit(
        Aabb2(Vector2.zero(), Vector2(100, 100)), const Size(400, 300)));
    addTearDown(camera.dispose);

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DraftCanvas(document: doc, index: index, camera: camera),
    ));

    // The whole point is that this used to draw nothing and say nothing.
    final error = tester.takeException();
    expect(error, isA<ArgumentError>());
    expect(error.toString(), contains('FlutterTextMeasurer'));
    expect(error.toString(), contains('DraftDocument.empty(measurer:'));
  });

  testWidgets('disposing one canvas leaves a sibling cache warm',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(ViewportTransform.fit(
        Aabb2(Vector2.zero(), Vector2(100, 100)), const Size(400, 300)));
    addTearDown(camera.dispose);

    Widget canvases(int count) => Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                    width: 200,
                    height: 150,
                    child: DraftCanvas(
                        document: doc, index: index, camera: camera)),
            ],
          ),
        );

    await tester.pumpWidget(canvases(2));
    measurer.paragraphFor('WC', const Handle(7), _roboto, 0xFFFFFFFF);
    final live = measurer.liveParagraphCount;
    expect(live, 1);

    await tester.pumpWidget(canvases(1));
    await tester.pump();

    // A canvas that cleared on dispose would take its sibling's cache with it.
    expect(measurer.liveParagraphCount, live);
  });
```

with, near the top of the file:

```dart
const TextStyleRecord _roboto =
    TextStyleRecord(handle: Handle(7), name: 'Standard', fontFamily: 'Roboto');
```

- [ ] **Step 2: Run them to verify they fail**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/draft_canvas_test.dart
```

Expected: the refusal test fails because `takeException()` returns `null` — nothing throws today. The split-view test fails because `dispose()` calls `clear()` and `liveParagraphCount` reads 0.

- [ ] **Step 3: Make the widget borrow, refuse, and stop disposing**

In `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`, delete the `_measurer` field at `:120-123` and replace it with nothing. In `_attach()`, immediately before the `sink = CanvasDrawSink(...)` line, insert:

```dart
    // The document owns the measurer; this widget borrows it. Refused
    // unconditionally rather than only when `drawText` is on: a document whose
    // boxes were computed from `TextMetrics.zero` is wrong whether or not
    // glyphs are drawn, and a conditional guard would force `CanvasDrawSink` to
    // hold a throwaway measurer for its typed field — the second cache coming
    // back. Before Plan 3f this widget built its own, handed it to the sink
    // only, and left the painter reading `document.textMeasurer`; a document
    // assembled the ordinary way therefore drew no text and reported nothing.
    final measurer = widget.document.textMeasurer;
    if (measurer is! FlutterTextMeasurer) {
      throw ArgumentError.value(
          measurer,
          'document.textMeasurer',
          'DraftCanvas requires a FlutterTextMeasurer. Build the measurer '
              'first and pass it to the document:\n\n'
              '    final measurer = FlutterTextMeasurer();\n'
              '    final doc = DraftDocument.empty(measurer: measurer);\n');
    }
```

and change the sink construction's `measurer:` argument to `measurer`.

In `dispose()`, replace the `_measurer.clear();` call and its comment with:

```dart
    // The measurer is **not** disposed here. The document owns it, two canvases
    // over one document share it, and clearing on dispose would wipe the
    // sibling's cache along with every native `Paragraph` in it. The
    // application that constructed the measurer calls `clear()` when it retires
    // the document — the ordinary Dart contract for a native-resource holder.
```

- [ ] **Step 4: Fix the nine documents**

Give each of these a real measurer with teardown:

`test/draft_canvas_test.dart:112` and `:180` —

```dart
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
```

`test/draft_canvas_test.dart:282` — swap the model measurer and disable LOD, because that test asserts `textOpCount == 1` and Task 5 makes the default cull:

```dart
    final textMeasurer = FlutterTextMeasurer();
    addTearDown(textMeasurer.clear);
    final textDoc = DraftDocument.empty(measurer: textMeasurer);
```

`test/render_backend_test.dart:9` and `:69` —

```dart
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = generateDocument(40, dashedFraction: 0.5, measurer: measurer);
```

`test/frame_path_seam_test.dart:39`, `test/golden/dash_ladder_golden_test.dart:22` and `test/golden/fill_ladder_golden_test.dart:46` — the same `DraftDocument.empty(measurer: FlutterTextMeasurer())` shape, with `addTearDown` where the surrounding code is inside a test body and a top-level construction otherwise.

- [ ] **Step 5: Fix the harness, including its disposal**

In `apps/dev_harness_2d/lib/main.dart`, add a library-level field beside the other configuration constants:

```dart
/// The one measurer the harness document is built with, reachable from
/// `_HarnessState.dispose` so the native paragraphs it holds are released.
///
/// A field rather than an inline argument because `DraftCanvas` no longer
/// disposes the cache: the document owns it and the application releases it.
final FlutterTextMeasurer harnessMeasurer = FlutterTextMeasurer();
```

Replace the ternary at `:154-156` with:

```dart
    // Always a real measurer. The old `kTextCorpus ? FlutterTextMeasurer() :
    // const InsertionPointMeasurer()` was a workaround for this file's own
    // doc comment above — a zero-metric measurer makes every text transform
    // singular — applied at one call site while the cause stayed. `DraftCanvas`
    // now refuses a document without one, and what turns text off is
    // `labelFraction: 0` and `attributedInstanceFraction: 0`, which is the
    // correct axis.
    measurer: harnessMeasurer,
```

In `_HarnessState.dispose()`:

```dart
  @override
  void dispose() {
    index.dispose();
    camera.dispose();
    // `DraftCanvas` stops disposing the cache under Plan 3f, because two
    // canvases over one document share it. The application owns it instead.
    harnessMeasurer.clear();
    super.dispose();
  }
```

- [ ] **Step 6: Run everything**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter test --tags golden && flutter analyze
cd ../../apps/dev_harness_2d && flutter analyze
```

Expected: all pass, **no golden PNG regenerated** — check with `git status`, which must show no `.png` under `test/golden`.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart \
        packages/jet_cad_2d_flutter/test apps/dev_harness_2d/lib/main.dart
git commit -m "feat: the document owns the text measurer and DraftCanvas borrows it"
```

---

## Task 5: level of detail in the painter, and the knob on the widget

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart:36-43`, `:145-160`, `:252-258`, `:793-822`
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:56-66`, `:145-152`, `:161-172`
- Test: `packages/jet_cad_2d_flutter/test/text_lod_test.dart` (create)

**Interfaces:**
- Consumes: nothing from Tasks 2-4 beyond a compiling tree.
- Produces:
  - `const double kMinTextCapPixels = 3.0;` in `draft_painter.dart`
  - `DraftPainter({..., double minTextCapPixels = kMinTextCapPixels})`
  - `int get culledTextCount` on `DraftPainter`
  - `DraftCanvas({..., double minTextCapPixels = kMinTextCapPixels})`

**The ordering is the whole point.** `_drawText` today calls `measure()` at `:807` and `TextLayout.resolve` at `:812`. The LOD test needs `resolve`'s output and must run before `measure`, so the method is reordered. A test placed after `measure` culls the draw and saves no layout.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/text_lod_test.dart`:

```dart
// `dart:typed_data` for Float64List, and `hide Aabb2` because vector_math ships
// its own Aabb2 and `jet_cad_2d` exports the one this codebase means. Every
// text-bearing test in this directory has exactly these two lines — see
// `text_paint_test.dart` and `draft_canvas_test.dart`.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/fixtures.dart';

const TextStyleRecord _style =
    TextStyleRecord(handle: Handle(7), name: 'Standard', fontFamily: 'Roboto');

/// One text entity of [height] world units at the world origin, and nothing
/// else, so the camera fit is decided by [world] rather than by the glyph box.
DraftDocument _doc(double height, Aabb2 world, FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: 'STAIR',
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(),
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([world.min.x, world.min.y]),
      scalars: Float64List.fromList([height, 0, 1, 0]),
    ),
  ));
  return doc;
}

void main() {
  test('text below the threshold is culled and never measured', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    // 1000 world units across a 400 px viewport is 0.4 px per unit, so a
    // height-2 glyph is 0.8 px of cap height — under the 3.0 default.
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    expect(painter.culledTextCount, 1);
    expect(painter.textOpCount, 0);
    // The load-bearing half: culling after `measure` would leave this at 1 and
    // save nothing. It is why the LOD test sits before the measure call.
    expect(m.layoutCount, 0);
  });

  test('the same text at the same camera draws once LOD is off', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0.0);
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    // The control arm. Without it the first test passes on a corpus with no
    // text at all.
    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('readable text at the same threshold is not culled', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    // 40 world units at 0.4 px per unit is 16 px of cap height.
    final doc = _doc(40.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('the threshold is exclusive at exactly kMinTextCapPixels', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    // 0.4 px per unit, so height 7.5 is exactly 3.0 px of cap height.
    final doc = _doc(7.5, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    // `<`, not `<=`: a glyph exactly at the threshold is drawn.
    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('culledTextCount is a per-frame figure, not a running total', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final view = ViewportTransform.fit(world, const Size(400, 300));

    painter.paint(RecordingDrawSink(), view, const Size(400, 300));
    painter.paint(RecordingDrawSink(), view, const Size(400, 300));

    expect(painter.culledTextCount, 1);
  });

  test('the threshold does not reach doc.extents', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final wide = doc.extents;
    doc.invalidateDerived();
    final again = doc.extents;
    // A document box that changed with zoom would be absurd; the painter's
    // threshold is a draw decision and lives nowhere near entityBounds.
    expect(again.min.x, wide.min.x);
    expect(again.min.y, wide.min.y);
    expect(again.max.x, wide.max.x);
    expect(again.max.y, wide.max.y);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/text_lod_test.dart
```

Expected: compile error — `culledTextCount` and `minTextCapPixels` are not defined.

- [ ] **Step 3: Add the constant, the parameter and the counter**

In `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`, beside `kAnisotropyThreshold`:

```dart
/// Text whose on-screen cap height is below this many **logical** pixels is not
/// drawn, and not laid out either.
///
/// Below three pixels of cap height a glyph cannot resolve two strokes, so
/// nothing readable is lost. Logical rather than device pixels is deliberate:
/// on a 2x display the same text is six device pixels tall, so this culls
/// *less* than a device-pixel rule would — the safe direction, the same one
/// [kScreenClipInflate] takes.
///
/// **Two alternatives were considered and are not taken.** *Greeking* — drawing
/// a bar the width of the text instead of the glyphs, so a zoomed-out plan
/// keeps its visual weight — is cheap to draw (two batched triangles in
/// `VerticesDrawSink`) but needs `advanceWidth`, so either the layout happens
/// anyway and the saving is lost, or a font-free width model
/// (`text.length * ratio`, the shape `MetricModelMeasurer` uses) becomes a new
/// approximation to defend. *Two tiers* — greek in a middle band, nothing
/// beyond it — is closest to real CAD and the most control, at two constants,
/// two counters, two golden ladders, and the same font-free width model.
/// Neither is ruled out later; both were priced and deferred.
const double kMinTextCapPixels = 3.0;
```

Add the constructor parameter and field:

```dart
  DraftPainter({
    required this.document,
    required this.index,
    required this.resolver,
    this.debugDisableRebasing = false,
    this.drawText = true,
    this.minTextCapPixels = kMinTextCapPixels,
  });
```

```dart
  /// Cap height in logical pixels below which a text leaf is culled.
  ///
  /// **`0.0` disables level of detail**, which is what the exit gate's control
  /// arm needs: LOD-on and LOD-off must be compared on the same corpus at the
  /// same camera, or the two rows are two different documents.
  ///
  /// `final` for the reason [drawText] is: the painter is built once and a rig
  /// that flipped this after the fact would be measuring a rebuilt painter,
  /// which is a different frame.
  final double minTextCapPixels;
```

Add the counter beside `_skippedText`:

```dart
  int _culledText = 0;

  /// Text and attrib entities culled in the last frame for being too small to
  /// read — see [kMinTextCapPixels].
  ///
  /// **Separate from [skippedTextCount] on purpose.** That one means *empty
  /// string*; this one means *below the threshold*. Blended, the exit gate
  /// cannot tell which mechanism fired, which is the mistake Ruling 54 records
  /// for the paragraph cache's hit rate.
  int get culledTextCount => _culledText;
```

and reset it in `paint()` beside `_skippedText = 0;`:

```dart
    _culledText = 0;
```

- [ ] **Step 4: Reorder `_drawText` and insert the cull**

Replace the body of `_drawText` between the empty-string guard and the `sink` call with:

```dart
    final styleHandle = document.entities.textStyleAt(slot);
    final record = document.textStyleOf(styleHandle);
    // Resolved before the metrics are asked for, and that ordering is the whole
    // mechanism. `resolve` needs no metrics — height, rotation, width factor,
    // oblique angle and justification all come from the payload, the attribute
    // bits and the style record — while `measure` is the expensive call. A cull
    // placed after `measure` would skip the draw and save no layout at all.
    final layout = _textLayout
      ..resolve(payload, document.entities.textAttrsAt(slot), record);
    // `layout.height` is the effective DXF text height, which *is* the cap
    // height, in world units; `chain` carries camera, ancestors, instance,
    // placement and rebase. The product is the on-screen cap height in pixels,
    // with no measurement involved.
    //
    // `scaleMagnitude` is the geometric mean of the axis scales, so text
    // squashed in y under an anisotropic placement reads taller than it renders
    // and survives longer than it should. Same approximation the painter
    // already makes for curve stroke widths past [kAnisotropyThreshold], and it
    // errs toward drawing.
    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
      _culledText++;
      return;
    }
    final metrics = document.textMeasurer.measure(text: text, style: record);
    // The anchor is rebased like every other coordinate that reaches `chain`,
    // which already carries `translate(localOrigin)`. An unrebased anchor is
    // exactly right at the origin and one rebase origin wrong everywhere else —
    // the failure a fixture at (0, 0) cannot see.
    layout.composeTransform(metrics, payload.coords[0] - localOrigin.x,
        payload.coords[1] - localOrigin.y);
```

- [ ] **Step 5: Run the LOD tests**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/text_lod_test.dart
```

Expected: PASS, six tests.

- [ ] **Step 6: Add the widget knob and its prop-update test**

In `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`, add to the constructor and the fields:

```dart
    this.minTextCapPixels = kMinTextCapPixels,
```

```dart
  /// Forwarded to [DraftPainter.minTextCapPixels]. `0.0` disables level of
  /// detail, which is what the exit gate's control arm needs.
  final double minTextCapPixels;
```

Forward it in `_attach()`'s `DraftPainter(...)` construction, and **add it to `didUpdateWidget`'s comparison list**:

```dart
        widget.minTextCapPixels != oldWidget.minTextCapPixels ||
```

Without that line a rebuild that changes the threshold keeps the old painter, so the LOD-off control arm silently measures the LOD-on build and looks like it worked.

Add to `draft_canvas_test.dart`:

```dart
  testWidgets('changing minTextCapPixels rebuilds the painter', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(ViewportTransform.fit(
        Aabb2(Vector2.zero(), Vector2(100, 100)), const Size(400, 300)));
    addTearDown(camera.dispose);
    final key = GlobalKey<DraftCanvasState>();

    Widget at(double threshold) => Directionality(
        textDirection: TextDirection.ltr,
        child: DraftCanvas(
            key: key,
            document: doc,
            index: index,
            camera: camera,
            minTextCapPixels: threshold));

    await tester.pumpWidget(at(kMinTextCapPixels));
    expect(key.currentState!.painter.minTextCapPixels, kMinTextCapPixels);

    await tester.pumpWidget(at(0.0));
    // The painter's field is final, so a stale painter here means the control
    // arm measures the wrong build and reads as a working gate.
    expect(key.currentState!.painter.minTextCapPixels, 0.0);
  });
```

- [ ] **Step 7: Run the widget suite**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze
```

Expected: PASS. If any existing test now reads a lower `textOpCount`, that is Task 6's margin sweep finding work early — record it and leave it.

- [ ] **Step 8: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart \
        packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart \
        packages/jet_cad_2d_flutter/test/text_lod_test.dart \
        packages/jet_cad_2d_flutter/test/draft_canvas_test.dart
git commit -m "feat: cull text too small to read, before it is measured"
```

---

## Task 6: the oracle derives its own cull, and every painter site gets a margin

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart:29-42`, `:154-175`
- Modify: `packages/jet_cad_2d_flutter/test/support/fixtures.dart:154`, `:167`
- Modify: `packages/jet_cad_2d_flutter/test/differential_test.dart:63`
- Audit and, where needed, modify: every file constructing a `DraftPainter`

**Interfaces:**
- Consumes: `kMinTextCapPixels`, `DraftPainter.minTextCapPixels` from Task 5.
- Produces: `referenceWalk(DraftDocument, DrawSink, ViewportTransform, Size, StyleResolver, {double minTextCapPixels = kMinTextCapPixels})`; `paintToRecording(DraftDocument, [ViewportTransform?], {double minTextCapPixels})`; `referenceToRecording(DraftDocument, [ViewportTransform?], {double minTextCapPixels})`.

**The walk computes the cull itself.** It must not ask the painter what it decided — sharing the decision would have the oracle share the assumption it exists to test. This is the correction Plan 3e made at `24cfd23` for fill triangulation, applied here before it can go wrong.

**LOD arrives by default value, so it has no compiler-visible call site.** Seventeen files construct a `DraftPainter` and every one of them silently gains culling. This task sweeps all of them.

- [ ] **Step 1: Write the failing differential test**

Add to `packages/jet_cad_2d_flutter/test/text_lod_test.dart`:

```dart
  test('painter and oracle cull the same text under a non-identity placement',
      () {
    // Deliberately not at the identity and not at the origin: the painter and
    // the walk reach `chain` by different routes, and a fixture at the identity
    // transform cannot tell a shared decision from two agreeing ones.
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final doc = textLodDifferentialDocument(m);
    final world = doc.extents;
    final view = ViewportTransform.fit(world, kViewport);

    final painted = paintToRecording(doc, view);
    final walked = referenceToRecording(doc, view);

    expect(painted.length, walked.length);
    for (var i = 0; i < painted.length; i++) {
      expect(painted[i], walked[i], reason: 'op $i');
    }
    // Non-vacuity: if nothing were culled this would pass with LOD deleted.
    final all = paintToRecording(doc, view, minTextCapPixels: 0.0);
    expect(all.length, greaterThan(painted.length));
  });
```

with a fixture in `test/support/fixtures.dart` that places text at three heights inside a scaled, rotated, off-origin instance so the two routes to `chain` differ:

```dart
/// Adds one text entity, which [addEntity] cannot: text carries `text`,
/// `textStyle` and `textAttrs` on the record rather than in the payload.
Handle addText(
  DraftDocument doc,
  Handle owner,
  Handle handle,
  String text,
  double x,
  double y,
  double height,
) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: text,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(),
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y]),
      // height, rotation, widthFactor, obliqueAngle.
      scalars: Float64List.fromList([height, 0, 1, 0]),
    ),
  ));
  return handle;
}

/// A drawing whose text straddles [kMinTextCapPixels] at the fitted camera,
/// placed under a scaled and rotated instance well away from the origin.
///
/// Every property here is load-bearing. At the identity transform the painter's
/// `chain` and the walk's `chain` are the same matrix by accident rather than
/// by agreement, so a walk that read the painter's decision would pass. Away
/// from the origin the rebase term differs between the two. And three heights
/// straddling the threshold are what make the comparison about culling rather
/// than about drawing.
///
/// The arithmetic the heights come from: the root line spans 16,000 x 12,000
/// world units into [kViewport]'s 800 x 600, so the fit is about 0.05 px per
/// world unit; the instance scales by 0.35; so on-screen cap height is roughly
/// `height * 0.0175`, and 3.0 px falls at a height of about 171.
DraftDocument textLodDifferentialDocument(TextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);

  // The drawing's real extent, so the camera fit is decided by this and not by
  // whichever glyph box happens to be widest.
  addEntity(doc, doc.rootHandle, const Handle(890), EntityKind.line,
      [0, 0, 16000, 12000], const []);

  const labels = Handle(900);
  // Not `const`: `Vector2.zero()` is not a const constructor, which is why
  // `differentialFixture` spells it this way too.
  doc.tree.addDefinition(Definition(
      handle: labels,
      name: 'labels',
      basePoint: Vector2.zero(),
      children: const []));

  // Definition-local coordinates, so nothing here is at the world origin once
  // the instance places it.
  addText(doc, labels, const Handle(901), 'TINY', 0, 0, 40);
  addText(doc, labels, const Handle(902), 'EDGE', 0, 900, 172);
  addText(doc, labels, const Handle(903), 'LARGE', 0, 2400, 800);

  // Rotated, uniformly scaled, and far from the origin. Uniform scale keeps
  // `scaleMagnitude` exactly 0.35 so the arithmetic above is checkable; the
  // rotation and the translation are what make the painter's and the walk's
  // routes to `chain` genuinely different rather than accidentally equal.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(910),
    parent: doc.rootHandle,
    transform: Transform2.translation(12000, 9000)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(0.35, 0.35)),
    definition: labels,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(3),
  )));

  return doc;
}
```

**The three heights are a starting point derived from the arithmetic above, not a measurement.** `ViewportTransform.fit` may add margin, which moves the fit scale. Before Step 2, print the actual on-screen cap height for all three — `layout.height * chain.scaleMagnitude`, or equivalently `height * 0.35 * fitScale` — and **state all three numbers in the task report**. `TINY` must land clearly below 3.0, `LARGE` clearly above, and `EDGE` within about 10% of 3.0. If the fit does not produce that, **the heights move, not the threshold**: a fixture tuned by changing `kMinTextCapPixels` is a fixture that tests nothing.

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/text_lod_test.dart --plain-name "painter and oracle"
```

Expected: FAIL — `painted.length` is less than `walked.length`, because the painter culls and the walk does not.

- [ ] **Step 3: Thread the threshold and derive the cull in the walk**

In `reference_walk.dart`, change the signature:

```dart
void referenceWalk(
  DraftDocument doc,
  DrawSink sink,
  ViewportTransform camera,
  Size viewport,
  StyleResolver resolver, {
  double minTextCapPixels = kMinTextCapPixels,
}) {
```

carry it into `_ReferenceWalk`, and inside the text branch, immediately after the empty-string guard:

```dart
      final attrs = resolveTextAttributes(
          payload, doc.entities.textAttrsAt(slot), record);
      // The same rule the painter applies, computed here rather than asked for.
      // An oracle that read the painter's decision would share the assumption
      // it exists to test — the correction Plan 3e made at 24cfd23 for fill
      // triangulation. The walk reaches `chain` by its own route, so this is a
      // genuinely independent number.
      if (attrs.height * chain.scaleMagnitude < minTextCapPixels) return;
      final metrics = doc.textMeasurer.measure(text: text, style: record);
```

moving the existing `resolveTextAttributes` call above the metrics call.

- [ ] **Step 4: Thread it through both recording helpers**

In `test/support/fixtures.dart`:

```dart
List<DrawOp> paintToRecording(DraftDocument doc,
    [ViewportTransform? camera,
    double minTextCapPixels = kMinTextCapPixels]) {
  final index = SpatialIndex(doc);
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  DraftPainter(
          document: doc,
          index: index,
          resolver: DocumentStyleResolver(doc),
          minTextCapPixels: minTextCapPixels)
      .paint(sink, view, kViewport);
  index.dispose();
  return sink.ops;
}

List<DrawOp> referenceToRecording(DraftDocument doc,
    [ViewportTransform? camera,
    double minTextCapPixels = kMinTextCapPixels]) {
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  referenceWalk(doc, sink, view, kViewport, DocumentStyleResolver(doc),
      minTextCapPixels: minTextCapPixels);
  return sink.ops;
}
```

**Both sides, not just the oracle.** Matched on/off control arms need both steerable, and the fixture above has to drive painter and oracle to the same number on purpose.

- [ ] **Step 5: Sweep every `DraftPainter` construction site**

Run:

```bash
grep -rn "DraftPainter(" packages/jet_cad_2d_flutter/test packages/jet_cad_2d_flutter/lib apps/dev_harness_2d
```

Expected: seventeen files. For each, determine whether it draws text:

```bash
for f in $(grep -rl "DraftPainter(" packages/jet_cad_2d_flutter/test); do \
  n=$(grep -c "EntityKind.text\|EntityKind.attrib\|labelFraction\|attributedInstanceFraction" $f); \
  [ "$n" -gt 0 ] && echo "$n  $f"; done | sort -rn
```

Expected, before this task's own additions: `test/text_paint_test.dart`, `test/rig/paint_microbench_test.dart`, `test/support/sink_comparison.dart`, `test/draft_painter_root_test.dart`, `test/draft_canvas_test.dart`.

**For each text-bearing site, record in the report the smallest text cap height in pixels at the camera it uses, against the 3.0 threshold** — the way `text_ladder`'s 7.3x margin is recorded in the spec. A site whose margin is thin gets `minTextCapPixels: 0` **explicitly**, so a later threshold change cannot silently empty it. A site whose margin is wide is left on the default and its number is written down.

- [ ] **Step 6: Run everything**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter test --tags golden && flutter analyze
```

Expected: PASS, no golden PNG regenerated.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/reference_walk.dart \
        packages/jet_cad_2d_flutter/test
git commit -m "test: the reference walk derives its own cull, and every painter site has a margin"
```

---

## Task 7: the LOD golden ladder

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_{1,2,3}.png` and `vertices/text_lod_ladder_{1,2,3}.png`

**Interfaces:**
- Consumes: `kMinTextCapPixels`, `DraftCanvas.minTextCapPixels`.
- Produces: six PNGs.

**Ahem is sufficient here and the reason is stronger than "presence and absence".** `capHeight` is `kCapHeightRatio * kNominalTextPixels`, a constant, and the LOD test reads no metrics at all — so the cull decision is font-independent. This ladder is font-proof and needs no `FontLoader`. Say so in the file's header comment; a future reader will otherwise assume it was an oversight.

- [ ] **Step 1: Write the ladder**

Create the file following `dash_ladder_golden_test.dart`'s structure exactly — the same `kGoldenViewport`, the same `_framed` helper shape, the same two-backend loop, the same `matchesGoldenFile('vertices/...')` spelling for the second backend.

```dart
// Three rungs, one axis: the level-of-detail threshold. One drawing carrying
// three text heights, framed so the smallest is culled, the largest is not, and
// the middle sits near the boundary — so the ladder pins `kMinTextCapPixels`
// visually and goes red if the constant moves.
//
// **Ahem is enough, and that is not an oversight.** The other text ladder needs
// `fonts/Roboto-Regular.ttf` because it asserts things about glyph *shape*. The
// cull decision reads no metrics at all — `layout.height * chain.scaleMagnitude`
// against a constant — so nothing here depends on which font is loaded.

const Size kGoldenViewport = Size(400, 300);
```

Rung 1 renders at the default threshold. Rung 2 renders the same document at `minTextCapPixels: 0.0` — the control arm, showing every string. Rung 3 renders it at a threshold above every string's cap height, showing none.

- [ ] **Step 2: Generate the PNGs**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden --update-goldens test/golden/text_lod_ladder_golden_test.dart
```

- [ ] **Step 3: Look at all six**

Open each PNG and confirm by eye: rung 1 shows the large and middle strings and not the small one; rung 2 shows all three; rung 3 shows none. **A golden accepted without being looked at pins whatever the code did, including a bug.**

- [ ] **Step 4: Verify no other PNG moved**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden && git status --porcelain packages/jet_cad_2d_flutter/test/golden
```

Expected: 29 + 6 = 35 golden tests pass, and `git status` lists exactly the six new PNGs as untracked — **no existing PNG modified.**

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d_flutter/test/golden
git commit -m "test: a golden ladder for the text level-of-detail threshold"
```

---

## Task 8: the harness measures LOD, and the threshold ladder

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart` — the `LOD` define, forwarded to `DraftCanvas`
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart:145-159` — `culledText=`
- Modify: `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart` — the measured distinct-key count into `kMetricsCacheLimit`'s doc comment

**Interfaces:**
- Consumes: `DraftCanvas.minTextCapPixels`, `DraftPainter.culledTextCount`, `FlutterTextMeasurer.liveMetricsCount`.
- Produces: the threshold ladder table, for the results note.

- [ ] **Step 1: Add the define**

In `apps/dev_harness_2d/lib/main.dart`, beside `kFillsEnabled`:

```dart
/// Whether the painter culls text too small to read.
///
/// **A `String.fromEnvironment`, and it stays one.** `bool.fromEnvironment`
/// reads `--dart-define=LOD=1` as **false**, and Plan 3c lost a full device run
/// to exactly that with `TEXT=1`. An unrecognised value throws at startup rather
/// than falling back to something that looks fine.
final double kMinTextCap =
    switch (const String.fromEnvironment('LOD', defaultValue: 'true')) {
  'true' => kMinTextCapPixels,
  'false' => 0.0,
  final other => throw ArgumentError.value(
      other, 'LOD', 'expected "true" or "false"'),
};
```

and forward it at the `DraftCanvas(...)` construction:

```dart
                drawText: kDrawText,
                minTextCapPixels: kMinTextCap,
                backend: kBackend),
```

- [ ] **Step 2: Print the counter**

In `printTextCounters`, add `culledText` to the first line:

```dart
  print('  text: corpus=${textCorpus ? "on" : "off"} '
      'draw=${drawText ? "on" : "off"} '
      'textOps=${painter.textOpCount} '
      'skippedText=${painter.skippedTextCount} '
      'culledText=${painter.culledTextCount}');
```

**The guard stays where it is.** Any rig guard belongs before the first print or nowhere — R4a and R4b printed three lines and threw, for months, and the numbers looked complete because the missing lines were the ones nobody expects to read.

- [ ] **Step 3: Check Low Power Mode before measuring anything**

Run:

```bash
pmset -g | grep lowpowermode
```

Record the value in the report. **Every timing taken in this task carries that mark.** No failable criterion is a timing, but the results note must state it.

- [ ] **Step 4: Measure the threshold ladder**

Run the widget-level rig at thresholds `0.0`, `1.0`, `2.0`, `3.0`, `4.0`, `6.0`, `10.0`, at both the working-set and whole-drawing cameras, on the 50,000-entity corpus:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test --tags rig --run-skipped \
  test/rig/paint_microbench_test.dart --plain-name "text paint at 50000"
```

extended by the implementer to loop the threshold. Record, per threshold and per camera: **layouts, paragraph evictions, metrics evictions, `culledTextCount`, and the distinct surviving key count in each map** (`liveParagraphCount`, `liveMetricsCount`).

The last column is the number that says whether 3.0 is feasible or whether Ruling 4's single raise finally gets spent.

**Expect a step, not a curve.** `generate_document.dart:676` gives every attribute a fixed height of `80.0` and attributes are 4,000 of the roughly 4,020 distinct pairs, so one threshold makes 4,000 keys vanish at once. Write the ladder up as a step-locator and say where the step is.

- [ ] **Step 5: Write the measured count into the constant**

Replace the "derived from the corpus generator, not yet measured" sentence in `kMetricsCacheLimit`'s doc comment with the measured distinct `(text, styleHandle)` count from Step 4, and the camera it was measured at.

- [ ] **Step 6: Run the device rig both ways**

```bash
cd apps/dev_harness_2d
flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=TEXT=true --dart-define=DRAW_TEXT=true --dart-define=LOD=true
flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=TEXT=true --dart-define=DRAW_TEXT=true --dart-define=LOD=false
```

**`flutter drive` rewrites `macos/Runner.xcodeproj/project.pbxproj`.** Revert it, do not commit it:

```bash
git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
```

That is the one sanctioned `git checkout` of a file in this repo, and it applies to this file only.

- [ ] **Step 7: Commit**

```bash
git add apps/dev_harness_2d/lib packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart
git commit -m "feat: the harness measures with and without level of detail"
```

---

## Task 9: mutation testing, the results note, and the exit gate

**Files:**
- Create: `docs/superpowers/notes/plan-3f-mutation-log.md`
- Create: `docs/superpowers/notes/2026-08-22-plan-3f-results.md`
- Modify: `STATUS.md`

**Interfaces:**
- Consumes: everything.
- Produces: the results of record.

**Mutation procedure — the mutation, the test and the restore run in ONE shell call.** A `trap ... EXIT` spread across two Bash calls fires before the test runs, so the mutation is never measured. Plan 3e lost a full agent run to that.

```bash
cp target.dart /tmp/target.dart.bak && \
  (apply the mutation) && \
  (CI=true flutter test ... ; echo "EXIT=$?") ; \
  cp /tmp/target.dart.bak target.dart
```

**Never `git checkout` a file to revert a mutation** — it restores HEAD and silently wipes every uncommitted change in that file.

- [ ] **Step 1: Run all fifteen named mutants**

| # | mutation | expected killer |
|---|---|---|
| 1 | move the LOD test after `measure()` | row 1 |
| 2 | `<` to `<=` at the threshold | the exact-threshold test in `text_lod_test.dart` |
| 3 | drop `chain.scaleMagnitude`, cull on world height alone | row 5 |
| 4 | drop `_culledText++` | row 4 |
| 5 | reference walk reads the painter's decision | the non-identity differential fixture |
| 6 | merge the two maps back into one | row 10 |
| 7 | `metricsLimit` defaulted to `kParagraphCacheLimit` | row 10, in layouts |
| 8 | remove the `DraftCanvas` guard | row 8 |
| 9 | `measure()` does not store metrics | rows 1 and 10 |
| 10 | apply LOD inside `entityBounds` | row 6 |
| 11 | `culledTextCount` not reset per frame | the two-frame test |
| 12 | keep the metrics probe paragraph instead of disposing it | the ladder's distinct-key column |
| 13 | `DraftCanvas.dispose()` keeps calling `clear()` | row 11 |
| 14 | `minTextCapPixels` left out of `didUpdateWidget` | the prop-update test |
| 15 | `DraftPainter.minTextCapPixels` defaulted to `0.0` | a bare-`DraftPainter` text test that passes no knob |

For each, record: the exact diff applied, the command run, the verbatim output, and the verdict — **killed**, **equivalent with the argument**, or **unmeasurable with the reason**.

**A named killer is not a killer until it has fired.** Plan 3c had four of twenty spec mutants survive the very suite named for them. If a mutant survives, that is a result: write the number, say what it implies, and either add the test that kills it or record it as a gap.

- [ ] **Step 2: Write the mutation log**

Create `docs/superpowers/notes/plan-3f-mutation-log.md` with one section per mutant: the diff, the command, the output, the verdict. No summary that is not derivable from the rows.

- [ ] **Step 3: Run the thirteen failable criteria**

| # | row | threshold |
|---|---|---|
| 1 | whole-drawing camera, repeat frame, new layouts | 0 (baseline 4,140) |
| 2 | whole-drawing camera, repeat frame, paragraph evictions | 0 (baseline 4,140) |
| 3 | working-set camera, layouts and paragraph evictions | 0 |
| 4 | `culledTextCount`, whole-drawing camera | > 0 |
| 5 | `culledTextCount`, working-set camera | 0 |
| 6 | `doc.extents` at `minTextCapPixels` 0 and 1000 | bit-identical |
| 7 | picking a text entity, at both thresholds | same hit |
| 8 | `DraftCanvas` over a document with the default measurer | throws, naming the fix |
| 9 | differential oracle, LOD on, both cameras | passes |
| 10 | extents-sweep non-interference | layouts 0, paragraph evictions 0 |
| 11 | split view: dispose one canvas | the other's `layoutCount` unchanged |
| 12 | `measurer.clear()` | every live paragraph `debugDisposed` |
| 13 | mutation log | every mutant killed, argued equivalent, or recorded unmeasurable |

Row 10's procedure: paint one frame at the working-set camera warm; call `invalidateDerived()` then read `doc.extents` in full; repaint at the same camera; read new paragraph layouts and paragraph evictions.

**If a failable row misses: record the number and stop.** Plan 3b's Task 4 stop clause is the precedent. Do not tune the threshold until the row complies — say what the number implies for Plan 3g's text LOD and stop.

- [ ] **Step 4: Run the full green gate**

```bash
cd packages/jet_cad_2d          && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter        && CI=true flutter test && CI=true flutter test --tags golden && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d    && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../packages/jet_cad_2d    && dart run benchmark/query_throughput.dart
```

`snap at dirty threshold` is the known carried failure from Plan 2. It is not a regression.

- [ ] **Step 5: Write the results note**

Create `docs/superpowers/notes/2026-08-22-plan-3f-results.md`: every criterion with its measured number and verdict, the threshold ladder table, the per-site margin table from Task 6, the measured distinct-key count, whether Low Power Mode was on, and the exact Flutter and framework versions from `flutter --version`.

State explicitly what this plan did **not** close: permitted divergence 5 (overlapping translucent strokes on a triangle soup), still live and still unexercised; the metrics-lookup allocation, unmeasurable without `vm_service` in the Flutter suite; and the step-function shape of the corpus's text pressure.

- [ ] **Step 6: Update STATUS.md**

Replace the "In flight" Plan 3f section from Task 1 with the finished account: exit gate result, links to both notes, and what Plan 3g inherits — a working text LOD, the threshold ladder, the measured distinct-key count, and the unresolved question of whether a cached picture may contain text at all, since a picture is baked per scale band while LOD is a function of continuous scale.

Refresh the suite table by **running** the suites, not by reading this plan.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/notes STATUS.md
git commit -m "docs: Plan 3f results, mutation log and exit gate"
```

---

## Self-review

**Spec coverage.** Section 1's ownership → Task 4. The split cache, both bounds, both constructor parameters, per-map counters, probe disposal, the insert assertion → Task 2. The counter-rename call sites and the microbench premise → Task 3. Disposal ownership and its three tests → Task 4 (split view, teardown) and Task 4 Step 5 (harness lifecycle). Section 2's LOD test and placement, the constant, the disable knob, `didUpdateWidget` → Task 5. The reference walk, the recording helpers, the second blast radius → Task 6. Documented alternatives → Task 5 Step 3's constant doc comment. Section 3's thirteen criteria, fifteen mutants, the golden ladder, the rig → Tasks 7, 8, 9. The renumbering → Tasks 1 and 9.

**One spec item is deliberately deferred rather than dropped:** `kMetricsCacheLimit`'s measured justification. Task 2 sets it from the spec's arithmetic and says in the doc comment that the figure is derived; Task 8 Step 5 replaces that sentence with the measured count. A plan that demanded the measurement in Task 2 would need the rig before the class it measures.

**Type consistency.** `paragraphEvictionCount` / `metricsEvictionCount` / `liveMetricsCount` / `paragraphLimit` / `metricsLimit` are introduced in Task 2 and used with those exact names in Tasks 3, 8 and 9. `culledTextCount` / `minTextCapPixels` / `kMinTextCapPixels` are introduced in Task 5 and used with those exact names in Tasks 6, 7, 8 and 9. `harnessMeasurer` is introduced in Task 4 and used in Task 4 only. `textLodDifferentialDocument` is introduced and used in Task 6.

**Known plan risk, stated rather than hidden.** Task 6 Step 1's fixture is complete code, but three of its numbers — the text heights 40, 172 and 800 — are derived from the fit arithmetic rather than measured, because `ViewportTransform.fit`'s margin cannot be computed from here. The step therefore requires the implementer to print all three on-screen cap heights before proceeding and to state them in the report, and says explicitly that a fixture which does not straddle the threshold gets new heights rather than a new threshold. A fixture tuned by moving `kMinTextCapPixels` tests nothing, and one written at the identity transform is the degenerate fixture this repository names as its dominant defect class.

**One more thing an implementer should not have to rediscover.** Task 2 leaves the tree in a state where `flutter analyze` fails on `paint_microbench_test.dart` — that file reads the old `evictionCount` and Task 3 owns it. This is the single place in the plan where a task does not end analyze-clean on every package, it is deliberate rather than an oversight, and Task 2 Step 5 says so. Merging the two would put a rig rewrite and a cache rewrite behind one reviewer's gate.
