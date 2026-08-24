# SDD ledger — plan: docs/superpowers/plans/2026-08-23-jet-cad-2d-plan-3g-tile-cache.md

Spec: docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md (reachable, read).
Base: 477d4c5 on `main`. No worktree — the human consented to working `main`
directly for Plans 3e, 3f and 3f.1 and the plan states the same arrangement.
origin/main is at 6c6dc42; `main` is 3 ahead. Nothing is pushed by this run.

## Pre-flight scan

### Shared files and interfaces, pair by pair

| # | tasks | produced vs consumed | found |
|---|---|---|---|
| P1 | 1 → 4, 5, 7 | `DraftPainter.debugRebaseOrigin`, `debugOnVisit` | **Clean.** Both are mutable fields, which is what lets one painter serve the live frame and every tile. The plan's interface block and Task 1's code agree after the pre-write correction. |
| P2 | 2 → 8 | `DocumentTables.mutationRevision`, `changes` (`TableListenable`) | **Clean.** Task 8 adapts the pure-Dart interface to Flutter's `Listenable`; the plan names the adapter. |
| P3 | 3 → 4 | `TileGrid`, `quantiseCamera`, `TileKey`, constants | **Clean.** |
| P4 | 4 → 8 | `TileCache.paintFrame` signature | **CONFLICT.** Task 4 defines `paintFrame` without `tablesRevision`; Task 8 adds it as required. `tile_fixture.dart`'s call site, written in Task 4, breaks at Task 8. See R1. |
| P5 | 4 → 9 | `_retireGeneration()` | **CONFLICT.** Task 9 needs it to take the viewport, to composite before disposing. See R2. |
| P6 | 4 → 7 | `_drawInto(..., onVisit)` | **Clean.** Task 4 already threads the parameter and passes null. |
| P7 | 7 → 8 | `applyChange(change, document)` | **Clean.** Task 8 wires it through `DocChangeNotifier.onChange`. |
| P8 | 7 → 9 | `_dropEverything`, `_dropGeneration` | **CONFLICT (minor).** Task 9's carry-over must be cleared by `_dropEverything`. See R2 — same ruling. |
| P9 | 9 → 10 | carry-over bytes counted in `liveBytes` | **Clean**, and the order (9 before 10) is the plan's. |
| P10 | 5 → 6 | `expectTiledEqualsLive` | **Clean.** |
| P11 | 4 → 6, 7, 10 | `TileRig({document, cacheBytes, tileDevicePixels, tilesBakedPerFrame})` | **Clean.** Task 4 defines all four parameters; later tasks only supply them. |
| P12 | 8 → 11 | `DraftCanvas.tiles`, `tileDevicePixels` | **Clean.** |
| P13 | 11 → 12 | the chosen `kTileDevicePixels` | **Clean** — Task 12 reads Task 11's decision, which Task 11 is told to record. |
| P14 | 1, 6 | `draft_painter.dart` — Task 1 edits it, Task 6 mutates it for M14 | **Clean.** Task 6's mutation is temporary and copy-restored, not an edit. |

### Task self-consistency, task by task

| task | its tests against its code | found |
|---|---|---|
| 1 | test calls `unitCamera()` from `support/fixtures.dart` | **CONFLICT.** `unitCamera()` is a *local* function in `test/invariants/text_cache_invariants_test.dart`, not a fixture. See R3. |
| 2 | test constructs six record types with parameter lists the plan tells the implementer to correct against `tables.dart` | **Acceptable, rowed.** Not a placeholder — the values are concrete and the instruction names the authority. A reviewer may read it as under-specification; R4 records why it stands. |
| 3 | arithmetic tests against arithmetic code | **Clean.** `dart:math` deliberately not imported until Task 10; the plan says so and `unused_import` is an error here. |
| 4 | counters against `paintFrame` | **Clean.** |
| 5 | pixel comparison against Task 4's mechanism | **CONFLICT with the review rubric.** Task 5's tests may pass on first run because Task 4 already built the mechanism. See R5. |
| 6 | text and translucency fixtures | **Clean**, with two `fixtures.dart` helpers the plan tells the implementer to add if absent. |
| 7 | invalidation tests use `Float64List` | **Minor.** `dart:typed_data` is not in the plan's import list for that test file. See R6. |
| 8 | widget test needs an `onPaintForTest` hook the plan tells the implementer to add | **Clean** — the plan states it and says why counting frames is the only separation. |
| 9 | tests against implementation *shape*, not line-by-line code | **Rowed.** See R7. |
| 10 | same | **Rowed.** See R7. |
| 11 | a sweep, no tests | **Clean** — a measurement task. |
| 12 | device measurement, no code | **Clean.** |
| 13 | documents | **Clean.** |

### Rulings made before dispatch

**R1** — Ruling: **Task 8 owns the `paintFrame` signature change and must update
`test/support/tile_fixture.dart`'s call site in the same commit.** — Why: the
`tablesRevision` parameter cannot exist in Task 4, which has no table signal to
read; adding it early would be a parameter nothing supplies. — Costs if wrong:
Task 8 fails to compile until the fixture is updated, which its own suite run
catches immediately. Carried into Task 8's dispatch.

**R2** — Ruling: **Task 9 owns `_retireGeneration`'s signature and
`_dropEverything`'s extension to the carry-over; both are private and have no
consumer outside `tile_cache.dart`.** — Why: the composite does not exist until
Task 9, and giving Task 4 a viewport parameter it ignores is dead weight a
reviewer would rightly flag. — Costs if wrong: nothing outside the file; the
compiler is the gate.

**R3** — Ruling: **Task 1's test defines its own local `unitCamera()` rather
than adding one to `support/fixtures.dart`.** — Why: `unitCamera()` already
exists as a local in `text_cache_invariants_test.dart`; promoting it to a shared
fixture would touch a Plan 3f.1 file this plan has no business editing, and
leaving both would be two definitions of one name. — Costs if wrong: a duplicated
four-line helper, which is cheaper than the alternative. **The camera must not be
`ViewportTransform.fit`** — anti-degenerate clause 2 binds regardless of where
the helper lives.

**R4** — Ruling: **Task 2's record constructor calls stand as written, with the
plan's instruction to correct them against `tables.dart`.** — Why: the plan
cannot know six constructor signatures it did not read, and inventing them would
be worse than naming the authority. The values themselves — `lineweight: 50`,
`transparency: 40`, `DraftColor.indexed(3)` — are deliberately non-default and
are the part that matters. — Costs if wrong: one compile-fix round inside the
task.

**R5** — Ruling: **Task 5's tests are allowed to pass on first run, and the
mutation step is what makes them count.** — Why: the mechanism necessarily
precedes the pixel comparison — Task 4 cannot be reviewed without drawing, and
Task 5's instrument cannot exist without something to compare. This repository's
own testing bar is "a new test is only worth landing if a named mutation makes it
go red", and M15 and M17 are that proof. — Costs if wrong: a reviewer flags a TDD
violation; the ruling is here for them to weigh rather than to be surprised by.
**Task 5's Step 4 is not optional and a report without both transcripts fails the
task.**

