# L2b report: m1, m2 and m5 from the L2 review

**Commit:** `9a4df2a` on `fix/live-object-rule`, on top of `980947d`. Not pushed.
- The commit touches three files: two test files and one doc-comment wrap. `lib` behaviour is unchanged.
- `packages/jet_cad/analysis_options.yaml` has the standing pub-get rewrite. It is not committed.

## Tests (`apps/floor_planner/test`)

### m1: EG10 in `wall_grips_test.dart`

**Fixture:**
- The L (A 1300, B 2600, C 3900) from `addL`.
- A **dimension** group, `0x1A2B`, at the root. It is translated to `(ox + 820.5, oy − 1330.25)` and rotated 0.7 rad.
- The group is made as the app makes a dimension: `FixedEnd`s, offset 350.5, regenerated through the dispatcher. The premise asserts it has children.
- `WallParams` is then attached **through the store**, as a file would bring it in: 400 thick, left-justified, starting from the L's corner. The premise asserts that the start is on the joint within `wallJoin.linear` in world, and that it is more than 1000 from `(ox, oy)`.

**What EG10 asserts:**
- `wallsInDocument(dim)` is null.
- A's other walls are `[wb, wc]`.
- `WallBands.hostAt` at a point in the stray's band is null. As a control, A's midpoint gives `wa`.
- `thickestWall` is 200.
- `attachCandidates` at the stray's far end has no `dim` entry.
- `RoomInputs.inputOf(dim)` is null. As a control, `inputOf(wa)` is not null.
- `WallGrips().gripsOf(dim)` is empty. `ObjectGrips` (built with an index) gives exactly `DimensionGrips`' 3 grips.
- `WallGrips.drag` of A's corner has the children `[wa, wb]`.
- The corner drag through the select tool:
  - throws nothing;
  - lands one undo step;
  - leaves `dim`'s `WallParams` and `DimensionParams` `==` their loaded values;
  - is fully reversed by undo (`canon`).
- The panel shows `dimension-section` for `dim`, and no `wall-section`.

### m2: TT10 in `room_tool_test.dart`

**What each site decides:**
- **`_cacheFace` (l.278):** whether a live room's world seed lies in the hovered face. If one does, the verdict is "occupied": the notice reads `Already a room: <name>`, there is no preview, and a click places nothing.
- **`_nextName` (l.352):** which `Room N` numbers live rooms already hold. The new room takes the lowest free one.

**Fixture:**
- The plan is `boxWalls` at `origin` and at `corpusGroups`.
- There are two dimension groups at the root. Each is made as the app makes a dimension, in its own rotated, translated group, and each is regenerated as a dimension (the premise asserts children, `isLiveObject<DimensionParams>` and the root parent).
- `RoomParams` is then attached through the store to each group:
  - `inFace` is named `Den`. Its world seed lies in the box's face, and its local seed does not (both are premises).
  - `outside` is named `Room 1`. Its seed lies outside the box.
- Premise: `rooms(doc)` is empty.

**What TT10 asserts:**
- A hover in the face gives no notice and a 1-ring preview.
- A click lands one step and creates exactly one room, `RoomParams(p.x, p.y, 'Room 1')`.
- As a control, the notice then reads `Already a room: Room 1`.

Neither site is unreachable: a file can bring either case in.

### m5

The `wall_grips.dart` doc-comment line (l.22) is rewrapped to three lines, each at most 80 columns. Lines 72 and 115 exceed 80 only in bytes, because of `′` (U+2032). In characters they are within 80.

## Mutants

**Procedure for every mutant:**
1. `cp` the file to `…/scratchpad/l2b-final-*.bak`.
2. Mutate the file.
3. Run `CI=true flutter test --no-pub`.
4. `cp` the backup back and `diff` it against the file. **Every diff exited 0.**

**Test files and logs:**
- `M-RV-*` ran `test/wall_grips_test.dart`.
- `M-L2-5t-*` ran `test/room_tool_test.dart test/room_inputs_test.dart`.
- The logs are `…/scratchpad/l2b-final-<M>.log`.
- The line numbers are those of the committed files, re-run after `dart format`.

On the committed code, every one of these passes.

| Mutant | Change | Result | Red test, line |
|---|---|---|---|
| **M-RV-narrowBands** | `wall_bands` cache build: live root group walk over `withComponent<WallParams>`, skipping only groups carrying `OpeningParams` | `+9 -1` | EG10 l.815, `Expected: null  Actual: <6699>` |
| **M-RV-narrowAdapter** | `wallsInDocument`'s other walls: live root group and no `OpeningParams` | `+9 -1` | EG10 l.807, `Actual: [2600, 3900, 6699]` |
| M-RV-narrowHost (own) | `wallsInDocument`'s host check narrowed the same way | `+9 -1` | EG10 l.806 (not null) |
| M-RV-narrowThick (own) | `thickestWall` narrowed the same way | `+9 -1` | EG10 l.820, `Actual: <400.0>` |
| M-RV-narrowRoomInputs (own) | `RoomInputs._refresh` walls narrowed the same way | `+9 -1` | EG10 l.830, `RoomInput(1A2B, band, …)` |
| M-RV-narrowGrips (own) | `ObjectGrips._of` wall line narrowed the same way | `+9 -1` | EG10 l.842, `Actual: []` |
| M-RV-narrowPanel (own) | `_isObject<WallParams>` narrowed the same way | `+9 -1` | EG10 l.865 (`wall-section` found) |
| **M-L2-5t** | `room_tool` `_cacheFace` and `_nextName` both on the old body (root `GroupNode` carrying `RoomParams`, sorted) | `+13 -1` | TT10 l.962, `Actual: 'Already a room: Den'` |
| M-L2-5t-face (own) | `_cacheFace` alone | `+13 -1` | TT10 l.962, same |
| M-L2-5t-name (own) | `_nextName` alone | `+13 -1` | TT10 l.968, `Actual: RoomParams((2100.5, 1300.75), Room 2, null)` |

"The same way" means the `_narrowWall` / `_narrowWalls` helper: a root `GroupNode` carrying `WallParams` and not `OpeningParams`.

**A first-run slip:** on the first run of M-RV-narrowRoomInputs, the mutant did not compile, because `room_inputs.dart` does not import `OpeningParams`. I restored the file (diff 0), then re-ran it with the import added, and it went red as shown in the table.

## Gates (`export PATH=/root/flutter/bin:$PATH`, `CI=true`, app `apps/floor_planner`, final tree)

| Gate | Exit | Output |
|---|---|---|
| `flutter test --no-pub` | 0 | `02:40 +514: All tests passed!` (512 + EG10 + TT10) |
| `flutter analyze` | 0 | "No issues found!" |
| `dart format --output=none --set-exit-if-changed .` | 0 | "Formatted 104 files (0 changed)" |
| `flutter build web --release` | 0 | "✓ Built build/web" |

- The transcripts are `…/scratchpad/l2b-gate-*.txt`.
- The engine and render packages are untouched (no `packages/` file in the commit), so they were not re-run.

## Outside scope

- The review's m3 and m4 (the report's grep claim and the 08 spec sentence l.1196–1198) were not part of this brief. They are untouched.
- The review's other cosmetic item under m5 (the 11 amendment's one line over 80 columns) was left alone. The brief named only `wall_grips.dart`.
