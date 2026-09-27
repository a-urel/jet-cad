# Spec 10 (rooms and area), revision 1: independent review

**Reviewed:** `docs/superpowers/specs/2026-09-26-rooms-design.md` at `5015828`
on `spec-10/rooms` (worktree `.claude/worktrees/rooms`, left untouched and
clean). **Against:** the decision record `10-brainstorm-decisions.md`, the
spike note and the spike's code at `spike/10-rooms` `d30bce5`, the engine at
`418d4c7` (`regeneration.dart`, `parametric_system.dart`), 06/07/08 specs,
`roadmap/10`, `CLAUDE.md`.

**Runs made for this review** (a detached worktree of `spike/10-rooms`,
`.claude/worktrees/spec10-review`, since removed), each
`cd apps/floor_planner && CI=true flutter test --no-pub …`:

- `spec10r_probe_test.dart` (my probes over the spike's tracer and the real
  07 walls; log `scratchpad/spec10r-probe-run1.log`), `00:00 +5: All tests
  passed!`:
  ```
  probe sample Hall: Traced area=21996100.0 ring=4 holes=0
  probe sample Bedroom 1: Traced area=8450100.0 ring=4 holes=0
  probe sample Bedroom 2: Traced area=8413200.0 ring=4 holes=0
  probe sample Kitchen: Traced area=13972200.0 ring=4 holes=0
  probe sample Bath: Traced area=13366100.0 ring=4 holes=0
  probe sample Living: Traced area=21897500.0 ring=4 holes=1
  probe sample Dining: Traced area=23043600.0 ring=4 holes=0
  probe sample total: 111138800.0
  probe pulled150 left: Traced area=29265000.0 ring=8 holes=0
  probe pulled150 right: Traced area=29265000.0 ring=8 holes=0
  probe JM: Traced area=20987500.0 ring=4 holes=0 ring=[[250.0,200.0], [6000.0,200.0], [6000.0,3850.0], [250.0,3850.0]]
  probe TR: Traced area=32766900.233162627 ring=3 holes=1; by hand 32766900.233162623
  probe FB before: Traced area=18703300.0 ring=6 holes=0 diag [] W=18
  probe FB after: Traced area=18708300.0 ring=8 holes=0 diag [wall.fallback[18], wall.fallback[42]] ring=[[0.0,0.0], [0.0,-200.0], [-450.0,-200.0], [-450.0,-2950.0], [2987.0,-2950.0], [2987.0,2950.0], [50.0,2950.0], [50.0,-200.0]]
  ```
- the spec's M-10b (least **absolute** area) fired on the spike's tracer with
  a `cp` backup, the whole `test/spike_rooms` suite run, restored with `cp`,
  `diff` and `git diff --quiet` clean (log `scratchpad/spec10r-M10b-abs.log`):
  `00:05 +84: All tests passed!` (the spike's 79 plus my 5).

## Verdict

**Ready with amendments.** The architecture holds: the decisions are
honoured, (a)–(d) and (f) are implementable as written against the real
code, the before-view diagnosis is right, the D7 localisation and the D16
no-drift argument survive every counterexample I could build, the frame
path is untouched, and every hand-worked area I recomputed is right except
one. Four major findings must be amended before the plan: one named
mutant is equivalent (the exit gate cannot be met as written), one expected
area is wrong (and lands on a rounding tie), `room.shared` needs a view API
the spec does not list, and the trigger's cost bound understates what it
rebuilds. The rest are minor precision and plan-readiness items.

**Counts:** blocking 0, major 4, minor 15.

## What I checked and found sound

- **Fidelity.** Decisions 1–25 are honoured with the stated supersessions
  (20>1, 24>9, 25>13/23). No `[spec ruling]` overturns a decision; two sit
  at the edge of latitude (S-15 R-3 "thin", S-16 R-28 seven rooms).
- **(a) text, (b) attributes.** `_plan` today adds records with
  `draftRecord(…, color:)` only and matches TEXT by `(kind, ordinal)` with
  `SetEntityGeometryCommand` only (regeneration.dart 276-298); no existing
  client or test generates TEXT or ATTRIB through the plain form (grep over
  `apps/` and `packages/`), so R-15 breaks nothing. `SetEntityTextCommand`
  exists with the signature used (commands.dart 235-265) and is a planned
  command the D6 guard never sees. `_recordOf` is straightforward.
- **(c) page.** `PageComponent` has value `==`; the Page panel and
  `startupPlan` both set the page with `SetComponentCommand<PageComponent>`
  through the dispatcher (`page_panel.dart:95-96`, `startup_plan.dart:168`),
  so the expander sees it once rooms exist.
- **(d) dissolve.** `lost` is computed from the after-survey
  (regeneration.dart 568-571), so a dissolving room is never in it and must
  plan its own detach, exactly as D15 says; `_subtreeRemoval` works over any
  survey's children; the capability summary: only `components` is skipped by
  the index and tile cache (`spatial_index.dart:2611`,
  `tile_cache.dart:1882`), so `geometry` is enough, as for 08's cascade.
- **The before-view claim is right.** `ParametricView.paramsOf` reads
  `_target.components` live and `toWorld` reads the live tree
  (parametric_system.dart 162-166); `_run` applies `inner` right after the
  before-survey (544-545). Only `before.reach` / `neighboursOf` are true
  before-values today. Every `paramsOf<U>` call in the app names a
  registered parametric type (grep), so snapshotting only the registered
  component changes no current answer.
- **(e) completeness.** I tried to make a room drift past the trigger:
  the FB two-hop (covered by `K`'s neighbours, confirmed by the run above:
  W reports `wall.fallback` only after the edit, and the notch
  `(0,0),(0,−200),(50,−200)` opens); a three-hop through a node lobe or the
  short-wall fallback (a band reads its neighbours' **parameters**, never
  their bands: `_outlineOf` → `outline(self, others)`, wall.dart 122-130);
  a separator moved far (before box); a deleted column (lost ⇒ seed, before
  box); a re-parented or detached wall (Ruling 06-4 seeds it); an island
  added inside the face (after box inside `box(F)`); a page change (page
  seeds). None drifts. The proof's one inherited edge (07's node cluster
  spread) is stated. **The rule is complete; it is its cost that is
  overstated (S-4).**
