# Plan 3e results and exit gate — fills

**Run of record:** 2026-08-22, on `main`, directly (no worktree — this plan
worked on `main` throughout, per its own brief).
**Commit range:** design and plan at `0eac1be..3201cc5`; the seventeen tasks
at `3201cc5..f0ea51e` (Tasks 1–16) plus this task's own results commit on top.
Ranges, not counts — a count is falsified by the commit that writes it.
**Spec:** `docs/superpowers/specs/2026-08-21-jet-cad-2d-plan-3e-design.md`
(referenced by the plan; not re-read line by line here).
**Plan:** [`docs/superpowers/plans/2026-08-21-jet-cad-2d-plan-3e-fills.md`](../plans/2026-08-21-jet-cad-2d-plan-3e-fills.md)
**Mutation log:** [`plan-3e-mutation-log.md`](plan-3e-mutation-log.md) — 56
mutants accounted for, 52 killed, 2 proven equivalent, 2 documented gaps.
**Per-task ledger:** `.superpowers/sdd/2026-08-21-jet-cad-2d-plan-3e-fills/`,
to be archived to `docs/superpowers/ledgers/` alongside this note.

---

## Verdict

**Six of nine failable criteria pass outright. One is measured and cannot be
honestly evaluated from what exists (a contaminated timing row — recorded, not
scored). One is settled only in part, on the instrument this plan could
measure with, and is explicitly left open on the engine this codebase ships
on. One (the mutation log) is a process criterion, satisfied.** No criterion
failed. Nothing here was tuned to make a number comply.

