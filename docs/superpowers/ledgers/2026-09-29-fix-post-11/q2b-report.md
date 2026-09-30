# Q2b report: the Q1+Q2 review's m1 and m3

**Commit:** `8605d95` on `fix/post-11`, parent `1ba7b94`. Not pushed.
`test(app): EG6 pins a root-level instance stray; gripsOf offers none on a non-live holder (post-11 review m1, m3)`

Files, both app files:
- `apps/floor_planner/lib/parametric/wall_grips.dart` (+5 −7)
- `apps/floor_planner/test/wall_grips_test.dart` (+44 −7)

## What changed

**m1: EG6 gets a third stray holder kind.**
- The fixture adds an empty definition `D` (5400) and a root-level `InstanceNode` 5300. The instance is translated by `(ox + 333.5, oy − 222.25)` and rotated by 0.8 rad, and it is added in the same `Add groups` compound.
- A `WallParams` is written straight into the store on the instance, as a file would bring it in. Its stored `end` is A's corner in world, taken back through the instance's inverse transform. Its `start` is `polar(lCorner, 173°, 1400.5)`. Thickness is 100, justification left.
- New assertions:
  - the holder is an `InstanceNode`;
  - its parent is the root;
  - the stored end is more than 1000 mm from its world point, so the fixture is not at the identity;
  - its world end is within `wallJoin.linear` of A's corner, so only liveness excludes it.
- EG6 already asserts these for the other two strays, and now asserts them for the instance stray too:
  - it stays `==` after the select-tool drag;
  - it stays `==` after the undo, and `canon` is restored;
  - the provider's command is `[wa, wb]` and the preview has two lines.
- The test name now mentions the instance and "offers no grips".

**m3: `gripsOf` filters liveness the way `drag` and `preview` do.**
- `WallGrips.gripsOf` now reads its wall from `wallsInDocument(d, group)?.host`, the same adapter that `_endsAt` (used by `drag` and `preview`) uses. A holder that is not a live wall object gets `const []`.
- The unfiltered `_world` helper had no other caller, so it is removed.
- The class doc's **Grips** bullet now says this.
- New test lines in EG6's provider section:
  - `gripsOf` on the bare stray, the nested stray and the instance stray is `isEmpty`;
  - on live wall A it is exactly `[(stretch, 0, A.s), (stretch, 1, A.e)]`, compared bitwise against `endOf(doc, wa, k)`.

## Mutants

Every mutant followed the same procedure:
1. `cp` the file to a scratchpad `q2b-*.bak`.
2. Mutate it and run `CI=true flutter test test/wall_grips_test.dart`.
3. `cp` the backup back and `diff` it against the file. Every diff exited 0.

No `git checkout` was used. The transcripts are in scratchpad as `q2b-*.txt`.

| Mutant | Change | Result |
|---|---|---|
| **M-R1** | `opening_geometry.dart` `_isLiveGroup`: `node is GroupNode && …` → `node != null && …` | **red** `+5 -1` (EG6), `q2b-mR1.txt`: `Bad state: "Stretch": floor_planner.wall written on 14B4, which is not a live root-level group after the edit, would never be regenerated (spec 06 D5); the edit is refused`. It is thrown from `_run (regeneration.dart:909)` and rethrown at `SelectTool.onPointerUp (select_tool.dart:424:19)`. Then `Expected: <1> Actual: <0>` "the commit succeeds" at wall_grips_test.dart line 454. 0x14B4 = 5300 is the instance stray. |
| **old gripsOf** | `wall_grips.dart` replaced by its `1ba7b94` content (the unfiltered `_world`) | **red** `+5 -1` (EG6), `q2b-mOldGrips.txt`: `Expected: empty Actual: [Grip(stretch 0 @ 4502761.514560358, 1201172.1933854679), Grip(stretch 1 @ 4503662.014560358, 1199971.9433854679)]` "1450 is not a live wall" at line 477. 0x1450 = 5200 is the bare stray. |

I also ran the new test before changing the lib file, with only the test edited on top of `1ba7b94`. It failed the same way as the old-gripsOf mutant: `+0 -1`, line 477, "1450 is not a live wall". The drag half of EG6, including the instance stray, passed at `1ba7b94`, as the review's PR1 predicted.

## Gate

Run at the commit's tree, with `export PATH=/root/flutter/bin:$PATH` and from `apps/floor_planner`:

- `CI=true flutter test`: exit 0, `04:13 +500: All tests passed!` (`q2b-gate-test.txt`)
- `CI=true flutter analyze`: exit 0, `No issues found! (ran in 2.1s)` (`q2b-gate-analyze.txt`)
- `CI=true dart format --output=none --set-exit-if-changed .`: exit 0, `Formatted 102 files (0 changed)` (`q2b-gate-format.txt`)

The count stays at +500 because EG6 was extended; no test was added. The engine, render and web gates were not run, because no engine or render file changed.

## Deviations and notes

- **The m3 test is in EG6, not a separate test.** It reuses EG6's three strays and live wall A, so it also covers the instance stray.
- **"Stored end" is read literally.** The instance stray's `end` field is the one on the corner. The bare stray uses `start` and the nested one uses `end`.
- **Cost:** `gripsOf` now builds `wallsInDocument`'s neighbour list, which is O(walls), where it used to build a single `WorldWall`. It runs only when the grip cache rebuilds on a selection change (`grip_cache.dart` `_rebuild`). That is not the steady-state frame path, and `drag` already paid the same cost.
- Nothing is staged or committed outside the two files. `analysis_options.yaml` was not touched.