- **Frame path.** The tint is one more fill drawn by `_drawFill` with the
  painter's reused buffers; the dash path already avoids per-leaf closures
  (`draft_painter.dart` 640-651); previews paint from cached payloads.
  Nothing new per frame.
- **(f).** `ReservedHandles` fills 1–5 and `firstFree` is 16
  (style.dart 104-114); the codec saves every linetype record and loads them
  with `raiseTo` only (json_codec.dart 42-43, 190-199); no validation reads
  an entity's linetype handle, so a missing DASHED record refuses nothing.
- **Hand areas recomputed** (arithmetic mine, each also confirmed by the
  run above):
  - sample plan: 21,996,100 + 8,450,100 + 8,413,200 + 13,972,200 +
    13,366,100 + 21,897,500 + 23,043,600 = **111,138,800** ✓, and
    111,298,800 − 160,000 = 111,138,800 ✓; every label string ✓ and ≥
    0.0011 m² from a tie ✓;
  - **JM**: left of (0,0)→(6000,0) is +y (wall.dart's `Justification`
    "looking from start to end"), so faces y 200, x 6,000, y 3,850, x 250;
    5,750 × 3,650 = **20,987,500** ✓; mitre limit `mitreLimit / 2 ×` the
    thicker wall = 500 at the (0,0) node ✓;
  - **TR**: inner diagonal x + 2y = 12,000 − 100√5; L_y = 5,850 − 50√5;
    L_y² = 34,235,000 − 585,000√5 = 32,926,900.233; less 160,000 =
    **32,766,900.23** ✓; the column clears the diagonal (x + 2y = 11,600 <
    11,776.4 at its far corner) ✓;
  - **FB**: 3,437 × 5,900 − 500 × 3,150 = **18,703,300** ✓; the acute
    corner at s = (50 + 200 cos 5°) / sin 5° = 2,859.7 mm > 2,000 ✓;
    notch ½ × 50 × 200 = 5,000 → **18,708,300** ✓;
  - the column 400 × 400 at x 23,500–23,900, y 13,800–14,200 inside Living
    and clear of the door approach (y 12,460) ✓; 581 = 549 + 7 × 4 + 1 + 3
    ✓ (a wall with no opening generates fill, boundary and centreline).

## Findings

### S-1 (major) — M-10b as redefined is an equivalent mutant

