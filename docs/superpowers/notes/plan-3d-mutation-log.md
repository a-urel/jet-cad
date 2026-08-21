# Plan 3d mutation log

**Verdict: thirty-nine mutants accounted for. Thirty-four killed (two of them
only after a fix round), one recorded as a deliberate control that is
expected to survive, and two recorded as not independently re-mutated with
the reason given, plus two more cited from the codebase's own confirmed
record rather than re-run.** Fourteen of the thirty-four kills are the design
document's own table — `J1`-`J9`, `B1`, `B2`, `A1`, `V1`,
`P1` — run fresh in this task in twelve mutation-test cycles (two pairs share
one code line and one run each: `J1`/`J6` and `J8`/`J9`, see the note under
Part 1). The other twenty-two kills, plus the one control, stand in for "the
spike's 33": drawn from the `// MUTATION:` comments the spike and Tasks 2, 4,
5, 6, 8 and 9 left embedded in the inherited test suite, plus a handful
constructed to reach code the comments describe but do not spell out, all run
fresh in this task against today's code. Combined, Parts 1 and 2 below are
**thirty-three distinct mutation-test cycles** — a coincidence with the
spike's own tally, explained rather than engineered, in the note before
Part 2. Two survivors surfaced (`A1`, `S2`) and both are closed, in this task,
with a new test each — `debugPaint` identity and flush-time colour order —
that the suite did not carry before, and both are re-counted as kills in the
"killed" total above. Two mutations are cited from the codebase's own
"confirmed empirically" record rather than re-run, and two are recorded as
not independently reproducible; the reasoning for each is given below rather
than treated as a gap.

| Category | Count | Outcome |
|---|---|---|
| Named in the design document (`J1`-`J9`, `B1`, `B2`, `A1`, `V1`, `P1`) | 14 | 13 killed outright, 1 (`A1`) survived and was closed with a new test |
| Spike-heritage, run fresh in this task | 21 | 19 killed outright, 1 (`S2`) survived and was closed with a new test, 1 (`E20_one`) is a deliberate control confirming a documented property |
| Cited from the codebase's own confirmed-empirical record, not re-run | 2 | both previously confirmed (Task 2, Task 8) |
| Not independently reproducible, reason recorded | 2 | no discrete code path exists to mutate (structural) |
| **Total accounted for** | **39** | **34 killed, 1 control, 2 cited, 2 not reproducible** |

Parts 1 and 2 below run to **thirty-three distinct mutation-test cycles**
(twelve covering the fourteen named mutants, twenty-one more for the
spike-heritage set) — a numeric coincidence with the spike's own tally,
explained rather than engineered, in the note before Part 2.

