# Plan 3d — final whole-branch fix wave

Worktree: `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike`
Branch: `spike/vertices-sink`. Base: `57bcd76`.

Commits:

- `4034012` test: pin the text-flush order and the golden dpr, not their counts
- `420f9de` fix(harness): detect a repaint on both backends, not only on canvas
- `ddd36c7` docs: retire four claims the implementation outlived

Nothing was merged, pushed or deleted. No `analysis_options.yaml` and no
`project.pbxproj` is in any commit. No golden PNG changed.

---

## Finding 1 (Important) — draw order across the text flush is not pinned

### What changed

`packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` gains
`'the batch reaches the Canvas before the text it was batched before'`.

The three tests the reviewer named all assert a flush **count**, and a count
cannot tell the two orders apart: a flush that happens *after* the paragraph is
still a flush. The new test does not count. It drives `VerticesDrawSink`
through a `SpyCanvas` (`test/support/spy_canvas.dart`, already used by
`paint_allocation_test.dart`) with a **real `CanvasDrawSink` fallback** wired to
the same spy — the existing tests pass no fallback at all, which is the
structural reason they could only ever count, since with a null fallback no
paragraph reaches any canvas. It then reads the recorded call sequence and
asserts:

- `indexOf('drawVertices') < indexOf('drawParagraph')` — the batch before the
  text reaches the canvas first;
- `lastIndexOf('drawVertices') > indexOf('drawParagraph')` — the batch after it
  reaches the canvas last;
- both indices are non-negative first, so a missing call cannot make the
  comparison vacuous (`-1` is less than every index);
- the two `drawVertices` indices differ, so the comparison was against two
  distinct submissions.

The fixture runs under a non-identity residual — `Transform2(0, 1, -1, 0, 100,
200)`, a quarter turn plus a translation — rather than at the identity, which
`CLAUDE.md` names as this repository's dominant failure mode.

### The mutation, and the transcript

The reviewer's exact mutation: in `VerticesDrawSink.text`, hand the text to the
fallback *before* the flush, leaving the flush count unchanged.

```dart
  void text(String text, Handle style, ResolvedStyle resolved) {
    _fallback?.text(text, style, resolved);   // was second
    _flushBeforeUnbatchable();                // was first
  }
```

`flutter test test/vertices_draw_sink_test.dart` with the mutation applied:

```
00:00 +11: the segment count is what a rig reads to compare sinks
00:00 +12: the batch reaches the Canvas before the text it was batched before
00:00 +12 -1: the batch reaches the Canvas before the text it was batched before [E]
  Expected: a value less than <5>
    Actual: <7>
     Which: is not a value less than <5>
  the strokes batched before the text must reach the Canvas before the paragraph does. Canvas call sequence was: [save, transform, save, translate, scale, drawParagraph, restore, drawVertices, restore, drawVertices]
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/vertices_draw_sink_test.dart 317:5             main.<fn>
  
00:00 +12 -1: an arc is flattened, and its ends sit on the arc
...
00:00 +18 -1: an unbatchable op flushes first, so draw order holds across it
...
00:00 +32 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the batch reaches the Canvas before the text it was batched before
```

Two things in that transcript are the finding, confirmed:

1. The failure is on the **order** assertion (`a value less than <5>` — a call
   index), not on a count, and the recorded sequence shows `drawParagraph` at
   index 5 with both `drawVertices` calls after it.
2. `'an unbatchable op flushes first, so draw order holds across it'` — the test
   at `:629` that names this exact property — **still passes** (`+18`) under the
   mutation. So does the whole rest of the file.

And `sink_comparison_test.dart`, with the same mutation still applied:

```
00:00 +0: the two backends draw the same drawing
00:00 +1: the two backends agree on the ops the painter cannot emit
00:00 +2: anisotropic stroke width diverges, and vertices is right
00:00 +3: a sub-pixel stroke is where the two backends stop agreeing
00:00 +4: a full-sweep ARC leaves an unjoined seam. This is a defect
00:00 +5: All tests passed!
```

Fully green, including its `verticesFlushCount == 2` assertion at `:38`. The
new test is the only thing on the branch that kills this mutant.

The mutation was reverted by `cp` from a backup taken before it was applied;
`git diff --stat -- packages/jet_cad_2d_flutter/lib/` was empty afterwards.

---

## Finding 2 (Important) — the golden helpers launder a dpr break

### What changed

`test/golden/dash_ladder_golden_test.dart` and
`test/golden/text_ladder_golden_test.dart`. The assertion was workable, so the
comment-only fallback was not used.

Both helpers did:

