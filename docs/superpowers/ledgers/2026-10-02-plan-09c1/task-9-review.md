# Task 9 review — leaf-equal reuse (spec D10)

Reviewer: independent, detached worktree `.worktrees/plan-09c1-review-t9` at `a073fb5`.
Diff reviewed: `git diff 54eab37..a073fb5` (2 files: `apps/floor_planner/lib/symbols/symbol_placer.dart`, `apps/floor_planner/test/symbols/symbol_placer_test.dart`).
Scratch: `/tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review9/` (gate logs, mutant logs and diffs under `mut/`, `mutate.py`, `run_mut.sh`, the probe test `zz_review_probe_test.dart`).

## Verdict: Needs fixes

The implementation is correct against D10 / W-11. Three mutants on load-bearing lines survive the committed tests; for each I wrote a probe test that turns it red. The fix is three tests. No production code changes.

## Implementation vs spec D10 (rev 4, W-11)

- **Base point.** `symbol_placer.dart:199`: exact `!=` on x and y. Correct. The test only moves y (finding 1).
- **No child nodes.** `:200`: `doc.tree.childNodesOf(def.children).isNotEmpty`. This is the tree's shared predicate, so a DXF leaf handle in `children` is not counted as a node. Correct.
- **Live leaf count.** `:203-208`: live slots whose `ownerAt == definition`, compared to `entry.leaves.length`. Correct.
- **Pairwise record equality except handle/owner/geomIndex (R-C9-1).** The live record goes through `copyWith(handle, owner, geomIndex := entry's)` and is then compared with `EntityRecord.==`. I read `packages/jet_cad_2d/lib/src/store/entity_store.dart:31-212`. Its `==` (`:178-194`) compares all 15 fields: handle, owner, kind, layer, linetype, linetypeScale, geomIndex, color, lineweight, transparency, flags, text, tag, textStyle, textAttrs. It is not identity and not partial. `copyWith` (`:89-120`) covers the same 15. So after normalising, the remaining 12 fields are exactly D10's list. `DraftColor` subclasses have value `==` (`document/style.dart:30-64`), and `encodeColor`/`decodeColor` round-trip exactly in the column store. The record `==` uses double `==` for `linetypeScale`, which is exact.
- **Payload.** `GeometryPayload.==` (`store/geometry_store.dart:70-74`) is `listEquals<double>` on `coords` and `scalars`, which is element-wise `!=` with a length check (`core/list_equality.dart`). That is exact, not identity. `-0.0 == 0.0` is accepted per D10, and L3 states it.
- **Pairing order (R-C9-2).** The document side is sorted ascending by handle (`:206-207`). The entry side is taken in list order. `SymbolEntry`'s doc (`symbol_library.dart:34`) promises ascending handle, and the loader sorts. This is acceptable, but the public `SymbolEntry` constructor does not enforce the order (note 4).
- **R-C9-3.** Accepted. The text-style edit points `textStyle` at a layer handle. `isLeafEqual` reads no table, and L1 never asserts `validate()`.
- **Lookup.** The candidates come from `withComponent<SymbolComponent>()`, which `ComponentStore.handles` sorts ascending (`component.dart:46-50`). A non-equal candidate is passed over and the search continues. When none qualifies, the copy uses the pre-existing `#n` rule. The commands are built once, so redo reuses the same handles. Undo/redo is unaffected.
- **Frame path.** The only callers of `placeSymbol` are `SymbolPlaceTool._place` (`symbol_place_tool.dart:294`, the pointer-up commit) and `symbolThumbnailDocument` (`symbol_panel.dart:44`, a fresh document with no candidate, so `isLeafEqual` is never reached). Cost is O(live entities x candidates) per click and never per paint. Confirmed off the frame path.
- **Allocation.** None on any frame path. `entities.read` and `geometry.read` allocate per leaf per placement, which is fine.
- **Draw order.** Unchanged. A copy's leaves are still added in the entry's ascending order.
- **Permissions.** Unchanged. `isLeafEqual` is pure and issues no command.

