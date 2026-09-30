# L2b review: independent review of 9a4df2a

**Verdict: Approved.** There is one minor, non-blocking finding (R1) about test coverage.

- **Worktree:** the detached review worktree `…/fix-live-object-rule-review`, at HEAD `9a4df2a`.
- **Commits:** 3 files changed, +194 and −2. The commit carries both trailers.
- **What I did:** nothing was committed or pushed. `git status` shows only the standing pub-get rewrite of `packages/jet_cad/analysis_options.yaml`, which is not committed.
- **Scratch files:** the logs are `…/scratchpad/l2br-log-<M>.txt` and `l2br-gate-*.txt`. The mutation driver is `l2br-mut.py`.

## `lib` is unchanged

`git diff 980947d 9a4df2a -- apps/floor_planner/lib` touches `wall_grips.dart` l.19–24 only.
- It is a pure rewrap of the doc comment: the same words over three lines instead of two. No code changed.
- m5 is met.
- The report says lines 72 and 115 exceed 80 in bytes only. That is confirmed:
  - l.72 is 73 characters and 81 bytes.
  - l.115 is 76 characters and 82 bytes.
  - Both go over in bytes because of `′`.

## EG10 (m1) is real and non-degenerate

- **The group:** it is a **dimension** group at handle `0x1A2B`, at the root, and not the lowest handle.
  - It is translated to `(ox+820.5, oy−1330.25)`, off the far origin, and rotated 0.7 rad.
  - It is made through `CompoundCommand` plus the dispatcher, as the app makes a dimension.
  - The premise `kids(doc, dim)` is not empty.
- **The stray:** the `WallParams` is attached through `doc.components.attach`, which bypasses commands and regeneration. That is how a file would bring it in.
  - It is 400 thick and left-justified, in the group's local frame.
- **The premises:**
  - The stray's world start is within `wallJoin.linear` of A's corner, so only the live-object rule keeps it out of the drag.
  - It is more than 1000 from `(ox, oy)`.
- **The L:** each wall is in its own rotated group at the far origin (`addL`, `gripDoc`).
- **The controls:**
  - `hostAt(A mid) == wa`
  - `inputOf(wa) != null`
  - `DimensionGrips` gives 3 grips, and `ObjectGrips` equals them.

## TT10 (m2) is real, and the report's claims about the two sites are right

- **`_cacheFace` (l.278):** it transforms each live room's seed to world and sets the "occupied" notice when the seed is in the face. This is confirmed from the code.
- **`_nextName` (l.352):** it collects the `Room N` numbers that live rooms hold. This is confirmed from the code.
- **Both sites can be reached by a file:** the fixture reaches each one. I agree that neither site is unreachable.
- **The fixture:**
  - It uses two dimension groups. Each is rotated (0.8 and −1.2 rad) and translated, and each is regenerated as a dimension.
  - The premises assert children, `isLiveObject<DimensionParams>` and the root parent.
  - `RoomParams` is attached through the store.
  - Premises: the world seed is in the face, the local seed is not, `outside`'s seed is outside the box, and `rooms(doc)` is empty.
  - It runs at both `origin` and `corpusGroups`.
- **Registration order:** in `catalog.dart`, Dimension is registered after Room, and Room after Wall. So each shadowed group is a dimension, as both tests assume.

## Mutants I fired

**Procedure:**
- `cp` the file to `l2br-bak-*`.
- Mutate it with the python driver. The driver asserts that the replaced text occurs exactly once.
- Run `CI=true flutter test --no-pub <file>`.
- `cp` the backup back and `diff` it. **Every restore diff exited 0.**

"Narrowed" means: a root `GroupNode` carrying `WallParams` and no `OpeningParams`, sorted by handle.

