# Task 4 brief — the `layer` parameter (spec D7, plan P-8) — preceded by 3b
Read common.md in this directory first and follow it. HEAD af87621. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/l4/.

## First, as its own commit: 3b (Task 3's review)
Read task-3-review.md findings 1-3 and do exactly what they say:
1. spatial_index.dart's _reconcile skip: skip only a handle that is purely a layer (layers[h] != null && !entities.containsHandle(h) && _lastKnownSlot[h] == null && tree[h] == null && tree.definition(h) == null — use the real API names on the branch). Add the reviewer's regression test (a layer sharing a handle with an entity; an edit to the entity keeps the index fresh) in test/index/layer_filter_test.dart; mutant: drop the containsHandle check -> red.
2. Test: a layer-0 ATTRIB owned by the fixture's nested instance; hide layer 0; still picked and drawn through the instance on A. Re-fire the reviewer's O1 (drop `&& ownLayer != layerZero` in the ATTRIB rule) -> red.
3. Test (in the test, not the shared fixture): a line on a new unlocked layer D inside Leg; lock A; a pick on that line returns null. Re-fire O2 (lock check on resolved.layer in acceptsNodeOnLayer) -> red.
Commit `fix(engine): Task 3 review follow-ups` (3b).

## Then plan Task 4 exactly (mechanical, P-8)
draftRecord, addDrafted, addDraftedRegion take a required `Handle layer`. Every caller outside drafting.dart passes `layer: ReservedHandles.layerZero` — engine lib (_recordOf included, for now), render's three tools, the app's startup_plan.dart, and every test (spec D7's blast radius plus whatever the compiler finds; dev_harness_2d should have none — confirm). Change NOTHING else in this commit. The report lists `git diff --stat` and confirms by grep that every non-drafting.dart hunk only adds `layer: ReservedHandles.layerZero` (plus an import where needed). Gate counts unchanged from 3b's. No mutant for Task 4 itself.
Commit `refactor(engine): drafting takes the layer explicitly`.
