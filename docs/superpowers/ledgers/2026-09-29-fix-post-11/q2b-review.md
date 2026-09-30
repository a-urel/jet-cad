# Q2b review: 8605d95 (fix/post-11), the Q1+Q2 review's m1 and m3

Reviewed in the detached worktree `.claude/worktrees/fix-post-11-review2` at `8605d95` (parent `1ba7b94`). Nothing was committed or pushed. `git status --short` was empty before the mutants, after them and after the gate. Transcripts are in scratchpad as `q2br-*.txt`.

## Verdict: **Approved**

There are no Important findings and one cosmetic Minor finding.

## (1) Scope: m1 and m3 are done as ruled, and nothing else changed

- `git diff --stat 1ba7b94 8605d95` shows two files, both app files: `lib/parametric/wall_grips.dart` (+5 −7) and `test/wall_grips_test.dart` (+44 −7).
- **m1** (ruling: "EG6 gains a root-level-instance stray"). EG6 adds an empty definition 5400 and a root-level `InstanceNode` 5300, translated by `(ox+333.5, oy−222.25)` and rotated 0.8. A file-style `WallParams` is attached straight into the store on the instance, with its stored `end` equal to A's corner in world, taken back through the instance's inverse. The instance stray gets every assertion the other two strays get:
  - it is on the joint within `wallJoin.linear`;
  - it is `==` after the select-tool drag;
  - it is `==` after the undo, and `canon` is restored;
  - `gripsOf` offers no grips on it.

  It also gets three assertions of its own: `isA<InstanceNode>()`, parent `== rootHandle`, and stored end more than 1000 mm from its world point.
- **m3** (ruling: "`gripsOf` offers no grips on a non-live holder, consistent with drag/preview"). `gripsOf` now reads `wallsInDocument(d, group)?.host`, the same adapter `_endsAt` uses for `drag` and `preview`. `_world` is removed. `grep` finds no other caller in `lib`, and a test cannot reach a private helper. The class doc's Grips bullet is updated.
- No other line of `lib` changed.

## (2) EG6's instance stray is non-degenerate, and M-R1 turns EG6 red

- **The fixture is not at the identity or the origin:**
  - the instance is translated and rotated;
  - `(strayInst.end − lCorner).length > 1000` is asserted;
  - its world end is asserted within `wallJoin.linear` of A's corner, so only liveness keeps it off the joint;
  - the stray has a non-default thickness (100), and its start is 1400.5 mm off at 173°.
- **Re-fired M-R1** (`opening_geometry.dart` l.702, `return node is GroupNode && …` → `return node != null && …`), running `CI=true flutter test test/wall_grips_test.dart`: **red** `00:05 +5 -1: Some tests failed.` (`q2br-mR1.txt`).
  - `Bad state: "Stretch": floor_planner.wall written on 14B4, which is not a live root-level group after …`, thrown from `_run (regeneration.dart:909:5)` through `SelectTool.onPointerUp (select_tool.dart:424:19)`.
  - Then `Expected: <1> Actual: <0>` at wall_grips_test.dart line 454 ("the commit succeeds").
  - 0x14B4 = 5300 is the instance stray, so the new holder kind is the one that kills it.

## (3) `gripsOf` before and after

- **On a live wall the grips are bitwise the same.**
  - With `moved` empty, `wallsInDocument`'s `host` is `WorldWall(host, p, doc.tree.accumulatedTransform(host))` (opening_geometry.dart l.724–726). That is the same expression as the removed `_world` (`WorldWall(h, p, d.tree.accumulatedTransform(h))`).
  - `wallsInDocument` returns null exactly when `p == null` or `!_isLiveGroup`.
  - So the only change is the non-live case, where it now returns `const []`.
