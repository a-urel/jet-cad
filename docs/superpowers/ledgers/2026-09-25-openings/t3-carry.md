# Task 3 — first step, carried from Task 2's re-review (binding)

Before the plan's Task 3 work, in `packages/jet_cad_2d` (one separate commit,
"Task 2 minors" in its message):
1. `_subtreeRemoval` (regeneration.dart) collects EVERY fill of the whole doomed
   subtree (the object's own leaves and every nested group's) before any
   boundary, so a loaded file with a region's fill in a nested group and its
   boundary in the doomed object deletes cleanly instead of being refused. Test
   (add to cascade_test.dart): that fixture — `deleteObject(A)` lands in one
   undo step, `validate()` shows nothing new, undo and redo exact. Mutant: the
   old order (own leaves' fills first, then nested) → red.
2. Add an `InstanceNode` child under P1 in CS11 (or a sibling test) so the
   mutant "no instance removal" in `_subtreeRemoval` goes red (the reviewer's
   probe: the instance branch works; nothing exercises it). A definition may
   be needed in the fixture.
Run the engine gate (and render/app, which must stay unchanged), commit, then
go on to the plan's Task 3.
