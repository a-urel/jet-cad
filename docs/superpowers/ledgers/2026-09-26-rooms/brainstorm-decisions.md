# 10 rooms — brainstorm decisions (2026-09-26)
Worktree .claude/worktrees/rooms, branch spec-10/rooms at 418d4c7.

## Research facts (Explore agent)
- No stored wall graph (07 D4: joints derived per generate, not cached); roadmap decisions 2 is stale.
- generate cannot write the component → area must be derived (not stored) — shown by the label/panel computing it.
- Generated TEXT loses its string/attrs (planner uses draftRecord without text; records never rewritten; SetEntityTextCommand on generated children refused) → engine change needed: Generated.text + planner text/attrs rewrite.
- generate cannot read the page (units, scale) → label height/units fixed or stored in the room's params.
- Region colour fixed at creation; no transparency option in the planner; a region that fails triangulation refuses the edit (fallback needed, like isValidPiece).
- References + orphan fit (long lists fine; orphan kept, regenerated, parametric.orphan reported). Seed-point-only reach never regenerates (unbounded reach = every room every edit).
- Uncut faces: outline/capsOf/hostFrameOf; T corners via cap/intersect; do not use 07 rings or 08 pieces.
- Picks: vertex > edge > fill, then highest handle → a later room wins fill picks inside furniture and edge picks near wall faces; opaque fill covers furniture; room group would be movable by default.
- Panel: _Field is numeric only; tool letters free: O, M.
- Units: DisplayUnit (mm/cm/m/in/ft-in) on the page; formatLength only for the ruler; no area formatting.
- Sample plan: six closed four-wall rooms (hall 22.00, bed1 8.45, bed2 8.41, kitchen 13.97, bath 13.37, living 45.10 m²; total 111.30), all loops need T splits; no L-shaped room (build separately); every room's walls carry openings.

## Decisions
1. Rooms from: a Room tool click inside a closed ring of walls; the room stores a seed point + references its bounding walls (orphan policy); each rebuild re-traces the ring from the seed among those walls and their neighbours (T splits); a new splitting wall needs a re-click.
2. Outline/area: inner wall faces (net floor area); traced from wall params (uncut faces), so doorways never break it; per-wall thickness respected.
3. Look: label + light translucent tint on the inner-face ring. (Note: both sinks already carry ARGB alpha through — vertices_draw_sink.dart:587, gpu/geometry_collector.dart:194, instance_record.dart:124 — the gap is the colour model/region having no alpha option.)
4. Order/pick: ascending-handle draw order kept; the tint is translucent (Generated.region gains a transparency, written into the fill record; the style resolver already maps transparency to alpha) and never pickable; a room is selected by its label.
5. Label placement: default at the inner ring's pole of inaccessibility; a label grip stores an offset from that default in params (null = auto); the offset rides with the room.
6. Area unit: follows the page — m² for mm/cm/m, ft² for in/ft-in, 2 decimals. Engine change: ParametricView reads the page; a page change regenerates every object whose generate read it (one undo step).
7. Label size: paper heights (e.g. name 2.5 mm, area 2.0 mm) × page scale denominator; read from the page like the unit.
8. Naming: the tool stores 'Room N' (lowest unused N among live rooms) in params at creation; the Room panel section gains a free-text name field (new string field kind), committed on Enter as one undo step.
9. Wall deleted: cascade — deleting any referenced bounding wall deletes the room in the same undo step (ReferencePolicy.cascade for room→wall).
10. Ring breaks (walls exist but no closed ring from the seed, or the seed falls outside it): the room is deleted in the same undo step. ENGINE CHANGE: generate/diagnose cannot delete objects today — the planner needs a per-type "dissolve" verdict applied inside the edit (like the 08 cascade). Spec detail: define "breaks" exactly (re-traced ring must contain the seed and use only referenced walls + their T neighbours).
11. Open plan: a room-separator object in 10 — the tracer treats it as a zero-thickness wall; drawn dashed on screen, hidden in print; own tool + grips.
12. Islands: freestanding walls inside the ring are subtracted (holes in tint and area).
13. Islands captured by the Room tool at click (re-click to pick up new ones). ENGINE CHANGE: ReferencePolicy per reference, not per type — bounding walls/separators cascade, islands orphan (dropped). Spec detail: island moved out/overlapping the ring.
14. Keys: M = Room tool, S = Separator tool.
15. Separator no-print: thin dashed line in 10; spec states non-printing; roadmap 13 gains "separators do not plot". No plot flag now.
16. Sample plan: rooms for all six spaces (named Hall, Bedroom 1, Bedroom 2, Kitchen, Bath, Living), one separator splitting Living from a Dining area, one column island in Living.
17. Separator geometry: a free two-point line placed with existing snaps; the tracer joins it where an end lies on a wall's inner face (Tolerance); it does not draw into or cut walls; a wall moved away breaks the ring → room deleted (decision 10).
18. Spike: yes — throwaway branch proving the ring tracer (six sample rooms + L-shape + separator + column + far-origin copy; areas vs hand-computed).
19. Spec review: yes — an independent reviewer checks the spec before the plan.

