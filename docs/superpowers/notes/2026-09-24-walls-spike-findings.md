# Sub-project 07 spike: findings

**Date:** 2026-09-24.
**Branch:** `spike/07-walls`, cut from `main` at `22957d1`.
**Status:** throwaway. The branch is never merged; this note is its only
output. It is an input to 07's spec, not a design.
**Where it ran:** a Linux x86_64 cloud container, Flutter 3.47.2 / Dart
3.13.2 — not the human's macOS machine. See "Platform" below.

## What was built

- **A wall type**, `test/spike_walls/wall.dart`, shaped by the brainstorm's
  decisions: one straight segment per object; `WallParams(start, end,
  thickness, justification)` in group-local space; three children, a FILL,
  its closed POLYLINE outline and an open POLYLINE centreline; joints
  derived in `generate` from the neighbours' parameters, never cached;
  `reach` = the centreline's world AABB expanded by the join tolerance; a
  join tolerance `Tolerance(linear: 1e-6, angular: 1e-9)`; mitre limit 4.
- **One planner hack**, in `lib/src/parametric/`: `Generated.region(payload)`
  plus about forty lines in `_plan`. A region is matched through its FILL
  child (whose payload names the boundary); a changed outline is one
  `SetEntityGeometryCommand` on the boundary; a missing region is one
  `AddRegionCommand` with two reserved handles, fill first; a surplus
  region is removed through its boundary, whose removal cascades the fill.
  The fill record itself is never rewritten.
