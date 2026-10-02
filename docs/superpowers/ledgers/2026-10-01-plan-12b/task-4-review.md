# Task 4 review (with 3b): the `layer` parameter

Reviewer: independent agent, detached worktree `.claude/worktrees/plan-12b-review` at `4a735fb` (base `af87621`;
commits `540f9cf` 3b, `4a735fb` Task 4). Scratch: `.../scratchpad/r4/`. `mut.py` takes a cp backup, applies one
exact-string mutation (asserted unique), runs the named test file in the foreground, copies the backup back and
prints the `diff` exit code. One temporary probe test (`test/index/zz_probe_test.dart`, untracked) was written and
deleted. At the end `git status --short` was empty. No analysis_options.yaml was touched.

## Verdict: **Approved with notes**

There is no defect. 3b does what Task 3's review asked, and the guard is cheap. The implementer's two arguments
against the review's suggested tests hold, and I re-derived both. Task 4 is purely mechanical: my own
whitespace-insensitive check finds 56 inserts of exactly `layer: ReservedHandles.layerZero` in 33 files, and
nothing else. All gates match the expected counts. M3b-4 is behaviour-equivalent, so no query answer can pin it.
Only a `rebuildCount` assertion can (note 1).

## 3b (`540f9cf`)

- **The guard is correct and cheap.** It is five conjuncts in `_reconcile`'s loop over `touched`
  (spatial_index.dart:2779-2785). Each is a hash or table lookup per touched handle, outside the frame path. The
  conjuncts short-circuit on `layers[h] != null`, so an ordinary entity edit pays one table lookup, as before. A
  handle that is purely a layer still skips. M-LP-2's test stays green.
- **The new tests** are in `layer_filter_test.dart`: edit, add, removal and instance at a layer's handle; the
  nested-instance ATTRIB (O1); lock A on D-in-Leg (O2b); and layer 0 locked (O2). They meet P-6:
  - Positions are off the origin and transformed.
  - The shadow layer is ACI 2.
  - Layer 0 is hidden or locked only in tests about layer 0, and only after A is made current.
- **The "review's test cannot catch the containsHandle drop" argument holds.** Under M3b-1 only the *add* test goes
  red, and the review's edit test passes. An edited entity is already in `_lastKnownSlot`, which guards it on its
  own.
- **The "review's lock-A test cannot catch O2" argument holds.**
  - A node's effective layer is the stored layer of its nearest ancestor-or-self on a non-zero layer, or layer 0
    when there is none.
  - That ancestor is tested by its own stored layer, which equals its effective layer, and is pruned when that
    layer is locked. So a locked context always has an already-pruned ancestor.
  - O2 (`_lockedLayer(resolved.layer)`) differs only for a stored-0 nested instance. It can only *add* a prune,
    when layer 0 is locked and the context is not. That is the converse test the implementer added, and it goes red.
- **M3b-4 (drop `definition(handle) == null`) cannot be pinned by any query answer. Confirmed, with one nuance.**
  - `AddDefinitionCommand` only adds an empty definition. `RemoveDefinitionCommand` only removes an empty,
    unreferenced one.
  - Under M3b-4, a definition added at a layer's handle is skipped and gets no `ContainerIndex`. Its first leaf then
    reaches `_containerHolding(owner) == null`, the "defensive" branch, which calls `rebuildAll`. Its first instance
    is a node, so it is structural anyway.
  - Probe, run on the original and then under M3b-4. The probe adds a definition at a layer's handle, then a leaf
    on A owned by it, then an instance at (-1400, 600) rotated -π/4, then picks the leaf:
    - original: `PROBE rebuilds after def add: 1` / `after leaf add: 1` / `PROBE picked: 37 leaf=37 rebuilds=2` /
      `00:00 +1: All tests passed!`
    - M3b-4: `PROBE rebuilds after def add: 0` / `after leaf add: 1` / `PROBE picked: 37 leaf=37 rebuilds=2` /
      `00:00 +1: All tests passed!` (`diff= 0`)

  The answers are identical, and so is the total rebuild count once a leaf exists. The only observable difference is
  `rebuildCount` straight after the bare definition add (1 against 0), and the mutant is the *cheaper* one. See
  note 1.

## Task 4 (`4a735fb`)

- **The `drafting.dart` signatures are right.** `draftRecord(..., {required Handle layer, String text = '', DraftColor
  color = ...})`, `addDrafted(..., {required Handle layer, String text = ''})` and `addDraftedRegion(..., {required
  Handle layer, ...})` all take the layer as named and required, with no default. The two hard-coded
  `ReservedHandles.layerZero` are replaced by `layer`, and `addDrafted` forwards it. `grep layerZero drafting.dart`
  finds nothing. The only other change is the doc comment.
- **My own check** (`r4/chk.py`). For every file in `git diff --name-only 540f9cf 4a735fb` except `drafting.dart`,
  it strips all whitespace from both sides and diffs character by character with `difflib`, autojunk off. Every
  non-equal opcode must be an insert of `,layer:ReservedHandles.layerZero` or `layer:ReservedHandles.layerZero,`.
  Output: `files 33 inserts 56 bad []`. That matches the implementer's 56. No import was added, and none was needed.
