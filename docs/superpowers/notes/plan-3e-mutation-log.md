# Plan 3e mutation log — fills

Every mutant this plan named, from Tasks 1–15's own per-task reports, **re-run
on today's merged code** (`main` at `f0ea51e`, the commit before this task's
own), plus the five cross-task mutants Task 17's brief names as belonging to
no single task. Every mutation used the `cp`/`trap` harness inside one shell
call — mutate, test, restore — and **never `git checkout`** to revert one, per
this plan's own non-negotiable. `git status --porcelain` was read after every
restore and showed no residual diff in every case below.

**Verdict: 56 mutants accounted for. 52 killed, 4 recorded as not killable —
2 proven equivalent mutants, 2 documented coverage gaps with the argument
given.** One additional finding, not itself a new mutant: a mutation that
**survived at Task 9's own time is now killed**, because Task 10's `_regionFill`
corpus fixture closed the gap Task 9 recorded. Task 15's forced-seam mutation
and its permanent regression test (`drawvertices_antialiasing_test.dart`) are
counted once, in Part 1.

| Category | Count |
|---|---|
| Killed, re-confirmed on today's tree | 52 |
| Equivalent mutants (proven, not fixture gaps) | 2 — T2c, T5d |
| Documented coverage gaps (real survivors, argued) | 2 — T9c, cross-task #4 |
| **Total accounted for** | **56** |

**"56" counts verification runs, not 56 distinct code mutations.** Cross-task
mutant #1 ("key the cache by `geomIndex`") is the *same* mutation as Task 3's
own "keying" row — re-verified here against a larger call-site surface than
Task 3 had, not a second, independent mutant. 55 distinct mutations, one of
them (the keying mutant) verified twice, for 56 verification runs total. The
overlap is disclosed above, not hidden; this line just says plainly what the
headline number counts.

---

## Part 1 — Tasks 1–15's own mutants, re-run today

### Task 1 — `EntityKind.fill`

| # | mutation | verdict | killed by |
|---|---|---|---|
| T1a | insert `fill` first in the enum instead of appending | **KILLED** | `fill is the last EntityKind, and its ordinal is stable` — `Expected: EntityKind.fill / Actual: EntityKind.attrib` |

### Task 2 — the triangulator

| # | mutation | verdict | killed by |
|---|---|---|---|
| T2a | drop winding normalisation | **KILLED** | `a clockwise loop is normalised, not rejected` — exactly this one fixture, none other |
| T2b | emit a fan instead of clipping ears | **KILLED** | `an L-shape is triangulated...` (400 vs 300) and the pinch fixture |
| T2c | `if (!clipped) break;` instead of `return Int32List(0);` | **SURVIVED — proven equivalent** | the post-loop `if (index.length != 3) return Int32List(0);` unconditionally re-catches the same condition whenever `!clipped` fires (`index.length` is always `>= 4`, hence `!= 3`); `break` and `return` are byte-identical in every reachable execution of this exact code |
| T2d | accept reflex vertices as ears (`area == 0` instead of `area <= 0`) | **KILLED** | the pinch fixture: `Expected: empty / Actual: [2,3,4, 1,2,4, 5,0,1, 1,4,5]` |
| T2e | drop the consecutive-duplicate collapse | **KILLED** | both duplicate-point fixtures |

### Task 3 — `FillIndex`

| # | mutation | verdict | killed by |
|---|---|---|---|
| T3a | `trianglesFor` returns a defensive copy | **KILLED** | `a hit returns the stored list itself, not a copy` |
| T3b | `dropBoundary` forgets the links | **KILLED** | `dropBoundary removes the triangles and every link naming it` |
| T3c | `fillsOf` returns insertion order | **KILLED** | `fillsOf returns every fill naming a boundary, in handle order` |
| keying | the cache keyed by `geomIndex` instead of `Handle` | **KILLED, and re-derived across today's larger surface — see Part 2** | see cross-task mutant #1 |

### Task 4 — `AddRegionCommand`