**Where:** Named mutants, "From the roadmap", row M-10b ("the outer ring
chosen as the cycle of least **absolute** area … `RT1`, `RT2`; spike:
`+8 −71`").

**Evidence.** A negative cycle is a component's outer contour; if it holds
the seed it encloses the seed's positive face, so its |area| is larger, and
the least-|area| cycle holding the seed is always the least positive one.
Run: the spike's tracer with exactly that selection (`if (areas[c] == 0)
continue; … areas[c].abs() < areas[outer].abs()`), whole `test/spike_rooms`
suite (sample plan at six placements, the mixed-direction L, the courtyard):
`00:05 +84: All tests passed!`. The quoted `+8 −71` is the spike's
**different** mutant (`spike10-mutate.py`: any-sign cycle, least **signed**
area, so the most negative contour wins). Exit gate 16 ("every named mutant
is killed") cannot be met as written.

**Amendment.** Define M-10b as the spike's: "cycles of either sign
accepted, the least **signed** area wins (the outer contour of the
building is taken as the room)", killed by `RT1`, `RT2`. Record why the
roadmap's shoelace-sign mutant has no meaning here (face orientation is
structural in the half-edge walk).

### S-2 (major) — the "partition pulled back 150 mm" area is wrong, and its label is a tie

**Where:** D8's table, row 4 ("both survive, one face of 29.64 m²
(7,800 × 3,800)"); `RD5`; exit gate 5 by reference.

**Evidence.** The partition (100 thick) keeps its T at the north end
(spike fixture: `movedWall(plan, plan.walls[4], s: (3000, 150))`), so its
band, 100 × (3,900 − 150), stands inside the merged face and the ring walks
around it: 29,640,000 − 375,000 = **29,265,000 mm²**. Run: `probe
pulled150 left/right: Traced area=29265000.0 ring=8`. (The 29,640,000 of
`RS4`/c4 is right: there the partition lies wholly inside the west band.)
29.265 m² is also exactly on a two-decimal tie, against D11's rule.

**Amendment.** Correct the row. Either pull back 160 mm (a 60 mm gap):
29,640,000 − 100 × 3,740 = 29,266,000, `29.27 m²`, 0.001 from the tie; or
keep 150 and assert the area, never the label, in `RD5`.

### S-3 (major) — `room.shared` needs a view API the spec does not list

**Where:** D22 (`room.shared`, "the lower room reports each higher room
whose seed lies inside its face"); `DG1`; M-10share2; the engine list.

**Evidence.** `ParametricView` offers `paramsOf`, `toWorld`, `neighbours`,
`referrers` (parametric_system.dart 149-178) and the spec adds `page`,
`placedIn`, `placeBoxOf`. A room has empty reach (no neighbours), no
references (no referrers), and is a reader, not a contributor (`placedIn`
never returns it; D16 forbids both roles). `diagnose(view, self)` therefore
has no way to find another room. (The tool's occupied check, D19, and the
naming rule use the document and are fine.)

**Amendment.** Add a generic, survey-backed
`List<Handle> ParametricView.objectsOf<U extends Component>()` (ascending
live objects carrying `U`), list it among the engine changes and in the
06-guarantees table, and pin it with an engine client test. Alternatively
state that `room.shared` is computed by an app-side pass outside
`diagnose`, but then say where it is surfaced.

### S-4 (major) — the trigger's cost bound understates what it rebuilds

**Where:** D16.2 (`L` over every contributor in `K`), D16.6 ("for a wall
move, the rooms on both sides of it and of its joint partners"), `RK2`.

**Evidence.** `K` holds every reach neighbour of a seed whether or not its
band changed, and each adds its **whole** band box. Sample plan, moving P5
(the kitchen/bath split, (21,500, 8,125)→(21,500, 11,500)) by 10 mm: its
reach neighbours are E1 (centreline y 8,125, overlap 2e-6 > 1e-9 on both
axes) and P3 (y 11,500). A T butt changes only the stem's band, so E1 and
P3 are unchanged, yet E1's box ([12,000, 26,000] × [8,000, 8,250]) touches
the Hall's read box (from y 8,248) and P3's box touches Living's and
Dining's (from y 11,558): **5 of 7 rooms rebuild, 2 change**. In general
every partition move T-joined to a long exterior wall rebuilds every room
along that wall, O(N) per edit, unbounded in N; at the corpus's 23°
placement every band box is an inflated rectangle (E1's becomes ≈ 12,755 ×
5,602 mm) and the rebuild set grows further. The trigger also computes
`2 × |K|` place boxes and their neighbour searches on every wall edit even
when the document has no room.

**Amendment.** (1) Put a `k ∈ K` into `L` only when its input changed:
compare its before and after inputs bit for bit (both are computed anyway
for its place boxes). D16.4's proof already uses only changed `k`, so it
stands unchanged; state that. (2) Skip `L` altogether when no live reader
exists (an O(1) check). (3) Restate the bound honestly ("the rooms whose
read box touches the box of a contributor whose input changed"). (4) Run
`RK2` also at the corpus rotation and on a layout with long exterior walls,
and add an `SD` test that an unchanged neighbour adds nothing (killed by a
mutant that keeps all of `K`).

### S-5 (minor) — the Room tool's hover re-traces everything outside a face

**Where:** D19, hover preview ("recomputed only when the pointer leaves the
cached face"); D7 costs.

**Evidence.** An `Unbounded` point has no cached face, and D7 reaches
`Unbounded` only after growing `B` over every contributor, so each pointer
move outside the building (the usual approach to a click) is a full
O(S log S) trace of the plan.

**Amendment.** Short-circuit to `Unbounded` when the pointer lies outside
the union of all place boxes, and cache the last `Unbounded` (or
`SeedInWall`) verdict against the cache's revision plus a cheap
containment test; extend `TT6` with a hover outside.

### S-6 (minor) — D7's growth loop can fail to terminate

**Where:** D7 step 1 ("until `placedIn(B)` is every contributor").

**Evidence.** A non-finite place box (a file with huge or non-finite
parameters) never touches any `B` (comparisons with NaN are false), so the
loop never sees "every contributor". D2 covers a non-finite seed, not a
non-finite box.

**Amendment.** Define "every contributor" as those with a finite place box
(a non-finite box is treated as `null`: not placed, reported by the owning
type's `diagnose`), and cap the loop at the union box.

### S-7 (minor) — M-10cert is ambiguous and can survive `LZ2`

**Where:** Named mutants, M-10cert ("D7 stops at the first `Traced` face
(no certificate)"); D7 step 3.

**Evidence.** If the mutant skips step 2 but keeps step 3 (trace among
`C = placedIn(box(F) ⊕ m)`), the triangle's column is in `C` and `LZ2`
passes: one certificate round is all `TR` needs.

**Amendment.** Define M-10cert as "return the first `Traced` result"
(steps 2 and 3 skipped), and add a fixture that needs two certificate
rounds (a hole whose own box reaches a second hole beyond `box(F₁)`).

### S-8 (minor) — `PG2` cannot see M-10pagekey as worded

**Where:** `PG2` ("a change outside every key plans nothing"), M-10pagekey.

**Evidence.** Seeding an object whose page key did not change regenerates
identical children: the plan is empty with or without the mutant.

**Amendment.** `PG2` asserts the client's `generate` call count (the
engine clients already count calls) is unchanged by a paper-colour or
grid change.

### S-9 (minor) — `LZ3`'s counter is not named

**Where:** D7 "Pinned by `LZ3` (the traced-segment counter)"; M-10grow.

**Amendment.** Name it (`debugTracedSegments` in `room_trace.dart`,
`@visibleForTesting`, never reset by the library) and state what `LZ3`
pins (an upper bound per rebuild on the sample plan, set from a run).

### S-10 (minor) — the label grip mixes local and world frames

**Where:** D21, the label grip ("the name TEXT's stored insertion point
minus `(0, 0.7 · h_name)`, mapped by `toWorld(room)`"; "`pole = anchor −
label`").

**Evidence.** D10 puts the name `0.7 · h_name` above the anchor in
**world** directions and stores `label` in **local**; subtracting a world
offset from a local point, and a local offset from a world anchor, is wrong
for any rotated or scaled room group (D10's own `RL4` case).

**Amendment.** Map the stored insertion point to world, subtract `(0, 0.7 ·
h_name_world)`, then take anchor and pole back to local:
`pole_local = toLocal(anchor_world) − label`. Run `GR1` under `RL4`'s
transform too.

### S-11 (minor) — the keyhole needs three more words, and `RG2` a seam

**Where:** D9, the tint's shape; `RG2`.

**Evidence.** Unstated: the frame of "rightmost x" (local, where the tint
is stored?); whether "ring" is the growing keyholed ring (the spike's
`keyhole` bridges to it and tests crossings against it and the remaining
holes); and what happens when a hole finds no visible vertex (the spike
leaves the hole out; the spec's chain is silent). `RG2`'s "a forced step 3"
names no fixture or seam: a traced outer ring is simple by construction.

**Amendment.** State the three rules as the spike does them, add a
two-hole fixture (the second hole's view of the ring blocked by the first)
to `RG2`, and name a test seam or a pinched-ring fixture for step 3.

### S-12 (minor) — where the page seeds and the trigger sit in `_run`

**Where:** D14 ("after the seeds are formed"), D16.2.

**Evidence.** `_run` returns early on `seeds.isEmpty && cleanup.isEmpty`
(regeneration.dart 585). A page-only edit touches the root, not an object:
its seeds are empty, so page seeds added after that line never plan.

**Amendment.** Say the page seeds join before the early return, and that
the trigger's after-view is the same view object `_plan` receives (so the
band memo of D4 is shared).

### S-13 (minor) — `SD6`'s "exactly" is not exact

**Where:** D16.6 and `SD6` ("exactly `2 × |K ∩ contributors|` place
boxes").

**Evidence.** An added or deleted contributor has one box, not two; and
when a reader regenerates, the bulk pass calls `placeBox` once per
contributor on top.

**Amendment.** Count "one per `k ∈ K` live before plus one per `k ∈ K`
live after", on a fixture where no reader regenerates, and count the bulk
pass separately. Adjust for S-4 if adopted.

### S-14 (minor) — how the engine forms `stored`

**Where:** D16.2 ("the world box of the coordinates of R's children's
payloads").

**Amendment.** Say it: every `coords` pair of each child's payload
(a fill's payload has none) mapped by `toWorld(R)`, and that it is a box of
points, not of extents (a generic reader with arcs or circles must grow it
itself in `readBox`).

### S-15 (minor) — R-3's 0.35 mm is not obviously "thin"

**Where:** D3, R-3; decision 15 ("thin dashed line").

**Evidence.** The only evidence is the test rasteriser (spike finding 4:
"Not checked on a device"), and 0.35 mm is a medium plotting weight.

**Amendment.** Make it Open question 4 (default 0.35) or add it to gate
17's look, so the human confirms "thin" on the real renderers.

### S-16 (minor) — R-28 adds a room decision 16 does not name

**Where:** D23, R-28.

**Evidence.** Decision 16 enumerates six rooms by name and a "Dining
area"; the seventh room is a product choice.

**Amendment.** Keep seven as the default but list it under Open questions
for the human.

### S-17 (minor) — `ensureDashedLinetype` on a document that has a DASHED

**Where:** D3 ("test fixtures through `ensureDashedLinetype(doc)`").

**Evidence.** `TableSection.add` throws `DuplicateTableNameError` on a
case-insensitive name clash and `DuplicateHandleError` on handle 6
(tables.dart `add`).

**Amendment.** Specify: no-op when handle 6 already holds a record; and
what it does when another handle already carries the name (keep it; the
separator still names handle 6 and draws continuous).

### S-18 (minor) — per-test placements

**Where:** Testing, "Tests by area" (`RT2`–`RT8`, `RS6`, `RD1`–`RD8`,
`RG3`).

**Evidence.** Only `RT1`, `RS1`–`RS4`, `RL1` and `LZ1` name placements;
exit gate 2 demands every fixture at every placement. The spike ran all
six for each.

**Amendment.** State the placements per test (all six for the tracer
fixtures; at least origin and corpus-in-own-groups for the relational
edits), so the degenerate-fixture trap is closed by the spec, not the plan.

### S-19 (minor) — small accuracy items

- D9: black at alpha 26 over white is 255 − 26 = 229 = **`#E5E5E5`**, not
  `#E6E6E6`.
- D23: the door at x 23,150–23,850 (P3, u 6,500) is the **bath**/living
  door (x > 21,560 is the Bath), not the kitchen/living one.
- D23: "every one from the real plan with its fifteen openings": Dining and
  Living-with-column come from the spike's rebuilt decision-16 walls, not
  the real plan (spike Q2, "The other fixtures").
- D7 "Pinned by": `LZ2` is "a hole beyond the first growth box `B`", not
  "beyond the first face's box" (the column is inside `box(F)`).
- `RL1` "against 685.786" (the pole's coordinate) and D10 "585.786" (its
  distance) are both right; say which is asserted.

## Plan-readiness summary

With S-1–S-4 amended, an implementer has everything but the small rules in
S-5–S-18. The ones most likely to be guessed wrong if left: S-3 (engine
API), S-10 (grip frames), S-11 (keyhole rules), S-12 (early return).
