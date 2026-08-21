# Plan 3e — final fix wave report

One wave, three findings from the whole-branch review, all three fixed on
`main` from `3940ea2`. Four named mutations, four kills. Suites green in all
three packages, both standing allocation gates green.

---

## Finding 1 (Critical) — `AddEntityCommand` never linked a fill

### Option chosen: **give `AddEntityCommand` a fill branch**, not a dedicated
### inverse for fill removal.

The brief offered both. The fill branch is the only one of the two that
closes the *whole* hole. The review's own last sentence on the finding is the
argument: "The same hole is reachable directly: any `AddEntityCommand`
carrying a fill record links nothing and the fill silently never paints." A
dedicated `RestoreFillCommand` would repair the undo path and leave the direct
path exactly as broken — a public command that adds a fill record and produces
an entity the painter cannot see, the cascade cannot find and `touched` never
names. It would also add a command class whose only caller is one branch of
another command, where the branch is four lines inside the command that
already owns "add one leaf entity".

`commands.dart:78` (`AddEntityCommand.apply`) now calls `_indexFill(target)`
for an `EntityKind.fill` record, after both stores are written. `_indexFill`:

- **links unconditionally** — including to a missing, unfillable,
  foreign-owner or inverted-handle boundary. That is the codec's
  `_rebuildFills` policy (`json_codec.dart:283-294`) and it is deliberate for
  the same reason: dropping the link silently discards the user's data, where
  `validate()` reports all four and the painter counts the skip. Undo
  therefore restores a malformed pair *exactly* as it was, unrepaired.
- **recomputes the boundary's triangulation rather than materialising it only
  when absent.** This is the part that is easy to get wrong and it is a real
  reachable path, not a hypothetical: `SetEntityGeometryCommand` refreshes the
  cache **only for boundaries that have fills**, so editing a boundary while
  its fill is removed leaves the old entry behind under that key. Restoring
  the fill "only if absent" would then hand it the stale entry — the exact
  bug this finding is about, moved one step later. Mutation F1b below is that
  variant, and a named test kills it.
- **drops the entry** when the boundary is now unfillable or has no cacheable
  triangulation (a circle, or a shape the ear clipper would not reduce), so a
  stale entry can never survive under a live key. The painter then counts a
  skip, which is the documented behaviour for that state.

`touched` stays `{record.handle}`: the boundary is not mutated, and the fill's
own box is what `SpatialIndex` re-derives.

### Test, and why the existing fixtures could not have caught it

`packages/jet_cad_2d/test/document/region_command_test.dart` gains four tests.
Every pre-existing fill-removal fixture removes the **boundary** (old lines
83, 213); removing the fill *alone* and undoing was untested, and an
entity-liveness assertion passes against the bug. The new tests assert on the
index — `fillsOf` and `trianglesFor` — and on the consequences:

- `undoing a fill-only removal restores the index, not just the record` —
  after undo, `fillsOf == [fill]`, `trianglesFor` has length 6, **and** a
  subsequent `SetEntityGeometryCommand` to an L refreshes to length 12 and
  names the fill in `touched`. That last half is the "indistinguishable from a
  fill that was never removed, including after a subsequent boundary edit"
  requirement.
- `a restored fill is a dependent again, so the cascade still sees it` — the
  later `RemoveEntityCommand(boundary)` must take the *cascade* branch, not
  the no-dependents branch that left the review's orphan.
- `a fill added back onto an edited boundary gets the new triangulation` —
  the staleness case, built through the public command path only.
- `a fill added directly is linked, not silently inert` — the direct hole,
  on a handle-inverted pair, which also proves linking is not repairing
  (`validate()` still reports `fillDrawOrderInverted`).

---

## Finding 2 (Important) — a removal whose inverse could not replay

### Option chosen: **refuse the removal.**