```dart
final dpr = key.currentState!.vertices!.devicePixelRatio;
```

so the rasterizer's resolution was whatever the sink said, and a broken sink
produced a self-consistently wrong image. They now do:

```dart
final dpr = tester.view.devicePixelRatio;
expect(key.currentState!.vertices!.devicePixelRatio, dpr,
    reason: 'the sink must be at the binding\'s device pixel ratio: '
        'DraftCanvas rebinds it per frame from MediaQuery, and a sink left '
        'at its constructor default draws stroke widths for the wrong '
        'device. Do NOT regenerate the goldens to make this pass.');
```

The ratio is the binding's, taken at the point the fixture is built, and the
sink is checked against it. The comment block above it was rewritten to say why
reading it back was wrong and to name the exact laundering path.

### The mutation, and the transcript

The reviewer's mutation: delete the per-frame rebind in `draft_canvas.dart`
(`vertices?.devicePixelRatio = MediaQuery.devicePixelRatioOf(context);`), which
leaves the sink at its constructor default of 1.0.

Plain run of both ladders with the mutation applied:

```
00:00 +2: .../dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.vertices)
Expected: <3.0>
  Actual: <1.0>
the sink must be at the binding's device pixel ratio: DraftCanvas rebinds it per frame from
...
00:00 +10 -10: Some tests failed.
```

10 red (every vertices rung on both ladders), 10 green (every canvas rung,
which has no vertices sink and is correctly unaffected). The failure is now a
**named assertion on the ratio itself**, `Expected: <3.0> Actual: <1.0>`, and it
fires before `matchesGoldenFile` is ever reached — not an image-size mismatch.

Then the half of the finding that matters, `flutter test --update-goldens` with
the mutation still applied:

```
00:00 +10 -10: Some tests failed.
```

Still 10 red. `git status --porcelain` immediately afterwards listed only the
three files I had edited — **not one PNG was rewritten**, because the assertion
aborts each vertices test before the golden is regenerated. Under the old
helpers this same command turned all 20 green with the break in place. That is
the regression closed.

(The golden directory was copied aside before the `--update-goldens` runs as a
precaution; it was not needed, since nothing changed.)

`draft_canvas.dart` was restored by `cp` from a backup;
`git diff --stat -- packages/jet_cad_2d_flutter/lib/` was empty afterwards.

---

## Finding 3 (Minor) — a rig guard that aborts healthy frames

`apps/dev_harness_2d/lib/measurement_rig.dart`. The guard was
`if (sink.canvasCallCount == 0) throw StateError(...)`. Under the vertices
default that sink is the fallback and takes only text, so the counter counts
paragraphs and its four other increment sites are unreachable; with
`DRAW_TEXT=0` it reads zero for a healthy frame and the rig aborted.

Now:

```dart
final drawCalls = sink.canvasCallCount + (vertices?.totalFlushCount ?? 0);
if (drawCalls == 0) {
```

`totalFlushCount` is the vertices sink's own counter — one `drawVertices` per
flush, already printed by `printBackend` since Task 7 — and `flush()` returns
without incrementing it when nothing was batched, so zero still means "nothing
was drawn". Summing the two makes the guard answer "did *something* reach the
canvas" on whichever backend is running, which is what its comment claimed all
along. The comment above it now states the paragraphs-only problem and why the
sum is the detector; the pre-existing comment inside the `if` about
`panBy(Offset.zero)` and `Transform2` is unchanged and still accurate.

Not mutation-tested: the rig has no test suite, and the change is a widened
disjunction in a debug-only measurement harness. It is covered by
`flutter analyze` on `apps/dev_harness_2d`, which is clean.

---

## Finding 4 (Minor) — the magnitude, where a sink reader meets the property

`vertices_draw_sink.dart`. `debugCapacityVertices`' doc now carries the
measured number and the corpus it came from:

> A vertex is 12 bytes here — a `Float32x2` position plus an `Int32` colour —
> and the peak is pinned for the life of the widget, because nothing ever
> shrinks it. On the dev harness's R2 corpus (`apps/dev_harness_2d`, pan 120 /
> zoom 120 over an 800x600 viewport) the peaks read out of this getter were
> 262,144 vertices at 10,000 entities (3.00 MiB), 1,048,576 at 50,000 (12.00
> MiB) and **8,388,608 at 500,000 entities — 100,663,296 bytes, exactly 96.00
> MiB**. The canvas backend has no equivalent cost.

`_positions`' doc, which is the other place that said "capacity is never given
back" without the magnitude, now points at `debugCapacityVertices` for the
bytes rather than repeating the table. Both point at
`docs/superpowers/notes/2026-08-21-plan-3d-results.md`.