**R6** — Ruling: **Task 7's implementer adds `dart:typed_data` (and any other
import the file needs) without treating it as a plan defect.** — Why: an import
list is not a requirement. — Costs if wrong: nothing.

**R7** — Ruling: **Tasks 9 and 10 give implementation shape and exact tests
rather than line-by-line code, and that stands.** — Why: `Picture`/`Image`
composition and an LRU are ordinary data-structure work whose contract is fully
pinned by the tests above them; speculative code the implementer would correct
against the API is worth less than the tests that judge it. The plan's own
self-review states this. — Costs if wrong: those two tasks take a fix round more
than the others. **Their reviewers are told the tests are the contract**, so a
"the plan did not give me the code" report is not a blocker.

## Progress

Task 1: dispatched (BASE 477d4c5, sonnet)
Task 1: implementer DONE (commit cb49f0d). Engine 793 pass; Flutter 306 pass / 1 skip.
Task 1: **R8** — Ruling: **the plan's Task 1 named `_rootLeaves++` and `_defLeaves++`
as insertion anchors; those exist only on the unmerged `spike/picture-cache-price`
branch, not on `main`.** The plan was written citing them from memory of that tree.
The implementer placed the calls structurally instead, which is correct; the plan
text is corrected in place so no later reader is misled. — Costs if wrong: the
callback fires at the wrong sites, which the task reviewer is explicitly asked to
verify against `paint` and `_drawContainer` in the working tree. — Scanned the rest
of the plan for the same defect: **no other task references spike-only names**, and
`report()`'s `totalSpan` really is on `main` at 2218eab.
Task 1: review dispatched (477d4c5..cb49f0d, sonnet)
Task 1: minor (deferred): `paint()`'s root visitor calls `entities.handleAt(slot)`
  twice per leaf when `debugOnVisit` is set, where `_drawContainer`'s sibling site
  reuses the computed handle. `?.` short-circuits when null, so steady state is
  unaffected; it is a redundant lookup on the bake path only.
Task 1: note — the task reviewer dispatched a helper agent for one index-query
  verification. Not a duplicate review seat, so not treated as the defect the
  skill names; recorded so the pattern is visible if it recurs.
Task 1: complete (commits 477d4c5..cb49f0d, review clean — spec PASS, quality approved, 1 minor deferred)
Task 2: dispatched (BASE a5f0336, sonnet)
Task 2: implementer DONE (commit 3dcca1b). Engine 797 pass (793 + 4 new); Flutter 306 pass / 1 skip.
Task 2: **R4 vindicated, and wider than expected.** All six record constructors
  differed from the plan's guesses: `DraftColor.indexed` does not exist
  (`IndexedColor`), `LinetypeRecord.pattern` is a `DashPattern` not a
  `List<double>`, `TextStyleRecord`'s field is `fontFamily` not `font`,
  `PatternRecord.lines` is required and the plan omitted it, `DimStyleRecord.opaque`
  was left at `{}` (the implementer made it non-empty per the anti-degenerate rule).
  `AppIdRecord` has no non-default field beyond handle and name; the implementer
  said so rather than inventing one, which is the right call.
Task 2: **R9** — Ruling: **Task 8's brief carries the same wrong `LayerRecord`
  constructor, and the plan text is corrected now rather than at dispatch.** — Why:
  the identical defect would surface again three tasks later, and a plan that stays
  wrong after its error is known is worse than one that was wrong once. — Costs if
  wrong: none; the correction is copied from the landed, passing test.
Task 2: review dispatched (a5f0336..3dcca1b, sonnet)
Task 2: minor (deferred, CARRIED TO TASK 8): `DocumentTables` has no `dispose` and
  `_TablesNotifier._listeners` is a plain list, so a listener added and never removed
  is retained for the document's life. Standard `Listenable` contract territory, not
  a defect in Task 2. **Task 8 adds the only consumer — its reviewer must confirm the
  adapter removes its listener in `dispose` AND in `didUpdateWidget`'s teardown.**
  (The reviewer wrote "Task 9"; the widget wiring is Task 8 in this plan.)
Task 2: complete (commits a5f0336..3dcca1b, review clean — spec PASS, quality approved, 1 minor carried)
Task 3: dispatched (BASE 759fcb4, sonnet)
Task 3: implementer DONE_WITH_CONCERNS (commit 9f5bd0e). Flutter 314 pass / 1 skip; engine 797 pass.
Task 3: **R10** — Ruling: **both of the implementer's concerns are correct findings
  against the plan text, and the plan is corrected rather than the code.** Verified
  independently: `_floorDiv` appears only in `visibleKeys`
  (`tile_cache.dart:133-136`); `destRectFor` (`:156-164`) never calls it, so the
  brief's claim that the `abut exactly` test would redden under the negative-key
  mutant was **false**. And the brief's pan direction could never produce a negative
  key: panning subtracts from `e`/`f`, the anchor-relative delta goes negative,
  `left = -dx` goes positive, and no key is ever below zero. The implementer flipped
  the pan sign and added a min-key assertion against an independently computed
  floor, which is the brief's own prescribed response to a surviving mutant.
  — Costs if wrong: a grid that mis-keys negative tiles ships, and the failure is a
  one-tile-wide duplicate column appearing one tile into any leftward pan. The
  mutant now fires (`Expected: <-1>, Actual: <0>`), so the gate is real.
Task 3: review dispatched (759fcb4..9f5bd0e, sonnet)
Task 3: minor (deferred): `quantiseCamera`'s identical-instance early return is
  tested at dpr 2 only. The branch is dpr-agnostic arithmetic, so this does not
  threaten the frame-path allocation claim.
Task 3: note — the reviewer independently recomputed every figure in the new doc
  comments (the four-row memory/overdraw table, 154 tiles, 29.3/38.5 MiB, the
  4.00x/1.56x bake ratios) and cross-checked `kScreenClipInflate` and the 96.00 MiB
  vertex-buffer figure against `2026-08-21-plan-3d-results.md:864`. All exact. Those
  numbers came from this session's design phase, so that is an independent
  confirmation of the design's arithmetic, not only of the code's.
Task 3: complete (commits 759fcb4..9f5bd0e, review clean — spec PASS, quality approved, 1 minor deferred)
Task 4: dispatched (BASE 942593f, sonnet) — 942593f is the controller's plan-correction commit on top of Task 3; Task 3's own review package was 759fcb4..9f5bd0e and excluded it.
Task 4: implementer DONE_WITH_CONCERNS (commit 2f9ff5e). Flutter 318 pass / 1 skip;
  engine 797 pass. New tile tests ~1.8 s wall clock — ample `toImageSync` budget for
  Tasks 5, 6, 9 and 10.