Precedent, and the escape. `RemoveEntityCommand`'s own n-ary branch already
refuses rather than half-handling, in the same method, for the same class of
reason ("inventing an n-ary inverse for it here would be untested
machinery"). The alternative — emitting a guaranteed-replayable inverse —
means a new command class that re-adds a *malformed* pair without checks, and
its own inverse, and its own tests: new machinery in a fix wave, to serve a
state that already has a lossless two-step escape.

That escape is what makes refusal cheap, and it is only lossless **because of
finding 1's fix**: removing the fill on its own is an ordinary
`RemoveEntityCommand`, it now undoes correctly through `AddEntityCommand`'s
fill branch, and it leaves the cascade with nothing to cascade. Verified
end-to-end (transcript below): the pair comes back with its link intact and
`validate()` still reporting the malformation.

The check lives in `AddRegionCommand.refusalReason`, a static that `apply`
itself now uses, so there is **one** copy of the rule. Two copies would drift,
and the drift is invisible until an undo throws. Handle collisions are
deliberately not part of `refusalReason` — handles are never reissued, so a
trio that is replayable now cannot become un-replayable by having its handles
taken; that check stays in `apply`.

`RemoveEntityCommand`'s single-dependent branch calls it **before anything is
written** and throws with the escape named:

```
Bad state: cannot remove boundary 13: 13 is not a fillable boundary, so undo
could not restore the pair; remove fill 12 first
```

Note this state is reachable **in-session**, not only from a malformed load:
`SetEntityGeometryCommand` documents making a live boundary unfillable ("the
painter then counts a skip"), so the test fixture needs no codec.

---

## Finding 3 (Important) — the oracle shared the painter's triangulation

### Option chosen: **the oracle triangulates for itself** (option 1), and the
### residual carve-out is recorded as well.

`reference_walk.dart`'s fill case no longer reads
`doc.fills.trianglesFor(boundary)` — the very map `draft_painter.dart:641`
reads. It checks the boundary kind, the point count and closedness itself
(exact comparison, stored-value rule) and calls `triangulateSimplePolygon` on
the boundary's own coordinates. Plan 3c's Ruling 28 is not reopened: the
residual/rebase route stays independently computed, as it already was.

The carve-out that remains is stated at the shared call and in the results
note: `triangulateSimplePolygon` itself is shared with the command that
populates the cache, so a defect **inside** the ear clipper appears identically
on both sides and no differential row can see it. What the oracle is now
independent of is the cache — its freshness, its presence, and the closedness
rule that decides whether an entry is written at all. That is what would have
caught the Critical.

Test: `the oracle triangulates for itself, so a wrong cache diverges` in
`packages/jet_cad_2d_flutter/test/fill_render_test.dart`. It runs a **control**
first (honest cache: painter and oracle agree, or the divergence proves
nothing), then plants a valid, in-range, *wrong* index list (`[0,1,2]` for a
square that needs two triangles) and asserts the two `FillPolygonOp`s disagree
and that the oracle's list equals a fresh triangulation of the boundary.
`FillPolygonOp.triangles` is part of `==`, so this is the comparison the
differential machinery already uses.

---

## Minor — recorded, no code changed

Added to `docs/superpowers/notes/2026-08-22-plan-3e-results.md`, in a new
`## Open items after the final fix wave` section, verbatim:

> - **A fill ignores its boundary's `EntityFlags.invisible`.** Neither
>   `DraftPainter._drawFill` nor `referenceWalk`'s fill case consults the
>   boundary entity's flags, so hiding an outline leaves its fill painted, with
>   no outline around it. Both backends and the oracle agree, so no differential
>   or golden row fires, and the spec is silent on what visibility means for an
>   entity that borrows another's geometry. **Recorded, not fixed** — deciding it
>   is a spec question (does a fill follow its boundary's visibility, or carry
>   its own?), and answering it in a fix wave would be inventing policy.

The same section records the triangulation carve-out from finding 3.

---

## Mutation transcripts

Method, every time: `cp` the file aside, apply the edit with a `python3`
exact-string replace, run the narrowest test file, `cp` the backup back, check
`git diff --stat`. **Never `git checkout`.** Applied and restored inside one
shell call each. Passing-test lines are filtered out of the pastes below
(`grep -vE "^00:0[0-9] \+[0-9]+: [a-z]"`); the counters (`+n -m`) are the
runner's own and are unedited.

### F1a — delete the fill branch from `AddEntityCommand.apply`

`- if (record.kind == EntityKind.fill) _indexFill(target);` — this is the
original defect, restored exactly.

```
00:00 +13 -1: undoing a fill-only removal restores the index, not just the record [E]
  Expected: [18]
    Actual: []
     Which: at location [0] is [] which shorter than expected
  the record alone is not a fill: the painter, the removal cascade and `touched` all read the link, not the store

  package:matcher                               expect
  test/document/region_command_test.dart 268:5  main.<fn>

00:00 +13 -2: a restored fill is a dependent again, so the cascade still sees it [E]
  Expected: null
    Actual: <0>
  with the link gone this took the no-dependents branch and left the fill orphaned -- the state the cascade exists to prevent

  package:matcher                               expect
  test/document/region_command_test.dart 296:5  main.<fn>

00:00 +13 -3: a fill added back onto an edited boundary gets the new triangulation [E]
  Expected: [18]
    Actual: []
     Which: at location [0] is [] which shorter than expected

  package:matcher                               expect
  test/document/region_command_test.dart 321:5  main.<fn>

00:00 +13 -4: a fill added directly is linked, not silently inert [E]
  Expected: [19]
    Actual: []
     Which: at location [0] is [] which shorter than expected
  an unlinked fill never paints and reports nothing

  package:matcher                               expect
  test/document/region_command_test.dart 346:5  main.<fn>

00:00 +14 -5: the refused removal has an escape, and the escape undoes cleanly [E]
  Expected: [18]
    Actual: []
     Which: at location [0] is [] which shorter than expected
  the malformed pair is restored exactly as it was, link included; validate() still reports it

  package:matcher                               expect
  test/document/region_command_test.dart 397:5  main.<fn>

00:00 +14 -5: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: a fill added back onto an edited boundary gets the new triangulation
  test/document/region_command_test.dart: a fill added directly is linked, not silently inert
  test/document/region_command_test.dart: a restored fill is a dependent again, so the cascade still sees it
  test/document/region_command_test.dart: the refused removal has an escape, and the escape undoes cleanly
  test/document/region_command_test.dart: undoing a fill-only removal restores the index, not just the record
```

**KILLED**, five named tests. (`[18]`/`[19]` are `Handle.toString`, decimal —
the same handles the messages print as hex `12`/`13`.)

### F1b — materialise the triangulation only when the entry is absent

`+ if (target.fills.trianglesFor(boundary) != null) return;` at the top of
`_indexFill`'s triangulation half. This is the *plausible* implementation, and
it is the one that would have shipped the Critical's payload one step later.

```
00:00 +15 -1: a fill added back onto an edited boundary gets the new triangulation [E]
  Expected: an object with length of <12>
    Actual: [3, 0, 1, 1, 2, 3]
     Which: has length of <6>
  materialising only when the entry is absent restores the fill onto the stale entry left behind by the edit

  package:matcher                               expect
  test/document/region_command_test.dart 322:5  main.<fn>

00:00 +18 -1: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: a fill added back onto an edited boundary gets the new triangulation
```

**KILLED.** `[3, 0, 1, 1, 2, 3]` is the *square's* triangulation, restored onto
an L — the review's failure shape exactly.

### F2a — delete the replayability check from the removal cascade

```
00:00 +16 -1: a fill added directly is linked, not silently inert [E]
  Expected: throws <Instance of 'StateError'>
    Actual: <Closure: () => void>
     Which: returned <null>

  package:matcher                               expect
  test/document/region_command_test.dart 355:5  main.<fn>

00:00 +16 -2: removing a boundary whose pair could not be restored is refused [E]
  Expected: throws <Instance of 'StateError'>
    Actual: <Closure: () => void>
     Which: returned <null>
  the cascade's inverse is an AddRegionCommand that would refuse an unfillable boundary, so undo would throw forever

  package:matcher                               expect
  test/document/region_command_test.dart 373:5  main.<fn>

00:00 +17 -2: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: a fill added directly is linked, not silently inert
  test/document/region_command_test.dart: removing a boundary whose pair could not be restored is refused
```

**KILLED**, two named tests, one per refusal reason (unfillable boundary;
inverted handles).

With F2a still applied, a throwaway probe (`dart run`, deleted in the same
shell call, never committed) reproduces the review's observation verbatim —
including its handle:

```
live entities after removal: []
canUndo: true
undo attempt 1: Bad state: 13 is not a fillable boundary  (canUndo still true)
undo attempt 2: Bad state: 13 is not a fillable boundary  (canUndo still true)
undo attempt 3: Bad state: 13 is not a fillable boundary  (canUndo still true)
```

The same probe on the fixed tree, extended with the escape route:

```
removal: Bad state: cannot remove boundary 13: 13 is not a fillable boundary, so undo could not restore the pair; remove fill 12 first
live entities: [0, 1]
after the escape and two undos: entities [0, 1], fillsOf(boundary)=[18], triangles=null
```

Both entities survive the refused removal; the two-step escape undoes cleanly
and restores the link, with no triangulation, because the boundary is still
unfillable.

### F3a — put the oracle back on the painter's cache

`- final triangles = triangulateSimplePolygon(...)` /
`+ final triangles = doc.fills.trianglesFor(boundary!);`

```
00:00 +4 -1: the oracle triangulates for itself, so a wrong cache diverges [E]
  Expected: not equals [0, 1, 2] ordered
    Actual: [0, 1, 2]
  an oracle that read the same cache would agree with the painter about a triangulation neither of them derived
00:00 +5 -1: Some tests failed.
```

**KILLED.** The control half of the test still passed under the mutation,
which is the point: the mutation is invisible on an honest cache and only the
planted one separates them.

`git diff --stat` was checked after every restore and matched the pre-mutation
state each time; `git status --porcelain` listed only the five intended files.

---

## Verification, all three packages

```
$ cd packages/jet_cad_2d && CI=true dart test
00:03 +777: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +777: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19 seconds.
```

771 before this wave, 777 after: six new tests.

```
$ cd packages/jet_cad_2d_flutter && flutter test
00:03 +276 ~1: .../test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:03 +277 ~1: All tests passed!
$ flutter test --tags golden
00:01 +29: .../test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:02 +29: All tests passed!
$ flutter analyze
No issues found! (ran in 1.2s)
$ dart format --output=none --set-exit-if-changed .
Formatted 49 files (0 changed) in 0.09 seconds.
```

276+1 skip before, 277+1 skip after: one new test. The skip is the
pre-existing one. **No golden was re-baselined** — the oracle change is
test-path only and the painter's output is unchanged.

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.9s)
```

### The two standing allocation gates, run on their own

```
$ cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=65ms
00:00 +3: All tests passed!

$ cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
00:02 +4: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +5: (tearDownAll)
00:02 +5: All tests passed!
```

Neither fix touches the frame path. `_indexFill` runs at command time only;
the oracle is not the painter and is not measured by either gate.

---

## Files changed

| File | Why |
| --- | --- |
| `packages/jet_cad_2d/lib/src/document/commands.dart` | finding 1 (`AddEntityCommand._indexFill`), finding 2 (`AddRegionCommand.refusalReason` + the cascade's pre-check) |
| `packages/jet_cad_2d/test/document/region_command_test.dart` | four tests for finding 1, two for finding 2 |
| `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` | finding 3: the oracle derives its own triangulation |
| `packages/jet_cad_2d_flutter/test/fill_render_test.dart` | one test for finding 3, with its control |
| `docs/superpowers/notes/2026-08-22-plan-3e-results.md` | the Minor, and finding 3's carve-out |

`CLAUDE.md` not amended. No `analysis_options.yaml`, no `project.pbxproj`.

---

## Concerns

1. **Refusal is a policy change with a user-visible edge.** A boundary that a
   `SetEntityGeometryCommand` has made unfillable while it still carries a fill
   can no longer be deleted in one step; the error names the two-step escape.
   Accepting a state you cannot undo out of is worse, but if the spec later
   wants one-step deletion here, the shape to add is a replayable
   restore-region inverse, and `AddRegionCommand.refusalReason` is already the
   single place that decides when it would be needed.
2. **The ear clipper stays uncovered by the differential**, by construction —
   recorded at the call site and in the results note, not papered over.
3. **`RemoveEntityCommand` on a fill still leaves the boundary's triangulation
   entry behind.** Harmless (nothing reads it while no fill names the boundary,
   and `_indexFill` recomputes rather than trusting it — F1b is the proof), and
   `FillIndex`'s own doc already calls this class of leftover "a leak, not a
   lie". Dropping it on last-unlink would be tidier and is not this wave's
   business.
