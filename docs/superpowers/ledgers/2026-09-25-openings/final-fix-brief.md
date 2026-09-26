# Final fix wave — plan-08/openings (binding)

Read the standing brief (standing-brief.md), then the ledger's "Final review"
and "Final I1 / minors / Ruling" lines (progress.md). The reviewer's scratch
(probes fr_probe*_test.dart, fuzz, dumps) is under
/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/plan08/final/
— read them; reuse the repro and the sweep as tests. HEAD is 5739442.

1. **I1:** in `opening_geometry.dart` (`_pieces` / `cutsOf`): (a) remove a
   vertex that lies on the segment between its neighbours within
   `wallJoin.linear` (the back-tracking endpoint) before judging a piece;
   (b) the admission loop admits an opening only if every piece it leaves is
   simple, anticlockwise and triangulable (use the same predicate the engine's
   region check uses — 07 D8 / `triangulationFor` non-empty — so the app can
   never generate a region the engine refuses); otherwise that opening is
   no-fit. Tests: the reviewer's repro (A: 3000 wall 200 centre; B from A's end,
   150 right, a 2° kink; a 600 gap at 2900) lands; the kink × thickness ×
   justification × start/end sweep (1,620 cases) refuses 0; through the real
   shell: the Window tool near a kinked end places (or no-fits) with one history
   entry, the slide grip dragged to that end yields a command or no-fit and no
   exception escapes pointer-up, a neighbour's end drag swinging B to 2° is not
   refused. Mutants: the validity check removed → red; the vertex cleanup
   removed → report whether more openings become no-fit (it should not refuse).
2. **m1:** `opening_tool.dart` `_place` stores a no-fit position clamped to
   [0, L] (as the grip does). Test the reviewer's probe (a 700 wall, a click
   snapped 6 mm past its end). Mutant: raw u → red.
3. **m2:** tests that kill fr-X4 (hostFrameOf's local-space fallback — a case
   where the world outline is simple and the local one is not, see 07's
   _localOutlineOf tests for the shape), fr-X8 (a grip on a yielded opening
   respects keep-a-piece admission), fr-X9 (WallBands._indexAt's length bound:
   a click on a wall's line beyond its end neither joins nor hosts — put it in
   a NEW test file; 07's six wall test files stay unedited), fr-X7
   (wallsInDocument's liveness: a hand-built non-live wall component is not a
   host/obstacle). Each mutant → red.
4. **m3 docs:** the results note (criterion 9 with the fixed state and the new
   sweep; the property-run claims), spec D6 (tools and grip stay in [0, L]),
   D7 + known limits (acute joints ≲12° and folded walls shrink, move or empty
   the straight span, following 07's caps), D8/D9 ("every piece left is valid"),
   and m4 as 07 debt in the results note.
Run all gates + web build; paste real output. Commit(s) in English with both
trailers; no push. Scratch prefix `ffw-`.
