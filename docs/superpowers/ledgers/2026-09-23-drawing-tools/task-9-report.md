# Task 9 report — mutation testing, M-05a..z

## Summary

Fired all twenty-six named mutants from the brief's table, one at a time,
against their named test file(s), with `CI=true`. For each: `cp` the target
file to `.superpowers/sdd/2026-09-23-drawing-tools/mutation-backups/`, apply
the one edit by hand, run the named test file, paste the failing test names
and summary line, restore with `cp`, then `diff` the backup against the
restored file and confirm it printed nothing.

**Tally: 27 fired (26 named + one reviewer-noted second form of M-05w): 26
killed, 1 survived, 0 equivalent.**

All 26 named mutants (M-05a through M-05z) were killed by their named test.
The dispatch also asked for a second form of M-05w (self-snap applied to the
*resolved* point rather than gated behind "nothing else snapped") to be fired
honestly; it survives `polyline_tool_test.dart`'s PL8 for a fixture-geometry
reason explained below. Per the dispatch note this is logged as a finding,
not fixed — no test change was made in this task.

No code change survives this task. `git status --short` lists only the new
log file; `git diff --stat` shows no `.dart` change. Every mutation-backup
file diffs empty against the restored source (verified with a sweep over all
27 backups against their target files after the last restore).

