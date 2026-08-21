# Task 8 report — the flush observer

## What was implemented

`packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`:

- Added `typedef FlushObserver = void Function(Float32List positions, Int32List colors);`,
  placed above the class's own doc comment (imports → new typedef with its
  own doc → the class's existing design essay → `class VerticesDrawSink`),
  not spliced into the tail of the class doc as the brief's snippet order
  would literally produce if pasted verbatim — see "A defect I introduced
  and fixed" below.
- Added `FlushObserver? observer;` beside `canvas`, with the doc comment the
  brief specifies verbatim (test seam, null in production, names
  `test/support/triangle_rasterizer.dart` as the only caller-to-be).
- In `flush()`, immediately after `_lastFlushVertices = colors.length;`:
  `observer?.call(positions, colors);` — before `Vertices.raw` is even
  constructed, so strictly before both the `drawVertices` submission and the
  disposal that follows it.

`packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`: the three
tests from the brief, appended verbatim with one addition (see below) —
`the observer sees exactly what was submitted, before the rewind`, `a flush
with nothing batched does not call the observer`, `the observer fires once
per flush, text included`.

One deviation from the brief's literal test code: the first test is built
without the `..observer = (...)` cascade the brief's snippet uses, because
the investigation below needed the closure to read `sink.lastFlushDisposed`
at call time — a self-reference a chained cascade can't make before `sink`
exists as a completed local. `final sink = _sink(canvas: canvas); sink.observer
= (positions, colors) { ... };` instead, functionally identical, followed by
one added `expect(disposedAtCallTime, isFalse);`. Documented inline in the
test with its own `// MUTATION:` comment and the empirical results below.

## TDD evidence

RED (before implementing, `observer` setter undefined):

```
test/vertices_draw_sink_test.dart:347:9: Error: The setter 'observer' isn't defined for the type 'VerticesDrawSink'.
      ..observer = (positions, colors) {
        ^^^^^^^^
[... two more identical errors at the other two call sites ...]
00:00 +0 -1: Some tests failed.
```

Expected and matches the brief's Step 2 exactly.

GREEN (after implementing, full file):

```
00:00 +28: the observer sees exactly what was submitted, before the rewind
00:00 +29: a flush with nothing batched does not call the observer
00:00 +30: the observer fires once per flush, text included
00:00 +31: All tests passed!
```

## A defect I introduced and fixed

Pasting the brief's typedef snippet "above the class" literally, immediately
before `class VerticesDrawSink implements DrawSink {`, put it after the
class's own ~80-line doc comment with no blank line separating the two doc
blocks. Dart/dartdoc attaches a contiguous run of `///` lines to whatever
declaration immediately follows it with no blank line in between — so that
placement would have made the entire class-design essay (the "Why this
shape" / "One buffer" / "What this is not" sections) read as the *typedef's*
doc comment instead of the class's, and left the class itself undocumented.
`dart format` doesn't catch this (it's not a formatting error) and
`dart analyze` doesn't either (it's not an analysis error) — I only found it
by rereading the diff before committing. Fixed by moving the typedef and its
doc comment above the class's doc block entirely, with a blank line on both
sides. Confirmed clean by rereading the file after the fix (see the final
diff below) and rerunning the full flutter test/analyze/format gate.

## Mutations run, with real transcripts

Backup taken before any mutation: `cp` to
`/private/tmp/claude-501/.../scratchpad/vertices_draw_sink.dart.bak`,
restored via a `trap 'cp "$BACKUP" "$FILE"; ...' EXIT` on every mutation run,
`git status --porcelain` confirmed clean after each one before moving to the
next.

### Mutation A — test 1's own comment: hand the observer the whole buffer

```sh
sed -i 's/observer?.call(positions, colors);/observer?.call(_positions, _colors);/' lib/src/vertices_draw_sink.dart
```

```
00:00 +0 -1: the observer sees exactly what was submitted, before the rewind [E]
  Expected: <12>
    Actual: <8192>
```

RED, for the right reason: `_positions` (the raw backing array) has 8192
slots; the sublistView is 12. Restored, `git status --porcelain` clean.

### Mutation B — test 2's own comment: call it unconditionally

Inserted an unconditional `observer?.call(...)` at the top of `flush()`,
before the `if (_vertices == 0)` guard:

```
00:00 +0 -1: a flush with nothing batched does not call the observer [E]
  Expected: <0>
    Actual: <1>
```

RED. Restored, clean.

### Mutation C — test 3's own comment: observe only the final flush

Guarded the real call with `if (_totalFlushes == 0) observer?.call(...)`,
simulating "only the first/final flush notifies":

```
00:00 +0 -1: the observer fires once per flush, text included [E]
  Expected: <2>
    Actual: <1>
```

RED. Restored, clean.

### Mutation D — "call it after disposal" (literal reorder, same captured views)

Moved `observer?.call(positions, colors);` to immediately after
`vertices.dispose();`, keeping the same local `positions`/`colors` variables:

```
00:00 +1: All tests passed!
```

