# Final fix report (fix/node-components-on-delete, base a39a2906)

## Items
1. `packages/jet_cad_2d/test/parametric/dissolve_test.dart` DV1 title (about :145-149) now says the object is removed with its component, the replay restores it through the node's snapshot, the guard is untouched; comment at about :312 now reads "geometry, structure and components". (DV1 does assert `restoredBy<Fuse>`, so the snapshot wording is checked.)
2. `packages/jet_cad_floor_plan/test/delete_components_test.dart:79-80` P-2 title: "...the undo restores them; the plan as before". No assertion added.
3. `packages/jet_cad_floor_plan/test/tables/table_data_test.dart:394-395` TD9: "an edit that does not remove the table keeps its data: a turn, and a delete of another table".
4. `packages/jet_cad_2d/test/parametric/page_test.dart:216-218` PG1 comment reflowed.
5. `node_components_test.dart`: scene now adds `sibling` before `node`, so the children are [sibling, node, last]; N-2 premise is `indexOf(node) == 1` plus `hasLength(3)`; scene doc comment updated. No other assertion touched.
   Probe (inverse built with `index: 0` in `RemoveNodeCommand`, `commands.dart`, restored from cp, cmp clean):
   - `00:00 +1 -1: N-2 undo restores the snapshot and the index byte for byte; redo removes them again [E]`
   - `00:00 +7 -2: N-5 a compound delete whose second removal fails rolls the first back with its components [E]`
   - `00:00 +9 -2: Some tests failed.`
6. `packages/jet_cad_2d/lib/src/document/component.dart`: the stores are all `ComponentStore<Component>`, so they cannot answer a type test (and `set` does not throw; the failure would surface as a cast error in `get<T>`). `register<T>` now also records `_accepts[T] = (c) => c is T`; `checkRestorable` throws StateError for an entry whose value fails it, before any write. `restore` still calls `checkRestorable`; doc updated.
   N-4 new case "a type id this document maps to a different class" (class `Impostor` registered under `test.mark` in a second document, non-empty snapshot, add into the scene document throws StateError; tree, parent's children, components, encoding, undo depth unchanged).
   `node_components_test.dart` alone: `00:00 +11: All tests passed!`.
   M-18 (the `_accepts` test replaced by `if (false)`; restored from cp, cmp clean): `00:00 +4 -1: N-4 a refused add leaves everything as it was a type id this document maps to a different class [E]`; `00:00 +10 -1: Some tests failed.`; with `-n`: `Which: returned <null>` at `node_components_test.dart 291:7`, `+0 -1: Some tests failed.`
7-11. `docs/superpowers/notes/2026-10-10-node-components-results.md`: the "Left for the final review" section (with the "none changes behaviour; no named mutant survives" lead-in) replaced by "The final review, and what became of its findings", which says the cross-document snapshot is now fixed (was out of scope). M-3 row: N-2 (Task 1) and TD7, TD7b, TD7c (final review at a39a2906). Gates: final review's lines and mutant re-runs copied from final-review.md, plus this round's gates. M-18 and X-0 rows added with red lines. Tests list: N-4 five cases, N-2 middle child. What-changed bullet for `component.dart` extended.
   Judgement call: Task 1's report table lists N-5 and N-6 as M-3 killers but pastes only N-2's line; per item 8 the row names N-2 only, and the note says so.

## Commands (pasted summary lines)
- `packages/jet_cad_2d`: `dart test` -> `00:06 +1281 -2: Some tests failed.` (only the two standing generate_document_test fingerprints); `dart analyze --fatal-infos` -> `No issues found!`; format -> `Formatted 172 files (0 changed) in 0.41 seconds.`
- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice test/delete_components_test.dart test/tables/table_data_test.dart` -> `00:00 +15: All tests passed!`; full suite (extra) `01:56 +1915: All tests passed!`; `flutter analyze` -> `No issues found! (ran in 3.4s)`; format -> `Formatted 281 files (0 changed) in 0.96 seconds.`
- `packages/jet_cad_2d_flutter`: `flutter test` -> `00:23 +1432 ~1 -5: Some tests failed.` (five text ladder rungs 1-5, standing); analyze `No issues found! (ran in 3.2s)`; format `Formatted 228 files (0 changed) in 0.46 seconds.`
- `packages/jet_cad_2d_gpu`: `00:00 +20: All tests passed!`; analyze `No issues found! (ran in 2.5s)`; format `Formatted 10 files (0 changed) in 0.01 seconds.`
- `apps/floor_planner`: `00:33 +212: All tests passed!`; analyze `No issues found! (ran in 3.7s)`; format `Formatted 47 files (0 changed) in 0.12 seconds.`
- `apps/restaurant_demo`: `00:17 +68: All tests passed!`; analyze `No issues found! (ran in 3.0s)`; format `Formatted 9 files (0 changed) in 0.06 seconds.`

Nothing else red. `git status --short` before commit: component.dart, node_components_test.dart, dissolve_test.dart, page_test.dart, delete_components_test.dart, table_data_test.dart (plus the results note, edited afterwards). No analysis_options.yaml touched.
