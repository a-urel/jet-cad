# Spec 10 (rooms and area), revision 2: independent re-review

**Reviewed:** `docs/superpowers/specs/2026-09-26-rooms-design.md` at `6163da8`
on `spec-10/rooms` (diff `5015828..6163da8`, one file, +482 −150), against
my revision-1 review (`10-spec-review.md`, S-1..S-19), the decision record
(now with decisions 26–28), the engine and render-layer code at `418d4c7`,
and the spike at `d30bce5`. The rooms worktree was not edited; it is clean.

**Runs made for this re-review:** a detached worktree of `spike/10-rooms`
(`.claude/worktrees/spec10-review`, removed afterwards), probe file
`spec10r_probe2_test.dart`, `cd apps/floor_planner && CI=true flutter test
--no-pub test/spike_rooms/spec10r_probe2_test.dart` (log
`scratchpad/spec10r-r2-probe-run1.log`), `00:00 +4: All tests passed!`:

```
probe2 pulled160 (1500.0, 2000.0): 29266000.0 -> 29.27
probe2 pulled160 (5500.0, 2000.0): 29266000.0 -> 29.27
probe2 origin: changed inputs [P5]; rebuilt (changed only) [Kitchen, Bath]; rebuilt (all of K) [Hall, Kitchen, Bath, Living]
probe2 corpus far origin, 23 deg: changed inputs [P5]; rebuilt (changed only) [Kitchen, Bath, Living]; rebuilt (all of K) [Hall, Bedroom 1, Kitchen, Bath, Living]
probe2 corpus far origin, 23 deg, own groups: changed inputs [P5]; rebuilt (changed only) [Kitchen, Bath, Living]; rebuilt (all of K) [Hall, Bedroom 1, Kitchen, Bath, Living]
```

The probe moves P5 10 mm on the spike's six-room sample plan (no separator,
so "Living" there is Living + Dining). It compares every wall's 07 world
outline before and after, bit for bit. Read boxes are the traced ring's box
with the seed, grown by 2 mm.

## Verdict

**Ready with amendments.** Every revision-1 finding is fixed or reasonably
ruled on. S-2 and S-4 I checked by running them. The writer's argument on
S-7 is right and I withdraw my fixture request. The new render-layer change
(g) is sound against `outline_cache.dart`. One new major defect was
introduced, and it is a one-phrase fix: the S-5 hover short-circuit, read
as written, would call every room interior of an axis-aligned plan
`Unbounded`. The rest are minor.

**Counts:** blocking 0, major 1, minor 7.

## 1. Revision-1 findings: were they fixed?

| Finding | Status | Note |
|---|---|---|
| S-1 M-10b equivalent | **Fixed** | Redefined as the spike's (either sign, least signed area), killed by `RT1`/`RT2` as the spike measured (`+8 −71`) |
| S-2 150 mm area | **Fixed, verified** | 160 mm: 100 × 3,740 = 374,000; 29,640,000 − 374,000 = 29,266,000 → `29.27`, 0.001 from the tie. Run: `29266000.0 -> 29.27` for both seeds |
| S-3 `room.shared` API | **Fixed** | `objectsOf<U>()` is survey-backed and memoised; it is in the engine table and the files list, pinned by `SD10`, with M-10objects killed by `DG1` |
| S-4 trigger cost | **Fixed, verified with a caveat** (T-3) | Only a changed input adds boxes; the no-drift proof still holds because it reads only changed inputs. The no-reader check is added. Run at the origin: only P5's input changes; rebuilt = [Kitchen, Bath] (revision 1's rule: + Hall, Living). At 23° it also rebuilds Living |
| S-5 hover | **Partly adopted; the adopted part is worded wrongly** (T-1) | The part left out (an `Unbounded` point inside the plan re-traced per move, timed in `TT6`) is acceptable; see T-8 for a cheap option |
| S-6 termination | **Fixed** | Non-finite boxes are `null`; the loop ends when `B` contains the union; no contributor at all gives `Unbounded` at once |
| S-7 M-10cert | **Fixed; the writer's argument accepted** | The certificate retrace runs among `T ∪ C₁` with `C₁ = placedIn(box(F₁) ⊕ m)` and gives `F₂ ⊆ F₁`. It cannot become `SeedInWall`: a wall or separator at the seed touches `B` and was traced already. It cannot become `Unbounded`: adding edges never unbounds a face. So `C₂ ⊆ C₁ ⊆` traced, and the loop exits after one extra trace. My two-round fixture cannot exist: any second hole lies inside `F₁`, hence inside `box(F₁)`. `LZ2` kills "return the first `Traced`" |
| S-8 `PG2` | **Fixed** | Counts `generate` calls |
| S-9 counter | **Fixed** | `debugTracedSegments` |
| S-10 grip frames | **Fixed** | `anchor_w`, `pole_l`, `label` are now consistent with D10 (anchor local = `toLocal(pole_w) + label`; lines offset in world). `GR6` / M-10gripframe |
| S-11 keyhole | **Fixed** | `tintOf` in the seed frame, bridges to the growing ring, a hole left out is reported; `TN1` tests step 3 on a pinched ring |
| S-12 early return | **Fixed** | M-10pagelate killed by `PG1`'s page-only edit; the trigger shares the plan's view |
| S-13 counts | **Fixed, one inconsistency left** (T-4) | |
| S-14 `stored` | **Fixed** | |
| S-15 0.35 mm | **Controller's ruling, acceptable** | Gate 17 now includes "whether 0.35 mm reads as thin" |
| S-16 Dining | **Controller's ruling, acceptable** | |
| S-17 DASHED duplicates | **Fixed** | Matches `TableSection.add` |
| S-18 placements | **Fixed, one inconsistency** (T-5) | |
| S-19 small items | **Fixed** | `#E5E5E5`, the bath/living door, the provenance of Dining and Living, `LZ2`'s wording, `RL1` distance vs coordinates |

