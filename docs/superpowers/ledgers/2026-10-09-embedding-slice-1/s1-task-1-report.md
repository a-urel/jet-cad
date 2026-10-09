# Slice 1, Task 1 — a table's detail and `tableAt` (G-1, G-4): report

**Commit:** `85918c4` on `claude/exciting-pasteur-9m22jv` (parent `a136a43`), not pushed. (A first commit, `22a9a6e`, was amended to move the fixture's page; see F-3.)

## What was built

| File | What |
|---|---|
| `packages/jet_cad_floor_plan/lib/src/host/table_detail.dart` (new) | `final class FloorPlanTableDetail` (`table`, `center`, `size`, `rotation`, `mirrored`, `corners`, `layer`, `locked`, `data`), `@immutable`, a public `const` constructor (`data` defaults to `const {}`), `==` (`listEquals` for corners, `mapEquals` for data), `hashCode`, `toString`, documented. Two internal builders: `tableDetailOf` (G-1's decomposition) and `tableDetailWithoutGeometry`. |
| `lib/src/host/floor_plan_controller.dart` | `List<FloorPlanTableDetail> get tableDetails` (cached) and `String? tableAt(Offset canvasPoint, {PointerDeviceKind kind = PointerDeviceKind.mouse})`. Nothing existing changed. |
| `lib/jet_cad_floor_plan.dart` | `export 'src/host/table_detail.dart' show FloorPlanTableDetail;` |
| `test/host/barrel_test.dart` | B1's pinned set gains `'FloorPlanTableDetail'` (the allowed edit; nothing else). |
| `test/host/embedding_fixture.dart` (new) | The slice's shared fixture (below). |
| `test/host/table_detail_test.dart` (new) | TD0–TD10, TA1–TA3. |
| `test/host/controller_test.dart` | One appended test, CD1 (the mode follow), and the import `'embedding_fixture.dart' as embedding`. No existing test changed. |

### The decomposition (G-1)

From a `TableCandidate` (`transform` m, `box`, `corners`):
- `rotation = atan2(m.b, m.a)`, normalised to `(-π, π]`, `-0.0` stored as `0.0` (so `==` and `hashCode` agree);
- `mirrored = m.determinant < 0`;
- `size = Size(box.width · |(a, b)|, box.height · |(c, d)|)`;
- `center` = m applied to the box's centre;
- `corners` = the candidate's four world corners, as given when unmirrored, `[0, 3, 2, 1]` when mirrored: counter-clockwise (y up) from the image of the box's (min x, min y) corner, unmodifiable.

### `tableDetails`

`TablePicker.candidatesOf(d, boxes: {}, leaves: d.leavesByOwner)` mapped by instance, joined to the controller's cached survey (`_tables`), ascending by handle, for `_active` (the service copy in the selection mode). `FloorPlanTable` is built exactly as `tables` builds it (layer visibility read from the instance's layer). `layer` is the layer's name, `locked` its lock. A survey table with no candidate gets `center: null`, `size: null`, `corners: const []`, `rotation: 0`, `mirrored: false`. Cached in four fields (`_details`, `_detailsDocument`, `_detailsState`, `_detailsLayers`), rebuilt when the active document is not identical or `commands.stateId` or `tables.mutationRevision` moved; the list is `List.unmodifiable`, so two reads at one key are `identical`.

### `tableAt`

The active plan's `TablePicker`, kept while (document, `stateId`, `mutationRevision`) hold and rebuilt otherwise; `camera.value.screenToWorld(point)`; reach `kTouchPickRadiusPixels / camera.scale` (24 px, the interaction layer's own constant, exported by `jet_cad_2d_flutter`) for `PointerDeviceKind.touch`, else 0; returns `pick(...)?.table.number`. It uses the current `@internal camera` (Task 2 renames it).

### The fixture (`test/host/embedding_fixture.dart`)

- `embeddingTable`: a hand-written servable `FurnitureSymbol` (4 seats), its top an asymmetric quadrilateral `(300,-200) (1100,-200) (900,400) (300,250)`, base point (0, 0). `embeddingBox` = (300..1100, -200..400): its centre (700, 100) is not the base point. TD0 checks the document's `definitionBounds` equals it.
- `embeddingTables` (each with its transform, degrees, sx, sy, layer, finite), placed in this order: `1` at 30°; `2` mirrored at 90° (`R(90°)·diag(1, -1)`, so `a = cos 90° ≥ 0`); `3` scaled (1.5, 0.8) at -20°; `4` at 180° unmirrored; `5` on the hidden layer; `L` mirrored at 120° on the locked layer; `7` at 60° and ` 7 ` mirrored at -150° (a shared number); an unnumbered table at 15°; `9` with `Transform2(1e306, 0, 0, 1e-306, …)` (det 1, no corner finite). Every table is 40 m or more from the origin and 3–4 m from the next.
- A page, A4 landscape at 1:50, at (37,000..51,850, -36,200..-25,700) mm. It holds every finite table's box, (39,929..48,841, -35,116..-25,900), so a view's first fit frames the page and not the extents that table 9 makes infinite (for later tasks that mount a view).
- `embeddingCamera()`: `Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.5)`, set before every call. `canvasOf(camera, x, y)`: the forward map.
- Tests compute every expectation from `embeddingBox` and each table's own transform (`near` = `closeTo` relative 1e-12, absolute 1e-12 near 0).

## Choices the spec and plan left open