**Did not go red.** Investigated why: `Vertices.raw` copies the position and
colour data into native memory synchronously at construction, so
`vertices.dispose()` frees the engine-side copy, not the Dart `Float32List`/
`Int32List` views this test already holds — those remain valid and
unchanged regardless of when `dispose()` runs. So the position/colour/count
assertions in test 1 cannot distinguish "before disposal" from "just after
disposal" by content alone; this was a `// MUTATION:` comment I would have
shipped as read (my first attempt said "hand the observer the whole buffer
... instead of before" would flip `disposedAtCallTime` to true) that turned
out factually wrong about the code, exactly the failure mode `CLAUDE.md`
warns this plan has shipped before. Restored, clean.

### Mutation D2 — moving the call past the point where disposal is actually recorded

Moved the call to just after the `assert(() { _lastFlushDisposed =
vertices.debugDisposed; ...` block (still ahead of the rewind):

```
00:00 +0 -1: the observer sees exactly what was submitted, before the rewind [E]
  Expected: false
    Actual: <true>
```

RED — this is the mutation the `disposedAtCallTime` assertion actually
catches, and I rewrote its `// MUTATION:` comment to say so precisely
instead of the inaccurate first draft. Restored, clean.

### Mutation E — "call it after the buffer is rewound"

Moved the call to after `_vertices = 0; _segments = 0;`, recomputing the
views fresh from the (now-empty) `_vertices` count rather than reusing the
pre-rewind locals:

```
00:00 +0 -1: the observer sees exactly what was submitted, before the rewind [E]
  Expected: <12>
    Actual: <0>
```

RED. Restored, clean.

### Honest conclusion on the two controller-named mutations

- **"Calling it after the buffer is rewound"** — dies. Mutation E.
- **"Calling the observer after disposal instead of before"** — dies for
  every version of this mutation with an observable side effect (Mutation
  D2: past the point where `_lastFlushDisposed` is actually recorded). It
  does *not* die for the narrow three-line window between `vertices.dispose()`
  itself and the `assert` block that immediately follows it (Mutation D),
  because that window has no observable effect through any public API —
  `Vertices.raw` already owns a native copy of the data by the time
  `dispose()` runs. I verified this is a real, reproducible fact about the
  engine rather than a gap in my test, by running both placements and
  getting a different, principled answer each time. The implementation
  itself calls the observer before `Vertices.raw` is even constructed —
  strictly earlier than either boundary — so this unfalsifiable window is
  not a defect surface the shipped code can actually land in without a
  deliberate further reorder past Mutation D2's boundary, which the test
  does catch.

## What a no-observer flush allocates: before vs. after

**Unchanged: three objects per flush — the `Vertices` and the two
`sublistView` wrappers — and nothing per entity or per flush from the new
code.** `observer` defaults to `null`; `observer?.call(positions, colors)`
is a null check on a field read, and Dart short-circuits without invoking
the closure or allocating anything when the field is `null`. No closure is
created at the call site (it forwards the already-stored `observer` value),
and no copy of `positions`/`colors` is made — the same two live sublistView
objects `flush()` already builds for `Vertices.raw` are passed through by
reference. `test/invariants/paint_allocation_test.dart` (which never sets
`observer`, so it's null throughout) still passes: `debugCapacityVertices`
holds still between the two reads of the steady-state frame, confirming no
new allocation appears on the no-observer path.

## Full three-package gate

`packages/jet_cad_2d`:

```
$ dart test
00:03 +720: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.18 seconds.
```

`packages/jet_cad_2d_flutter`:

```
$ flutter test
00:02 +209 ~1: All tests passed!
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
$ dart format --output=none --set-exit-if-changed .
Formatted 40 files (0 changed) in 0.07 seconds.
```

209 passing / 1 skipped — the stated baseline of 206 passing / 1 skipped
plus the 3 new tests, no regressions.

`apps/dev_harness_2d`:

```
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
$ dart format --output=none --set-exit-if-changed lib integration_test
Formatted 2 files (0 changed) in 0.01 seconds.
```

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — `FlushObserver`
  typedef, `observer` field, the hook in `flush()`.
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` — three new
  tests.

`git status --porcelain` shows exactly these two files; no
`analysis_options.yaml`, no stray files from mutation testing.

## Self-review findings

1. **Fixed before commit**: the doc-comment misattachment described above
   (typedef spliced into the tail of the class doc with no blank line). This
   is the kind of defect that survives `dart analyze`/`dart format` silently
   and would only surface on a documentation build or a careful reread —
   worth flagging for reviewers checking future "add a top-level declaration
   above an existing heavily-documented class" tasks in this plan.
2. Considered whether `observer` should be reset to `null` by anything in
   the sink (e.g. on dispose/reset) — no such lifecycle exists on
   `VerticesDrawSink` today and the brief doesn't ask for one; left as a
   plain settable field, matching `canvas`'s own late-rebound pattern.
3. Considered whether the observer should also fire from
   `_flushBeforeUnbatchable`'s early-return branch (`if (_vertices == 0)
   return;`) — it correctly does not, since that branch never reaches the
   real `flush()` body's `observer?.call`, and test 2 pins exactly this.

## Concerns

- The one honestly-unfalsifiable mutation window described above (calling
  the observer in the three lines between `vertices.dispose()` and the
  `assert` block that records `_lastFlushDisposed`) is worth a reviewer's
  own look, since it means "before disposal" and "before the buffer is
  rewound" are not fully independent claims for *this* observer design —
  only the rewind (and the disposal record, one step short of the rewind)
  are directly testable. The implementation itself is unaffected: the
  observer call sits well before both boundaries in the source, ahead of
  where `Vertices.raw` is even constructed.
