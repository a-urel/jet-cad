# Final fix re-review: a39a2906..f1a99890

Reviewer: fresh. I read the fix diff (`review-a39a2906..f1a99890.diff`), `final-fix-report.md`, `final-review.md`, and the touched files at the head. I made one run in a scratch worktree at `f1a99890` (one `flutter pub get`), which I removed afterwards:

- `node_components_test.dart` at the head: `00:00 +11: All tests passed!`
- M-18 applied alone (`if (!_accepts[type]!(component)) {` replaced by `if (false) {`), then restored from a `cp` copy. `git status --short` was empty afterwards. Result:
  - `00:00 +4 -1: N-4 a refused add leaves everything as it was a type id this document maps to a different class [E]`
  - `Which: returned <null>`
  - `00:00 +10 -1: Some tests failed.`

I did not run X-0 (one mutant only). My verdict on item 5 rests on reasoning, set out below.

### Finding Verdicts

- **Item 1: ADDRESSED.** `packages/jet_cad_2d/test/parametric/dissolve_test.dart:147-150` and `:313`.
  - The title no longer names a detach or a cleanup.
  - The new phrase "through the node's snapshot" is checked by the test: `restoredBy<Fuse>` (`:110`) reads the `AddNodeCommand`'s snapshot at `:233` and `:308`, and `fuseSets` is empty.
  - The comment now reads "geometry, structure and components".
- **Item 2: ADDRESSED.** `packages/jet_cad_floor_plan/test/delete_components_test.dart:79-80` now says "...the undo restores them; the plan as before". It names the outcome only.
- **Item 3: ADDRESSED.** `packages/jet_cad_floor_plan/test/tables/table_data_test.dart:394-395`, worded as the final review proposed.
- **Item 4: ADDRESSED.** `packages/jet_cad_2d/test/parametric/page_test.dart:216-217` is reflowed.
- **Item 5: ADDRESSED.** `packages/jet_cad_2d/test/document/node_components_test.dart:83-104` and `:168-169`.
  - `scene()` now lists the children as [sibling, node, last]. The premises are `indexOf(node) == 1` and `hasLength(3)`.
  - An inverse that re-inserts at 0 yields [node, sibling, last]. That fails `expect(childrenOf(...), order)` in N-2, deterministically.
  - The fix report's red lines for N-2 and N-5 agree with this.
  - See New Issue 1: the fixture lost a property it used to have.
- **Item 6: ADDRESSED.** `packages/jet_cad_2d/lib/src/document/component.dart:104`, `:116`, `:191-204` and `:220`, with the new N-4 case at `node_components_test.dart:269-304`. The named risk checked out:
  - **Registration paths.** `_stores` is written only in `register` (`:115`), on the line next to `_accepts` (`:116`). So `_stores[type] != null` implies `_accepts[type] != null`, and the `!` at `:198` cannot fail.
    - Registering one type twice, under either id, keeps one `is T` closure.
    - A type id that maps to nothing is refused first, at `:194`, as before.
    - Unknown payloads are not in `snapshot.components`, so the check never touches them.
  - **`restore` still calls the check.** It calls `checkRestorable` first (`:220`).
  - **`AddNodeCommand`** (`commands.dart:423`) calls it before `addNode`, so the new refusal also comes before any write.
  - **Cost.** `get`, `attach`, `detach`, `snapshotOf` and `detachAll` are unchanged. The closure is allocated once per `register`, and the map lookup runs only at command rate (add, restore). The frame path is not touched.
  - **What the N-4 case proves.** Its premise pins that the snapshot carries `Mark.id` alone. Mark is registered in the scene document, so only the new class test can refuse it. The case then asserts the `StateError`, no components on `h`, the parent's `children`, the encoding and `undoDepth`. My M-18 run turns it red with `returned <null>`, which means the add went through.
- **Item 7: ADDRESSED.** `docs/superpowers/notes/2026-10-10-node-components-results.md:366-370`.
  - The section that carried the old lead-in, "none changes behaviour; no named mutant survives", is gone.
  - The new text reads "Nothing below changes behaviour the tests pin, apart from the cross-document snapshot".