## Gates (re-run by me, `CI=true`, `PATH=/root/flutter/bin:$PATH`, in `apps/floor_planner`)

| Gate | Mine | Implementer |
|---|---|---|
| `flutter test` | `05:12 +1121: All tests passed!`, exit 0 | `+1121: All tests passed!` |
| `flutter analyze` | `No issues found! (ran in 5.6s)`, exit 0 | No issues found |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 | 180 files, 0 changed |
| `flutter build web --release` | `✓ Built build/web`, exit 0 | `✓ Built build/web` |

The engine and the render layer are untouched by the diff (`git diff --stat` shows the app only), so I did not re-run them. Same as the implementer.

## Mutants (re-fired by me)

Each mutant: `cp` from backup, mutate with `mutate.py`, run `test/symbols/symbol_placer_test.dart` (54 tests), `cp` back, `diff -q` exit 0. Every run printed `[restored]`.

| Id | Mutation | Result | Red tests |
|---|---|---|---|
| M-09c-p scalar | payload compared with the entry's scalars (coords only) | `+52 -2` | L1 payload scalar (arc sweep); L1 text scalar (height) |
| M-09c-p style: color | `color: want.record.color` in the normalising copyWith | `+53 -1` | L1 the colour |
| … lineweight | same | `+53 -1` | L1 the lineweight |
| … transparency | same | `+53 -1` | L1 the transparency |
| … flags | same | `+53 -1` | L1 the flags |
| … linetypeScale | same | `+53 -1` | L1 the linetype scale |
| … linetype | same | `+53 -1` | L1 the linetype |
| … layer | same | `+53 -1` | L1 the layer |
| … kind | same | `+53 -1` | L1 the kind |
| … text | same | `+53 -1` | L1 the text |
| … tag | same | `+53 -1` | L1 the tag |
| … textStyle | same | `+53 -1` | L1 the text style |
| … textAttrs | same | `+53 -1` | L1 the text attributes |
| M-09c-p base point | `:199` deleted | `+53 -1` | L1 a moved base point |
| M-09c-bd child nodes | `:200` deleted | `+53 -1` | L1 a child node |
| M-09c-bd leaf count | `:208` deleted | `+52 -2` | L1 an extra leaf; L1 a missing last leaf |
| own: coords | payload compared with the entry's coords | `+53 -1` | L1 a leaf coordinate |
| own: no D10 | `&& isLeafEqual(...)` removed | `+34 -20` | all 20 L1 |
| **own: base x only** | `def.basePoint.x != base.x \|\|` removed at `:199` | **`+54` survives** | none |
| own: base y only | `\|\| def.basePoint.y != base.y` removed | `+53 -1` | L1 a moved base point |
| **own: no sort** | `..sort(...)` at `:206-207` removed (pair in slot order) | **`+54` survives** | none |
| **own: last match** | `break;` at `:117` removed (the last leaf-equal candidate wins) | **`+54` survives** | none |

Each of the 12 style mutants turns exactly its own L1 test red and nothing else. The leaf-count mutant turns "an extra leaf" and "a missing last leaf" red, as the implementer reported. The implementer's other counts also match mine (scalar 2 red, no-D10 `+34 -20`).

Probe (`review9/zz_review_probe_test.dart`; I placed it in the review worktree temporarily, ran it, and deleted it). All three probe tests pass on `a073fb5`. Under the surviving mutants:
- no sort: `probe: slot order differs from handle order, still reused`. `Expected: <1> Actual: <2>`.
- base x only: `probe: base point moved in x only is not reused`. `Expected: <2> Actual: <1>`.
- last match: `probe: two leaf-equal definitions, the lower handle is reused`. `Expected: <18> Actual: <26>`.

## Degenerate fixtures (P-2)

