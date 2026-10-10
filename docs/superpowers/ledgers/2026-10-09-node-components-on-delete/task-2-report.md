# Task 2 report: the floor plan, the table-data expander goes (D-7), TD10, P-1 to P-3

Status: DONE_WITH_CONCERNS (one deviation, below). Commit `391d9671` on `fix/node-components-on-delete`.

## What was implemented

- `lib/src/tables/table_label_system.dart`: `_detachFor` and its branch deleted; the loop is stamp-only; the catch's comment reads "the stamps written so far, then the edit itself"; the "A detach alone..." comment is gone (`_stamped = stamps > 0` kept); file header and `TableLabelEdit`'s doc say the delete itself takes a table's data (`RemoveNodeCommand`, node-components D-1). The now-unused `table_data_component.dart` import was removed.
- `lib/src/planner_shell.dart`: doc of `_deleteByHost` says "the delete takes each table's data with it".
- `test/tables/table_data_test.dart`: file header, group title ("a deleted table takes its data"), TD7 title ("takes" for "detaches"), TD9 title, TD10 and `_RefusingTarget` rewritten per the brief (`labelPayload`, `samePayload` added; the forwarding members kept verbatim). TD8's title needed no change (no expander wording).
- `test/delete_components_test.dart` created: P-1, P-2, P-3.

Files: `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/confident-ardinghelli-29b386/packages/jet_cad_floor_plan/` `lib/src/planner_shell.dart`, `lib/src/tables/table_label_system.dart`, `test/tables/table_data_test.dart`, `test/delete_components_test.dart` (new). No `analysis_options.yaml` in the commit (checked `git status --short`).

## Deviations from the brief

1. **P-1 to P-3 compare with `canon(doc)` (from `support/wall_fixture.dart`), not `DraftDocumentCodec.encodeToString`.** With `enc` all three failed on undo, at the entity order only (e.g. `"handle":20` expected, `"handle":21` actual): `RemoveEntityCommand` undo restores entities into other slots, and the encoder writes slot order. The repo already treats this as history, not state (`canon`'s doc: "Entities sorted by handle: slot order is history, not state (06 D11)"; `opening_object_test` uses it for the same delete/undo). `canon` still compares everything else, components included, so no assertion was weakened as to components; the byte-for-byte claim is "byte for byte with entities in handle order". The fixtures, and every other assertion, are as given. The local `enc` helper was dropped (wall_fixture has one); the two `reason: '${h.toHex()}'` became `reason: h.toHex()` (analyzer `unnecessary_string_interpolations`).
2. Importing `table_data_test.dart`'s helpers worked (analyzer and runner fine); the `table_fixture.dart` move was not needed.

## TD10

Stamp order found: **A before B** (the touched order is the compound's), so the brief's arguments stand, no swap. Proof: `_RefusingTarget` refuses only after A's label payload differs from its unstamped value, and the test passes with `target.refused` true, which can only happen if A's stamp wrote first and B's read then hit the refusal.

Green on the code:
```
00:00 +11: a deleted table takes its data (E-9 gate 3) TD10 all or nothing: a stamp that throws after another stamp puts that one back with the edit
00:00 +12: All tests passed!
```

## Gates (all run, this machine)

- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice`: `01:45 +1915: All tests passed!` (1912 + P-1..P-3). `flutter analyze`: `No issues found! (ran in 3.1s)`. `dart format --output=none --set-exit-if-changed .`: `Formatted 281 files (0 changed)`.
- `apps/floor_planner`: `00:33 +212: All tests passed!`; analyze `No issues found!`; format `Formatted 47 files (0 changed)`.
- `apps/restaurant_demo`: `00:19 +68: All tests passed!`; analyze `No issues found!`; format `Formatted 9 files (0 changed)`.
- Step 2 (P-1..P-3 with the expander still installed): `00:00 +3: All tests passed!` (after the `canon` change).
- jet_cad_2d / _flutter / _gpu were not touched in this task (only `jet_cad_floor_plan` files changed; Task 1's commands.dart was mutated and restored byte for byte, `cmp` clean, `git status` clean for it).

## Mutants (each applied alone, run, red line captured, restored from a `cp` copy, `cmp` confirmed)

- **M-17** (`table_label_system.dart`, delete the `for (final inverse in inverses.reversed) inverse.apply(target);` loop in the catch, keep `r.inverse.apply(target)`). Killing test: TD10. Red:
  `00:00 +0 -1: a deleted table takes its data (E-9 gate 3) TD10 all or nothing: a stamp that throws after another stamp puts that one back with the edit [E]` ... `Expected: ... ":[200.0,-1.57079632 ...` / `Actual: ... ":[200.0,-2.21656815 ...` / `both tables unturned, A's label as it was` (A's label left stamped).
- **M-1** (`jet_cad_2d/lib/src/document/commands.dart`, drop `target.components.detachAll(handle);` in `RemoveNodeCommand`). Red: TD7 (`+6 -1: ... TD7 M-H27: a Delete takes the data in the same step...`), also TD7b, TD7c, TD8, P-1, P-2, P-3 and **HD12** (`test/host/table_data_test.dart`: `+19 -8: ... HD12 M-H27 (E-9 gate 3): the editor's Delete of table 1 drops its data...`). Final line `Some tests failed.` (8 red).
- **M-2** (inverse built without `components:`: `AddNodeCommand(node, index: index)`). Red: TD7, TD7b, TD7c, TD8, P-1, P-2, P-3, HD12 (`+19 -8 ... HD12 ...`).
- **M-15** (inverse built without `index:`: `AddNodeCommand(node, components: components)`). Red: **TD7b** (`+7 -1: ... TD7b the first table deleted and undone...`), TD7c, P-1, P-3, HD12 (`+22 -5`). TD7 (B last) correctly stays green.

So the brief's expectations hold: TD7 + HD12 for M-1, TD7 + P-1 for M-2, TD7b for M-15, now with the expander's detach gone (M-1 and M-2 are no longer masked by the expander).

## Self-review

- Diff is exactly the four files; no `_detachFor` remnants (`flutter analyze` clean, no `unused_element`, no unused import).
- Behaviour check: `TableLabelEdit.capabilities` is still `inner.capabilities`, now `{structure, components}` for a delete (from Task 1); nothing else in the class changed. The `inverses.isEmpty` fast path now means "no stamps".
- TD7c's comment about node_index_undo_test and TD7b untouched.

## Concerns

- The `canon` deviation above: if the reviewer wants literal `encodeToString` byte equality in P-1..P-3, the entity slot order after undo would have to be made stable by the engine, which is outside this task (and 06 D11 says it is not state).
- Floor plan's two "TD8 / TD9 titles" instruction: TD8's title contained no expander wording so it is unchanged; TD9's was reworded, since "adds no detach" described removed behaviour.
