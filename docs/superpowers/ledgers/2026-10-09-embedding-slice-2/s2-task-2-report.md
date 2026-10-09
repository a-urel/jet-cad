# Slice 2, Task 2 report — host data on a table (E-6, E-7, E-9 gates 2 and 3)

Commit `2193fca` on `claude/exciting-pasteur-9m22jv` (parent `14e6c7f`, Task 1), pushed.
Flutter `/root/sdk/flutter/bin`, `CI=true`.
No `analysis_options.yaml` changed or staged. The engine (`jet_cad_2d`) and `jet_cad_2d_flutter` are not edited.
No existing test was edited; `barrel_test` needed no change (no new barrel name).

## What was built (all in `packages/jet_cad_floor_plan`)

- `lib/src/tables/table_data_component.dart` (new, 176 lines)
  - `tableDataProblem(Map<String, String>)` (:35): the one limits check the constructor and the controller share:
    at most 32 keys; a key `^[a-z0-9_.-]{1,64}$`; a value at most 1024 UTF-16 units, no code unit below U+0020
    or in U+007F..U+009F (the table numbers' rule). An empty map and an empty value are within the limits (S-6).
  - `final class FloorPlanTableData implements Component` (:68), `componentTypeId = 'jetcad.table_data'`, `register`.
    - Factory constructor: `ArgumentError` for an empty map or one outside the limits; keys stored sorted, unmodifiable.
    - `fromJson` (:118) never throws: exactly `{"data": {string: string}}`, non-empty, within the limits → the data
      (re-sorted; a hand-edited unsorted file is canonicalised). Anything else (over a limit, a non-string value,
      `data` missing / not a map / empty, an extra key) → `kept`: a deep unmodifiable copy of the payload, key order kept,
      written back by `toJson` as read; `data` empty; `isKept` true.
    - Value `==`/`hashCode`: data by entries; a kept payload by its JSON encoding.
- `lib/src/parametric/catalog.dart`: `registerAppComponents` registers it after `SeatingComponent` (:58), doc updated.
- `lib/src/tables/table_index.dart`: `TableDiagnosticCodes.invalidData = 'table.invalid_data'` (:196, warning),
  raised per **table** whose payload is kept. The survey records the kept tables when it is taken (a `Set<Handle>`),
  so `diagnostics()` reads the survey's state, not the registry's later one.
- `lib/src/tables/table_label_system.dart`: the delete expander in `TableLabelEdit.apply`.
  - Per touched handle (in `touched` order): `_detachFor` (:134) — a handle naming no live node, definition or entity
    that still carries `FloorPlanTableData` gets `SetComponentCommand<FloorPlanTableData>(h, null)`; otherwise the
    existing stamp. Both go into the same `inverses` list, so the existing rollback on a throw and the replay
    (undo/redo) cover the detach.
  - `_stamped` (the capability raise to `geometry`) counts stamps only: a detach writes no label.
  - The cheap path (no servable definition → unwrapped) is unchanged.
- `lib/src/host/table_detail.dart`: `tableDetailOf` and `tableDetailWithoutGeometry` take an optional
  `data` (default `const {}`); `FloorPlanTableDetail.data`'s doc comment updated (no signature change).
- `lib/src/host/floor_plan_controller.dart`
  - `_detailsOf` fills `data` from the instance's component (`?.data ?? const {}`: unmodifiable; empty when absent
    or kept), for hidden, locked and non-candidate tables too; `_detailOf` passes it on.
  - `bool setTableData(String number, Map<String, String> data)` (:1197) = `setTablesData({number: data})`.
  - `bool setTablesData(Map<String, Map<String, String>> byNumber)` (:1207): `StateError` in the selection mode;
    then every map checked (`ArgumentError`, nothing changed); then `_settle`; then per entry: two keys trimming to one
    number → false; a trimmed number naming no table or more than one → false; an entry equal to the current
    component (null for an empty map) skipped. Nothing left → true, no step. Else one
    `CompoundCommand(..., label: 'Table data')` executed on the design and `_refreshFlags()` so `dirty`/`canUndo`
    read it on return. An empty map removes the component, a kept payload included.