## 2. New material, checked against the code

- **D24 / (g), `OutlineCache._addLeaf`** (`outline_cache.dart:372-380`
  today: the `rendering()` check at 377, `if (kind == EntityKind.fill)
  return;` at 379).
  - **What it outlines.** The room group's key walks its leaves
    (`_addContainer`). The tint boundary leaf is still rejected, because it
    is invisible. The fill arm then adds that boundary's polyline once, with
    the owner's transform, and the labels add their text boxes. So the
    outline is exactly the stored tint boundary: the outer ring, the holes
    and the slit's two close edges under step 1. Under step 2 it is the
    outer ring only. Under step 3 there is no outline, and the spec records
    that. Stored closed polylines repeat their first point
    (`triangulate.dart`, "the first point repeated as the last"), so the
    polyline arm closes the loop.
  - **Existing drawings.** Nothing changes unless a fill's boundary carries
    the invisible flag. No tool or command sets that flag today, and there
    is no importer, so walls, openings, furniture and boxes are unchanged.
  - **Frame path.** The walk runs from the selection, hover and `DocChange`
    listeners. Per frame, `pathFor` returns the cached path, and
    `_debugRebuilds` counts path rebuilds, so `OL3`'s steady-state check is
    meaningful. The non-negotiable holds.
  - **Pickability.** The only readers of `OutlineCache` are
    `selection_overlay.dart`, `grip_cache.dart` (`box`, via `worldBoundsOf`)
    and the shell (`main.dart`, `planner_view.dart`, which pass it on);
    picking and band selection do not read it. The tint stays unpickable.
  - **Rotation grip.** The box grows to the ring, but `rotatable` also
    needs a movable key, and rooms are not movable, so no rotation grip.
  - **Tests.** `OL1` (a rotated group at the far origin, by coordinates)
    kills M-10ring. `OL2` kills M-10ringdup: `debugWorldSegmentsOf`
    concatenates segments, so a doubled loop shows. `OL2`'s hidden layer is
    rejected before the arm, and its missing boundary goes through the
    `slotOf == null` path. The test files named (`outline_cache_test.dart`,
    `selection_overlay_test.dart`) exist.
  - See T-6 and T-7 for two edges.
- **`objectsOf<U>()`:** sound and cheap. `SD10` covers lost and re-parented
  objects.
- **`placeInput`:** sound for the room's two types. The engine default is
  unsafe for any other type (T-2).
- **Decision 26's notice (R-29, `TT7`, M-10notice):** consistent with
  `main.dart` (`_status` at 247 merges selection and tools; `_statusLine`
  at 287). The hover-time notice is within the latitude decision 26 leaves.
  "The lowest-handle room whose seed is in the face" is well defined.
- **S-5 short-circuit:** see T-1.

## 3. Findings

### T-1 (major) — the hover short-circuit, as worded, calls room interiors `Unbounded`