Task 4: **R11** — Ruling: **M13's instrument was a tautology, and the defect is in
  the SPEC, not only in the plan.** Verified: `debugBlitPaint` returns the cache's
  own field (`tile_cache.dart:244`), which a mutant building a fresh `Paint` at the
  `drawImageRect` call site never touches, so the identity assertion stays green.
  The spec claimed that getter "is what makes M13 killable" — one section after
  citing trap 5, which is precisely about instruments that cannot see what they
  claim to measure. The implementer fixed the **test**, using the repository's
  existing `test/support/spy_canvas.dart` to read the `Paint` actually handed to
  `drawImageRect`, and left the production code untouched because it was correct.
  Spec and plan both corrected. — Costs if wrong: criterion 13 would have shipped
  unfalsifiable, exactly as Plan 3f.1's criterion 11 did. **Task 10 re-uses this
  instrument; its dispatch carries the correction.**
Task 4: review dispatched (942593f..2f9ff5e, sonnet)
Task 4: minor (deferred, CARRIED TO TASK 5): `tile_fixture.dart`'s `crossingGrid`
  doc comment claims "every line below is 90 logical pixels long". Recomputed: the
  lines are 190 world units, which at the fixture camera's 1.4 scale is **266
  logical pixels**, spanning about eight 32-logical-pixel tiles — not 90 and not
  2.8 tiles. The claim came from the plan text, so it is the controller's error, not
  the implementer's; the conclusion it supports (the lines cross tile boundaries)
  holds either way. **A shipped false claim in a committed comment is the exact
  thing Plan 3f.1 spent a commit narrowing (`e39f295`)**, so it is carried into
  Task 5's dispatch as a one-line correction rather than left to the final review.
  Plan text corrected in both places.
Task 4: complete (commits 942593f..2f9ff5e, review clean — spec PASS, quality approved, 1 minor carried)
Task 5: implementer DONE (commit 8e8fd61). Flutter 322 pass / 1 skip; engine 797 pass.
  Tile suite ~2.4 s. The subagent spent 340k tokens and 139 tool uses on this —
  most of it on the M17 investigation below, which was worth it.
Task 5: **R12** — Ruling: **M17 cannot be fired by any pixel comparison on the
  vertices backend, and the plan's fallback ("move the fixture to 4.5e6") was a
  wrong diagnosis of a right observation.** Verified independently: the painter
  pushes the rebase origin *as the residual*
  (`draft_painter.dart:605,742` — `Transform2.translation(_screenOrigin.x, ...)`)
  and `VerticesDrawSink` applies that residual in Dart `Float64`
  (`vertices_draw_sink.dart:322-323`) before storing into its `Float32List`, so
  `(screen - origin) + origin = screen` exactly and the pixel cannot depend on the
  origin at any magnitude. The implementer proved this algebraically and with a
  five-point sweep to 1e15, then added a wiring test that subclasses
  `VerticesDrawSink` to read what `_bake` hands it — which kills M17 cleanly. That
  follows Task 4's own precedent (R11) and the methodology of the package's
  existing `large_coordinate_test.dart`. Spec and plan both corrected; **Task 13's
  mutation log must record M17 as killed by the wiring test, not by criterion 1.**
  — Costs if wrong: D1's injected origin ships ungated. It is not ungated — the
  wiring test fires. **What would have been wrong is the coverage claim**, which is
  the defect this plan's spec cites from Plan 3f.1 and which nearly recurred here
  for the second time in two tasks.
Task 5: note (carry to Task 13 and to STATUS) — **the rebase origin has no effect
  on vertices-backend pixels at all.** That is a fact about the shipped codebase,
  not about this plan: rebasing earns its keep on the `CanvasDrawSink` path, where
  the residual becomes a canvas transform Skia evaluates in `float32` and text
  takes that path every frame. Worth carrying forward; nothing in 3g acts on it.
Task 5: review dispatched (2f735f9..8e8fd61, sonnet)
Task 5: minor (fixed immediately, not deferred): the controller's own citation
  `vertices_draw_sink.dart:317-318` points at the residual's destructuring; the
  addition is at `:322-323`. Corrected in the spec, the plan and this ledger. A
  wrong line number in a spec that will be read for months is worth a `sed`.
Task 5: complete (commits 2f735f9..8e8fd61, review clean — spec PASS, quality approved)
Task 6: dispatched (BASE e680979, sonnet)
Task 6: implementer DONE (commit ac6576e). Flutter 325 pass / 1 skip; engine 797 pass.
  Four findings: criterion 3 read `textOpCount` after the wrong paint (the painter
  resets counters per call and the cache calls it per tile, so the reading was the
  last tile's, usually text-free — fixed by reading from one standalone whole-
  viewport paint); M14 reddens through `textOpCount` rather than `uncoveredPixels`
  because `drawText` is `final` and the mutation is global; **M11 reddens nothing**
  in the existing criteria because `_capture`'s destination is always blank, making
  `BlendMode.src` and `srcOver` algebraically identical there — closed with a direct
  `debugBlitPaint.blendMode` assertion after confirming empirically that pre-filling
  opaque red erases 460,140 of 480,000 pixels under the mutation.
Task 6: **R13** — Ruling: **the diagonal tile-seam disagreement is load-bearing, not
  a follow-up, and gets its own task before Task 7.**
  What was found: ten diagonal lines crossing tile seams give
  `stray: 19, uncovered: 17, differing: 44` out of ~10,342 ink pixels, every
  difference a single-device-pixel horizontal displacement on a fixed row; it
  persists at `transparency: 0`; and `crossingGrid`'s axis-aligned lines over the
  same camera and tile size give exactly zero. That isolates it to slope, not to
  tile-crossing.
  Why it cannot be deferred: criteria 1 and 2 are this plan's central claim — the
  tiled frame **equals** the live frame — and as landed they are true only of the
  geometry their fixtures happen to exercise. Shipping that unqualified and
  unmeasured is the precise defect this plan's spec cites from Plan 3f.1.
  Controller's mechanism hypothesis, to be tested rather than assumed:
  `bakeCameraFor` folds the tile offset into the camera, so the painter computes
  `a*x + c*y + (e_frame - k*32)` and subtracts a `_screenOrigin` shifted by the same
  `k*32`. The offset cancels in exact arithmetic and **not in `Float64`** — each
  subtraction rounds separately — leaving a last-ulp difference. An axis-aligned
  edge is parallel to the pixel grid and a last-ulp shift can never flip a pixel; a
  diagonal edge can. If that is the cause, the fix is to stop folding the tile
  offset into the camera: cull by the tile, derive coordinates with the frame
  camera, and apply the offset as an exact integral device-pixel translate.
  — Costs if wrong: one task spent measuring a gap that then gets recorded as G5
  with a number instead of being fixed. That is still a better outcome than a
  criterion whose scope nobody wrote down.
Task 6: complete (commits e680979..ac6576e, review PENDING — dispatched after 6a)
Task 6a: dispatched (BASE ac6576e, opus) — diagnose and either fix or measure
Task 6a: DONE, outcome **MEASURED not FIXED** (commit b2c8a8c, no production file
  changed). Flutter 330 pass (was 325); both packages green.