- **On a non-live holder it offers no grips.** The bare, nested and instance strays all get `isEmpty` in EG6.
- **Nothing that relied on the old `gripsOf` changed behaviour.**
  - **Grip cache:** `grip_cache.dart` l.353–360 calls `provider.gripsOf` only for a `GroupNode` whose parent is `document.rootHandle`, and `rootHandle => tree.root` (draft_document.dart l.118). That is `_isLiveGroup`'s own condition, so every key the cache asks about is live, and it gets the same grips as before.
  - **Other callers:** `ObjectGrips.gripsOf` only dispatches. No other `lib` code in the app or the render package calls `WallGrips.gripsOf`.
  - **Cost:** the cache rebuilds on the outlines listener (grip_cache.dart l.187/l.325), not per frame. The extra neighbour walk is O(walls) per rebuild, which `drag` already pays.
  - **The select tool's grip hover and drag on a live wall:** EG1–EG5 and EG6's drag half pass at HEAD. My mutant M-Q2br-B below shows those paths read `gripsOf`'s positions.
- **Re-fired the old `gripsOf`** (`wall_grips.dart` replaced by `git show 1ba7b94:…`, which is the unfiltered `_world`): **red** `00:05 +5 -1` (`q2br-mOldGrips.txt`).
  - `Expected: empty Actual: [ …` "1450 is not a live wall", at wall_grips_test.dart line 477. 0x1450 = 5200 is the bare stray.
  - The first failure is at l.477, after the drag half (l.454–470). This confirms the report's claim that the drag half, including the instance stray, passed with 1ba7b94's lib.

### Mutants I designed

**M-Q2br-A: `gripsOf` checks the parent only.**
- Change:
  ```dart
  final p0 = d.components.get<WallParams>(group);
  final w = p0 == null || d.tree[group]?.parent != d.tree.root
      ? null
      : WorldWall(group, p0, d.tree.accumulatedTransform(group));
  ```
- This passes the bare stray (no node) and the nested stray (parent is not the root). Only the instance can kill it.
- Result: **red** `00:05 +5 -1` (`q2br-mOwnA.txt`), `Expected: empty Actual: [ …` "14B4 is not a live wall", line 477.
- So the instance entry in the `gripsOf` loop is load-bearing on its own.

**M-Q2br-B: a live wall's grips at the identity transform.**
- Change: `WorldWall(group, h0.params, Transform2.identity())` after the liveness check.
- Result: **red** `00:08 +1 -5` (`q2br-mOwnB.txt`):
  - EG1: `Expected: <0> Actual: <1>`, l.175;
  - EG2: grip positions, l.207;
  - EG3: l.243;
  - EG4: `Actual: <496.56…>`, l.326;
  - EG6: `Actual: <642.00…>`, l.456.
- So the select tool's grip hover and drag on a live wall depend on `gripsOf`'s world positions, and those positions are pinned.

**Procedure for every mutant:**
1. `cp` the file to scratchpad `q2br-og.bak` or `q2br-wg.bak`.
2. Mutate it and run with `CI=true`.
3. `cp` the backup back and `diff` it against the file. Every `diff` exited 0.

No `git checkout` was used.

## Minor

**m1 (cosmetic): a stale doc comment.** `wall_grips.dart` l.152–154, `_endsAt`'s doc, still lists a file's stray `WallParams` as "(on a handle with no node, or on a nested group)". EG6 now also pins a third kind, the root-level instance. The wording could be "(on a handle with no node, a nested group or a root-level instance)" or "(on any holder that is not a root-level group)". This is optional and does not affect behaviour.

## Gate (`export PATH=/root/flutter/bin:$PATH`, `apps/floor_planner`, at 8605d95)

- `CI=true flutter test`: exit 0, `03:48 +500: All tests passed!` (`q2br-gate-test.txt`)
- `CI=true flutter analyze`: exit 0, `No issues found! (ran in 5.3s)`
- `CI=true dart format --output=none --set-exit-if-changed .`: exit 0, `Formatted 102 files (0 changed) in 0.95 seconds.`

This matches the expected +500. The engine and render gates were not run, because no file in either package changed.

## The report checked against evidence

- Hash, parent, files and line counts match `git show`.
- M-R1 reproduces: the same handle (14B4), the same throw site (regeneration.dart:909 through select_tool.dart:424), and the same line (454).
- The old-`gripsOf` mutant reproduces: the same handle (1450) and the same line (477).
- The cost note is correct: the extra work runs on a grip-cache rebuild only, not per frame.
- The deviations (the m3 test sits inside EG6, and "stored end" is read literally) are sound.