| # | Criterion | Verdict | The deciding evidence |
|---|---|---|---|
| 1 | Allocations per fill in a steady-state frame — zero | **PASS** | `paint_allocation_test.dart`: `debugCapacityVertices` unchanged across the subject frame on a 200-fill corpus; `fillCount > 0`, `skippedFillCount == 0` |
| 2 | 10,000 entities, fills on, vertices backend — under 16.67 ms | **MEASURED, UNEVALUABLE** — macOS Low Power Mode was **on** for every device row | build p50 **9.12 ms**, raster p50 **5.00 ms** (Task 16, run 2) — both numbers are under threshold, but the row is contaminated and the honest reading is "does not settle the question," not "passed" |
| 3 | A fill's cost in `canvasCalls` on the vertices backend — zero | **PASS** | Task 16: `canvasCalls=0` on every `BACKEND=vertices` row, `FILLS=true` and `FILLS=false` alike |
| 4 | Ink agreement, opaque fills | **PASS** | Task 14 (fix round): canvas 174,135 / vertices 174,130 ink pixels, **0 stray, 0 uncovered** — well past the 4,000-pixel floor and the ≤1% ceilings |
| 5 | Translucent seam | **PARTLY SETTLED — do not read as "no seam"** | `SEAM interior=656204 over8=0 fraction=0.000% worst=0`; the rule does not fire, so fills batch — that part is settled. The mode-2 mechanism itself is **open on Impeller/GPU**: `flutter_test`'s software Skia does not antialias `drawVertices` at all (proven by probe, pinned as a permanent regression test), so the 0.000% is a property of the instrument, not evidence the seam is absent |
| 6 | `skippedFillCount` on the rig corpus — zero | **PASS** | Task 16: all four `FILLS=true` runs, `skippedFills=0` |
| 7 | A malformed fill in a loaded document | **PASS** | Task 8's five `validate()` codes, all five re-confirmed killed today, one-fixture-per-code, 0 cross-contamination |
| 8 | Triangulation entries after `purge()` | **PASS** | Task 3's keying mutant, re-derived across today's full six-call-site surface (not just the two files it touched at Task 3's own time) — still killed, and now also breaks undo/redo, which the original test didn't know to check |
| 9 | Cache entries after removing every fill's boundary — zero | **PASS** | Task 6's `T6b`, re-confirmed: `entryCount` goes to 0 only when `dropBoundary` actually runs; entity liveness alone stays green under the mutation |
| 10 | Load-time triangulation cost | **MEASURED AND RECORDED, no threshold** | `LOAD fills=5000 elapsed=66ms` (today's re-run; Task 16's own run read 68ms) |
| 11 | The mutation log | **PASS** | 56/56 accounted for — see [the log](plan-3e-mutation-log.md) |

**If a failable row misses, the rule is "record the number and stop."**
Nothing here misses outright. Two rows (2 and 5) are recorded as **not
settleable** by what exists rather than scored pass or fail, per the
instruction that governs exactly this situation: measure honestly, say why it
does not decide the question, and do not force a verdict a contaminated or
instrument-blind measurement cannot support.

---

## Four facts the per-task reports never state together

### 1. Flutter upgraded mid-plan: 3.47.0 → 3.47.1, between Tasks 2 and 3

Confirmed again today:

```
$ flutter --version
Flutter 3.47.1 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 6655482ec0 (2 days ago) • 2026-08-19 10:07:23 -0700
```

Task 3's report records the cause directly: three of four implementer-agent
stalls were the auto-update triggering a full Dart SDK re-download
mid-session (`curl --continue-at - ... dart-sdk-darwin-arm64.zip`, about ten
minutes, diagnosed via `ps aux` rather than by re-reading transcripts). **The
plan's own header states 3.47.0; every measurement from Task 3 onward,
including everything in this results note, was taken on 3.47.1, framework
`6655482ec0`.** The upgrade broke nothing that could be checked: the golden
suite held (23/23 at Task 3's own check, 29/29 today) and Plan 3c's Ruling 22
test-font tripwire held throughout.

### 2. macOS Low Power Mode was ON for every device timing row in Task 16

```
$ pmset -g | grep lowpowermode
 lowpowermode         1
```

Read before this task's own gate re-run, and it was **already** on when Task
16 took its six device transcripts (Task 16's own report opens with this
exact reading). This repository has been bitten by exactly this contamination
twice before: Plan 3b's entire timing set is contaminated with no clean
control, and Plan 3d measured the effect directly with Low Power Mode off —
**a uniform ~24% penalty on both raster and build**, not the 4–12× Plan 3b's
own note guessed, and CPU-only paths (closer to what the vertices backend's
`build` phase does) run **23–40% faster** with it off, contradicting Plan 3b's
claim that CPU-only paths are unaffected.

**Every timing row in Task 16 carries this mark. None of the six device
transcripts is a clean number.** The directional comparisons inside Task 16
(vertices build/raster far below canvas's; `FILLS=true` vs `FILLS=false`
leaving `dashSpans`/`collapsed` unchanged) are still meaningful, because Low
Power Mode's ~24% is a near-uniform multiplier applied to both arms of each
comparison — but no absolute number from that session should be read as a
clean measurement, and none is here.

### 3. Criterion 2 (10,000 entities, fills on, vertices, under 16.67 ms) is a timing row, and cannot be honestly evaluated

The row exists:

```
R2 (10000) frames=243
  build  p50=9.12ms p95=11.18ms max=201.24ms            [CONTAMINATED]
  raster p50=5.00ms p95=6.67ms max=80.99ms              [CONTAMINATED]
  fills=18 skippedFills=0
  backend=vertices triangles=207343 drawVerticesCalls=1
```

Both `build` p50 (9.12 ms) and `raster` p50 (5.00 ms) are numerically under
16.67 ms, by a wide margin — wider than the ~24% contamination could plausibly
erase. **This note still does not mark the row passed.** The plan's own rule
for a failable row that misses is "record the number and stop"; the honest
form of that rule for a row that is **measured but contaminated** is to record
the number, say plainly that Low Power Mode makes it unevaluable as a clean
result, and stop there rather than either asserting a pass the contamination
undermines or manufacturing a failure the numbers do not show. **Recorded:
measured, not scored.** Re-measuring with Low Power Mode off is the only way
to close this row, and it was not done in this task — Task 17's brief scopes
this task to re-running mutations and writing the note, not to retaking
device timings.

### 4. The translucent seam question is open on Impeller/GPU

Task 15 measured `SEAM interior=656204 over8=0 fraction=0.000% worst=0`
against the design's declared rule (routing fires above 0.5% at 8/255, or any
pixel at 32/255). **The rule does not fire, and that part is genuinely
settled: fills batch through `VerticesDrawSink.fillPolygon` unchanged, no
routing change was needed.**

What is **not** settled is whether the mode-2 mechanism — two triangles each
contributing partial coverage to a shared edge pixel, compounding into a
double blend — exists on the engine this codebase actually ships on. Task
15's own reviewer-driven addendum proved, by direct probe against
`Canvas.drawVertices` (not through any sink), that `flutter_test`'s software
Skia **does not antialias `drawVertices` at all**, independent of the
`isAntiAlias` paint flag: the exact same slope shows real partial-coverage
values under `drawPath` (`224,232,247`, `167,189,233` — genuinely between
white and the full-coverage colour) and only flat, fully-covered or fully-white
values under `drawVertices`, at the identical sampled coordinates. This is
pinned as a permanent regression
(`packages/jet_cad_2d_flutter/test/drawvertices_antialiasing_test.dart`, 2
tests, both green today) so a future Skia upgrade that starts antialiasing
`drawVertices` would be caught before anyone reads Task 15's `0.000%` as
settled.

**The correct sentence, and the one this note uses:** the mode-2 question is
open on Impeller/GPU, unmeasured by anything in this repository's test suite,
because the suite's picture-capture path cannot see the mechanism the design
predicts — on any geometry, not only Task 15's fixture. Per Task 15's own
amended report: **do not write "no seam was found."** This note does not.

---

## The exit gate, criterion by criterion

### Criterion 1 — allocations per fill in a steady-state frame, zero

Re-run today:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=66ms
00:00 +3: All tests passed!
```

The 200-fill corpus (`_corpus()`, `_fillFraction = 0.4`) is warmed up three
times, then `sink.debugCapacityVertices` is read before and after the subject
frame and compared for equality — a fill's triangles land in the same
doubling-reserve buffer every other primitive does, so a fill that needed to
grow the buffer in steady state would show up here exactly like any other
entity would. `painter.fillCount > 0` and `painter.skippedFillCount == 0` are
asserted directly, so the gate cannot pass vacuously on a corpus that carries
no fills or silently drops them all.

**PASS.** T4c (materialises triangles at command time, not draw time) is the
mutation that actually proves eager population — see the caveat below on what
this specific allocation mechanism can and cannot see.

**A documented caveat, found while re-deriving the cross-task mutants (see
the mutation log's Part 2, mutant #4):** `debugCapacityVertices` measures only
`VerticesDrawSink`'s own vertex-buffer capacity. A fill that computed a fresh
triangulation on the frame path (a genuine "populate lazily on first draw"
defect) would allocate an `Int32List` on the general Dart heap without
necessarily growing the sink's own buffer, because the warm-up frames have
already sized that buffer to the corpus's worst case. Constructing exactly
this mutation and forcing a cache miss on the subject frame (by clearing
`doc.fills` immediately before it) leaves this specific assertion green. **The
gate's own doc comment claims a cache miss "would show up here immediately as
a per-fill allocation" — that claim does not hold for this mechanism.** It is
`T4c`'s direct assertion (materialisation happens at `apply()` time, not
`_drawFill` time) that actually carries this criterion, not the allocation
gate's buffer-capacity read. Recorded so a future task does not lean on the
allocation gate for a claim it cannot make.

### Criterion 2 — 10,000 entities, fills on, vertices backend, under 16.67 ms

**MEASURED, UNEVALUABLE.** See fact 3 above. Task 16's run:

```
R2 (10000) frames=243
  build  p50=9.12ms p95=11.18ms max=201.24ms            [CONTAMINATED]
  raster p50=5.00ms p95=6.67ms max=80.99ms              [CONTAMINATED]
  fills=18 skippedFills=0
  backend=vertices triangles=207343 drawVerticesCalls=1
```

Both numbers clear the threshold by a wide margin. This note records the
number and does not mark the row passed, because macOS Low Power Mode was on
for the entire session that produced it and this project has twice measured
what that contamination is worth (Plan 3d: ~24% uniform on raster and build;
CPU-bound paths run 23–40% faster with it off) — a margin this row's numbers
do not obviously survive being told apart from. **What it implies for 3f:**
any plan that inherits a timing-sensitive criterion from device rows taken in
this session must re-take them with Low Power Mode confirmed off before
treating the number as clean, exactly as Plan 3d's own note had to be
re-measured after Plan 3c's contamination was discovered.

### Criterion 3 — a fill's cost in `canvasCalls` on the vertices backend, zero

Task 16, all four device transcripts:

| run | backend | FILLS | canvasCalls |
|---|---|---|---|
| 1 | canvas | true | 50,969 |
| 2 | vertices | true | **0** |
| 3 | canvas | true | 54,381 |
| 4 | vertices | true | **0** |
| 5 | canvas | false | 50,893 |
| 6 | vertices | false | **0** |

Every vertices row reads `canvasCalls=0` regardless of whether fills are
present — a fill costs the vertices backend nothing in `canvasCalls` because
nothing about a fill routes through `CanvasDrawSink` on that backend at all.
This is a structural fact (`fillPolygon`/`fillCircle` are handled entirely
inside `VerticesDrawSink`, with no fallback path the way `text` has one), not
a timing measurement, so it is not marked contaminated.

**PASS.**

### Criterion 4 — ink agreement, opaque fills

Task 14's fix round (the amended `fillComparisonDoc`, a pentagon, a circle
and a concave L-tromino pivoted at its convex tip and scaled 3×, so the fixture
both clears the non-vacuity floor and gives a real triangulation mutant real
margin to be caught by):

```
UNMUTATED CANVAS=174135 VERTICES=174130 STRAY=0 UNCOVERED=0
```

`canvasInkPixels = 174,135`, clearing the 4,000-pixel non-vacuity floor by
close to two orders of magnitude. `strayVerticesPixels / canvasInkPixels =
0.0000%` and `uncoveredCanvasPixels / canvasInkPixels = 0.0000%`, both inside
the ≤1% ceiling with room to spare. Re-running the round's own T14a mutation
(fan from vertex 0) against this exact fixture: `STRAY=7744`, `7744/174135 =
4.45%` — clears the 1% ceiling by roughly 4.4× rather than by a coin flip,
which is the property the fix round exists to guarantee (the first attempt's
fixture cleared the ceiling by a margin of 0.02 percentage points, a
measurement noise-level result the coordinator rejected).

**PASS.**

### Criterion 5 — translucent seam

See fact 4 above in full. **The routing rule does not fire, and fills
continue to batch unchanged — that half is PASS.** The mode-2 mechanism
itself is **OPEN on Impeller/GPU**, not evaluable by anything this repository
can run today, and this note states that rather than reading the 0.000% as
proof of absence.

### Criterion 6 — `skippedFillCount` on the rig corpus, zero

Task 16, all four `FILLS=true` runs: `skippedFills=0` in every one — the two
device rows at 10,000 entities (canvas and vertices) and the two at 50,000.
The corpus's fill placement corridor (derived from replaying R2's own
pan/zoom script — 120 pan steps, `Offset(-7,-3)`, zoom anchor `(800,600)`,
factors 1.03/0.97) was purpose-built after a real bug was found mid-task: a
uniform scatter or a fixed-point cluster both missed R2's actual measurement
window, which sits well away from the fit's initial centre after 120 pan
steps move it by `(+3228, -1355)` world units.

**PASS.**

### Criterion 7 — a malformed fill in a loaded document

Task 8's five `validate()` codes — `fillBoundaryMissing`,
`fillBoundaryNotFillable`, `fillBoundaryNotClosed`, `fillBoundaryForeignOwner`,
`fillDrawOrderInverted` — each deleted and re-run today, each time inside one
shell call (delete the block, run the suite, restore, diff clean). Each
deletion failed **exactly one** named test and no other:

| deleted check | failing test | other fill tests failing |
|---|---|---|
| `fillBoundaryMissing` | `a fill naming nothing is reported` | 0 |
| `fillBoundaryNotFillable` | `a fill on a text entity is reported as not fillable` | 0 |
| `fillBoundaryNotClosed` | `a fill on an open polyline is reported as not closed` | 0 |
| `fillBoundaryForeignOwner` | `a fill in a different owner than its boundary is reported` | 0 |
| `fillDrawOrderInverted` | `an inverted pair is reported and nothing is changed` | 0 |

The "0 other tests failing" column is the property Task 8's fix round exists
to guarantee: the round-1 fixtures allocated the fill's handle *after* the
boundary's, so `fillDrawOrderInverted` silently fired alongside every other
fixture and the isolation was incidental, not real. The fixed fixtures
allocate in the production order (`AddRegionCommand.allocate`'s own order)
and every assertion moved from `contains(...)` to exact list equality — that
discipline still holds today; nothing repairs, none mutates the document.

**PASS.**

### Criterion 8 — triangulation entries after `purge()`

Task 3's keying mutant is the deliverable for this criterion, and it was not
merely re-run today — it was **re-derived against a much larger surface**
than it had at Task 3's own time. In `a21188d`, `FillIndex` had exactly two
callers (its own test file); today it has six production call sites across
both packages (`json_codec.dart`, `commands.dart` twice, `draft_painter.dart`,
`reference_walk.dart`) plus test-file call sites in three more files, all of
which needed patching together for a `geomIndex`-keyed `FillIndex` to even
compile.

**KILLED**, and more broadly than before: `the index survives a purge because
handles do` fails (`Expected: [0, 1, 2] / Actual: null`) when the read side
uses the entity's *current* `geomIndex` rather than the stale write-time
value — confirming the failure mode the design names is "permuted/orphaned,"
not "stale in a way that happens to still work." **Collateral finding, not
itself required by the criterion but worth recording:** the same mutation
also breaks two unrelated, pre-existing tests — `removing a boundary removes
its fill, and undo restores both` and `undo removes both halves and redo
restores the same handles` — because `geomIndex` is not stable across
undo/redo, only handles are. The handle-keying decision protects more of this
plan's surface than its own dedicated test suite advertises.

"Drawing unchanged, byte for byte" reads here as: the exact same `Int32List`
values (`[0, 1, 2]`) that were written before the purge are the values found
after it — not a fresh recomputation that happens to agree, but the identical
stored data, because nothing about the purge touches `FillIndex` at all
(`draft_document.dart`'s own comment: "`fills` is deliberately untouched...
adding an invalidation here would be correct-looking and wrong").

**PASS.**

### Criterion 9 — cache entries after removing every fill's boundary, zero

Task 6's `T6b` (cascade the removal but forget the `dropBoundary` call),
re-run today:

```
Expected: <0>
  Actual: <1>
```

`entryCount` is what catches this — entity liveness alone (`slotOf(...)`
returning null for both halves) stays green under this mutation, exactly as
Task 6's report warned it would; it is the direct `FillIndex.entryCount`
assertion that proves the triangulation entry is actually gone, not merely
that the entities that used to reference it are.

**PASS.**

### Criterion 10 — load-time triangulation cost

```
$ flutter test test/invariants/paint_allocation_test.dart
LOAD fills=5000 elapsed=66ms
```

Re-run today on `fillHeavyCorpus()` (5,000 fills, `fraction: 1.0`, every
boundary a region) — `DraftDocumentCodec.decodeString` on the encoded JSON,
wall-clock via `Stopwatch`. Task 16's own run read `68ms`; today's `66ms` is
consistent within session-to-session variance and is not itself a device
frame-timing row (it runs inside `flutter test`, not `flutter drive`), so it
carries no Low Power Mode contamination mark, though the machine's overall
clock speed is still whatever Low Power Mode leaves it at. **No threshold is
declared for this row**, per the brief's own instruction; it is recorded as
the cost eager materialisation owes, and it has to land somewhere.

**MEASURED AND RECORDED.**

### Criterion 11 — the mutation log

56 mutants accounted for across Tasks 1–15's own named mutations plus the
five cross-task mutants this task's brief names as belonging to no single
task. 52 killed outright on today's tree, 2 proven equivalent mutants (T2c,
T5d — both argued formally in the log, not merely asserted), 2 documented
coverage gaps with the argument given (T9c; cross-task mutant #4). One
additional, unscheduled finding: a mutation that **survived** at Task 9's own
time (the oracle at `reference_query.dart:210`) is **now killed**, because
Task 10's `_regionFill()` corpus fixture — added one task later, for an
unrelated reason — closed exactly the gap Task 9's report recorded and left
open. Full detail: [`plan-3e-mutation-log.md`](plan-3e-mutation-log.md).

**PASS.**

---

## Nine plan defects found and corrected during execution

All nine share one root cause: **an API written from memory rather than
looked up.** None changed what got built; all cost implementer time
re-deriving the real signature from the tree.

1. `JsonCodec.save`/`JsonCodec.load` — the real class is `DraftDocumentCodec`,
   with `encode`/`decode`/`encodeToString`/`decodeString`. Named in at least
   three separate briefs' Step-1 snippets (Tasks 7, 8, 16) before being
   corrected each time.
2. `GroupNode(handle: ..., parent: ...)` missing the required `transform` and
   `children` fields (Task 8).
3. `CommandDispatcher.execute` assumed to return a `CommandResult`; it is
   `void` in this codebase, and the established pattern for observing
   `touched` synchronously is `onAfterMutate` (Task 5).
4. `CanvasDrawSink._popTransform()`, which does not exist — every other
   primitive pushes the transform once per residual and lets `endResidual()`
   pop it once; there is no per-op pop anywhere in the file (Task 11).
5. `index.boxOfLeaf`/`index.dirty` called on a `SpatialIndex` receiver; both
   are members of `ContainerIndex`, reached via `SpatialIndex.rootIndex`
   (Task 9).
6. `expectPainterSupersetOfReference(doc)` called with one argument; the real
   helper takes `(painter ops, reference ops, viewport, {edgeBandPx})` (Task
   13).
7. `SpyCanvas.lastPaintStyle`/`drawPathCount`, which do not exist — the real
   API is `spy.named('drawPath')`/`.paintingStyle`/`.length` (Task 11).
8. The ear-clipping code, transcribed verbatim from the brief's own Step 3,
   failed its own Step 4 test: the bow-tie self-intersection fixture returned
   two triangles covering the whole square instead of empty, because the
   "no ear anywhere" stall the brief's comment relies on cannot fire for a
   self-intersection that crosses through edges the clipper never diagonals
   across. Fixed with an explicit upfront proper-crossing check (Task 2).
9. The instruction "T14a must red both backends" contradicted the design's
   own architecture: `CanvasDrawSink.fillPolygon` never reads the
   triangulation at all (it fills a `Path` by Skia's own winding rule), so no
   fixture at any size can make the canvas backend sensitive to a
   triangulation-only mutant. Reported rather than force-fit (Task 14).

---

## Deferred minors, triaged

- **`GeometryStore.peek`'s doc comment states an aliasing hazard that every
  write path forecloses.** Confirmed directly (Task 5): `GeometryStore.replace`
  always builds a fresh `GeometryPayload` with fresh `Float64List`s rather
  than mutating a stored object's arrays in place, and `grep -rn '\.coords\['
  lib/` shows every hit in this codebase is a read. The comment describes a
  real hazard in the abstract (a future in-place vertex-drag optimisation
  would reintroduce it) but no reachable code path today exercises it — this
  is also **why T5d is a proven equivalent mutant, not a test gap.** Leave the
  comment; it is forward-looking documentation, not a stale claim about
  today's code. No action needed unless a future task adds an in-place write.
- **`draft_document.dart:266-267`'s comment justifies `read` over `peek`
  imprecisely.** Not independently re-verified in this task beyond confirming
  the surrounding code still reads as Task 9 described it. Left for whoever
  next edits `_boundsOfContainer` to tighten, since it is a comment-accuracy
  issue with no behavioural weight.
- **`fill_seam_test`'s probe 2 hardcodes an exact colour constant**
  (`153,178,229,255`, the Porter-Duff composite of `0x3366CC` at alpha `0x80`
  over white). This is a legitimate, derived-and-checked constant (Task 15's
  report shows the arithmetic), not a magic number, but it will need
  recomputing by hand if the fixture's colours or alpha ever change. No action
  needed now.
- **Task 16's placement corridor is coupled to today's pan/zoom script
  constants** (120 steps, `Offset(-7,-3)`, zoom anchor `(800,600)`, factors
  1.03/0.97). If `measurement_rig.dart`'s script changes, the corpus's fill
  placement could silently under-cover the measured window again — the only
  safety net is the `fills=`/`skippedFills=` printed line itself, the same
  net Task 16 relies on for the `FILLS` define generally. Recorded, not
  fixed, since strengthening it is outside this task's scope and outside
  Task 16's stated scope too.

---

## Open items after the final fix wave

The whole-branch review's three findings were fixed on the branch (ledger:
`.superpowers/sdd/2026-08-21-jet-cad-2d-plan-3e-fills/final-fix-report.md`).
Two things it surfaced are recorded here rather than changed:

- **A fill ignores its boundary's `EntityFlags.invisible`.** Neither
  `DraftPainter._drawFill` nor `referenceWalk`'s fill case consults the
  boundary entity's flags, so hiding an outline leaves its fill painted, with
  no outline around it. Both backends and the oracle agree, so no differential
  or golden row fires, and the spec is silent on what visibility means for an
  entity that borrows another's geometry. **Recorded, not fixed** — deciding it
  is a spec question (does a fill follow its boundary's visibility, or carry
  its own?), and answering it in a fix wave would be inventing policy.
- **The differential covers the triangulation's *freshness*, not the ear
  clipper itself.** `referenceWalk` now derives a fill's triangulation from the
  boundary's own points instead of reading `doc.fills.trianglesFor`, which is
  what the painter reads — so a stale, missing or wrong cache entry is a
  divergence rather than something both sides agree on. What both sides still
  share is `triangulateSimplePolygon`: a defect inside the clipper appears
  identically in painter and oracle and no differential row can see it.
  `packages/jet_cad_2d/test/geometry/triangulate_test.dart` is the only cover
  for that, and this carve-out is stated at the shared call in
  `reference_walk.dart` as well.

---

## `CLAUDE.md`

**Not amended.** Every non-negotiable this plan measured against still
describes this work:

- The frame path allocates nothing per entity in steady state (criterion 1,
  PASS) and O(1) per flush — fills add no new per-entity allocation and no
  new per-flush object.
- Draw order is ascending handle value, stable across undo, save, load and
  purge — `AddRegionCommand`'s fill-before-boundary handle ordering and
  criterion 8's purge survival both hold this exactly.
- Geometric decisions use `Tolerance`; stored-value comparisons are exact
  `==` — the triangulator's closedness check, `_isEar`'s containment test,
  and `_hasSelfIntersection`'s proper-crossing test are all exact comparisons
  by design (Task 2's report), and `boundaryHandleOf`'s `Handle` round trip
  through a `double` is exact by construction.

No criterion here needed the rule amended to pass, and none is recorded as
failing because the rule does not describe the work — the precedent Plan 3d
set for criterion 7 does not apply to anything in this plan.

---

## What this implies for Plan 3f

- **Any timing-sensitive criterion 3f inherits from this session's device
  rows must be re-taken with Low Power Mode confirmed off first.** Criterion
  2 here is the second plan in a row (after Plan 3d's initial Plan 3c
  contamination) to be unable to close a timing criterion cleanly for this
  reason. Check `pmset -g | grep lowpowermode` before, not after.
- **Permitted divergence 5 (overlapping translucent strokes double-blending
  on a triangle soup) is now live**, per Plan 3d's own note — 3e's translucent
  fills are exactly the case that makes it reachable. Task 15 measured the
  *seam* question and found the routing rule does not fire on the instrument
  available; it did **not** measure divergence 5 itself (opaque strokes
  overlapping a translucent fill, rather than a fill's own internal
  triangulation seam). That is a distinct, still-open question for whoever
  next builds a fixture with both a translucent fill and an overlapping
  stroke.
- **The mode-2 seam question needs a GPU-backed instrument to close, not
  another software-Skia measurement.** `flutter_test`'s picture-capture path
  is structurally blind to partial-coverage antialiasing on `drawVertices`;
  closing this needs either `flutter drive`'s real Impeller path with a pixel
  probe, or an external tool that can inspect a GPU-rendered frame.
- **The allocation gate's `debugCapacityVertices` mechanism cannot see a
  non-buffer heap allocation.** A "lazy populate" style defect on any future
  frame-path cache would need either a genuine VM allocation-profile
  mechanism (like `packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart`,
  not currently available to the Flutter-side test suite) or a
  command-time-materialisation assertion in the style of `T4c`, not a buffer
  capacity read.
