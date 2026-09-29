# Sub-project 11 (dimensions): the human's brainstorm decisions

Binding for the spike, the spec and the plan. Later decisions supersede
earlier ones only where they say so. Recorded as asked and answered.

## Context the questions were grounded in (survey, 2026-09-28)

- A parametric reference is a stored `Handle` to another *parametric* object
  (08); a plain drafted line cannot be referenced. Policy per type:
  `cascade` (deleted with the referent) or `orphan` (kept, generate sees null).
- Stable wall identities: (wall handle, end k in {0,1}); faces left/right by
  justification offsets. No stored node objects; ring vertex indices are not
  stable. Snaps carry the hit leaf and its root chain but no feature index,
  and `resolveDragPoint` drops the entity today.
- 10 gives: Generated.text, page on the view + pageKey, paper-mm text height
  (`textHeightMm`), formatLength (rulers: 3 dp metric, 1/16" feet-inches).
- No layers UI (12). No arrowheads anywhere. Free letters: E H I J K O Q U X Y Z.

## Decisions

1. **What a dimension attaches to: walls + free points.** Each end of a
   dimension is either a wall feature (a wall end, or a point on its left or
   right face, corners included), which it follows when the wall changes, or
   a fixed point (no wall feature snapped). Dimensions on drafted geometry
   are placed but do not follow it. Openings are not v1 referents.

2. **v1 types: aligned + linear.** Aligned measures the true distance along
   the line between its two points; linear measures the horizontal or the
   vertical component, locked by where the dimension line is dragged. No
   chains (continued/baseline), no angular, radial or ordinate in v1.

3. **A referenced wall deleted → the dimension is deleted** in the same
   edit and undo step (08's `cascade`); undo restores both. No new engine
   policy.

4. **Wall attach points: the six end points.** Per wall: start and end, each
   on the left face, the centreline or the right face. The stored reference
   is (wall handle, end k in {0,1}, side in {left, centre, right}). A face
   point is the cleaned-up corner where walls meet (the joint's outline
   corner), so corner-to-corner room widths and overall lengths follow. A
   snap mid-face (or anywhere that is not one of these six) gives a fixed
   point. No along-face points, no face-to-face mode in v1.

5. **Terminators: the architectural slash** — a short 45° tick through each
   end of the dimension line, drawn as lines (no fill). No arrowheads, no
   per-dimension choice.

6. **Sizes: fixed paper constants**, scaled by the page scale exactly as the
   room labels are (text height, slash length, extension-line gap and
   overshoot, dimension-line offset defaults). Text scales with the paper,
   never the camera (M-11b). A page-scale change regenerates every
   dimension (pageKey). No style table, no style UI in v1 (a style table can
   come with 12's shell).

7. **Value format: per-unit plan precision, round-half-up.** Unit = the
   page's display unit. mm to 1 mm (3450); cm to 0.1 cm (345.0 / 345); m to
   0.01 m (3.45); in to 1/8"; feet-inches to the nearest 1/4" (11'-4 1/4").
   No unit symbol on the dimension text. Rounding half-up (M-11e at .5).
   [Spec to pin: trailing-zero policy for cm, fraction reduction, how a
   .5 boundary is decided exactly despite binary floating point.]

8. **Text: centred above the dimension line, aligned with it, readable**
   from the bottom or the right of the page (flipped by 180° when the line's
   direction would read upside down). [Spec to pin: the flip boundary at
   exactly vertical, with Tolerance; the text's gap above the line.]

9. **One Dimension tool, three clicks:** first point, second point, then
   place the dimension line. Aligned by default; hold Shift while placing
   for linear, horizontal or vertical by the side dragged to. Esc cancels as
   in the other tools. Each end attaches to a wall end point when the snap
   lands on one (decision 4), else it is fixed.

10. **The Dimension tool's key is I.** (Add to the palette and to
    `kShellLetterKeys`.)

11. **Grips: the line offset and the two ends.** The offset grip moves the
    dimension line nearer/further; the line keeps that offset (stored
    relative to the measured points) when the walls move. Two end grips
    re-pick an end with the tool's snaps: an end can attach, detach, or
    move to another wall end point. No text grip in v1.

12. **Select-tool move/rotate: fixed ends move, attached ends follow their
    wall.** A fixed end moves/rotates with the selection; an attached end
    never moves by itself and always follows its wall. Moving walls and
    their dimensions together keeps every dimension right; moving a
    dimension alone leaves its attached ends pinned. [Spec to pin: what a
    rotation does to a linear dimension's horizontal/vertical axis, and to
    the stored offset.]

13. **Panel: a Dimension section** with the measured value (read-only, as
    displayed), a switch Aligned | Horizontal | Vertical, and each end's
    state (attached to a wall end point, or fixed). Each change is one undo
    step. No text override in v1.

14. **Only placed dimensions.** No automatic dimensioning: rooms keep 10's
    name and area label unchanged; no transient wall-length readout.

15. **The sample plan ships a few varied dimensions:** overall width and
    depth outside the plan, two interior room widths corner to corner, and
    one aligned dimension on a non-axis pair (a fixed-end one if the plan
    has no angled wall) — every kind and both end states for the look.

16. **Spike first**, on a throwaway branch: the corner point per (wall, k,
    side) at L/T/X joints; which edits must rebuild a dimension (a
    neighbour moving the referenced wall's corner — drift); how a snap
    identifies the wall end point it hit; what rotation does to a linear
    dimension. Findings note, then the spec.

## Controller's readings (not the human's; the spec may overturn with reason)

- Layer: everything stays on layer 0 (no layer UI until 12); roadmap 11's
  "fixed layer" question is deferred to 12.
- EntityKind does not grow a dimension kind (roadmap decision 2); a
  dimension is a parametric object whose children are lines (extension
  lines, dimension line, slashes) and one Generated.text.
- A dimension references up to two walls (`references` → the attached
  ends' wall handles), policy cascade (decision 3).
- Suspected engine need: 08's references rebuild a referrer when its
  referent is edited, but a neighbour's edit can move a referenced wall's
  cleaned-up corner without editing the referent. Either the closure must
  reach referrers of regenerated neighbours, or a dimension also reads by
  place (10's readsPlaces), or something else — the spike decides.

## After the spike (findings note on `spike/11-dimensions` at `675f997`)

17. **Linear axes are the dimension's own (group-local) axes.** They turn
    with the dimension under a rotation: rotating a plan keeps every value;
    a both-ends-attached linear dimension rotated alone turns its axis (the
    spike's 4000 → 3464), and the panel shows it as rotated.

18. **The offset is a model length.** A dimension line stays where it was
    placed when the page scale changes; only the text, slashes and gaps
    (paper constants, decision 6) grow or shrink in the model.

19. **A shared point attaches to the wall the dimension runs along.** When
    an end's point is one of several walls' attach points (an L corner),
    the choice is made once both ends are known (the second click, or an
    end-grip drop): the candidate wall most nearly parallel to the
    dimension's measuring direction, then the lowest handle, then the
    spike's order (face before centre, k, left before right). A wall-length
    dimension stays on that wall's ends: deleting a side wall leaves it
    measuring the wall; deleting the wall deletes it. [Spec to pin: the
    parallel measure for linear vs aligned, its Tolerance, and a candidate
    set from the index rect query as spiked.]

20. **Dimension lines at 0.25 mm lineweight.** The spec measures whether
    0.25 survives the rasteriser's axis-aligned drop-out (the spike's
    threshold was about 0.27 mm, 0.18 vanished) at the look's zooms, and
    raises it to 0.30 if not. The render-layer sub-pixel fix stays a
    separate follow-up with 10's dash debt (R-17); the render package stays
    frozen in 11.

21. **Collisions are accepted; the user drags to fix.** Nothing avoids
    anything automatically (slashes across a partition, text over a room
    label): the offset grip (decision 11) or 10's label grip resolves it.
    Recorded as a known limit; no collision diagnostic.

## Open spike decisions left to the spec as [spec ruling]s

Spike list items 1 (centre = stored centreline end, as spiked), 3 (re-derive
via the index, as spiked), 4 (attach tolerance), 6's reference point and
sign (decision 18 settles units), 7 (half-up tolerance, cm trailing zero,
fraction reduction, inch/foot marks — decision 7 says no unit symbol; the
spec says whether ' and " count as symbols in feet-inches), 8 (flip
tolerance/direction), 9 (paper constants), 11 (degenerate/coincident +
diagnostics), 12 (07's local-ring fallback vs the attach point), 14 (select
tool movability through the real tool), 15 (state the closure invariant: a
dimension reads only its referents and their one-hop wall neighbours).
Q2 finding: today's closure (08's core referrers) already rebuilds the
neighbour case — no engine change for drift; the controller's reading was
wrong.

## After the spec review (rev 1, review S-1..S-12)

22. **Decision 19's choice is made at the commit, not the second click**
    (supersedes decision 19's timing): at the third click, using the
    direction the committed dimension actually measures (aligned, or the
    group-local x/y for horizontal/vertical); at an end-grip drop, for the
    dropped end, using the dimension's current kind. The spec's R-17 rule
    becomes this decision (S-1).

23. **Attach by position.** While F3 is on, any end that lands within the
    attach tolerance of a wall's attach point attaches, whether an object
    snap or the grid put it there; tool and grips behave the same (they see
    only the resolved point). D12's "a grid point is fixed" is reworded
    (S-3).

24. **Extension lines never take clicks** (supersedes rev 2's R-35): like
    10's room tint, they are never pickable. A dimension is selected by its
    dimension line, slashes or text; a wall face under an extension line
    stays clickable. (The mechanism must be one the engine already has —
    the spec verifies which.)

25. **A "not pickable" entity flag in the engine** (qualifies decision 24
    and D1): no existing mechanism keeps a plain LINE drawn but unpicked
    (the tint trick needs a fill; `invisible` also stops drawing; locked
    layers need a layer on `Generated`; 10 R-10 declined such a flag). So
    11 adds one small engine change: a new `EntityFlags` bit that
    `QueryFilter.picking()` (and snapping) skip while `rendering()` still
    draws, set on the extension-line children on add (10 D13's
    record-attribute path). D1 becomes "one small engine change"; the flag
    gets its own tests and mutants, save/load round trip, and a check that
    the frame path is untouched.