- **Item 8: ADDRESSED.** Results note, `:167`, and the bullet after it.
  - The M-3 row now reads "N-2 (Task 1's run); TD7, TD7b, TD7c (the final review's run at `a39a2906`)". Its red lines match `task-1-report.md:36` and `final-review.md`'s `00:00 +0 -3: Some tests failed.`
  - Dropping N-5 and N-6 is explained in the note: Task 1 pasted no line for them.
- **Item 9: ADDRESSED.** Results note, `:261-298`. Every gate line and mutant re-run in the "Final review" block matches `final-review.md` character for character. I checked:
  - all seven packages' test, analyze and format lines, timings included;
  - M-17, M-3, M-12 (PG1 and P-1 to P-3), M-5, M-14 and X-0 (`+17 -7`).
- **Item 10: ADDRESSED.** Results note, `:182-183`, plus the "Final fix round" block at `:307-327`.
  - The M-18 and X-0 rows match `final-fix-report.md`'s lines.
  - The note's `291:7` is the `expect(` at `node_components_test.dart:291`.
  - The `+11` line matches the report, and so do the gate lines for the six packages the fix round ran.
  - My own M-18 run reproduces M-18's lines.
- **Item 11: ADDRESSED.** Results note, `:378-383`.
  - The case is listed as "Fixed ... (was out of scope)".
  - There is no O-8 line for it, and the O-1 to O-7 list is unchanged.
  - See New Issue 2 on how the note describes the old failure.

### New Issues in the Fix Diff

1. **Minor. `node_components_test.dart:83-91`: the fixture's children are now in ascending handle order.**
   - The handles are allocated parent, sibling, node, last (`:88-91`). The children are now [sibling, node, last], so they sit in handle order.
   - The old doc comment named the opposite as a deliberate property: "(not ascending: [sibling] < [node])". The fix dropped it.
   - So an inverse or `addNode` that re-inserts by handle value instead of by index would leave N-2 green. I reasoned this and did not run it. `node_index_undo_test` may still catch it.
   - Fix: swap the two `handleSeed.next()` lines for `sibling` and `node` (`:89-90`). That keeps node in the middle and the order non-ascending. Then restore the "not ascending" note in the doc comment.
2. **Minor. Results note `:378-381` describes the old failure wrongly.**
   - It says the cross-document snapshot "used to pass `checkRestorable` and then fail after `addNode` wrote, breaking I-3".
   - The stores are `ComponentStore<Component>`, so `set` did not throw. The add succeeded and stored a value of the foreign class in this document's `Mark` store, and a later `get<Mark>` would fail its cast.
   - The note's own M-18 row (`:182`, "the add did not throw"), the fix report's item 6, and my M-18 run (`returned <null>`) all show this.
   - The text repeats `final-review.md` Minor 7's `TypeError` premise, which the fix round found to be wrong.
   - Fix: reword, for example: "used to pass `checkRestorable` and be written: a value of the foreign class stored under this document's type, which a later `get<T>` fails to cast."
3. **Minor. Results note `:307-308` claims more than was run.**
   - It says "the engine's `component.dart` changed, so every consumer was re-run".
   - The fix round's list, and `final-fix-report.md`'s Commands, have no `packages/jet_cad_restaurant_symbols`, which depends on `jet_cad_2d` by path.
   - Fix: run it and paste its line, or narrow the claim to the packages listed.
4. **Minor (doc nit). `component.dart:197-198`: "Only a snapshot from another document can fail either" is not strictly true.**
   - Suppose two classes are registered under one type id in one registry. `snapshotOf` then emits the earlier class's value under that id, `_typeOf` maps the id to the later class, and a same-document undo is now refused.
   - Production registers one class per id (I grepped the `register<` calls), and a refusal beats the old silent mis-store.
   - An optional "(or a registry that binds one type id to two classes)" would make the comment exact.

### Out-of-Scope Observations

- The spec's I-3 (`docs/superpowers/specs/2026-10-09-node-components-on-delete-design.md:404-406`) still lists four refusals: "duplicate, cycle, index out of range, unmapped type". It does not name the new class check. The spec is the binding authority, so the controller may want a revision note, or a line in the results note saying the fix goes beyond it.
- `_Registration.detach` is still dead, and the fixture-breadth and `TableLabelEdit` leftovers remain. All of them are recorded under "Left", as the final review triaged them.

### Verdict: All findings addressed

All 11 items are addressed. The fix diff adds four Minor issues: a weaker fixture order and three wording or provenance points. None is Critical or Important, and none blocks.
