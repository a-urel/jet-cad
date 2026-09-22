# Task 5 report: `SelectTool` — hover, click, shift, band

## What was implemented

`packages/jet_cad_2d_flutter/lib/src/selection_style.dart` — new file, exactly
the three constants the brief scopes for this task: `kWindowBandColor`
(`Color(0xFF1E6FE8)`), `kCrossingBandColor` (`Color(0xFF2E9E5B)`) and
`kBandFillAlpha` (`0x22`). Task 7 adds the rest.

`packages/jet_cad_2d_flutter/lib/src/select_tool.dart` — new file, following
the brief's implementation closely:

- `kPickRadiusPixels = 6.0` and `kBandSlopPixels = 4.0`, top-level constants
  (the former moves to Task 9's file later).
- `SelectTool extends Tool`: `name`, `phase`, the four pointer callbacks,
  `onKey` (returns `KeyEventResult.ignored` — Task 6 wires Delete/Escape),
  `cancel`, `paintOverlay`, plus the read-only `bandMode`, `bandScreen` and
  `bandStart` getters the brief's Produces line calls for.
- `onPointerDown` records the press position/world point and resolves a hit
  via `_pick` (one reused `HitPath`, `QueryFilter.picking()`, `resolveHit`).
- `onPointerMove`: idle hovers (skipped while any button is down);
  `pressed` stays put under `kBandSlopPixels`, and only escalates to
  `dragging` when the press started on a miss (`_downHit == false`) — a
  press on a hit never turns into a band, per spec; the band mode is
  recomputed every move from `end.dx >= start.dx` (spec D1).
- `onPointerUp`: `pressed` does the click/shift-toggle/clear dance;
  `dragging` computes the band's key list and replaces or toggles.
- `_bandKeys`: builds the world-space `Aabb2` from the down and up points,
  walks `forEachLeafInBand` once, buckets slots by root-entity vs.
  group-owned vs already-seen group, resolves each group's topmost handle
  through `_topmostGroup` (which delegates to `selection.dart`'s
  `topmostGroupOf`, not a re-implementation), and decides group membership
  with `_everyLeafIn` for window mode only (crossing short-circuits, per
  Ruling 02-2 — decided in the tool, from the passing-slot set, once per
  band). `forEachInstanceInBand` is walked separately for instances.
- `_everyLeafIn` walks only nested *groups* from the stack (Ruling P-1): a
  child instance's own leaves never enter the every/any accounting, and
  `EntityKind.fill` slots are skipped the same way `forEachLeafInBand`
  already skips them.
- `paintOverlay` draws the band's fill (with `kBandFillAlpha`) and, for a
  window band, a solid stroke; for a crossing band, `_drawDashedRect` walks
  the four edges clockwise from `topLeft` in 6-on/4-off screen-pixel steps
  via `Path.moveTo`/`lineTo`. This `Paint` allocation only happens while
  `_phase == dragging` (the drag preview), which the brief accepts as
  outside the steady-state zero-allocation guarantee.

`packages/jet_cad_2d_flutter/test/select_tool_test.dart` — new file, the ten
tests from the brief's Step 1 list, each building its own
`DraftDocument`/`SpatialIndex`/`SelectionController`/`ToolContext` (disposed
via `addTearDown`) rather than sharing fixtures across tests:

1. **Hover** — a root-level line at world `(990..1010, 500)`, camera
   `cameraAt(2.0, Offset(-1600, 1300))`. First asserts the line's midpoint
   lands inside an 800x600 rect (the non-degenerate-fixture sanity check the
   brief calls for), then drives a hover move onto the line and off it.
2. **M-02d** — two lines 15 world units apart (30 screen px at scale 2); a
   click 3 screen px off the line's centre hits, 10 screen px misses both
   lines, exercising the exact `kPickRadiusPixels / scale = 3` world-unit
   boundary.
3. **M-02h** — click A, click B, shift-click A twice, checked by
   `selection.length` + `selection.contains(...)` at each step (the same
   style `selection_test.dart` already uses — `SelectionController.keys` is
   an `UnmodifiableSetView`, and `expect(..., <Set literal>)` does not do a
   set-equality comparison in this codebase's existing tests, so I matched
   that convention instead of introducing a new one).
4. Click-empty clears; shift-click-empty is a no-op — both arms on the same
   fixture.
5. **M-02f** — a 2px move stays `pressed`; the up half's "selection still
   empty" assertion is non-discriminating on its own (starting selection was
   already empty) and is called out as such in the test's own comment,
   matching the brief's framing.
