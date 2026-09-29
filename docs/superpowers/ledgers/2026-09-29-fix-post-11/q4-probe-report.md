# Q4 probe report: why a panel-legal wall thickness throws at turned placements

Investigator, detached worktree `fix-post-11-probe` at `a025c2f`. Nothing
committed or pushed. At the end `git status --short` and `git diff --stat`
are empty. The two lib files patched for the experiment in §4 were restored
from scratch copies, and `diff` against the copies came back empty. The one
`analysis_options.yaml` that `flutter pub get` rewrote
(`packages/jet_cad/analysis_options.yaml`) was restored from a backup.
Every test command ran with `CI=true`. The probe sources and their raw
outputs are in the scratchpad (list at the end). The probe test files were
deleted from the worktree.

## TL;DR

- **The panel catches it.** Typing 1e100 or 1.5e154 into a wall's
  Thickness field (by Enter or by focus loss) is refused silently. The
  field goes back to "200", the document and history are unchanged, and
  nothing reaches `FlutterError`. There is also no message to the user.
- **The Wall tool does not catch it.** Typing 1e100 into the tool's
  settings without pressing Enter, then drawing a non-axis-aligned wall,
  throws `ArgumentError` out of the pointer handler. It lands in
  `FlutterError` ("while dispatching a pointer event", gesture library).
  No wall is added, but the handle seed is consumed, and the chain stays
  pending on its first point. An axis-aligned wall at 1e100 is **accepted
  and stored**.
- **Two separate mechanisms**, both ending at the unchecked local
  free-rectangle fallback in `localOutlineOf`
  (`wall_geometry.dart:468-483`), which the planner's `_checkRegion` then
  refuses:
  - **A, precision collapse** (the found item). The wall's width `L` falls
    below an ulp of its own corner coordinates (about `t`). The four
    corners round to two distinct points, and every value stays finite.
    **This is not overflow**: for a 3 m wall at 30° it starts at t ≈
    1.48e20. It needs a local direction that is not axis-aligned. The
    smallest ratio measured is **t/L ≥ 1.15e16**, and the smallest
    thickness that throws at any length > `wallJoin.linear` is **1.33e10
    mm**. No thickness ≤ 1e10 mm throws through A anywhere.
  - **B, cancellation in the absolute-coordinate shoelace** (new, not in
    the finding). This one is reachable with **ordinary** thicknesses when
    the wall is short and far from the origin. Both `isSimpleCcw`'s
    `signedArea` (app) and the triangulator's `_signedArea` (engine) sum
    `x·y` products of absolute coordinates. Far from the origin, the
    rounding error (about eps·|X·Y|) swamps the true area `t·L`. Example:
    a 0.01 mm × 150 mm wall at 1e9 has shoelace −64.0 against a true 1.5.
    The triangulator then reverses a correctly wound ring, finds no ear,
    and the edit is refused. Within 10 km of the origin, only walls
    shorter than about 1e-4 mm throw. At 100 km the limit is about
    0.01 mm, and at UTM-like mm coordinates it is up to about 3 mm long.
- **Recommendation: (i)**, an upper bound in `isWallThickness`. I suggest
  1e7 mm, with the derivation in §4. Also record B as a separate found
  item, whose fix is a vertex-relative `_signedArea` in the engine
  (measured to remove B with zero suite regressions). Killing mutant for
  (i): `M-q4-noUpperBound`.

## 1. What the user sees

Probe `q4p-panel2_test.dart` uses the shell over `selection_panel_test`'s
`panelDoc`: wall A sits in its own rotated group at the far origin, and the
plan is turned 23°. Each value runs on a fresh shell. Pasted:

```
PROBE "1e100" by Enter: exception=null; FlutterError reports=0; field "200"; stored thickness 200.0; doc unchanged=true; undoDepth=0; diagnostics []
PROBE "1e100" by focus loss: exception=null; FlutterError reports=0; field "200"; stored thickness 200.0; doc unchanged=true; undoDepth=0; diagnostics []
PROBE "1.5e154" by Enter: exception=null; FlutterError reports=0; field "200"; stored thickness 200.0; doc unchanged=true; undoDepth=0; diagnostics []
PROBE "1.5e154" by focus loss: exception=null; FlutterError reports=0; field "200"; stored thickness 200.0; doc unchanged=true; undoDepth=0; diagnostics []
PROBE "1e20" by Enter: exception=null; FlutterError reports=0; field "9223372036854775807"; stored thickness 9223372036854776000.0; doc unchanged=false; undoDepth=2; diagnostics [wall.fallback, wall.fallback]
PROBE    undo chain thicknesses: [100000000000000000000.0, 200.0]
PROBE "1e20" by focus loss: exception=null; FlutterError reports=0; field "9223372036854775807"; stored thickness 100000000000000000000.0; doc unchanged=false; undoDepth=1; diagnostics [wall.fallback, wall.fallback]
PROBE "1e7" by Enter: exception=null; FlutterError reports=0; field "10000000"; stored thickness 10000000.0; doc unchanged=false; undoDepth=1; diagnostics [wall.fallback, wall.fallback]
```