**Why "the spike's 33" is not a literal replay.** The spike's own note
(`docs/superpowers/notes/2026-08-20-vertices-sink-spike.md`) records a tally —
33 mutants, 32 killed, 1 not applicable — but no surviving per-mutant diff:
the individual edits lived only in a session-local script that was never
committed. What *did* survive, committed and inherited, is `// MUTATION:`
comments beside twenty of the twenty-eight tests the spike shipped in
`vertices_draw_sink_test.dart`, plus more that Tasks 2, 4, 5, 6, 8 and 9 added
alongside their own work in `vertices_join_test.dart`, `point_shape_test.dart`
and `render_backend_test.dart`. Those comments *are* the concrete, checkable
trace of the spike's mutation testing, most of them still describing the exact
lines they were written against. This task ran every one of them for real,
against the code as it stands today, rather than assert the historical count.
Two of the thirty-four candidate mutations this produced turned out to be the
same code line under two different names (`S15` and `S17b`, both the
half-width floor's `devicePixelRatio` division — see below); merged, that
leaves **thirty-three** distinct mutations run in this part of the task,
which is a coincidence worth naming rather than a target this task aimed at.

**How each mutant was applied and reverted.** A Python runner
(`scratchpad/mutate14.py`, session-local, not committed, modelled on Plan 3c's
`mutate13.py`) copies the target file aside, applies the edit, runs the
narrowest test file that should catch it, and restores from the copy in a
`finally` block — **`git checkout` was not used anywhere in this task.**
`git status --porcelain` was read after every mutation and confirmed the
backup-restored file carried no leftover edit; the three real (non-mutation)
changes this task makes — a `debugPaint` getter and two new tests — are the
only diff left in the tree once every mutation run finished, confirmed by
`grep -rn MUTATION packages/jet_cad_2d_flutter/lib/` finding nothing.

**Baseline before this task:** `jet_cad_2d` 720 tests; `jet_cad_2d_flutter`
236 passed / 1 skipped. **After:** `jet_cad_2d` 720 (unchanged, this task
touches no file in that package); `jet_cad_2d_flutter` **237** passed / 1
skipped — one net new test (the second closes an existing test's own
assertion, described below); `dart analyze`/`flutter analyze` and
`dart format --set-exit-if-changed` clean in all three packages.

---

## Part 1: the design document's table (14 mutants)

Run fresh in this task against `lib/src/vertices_draw_sink.dart`,
`lib/src/canvas_draw_sink.dart` and `lib/src/draft_canvas.dart`. `J8` and `J9`
share one code line (the seam join's `_emitJoin` call in `_endRun`) and so
share one mutation run; `J6`'s killer is the same `_emitJoin` no-op as `J1`,
reached through the arc fixture rather than a separate line, so it rides on
`J1`'s run rather than a second one.

| # | Mutant | Site | Killed by | Observed |
|---|---|---|---|---|
| J1 | Emit no join triangle at an interior vertex | `_emitJoin` becomes `return;` on entry | 12 of 14 tests in `vertices_join_test.dart`, e.g. `'a zero-length step is skipped and the join spans it'` | `Expected: <6> / Actual: <4>` |
| J6 | Skip the join between two chords of a flattened curve | same `_emitJoin` no-op (`J1`) | `'a flattened curve joins its chords'`, in the same run | `Expected: true / Actual: <false>` |
| J2 | Miter every corner, ignoring the limit | `if (d0x*d1x+d0y*d1y < kMinMiterCosine) return;` → `if (false) return;` | `'a corner past the miter limit is bevelled, one triangle'` (and 12 more) | `Expected: <5> / Actual: <6>` |
| J3 | Bevel every corner, ignoring the limit | same guard → `if (true) return;` | `'a corner just inside the limit is still mitred'` (and 8 more) | `Expected: <6> / Actual: <5>` |
| J4 | Take the miter on the inside of the turn | `s = cross > 0 ? -half : half;` → `? half : -half` | `'a mitred corner emits both the bevel and the tip triangle'` (and 6 more, including the right-angle and clockwise-turn fixtures the mutation's own comment names) | `Expected: true / Actual: <false>` |
| J5 | Join the first and last segment of an *open* polyline | `polyline`'s `_endRun(closed: closed, ...)` → `closed: true` | `'a corner past the miter limit is bevelled, one triangle'` (and 5 more — every open-run triangle count moves) | `Expected: <5> / Actual: <11>` |
| J7 | Emit the miter tip triangle without the bevel | bevel triangle rebuilt from the *inner* corners, honest form (see Task 4) | `'a mitred corner emits both the bevel and the tip triangle'` (and 2 more) | `Expected: true / Actual: <false>` |
| J8 | Cap the seam of a closed flatten instead of joining it | `_endRun`'s seam `_emitJoin` call disabled | `'a circle joins at its seam, so there is no notch at the start angle'` | `Expected: true / Actual: <false>` |
| J9 | Cap the seam of a closed polyline instead of joining it | same disabled call (`J8`) | `'the seam is one join, not two, and not a cap'`, same run | `Expected: <16> / Actual: <14>` |
| V1 | Never dispose the submitted `Vertices` | `vertices.dispose();` deleted | `'the submitted Vertices is disposed, and the flag reads its state'` | `Expected: true / Actual: <false>` |
| P1 | Emit the point square in local space, so it shears with the residual | `CanvasDrawSink.point` reverted to `_pushTransform()` + local-space `drawRect` | `'the marker is axis-aligned on screen under a sheared, non-uniformly-scaled residual'` | `Expected: (maxX: 9, maxY: 9, minX: 6, minY: 6) / Actual: (maxX: 11, maxY: 10, minX: 4, minY: 5)` |
| B1 | Resolve the backend per call site rather than once | `didUpdateWidget`'s comparison drops `widget.backend != oldWidget.backend` | `'changing the backend prop rebuilds the sinks'` | `Expected: not null / Actual: <null>` |
| B2 | Ignore the backend override, always use the platform default | `resolvedBackend = widget.backend ?? defaultRenderBackend();` → drops the `??` | `'only the resolved backend builds a sink'` | `Expected: null / Actual: <Instance of 'VerticesDrawSink'>` |
| A1 | Allocate the `Paint` per flush | field un-finalled, `_paint = Paint()..color = ...` inserted at the top of `flush()` | **survived first run — closed, see below** | `Expected: true / Actual: <false>` (after the fix) |

### J1/J6 and J8/J9: one code line, two rows

The design document lists these as four rows because they name four different
*properties*, but Plan 3d's own architecture (Task 5: "one shared walk") means
an interior-vertex join and a flattened curve's chord join are the same
`_emitJoin` call, and a closed polyline's seam and a closed flatten's seam are
the same call inside `_endRun`. Disabling `_emitJoin` entirely kills both `J1`
and `J6` fixtures in one run; disabling the seam call inside `_endRun` kills
both `J8` and `J9` fixtures in one run. Recording them as four rows with two
runs, rather than four runs, is the honest reflection of the code, not a
shortcut — mutating the shared line twice would be the same edit twice.

### J4's mutation as literally described

The mutant table names one property (miter on the inside of the turn), and
Task 4's own history (`progress.md`, Task 4 entries) found a **second**,
narrower way to reach the same wrong-side behaviour that its first review
missed entirely: collapsing `s = cross > 0 ? -half : half` to the constant
`s = -half` (always the left-turn side) left all 198 tests green until a
right-turn fixture was added specifically to catch it. This task re-ran both:
the sign-flip (`J4` as tabled) and the historic collapse (recorded as `J4b`
below, in Part 2, since it is not a distinct row of the design table but the
same property reached a second way). Both die today, on the same fixture
(`'a right (clockwise) turn is mitred out on its own outer side'` for `J4b`),
because that fixture exists precisely because the first review missed it.

### A1 — the one survivor in the named table, closed

`paint_allocation_test.dart` measures `debugCapacityVertices`, which pins the
two buffers but has no way to see a `Paint` object, because a `Paint` is not
part of either buffer. Mutating `flush()` to build a fresh `Paint()..color =
const Color(0xFFFFFFFF)` on every call, instead of reusing the field the sink
carries for its life, left every existing assertion in the file green:

```
[A1] file: lib/src/vertices_draw_sink.dart
+0: a steady-state frame allocates O(1) per flush, not O(entities)
All tests passed!
```

Neither of `jet_cad_2d_flutter`'s test files instruments VM-level allocation
the way `jet_cad_2d/test/invariants/vm_allocation_meter.dart` does for the
query path — `paint_allocation_test.dart`'s own mechanism is a field read,
by design ("this needs no sampling profiler: once a frame has drawn its
widest view... either holds still... or it does not," per the file's header),
which is exactly why a non-buffer allocation is invisible to it. **Closed** by
adding a `debugPaint` getter (`vertices_draw_sink.dart:159-171`, `Paint get
debugPaint => _paint;`) and pinning its *identity* — not its value — across
the subject frame in `paint_allocation_test.dart`:

```dart
final paintBefore = sink.debugPaint;
painter.paint(sink, camera, _viewport);
sink.flush();
...
expect(identical(sink.debugPaint, paintBefore), isTrue, ...);
```

Re-run against the widened file: **killed**, `Expected: true / Actual:
<false>`, on the `identical` check specifically — the two prior assertions
(flush count, triangle count) stayed green under this exact mutation, which
is the point: nothing else in the file was ever going to catch it.

---

## Part 2: the inherited suite's own mutations (33, after one duplicate merge)

Each of these is either an existing `// MUTATION:` comment in
`vertices_draw_sink_test.dart`, `vertices_join_test.dart`,
`point_shape_test.dart` or `render_backend_test.dart` — most inherited from
the spike, some added by Tasks 2, 4, 5, 6, 8 and 9 — run for real against
today's code, or a mutation constructed to reach a documented finding
(`E`-prefixed below) that has no single-line comment of its own.

| id | Mutant | Killed by | Observed |
|---|---|---|---|
| S2 | Group the vertices by colour before flushing, instead of preserving emission order | **survived first run — closed, see below** | see below |
| S5 | A flush with nothing batched still tries to dispose | `'a flush with nothing batched disposes nothing'` | `Expected: <0> / Actual: <1>` |
| S6 | Hand the observer the whole buffer rather than the submitted view | `'the observer sees exactly what was submitted, before the rewind'` | `Expected: <12> / Actual: <8192>` |
| S8 | Call the observer unconditionally, even on an empty flush | `'the observer sees exactly what was submitted, before the rewind'` (calls count moves) | `Expected: <1> / Actual: <2>` |
| S10 | Replace the segment count with a constant 8 | `'the flattened arc stays within a quarter pixel of the true one'` | `Expected: a value less than <0.25> / Actual: <0.9607...>` |
| S11 | Take the radius in local space instead of device space | `'the segment count follows the arc as the residual scales it'` | `Expected: a value greater than <32> / Actual: <8>` |
| S12 | Emit nothing for a point | `'a point is a square of the stroke width, at the residual'` | `Expected: <1> / Actual: <0>` |
| S13 | Let text reach the fallback without flushing first | `'an unbatchable op flushes first, so draw order holds across it'` | `Expected: <2> / Actual: <1>` |
| S14 | Report `lastFlushSegmentCount` as the frame total | same test, second assertion | `Expected: <4> / Actual: <1>` |
| S15 / S17b | Drop `devicePixelRatio` from the half-width floor (`_halfWidthFor`) — the same code line under two names, merged, see note | `'a sub-pixel stroke gets one device pixel and loses alpha for it'`, `'a lineweight of zero is a hairline at full alpha'`, `'the floor is device pixels, so it moves with the ratio'` | `Expected: a numeric value within <1e-6> of <0.25> / Actual: <0.5>` |
| S16 | Clamp the width without touching the alpha (`_coveredArgb` returns `argb` unchanged) | `'a sub-pixel stroke gets one device pixel and loses alpha for it'` | `Expected: <3422552064> / Actual: <4278190080>` (0xCC000000 vs 0xFF000000) |
| S17 | Drop `devicePixelRatio` from `_coveredArgb`'s own `deviceWidth` (the alpha-fade width, a distinct line from `S15`/`S17b`'s floor — constructed, not from a single comment) | `'a sub-pixel stroke...'`, `'every emitter fades, not just the straight one'`, `'the fade multiplies the style alpha...'` | `Expected: <3422552064> / Actual: <1711276032>` |
| S18 | Let zero fall through to the proportional fade | `'a lineweight of zero is a hairline at full alpha'` | `Expected: <4278190080> / Actual: <0>` (alpha to 0x00) |
| S19 | Pass `style.argb` directly in `point()`, bypassing the fade | `'every emitter fades, not just the straight one'` | `Expected: <3422552064> / Actual: <4278190080>` |
| S20 | Write the coverage as the alpha instead of scaling the style's own alpha by it | `'the fade multiplies the style alpha rather than replacing it'` | `Expected: <1712469078> / Actual: <3423745110>` |
| J4b | Collapse `s = cross > 0 ? -half : half` to `s = -half` (Task 4's historic survivor, see Part 1 note) | `'a right (clockwise) turn is mitred out on its own outer side'` | `Expected: true / Actual: <false>` |
| E17 | A zero-length step loses the run's accumulated direction (`_runHasDirection = false` on the skip) | `'a zero-length step is skipped and the join spans it'` | `Expected: true / Actual: <false>` |
| E20_one | Disable only the `cross == 0` bail in `_emitJoin` | **expected non-kill, see note** | all 14 tests pass |
| E20_all | Disable all three of `_emitJoin`'s bails at once (`cross == 0`, `dot < kMinMiterCosine`, `mlen == 0`) | `'a corner past the miter limit is bevelled, one triangle'` (and 1 more) | `Expected: <5> / Actual: <6>` |
| E21 | Build both sinks unconditionally in `_attach()` | `'only the resolved backend builds a sink'` | `Expected: null / Actual: <Instance of 'VerticesDrawSink'>` |
| E22 | Swap `a` and `d` in `CanvasDrawSink.point`'s coordinate math | `'the marker is axis-aligned on screen under a sheared, non-uniformly-scaled residual'` | `Expected: (maxX: 9, minX: 6, ...) / Actual: (maxX: 7, maxY: 12, minX: 3, minY: 8)` |

That is 21 rows in this table (`S2` counted, `S15`/`S17b` merged into one).
Combined with the 12 mutation *runs* in Part 1 (which cover 14 rows, `J1`/`J6`
and `J8`/`J9` sharing), that is **33 distinct mutations executed in this
task.**

### E20_one — a control, not a survivor

`vertices_join_test.dart`'s own comment on `'a closed run of two points closes
without a phantom seam'` (the fixture two points make: one segment out, one
back) already states that disabling `_emitJoin`'s three bails **one at a
time** does not reach the division-by-zero the fixture is built to catch —
"confirmed empirically: this test is the one that goes red... and it does so
only when all three are gone together, not for any one of them alone." This
task re-ran that claim rather than take it on faith: disabling only the
`cross == 0` bail left all 14 tests in the file green, because the other two
bails (`dot < kMinMiterCosine`, `mlen == 0`) still catch the same reversal on
their own. `E20_all` — all three disabled together — then does fail, on
`v.isFinite` reading false as the comment predicts. `E20_one` is recorded as a
**deliberate control confirming a documented layered-guard property**, not as
an open survivor; the property it demonstrates is that no single bail is
load-bearing alone, which is a fact about the code, not a gap in its tests.

### S2 — the other survivor, closed

`'draw order survives batching: segments stay in emission order'` reads
`sink.debugColors()` **before any `flush()` runs** — it pins that `polyline`
writes `_colors` in call order, which is true by construction (nothing
reorders on the way in) and therefore cannot see a reorder introduced *inside*
`flush()`, on the way to `drawVertices` — which is exactly where the sink's
first shipped cut had its real bug (the class comment: "every segment of one
colour then drew after every segment of another whatever order the walk
emitted them in"). Grouping the vertices by colour inside `flush()`, before
building the submitted view, left this test green:

```
[S2] file: lib/src/vertices_draw_sink.dart
+31: All tests passed!
```

**Closed** by adding `'draw order survives the flush itself, not just the
pre-flush buffer'` (`vertices_draw_sink_test.dart:172-206`), which attaches
`sink.observer` and reads the colours the observer actually receives — the
same view `flush()` hands to `Vertices.raw` — rather than the pre-flush
buffer. Re-run against the widened file: **killed**,
`Expected: equals [4294901760, 4278255360, 4294901760] ordered / Actual:
[4278255360, 4294901760, 4294901760]` (0xFFFF0000, 0xFF00FF00, 0xFFFF0000
read back unsigned) — green, red, red instead of red, green, red, on the new
test specifically; the old test stays green either way, exactly as diagnosed.

---

## Two mutations cited, not re-run

**Dispose before `drawVertices` instead of after.**
`vertices_draw_sink_test.dart`'s `'the disposed Vertices rasterises the same
pixels a retained one would'` carries its own confirmed record: "swapping the
two lines fails an `assert(!vertices.debugDisposed)` inside `dart:ui`'s
`Canvas.drawVertices`, before this expectation is ever reached." That is an
engine-level assert, not a test assertion this suite could re-derive, and
Task 2's review (`progress.md`, Task 2 entries) already ran this exact swap
and confirmed the crash independently. Not re-run in this task; the citation
is to that engine assert and to Task 2's own re-run, not to the comment alone.

**Move the observer call to after the `assert` block.**
`'the observer sees exactly what was submitted, before the rewind'` records
that this one is unfalsifiable through any public API: `Vertices.raw` copies
`positions`/`colors` into native memory synchronously at construction, so the
three-line window between `vertices.dispose()` and the `assert` block that
reads `debugDisposed` has no observable side effect, whichever side of that
window the observer call sits on. Task 8's review reached the same conclusion
independently (`progress.md`, Task 8: "An honestly unfalsifiable window,
recorded rather than papered over"). Not re-run in this task for the same
reason it was not run again in Task 8: there is nothing a re-run could show
that the first one did not already rule out.

## Two mutations not independently re-mutated

**S1 — take the perpendicular in local space and transform it with the
segment.** `polyline` transforms every point (`a*points[i]+c*points[i+1]+e`,
similarly for `y`) *before* `_beginRun`/`_runTo` ever compute a direction or a
normal — there is no local-space normal anywhere in `_runTo`, `_emitQuad` or
`_emitJoin` to redirect; all three only ever see already-device-space
coordinates. Reaching the described mutation would mean writing a second,
parallel geometry path (compute direction from the untransformed points, take
its normal, transform *that*), which is not a mutation of a line that exists
today — it is new code with no counterpart to delete or invert. The property
is structurally guaranteed by the code's shape, and pinned by `'stroke width
is device pixels under a non-uniform residual'`, which already passes against
today's code and would need that same non-existent path to fail.

**The equivalent for joins ("joins are emitted under the residual, not in
local space").** The same argument applies one level up: `_emitJoin` receives
`vx, vy, d0x, d0y, d1x, d1y` that are already device-space by the time
`_runTo` calls it, for the identical reason. `'joins are emitted under the
residual, not in local space'` pins it and, notably, was one of the tests `J4`
and `J4b`'s mutations both broke as a side effect (both appear in Part 1 and
Part 2's failing-test lists above) — real evidence that the residual-space
property is exercised on every join mutation this task ran, even without a
dedicated local-space-join mutant to run against it directly.

---

## What this does not cover

Consistent with Task 11's architectural finding (`progress.md`, Task 11): the
seam join and the point-shape fix have no coverage through any frame path.
`draft_painter.dart` routes point, line and polyline through `_emitScreenSpace`
whose residual is a bare `Transform2.translation`, so a rotated residual never
reaches `point`, and `closed:` is `false` at all four of the painter's call
sites — `J9`'s mutation is killed here only because
`vertices_join_test.dart` calls `sink.polyline(..., closed: true)` directly,
exactly as the design document's own table says ("no painter reaches this").
This log pins what the sink does when driven directly; it does not claim the
frame path exercises `J5`, `J8`, `J9` or `P1` end to end. That gap is
pre-existing and outside this task's brief.

---

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — one getter
  added, `debugPaint`, exposing `_paint`'s identity for `A1`'s test. No
  behaviour change.
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` —
  pins `debugPaint`'s identity across the subject frame, closing `A1`.
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` — one new
  test, `'draw order survives the flush itself, not just the pre-flush
  buffer'`, closing `S2`.

## Reproducing

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike

# baseline
(cd packages/jet_cad_2d          && dart test)      # 720 pass
(cd packages/jet_cad_2d_flutter  && flutter test)   # 237 pass, 1 skip

# the two mutants that needed new tests, narrowest suite each
(cd packages/jet_cad_2d_flutter && flutter test \
  test/vertices_draw_sink_test.dart \
  test/invariants/paint_allocation_test.dart)
```

The runner used for the mutants themselves is `scratchpad/mutate14.py`
(session-local, not committed). Its shape:

```python
shutil.copy(path, backup)          # NOT `git checkout` -- see the header above
try:
    apply_edits(path, spec["edits"])
    proc = run(["flutter", "test", *spec["narrow"]])
    killed = proc.returncode != 0
finally:
    shutil.copy(backup, path)
    os.remove(backup)
    assert git_status_porcelain(spec["file"]) == expected  # clean modulo the
                                                             # three real edits
```

Every mutation's exact `old` → `new` strings live in that script; the `Site`
and `Killed by` columns above name the file and test for each.