`styledSofa()` is not degenerate. Every leaf has a non-default style that differs from the other leaves (L5 asserts it). There is a text leaf and an attribute leaf with every text field set. The base point is (900, 400). The placements are at 30°, mirrored, at `(100000.25, -70000.75)`, with a quarterTurns 3 mirrored follow-up. The edits are the smallest that exact `==` can see (`+1e-9`, `+2^-20`). Two fixture gaps remain:
- The base-point edit moves y only (finding 1).
- The slot order equals handle order in every fixture, because every document is fresh with no holes in the free list (finding 2). That is the "default allocation state" form of a degenerate fixture.

## Hygiene

- Allocation invariant tests: not in the diff, so unedited.
- `analysis_options.yaml`: not committed. In the review worktree, `pub get` dirtied `packages/jet_cad/analysis_options.yaml`, which is expected and was left alone.
- Purity: `symbol_placer.dart` imports only `jet_cad_2d`, `vector_math`, `symbol_component.dart` and `symbol_library.dart`. `wall_attach.dart` and `symbol_box.dart` are not in the diff and import no Flutter or `dart:ui`.
- Commit message is as the plan specifies, with both trailers.

## Findings

1. **major: test gap, M-09c-p (base point) half survives.** `symbol_placer.dart:199`; test `symbol_placer_test.dart:1191-1203` ("a moved base point" adds `Vector2(0, 1e-9)`). Evidence: the mutant that drops the x comparison runs `+54: All tests passed!`. A regression that compared only y (or compared `basePoint.y` twice) would reuse a definition with a moved x base point. Fix: make the edit move x as well, or add a second L1 edit "a moved base point (x)" with `Vector2(1e-9, 0)` next to the y one. Re-fire both the x and y half-mutants.

2. **major: test gap, the ascending-handle pairing (D10 "pairwise, ascending handle on both sides") is unguarded.** `symbol_placer.dart:206-207`. Evidence: removing the `sort` survives (`+54`). The slot allocator's free list is LIFO (`slot_allocator.dart` `allocate`: `_free.removeLast()`), so in a real document the leaves of a definition do not sit in handle order. Example: free two slots in ascending order before the first placement. The sofa's line then lands in slot 1 and its polyline in slot 0. Without the sort, every later placement makes a new `#n` copy. My probe shows `definitions.length` is 2 instead of 1. Undo of a leaf removal and a restyle via Remove+Add hit the same case. Fix: add a test (e.g. "L6 a definition whose leaves sit out of handle order in the slots is reused"). Add two loose entities, remove them in ascending slot order, place twice, and expect one definition. Assert that the slot order really differs from handle order so the fixture cannot silently become degenerate.

3. **minor: the new doc comment's "the first such in ascending handle" is untested.** `symbol_placer.dart:82`, `:116-117`. Evidence: removing `break` (the last leaf-equal candidate wins) survives (`+54`). My probe kills it: edit the first copy, place (makes `#2`), restore the first with a fresh edit, place again, and expect the instance on the first. Fix: add that test, or drop the claim from the comment. Since this task added the claim, a test is preferred.

4. **note: R-C9-2.** Pairing the entry in list order relies on `SymbolEntry`'s documented ascending order, which its public constructor does not enforce (`symbol_library.dart:48-57`). An out-of-order entry built by hand (D7's size change in 09c-2 is a future caller) would make a copy on every placement. That is not wrong data, but it is a silent leak. Acceptable as ruled. 09c-2 should either sort the entry side too or `assert` the order.

5. **note for Task 11: stale comment confirmed.** `symbol_placer_test.dart:891-892`, group `the library entry is read-only to a placement`, says "a record has no `==`, a payload compares by identity". Both have had value `==` for some time (`entity_store.dart:178`, `geometry_store.dart:70`). The comment is pre-existing and not in this diff. Task 11 should correct it.

6. **note: R-C9-1 and R-C9-3 accepted.** R-C9-1 is the better design: a field added to `EntityRecord` later is compared automatically. Its one dependency is that `EntityRecord.==` stays complete, and today it covers every field.