Full per-mutant detail (file, edit, test, exact failure output, and the
M-05w′ survivor analysis) is in
`docs/superpowers/notes/plan-05-mutation-log.md`, which is the one file
committed by this task (commit `6d98d72`, "docs: Plan 05 mutation log --
M-05a..z").

## Deviations from the brief's literal mutant text

Per implementer-common.md ("If the brief's code must change to compile or to
pass, make the smallest change"), three mutants needed a small adjustment to
compile; each is called out in the log with its reasoning. Summarized here:

1. **M-05d** (`addDrafted`'s handle): the brief's literal text,
   `Handle(doc.entities.liveCount + ReservedHandles.firstFree)`, does not
   type-check — `ReservedHandles.firstFree` is a `Handle` (an extension type
   over `int`, not implicitly an `int`), and `int + Handle` has no `+`
   operator. Used `ReservedHandles.firstFree.value` to keep the same intent
   (a handle derived from population rather than the monotonic seed) while
   compiling. Still killed E3 (target) plus E2 and E4.

2. **M-05n**: the dispatch note warned that `planner_view.dart`'s root moved
   from a `Stack` to a `Flow` in Task 7. That change is one layer above
   `TextEntryOverlay` and does not touch its own internal `Stack` /
   `ListenableBuilder` structure, so the brief's mutant (substituting the
   placement's raw point for the camera-projected screen point in the
   `Positioned`) applied without further adaptation. Killed A7 as named.

3. **M-05u**: adapted per the dispatch note ("field rebuilt/keyed per camera
   change... adapt to the code as it stands"). Moved the field's
   construction inside the `ListenableBuilder`'s `builder` callback (instead
   of the stable `child:` parameter) and replaced the `const Key
   ('text-entry-box')` with `ValueKey(widget.camera.value
   .worldToScreenMatrix.e)`, matching the brief's literal instruction. This
   kills A7, but via the `corner()` helper's `find.byKey(const
   Key('text-entry-box'))` throwing "Found 0 widgets" — the literal key
   the test looks up by is exactly what the mutant replaces — rather than
   via the later `identical(EditableTextState...)` assertion Ruling 05-10
   describes. This is logged honestly as the actual failure mode; it is
   still a real kill caused by the exact edit specified.

4. **M-05p**: Ruling 05-15 (plan lines 95–227) gives the concrete two
   -command form directly; implemented as written (boundary executed
   inline via `ctx.execute`, fill returned as the command `commit` itself
   executes), adding `import 'dart:typed_data' show Float64List;` to
   `placement_tool.dart` since the payload literal needs it. Killed R3 and
   PL4 as named, both via `undoDepth` going from 1 to 2.

5. **M-05t**: needed `import 'text_geometry.dart';` in `drafting.dart` for
   `packTextAttrs`; otherwise applied as the brief's literal text. Killed E1
   and E7 as named.

6. **M-05c**: needed `import 'text_metrics.dart';` in `drafting.dart` for
   `kCapHeightRatio`; otherwise applied as the brief's literal text. Killed
   E7 as named.

None of these import additions or the `.value` accessor changed the
mutant's intent; each is reverted along with the rest of the file on
restore (confirmed empty diff).

## M-05w′ — the honest survivor

Ruling and dispatch context: the plan names one concrete form for M-05w
("run `resolveDragPoint` first and consult `selfSnap` only when
`_hover.objectKind == null && !_hover.grid`"), which was fired first and
killed PL8 cleanly (the polyline never closes — `ofKind(...).single` throws
"Bad state: No element" because self-snap is skipped once the anchor's
entity endpoint has already claimed the hover).

The dispatch separately asked to fire a second form a reviewer flagged:
self-snap consulted *unconditionally* after `resolveDragPoint`, but against
the **already-resolved** `_hover.point` rather than the raw click. That
form survives `polyline_tool_test.dart` in full (`00:00 +11: All tests
passed!`).

**Why it survives, concretely.** In PL8 the closing click sits 2 px from the
anchor's entity endpoint and 4 px from the polyline's own first vertex, both
inside the 10 px aperture. `resolveDragPoint` runs first and snaps
`_hover.point` to the nearer target (the anchor, at 2 px). The mutant then
asks `selfSnap(_hover.point, aperture)` — is the *anchor's endpoint* itself
within the aperture of the polyline's own first vertex? Because the fixture
places the first vertex only 6 px (screen) from the anchor's endpoint, and
6 px < 10 px aperture, that check also succeeds, so `selfSnap` still returns
the polyline's own vertex and the assertion `p.coords[6] is not kAnchorX`
holds anyway — coincidentally, not because the fix is correct. A fixture
where the polyline's own vertex sits outside the aperture of the nearer
entity endpoint (while the raw click stays inside the aperture of both)
would distinguish the two forms; PL8 does not do that today.

Per the dispatch's explicit instruction, no test or fixture change was made
in this task — this is recorded as a finding for a follow-up task, and the
survivor is logged with full reasoning in the mutation log's M-05w′ section.

## Gate check (sanity, not itself part of the brief's per-mutant procedure)

After the last restore and before writing the log, ran the engine's full
suite to confirm the tree is genuinely at its pre-mutation state:

```
cd packages/jet_cad_2d && CI=true dart test
...
00:03 +911: (tearDownAll)
00:03 +911: All tests passed!
```

911 passing (up from the plan's branch-point count of 894, consistent with
tests added across Tasks 1–8). `git status --short` after this run was
still clean (no `pub get`-driven `analysis_options.yaml` rewrite this time;
earlier `flutter test` invocations during the mutation runs did trigger a
`pub get` resolution message each time, but never modified any tracked
file — checked after every restore).

## Files touched by this task

- Created and committed: `docs/superpowers/notes/plan-05-mutation-log.md`
- Temporary, git-ignored, left in place per the brief's backup path (not
  committed, not touched by the "no code change survives" rule since they
  are outside `packages/` and `apps/`):
  `.superpowers/sdd/2026-09-23-drawing-tools/mutation-backups/*` — one file
  per mutant fired (27 total, including `placement_tool.dart.M-05w-prime`
  for the w′ variant).
- No `.dart` file under `packages/` or `apps/` differs from its
  pre-task state (verified by the backup-vs-target diff sweep above).

## Concerns

- None blocking. The one open item is the M-05w′ finding itself, which is
  by design not resolved in this task.

---

## Fix round 1 (Ruling T9-a)

The coordinator asked for PL8's fixture to be changed so both forms of
M-05w are killed, closing the M-05w′ finding above. This is a test-only
change.

### What changed

`packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`, PL8 ("its
own first vertex beats a nearer entity endpoint"):

- the first vertex moved from `anchor + Offset(6, 0)` to `anchor +
  Offset(13, 0)` — still placed with object snap toggled off, as before,
  but now 13 px from the anchor's entity endpoint, **outside** the 10 px
  aperture;
- the closing click moved from `anchor + Offset(2, 0)` to `anchor +
  Offset(5, 0)` — 5 px from the anchor and 8 px from the first vertex,
  both still inside the aperture;
- the two comments were updated to state the new distances and to name
  Ruling T9-a;
- the assertions are unchanged: the polyline closes
  (`isClosedPolyline(p)` true) and `p.coords[6]` is not `kAnchorX`.

This is exactly the geometry the coordinator specified: with the first
vertex outside the aperture of the anchor, a self-snap check applied to
the *resolved* (already-snapped-to-the-anchor) point can no longer reach
the first vertex, which is what let M-05w′ survive before.

### Step 2 — confirmed PL8 green on clean code

```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/polyline_tool_test.dart
...
00:00 +9: PL8 its own first vertex beats a nearer entity endpoint (M-05w)
00:00 +10: PL9 Escape with three vertices placed is byte-identical (M-05l)
00:00 +11: All tests passed!
```

### Step 3 — re-fired both mutants

**M-05w** (the plan's form: `resolveDragPoint` first, `selfSnap` only when
`_hover.objectKind == null && !_hover.grid`), re-applied to
`packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart` after a
fresh `cp` backup (`placement_tool.dart.M-05w-refire`):

```
00:00 +9 -1: PL8 its own first vertex beats a nearer entity endpoint (M-05w) [E]
  Bad state: No element
  dart:core                                 List.single
  test/draw/polyline_tool_test.dart 172:71  main.<fn>

Failing tests:
  .../test/draw/polyline_tool_test.dart: PL8 its own first vertex beats a nearer entity endpoint (M-05w)
```

Restored from the backup; `diff` printed nothing.

**M-05w′** (self-snap applied to the resolved point:
`selfSnap(_hover.point, aperture)`, unconditional), re-applied after a
fresh `cp` backup (`placement_tool.dart.M-05w-prime-refire`):

```
00:00 +9 -1: PL8 its own first vertex beats a nearer entity endpoint (M-05w) [E]
  Bad state: No element
  dart:core                                 List.single
  test/draw/polyline_tool_test.dart 172:71  main.<fn>

Failing tests:
  .../test/draw/polyline_tool_test.dart: PL8 its own first vertex beats a nearer entity endpoint (M-05w)
```

Both forms now fail identically: the raw click is 5 px from the anchor and
8 px from the first vertex, so `resolveDragPoint` still snaps the click to
the (nearer) anchor endpoint first, unaffected by either mutant. What
differs is what each mutant does next — M-05w skips `selfSnap` entirely
once `resolveDragPoint` has set `_hover.objectKind`; M-05w′ calls
`selfSnap(_hover.point, aperture)`, checking the anchor's endpoint against
the first vertex. That distance is now 13 px, outside the 10 px aperture,
so M-05w′'s `selfSnap` also returns null. Either way self-snap never
fires, the click is appended as an ordinary fourth vertex instead of
closing the shape, nothing commits, and `ofKind(...).single` throws on the
empty list. Restored from the
backup; `diff` printed nothing.

### Step 4 — updated the log

`docs/superpowers/notes/plan-05-mutation-log.md`:

- tally line changed to "27 fired: 27 killed, 0 survived, 0 equivalent",
  with a new note under it pointing at the fix-round-1 detail;
- M-05w's entry gained a "Re-fire (fix round 1, Ruling T9-a)" paragraph
  with the new RED output (same failure shape, line number moved from
  170:71 to 172:71 because the fixture's comments grew by two lines);
- M-05w′'s entry was restructured into "First fire ... SURVIVED" (the
  original Task 9 result, reasoning preserved) followed by "Fix round 1
  ... fixture changed, re-fired, KILLED" with the new RED output and the
  reasoning for why the new distances distinguish the two forms;
- a new "## Fix round 1 (Ruling T9-a)" section at the end summarizes the
  fixture change and the re-fire outcome.

### Step 5 — gate line

```
cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:12 +911 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

911 total (1 skip), failing exactly the five pre-existing
`text_ladder_golden_test.dart` goldens named as the standing exception in
implementer-common.md — no new failures.

```
flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.6s)

dart format --output=none --set-exit-if-changed test/draw/polyline_tool_test.dart
Formatted 1 file (0 changed) in 0.01 seconds.
```

Exit codes 0 for both.

### Step 6 — commit

`git status --short` before the commit showed exactly the two touched
files:

```
 M docs/superpowers/notes/plan-05-mutation-log.md
 M packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart
```

Committed both together as `5c55000` "test(draw): PL8's fixture kills both
forms of M-05w (Ruling T9-a)". `git status --short` after the commit is
clean.

### Verification of "no code change survives"

After both re-fires, restored from the fresh backups and diffed empty
each time; `placement_tool.dart` in the final tree is byte-identical to
its pre-round-1 state (only the test file and the log are different from
the original Task 9 commit).

### Concerns

None. The M-05w′ finding from the original Task 9 report is now closed:
both forms of M-05w are killed by PL8's updated fixture.