1. **A non-candidate's `mirrored`** is `false`. The spec names `rotation: 0` but not `mirrored`. A table with no geometry reports none, consistently.
2. **The corner order** starts at the image of the box's (min, min) corner, and a mirrored table's is walked backwards from that same corner (`[0, 3, 2, 1]`). The spec says only "counter-clockwise".
3. **A layer missing from the plan's layers** (a hand-edited file) reads `layer: ''`, `locked: false`, visible true, as the picker reads it.
4. **The public constructor** takes `data` (default `const {}`), so a host can build details in its own tests. Slice 2 fills `data` from the plan.
5. **`tableAt`'s picker is rebuilt per (document, state, layers revision)**, not kept for the document's life. `TablePicker` keeps definition boxes and tops forever, which is safe only under `runtime` permissions (its R-8), and the design plan can change a definition.
6. **The mode-follow test** is in `controller_test` (CD1), as the plan places it, reaching the fixture through a prefixed import so none of `controller_test`'s own helpers is shadowed.
7. **The M-H15 killer** hides the layer with a table edit outside the history (`layers..remove..add`, which moves `mutationRevision` but not `stateId`), then runs an edit and its undo so `revision` moves while `stateId` returns to the cached one. A `SetLayerCommand` hide would also move `stateId`, so it would not separate the mutant from the original.

## Mutants (each applied, seen red, restored from a copy; never `git checkout`)

Each mutant was applied by a script that copied the file aside, replaced exactly one occurrence, ran `flutter test test/host/table_detail_test.dart test/host/controller_test.dart` (exit 1 every time), and restored the file from the copy with `cmp` confirming it. Red lines are copied from the run logs.

| Mutant | Edit | Killer | Red line |
|---|---|---|---|
| M-H1 | `cx, cy = box.minX, box.minY` | TD2 (also CD1) | `Expected: a numeric value within <4.055621778264911e-8> of <40556.21778264911>` / `Actual: <40359.80762113533>` |
| M-H2 | `rotation = -atan2(b, a)` | TD3 | `Expected: a numeric value within <1e-12> of <0.5235987755982988>` / `Actual: <-0.5235987755982988>` |
| M-H3 | `mirrored = m.a < 0` | TD4 (also TD6) | `Expected: false` / `Actual: <true>` (reason `180 degrees, unmirrored`) |
| M-H4 | `tableDetails` reads `_design.document` | CD1 (also TD8) | `Expected: a numeric value within <4.055621778264911e-8> of <41306.21778264911>` / `Actual: <40556.21778264911>` |
| M-H13 | `center = Offset(m.e, m.f)` | TD2 (also CD1) | `Expected: a numeric value within <4.055621778264911e-8> of <40556.21778264911>` / `Actual: <40000.0>` |
| M-H14 | `size = Size(box.width, box.height)` | TD5 (also TD6) | `Expected: a numeric value within <1.2e-9> of <1200.0>` / `Actual: <800.0>` |
| M-H15 | cache key without `_detailsLayers` | TD9 | `Expected: null` / `Actual: Offset:<Offset(42736.6, -30343.8)>` |
| M-H19b(tableAt) | `reach = false ? … : 0.0` (reach ignored) | TA2 | `Expected: '1'` / `Actual: <null>` |

## Gates (real output tails)

`export PATH=/root/sdk/flutter/bin:$PATH CI=true`.

- `packages/jet_cad_floor_plan`:
  - `flutter test` → `04:32 +1452: All tests passed!` (and `04:24 +1452: All tests passed!` after F-3's page move)
  - `flutter analyze` → `No issues found! (ran in 4.8s)`
  - `dart format --output=none --set-exit-if-changed .` → `Formatted 245 files (0 changed) in 1.30 seconds.`, exit 0.
- `apps/restaurant_demo`: `00:24 +39: All tests passed!`; `No issues found! (ran in 4.7s)`; `Formatted 4 files (0 changed) in 0.06 seconds.`, exit 0.
- `apps/floor_planner`: `01:35 +212: All tests passed!`; `No issues found! (ran in 6.5s)`; `Formatted 47 files (0 changed) in 0.21 seconds.`, exit 0.
- `packages/jet_cad_2d`: `dart test --file-reporter json:/tmp/e.json` (exit 1, the standing two), then `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d /tmp/e.json` → `packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly`, exit 0.
- `packages/jet_cad_2d_flutter`: `flutter test --file-reporter json:/tmp/r.json` (exit 1, the standing seven), then `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter /tmp/r.json` → `packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly`, exit 0.

`git status` was clean apart from this task's files before the commit; no `analysis_options.yaml` was touched.

## Findings

- **F-1, the brief's comparison command.** `--package jet_cad_2d` (the bare name, as the brief wrote it) reports both standing engine failures as `new failure`. `standing_failures.txt` keys lines by path, and CI passes `--package ${{ matrix.package }}` = `packages/jet_cad_2d`. The plan's form (`--package <pkg> --root <pkg>`) is right when `<pkg>` is the path. Every gate above uses the path. Worth fixing in later task briefs.
- **F-2.** No existing test needed changing beyond the barrel's pinned set. `controller_test` gained one test and one prefixed import.
- **F-3, fixed before the final commit.** The fixture's first page, at origin y -38,000 (top edge -27,500), left tables `1`–`4` partly off the page. The origin moved to y -36,200, so the page now holds every finite table's box (computed from the fixture's transforms). After the move, all eight mutants were run again (same killers, same red lines as in the table above), and so were the planner's full `flutter test` (`04:24 +1452: All tests passed!`) and format (`Formatted 245 files (0 changed)`, exit 0). The commit was then amended.