Task 6a: **R14** — Ruling: **the controller's R13 hypothesis was WRONG, Task 6's
  diagnosis was ALSO wrong, and the real cause is recorded as accepted gap G5 with
  a measured bound.**
  Refuted, by measurement not argument: the `Float64` coordinates the two paths
  emit are **bit-identical** — 1368 comparisons, 0 mismatches — so
  `bakeCameraFor`'s folded offset loses nothing and R13's cancellation story is
  dead. Task 6's "it is the slope" reading is dead too: ten *parallel* diagonals at
  slope 0.6 cross just as many seams and give zero, while a single *near-axis* line
  gives seven alone.
  The real cause, verified by the controller to the bit: `VerticesDrawSink` stores
  positions as `Float32`, and a tile's whole-device-pixel offset moves a coordinate
  into a coarser binade. `-17.943408966064453` is exactly representable (binade 2^4,
  ulp 1.907e-06); `-401.94340896606445` sits in binade 2^8 where the ulp is
  3.052e-05 and stores as `-401.94342041015625`, error **1.1444091796875e-05 px**.
  The reproduction's device slope is exactly 3/50 and its differing pixels are
  exactly 50 apart. Reproduced with `Canvas.drawVertices` alone, no jet-cad code.
  The fix R13 implied was **built and tested**: region-based culling with an exact
  canvas translate, per-tile culling preserved (so not M7). Vertices became
  bit-identical; pixels moved zero. Reverted.
  Bound: **2.38%** of ink worst case over an 82-slope sweep, 0.39% on a ten-line
  drawing, 0.000% axis-aligned and at slopes 0.2/1.0/5.0/16.7. A permanent test
  asserts the bound and reddens under a one-pixel `destRectFor` error (3192 vs 60).
  — Costs if wrong: none that this plan can incur — nothing was changed. The cost
  already paid is one task, and it bought the scope of criteria 1 and 2, which was
  previously unwritten.
Task 6a: note — **the bound is software-Skia's.** G1's reservation applies in both
  directions: it does not transfer to a GPU backend and Impeller may show more, less
  or none. Owed alongside G1's device seam check.
Task 6 + 6a: combined review dispatched (e680979..b2c8a8c, opus)
Task 6 + 6a: review returned **spec ❌ (narrow)** + 1 Important + 1 Minor. Verified
  sound by the reviewer: no production file changed anywhere in e680979..b2c8a8c,
  no dead scaffolding from 6a's reverted experiment, criteria 1 and 2 not weakened,
  the bound is a real gate (36 measured / 60 asserted, 26 / 45 at the worst slope),
  and every line citation checks out.
  Open findings, entering fix round 1:
  F1 (spec ❌) — criterion 4 has no mutation that reddens it. M11 was honestly shown
    blind; nothing was fired in its place. Fire 6a's alpha mutant at criterion 4.
  F2 (Important) — criterion 4 cannot see a dropped alpha: the fixture passes
    `transparency: 153` but nothing asserts it took effect, so a resolver that
    ignored transparency entirely would draw both arms opaque and the test would
    still pass at zero. The same trap Task 6 correctly closed for text with
    `textOpCount`/`culledTextCount`, left open for alpha.
  F3 (Minor, NOT deferred) — two comment overclaims: the gap-group header says the
    `destRectFor` mutant reddens "at roughly two hundred times the bound" where the
    measurement is 53x, and criterion 3's comment calls its standalone paint "the
    same call `measureTiledAgreement`'s live arm makes" when that arm quantises the
    camera and injects the rebase origin and this one does neither. **Overclaiming
    comments are this session's recurring defect and are fixed, not parked.**
Task 6 + 6a: fix round 1/5 (3 addressed, 0 open — F1 criterion 4 now has a firing
  mutant, F2 an alpha assertion proven non-tautological by mutating
  `style_resolver.dart`, F3 both comments corrected; commits b2c8a8c..e760c64).
  The F2 assertion reads `0x66FFFFFF` — 255-153 = 102 = 0x66 — so it reads the value
  *through the resolver*, not the raw input the fixture supplied. That is what makes
  it a gate rather than a read-back.
Task 6 + 6a: complete (commits e680979..e760c64, re-review clean — spec PASS after
  fix, quality approved, 0 parked)
Task 7: dispatched (BASE e760c64, opus) — invalidation, the plan's largest task
Task 7: implementer DONE (commit 67b2e1f). Flutter 336 pass / 1 skip; engine 797.
  Five findings, all against the brief, all handled the way this plan expects.
Task 7: **R15** — Ruling: **four of the five findings are corrections to the plan
  text and one is a new accepted gap; the code stands as written.**
  Verified by the controller: `_childrenOf` (`draft_document.dart:331-341`) matches
  `GroupNode` and otherwise falls to `tree.definition(container)?.children ?? []`.
  An `InstanceNode` is neither, so **`definitionBounds(instanceHandle)` returns an
  empty box with no error** — direction two would have skipped every instance and
  dropped nothing, while direction one kept the tests green. That is the fifth
  instance in this plan of a gate that cannot see what it claims, and the most
  dangerous because the API's name promises otherwise.
  The other three plan corrections: `_isDefinitionOwned` must climb (a leaf owned by
  a group *inside* a definition has a group as owner, and `tree.definition(group)`
  is null); the brief's leaf edit cannot separate the two invalidation directions at
  all (shrinking makes the new tile set a subset and M2 survives, extending makes it
  a superset and M1 survives — **only a move separates them**, and every test now
  asserts the two sets are disjoint at runtime first); and M12 as briefed is a
  **compile error** rather than a red test, because `DocChange` is `sealed`.
  — Costs if wrong: the invalidation would drop too little and the drawing would go
  stale in exactly the places nobody looks. All four are now in the plan text.
Task 7: **G6** added to the spec — direction two uses the entity's *geometric* box,
  and a stroke puts ink up to half its width beyond that, so a tile it clips into
  from just outside is not invalidated. Bounded by half the rendered stroke width;
  not closable from the cache because the index's margin is private. Recorded.
Task 7: allocation per change is O(tiles), not O(tiles x touched) — one
  `Set<TileKey>`, one `List<Aabb2>` of at most `touched.length`, and one `Aabb2`
  plus four `Vector2` per live tile. Frame path unchanged; `paint_allocation_test`
  green.
Task 7: review dispatched (e760c64..67b2e1f, opus)
Task 7: review returned **spec ✅** but **1 Critical + 2 Important + 3 Minor**.
  Critical: a dragged GROUP leaves ghosts. `debugOnVisit` fires for `InstanceNode`
  only (`draft_painter.dart:401,485` both guard `node is! InstanceNode`), so no group
  handle is ever recorded; `TransformNodeCommand` accepts a `GroupNode` and reports
  only that handle, so direction one finds nothing. The reviewer *probed* it rather
  than arguing it: root leaf + group 400 holding leaf 1003, drag 400 -> groupTiles
  empty, four old tiles still held. The M16 defect, unmutated, in shipped code. And
  `tile_cache.dart:206`'s doc comment claims the record holds "every container
  descended", which is false.
Task 7: note — **how it got through.** Task 1's review traced `debugOnVisit` across
  all four call sites and confirmed "once per container descended". That was true of
  the fixture it traced. No fixture in Task 1 or Task 7 contains a group, so one
  implementation and two reviews approved an unbounded claim without anything
  contradicting it. The third reviewer wrote a group fixture and ran it. Same move
  that found G5's diagonal gap: the limit of a claim's coverage is harder to see
  than the claim.