| # | mutation | verdict | killed by |
|---|---|---|---|
| T4a | allocate the boundary's handle before the fill's | **KILLED** | `the fill gets the lower handle, so it draws underneath` and 3 more |
| T4b | drop the ordering re-check | **KILLED** | `apply refuses an inverted pair rather than drawing it wrong` |
| T4c | don't populate triangles at command time | **KILLED** | `the triangulation is materialised by the command, not by a draw` and the undo/redo test |
| T4d | accept a nearly-closed loop | **KILLED** | `an unfillable boundary is refused before anything is written` |

### Task 5 — `SetEntityGeometryCommand`

| # | mutation | verdict | killed by |
|---|---|---|---|
| T5a | drop dependent fills from `touched` | **KILLED** | `editing a boundary re-triangulates and touches its fills` |
| T5b | do not re-triangulate after the edit | **KILLED** | same test, on triangle count |
| T5c | accept a fill's own geometry as editable | **KILLED** | `it refuses a fill, because a fill's payload is a reference` |
| T5d | inverse reads via `peek` instead of `read` | **SURVIVED — proven equivalent** | `GeometryStore.replace` always builds a fresh `GeometryPayload` with fresh `Float64List`s rather than mutating one in place, so nothing in this codebase writes into a stored payload's arrays; a `peek`-based inverse cannot be observably distinguished from a `read`-based one by any command-level test |

### Task 6 — `RemoveEntityCommand` cascades to fills

| # | mutation | verdict | killed by |
|---|---|---|---|
| T6a | do not cascade, leave the fill orphaned | **KILLED** | `removing a boundary removes its fill, and undo restores both` (`StateError`) |
| T6b | cascade but forget the index (`dropBoundary` not called) | **KILLED** | `entryCount` stays 1 instead of 0 — entity liveness alone stays green, the index-entry assertion is what catches it |
| T6c | removing a fill forgets to unlink it | **KILLED** | `removing a fill alone unlinks it and leaves the boundary drawable` |

### Task 7 — schema 5 and the load-time rebuild

| # | mutation | verdict | killed by |
|---|---|---|---|
| T7a | drop the `_rebuildFills` call | **KILLED** | `load leaves the fill index populated, not empty` |
| T7b | leave `kSchemaVersion` at 4 | **KILLED** | `the schema version is 5, and a v6 document is refused` |

### Task 8 — `validate()`'s five fill codes

Five deletions, each in its own shell call, each restored and diffed
byte-identical before the next ran.

| deleted check | verdict | killed by | other fill tests failing |
|---|---|---|---|
| `fillBoundaryMissing` | **KILLED** | `a fill naming nothing is reported` | 0 |
| `fillBoundaryNotFillable` | **KILLED** | `a fill on a text entity is reported as not fillable` | 0 |
| `fillBoundaryNotClosed` | **KILLED** | `a fill on an open polyline is reported as not closed` | 0 |
| `fillBoundaryForeignOwner` | **KILLED** | `a fill in a different owner than its boundary is reported` | 0 |
| `fillDrawOrderInverted` | **KILLED** | `an inverted pair is reported and nothing is changed` | 0 |

Each deletion failed exactly its own fixture and no other, confirming the
one-fixture-per-code discipline the fix round (Task 8's own report) put in
place still holds on today's tree.

### Task 9 — `entityBounds` and its call sites

| # | mutation | verdict | killed by |
|---|---|---|---|
| T9a | fill always returns `Aabb2.empty()` | **KILLED** | 5 named tests, including the two the fix round added |
| T9b (spatial_index.dart, `_reconcileEntity`) | skip fill resolution at this site | **KILLED** | `an edited boundary moves its fill's indexed box` |
| T9b (container_index.dart, `addLeaf`) | same, at initial build | **KILLED** | `a fresh index resolves a fill to its boundary without any edit` (fix-round test) |
| T9b (draft_document.dart, `_boundsOfContainer`) | same, at `doc.extents` | **KILLED** | `doc.extents finds a fill's boundary by handle, not by walking the tree` (fix-round test) |
| T9c | `read` instead of `peek` in the reconcile hot path | **SURVIVED — documented gap** | correctness is unaffected (`peek`/`read` is an allocation choice) and `query_allocation_test.dart` never invokes `_reconcileEntity` during its measured window (it only queries, never edits, inside the steady-state frame) — a genuine, unclosed blind spot in the allocation gate, not a false reading |
| T9b variant (`reference_query.dart:210`, oracle) | skip fill resolution in the oracle | **NOW KILLED — was SURVIVED at Task 9's own time** | `regionFill entitiesInRect matches brute force over 200 random rects` — Task 10's `_regionFill()` corpus fixture (added one task later) closed exactly the gap Task 9 recorded; re-running today shows the survivor from Task 9's report no longer survives |