---

## The four claims that outlived their evidence

All four in one commit, `ddd36c7`.

**`vertices_draw_sink.dart:21` — "A spike."** Now opens
"**The default backend on every platform, the web included.**", records that it
began as a spike, that Phase C answered the question and Task 13 flipped the
default, points at the results note, and says explicitly that being the default
does not retire anything under "What this is not".

**`:76-78` — "`flutter_test` cannot render it … the golden suite is not
available to this sink."** Rewritten so the true mechanism survives and the
false conclusion goes: software Skia still cannot rasterise a large
`drawVertices`, so `matchesGoldenFile` on the widget is still ruled out — but
the bullet now says the goldens exist, that the `observer` seam hands each
buffer to `test/support/triangle_rasterizer.dart`, that the 14 PNGs live in
`test/golden/vertices/`, and that they are updated like any other golden.

**`:143` — `_fallback`'s doc.** It was the wrong one of the two (`:71-73` was
right), so it was the one fixed: "Takes the ops this sink does not batch, which
is fewer than it sounds: exactly `beginResidual`, `endResidual` and `text`
forward here. Points, circles and arcs all become triangles in this sink and
never reach it."

**`specs/2026-08-20-…-plan-3d-design.md:336`.** A dated block quote was added
directly after the sentence. The spec's own argument is **not** rewritten. The
annotation records that Phase C's measurement overturned the premise, that Task
13 flipped the default on every platform including the web, the two ratios that
decided it (17.3x at 10,000, 17.5x at 50,000), that both backends are now
goldened, and that the section is left as written because it was correct
against the evidence of its day. It points at the results note.

---

## The parity fix — `_emitJoin`'s unreachable branches

**Chosen: comment, not delete.** Both now carry a justification in the same
shape as `_endRun`'s.

`mlen == 0`: `n0` and `n1` have equal length, so their sum vanishes only when
they are antiparallel — `d0` and `d1` antiparallel, dot product `-1`, and the
`kMinMiterCosine` bail three lines above already returned.

`cosHalf <= 0`: the bail bounds the turn at about 151 degrees (`-0.875` at a
miter limit of 4), so half of it is under 76 degrees and its cosine is
comfortably positive.

Why kept rather than deleted, which is the part the comments record: both are
unreachable *because of today's bail threshold*, which is a constant derived
from `kMiterLimit` and not a promise the arithmetic below makes on its own.
Without `mlen == 0` a loosened limit divides by zero and writes NaN positions
into the buffer the engine draws; without `cosHalf <= 0` the alternative to a
bounded `reach` is a miter spike of unbounded length, which is the exact
failure a miter limit exists to prevent. Deleting them would trade a dead line
for a silent NaN, and `_endRun` already made this call the same way in the same
file — which was the reviewer's point about the treatment being inconsistent.

---

## The three-package gate

```
### packages/jet_cad_2d
00:02 +720: All tests passed!
No issues found!
Formatted 105 files (0 changed) in 0.14 seconds.
### packages/jet_cad_2d_flutter
00:02 +239 ~1: All tests passed!
No issues found! (ran in 0.9s)
Formatted 44 files (0 changed) in 0.06 seconds.
### apps/dev_harness_2d
No issues found! (ran in 0.8s)
Formatted 4 files (0 changed) in 0.02 seconds.
```

Engine 720 passing (unchanged). Widgets **239 passing / 1 skipped**, up from
238/1 — the one added test is Finding 1's. Harness analyze and format clean.

`git status --porcelain` on the worktree is empty after the three commits.

---

## Files changed

| File | Finding |
|---|---|
| `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` | 1 |
| `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart` | 2 |
| `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart` | 2 |
| `apps/dev_harness_2d/lib/measurement_rig.dart` | 3 |
| `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` | 4, stale claims 1–3, parity fix |
| `docs/superpowers/specs/2026-08-20-jet-cad-2d-plan-3d-design.md` | stale claim 4 |

---

## Not fixed, and why

- **Finding 3 has no test.** `apps/dev_harness_2d` has no suite to add one to,
  and the rig is debug-only measurement code. Named here rather than left
  implicit.
- **`CLAUDE.md` untouched**, as instructed — its allocation rule is the human's
  open question.
- **`docs/superpowers/notes/2026-08-21-plan-3d-results.md` untouched.** Finding
  4 asked for the number to be moved to where a sink reader meets it, not
  removed from the note; the note is a result of record.
- **The `STATUS.md` resume doc is not updated.** The handoff is the
  controller's and the menu is the human's, per the constraints.