Task 7: fix round 1 dispatched (Critical + 2 Important + 3 Minor)
Task 7: fix-round re-review #1 FAILED (agent stalled, watchdog, no progress 600s). Not a finding; re-dispatched on sonnet.
Task 7: fix round 1/5 (6 addressed, 0 open — C1 group ghosts closed by an owner-chain
  walk in `_bake` whose visited set doubles as memo and cycle guard, gated by a test
  asserting on **leaf 1003's** tiles rather than on the group's record; I2's climb
  gated by a `nestedFixture` carrying both real shapes; I3's `leavesByOwner` built
  once per invalidation pass at `tile_cache.dart:459-464`, not per handle; three
  minors corrected to true values. Commits 67b2e1f..a9f60a5.)
Task 7: note — M16 and the group mutant are **independent; neither subsumes the
  other.** Group recovery runs through the leaf's owner-chain climb, which M16 does
  not touch; instance recovery depends on the two `debugOnVisit` sites M16 removes,
  and a leaf's owner chain stops at the definition boundary and never reaches an
  enclosing instance. Both are required. Carry to Task 13's mutation log.
Task 7: complete (commits e760c64..a9f60a5, re-review clean — spec PASS, quality
  approved after one fix round, 0 parked)
Task 8: dispatched (BASE a9f60a5, opus)
Task 8: implementer DONE then fix round 1 (commits 6ca0789, eb3f800). Flutter 341
  pass / 1 skip; engine 797; golden 35/35 with **zero PNGs modified** against a9f60a5.
Task 8: **R16** — Ruling: **D9's quantisation belongs to the tiled branch only, and
  the sixteen re-recorded goldens are reverted.** The spec said the quantised camera
  drives "the live path too", unqualified; read as *always*, it changed the default
  rendering path. The level-of-detail ladders sit at `f = 292.5`, exactly the
  rounding tie at dpr 3, so quantisation moved them half a device pixel in y.
  It bought nothing: criterion 1's instrument quantises its own live arm at
  `tile_comparison.dart:81`, so the gate never depended on the widget doing it.
  Spec narrowed; `quantiseCamera` now has exactly one call site, `tile_cache.dart:348`.
  — Costs if wrong: with `tiles` on, the drawing sits half a device pixel from where
  it sits with `tiles` off. Recorded on `DraftCanvas.tiles`' doc comment and in the
  spec, deliberately **not** pinned by a test: codifying an accepted imprecision as a
  requirement would make it unremovable for whoever later wants tiles as the default.
  The reviewer was asked to judge that call and agreed.
Task 8: note — the implementer found criterion 7 as briefed could not see its own
  name: it asserted only the frame count, and a mutant keeping the merge while
  deleting the invalidation passes it while the cache shows stale pixels forever.
  **Seventh instance of this plan's recurring defect**, found and closed by the
  implementer with an exact `invalidationCount` assertion. It also added
  `DocumentTables.debugListenerCount` — there was no instrument for listener
  lifetime at all — and pinned 0 -> 1 -> re-attach -> 1 -> re-attach -> 1 -> unmount -> 0.