- **The wall edit is caught.** `_commit` catches `ArgumentError`
  (`selection_panel.dart:463-470`, 07 D11's WS9 amendment). The field
  reverts, the document is byte-identical and history is unchanged. There
  is no status message and no invalid state on the field: the user sees
  only the revert.
- **A side defect** (found, not part of A or B): `_number` in
  `selection_panel.dart` calls `v.round().toString()`, which saturates on
  the VM at 2^63−1 for |v| ≥ 2^63.
  - The field shows "9223372036854775807" for 1e20.
  - After Enter, the focus-loss commit re-parses that text. It writes a
    **second, silent undo step** storing 9.223372036854776e18 (undoDepth
    2).

The Wall tool's settings were tested with probes `q4p-panel2` (P2a, P2b)
and `q4p-panel3` (P3a):

```
PROBE after typing: settings 1e+100; field "1e100"
PROBE click 2 (diagonal, ~1504 mm): exception Invalid argument(s): 1455 generated a region whose boundary is not a closed polyline with a non-empty triangulation (spec 07 D8) (ArgumentError); FlutterError reports 1; walls 3 (was 3); doc unchanged=false; undoDepth=0; points [[4500020.0,1200980.0]]; status "Wall"
PROBE click 3 at the same point: exception Invalid argument(s): 1456 generated a region ... (spec 07 D8); walls 3; points [[4500020.0,1200980.0]]
PROBE FlutterError: Invalid argument(s): 1455 generated a region ... (spec 07 D8) | context: while dispatching a pointer event | library: gesture library
PROBE axis-aligned 500 mm at 1e100: exception null; walls 4 (was 3); last WallParams((4502600.0, 1201500.0) -> (4503100.0, 1201500.0), 1e+100, centre); undoDepth 1; diagnostics []
PROBE what a refused click changed in the file: [handleSeed: 5208 -> 5209]
PROBE after Enter: settings 9223372036854776000.0; field "9223372036854775807"
```

- **Where it escapes.** `PlacementTool.commit` calls `ctx.execute`
  unguarded (`placement_tool.dart:229-235`). `onPointerDown` has only a
  `finally`. So the throw reaches the gesture binding and `FlutterError`.
  - History is unchanged.
  - The file does change: `handleSeed` is consumed by
    `doc.handleSeed.next()` in the build closure, outside the rolled-back
    command.
  - The chain stays pending, and every further click throws again.
- **Enter launders the value.** With Enter, the `_number` saturation
  changes the setting to 2^63 (9.22e18). The walls I then drew landed,
  with no throw. That value still sits above A's threshold for walls
  shorter than about 9.22e18 / 1.15e16 ≈ 800 mm at unlucky angles.
- **An absurd wall is accepted.** An axis-aligned 1e100 wall is stored
  with no diagnostic.

## 2. The threshold, and the mechanism

Probes `q4p-threshold`, `q4p-runs`, `q4p-dissect`, `q4p-reach` and
`q4p-bound` used a pure predicate: `localOutlineOf(...).ring` fails
`triangulationFor`. It was cross-checked against a real `execute`: 1,234
checks per configuration in `runs`, 1,890 plus 96 in `reach`, all
**disagree 0**.

**A — collapse** (`q4p-dissect`, origin, wall at 30°, L = 3000):

```
=== A huge: ... t=1e+100 ...
 local ring (stored): (2.4999999999999996e+99, -4.330127018922193e+99) (-2.4999999999999996e+99, 4.330127018922193e+99) (-2.4999999999999996e+99, 4.330127018922193e+99) (2.4999999999999996e+99, -4.330127018922193e+99) fellBack=true
   distinct points 2/4, all finite true
   triangulationFor: 0 triangles
=== A just above t*: ... t=148000000000000000000.0 ...   distinct points 2/4, all finite true ... execute: Invalid argument(s): 12 generated a region ...
=== A just below t*: ... t=147000000000000000000.0 ...   distinct points 4/4 ... triangulationFor: 2 triangles  execute: ok
sqrt(maxFinite) = 1.3407807929942596e+154
```

- **The chain.** The world ring collapses, so `outline()` falls back to
  the free caps, which have also collapsed. `localOutlineOf` finds the
  local image not simple and returns the local free rectangle. It does
  **not check** that rectangle, and `_checkRegion` throws.
- **What "turned" really means.** It means the wall's **local** direction
  is not axis-aligned. A diagonal wall at the root at the origin throws
  too (from t/L = 3.4e16 for L = 1; runs `origin, wall at 30 deg`). An
  axis-aligned local wall never throws at any t up to 1.7e308 (runs
  `origin` and `+1e9, 0 deg`, "0 throw"). So the finding's "every turned
  placement" is really "every wall not parallel to its group's axes".
- **The worst case found** (`q4p-bound`: 3 justifications × 120 angles ×
  5 lengths from just above 1e-6 up to 3000 mm × 5 placements, 520,200
  cases each, t from 1e-5 to 1e13 at 16 per decade):
  - `group at corpus turned 17`: smallest failing t **1.33e+10** (left,
    L = 1.000000001e-6); smallest failing t/L **1.15e+16**
    (unpatched).
  - Every configuration: `fail with t<=1e7: 0, t<=1e9: 0, t<=1e10: 0`
    through A.

**B — shoelace cancellation** (`q4p-dissect`):

```
=== B far realistic-ish: +1e9 mm (1e6 m), 23 deg, L=0.01, t=150.0, true area=1.5
   isSimpleCcw=false shoelace abs=-64.0 rel=1.5000081886982173
   distinct points 4/4, all finite true
   triangulationFor: 0 triangles
 execute: Invalid argument(s): 12 generated a region ...
```

`q4p-reach` gives the longest wall that throws at ordinary thicknesses,
scanned over 5 angles and L from 1e-6 to 1e4 mm:

```
1e5,1e5 (100 m) t=100.0: 0/1605 throw
corpus 4.5e6,1.2e6 t=100.0: 10/1605 throw ...; longest throwing L = 1.78e-6 mm
1e7,1e7 (10 km) t=100.0: 57/1605 throw ...; longest throwing L = 6.49e-5 mm
1e8,1e8 (100 km) t=100.0: 139/1605 throw ...; longest throwing L = 6.04e-3 mm
UTM-like 5e8,5.5e9 (mm) t=50.0: 275/1605 throw ...; longest throwing L = 3.16e+0 mm
1e9,1e9 (1000 km) t=100.0: 197/1605 throw ...; longest throwing L = 3.92e-1 mm
```

- **Where B lives.** It only reaches walls whose **local** coordinates are
  far from the origin. The Wall tool's groups sit at the identity with
  world coordinates, so every tool-drawn wall far away is exposed. A wall
  in a translated group is not exposed: its local coordinates are small
  (`corpusGroups`, `km1000Groups`, "max throwing t<=1e7: -").
- **It is scattered, not monotone.** The runs show dozens of throwing runs
  interleaved with passes; rounding luck decides.
- **Is 1e7 mm reachable anywhere?**
  - Through A, **no**. Any wall of 1e-6 mm or longer at t ≤ 1e7 is safe
    (bound sweep above).
  - Through B, yes, at ordinary thicknesses. The walls involved are far
    and short: at most 1e-4 mm long within 10 km, and up to about 3 mm
    at georeferenced mm coordinates.

## 3. Other routes to the same throw

The throw needs two things. First, the wall's joined outline fails in
world or local. Second, its **local free rectangle**, a function of local
`(s, e, t, justification)` alone, fails `triangulationFor`. So any input
that sets those four can trip it. One route was probed; the rest are by
reading and were not driven in a widget:

- **Wall tool commit.** Probed: uncaught, reaches `FlutterError` (§1).
- **Wall-end or length grips.** A drag that shortens a wall far from the
  origin (B), or shortens a very thick one (A). `select_tool.dart:423-427`
  runs `ctx.execute(command)` and **rethrows** after `dropCarry`, so this
  would reach `FlutterError` too. By reading plus the pure predicate
  (execute-verified); not driven in a widget.
- **Justification toggle.** Left or right doubles the offset, which halves
  A's threshold. It is caught (`_setJustification`,
  `selection_panel.dart:680-701`).