- **No caller was missed.**
  - `grep -rl "draftRecord(\|addDrafted(\|addDraftedRegion("` over the repo gives 34 files. Every one is in the
    commit's diff (`comm` shows no caller file outside it).
  - dev_harness_2d and apps/dev_harness have no caller.
  - analyze is clean in all four packages (below).
  - `layer_commands_test.dart` is outside D7's list, as reported, and is legitimate.

## Gates (re-run here at 4a735fb, CI=true, real tails)

- engine `dart test`: `00:18 +1211 -2: Some tests failed.` The 2 failures are the standing
  `test/testing/generate_document_test.dart: both text fractions default to zero and change nothing` and
  `...: the default document is the one Plan 2 measured, byte for byte`. `dart analyze`: `No issues found!`. Format:
  `Formatted 167 files (0 changed) in 0.59 seconds.`
- render `flutter test`: `01:04 +1154 ~1 -7: Some tests failed.` The 7 are, by name, `text_ladder_golden_test.dart:
  text ladder rung 1..5 (RenderBackend.canvas)` and `text_lod_ladder_golden_test.dart: text lod ladder rung 1..2
  (RenderBackend.canvas)`. analyze `No issues found! (ran in 1.6s)`. Format `Formatted 200 files (0 changed) in
  0.62 seconds.`
- app `flutter test`: `03:17 +934: All tests passed!`. analyze `No issues found! (ran in 2.1s)`. Format `Formatted 165
  files (0 changed) in 0.77 seconds.`
- dev_harness_2d `flutter analyze`: `No issues found! (ran in 1.1s)`
- `git diff main 4a735fb --stat -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants`
  is empty (exit 0).

## Mutants re-fired here (`layer_filter_test.dart`; every one `diff= 0`)

| id | mutation | result |
|---|---|---|
| M3b-1 | drop `!document.entities.containsHandle(handle) &&` | RED `00:00 +6 -1: ... an entity added at a layer record's handle is indexed (the containsHandle guard) [E]` (`00:01 +23 -1`) |
| M3b-2 | drop `_lastKnownSlot[handle] == null &&` | RED `00:00 +7 -1: ... an entity removed at a layer record's handle leaves the index (the last-known-slot guard) [E]` |
| M3b-3 | drop `document.tree[handle] == null &&` | RED `00:00 +8 -1: ... an instance added at a layer record's handle is indexed (the node guard) [E]` |
| O1 | `ownLayer != Handle.none && ownLayer != ReservedHandles.layerZero` → `ownLayer != Handle.none` | RED `00:00 +18 -1: ... with layer 0 hidden, an ATTRIB on layer 0 owned by the nested instance on layer 0 follows the instance on A; locking A unpicks it (Task 3 review, finding 2) [E]` |
| O2 | `acceptsNodeOnLayer`: `_lockedLayer(layer)) {` → `_lockedLayer(resolved.layer)) {` | RED `00:00 +20 -1: ... with layer 0 locked, the nested instance on layer 0 follows the unlocked A: its leaves on D and on layer 0 stay pickable (Task 3 review, finding 3; O2) [E]` |
| O2b | `acceptsNodeOnLayer`: `_lockedLayer(layer)) {` → `false) {` | RED `00:00 +19 -1: ... a line on an unlocked layer D inside Leg is unpickable once A is locked ... (Task 3 review, finding 3) [E]` |
| M3b-4 | drop `document.tree.definition(handle) == null` | SURVIVES (probe above); behaviour-equivalent, note 1 |

## Findings

None that need a fix.

## Notes (no action required)

1. **M3b-4 can be pinned only by cost.** One more `expect` in a new test would turn M3b-4 red. The test adds a
   definition at a layer's handle and asserts `rebuildCount - before == 1`:
   ```dart
   final shared = f.doc.handleSeed.next();
   _layerAt(f, shared, 'Shadow');
   final index = SpatialIndex(f.doc);
   addTearDown(index.dispose);
   final before = index.rebuildCount;
   f.doc.commands.execute(AddDefinitionCommand(Definition(
       handle: shared, name: 'Shadowed', basePoint: Vector2(7, -3), children: const [])));
   expect(index.rebuildCount - before, 1); // M3b-4: 0
   ```
   This pins `AddDefinitionCommand`'s documented contract ("`touched` names the definition handle, which is what
   makes the spatial index rebuild"). It does not pin a correct answer, and the mutant is cheaper and still correct
   because it relies on the defensive `_containerHolding == null` fallback. Optional. I would not block on it.
2. **Removing a definition at a layer's handle is skipped, even with the guard.** After the removal, all five
   conjuncts hold, so the empty, unreferenced definition's `ContainerIndex` stays in `_byContainer` until the next
   rebuild. Probe: `PROBE rebuilds on def removal: 0`, and after undoing the three removals the leaf is picked again
   (`PROBE after undo x3: 37`). It is harmless: no instance reaches it, its undo is a structural add, and it needs a
   malformed document. Info only.
3. **`Definition.basePoint` is not subtracted by the index.** The probe's leaf was found at the instance transform
   of the definition-local point, not of `point - basePoint`. This predates the plan and the review takes no
   position on it. It only explains why the probe's coordinates read as they do.