### Task 10 — the index stays silent about fills

| # | mutation | verdict | killed by |
|---|---|---|---|
| T10a | give the oracle a fill hit the real index does not produce | **KILLED** | `regionFill pick matches brute force over 200 random points` |
| T10b | plant a fabricated snap centre for a fill and stop re-filtering it (both `container_index.dart`'s `snapCentreOfLeaf` and `spatial_index.dart`'s `_considerSnapCentre` mutated together — a single-function mutation of either alone is masked by the other, exactly as Task 10's report found) | **KILLED** | `a fill manufactures no snap candidate of its own, even away from every real vertex` — the corner-of-the-room test stays green under the same mutation, confirming it is masked by the endpoint tie-break as documented |

### Task 11 — `DrawSink.fillPolygon`/`fillCircle`

| # | mutation | verdict | killed by |
|---|---|---|---|
| T11a | leave `_paint.style` on fill after `fillPolygon` | **KILLED** | `the canvas sink leaves its paint on stroke afterwards` |
| T11b | drop `triangles` from `FillPolygonOp`'s `==` | **KILLED** | `a different triangulation of the same outline is a different op` |
| T11c | draw the polygon unclosed | **KILLED** | `fillPolygon closes the path` |

### Task 12 — `VerticesDrawSink` fills

| # | mutation | verdict | killed by |
|---|---|---|---|
| T12a | route the fill through `_coveredArgb` | **KILLED** | `a fill on a hairline layer keeps full alpha` (only the hairline fixture; the normal-lineweight fixture stays green, confirming the brief's claim) |
| T12b | give the circle fan its own step count (`steps = 32`) | **KILLED** | `a filled circle and its own outline use the same step count` |
| T12c | drop every third triangle (`i += 6`) | **KILLED** | `a fill batches with strokes into one flush, not one call each` and `a polygon fill emits exactly the triangles it was handed` |

### Task 13 — the painter draws fills, and counts the ones it skips

| # | mutation | verdict | killed by |
|---|---|---|---|
| T13a | defer every fill to the end of `paint()` | **KILLED** | `a region draws the fill before its boundary` and `the painter walks fills and the reference walk agrees` |
| T13b | hand `trianglesFor(boundary) ?? Int32List(0)` to the sink instead of skipping | **KILLED** | `an unfillable boundary is skipped and counted, not handed to a sink` |
| T13c | replace every `_skippedFills++;` with a no-op | **KILLED** | same test |
| T13d | drop the `_skippedFills = 0;` reset | **KILLED** | `skippedFillCount is per frame, not a running total` (2 instead of 1) |
| T13e | triangulate the circle boundary instead of fanning it | **KILLED** | `a circle boundary draws a fillCircle, never a triangulated polygon` |

### Task 14 — goldens and the opaque agreement floor

| # | mutation | verdict | killed by |
|---|---|---|---|
| T14a | fan the polygon from vertex 0 instead of ear-clipping | **KILLED on the vertices backend at rungs 1–2, and on the opaque-agreement fixture (7744/174135 = 4.45%, clears the 1% ceiling with real margin); the canvas backend is architecturally immune** — `CanvasDrawSink.fillPolygon` builds a `Path` from `points` and lets `Canvas.drawPath` fill it by Skia's own winding rule, never reading `triangles` at all, so no fixture at any size can make it sensitive to a triangulation-only mutant. This is the same finding Task 14's own report reached; re-confirmed rather than assumed. |
| T14b | skip winding normalisation | **KILLED on both backends, all 3 rungs** | all 6 golden tests |
| T14c | route the fill through `_coveredArgb` (vertices backend) | **KILLED on the vertices backend, all 3 rungs; canvas untouched** | matches T12a's mechanism, re-run against the golden ladder fixture specifically |

### Task 15 — the translucent seam

| # | mutation | verdict | killed by |
|---|---|---|---|
| forced seam (every triangle in `fillPolygon` emitted twice) | **KILLED** | `the translucent seam, measured` — `fraction=1.0` instead of `0.000%` |
| (pinned regression, not a new mutant) | `drawvertices_antialiasing_test.dart` — 2 tests, both green today | confirms `flutter_test`'s software Skia still does not antialias `drawVertices`, so the instrument's own blind spot (recorded in Task 15's addendum) has not silently changed |

---

## Part 2 — the cross-task mutants Task 17's brief names

None of these belong to a single task's own test file. Each was verified by
constructing the exact fixture property the brief names, not by reusing an
existing task's test verbatim — three of the five needed a purpose-built
probe because no existing test exercises that specific property.

### 1. Key the cache by `geomIndex` instead of `Handle`

**Fixture property: purge a document containing fills and draw again.**

Task 3's original mutation (`a21188d`) touched two files, because at the time
`FillIndex` had no other callers. **Re-derived here against today's full
surface** — six call sites across both packages
(`json_codec.dart`, `commands.dart` ×2, `draft_painter.dart`,
`reference_walk.dart`, plus every test call site that had grown since) needed
patching together for the mutation to even compile, which is itself evidence
of how much this decision now protects.

**KILLED.** `the index survives a purge because handles do` fails
(`Expected: [0, 1, 2] / Actual: null`) when the read side uses the entity's
**current** (post-purge) `geomIndex` — the stale write-time key is never
re-attached to anything, so the entry is orphaned rather than merely stale.
**Collateral, and worth recording on its own:** the same mutation also breaks
two *unrelated*, pre-existing named tests — `removing a boundary removes its
fill, and undo restores both` and `undo removes both halves and redo restores
the same handles` — because `geomIndex` is not stable across undo/redo either,
not only across `purge()`. The handle-keying decision protects more ground
than its own test suite advertises.

### 2. Drop dependent fills from `SetEntityGeometryCommand`'s `touched`

**Fixture property: edit a boundary, then pick or cull inside the
new-but-outside-the-old region.**

Task 5's own T5a test reads the indexed box directly
(`index.rootIndex.boxOfLeaf(slot)`), not through a query. This is a materially
different, stronger fixture: a real `forEachInRect` cull.

Built a probe (`AddRegionCommand.allocate` a 10×10 room, build a
`SpatialIndex` **before** the edit so the edit drives its incremental
`onAfterMutate` reconcile, grow the boundary to 100×100, then
`forEachInRect` a rect at `(45,45)–(55,55)` — inside the new region, outside
the old one).

**KILLED.** Control: `sawFill=true`. Under the mutation (`touched: {handle}`,
dropping the dependents): `sawFill=false` — the fill's stale, small box never
grows with its boundary, so the broad-phase cull misses it in exactly the
region the brief names.

### 3. Make `AddRegionCommand` two composed commands

**Fixture property: assert no observer sees a fill whose boundary is
missing.**

`AddRegionCommand.apply` is one atomic mutation returning one `CommandResult`,
so `CommandDispatcher.execute` notifies `onAfterMutate` exactly once, after
both halves already exist. `CommandTarget` (what `apply` receives) has no
notification hook of its own, so the "two composed commands" alternative
can only be built as two separate top-level `execute()` calls — which is
exactly what a less careful implementation would do.

Built a probe: an observer hooked to `onAfterMutate` that checks, after every
mutation, whether any live fill's boundary handle fails to resolve.

**KILLED, by construction.** The real `AddRegionCommand`: `sawGap=false`. The
same two `EntityRecord`s added via two separate `AddEntityCommand.execute()`
calls (fill first, boundary second — the natural order): `sawGap=true`, since
the observer callback after the first `execute()` sees a live fill entity
whose boundary does not exist yet.

### 4. Populate the cache lazily on first draw

**Fixture property: the allocation gate, on a corpus with fills.**

Mutated `DraftPainter._drawFill` to compute `triangulationFor(...)` and write
it into `document.fills` on a cache miss, instead of skipping and counting.
Task 16's paint_allocation_test.dart's own doc comment claims "a cache miss on
the frame path would show up here immediately as a per-fill allocation."

**SURVIVED — a real, documented gap, not a fabricated pass.** Cleared
`doc.fills` immediately before the gate's subject (post-warm-up) frame to
force exactly the miss this mutation exists to make interesting, then ran the
gate's `debugCapacityVertices`-before/after comparison: it stayed green
under the mutation. Root cause: `debugCapacityVertices` measures only
`VerticesDrawSink`'s own vertex-buffer capacity, and the warm-up frames had
already sized that buffer to the corpus's worst case (fills included, since
the buffer is a doubling reserve that never shrinks) — a freshly computed
`Int32List` triangulation lands on the general Dart heap, which this specific
gate mechanism was never built to see. **Task 16's claim, read literally as
"this gate would catch a lazy-populate mutation," does not hold** — the
mechanism that actually proves eager, command-time population is Task 4's
`T4c` (`the triangulation is materialised by the command, not by a draw`,
re-confirmed killed above), not the allocation gate. Recorded as a deferred
finding for the note below rather than argued away.

### 5. Let the codec skip `_rebuildFills`

**Fixture property: the same gate, after a load.**

Built a probe alongside mutant 4's: encode the same 200-fill corpus, decode
it with Task 7's `T7a` mutation applied (the `_rebuildFills` call removed),
and run the same gate's frame on the **reloaded** document.

**KILLED — but not by the buffer-capacity assertion.** `painter.fillCount`
stays `> 0` and `debugCapacityVertices` stays unchanged (a skip, like a miss,
allocates nothing in the sink's own buffer — same mechanism gap as mutant 4),
but the gate's own **`expect(painter.skippedFillCount, 0)`** assertion goes
red: every polyline fill in the reloaded, never-rebuilt document is silently
skipped, since `FillIndex` carries no triangles for any of them. "The same
gate" is correct as stated in the brief — it is the `skippedFillCount`
assertion inside that gate, not the allocation assertion, that catches this
one.

---

## Method notes

- Every mutation ran inside one shell call: `cp` the target file(s) aside,
  apply the edit (`perl`, `sed`, or a small `python3` string-replace script
  when the edit needed to be exact-matched against surrounding context),
  run the narrowest test file that should catch it, then `cp` the backup
  back — **never `git checkout`**. `git status --porcelain` was clean after
  every single mutation in this log.
- The keying mutant (Part 2, #1) required patching six production files plus
  four test files together to keep the tree compiling; every patch that
  failed to compile printed `Failed to load`, not a named test failure, and
  was **not** counted as a kill — this plan's own recorded history (Task 3's
  two discarded controller attempts, Task 8's discarded zsh-array attempt)
  says to assume the harness is wrong until a named test failure proves
  otherwise, and that discipline held here too: one early version of the
  keying mutant's purge test read the *stale* write-time `geomIndex` on both
  the write and the read side, which made the mutation look like it survived
  when it had not actually been exercised — caught before being recorded,
  not after.
- Cross-task mutants 2–5 needed purpose-built probes because the brief's
  fixture properties are, in three of four cases, materially different from
  what any existing named test checks (a direct index-box read is not a
  cull query; an atomicity property has no existing observer test; a
  frame-path allocation claim was untested against the specific "lazily
  populate on miss" shape). Every probe was deleted after use — none is
  committed.