## After the spike (spike/10-rooms d30bce5; note docs/superpowers/notes/2026-09-26-rooms-spike-findings.md)
20. Trace set: re-trace among ALL walls (live) — overrides decision 1's "trace among referenced walls; new splitting wall needs re-click". ENGINE CHANGE (fifth): spatial dependencies in the closure — a room rebuilds when a changed wall's before/after extent touches the room's extent. Spike warned: neighbours-shaping drifts two hops away (Q3e drift [34]); the spatial closure must cover that.
21. Tint on dark paper: follows the paper by contrast (like ACI 7 foreground), resolved at paint time, no rebuild.
22. Label over furniture: accepted — the label wins the click; drag it with its grip.
23. Island: cuts a hole only while wholly inside the ring without touching it; otherwise ignored for area and reported by diagnose; room survives.
24. Wall deleted: ONE rule — every change (delete or move) just re-traces; a room is deleted only when its seed lands in an unbounded face or inside a wall/on a separator (decision 10 rule). Two rooms in one face both survive; diagnose reports "Room A and Room B share a space". SUPERSEDES decision 9 (no cascade) and the stored bounding-wall references.
25. Islands live: any wall component wholly inside the face is a hole, found on every re-trace; no island list stored. SUPERSEDES decision 13 (no captured list, no per-reference policy — that engine change is dropped). Consequence for decision 23 under live tracing: a column touching the ring is part of the ring's boundary (the tracer excludes it exactly); a column outside the face is simply not in it. diagnose need not report either.

### Net engine changes for 10
(a) Generated.text keeps string (+attrs at creation; planner rewrites the string on match).
(b) Generated gains transparency/flags/linetype/lineweight as needed (translucent unpickable tint, invisible boundary, dashed separator).
(c) ParametricView reads the page; a page change regenerates every object that reads it, one undo step.
(d) Dissolve verdict: an object whose type says it dissolves is deleted inside the same edit (detach before D8 cleanup — spike mutant).
(e) Spatial dependencies: a room rebuilds when any wall/separator changed in the edit has a before/after extent touching the room's extent (its last generated extent and its seed); must not drift two hops (spike Q3e).
Dropped: references for rooms, per-reference policy.

## After spec revision 1 (5015828) — the spec's open questions
26. Room tool click in a face that already has a room: nothing happens (status line says so) — confirms R-19.
27. Selected room: labels AND the inner-face ring outlined in the selection colour — needs a render-layer change (the tint boundary is invisible today). Spec must add this (overrides the spec's labels-only default).
28. Tint: page foreground at ~10% — confirms R-8/R-9.

## During execution (Task 14 review)
29. Tint loss when a separator ties a freestanding column/island to the ring (the ring walks out and back along the separator: a doubled edge, an exact keyhole the triangulator refuses → D9 step 3 outline): FIX IN 10 — a new task after Task 14 splits the doubled edge into a hole boundary before the tint is cut; D9 amended; own tests and mutants.