- **Opening width and position.** These do not add a route. `cutsOf`
  admits an opening only when every piece passes `isValidPiece`, which is
  the engine's own check (`opening_geometry.dart:297-337, 511-518`).
  Otherwise the wall takes 07's uncut path, the same outline as without
  the opening.
- **Rooms and dimensions.** Both are guarded already. The room's tint
  chain checks `_triangulates` and degrades to an unfilled outline
  (`room.dart:170-189`, step 3). A dimension becomes `dimension.broken`.
- **Move and rotate.** They change only the group transform. The local
  rectangle is unchanged, so neither A nor B is triggered by the move
  itself.
- **Loaded files.** `fromJson` accepts any thickness. After such a load,
  any regenerating edit (a neighbour's included) can throw. The panel
  catches those edits; the tool and the grips do not.

## 4. Options and their cost

**(i) An upper bound in `isWallThickness`.**

- **The value.** Measured: A never fails for t ≤ 1e10 at any direction,
  justification, length > 1e-6 or placement (`q4p-bound`). The smallest
  failing t is 1.33e10 and the smallest t/L is 1.15e16. A bound
  `T ≤ 1e10` therefore holds with no margin, `1e9` with about 13×, and
  `1e7` with about 1,300×. At 1e7 and L = 1e-6, the band is still about
  500 ulps of `t` wide.
  - 1e7 mm (10 km) is already absurd for a floor plan.
  - It is below 2^53, so `_number` displays it exactly, and far below
    2^63, so the saturation defect becomes unreachable for thickness.
- **Does it hold at every reachable placement?** For A, yes: the fallback
  is judged in local space, and the sweep covered identity groups at 0,
  at the corpus and at 1e9, and turned groups at the corpus and at 1e9.
  It does **not** cover B, because B is independent of any upper bound,
  and it does not cover loaded files.
- **What it fixes.** Panel and Wall-tool settings both go through
  `isWallThickness`, so both refuse. The tool's `_addWall` already
  refuses a setting that fails it.
- **Cost.** One named constant. The spec 07 D11 amendment gains an upper
  bound. Tests: a WS3-style case, a boundary case, and the tool-route
  case below.
- **Suite effect: not measured.** I did not run the suites with a bound
  in place. By reading, the only effect should be on existing cases that
  type a thickness above the chosen bound.

**(ii) The wall never generates an untriangulable region.** Check the
local free rectangle, the way 08 already checks pieces with
`isValidPiece`. When it fails, generate the centreline alone (or an
unfilled outline, like room step 3) and diagnose it.

- **What it covers.** Both A and B, every route, and loaded files.
- **Spec conflicts.**
  - 07 D6's invariant says "every stored outline is a simple,
    anticlockwise, triangulable polygon. **The fill is never dropped.**"
    That needs amending.
  - D3's fixed handle order breaks: a region that returns later sits
    above the centreline, the same case as D3's amendment for a loaded
    degenerate wall.
  - D12 gains a code.
  - The room inputs and the band cache read the same ring.
- **Why it is the wrong fit for B.** It would silently drop the fill of a
  far, short wall whose rectangle is geometrically sound. It hides an
  arithmetic bug rather than fixing it.
- **Cost.** Medium: `wall.dart`, `wall_geometry.dart` and the spec.

**(iii) Catch the refused edit in every input path.** The panel already
does this.

- **What would remain.** `PlacementTool.commit`, used by every placement
  tool, and the select tool's grip commit.
- **What is still missing afterwards.** The handle seed is still
  consumed, the user still gets no feedback, and the cause is not
  touched. It is whack-a-mole.
- **Cost.** Small in code (render layer and app). The problem is its
  scope, not its size.

**(iv) Better, for B: a vertex-relative `_signedArea` in the engine
triangulator** (`triangulate.dart:103-110`; subtract the ring's first
vertex).

The experiment: patch temporarily, run, then restore and diff. The saved
diff is `q4p-shoelace.patch`.

- **Engine patch alone:**
  - `q4p-reach` B: 0 of 1,605 throw at every distance, 1e9 and UTM-like
    included.
  - `q4p-bound`: `fail with t<=1e10: 0` in all 5 configurations; A
    unchanged (smallest failing t 1.33e10).
  - `q4p-dissect`: the 1e9 ring now gives "2 triangles, execute: ok",
    but still `fellBack=true` (see the next paragraph).
  - Suites: app `+491: All tests passed!`; engine
    `+1078 -2: Some tests failed.`, the same two
    `generate_document_test` byte-for-byte failures as unpatched
    (`+1078 -2` there too; the two standing Linux-only hash tests).
- **Patching the app's `signedArea` as well** removes the spurious
  `wall.fallback`. But it **changes three 07/08 decisions**, measured:
  `WG10` (ring length 6, not 4), `WR12` (an extra `wall.fallback`) and
  `KJ1` (length 2, not 4). Those fixtures' decisions depend on the
  absolute-shoelace rounding at the far origin. That is a separate,
  larger item.

**Recommendation: (i), with T = 1e7 mm** (a named constant; the value is
the human's call below the measured 1.33e10). It closes found item (c)
exactly, through both the panel and the Wall tool, and is essentially
free.

- Record **B** as its own found item. Fix it with (iv) on the engine only,
  which measured green on both suites. Its mutant is `M-q4-absShoelace`:
  restore the absolute shoelace. It is killed by an engine test that
  triangulates the ring from §2 at 1e9 and expects 2 triangles. Today that
  ring gives 0, as the dissect output shows.
- Record the `_number` saturation as its own found item (the second
  silent undo step).
- (ii) stays the backstop if the human wants loaded files covered.

**Killing mutant for (i): `M-q4-noUpperBound`**, which restores
`isWallThickness(t) => t.isFinite && t > wallJoin.linear`.

- **The killing test.** The shell with `panelDoc`: press W, type "1e100"
  in Thickness **without Enter**, then click a diagonal wall (P2a's
  `plan(400, 900)` → `plan(1900, 800)`). Expect:
  - `takeException()` null;
  - the settings still 200;
  - a new wall at 200.

  On the mutant, P2a's pasted output shows the `ArgumentError` from the
  pointer event, so the test goes red. The panel route cannot kill this
  mutant, because the panel's catch reverts either way.
- **Plus a boundary case**, which kills `M-q4-boundary` (`<` against
  `<=`): `isWallThickness(kMax)` is true and
  `isWallThickness(nextUp(kMax))` is false. Also, typing `kMax` in tool
  mode is accepted.

## Probe sources and raw outputs (scratchpad, prefix `q4p-`)

Directory: `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/`

- **Tests** (they ran from `apps/floor_planner/test/` as
  `q4p_<name>_test.dart`, then were deleted):
  - `q4p-threshold_test.dart`
  - `q4p-runs_test.dart`
  - `q4p-realistic_test.dart`
  - `q4p-dissect_test.dart`
  - `q4p-reach_test.dart`
  - `q4p-bound_test.dart`
  - `q4p-panel_test.dart` (the first attempt; its values interfered with
    each other, superseded by panel2)
  - `q4p-panel2_test.dart`
  - `q4p-panel3_test.dart`
- **Outputs:**
  - `q4p-threshold.out`, `q4p-runs.out`, `q4p-realistic.out`,
    `q4p-dissect.out`, `q4p-reach.out`
  - `q4p-bound-unpatched.out`, `q4p-bound-patched.out`
  - `q4p-panel.out`, `q4p-panel2.out`, `q4p-panel3.out`
  - `q4p-patched-probes.out`, `q4p-enginepatch-probes.out`,
    `q4p-dissect-enginepatch.out`
  - `q4p-app-patched.out`, `q4p-app-enginepatch.out`
  - `q4p-engine-patched.out`, `q4p-engine-unpatched.out`
- **The experiment:**
  - `q4p-shoelace.patch` (app and engine)
  - `q4p-patched-triangulate.dart`, `q4p-patched-wall_geometry.dart`
  - `q4p-orig/` (the originals restored from)