## Tests added

`test/tables/table_data_test.dart` (component, limits, lenient read, diagnostic, expander):
- TD1 accepted at the boundaries: 32 keys, a 64-character key, a 1024-unit value, an empty value, non-ASCII text
- TD2 refused one past each boundary: 33 keys, a 65-character key, a 1025-unit value, each control character range, a bad key
- TD3 M-H24: keys inserted as zeta, id, alpha are written sorted; the data is unmodifiable and value-equal
- TD4 M-H28: fromJson never throws; a payload of another shape or outside the limits is kept verbatim and reads as empty data
- TD5 a valid but unsorted stored payload is the data, re-sorted on write (S-6)
- TD6 registerAppComponents registers it: a plan decodes it typed, and one outside the limits decodes too, with a diagnostic
- TD7 M-H27: a Delete detaches the data in the same step; undo puts it back byte for byte, redo drops it again; the other table keeps its
- TD7b the first table deleted and undone: its data back, the plan equal but for the root's children order (the engine appends a re-added node)
- TD8 a nested instance of a deleted group loses its data too; a kept payload is dropped and restored as read
- TD9 an edit that removes nothing keeps the data: a turn, and a delete of a table carrying none adds no detach
- TD10 all or nothing: a stamp that throws after the detach puts the data back with the edit (a `CommandTarget`
  wrapper refuses `geometry` once the deleted table's data is gone, so the throw provably lands after the detach)

`test/host/table_data_test.dart` (controller, on `embeddingPlanJson`):
- HD1 E-9 gate 2: data on 1 (30°), 2 (mirrored) and L (locked) round-trips through designJson and load byte for byte, and tableDetails reads it back on the same tables
- HD2 M-H24: data inserted as zeta, id, alpha is written with its keys sorted, under the table's instance (exact text `"jetcad.table_data":{"<h>":{"data":{"alpha":"","id":"7f3c-ä","zeta":"Masa 4.ğ"}}}`)
- HD3 M-H22: a number two tables carry is refused, whichever way it is written; so are an unknown and an empty number
- HD4 M-H23: in the selection mode both throw a StateError; the design and the copy are untouched (the copy carries data read only)
- HD5 M-H24b: an empty map removes the data: no jetcad.table_data section at all
- HD6 M-H28: a plan whose data is outside the limits loads; each such table reads empty data, is reported table.invalid_data, and is written back byte for byte; a later setTableData replaces it (1: 33 keys, 2: `Bad Key`, 3: 1025 units, 4: a number value, L: `data` a list; a valid payload on hidden 5 beside them; the service copy; undo restores the kept payloads)
- HD7 M-H29(setTablesData): one bad entry changes nothing: an ambiguous number, an unknown one, two keys trimming to one number are false; a map outside the limits throws first
- HD8 setTablesData is one undo step labelled "Table data"; entries already equal are skipped; nothing to change is no step; hidden and locked tables take data
- HD9 the limits through the controller: the boundaries accepted, one past each refused with an ArgumentError, nothing changed
- HD10 renumbering 1 to 21 keeps its data: it is the instance's
- HD11 undo and redo of setTableData; dirty and canUndo on return, revision after the change; dirty again after markSaved
- HD12 M-H27 (E-9 gate 3): the editor's Delete of table 1 drops its data in the same step; Undo puts it back, the plan as it was but for the root's children order (FloorPlanView mounted, `select({'1'})`, the Delete key, then Ctrl+Z)

Fixtures: keys out of order (`zeta`, `id`, `alpha`), a value with a space, a dot and non-ASCII (`Masa 4.ğ`, `7f3c-ä`),
an empty value, a 64-character key, a 1024-unit value (1000 × `ş` + 24 × `x`), the rotated/mirrored/scaled tables
40 m off the origin, hidden `5`, locked `L`, the two `7`s.

## Mutants (each applied by script, run against both test files, reverted; `git status` clean of them after)

| Mutant | Change | Red killers |
|---|---|---|
| M-H22 | `found.isEmpty` / `found.first` (writes the first of a duplicated number) | HD3, HD7 |
| M-H23 | the selection-mode `StateError` removed | HD4 ("Expected: throws StateError") |
| M-H24 | `_sorted` keeps insertion order | TD3, TD5, HD1, HD2 |
| M-H24b | the empty-map refusal removed and the controller always builds a component | HD5 (also HD6, TD2) |
| M-H27 | `_detachFor` returns null | TD7, TD7b, TD8, TD10, HD12 |
| M-H28 | `_keep` throws `FormatException` (an over-limit payload refuses the plan) | TD4, TD6, TD8, HD6 |
| M-H29(setTablesData) a | an unresolved/ambiguous entry skipped (`continue`) instead of `return false` | HD7 (also HD3, HD10) |
| M-H29(setTablesData) b | no up-front check; each entry executed as it resolves, a bad map throws mid-batch | HD7 (also HD8, HD11) |

## Gates (this tree, real runs)

- `packages/jet_cad_floor_plan`: `flutter test` +1541 All tests passed; `flutter analyze` No issues found; format 0 changed.
- `apps/restaurant_demo`: +47 All tests passed; analyze clean; format 0 changed.
- `apps/floor_planner`: +212 All tests passed; analyze clean; format 0 changed.
- `packages/jet_cad_restaurant_symbols`: +97 All tests passed; analyze clean; format 0 changed.
- `packages/jet_cad_2d` (not edited): `dart test --file-reporter json`, then `expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d`:
  "1258 tests; the standing failures and skips, exactly".
- `packages/jet_cad_2d_flutter` (not edited): same comparison: "1374 tests; the standing failures and skips, exactly".

## Findings and deviations

1. **An undone delete is not byte-for-byte when the table is not its parent's last child** (plan's M-H27 killer says
   "Undo → `designJson()` byte-equal to before the delete"). `DocumentTree._link` (engine `tree.dart:557-570`) appends,
   so `AddNodeCommand` (the delete's inverse) puts the restored node at the **end** of the root's `children`; the
   encoding writes `children` in stored order. Pre-existing engine behaviour, independent of table data (draw order is
   by handle, so nothing is drawn differently). The engine is out of bounds for Task 2, so:
   HD12 (table `1`, as the plan says) asserts the data back, the `jetcad.table_data` section byte-equal, the restored
   handle last in the root's children, and the encoding equal once every group's children are sorted; TD7 deletes the
   root's last table and asserts strict byte equality after undo (and after redo + undo). Recommend recording it with
   O-8 (or its own engine task: `AddNodeCommand` restoring the child's index).
2. **Selecting fixture table `9` (no finite corner) in the design view throws a NaN-offset assertion** in
   `SelectionOverlayPainter._paintGrips` (`jet_cad_2d_flutter/src/selection_overlay.dart:290`), seen while trying a
   byte-exact Delete of `9` (the root's last child) through the view. Pre-existing, debug-only, a degenerate fixture
   table; that test was dropped (TD7 covers byte-exactness). Not fixed here (render package out of bounds).
3. Readings pinned by tests, within S-6 and the plan: `{"data":{}}` on read is kept (and reported), since an empty
   map is no component; `setTableData(n, {})` on a kept payload removes it (it is not "equal to the current");
   the mode check comes before the limits check (selection mode + bad data → `StateError`).
4. `controller.undo()`/`redo()` refresh `dirty` only through the async change stream (existing behaviour), so HD11
   pumps before reading `dirty` after them; `setTableData` itself refreshes on return as the plan requires.

## Fixes

Commit `890656d` (parent `69d56fc`, Task 3), pushed. Flutter `/root/sdk/flutter/bin`, `CI=true`.
No `analysis_options.yaml` changed or staged. The engine and `jet_cad_2d_flutter` are not edited.

### Changes

- **R-1 (accepted):** the 1024-unit limit is pinned against a character count. Two new fixtures are
  `astral1024 = '\u{1F37D}' * 512` (1024 units, 512 runes) and `astral1025 = 'x' * 1023 + '\u{1F37D}'`
  (1025 units, 1024 runes). Each test file asserts both counts.
  - TD1: `astral1024` accepted (`tableDataProblem` null; the constructor keeps it).
  - TD2: `astral1025` refused (a problem; `ArgumentError`).
  - TD4: `{"data":{"a":astral1025}}` kept verbatim by `fromJson`, read empty, written back as read.
  - HD9: through the controller, `astral1025` throws `ArgumentError` with nothing changed. `astral1024` is
    accepted and read back. A plan carrying `astral1025` on `4` loads, is written back byte for byte, reads
    empty data and is reported `table.invalid_data` on `4` alone.
- **R-2 (accepted, extracted):** `bool isControlCodeUnit(int u)` lives in `tables/table_numbers.dart`. It is
  below U+0020, or U+007F to U+009F. `tableNumberProblem` and `tableDataProblem` both use it, with no
  behaviour change. `table_numbers_test.dart` passes unedited (it is in the full run).
  - New pin: TD1 asserts `{'a': 'a~b'}` (U+007E) accepted.
  - Ends of each range already pinned: U+001F, U+007F and U+009F are refused in TD2; U+0020 and U+00A0 are
    accepted in TD1 (`' ¡ é'`).
  - Editor API: `editor.dart` exports `table_numbers.dart` whole, so `isControlCodeUnit` is a new name
    there. It is additive. The host barrel is unchanged (B1 green).
- **R-3 (accepted):** the plan's M-H27 killer, in `docs/superpowers/plans/2026-10-09-embedding-slice-2.md`,
  is amended to what HD12 and TD7 pin, with the reason (the engine re-appends an undeleted node,
  `tree.dart:557-570`, pre-existing). No code change.
  - The sentence names the follow-up "beside the spec's O-8". The spec's own O-list is not edited here,
    because it is outside Task 2's files. The controller adds that entry.
- **R-4, R-5:** recorded, no change. **R-6:** nothing now. Task 5's guide will say "kept as read (re-encoded)".

### Mutants

Each was applied by script against `table_data_test`, `host/table_data_test` and `table_numbers_test`, then
reverted by copying the saved file back. `cmp` confirmed the restore.

| Mutant | Change | Red killers |
|---|---|---|
| O6 | `value.runes.length > kTableDataMaxValueLength` | TD2, TD4, HD9 (was: survived) |
| O8b | `isControlCodeUnit`: `u >= 0x7E` | TD1 (was: survived) |
| O7 | upper `< 0x9F` (on the shared predicate) | TD2, TN8 |
| O8 | lower `0x80` | TD2, TN8 |
| O8c | upper `<= 0xA0` | TD1, TN7 |
| O9 | C0 `< 0x1F` | TD2 |
| O9b | C0 `<= 0x20` | 19 tests (TD1…TD10, HD1…HD12, TN7) |

Baseline (all three files): +31, all passed.

### Gates (this tree at `890656d`'s content, real runs)

| Package | test | analyze | format |
|---|---|---|---|
| `packages/jet_cad_floor_plan` | `07:53 +1556: All tests passed!` | No issues found | 255 files, 0 changed |
| `apps/restaurant_demo` | `00:48 +47: All tests passed!` | No issues found | 5 files, 0 changed |
| `apps/floor_planner` | `03:03 +212: All tests passed!` | No issues found | 47 files, 0 changed |
| `packages/jet_cad_restaurant_symbols` | `00:04 +97: All tests passed!` | No issues found | 15 files, 0 changed |
| `packages/jet_cad_2d` | `+1256 -2` → "packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly" (exit 0) | n/a | n/a |
| `packages/jet_cad_2d_flutter` | `+1366 ~1 -7` → "packages/jet_cad_2d_flutter: 1374 tests; the standing failures and skips, exactly" (exit 0) | n/a | n/a |

The planner count includes Task 3's tests: HEAD was `69d56fc`.
