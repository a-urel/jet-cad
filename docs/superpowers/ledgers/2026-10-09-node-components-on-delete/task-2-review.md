# Task 2 review: the floor plan, the expander's detach goes (D-7), TD10, P-1 to P-3

Base `d082640e`, head `391d9671`. Reviewed from the diff file; one focused probe run in a scratch worktree at `391d9671` (since removed).

### Spec Compliance

- ✅ Spec compliant, with one justified deviation from the brief's literal text (the `canon` comparison, below). Each brief step and spec point checked:
  - D-7, `_detachFor` and its branch removed: `table_label_system.dart:92-103`. The loop now does stamps only, and `stamps++` / `_stamped = stamps > 0` are kept. The `table_data_component.dart` import is gone too, so the analyzer has no unused import and no `unused_element`. A grep at head for `_detachFor`, "table-data expander" or "expander … detach" across `packages` and `apps` `*.dart` finds nothing.
  - The catch comment reads "the stamps written so far, then the edit itself" (`table_label_system.dart:105`). The "A detach alone…" comment is gone. The file header (`:1-5`) and `TableLabelEdit`'s doc (`:83-90`) say the delete takes the data (`RemoveNodeCommand`, node-components D-1).
  - `planner_shell.dart:929-931`: "the delete takes each table's data with it".
  - TD10 is rewritten as the spec (D-7, V-1) and the brief give it: two tables turned in one edit, `_RefusingTarget(doc, a.label!, labelPayload(...))`, and `throwsA(_Refused)`. It checks `refused` as its premise and asserts encoded equality (`table_data_test.dart:405-448`). The forwarding members are unchanged. A comes before B, so the brief's arguments stand.
  - Titles: the group title (`:355`, spec D-8's `:356`), TD7 "takes" (`:358`), TD9 (`:380-381`) and the file header (`:1-8`) are reworded. TD8's title (`:358` in the old numbering) never said "expander", so leaving it unchanged is right.
  - P-1, P-2 and P-3 exist in `test/delete_components_test.dart` with the brief's fixtures. Helpers are imported from `table_data_test.dart`, as the brief allowed.
  - The diff touches the four files the brief names and nothing else. The only existing tests edited are TD8's and TD9's titles, TD10 and `_RefusingTarget` (the global-constraint exceptions), plus TD7's title and the group title. The last two are covered by spec D-8's line list (`:356`).
- **Deviation: P-1 to P-3 compare `canon(doc)`, not `DraftDocumentCodec.encodeToString`** (`delete_components_test.dart:59/74, 93/101, 123/134`). I verified the implementer's reason myself. I ran P-2's scenario with both encoders at `391d9671`, and the output was:
  - `enc equal: false; canon equal: true; differing top-level keys: [entities]`
  - entity handle order before `[20, 21, 22]`, after undo `[21, 20, 22]`

  Only the entity slot order differs. That comes from `RemoveEntityCommand`'s undo of the wall's children, not from the node removal. `canon` (`test/support/wall_fixture.dart:287-293`) sorts only `entities` by handle and compares the rest of the encoding exactly, components and unknown payloads included. So nothing about components is weakened. The repo already uses `canon` for the same delete-then-undo comparison (`opening_object_test.dart:111-140`). I-2 is about a node removal and still holds. P-1 as the spec writes it ("undo restores the plan byte for byte") cannot hold literally for any delete that removes more than one entity.
- ⚠️ Cannot verify from the diff alone:
  - **The spec P-1 text and the results note.** Spec P-1 (`spec:472-476`) says "byte for byte". The note of record should say "byte for byte, entities in handle order (06 D11)", so the record does not claim an encoding equality the suite does not assert. The controller or Task 3 (docs) should carry this.
  - **M-12's killer list.** The spec's mutant table names P-2 as a killer of M-12 ("the cleanup list put back", `spec:494`). The plan names only PG1, and Task 1 killed it with PG1. Reading `regeneration.dart`'s removed cleanup, I expect M-12 to leave P-2 green. Under D-1 the removal has already detached `WallParams`/`ObjectLayer`, so a re-added `SetComponentCommand<WallParams>(w, null)` is a no-op with a null inverse, and the undo outcome is the same. I did not run it. The results note should not list P-2 for M-12 unless someone runs it. See Minor 1.

### Strengths

- The D-7 removal is clean and minimal. It also catches the newly unused import (`table_label_system.dart`, old `:62`), which the brief did not mention.
- The rewritten TD10 is a real all-or-nothing pin.
  - The refusal fires only after A's label payload has actually changed (`table_data_test.dart:486`), and the `refused` premise is asserted (`:443-444`). That proves a derived stamp was applied before the throw.
  - The refusal is one-shot (`!refused`), so the rollback's own geometry reads pass.
  - Both tables sit off the origin, one turned and one mirrored, and each is rotated about its own anchor.
  - The reported M-17 red line shows A's label rotation left stamped (`-2.2165…` vs `-1.5707…`), which is exactly the defect TD10 targets.
- `samePayload` compares stored values with exact `==` and does not use `Tolerance`, which matches the house rule.
- The `canon` deviation is reported openly, its reasoning holds up (probe above), and it reuses an existing helper rather than inventing a new normalization.
- The mutant runs go beyond the brief. M-1, M-2 and M-15 each list every red test, including P-1 to P-3. M-15 correctly leaves TD7 green, since B is last there.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **P-2's title claims more than it asserts** (`delete_components_test.dart:79-80`): "the undo replay restores them through the node's snapshot". The test checks only the outcome (`:96-101`): the components are gone, then come back, then `canon` matches. It never inspects the replay (DV1 and PG1 do inspect the replay's `AddNodeCommand`). A replay that restored `WallParams` through a separate `SetComponentCommand` would pass too. That is why P-2 probably does not kill M-12, despite the spec's table (see ⚠️). Either reword the title to the outcome, or assert that the top undo entry's `AddNodeCommand(w)` carries `WallParams` and `ObjectLayer` in `components`. The test text is brief-mandated.
2. **Plan-mandated fixture gaps in P-1 to P-3**:
   - None of the three has a surviving sibling with the same component types and other values, so I-4 (other handles untouched) is not exercised at the floor-plan level.
   - P-1's table carries one unknown payload, while the global constraint asks for two, attached out of type-id order (`delete_components_test.dart:49`).

   No named mutant survives because of this: M-6 is killed by N-1's sibling, unknown order by N-2 and N-5, and the table sibling by TD7. So this is recorded as Minor, not Important.
3. **TD9's title contradicts itself** (`table_data_test.dart:380-381`): "an edit that removes nothing keeps the data: … a delete of another table". A delete removes something. The old title had the same tension. Something like "an edit that does not remove the table keeps its data" would read true.
4. **The loop keeps a vestigial indirection** (`table_label_system.dart:93-99`): `final DraftCommand derived; if (... case final stamp?) {derived = stamp; stamps++;} else {continue;}` exists only for a second branch that is now gone. The brief explicitly allowed this form, so it is optional. A single `final stamp = _stampFor(target, h); if (stamp == null) continue;` would read more directly.

### Assessment

**Task quality:** Approved

**Reasoning:** D-7, TD10 and P-1 to P-3 land as specified. The one deviation (`canon` instead of the raw encoding) is forced by entity slot order, which I verified by a probe: it is the only difference. It weakens no component assertion, and the repo already uses it. The remaining items are title wording and plan-mandated fixture breadth, with no surviving mutant identified.