## Re-review of 9b (5f4c235)

Reviewed `git diff a073fb5..5f4c235`. The only file changed is `apps/floor_planner/test/symbols/symbol_placer_test.dart` (+94/-13). The review worktree is detached at `5f4c235`. `lib/symbols/symbol_placer.dart` is byte-identical to `a073fb5`'s (`diff -q` against my backup shows no difference). Logs are in `review9/b/`.

### Verdict: Approved

The changes match what my findings asked for:
- **Finding 1.** The L1 edit "a moved base point" is split into "a base point moved in y" (`Vector2(0, 1e-9)`) and "a base point moved in x" (`Vector2(1e-9, 0)`), sharing a helper `movedBase`. Both run the full L1 body.
- **Finding 2.** New test L6. It asserts the loose lines sit at slots `[0, 1]`. It removes them in ascending slot order and places the sofa. It then asserts the premise: the leaf handles in slot order are not the handles in ascending order, the line is at slot 1 and the polyline at slot 0. It then checks `isLeafEqual` and that a second placement reuses the definition (one definition, no new live entity, both instances on it).
- **Finding 3.** New test L7. Two definitions with the key and version are both made leaf-equal; the test asserts both are, and asserts `first < second`. A third placement must land on `first`, with 2 definitions and no new live entity. The text is restored by a fresh command rather than an undo, which would remove `#2`.

### Gates (re-run by me at `5f4c235`, `CI=true`, in `apps/floor_planner`)

| Gate | Mine | Implementer |
|---|---|---|
| `flutter test` | `05:55 +1124: All tests passed!`, exit 0 | `+1124: All tests passed!` |
| `flutter analyze` | `No issues found! (ran in 2.3s)`, exit 0 | No issues found |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 | 180, 0 changed |

1124 = 1121 + the second base-point edit + L6 + L7. Neither of us re-ran the web build: no `lib/` file changed, and test files are not compiled into it. The engine and render packages are untouched.

### Mutants (re-fired by me)

`symbol_placer_test.dart`, 57 tests. Each mutant: `cp` backup, mutate, run, `cp` back, `diff -q` showed the file restored every time.

| Id | Mutation | Result | Red test, real output |
|---|---|---|---|
| base x dropped (my `base_x`) | `def.basePoint.x != base.x \|\|` removed at `:199` | `+56 -1` | L1 "a base point moved in x": `Expected: false / Actual: <true>` |
| base y dropped (my `base_y`) | `\|\| def.basePoint.y != base.y` removed at `:199` | `+56 -1` | L1 "a base point moved in y": `Expected: false / Actual: <true>` |
| no sort | `..sort(...)` at `:206-207` removed | `+56 -1` | L6: `Expected: true / Actual: <false>` |
| last match | `break;` at `:117` removed | `+56 -1` | L7: `Expected: <18> / Actual: <26>` |

All three survivors from the first review are now red, and the y half stays red.

### L6's premise is asserted (fixture mutants on the test file, production code unmutated)

Each fixture mutant: `cp` backup of the test file, edit, run `--plain-name "L6"`, `cp` back, `diff -q` showed the file restored.
- The loose lines removed in **descending** slot order (`loose.reversed`), so the leaves land in slot order. L6 goes red at `symbol_placer_test.dart:1343`: `Expected: not [21, 22, 23, 24, 25, 26] / Actual: [21, 22, 23, 24, 25, 26]`.
- The loose lines **never removed** (no holes in the slots). L6 goes red at `:1340` with the same message.

So L6 cannot silently become the degenerate in-order fixture: if the setup stops producing out-of-order slots, the test fails instead of passing vacuously.

### Remaining notes (no action in 9b)

- Note 4 (R-C9-2: the entry side relies on the documented order) is for 09c-2.
- Note 5 (the stale comment at `symbol_placer_test.dart`, group `the library entry is read-only to a placement`) is still for Task 11. Its line numbers are unchanged at `5f4c235`, since the 9b edits are all below it.
