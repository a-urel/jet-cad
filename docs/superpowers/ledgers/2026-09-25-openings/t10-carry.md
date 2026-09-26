# Task 10 — carried (binding, in addition to the plan's Task 10)

First, as a separate commit ("Task 9 minors"):
1. **m1 — OT2 hinge from the stored centre:** a T obstacle at [2300, 2420] on a
   5000 wall, a click at 2400 → the clamped centre is 2870, so hinge = end.
   Mutant rv9-hingeRaw (opening_tool.dart hinge from `u` instead of `c`) → red.
2. **m2 — OT2 swing from the raw point:** the reviewer's probe — camera scale
   0.15, a centred 200 wall, clicks at 2510 along it ±30 off; the midpoint snap
   puts the resolved point ~-2.9e-10 from the centreline; the swing must follow
   the RAW click (left/right). Mutant rv9-swingResolved (`raw` → `resolved`) → red.
3. **m3 — handle:** in OpeningTool.accept, allocate the new opening's handle
   (handleSeed.next()) before placing it, and pass it into build — no
   prediction of `current + 1`. Add a keep-a-piece tool test (the reviewer's
   probe: a 2000 wall with a 1200 window, an 800 door clicked at 1700 → the door
   is no-fit and stored at the projected u; the preview shows no jambs). Mutant:
   admit the new opening with a wrong handle (e.g. Handle(1)) → red.
4. **m4 — guard:** an A8-style test pressing D, N, G (written literally, not
   derived from kShellLetterKeys) into the Text tool's field and a panel field:
   they are typed, not taken as shortcuts. Mutant rv9-guardDNG (the three entries
   removed from shortcut_guard.dart) → red.
5. **m5 — liveness:** WallBands._refresh caches only live walls (root-level
   GroupNode, as `_keptPut`/`_isLiveGroup`). Test: a node-less WallParams at a
   low handle over a live wall — D places on the live wall. Mutant: no liveness
   filter → red. 07's WT tests must stay green.
Then the plan's Task 10. Scratch prefix `t10-`.