Task 8: complete (commits a9f60a5..eb3f800, review clean — spec PASS, quality
  approved, **zero findings**, the plan's first clean review)
Task 9: dispatched (BASE eb3f800, opus)
Task 9: implementer DONE (commit 2d595a1). Flutter 349 pass; engine 797; golden 35/35
  with `git diff --stat eb3f800 -- test/golden` **empty**. M4 red on criterion 8 (2 vs
  1) and on criterion 1 after a zoom (35,349 differing pixels); M9 red on the settle
  (12 vs 130). Two brief tests were wrong and the implementer fixed the tests: a rig
  at `tilesBakedPerFrame: 0` never bakes a first generation so every counter reads
  zero against zero, and `TileRig.zoomBy` scaled about a point outside the viewport
  so the composite fell short of the left edge.
Task 9: **R17** — Ruling: **defect F1 is a visible bug, not an accepted gap, and gets
  its own task before Task 10.**
  What it is: at 6 of 41 swept zoom factors a **whole stroke column vanishes** from
  the tiled frame. Verified by the controller: `DraftPainter.paint` derives its index
  query from `camera.visibleWorld(viewport)` with **no slack**
  (`draft_painter.dart:338`, used raw at `:357` and `:369`), while the screen clip is
  inflated by `kScreenClipInflate` at `:345-351`. A clip only *keeps*; it cannot
  return an entity the query never yielded. So a tile whose world rect ends just left
  of a stroke's centreline never receives that entity, and the half-stroke reaching
  back inside is drawn by nobody.
  Why it was invisible until now: this is a **pre-existing latent defect in
  `DraftPainter`**, not something 3g introduced. On a full frame the missed entities
  are off-screen. On a tile the edge is interior to the drawing.
  Why it is not deferrable: a vanishing stroke column is not sub-pixel and not
  bounded — it is the feature being wrong where a user looks.
  The implementer already built the one-call fix (pad `_bake` by
  `kScreenClipInflate`), measured it from 6-of-41 to **0-of-41**, found it reddens
  four direction-two assertions in `tile_invalidation_test.dart` — because the
  `_baked` record widens by a ring while `_invalidateTouched`'s geometry does not
  inflate — and reverted, correctly, as an invalidation-precision decision outside
  its brief.
  **That mismatch is G6.** Inflating both sides by the same constant closes F1 and
  G6 together, which is why they are one task and not two.
  — Costs if wrong: invalidation over-drops by a ring, which is a hit-rate cost and
  not a correctness one; the alternative is a visible missing stroke.
Task 9: note — no instrument sees a leaked `ui.Image`; the disposal table is argued
  from code and gated only through `hasCarryOver`. Carry to Task 10, which owns
  eviction and is where a leak would compound.
Task 9a: dispatched (BASE 2d595a1, opus) — close F1 and G6 together
Task 9a: DONE. **F1 CLOSED, G6 CLOSED** (commit 1d55659). Flutter 350; engine 797;
  goldens 35/35, `git diff --stat 2d595a1 -- test/golden` empty.
  One constant, `kTileSlack = kScreenClipInflate`: `_bake` widens its cull,
  `_worldRectOf` grows the tile rect in screen space before inverting, clip untouched.
  Sweep 6/41 -> 0/41. **Three of the four assertions went green with no test change**
  — they had reddened only because the arrival oracle over-reported against an
  unpadded rule. The fourth is the separability guard, untouched; its fixture moved
  from two tile columns clear to five because each position now claims a ring.
  Nothing loosened; F1's group tightened from `<= 600` uncovered to `== 0` and
  criterion 1's zoom list stopped excluding the six killers.
  New mutants: M18 (slack removed) kills 3; M19 (bake-only, Task 9's reverted patch)
  kills 5. Both added to the spec's table.
  Over-drop measured: 64 px tile, leaf move 15 -> 32 of 130, dragged instance 8 -> 28.
  **At the production 256 px tile the dragged instance costs nothing extra.**
Task 9a: note (carry to Task 13's owed list) — **`kScreenClipInflate`'s doc comment
  says "device pixels" and it is used as logical.** Usage is consistent and errs
  safe, so nothing is wrong today; the comment is. Belongs to whoever owns
  `draft_painter.dart`, not to this plan.
Task 9 + 9a: combined review dispatched (eb3f800..1d55659, opus)
Task 9 + 9a: review returned **spec ❌** on Task 9 (9a itself clean, every claim
  held) + 1 Critical + 1 Minor + 2 unverifiable-from-diff.
  Critical: **an edit while a carry-over composite is alive shows pre-edit pixels.**
  `_dropGeneration`/`_invalidateTouched` never clear `_carryOver`, and
  `tile_cache.dart:546`'s `if (carryOverCovers) return;` then suppresses the live
  fallback that would repaint. Reproduced by the reviewer with a scratch probe: zoom
  1.19, then a layer add -> `hasCarryOver=true, liveTileCount=0, liveDrawCount=0,
  carryOverBlitCount=1` — the whole frame is the stale composite.
  **Instance eight, and the blindness is in the test's SETUP.**
  `tile_cache_test.dart:598-630` asserts exactly the right thing — `liveDrawCount > 0`,
  and its own comment says "which a composite standing in front of it would hide" —
  but it never zooms, so no composite exists. The author saw the hazard, named it in
  the comment, and built a fixture in which it cannot arise.
  Verified clean by the reviewer: slack on both sides with the clip untouched
  (`kTileSlack` at `:62`, `:955`, `:1043`; hard clip at `:1007` before the
  `translate` at `:1045`); three assertions green with no expected value moved; the
  separability guard a context line with only the fixture's coordinates changed; the
  only bound that moved **tightened** (`<= 600` -> `== 0`) and criterion 1's zoom list
  *gained* 1.10 and 1.22; the G6 test reds on `holds(key) isFalse`, not on a
  precondition; the composite is one `toImageSync`, unsnapped, with its own
  `FilterQuality.low` paint; and every `_carryOver` assignment is preceded by a
  `_dropCarryOver()`, with disposal reachable from all three drop paths.
Task 9: **R18** — Ruling: **two of the reviewer's items are unverifiable from the
  diff because nothing gates them, and that is correct — they belong to Task 11.**
  The over-drop table (15->32, 8->28) and the 2.25x padded bake cost at the
  production 256 px tile are measurements in a report, not claims in code. Task 11's
  sweep already owes a **bake cost per tile** column and an **overdraw factor**
  column; both now also carry the padded figure. — Costs if wrong: a number in a
  report nobody re-derives. Task 11's dispatch carries it.
Task 9: fix round 1 dispatched (Critical + Minor)
Task 9: fix round 1/5 (2 addressed, 0 open; commit b657dec). Flutter 351; engine 797;
  goldens 35/35, diff vs eb3f800 empty.
  C1 was **worse than the review reported**: at the production budget of 4 the frame
  never heals — `liveDrawCount` stayed 0 for eleven frames while the un-refilled
  viewport showed pre-edit pixels for a whole settle. And the fix needed **two**
  calls, not one: `_dropGeneration` misses `_invalidateTouched`'s per-tile path, so an
  ordinary leaf edit still left the composite standing. The second is hoisted above
  `applyChange`'s switch. Each proved load-bearing independently — the table arm reds
  with one backed out, the leaf arm with the other.
  The blind test is now two tests: one zooms first, one deliberately keeps the
  opposite precondition (a *covered* outgoing generation) because that is what gates
  the minting mutant. Neither catches the other's.
Task 9: **instance nine of the recurring pattern, and a new kind.** The sweep found
  that criterion 13's `SpyCanvas` test — "every `drawImageRect` shares one `Paint`" —
  was made **false by Task 9's own carry-over**, which carries its own filtered
  `Paint`. True the day it was written; silently wrong afterwards, and invisible
  because no test entered that path with a composite standing. Closed with a second
  phase in that state, a new `debugCarryOverPaint`, M18 killed, and the filter
  qualities and the composite's blend mode pinned — which also closes M11's hazard on
  the one blit M11 could never see. Two further tests read `liveDrawCount` as
  coverage where a composite means suppression; both now say so.
  **The defence is asking, when a new state is introduced, whether the old
  assertions are still true in it.** The implementer only swept because the fix
  dispatch asked; without the question `debugCarryOverPaint` would not exist.
Task 9: **structural blind spot, carry to Task 13.** Nothing outside
  `tile_cache_test.dart` ever zooms, so the whole invalidation suite runs in a world
  with no carry-over. That is exactly why C1 was invisible to it.
Task 9 + 9a: fix-round re-review dispatched (1d55659..b657dec, sonnet)
Task 9 + 9a: fix round 1/5 (2 addressed, 0 open; commits 1d55659..b657dec).
  The re-reviewer verified the two `_dropCarryOver()` calls are independently
  load-bearing **by reading control flow rather than trusting the transcript**: a
  table edit reaches only `paintFrame`'s `tablesRevision` check, which calls
  `_dropGeneration()` directly and never enters `applyChange`, so that arm depends
  solely on `:850`; an ordinary leaf edit goes through `_invalidateTouched`, whose
  non-definition path removes tiles individually and never calls `_dropGeneration`,
  so that arm depends solely on the hoisted `:716`. Neither subsumes the other.
  M2 corrected in the other direction: the implementer's "seven lines at 81-83" was a
  **byte-counting artifact**; measured in codepoints no line exceeds 80.
Task 9 + 9a: complete (commits eb3f800..b657dec, re-review clean — spec PASS after
  one fix round, quality approved, 0 parked)
Task 9: minor (CARRIED TO TASK 10): `_dropEverything`'s comment still says it "is the
  only drop path that clears" the carry-over. False since the fix — `_dropGeneration`
  and the hoisted `applyChange` call clear it too. Harmless because idempotent, but a
  **false claim in a committed comment is this session's signature defect** and
  Task 10 is already in that file.
Task 10: dispatched (BASE b657dec, opus)
Task 10: implementer DONE (commit 810077b). Flutter 359 pass + 35 golden; engine 797;
  golden diff vs b657dec empty. M6 reds criterion 12 at 2,129,920 B against a 131,072 B
  cap; restored by copy-aside with a clean `diff`.
Task 10: **the three questions caught three at once, in one task.** The dispatch
  carried the nine disguises and asked: what must break for this to fail and is that
  what it names; is there a shape that falsifies the claim and does the fixture have
  it; does the setup produce the state the assertion is about. All three of the
  brief's tests were weaker than they read, each confirmed by firing a mutant:
  dropping the composite term from `liveBytes` left all three green because they only
  pan and `_carryOver` is therefore always null (question 3); criterion 13 survived a
  destination counter stuck at zero (question 1); and the pan-back test survived M6
  outright, so the eviction fixture never evicted what it claimed. Five tests added,
  each with a named mutant. **This is the first task where the pattern was hunted
  rather than stumbled on.**
Task 10: judgment calls accepted — eviction runs **before** each bake rather than as
  a closing sweep, because at 130 visible tiles against an 8-tile cap a closing sweep
  has nothing left it is permitted to take; and the budget tests deliberately do not
  zoom, because one composite is **14x** the small cap and `liveBytes <= cacheBytes`
  would be a contradiction — the composite state is covered at the production ceiling
  instead. Both reasoned rather than assumed.
Task 10: leak instrument `debugImagesAlive` added; it sees a leak, **not** a
  double-dispose. Honest limitation, recorded.
Task 10: review dispatched (b657dec..810077b, opus)
Task 10: fix round 1/5 (4 addressed) and round 2/5 (1 addressed, 0 open; commits
  810077b..aa21ee8). Round 2 was a single comment, and it is worth recording why it
  existed: I2's *narrowed* comment — written to close a comment-accuracy finding —
  was itself false, and the evidence falsifying it sat about eighty lines above it in
  the implementer's own report (`evict=119` in one frame). The gap was not knowledge;
  it was not turning back to the transcript while writing the claim.
  The implementer then did more than asked: it **asserted** the 119 as a floor
  (`> 50`, not the exact figure, with a note that the exact count would be a
  map-iteration-order claim), so no number in that comment now rests on memory. Both
  ways a comment goes wrong — written wrong, or outlived by the code — are closed by
  one line. The re-reviewer derived the true bound from the `while` loop itself
  before comparing it to the comment.
Task 10: complete (commits b657dec..aa21ee8, re-review clean — spec PASS, quality
  approved after two fix rounds, 0 parked)
Task 10: minor (deferred): `_lastUsedFrame.entries` allocates a `MapEntry` per scan
  step where `keys` plus a lookup would not. Never runs on a steady-state frame;
  explicitly left alone rather than churned.
Task 10: note (carry to Task 13): `cacheBytes` is now a second test-only mutable knob
  on a production type, after `tilesBakedPerFrame`. Accepted; the implementer's own
  bar — a third knob should trigger revisiting the design — is the right one.
Task 11: dispatched (BASE aa21ee8, opus). Machine verified: `lowpowermode 0`, AC
  power, battery 100%.
Task 11: DONE (commit 96cdd56, harness only). Control reproduced Plan 3d's clean
  50,000/vertices row: 7.17 / 8.48 against [7.06, 7.38] / [8.22, 8.63]. Machine
  verified `lowpowermode 0`, AC, every drive in the foreground.
Task 11: **R19** — Ruling: **`kTileDevicePixels = 512`, and `kTilesBakedPerFrame`
  must be re-expressed as a device-pixel budget. A follow-up task applies both to
  source; Task 11 owned the harness only.**
  512 is the only size whose pan p95 fits 16.67 ms — 2.31 ms against 47.42 at 256
  and 65.19 at 128, and zero live-walk fallbacks against 1 and 18.
  **The three-column requirement earned itself**: blit cost is flat at 1.45 / 1.44 /
  1.52 ms across a 16x range of tile count, so a sweep reading only the column the
  spike had measured would have decided nothing.
  **And the overdraw model was wrong.** Area factors came out as predicted
  (4.000 / 2.250 / 1.563) but measured leaf overdraw is 17.983 / 6.888 / 4.185,
  leaving residues of 4.50x / 3.06x / 2.68x. The cause is not the pad: **an entity is
  walked once per tile it crosses**, and crossing multiplicity dominates. So
  `kTileClipInflate` is **withdrawn** — the spec's own invitation to name it if the
  overdraw column justified it is closed by the measurement, since it attacks only
  the smaller term and shrinking the pad reopens the vanishing-stroke defect.
  — Costs if wrong: 512's 48.0 MiB visible set plus the 29.3 MiB composite is
  77.3 MiB against the 96 MiB cap, leaving 18.7 MiB of ring — tight but inside, and
  Task 10's cap tests gate it.
Task 11: **the 512 choice invalidates `kTilesBakedPerFrame`'s unit.** Eight tiles at
  128 px is a modest strip; eight at 512 px is 8 x 12.56 ms = **~100 ms in one frame**,
  six budgets. Caught by the implementer, not by the plan.
Task 11: two more findings carried to the follow-up — with `TILES=on`,
  `printInvariants`' leaf and triangle counts report the last **bake**, not the frame
  (512 printed 1402 against a true 4612), so every leaf number in the report came
  from a probe instead; and `frame_timing_test.dart` needed changes beyond the
  brief's file list, because `onReady` must hand the rig the resolved `TileCache`.
Task 11a: dispatched (BASE 96cdd56, sonnet) — apply 512, re-unit the bake budget,
  fix the harness counters
Task 11a: DONE (commits 96cdd56 harness, 20565d4 source). `kTileDevicePixels = 512`;
  `kTilesBakedPerFrame` replaced by `kBakeBudgetDevicePixels = 262144` — one 512 px
  tile's area, chosen because 12.56 ms bake + 1.52 ms blit = 14.08 ms fits 16.67 and
  two tiles' 25.12 does not. `TileCache` divides by tile area at runtime so the tile
  count now follows the tile size instead of being independent of it.
  Every test's intent preserved through a bridging conversion plus six manual edits:
  unlimited (1000), exactly-N-tiles, and zero-means-bake-nothing all still mean what
  they meant. **That was the risk worth naming** — a test that meant "bake nothing"
  and now means "bake one tile" stays green and still reads as proof of the old
  thing.
  Controller omission, recorded: the dispatch asked for commit SHAs but gave no
  commit step, so the first pass correctly left the tree uncommitted.
Task 11a: **the harness default silently moved from 8 tiles to 1**, which would have
  made the device task's runs incomparable with Task 11's sweep with nothing in the
  transcript saying so. Closed by naming `kBakeBudgetDevicePixels` in `main.dart` and
  by having the rig **print the budget it ran with**, in device pixels and in tiles,
  beside its counters. A measurement that does not carry its own configuration is how
  two incomparable runs end up in one table.
Task 11a: carried to Task 12 — the 1-tile default's pan-settle behaviour has **not**
  been re-verified against Task 11's sweep, which ran at 8.
Task 11 + 11a: combined review dispatched (aa21ee8..20565d4, opus)
Task 11 + 11a: fix round 1/5 (5 addressed, 0 open; commits 20565d4..37918c5).
  I1's floor sits at `tile_cache.dart:499-502`, and the re-reviewer confirmed
  `paintFrame` calls that getter directly at `:687`, so it is the truncation point
  itself and not a bypassable duplicate. Two new tests cover both branches at
  `tileDevicePixels: 1024`.
  **I1 is worth remembering past this plan.** The repository's throw-on-bad-define
  rule was written after Plan 3c lost a device run to `bool.fromEnvironment('TEXT')`
  reading `TEXT=1` as false. It guards the *string* level. `TILE_PX=1024` is a valid
  number, inside the declared range, that divided to a zero budget and would have run
  the whole sweep on the live-walk fallback — **publishing the untiled baseline under
  a tiled heading.** Same failure, numeric disguise, two years later. The guard's
  type was right; its scope was not.
Task 11 + 11a: complete (commits aa21ee8..37918c5, re-review clean — spec PASS,
  quality approved after one fix round, 0 parked)
Task 11: **the measurement changed more than it measured.** The sweep was asked to
  choose a tile size. Choosing it invalidated `kTilesBakedPerFrame`'s unit, disproved
  the overdraw model, closed the `kTileClipInflate` question the spec had left open,
  and exposed the numeric gap in the define guard. None of those were the sweep's
  question; all were consequences of its answer, and most of the dependencies were
  nowhere written down.
Task 12: dispatched (BASE 37918c5, opus) — criteria 10 and 11 on device
Task 12: **BLOCKED on machine state, not dispatched.** `pmset` now reads
  `lowpowermode 1` on Battery Power — the charger came out and macOS re-enabled it.
  Criteria 10 and 11 are device timings and the plan requires the control run to
  reproduce Plan 3d's clean row before any number is published. Dispatching a task
  whose first act would be to stop is waste, so it waits for AC power.
Task 12: **R20** — Ruling: **reorder — Task 13's documentation work runs now, with
  criteria 10 and 11 left explicitly pending rather than estimated.** — Why: the
  mutation log covers nineteen named mutants whose transcripts already exist in the
  task reports, and none of that needs a device. Blocking the whole plan on a
  charger would waste the window. — Costs if wrong: Task 13 is revisited once to
  fill two rows, which is cheaper than idling. **No number for criteria 10 or 11 may
  be written until Task 12 runs**; the results note carries them as PENDING, and a
  PENDING row is an honest state where an estimate would be a fabrication.
Task 13 (documentation half): dispatched (BASE 37918c5, opus)
Task 13 (documentation half): DONE (commit 666714d). **41 mutants named, 40 fired.**
  The plan counted seventeen; execution more than doubled it because repeatedly the
  mutant a task was handed could not fire and a working one had to be built. Three
  label collisions found and renamed (`M18` named two different mutants; Task 7's
  local G1/G2/G3 collided with the spec's accepted-gap names) — **briefs should carry
  a namespace.** One transcript genuinely missing and recorded as missing rather than
  reconstructed. The plan's own "sixteen fired, one unfirable" line is superseded
  (a0312cc).
Task 12: DONE, no source change. Machine verified before all six runs; control
  reproduced Plan 3d's clean row at 7.26 / 8.56.
  **Criterion 10 PASS** — settled frame `totalSpan` median **1.58 ms** against a
  4.00 threshold, and 26x the same runs' untiled 41.09 ms.
  **Criterion 11 MISS by 2.1x** — a baking pan frame reads **35.67 ms** against
  16.67. Threshold not moved.
Task 12: **R21** — Ruling: **criterion 11's miss is recorded as a miss and the
  spec's prescribed remedy is spent, so it becomes Plan 3h's design question.**
  The cause is not the bake: a bake walk is 5.7-6.4 ms per tile, and the frame's
  ~32 ms of excess is the **live fallback drawing the still-uncovered strip**
  (`liveDraws=10`, live walk 31-42 ms). The spec said the response to an unreachable
  threshold is a smaller bake budget; the budget is **already one tile**. A pan frame
  exposing more than one tile falls back to a live walk for the remainder and that
  walk is the whole cost. — Costs if wrong: 3h inherits a wrong diagnosis. It is
  measured, not argued: the probe separates the bake from the fallback.
Task 12: **M7 fired on device and collapsed nothing — recorded as G7.** Criterion 10
  is *structurally blind* (`bakeFrames=0/60`, the mutated clip never runs in a
  settled frame); criterion 11 degraded 35.67 -> 49.90 from an already-red state, so
  there is **no green-to-red transition anywhere**. M7 was demonstrably live:
  triangles 734,442 -> 1,183,035, build 23.10 -> 38.47, twice.
  **Nothing in Plan 3g gates per-tile clipping**, and the spec's own sentence — "a
  suite that cannot kill it is not gating this plan" — stands against it.
  Twelfth instance of the recurring pattern, and it reaches the instrument: the rig's
  `overdraw` column reads an identical 4.185 under M7, because `_probeBake`
  reimplements the bake geometry instead of calling `_bake`.
Task 12: settle takes 11 frames, five for five; the evidence says most miss the
  budget (~30-40 ms each, ~350-450 ms per zoom). Labelled as inference with its three
  supports, since the rig cannot time warm frames.
FINAL REVIEW (477d4c5..82976ce, 39 commits, opus): **1 Important + 7 Minor. Verdict:
  fit to merge after findings 1 and 4.** Verified clean by the reviewer: every
  `ui.Image` exits through `_disposeImage` with no drop-without-dispose on any path;
  the table listener is removed on both teardown paths; no forbidden file in any
  commit; draw order intact; and every spot-checked citation correct.
FINAL REVIEW: **F1 is the third falsified comment, and it carries the controller's
  own error.** `quantiseCamera`'s doc still describes quantising both paths, which
  R16 narrowed away — and **R16's ledger entry claims the half-device-pixel offset is
  "recorded on `DraftCanvas.tiles`' doc comment". It is not in the tree.** Task 8's
  reviewer told me it was, and I wrote its claim down as verified fact.
  **Thirteenth instance of this plan's recurring defect, and it is mine.** New
  disguise: *taking a reviewer's claim for evidence*. Every dispatch this session
  told an implementer to verify claims against the tree; I did not apply it to a
  reviewer's. The eighth question follows: **did I verify this, or was I told it?**
FINAL REVIEW: triage of the deferred minors — three **stand** (Task 1's double
  `handleAt` on the bake path only; Task 3's dpr-2-only identity return, the branch
  being dpr-agnostic; Task 10's `_lastUsedFrame.entries`, never on a steady-state
  frame). Three were **already closed** and the reviewer verified each. Production
  surface (two test-only knobs plus the `debug*` getters) accepted as gates rather
  than conveniences, on the precedent of `VerticesDrawSink.debugPaint`.
FINAL REVIEW: fix wave dispatched (7 findings, one dispatch, sonnet).
FINAL REVIEW: fix wave (commit fffd853) re-reviewed — **all seven ADDRESSED**, no new
  breakage, no behaviour change beyond the F4 rename, engine package still free of
  Flutter and `dart:ui`.
FINAL REVIEW: **R22** — Ruling: **the fourth falsified comment is F1's residue, not a
  new finding, and finishing it completes the dispatched fix rather than opening a
  second wave.** `tile_comparison.dart:76-78` still says "`DraftCanvas` quantises the
  camera it hands the live path", which is the sentence F1 was dispatched to remove
  and which F1 removed from three other places. `measureTiledAgreement` never touches
  `DraftCanvas`; it quantises the camera itself at `:81` — **the very line F1's new
  text cites as proof the instrument does its own quantisation.** Leaving it would
  put the corrected comment's own evidence directly beneath a sentence asserting the
  opposite. Sent with one citation correction (`draft_canvas.dart:384-392` should be
  ~`392-402`). — Costs if wrong: one extra round on two comment lines. The skill's
  no-second-wave rule exists to stop spirals, and this is the first wave's own scope.
  **The reviewer found it because it was asked to judge, not to check** — "having
  read these six files, is there a fourth?" Three had been found by then, and the
  absence of a fourth would have been a hope rather than a result.