**Where:** D19, "Hovering outside a room" ("a pointer outside `U`, the
union of every contributor's place box … is `Unbounded` without a trace");
`TT6` ("a hover outside every place box traces nothing"); M-10hover.

**Evidence.** The union of place boxes is a set of thin rectangles along
the walls, not the plan's extent. A room's interior lies outside every one
of them whenever its walls are axis-aligned. The sample plan's Kitchen seed
(19,000, 10,000) is a concrete case:
- E1's band box has y ≤ 8,250;
- P3's has y ≥ 11,440;
- P1's has x ≤ 17,060;
- P5's has x ≥ 21,440;
- every other wall's box is farther away.

Read literally, the tool reports `Unbounded` there: no preview, and no room
if the click shares the path. `TT6` as worded would pass for that broken
tool. D7's "until `B` contains `U`" is correct under either reading.

**Amendment.** Say "outside the **bounding box** of every finite place box"
in D19 and in `TT6`. Add to `TT6` (or `TT1`) that a pointer at the
Kitchen seed, outside every place box but inside that bounding box, is
traced and previewed. List M-10hover in D19's "Pinned by".

### T-2 (minor) — `placeInput`'s default makes change detection unsafe for other types

**Where:** D16 API (`Object placeInput(...) => placeBox(view, self)!`).

**Evidence.** A contributor whose input changes inside an unchanged box
would count as unchanged. Example: a segment flipped from one diagonal of
its box to the other, (0,0)→(10,10) to (0,10)→(10,0). The readers it
splits would then keep a stale face (drift). The room's two types override
the default. Any later contributor, or an engine test client, that forgets
to override is silently wrong. The failure only ever under-rebuilds.

**Amendment.** Make the default conservative: "always changed", for example
a fresh `Object()` that never compares equal, which is revision 1's
behaviour. Alternatively, make `placeInput` required when
`contributesPlace` is true. Add an `SD` case with the diagonal flip.

### T-3 (minor) — S-4's example holds at the axis-aligned placement only

**Where:** D16.6 ("rebuilds the two rooms P5 bounds (Kitchen, Bath)").

**Evidence.** At the corpus's 23°, P5's rotated band box also touches
Living's read box. Run: `rebuilt (changed only) [Kitchen, Bath, Living]`
in both the corpus and the own-groups placement.

**Amendment.** Add "at the plan's own axis-aligned placement; box
inflation under rotation can add a neighbour room (the review's run, 23°:
+ Living)". `RK2` already prints the count.

### T-4 (minor) — the bulk pass's place-box count

**Where:** D16.6 ("one more place box per contributor … the after boxes of
`K` are memoised and not recomputed") against `SD6` ("the bulk pass's count
(one per contributor)") and the counter ("every `placeBox` call the engine
makes").

**Amendment.** Pin one number. Either the bulk pass counts `n − |K ∩ live
after|` calls, or memo hits are counted as calls.

### T-5 (minor) — `RL1`'s placements disagree

**Where:** D10 "Pinned by" and `RL1` say "three placements" (origin,
corpus, +1e9 mm). The S-18 paragraph lists `RL1` under "all six
placements".

**Amendment.** Choose one; all six costs nothing.

### T-6 (minor) — D24's rule keys on the flag, not on "not drawn"

**Where:** D24, the mechanism and R-30.

**Evidence.** The rationale is "a drawn fill whose stroke is hidden". A
boundary hidden some other way, for example on a hidden layer while its
fill's layer is visible (only possible from a file), draws its area and
gets no outline. Separately, the arm uses the fill's transform `t`, which
is right only when the boundary has the same owner. The spec asserts that
both share an owner; that holds for `AddRegionCommand`, but a file can
break it (08's `_subtreeRemoval` comment describes such a load).

**Amendment.** State that the flag-only rule is deliberate, or key it on
"the boundary is rejected by `rendering()`". In either case add: "and only
when the boundary's owner is the fill's owner; otherwise nothing".

### T-7 (minor) — the move preview now drags a room's whole ring

**Where:** D21 and D24, against `selection_overlay.dart:207-228`
(`_paintPreview` strokes every selected key's outline under the drag's
`T`).

**Evidence.** In a mixed selection a room is skipped by the move (R-22),
but its outline, now the whole ring, is drawn moving with the walls during
the drag. This already happens for openings and labels; it is much more
visible with a ring.

**Amendment.** Either leave non-movable keys out of the preview, which is
one `movableKey` test per key and is not per-frame work to allocate, or
record it and add it to gate 17's look.

### T-8 (minor, optional) — a cheap containment test does exist for the courtyard case

**Where:** D19; the Revision 2 table, S-5 ("has no cheap containment
test").

**Evidence.** When the tool's full trace returns `Unbounded`, it has
traced every contributor. The unbounded face is then exactly the outside
of every component's outer contour (its most negative cycle). Caching
those contours with the cache's revision gives a point-in-polygon test
that is valid until the cache goes stale.

**Amendment.** Optional. The measured per-move re-trace (`TT6`) is
acceptable as it stands; correct the "no cheap test" wording or adopt the
cache.

## Cross-references and consistency (item 3)

- The header, the engine-changes table (row (g)), Files (render `lib` and
  test files, `objects_of_test.dart`, `main.dart`'s notice), Amendments
  (02 D9 row), Invariants, gates 10, 12, 14 and 17, and Open questions
  ("none") are all consistent with D24 and decisions 26–28.
- The mutant table's new rows (M-10allK, M-10objects, M-10pagelate,
  M-10hover, M-10notice, M-10gripframe, M-10ring, M-10ringdup) each name a
  test that the Testing section defines. M-10hover is missing from D19's
  "Pinned by" (T-1).
- No stale "Open question n" reference remains. R-28 is marked withdrawn
  and D23 cites decision 16. The `SD1`–`SD10`, `TT1`–`TT7` and `GR1`–`GR6`
  ranges match their definitions.