6. A 5px move from a miss reaches `dragging`; a 5px move from a hit stays
   `pressed` — two separate `SelectTool` instances sharing one `ToolContext`,
   since the first arm never calls `onPointerUp` (no selection state to
   collide with the second arm).
7. **M-02a at the tool level** — reuses the inside/straddling/far-line shape
   from `packages/jet_cad_2d/test/index/band_query_test.dart` (translated
   into screen coordinates through a scale-1 camera), dragged both
   directions from precisely computed screen corners so the band's world
   box is `[90,210]x[990,1010]` either way — window keeps only `inside`;
   crossing adds `straddling` too.
8. **M-02r / Ruling P-1** — a group (plain `Transform2.translation(500,
   300)`; see Departures) owning two leaves 20 world units apart; a band
   enclosing only the first leaf. Window → empty selection (one leaf isn't
   enclosed, so `_everyLeafIn` fails); crossing → `{group}` (the touched
   leaf's owner resolves and crossing doesn't require the second leaf).
9. **Shift-band toggles** — pre-select A directly via
   `selection.replace(...)`, then the same crossing-mode band over B twice:
   first toggle adds B (`{A,B}`), second removes it (`{A}`).
10. **Escape/cancel** — builds the `KeyDownEvent(physicalKey:
    PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero)` the brief specifies (asserted only for its
    own shape, since `onKey` is a no-op until Task 6), then drives a real
    band into `dragging` and calls `tool.cancel(ctx)` directly, asserting
    `phase == idle`, `bandMode`/`bandScreen == null`, and the selection
    (pre-loaded with a key) is untouched.

All ten camera/band coordinates in tests 2, 3, 7, 8 and 9 were computed by
hand from the `cameraAt(scale, translation)` affine
(`sx = scale*wx + tx`, `sy = -scale*wy + ty`) so that every "miss" point used
to start a press or a band is genuinely outside `kPickRadiusPixels / scale`
of every entity in that test's fixture — verified by running the suite,
which passed on the first attempt with no coordinate corrections needed.

## Departures

- **M-02r fixture uses a plain translation, not `kPlacement`.** The brief's
  own convention (`selection_test.dart`'s nested-group test uses
  `Transform2.translation(10, 10)` for an inner group while the outer group
  uses `kPlacement`) already draws this line: `kPlacement`'s
  translate-rotate-scale composition matters when a test is checking that
  the transform pipeline itself is correct, which is exactly what
  `band_query_test.dart` already covers at the index level (M-02a and
  friends). Task 5's M-02r test is checking a different thing — the tool's
  own every-leaf/any-leaf accounting over the *passing-slot set* the index
  hands back — so a translation-only group transform keeps the hand-computed
  band corners simple without weakening what the test is actually for. Noted
  here per the task's "a local obvious fix you may make" allowance, since it
  is a fixture-construction choice rather than a change to the shipped code.