- **Tests**, `test/spike_walls/`: `geometry_test.dart` (Q1–Q5, world
  geometry at the far origin), `e2e_test.dart` (Q6, the real
  `ParametricSystem`), `render_test.dart` and `svg.dart` (SVG dumps,
  screenshotted with the container's headless Chromium). The images kept
  are in [2026-09-24-walls-spike/](2026-09-24-walls-spike/).
- **The engine suite on the spike branch:** `+962 -2` — 06's 951, plus the
  11 spike tests, minus the 2 platform failures below. 06's own tests are
  unaffected by the planner hack.

## The node rule that survived

The brainstorm chose "angular neighbours". The spike's first reading of it
failed; this is the reading that works.

1. **Ends at a node** are gathered within the join tolerance and sorted
   anticlockwise by outgoing angle (ties: handle, then end index).
2. **Each wedge** between consecutive ends *x → y* gets **one shared
   corner**: *x*'s outgoing-left face ∩ *y*'s outgoing-right face. Both
   walls compute it from the same parameters in the same order, so it is
   the same bits in both outlines (Q1: bitwise shared, and equal to an
   independent Cramer's-rule oracle to `0.0`).
3. **Every wall's cap is the straight segment** between its two corners. At
   two ends this *is* the mitre, asymmetric thickness and justification
   included.
4. **At three or more ends** the corners enclose a **central polygon**. It
   is split at exactly repeated vertices into lobes; each lobe is owned by
   the lowest-handle end whose cap is one of its edges, and the owner's cap
   walks the lobe. A lobe that is folded (non-positive area) or crosses
   itself is dropped: every wall keeps its straight cap.
5. **Clamps.** A wedge **narrower than 90° is never clamped**: its long
   inner mitre is real geometry, and clamping it produced overlap (Q4's
   first run: 596 of 20,000 samples). A wider wedge whose corner lies
   farther from the node than `4 × ½ × the thicker wall`, or whose faces
   are parallel, is replaced by two feet (each face's point at the node);
   the central polygon then carries the bevel or the step.
6. **T:** an end strictly inside another centreline butts to that wall's
   near face; beyond the mitre limit it ends square at its own endpoint,
   inside the through wall's body. **X:** nothing to do.
7. **Short wall:** if a wall's own outline is not simple, that wall — and
   only that wall — squares both ends at its own endpoints.

**What failed first, and why it matters for the spec.** The first reading
routed every cap through the node point ("hub"). Wherever a justification
puts the node on a face — every left- or right-justified wall — the bent cap
cut a corner off a wall's own body (Q1: a visible notch) or folded into a
neighbour's (Q2b: 17 of the 27 justification triples overlapped or gapped).
**The node point must not be a vertex.** It is used only as the clamp
reference and the feet's base.

## Answers

| Question | Answer, with evidence |
|---|---|
| Does the asymmetric mitre come out right? | **Yes.** Q1, 67°, 200 centre against 115 left: two shared corners, bit for bit, equal to the oracle. The M-07a probe (the bisector at the symmetric distance) lands 278.306 mm from the true corner; the M-07b probe (B at A's thickness) moves A's corners by 108.636 mm. Both are killable on this fixture and invisible on a 90° equal-thickness one. |
| Does a 3+ junction work? | **For every common plan shape, yes.** Q2c: a split wall with a branch (300/115 and 300/300), a 4-way cross (200/115), an L at 90° and at 120°, a Y — each under all 9 justification pairings and 4 rotations: **216 nodes, 0 crossing outlines, 0 dropped lobes.** |
| Where does it fail? | **Exotic 3–4-way mixes: 0.78% of plausible random nodes** (Q5b, 156 of 20,000; thickness 100–300 mixed, 30% mixed justification, wedges ≥ 30°, walls ≥ 3× thickness). A crossing lobe is dropped and leaves a **visible hole** in the band — image `q5b_hole_2.png`: two near-collinear 115s and a 300. **This is the spec's open decision** (below). |
| Is the fill ever dropped? | **No.** Every outline is simple and triangulates: 49,887 plausible walls (Q5b) and 34,988 stress walls (Q5: 2–5 ends at any angle, lengths from 30 mm) — **0 triangulation failures**. It needed one extra step: exact removal of consecutive duplicates and zero-width spikes `a, b, a` (a pinched central polygon, where two corners land exactly on the node), which the triangulator rightly refuses (485 refusals before, 0 after). |
| How often does a wall fall back? | **0.11% of plausible walls** (54 of 49,887), all genuinely shorter than their own corners. |
| Overlap? | Present at about 4% of plausible nodes sampled (88 of 2,000, radius 80 mm) — from clamped wide wedges and fallbacks. **Invisible in an opaque one-colour band**, but see "Consequences for 08". Acute joints no longer overlap. |
| Does a mitre regenerate through 06 in one step? | **Yes** (Q6). Far origin, each wall in its own rotated group, joined only within tolerance. A and B each have exactly `fill,polyline,polyline`. Moving B is one undo step; undo restores the mitre exactly (canonical form), redo the move; child handles are unchanged by undo. Load → save is byte-identical; `drift()` is empty after every step and after reload; the typed component comes back equal. D6 refuses a direct edit of the outline. Deleting B with the select tool's cascade detaches its component and regrows A; undo restores three children. |
| Is the mutual dependency a problem? | **No**, as 06 predicted: generation reads parameters only, so A's mitre and B's are two independent evaluations of the same shared corners. |
| Is the join tolerance needed? | **Yes, measurably.** Q6's two rotated groups leave the joint **4.656612873077393e-10** apart in world — half an ulp at the far origin. `Tolerance.standard` (1e-9) would have held by a factor of two; `1e-6` holds by three orders. |
| Are M-07d and M-07h killable? | **Yes, both fired against Q6** with a `cp` backup, restored and diffed clean: exact `==` in the join test and a dropped group transform each send `shared corners` from 2 to 0 (`Expected: <2> Actual: <0>`). |

## Findings nobody asked about

1. **The short-wall fallback must be one-sided.** A rule that also squares
   the short wall's *neighbours* makes B depend on C through A (B and C
   touch the two ends of a short A), a **two-hop dependency** that 06's
   one-hop closure does not regenerate — `drift()` would go non-empty. The
   one-sided rule leaves a small notch at such a joint instead.
2. **Count assertions cannot see a joint.** A mitred L outline and a
   square-ended one both have 4 points (Q6: 4 before the move, 4 after). The
   roadmap's "assert counts on relational fixtures" is necessary, not
   sufficient, here: the tests need **coordinate oracles** (shared-corner
   counts, oracle corners).
3. **"Inside some wall's strip but uncovered" is not a gap oracle.** A mitre
   legitimately cuts away the part of a square end that sticks out past the
   partner's outer face (Q1: 82 of 20,000 samples, `q1_l67.png`, red). The
   overlap census is valid; watertightness is structural (bitwise shared
   corners, lobe edges that are the other walls' caps).
4. **M-07d is killed only by a fixture whose joint is not bitwise.** Q6's is
   non-bitwise by accident of rounding; the plan's fixture must perturb one
   endpoint by a deliberate ulp, as the roadmap asks.
5. **Node membership is not transitive.** Each end gathers the ends within
   tolerance of *its own* endpoint, so A~B, B~C, not A~C is possible in
   principle. Not observed; the spec should fix a rule (for example,
   membership measured from the lowest-handle endpoint).
6. **Two ends in one direction** (collinear overlapping walls) were
   excluded from the random runs; the angle sort's tie-break is defined but
   the geometry is not. The spec should define it.
7. **Platform.** On Linux x86_64 `main` itself fails two tests in
   `test/testing/generate_document_test.dart` — `the default document is
   the one Plan 2 measured, byte for byte` and `both text fractions default
   to zero and change nothing`, both `Expected: <1593811103237081036>
   Actual: <7763566604490466414>` — a hash of trig-dependent output. The
   engine gate of 953 is a macOS number. **07's tests must not pin a hash
   of rotated geometry;** compare two documents built in the same run.

## Consequences for 08 and 10

- **08 (openings):** where two walls overlap at a joint, a neighbour's fill
  can cover an opening cut close to the corner. 08 must either keep
  openings clear of joints or cut every fill that covers them.
- **10 (rooms):** rooms should be derived from faces and centrelines, not
  from these polygons, which overlap and (rarely) leave a hole.

## Open decision for the spec

The 0.78% hole. Options, cheapest first:

1. **Accept and document it**, with the measured rate, as 07's known
   limitation, plus a `diagnostics()` entry naming the node so a user can
   see why.
2. **A fourth child, only at such nodes:** the dropped lobe's convex hull as
   its own region, owned by the lowest-handle wall. It always covers the
   hole, but the child count stops being fixed at three, and 06 D12's
   draw-order cost comes back for that one child.
3. **A real polygon union** of the owner's body and the lobe. Always
   correct and three children kept, at the cost of a clipping routine the
   engine does not have.