| Mutant | Change | Result | Red test, line |
|---|---|---|---|
| **M-RV-narrowBands** | `wall_bands` l.130 loop over narrowed walls | `+9 -1` | EG10 `wall_grips_test.dart:815`: `Expected: null  Actual: <6699>` |
| **M-RV-narrowAdapter** | `wallsInDocument`'s walls (`opening_geometry` l.720) narrowed | `+9 -1` | EG10 `:807`: `Actual: [2600, 3900, 6699]` |
| **M-L2-5t-face** | `_cacheFace` on the old spelling (root `GroupNode` carrying `RoomParams`, sorted) | `+10 -1` | TT10 `room_tool_test.dart:962`: `Actual: 'Already a room: Den'` |
| **M-L2-5t-name** | `_nextName` on the old spelling | `+10 -1` | TT10 `:968`: `Actual: RoomParams((2100.5, 1300.75), Room 2, null)` |
| M-R-attachThick (own) | `thickestWall` over every `withComponent<WallParams>` | `+8 -2` | EG9 `:694` and EG10 `:820`: `Actual: <400.0>` |
| M-R-hostCheck (own) | `wallsInDocument` host check becomes `get<WallParams> != null` | `+7 -3` | EG6, EG9 and EG10 (the adapter is not null) |
| M-R-attachOwner (own) | `attachCandidates` l.124 becomes `get<WallParams>(owner) != null` | `+9 -1` | EG9 `:697` only. EG10 passes |
| M-R-faceLocalSeed (own) | `_cacheFace` reads `r.seed` without the group transform | `+10 -1` | TT3 `:444` (an existing test). TT10's local-seed premise is consistent with this |
| **M-R-narrowAttach (own)** | `attachCandidates` l.124 narrowed | **survives**: `+10` in `wall_grips_test`, **`+514` in the full app suite** | none (see R1) |

## Findings

**R1 (minor, non-blocking): EG10's attach-candidates assertion is vacuous.**
- **The mutant:** M-R-narrowAttach narrows `dimension_attach.dart` l.124's owner check in the same way M-RV-narrowBands narrows the band cache. It survives the whole suite (`l2br-log-narrowAttachFull.txt`, `02:32 +514: All tests passed!`).
- **Why the assertion catches nothing:**
  - `attachCandidates` finds walls by the owners of indexed entities within `dimAttach.linear` of `q`.
  - The stray has no drawn entities of its own. Its group's entities are the dimension's.
  - EG10 queries at `ws.e`, 1800 out along the stray, which is presumably far from the dimension's drawn line and text. So `dim` never becomes a candidate owner.
  - `isNot(contains(dim))` therefore holds under any rule.
- **What EG9 does instead:** EG9 kills the unnarrowed version because its shadow tip is placed on "a point of the door's own children". EG10 did not copy that construction.
- **What the mutant would do in the app:** if `q` is near the dimension's drawn geometry and on the stray's line, `_wallPointsOf` reaches `wallsInDocument(doc, dim)!`, which is null, so the attach would throw.
- **Suggested fix:** run the attach query at a point that is both on one of the stray's three lines and within `dimAttach.linear` of the dimension's children. This mirrors EG9's `shadowTip`.
- **Scope:** the brief's list for m1 did not name the attach site, so this is not blocking. But the test title and the commit message both claim that EG10 covers "the attach's", and it does not.

Beyond R1, every claim in the report that I checked matched what I reproduced:
- the fixture;
- what each site decides;
- the four named mutants and their red lines;
- the gates.

I did not re-run the implementer's own M-RV-narrowHost, narrowThick, narrowRoomInputs, narrowGrips and narrowPanel. My M-R-hostCheck and M-R-attachThick are stronger versions of narrowHost and narrowThick, and they are red on EG10.

## Gates (clean tree, `export PATH=/root/flutter/bin:$PATH`, `CI=true`, `apps/floor_planner`)

| Gate | Exit | Output |
|---|---|---|
| `flutter test --no-pub` | 0 | `02:33 +514: All tests passed!` |
| `flutter analyze` | 0 | `No issues found! (ran in 1.7s)` |
| `dart format --output=none --set-exit-if-changed .` | 0 | `Formatted 104 files (0 changed)` |

I did not re-run `flutter build web`, because `lib` changed by a comment only. The packages were not re-run either, since no `packages/` file is in the commit.