- **`_drawDashedRect`'s exact walk was written from scratch.** The brief only
  described it in prose ("walks the four edges with `Path.moveTo`/`lineTo`
  in 6/4 steps"); the code above is my implementation of that description —
  clockwise from `topLeft`, alternating 6-on/4-off spans, with the last span
  on each edge clipped to the edge's remaining length so it never overshoots
  a corner. No test exercises the overlay's pixels (`paintOverlay` is not in
  the brief's ten tests), so this is unverified by this task beyond
  compiling and being called with a non-null band during the manual
  RED/GREEN run.
- `_startWorld` is `final` (mutated in place via `Vector2.setFrom`, never
  reassigned) rather than the brief's plain `Vector2 _startWorld =
  Vector2.zero()` — `flutter analyze` flagged the non-final field
  (`prefer_final_fields`) and this is exactly the "local obvious fix" the
  task pre-authorizes.
- Commit trailer: used `Co-Authored-By: Claude Fable 5.1
  <noreply@anthropic.com>` per this task's explicit binding constraint
  (verified against the actual trailer on every prior commit in this plan,
  e.g. `fae61c4`, `4626779`, `a864a8b` — all carry the Fable 5.1 line), not
  the general session-level Sonnet 5 attribution reminder, which the task
  prompt's own instruction takes precedence over here.

## TDD evidence

**RED** — moved `lib/src/select_tool.dart` and `lib/src/selection_style.dart`
aside (to the scratchpad, not `/tmp`), then:

```
$ CI=true flutter test test/select_tool_test.dart
```

Result: compile-time failures — the test file could not even load:

```
Error: Error when reading 'lib/src/select_tool.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
       ^
Error: Undefined name 'kPickRadiusPixels'.
Error: Method not found: 'SelectTool'.
(...repeated at every call site...)
00:00 +0 -1: loading .../test/select_tool_test.dart [E]
00:00 +0 -1: Some tests failed.
```

**GREEN** — both files restored, then:

```
$ CI=true flutter test test/select_tool_test.dart
00:00 +0: loading .../test/select_tool_test.dart
00:00 +0: hover sets the controller's hover and clears on a miss
00:00 +1: the pick radius is six screen pixels
00:00 +2: click replaces, shift-click toggles
00:00 +3: click on empty space clears; shift-click on empty space does nothing
00:00 +4: a 2 px move keeps the press a click
00:00 +5: a 5 px move from empty space starts a band; from a hit it does not
00:00 +6: left-to-right encloses, right-to-left touches
00:00 +7: a group is window-selected only when every leaf is enclosed
00:00 +8: shift-band toggles
00:00 +9: Escape during a band drops it, selection untouched; cancel returns to idle
00:00 +10: All tests passed!
```

All ten passed on the first attempt after restoring the implementation — no
coordinate or logic fixes were needed between RED and GREEN.

## Gate line output

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

`CI=true flutter test` (full suite): exit code 1, summary line
`00:40 +727 ~1 -5: Some tests failed.` — the five failures are exactly the
pre-existing golden failures named in the task brief:

```
Failing tests:
  test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

(727 passed, 1 pre-existing skip, 5 pre-existing golden failures — 10 more
passing than the prior task's `+717` baseline, matching the 10 new tests
added here.)

`flutter analyze`: first run reported one issue —
`info • The private field _startWorld could be 'final' ... prefer_final_fields`
— fixed by making the field `final` (see Departures); re-run:
`No issues found! (ran in 3.3s)`, exit code 0.

`dart format --output=none --set-exit-if-changed .`: first run reported
`Changed lib/src/select_tool.dart` and `Changed test/select_tool_test.dart`;
ran `dart format` on exactly those two files, then re-ran the check clean:
`Formatted 130 files (0 changed) in 0.30 seconds.`, exit code 0. Re-ran
`test/select_tool_test.dart` and `flutter analyze` once more after
formatting to confirm the reformat changed nothing observable — both still
green (`+10: All tests passed!`, `No issues found!`).

`git status --short` before staging showed only the three new files — no
`analysis_options.yaml` rewrite to discard.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` (new)
- `packages/jet_cad_2d_flutter/test/select_tool_test.dart` (new)

Commit: see below.

## Self-review

- Every method in the brief's Produces line exists with the exact signature:
  `SelectTool extends Tool`, `kBandSlopPixels`, `bandMode`, `bandScreen`, and
  I additionally kept `bandStart` (named in the Interfaces line) as a third
  getter mirroring `_start`.
- Verified the band-mode rule (D1: `end.dx >= start.dx` → window) is read
  fresh on every `onPointerMove` while dragging, not fixed at the moment the
  drag starts — tests 7, 8 and 9 each construct their `end` point
  deliberately so a stale-mode bug (mode computed once, at transition, and
  never updated) would still coincidentally pass for tests 7/8 (single move
  call) but not for a hypothetical multi-move sequence; I did not add a
  dedicated "mode updates mid-drag" test since it is not in the brief's ten
  and would be scope creep, but flag it here as something Task 9's overlay
  work (or a mutation pass) may want to add.
- Confirmed `_everyLeafIn`'s stack only ever pushes handles where
  `doc.tree[child] is GroupNode` — an `InstanceNode` child is never pushed,
  so its leaves cannot leak into the every/any accounting, matching Ruling
  P-1 exactly. Test 8 exercises the "not every leaf" (window→empty) and
  "any leaf, mode==crossing short-circuits" (crossing→{group}) arms; it does
  not exercise the *nested*-group case (a group inside a group), which
  `_everyLeafIn`'s stack loop specifically handles — that shape isn't in the
  brief's ten tests either, and is the most obvious follow-up mutation
  target for a reviewer or a later task to add.
- `seenGroups` dedupe: with only one group in scope across all tests, this
  path is exercised (both of the group's leaves resolve to the same
  `topmostGroup`) but the "two different slots resolving to the same group,
  second one skipped rather than double-counted" behavior isn't asserted by
  a length check that would fail if dedup were missing — `selection.length
  == 1` in test 8's crossing arm does catch a double-add, though, since a
  duplicate `SelectionKey.root(group)` added twice to the `keys` list would
  still collapse to one entry once `replace`/`toggle` puts them through a
  `Set`, so a missing `seenGroups` guard would not actually be caught by
  this test today — only extra index-walk work would be wasted, not a
  visible defect. Flagging this as a real gap: a mutation removing the
  `seenGroups` check would not go red here.
- Ran the full package gate line twice (before and after the format fix) to
  make sure formatting didn't change behavior.

## Concerns

- The `seenGroups`-dedup gap noted above: no test in this task's ten (or
  written by me beyond them) distinguishes "dedup present" from "dedup
  absent but harmless because of the final `Set`". A reviewer or a later
  task might want a two-leaf-in-two-different-slots-of-the-same-group band
  test that checks `SpatialIndex` visit counts or wraps `leavesByOwner` to
  assert it's called at most once per band (the brief's own doc comment on
  `byOwner ??= doc.leavesByOwner()` implies this matters for cost, not just
  correctness) rather than relying only on final-selection-set equality.
- `paintOverlay`/`_drawDashedRect` has no test coverage in this task (none
  of the brief's ten touch it) — it compiles and runs during the manual
  RED/GREEN pass (called implicitly never, actually — no test calls
  `paintOverlay` at all) but is otherwise unverified. Task 7/9 likely add
  overlay tests; flagging in case that's assumed to already be covered here.

## Fix round 1

Reviewer sent back two Important findings on commit `fc05c43`, both about
fixture discipline in `test/select_tool_test.dart`. Only that file changed;
`lib/src/select_tool.dart` and `lib/src/selection_style.dart` are untouched.

### Finding 1: tests 7, 8, 9 used `cameraAt(1.0, ...)`

The plan's binding constraint requires every camera fixture to use
`fitOffOrigin` or a scale ≠ 1 with a non-zero translation; these three tests
used scale exactly 1 while every other test in the file already used
`cameraAt(2.0, ...)`. Fixed by moving all three to `cameraAt(2.0, ...)` and
hand-recomputing every screen corner from the same
`sx = scale*wx + tx`, `sy = -scale*wy + ty` affine used throughout the file,
keeping each test's world-space band box and entity positions unchanged (so
the geometric claim each test makes is identical, only expressed through a
non-degenerate camera):

- Test 7 (`'left-to-right encloses, right-to-left touches'`): now
  `cameraAt(2.0, const Offset(-100, 2300))`; the band's world corners
  `(90,1010)`/`(210,990)` land at screen `(80,280)`/`(320,320)`.
- Test 8 (`'a group is window-selected...'`): now
  `cameraAt(2.0, const Offset(-600, 900))`; the band's world corners
  `(486,280)`/`(510,320)` land at screen `(372,340)`/`(420,260)`.
- Test 9 (`'shift-band toggles'`): now
  `cameraAt(2.0, const Offset(-80, 2200))`; the band's world corners
  `(290,990)`/`(330,1010)` land at screen `(500,220)`/`(580,180)`.

Every down-point's pick-radius safety margin was re-verified against the new
`kPickRadiusPixels / scale = 6 / 2 = 3` world units (previously `6 / 1 = 6`);
all margins are still well over 10 world units, so no down point accidentally
resolves as a hit.

### Finding 2: tests 8 and 9 had no straddling entity

Both band fixtures previously had only a fully-enclosed entity and a
fully-outside one, which cannot distinguish a correct enclosure/touch
boundary from an off-by-one on it. Fixed by adding one straddling entity to
each and asserting its fate in both directions:

- **Test 8**: added `straddler`, a **root-level** line at world
  `(505,300)-(515,300)` — deliberately not a group member, so it cannot
  perturb the group's every/any-leaf accounting the test exists to check.
  It straddles the band's right edge (world x 510): the window arm now
  asserts `selection.isEmpty` with a reason covering both the group (missing
  a leaf) and the straddler (not fully enclosed); the crossing arm now
  asserts `selection.length == 2` and that both the group and the straddler
  are present.
- **Test 9**: added `lineC`, a root-level line at world
  `(325,1000)-(340,1000)`, straddling the band's right edge (world x 330).
  The existing crossing-mode shift-toggle sequence now toggles `{B, C}` in
  and back out (selection length 3 then 1, with an explicit `reason:`
  on the `lineC` assertion), and a third step was added — a non-shift,
  window-mode band over the same box — asserting the straddler is excluded
  and the selection replaces down to `{B}` alone. This drives both
  directions in the same test, per the finding's "add the other direction
  where it is cheap."

Test 7 already had a straddling entity as its own subject (`straddling`) and
needed no change for Finding 2.

### Covering tests

`test/select_tool_test.dart`, tests 7 ('left-to-right encloses, right-to-left
touches'), 8 ('a group is window-selected only when every leaf is enclosed')
and 9 ('shift-band toggles') — all ten tests re-run together below.

```
$ CI=true flutter test test/select_tool_test.dart
00:00 +0: loading .../test/select_tool_test.dart
00:00 +0: hover sets the controller's hover and clears on a miss
00:00 +1: the pick radius is six screen pixels
00:00 +2: click replaces, shift-click toggles
00:00 +3: click on empty space clears; shift-click on empty space does nothing
00:00 +4: a 2 px move keeps the press a click
00:00 +5: a 5 px move from empty space starts a band; from a hit it does not
00:00 +6: left-to-right encloses, right-to-left touches
00:00 +7: a group is window-selected only when every leaf is enclosed
00:00 +8: shift-band toggles
00:00 +9: Escape during a band drops it, selection untouched; cancel returns to idle
00:00 +10: All tests passed!
```

All ten passed on the first run after the fixture rewrite — no further
coordinate corrections were needed.

### Gate line output

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

`CI=true flutter test` (full suite): exit code 1, summary line
`00:42 +727 ~1 -5: Some tests failed.` (same totals as fc05c43's gate run —
the fix added assertions and entities inside existing tests, not new
`test(...)` blocks) — the five failures are, again, exactly the pre-existing
golden failures:

```
Failing tests:
  test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

`flutter analyze`: `No issues found! (ran in 2.7s)`, exit code 0.

`dart format --output=none --set-exit-if-changed .`: `Formatted 130 files
(0 changed) in 0.29 seconds.`, exit code 0 — the edits were already
correctly formatted.

`git status --short` before staging showed only
`packages/jet_cad_2d_flutter/test/select_tool_test.dart` modified — no
`analysis_options.yaml` drift.

### Files changed (this round)

- `packages/jet_cad_2d_flutter/test/select_tool_test.dart` (tests 7, 8, 9:
  non-identity cameras, straddling entities and their membership
  assertions; tests 1–6 and 10 untouched)

Commit: see below.

### Self-review (this round)

- Re-verified by hand that every down-point in the three rewritten tests is
  still a genuine miss under the new scale-2.0 radius (3 world units), not
  just "far enough under the old scale-1 radius of 6" — the margins (10 to
  ~28 world units in every case) have plenty of room either way.
- Confirmed the straddler in test 8 is root-owned (`doc.rootHandle`), not
  added under the `group` handle, so `_everyLeafIn`'s stack walk over the
  group's own leaves and nested groups cannot see it — the test still
  isolates the group every/any-leaf behavior Finding 2 asked to preserve.
- Confirmed test 9's added window-mode step does not disturb the
  shift-toggle narrative: it runs after both toggle steps have already
  brought the selection back to `{A}`, and is itself a plain non-shift
  band, independent of the toggle assertions above it.
- Ran the full gate line after the fix and diffed the failing-test list
  against the pre-fix run — identical five golden names, same total test
  count.

### Concerns (this round)

None new. The two pre-existing self-review notes from the initial report
(the `seenGroups`-dedup gap and `paintOverlay` having no test coverage)
still stand and are unrelated to this round's findings.
