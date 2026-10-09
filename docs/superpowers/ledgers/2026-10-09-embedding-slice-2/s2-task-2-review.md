# Slice 2, Task 2 review — host data on a table

Commit under review: `2193fca` (parent `14e6c7f`) on `claude/exciting-pasteur-9m22jv`.
Reviewer's clones: `/home/user/review-s2t2` (gates), `/home/user/review-s2t2-mut`
(mutants), `/home/user/review-s2t2-probe` (probe tests, not for commit). Nothing
was edited, committed or pushed in `/home/user/jet-cad` but this file.
Flutter `/root/sdk/flutter/bin` (3.47.6), `CI=true`.

## Verdict: **Approve with fixes**

The diff does Task 2 and nothing else, P-1 holds, every gate is green with
the standing sets exact, every named mutant is red, and 33 of my 36 own
and variant mutants are red. The fixes are two test gaps (R-1, R-2): two
mutants survived (the length counted in characters rather than UTF-16
units, and U+007E counted as a control character). Each needs a
fixture of a few lines, and I show below that such a fixture kills it. Neither is a
defect in the code as committed. The implementer's two findings stand
(R-3, R-4); I rule on both below.

## 1. Scope and P-1

`git diff --stat 14e6c7f 2193fca`: 8 files, all in `packages/jet_cad_floor_plan`.
- `lib/`: `host/floor_plan_controller.dart`, `host/table_detail.dart`,
  `parametric/catalog.dart`, `tables/table_index.dart`,
  `tables/table_label_system.dart`, new `tables/table_data_component.dart`.
- `test/`: two new files only (`--diff-filter=M` lists no test file), so no
  existing test was edited.
- The engine and `jet_cad_2d_flutter` are untouched. `lib/jet_cad_floor_plan.dart` (the host barrel)
  and `lib/editor.dart` are unchanged. `FloorPlanTableData`, `tableDataProblem`
  and the `kTableDataMax*` constants are not exported. `table_label_system.dart`
  (exported by `editor.dart`) imports the component but does not re-export it.
  No handle or component type crosses the barrel (invariant 5).
- `FloorPlanTableDetail`'s constructor, `==`, `hashCode` and `toString` are
  unchanged: the diff touches only the `data` doc comment (`table_detail.dart:77-81`).
  `tableDetailOf` and `tableDetailWithoutGeometry` each gain an optional named `data`
  that defaults to `const {}`. `_detailOf` is private.
- The new controller methods are additive. The guide, probe and demo for them
  are Task 5's work (P-7), not this task's.

## 2. Correctness (verified by reading and by probes)

- **Limits** (`table_data_component.dart:35-55`):
  - `> 32` keys is refused.
  - A key must match `^[a-z0-9_.-]{1,64}$`. Dart's `$` without multiLine anchors at the end of the input only, so `"a\n"` is refused.
  - A value is measured by `value.length`, which counts UTF-16 units.
  - A value may not contain a code unit `< 0x20` or in `0x7F..0x9F`. This is
    textually the same predicate as `tableNumberProblem` (`table_numbers.dart:31-35`), but it is a copy, not a shared function (R-2).
  - Each boundary is pinned (O1–O5, O7, O8, O8c, O9, O9b red), except units against characters (R-1) and the 0x7E side (R-2).
- **Sorted write and verbatim keep:**
  - `_sorted` writes the keys sorted. `fromJson` keeps any other shape as a deep, unmodifiable, order-kept copy (`_frozen`).
  - Equality of a kept payload is by its encoding.
  - Verified byte for byte through `load`/`designJson` (HD6), the service copy (HD6), a replacing `setTableData` and the undo of it (HD6), and a Delete and its Undo through the view (probe P4, below).
  - Renumbering keeps the data (HD10).
- **`table.invalid_data`:** one warning per root table whose payload is kept, recorded when the survey is taken (`table_index.dart:103-106, 163-173`). Pinned exactly in HD6 and TD6 (O13 and O13b red).
- **`setTablesData`** (`floor_plan_controller.dart:1207-1236`), in this order:
  - The mode check comes first, throwing `StateError`.
  - Every map is then checked; one outside the limits throws `ArgumentError` before anything else happens.
  - `_settle`, then one pass over the entries. It returns false on a duplicate trimmed key, or on a number that names no table or more than one.
  - Entries equal to the table's current data are skipped. If nothing is left, it returns true and creates no step.
  - Otherwise it runs one `CompoundCommand('Table data')`, then `_refreshFlags`.
  - Pinned: all-or-nothing, one step, no-op means no step, `dirty`/`canUndo` on return, and `revision` (HD3, HD5, HD7, HD8, HD11).
- **Delete expander** (`table_label_system.dart:88-142`):
  - Every touched handle that no longer names a node, a definition or an entity, and still carries the component, gets `SetComponentCommand(h, null)`.
  - The detach's inverse joins the same `inverses` list, so undo, redo and the rollback on a throw restore it (TD7, TD10; O20 and O21 red).
  - `_detachFor` returns null for any live handle, so nothing is detached from a live table (O11 red).
  - Nested instances are caught because their own `RemoveNodeCommand` touches them (O10 red).
  - The cheap path is unchanged.

  **Delete paths:** the editor has one delete, `SelectTool._deleteSelection`
  (`jet_cad_2d_flutter/lib/src/select_tool.dart:673-733`), reached by the Delete key. It has an instance branch and a
  group cascade. The only other node removals in the code base are the parametric regeneration's
  (`jet_cad_2d/lib/src/parametric/regeneration.dart:870-874`), which run inside the same
  expander chain (`_previous`). There is no cut, paste, duplicate or explode. Change size
  (`symbol_section.dart:220`) keeps the instance handle, so it keeps the data.
- **`tableDetails`:**
  - The data is read from the component in `_detailsOf`. It is unmodifiable and empty when absent or kept.
  - The cache key includes `stateId`, so a data-only edit refreshes it (O12 red: HD8, HD10, HD11).
  - Hidden tables and tables without geometry carry their data (O23 red).
- **Invariant 4:** in the selection mode both methods throw before touching anything (HD4). Probe P3: in the selection mode, `select({'1'})` followed by the Delete key leaves `designJson()` unchanged.

### Reviewer's probes (`test/review/s2t2_probe_test.dart` in the probe clone, at `2193fca`)

`flutter test test/review/s2t2_probe_test.dart` gave +4 -1. The one failure is P5, the deliberate reproduction of finding (2):
- **P1:** with the view mounted (table system installed), `setTablesData` on `1 2 3 4 5 L 9`. The encoding changes only in `components.jetcad.table_data`, so no label is re-stamped by a data edit. Passed.
- **P2:** tables `1` and `3` with data, deleted together with the Delete key. The result is one step, both detached and `4` kept. The controller's `undo()` restores both in `tableDetails`, and `redo()` drops them again; the section then holds `4` alone. Passed.
- **P3:** invariant 4 under the Delete key in the selection mode. Passed.
- **P4:** a kept `{"data":{"Bad Key":"x"}}` on `2`, deleted through the view. No `jetcad.table_data` remains, and Undo restores it as kept. Passed.
- **P5:** `select({'9'})` in the design view raises `Offset argument contained a NaN value`. The same happens at `14e6c7f` (a P5-only copy of the file run against the parent commit, same assertion), so this is pre-existing.

## 3. Gates (real runs in `/home/user/review-s2t2` at `2193fca`)

| Package | test | analyze | format |
|---|---|---|---|
| `packages/jet_cad_floor_plan` | `06:09 +1541: All tests passed!` | No issues found | 253 files, 0 changed |
| `apps/restaurant_demo` | `00:35 +47: All tests passed!` | No issues found | 5 files, 0 changed |
| `apps/floor_planner` | `02:28 +212: All tests passed!` | No issues found | 47 files, 0 changed |
| `packages/jet_cad_restaurant_symbols` | `00:03 +97: All tests passed!` | No issues found | 15 files, 0 changed |
| `packages/jet_cad_2d` | `+1256 -2` → `expect_failures`: "packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly" (exit 0) | n/a (not edited) | n/a |
| `packages/jet_cad_2d_flutter` | `+1366 ~1 -7` → "packages/jet_cad_2d_flutter: 1374 tests; the standing failures and skips, exactly" (exit 0) | n/a (not edited) | n/a |

The comparison command, run from the clone root, was `dart run tool/ci/expect_failures.dart --package packages/<pkg> --root packages/<pkg> <run.json>`, with `<run.json>` from `--file-reporter json:`. These counts match the implementer's report.

## 4. Mutants

Each mutant was applied by script (`/tmp/claude-0/.../scratchpad/s2t2-mut/mut.py`), run against
`test/tables/table_data_test.dart` and `test/host/table_data_test.dart`, and
reverted with `git show HEAD:<path> > <path>`. `git status` was empty after the run. The baseline is +23, all passed.

### Named (all red)

| Mutant | Change | Red |
|---|---|---|
| M-H22 | `found.isEmpty` / `found.first` | HD3, HD7 |
| M-H23 | the selection-mode `StateError` disabled | HD4 |
| M-H24 | `_sorted` keeps insertion order | HD1, HD2, TD3, TD5 |
| M-H24b | the controller builds a component for `{}`; the ctor accepts empty | HD5, HD6, TD2 |
| M-H27 | `_detachFor` returns null | HD12, TD7, TD7b, TD8, TD10 |
| M-H28 | `_keep` throws `FormatException` | HD6, TD4, TD6, TD8 |
| M-H29(setTablesData) a | each entry executed as it resolves | HD7, HD8, HD11 |
| M-H29(setTablesData) b | maps checked lazily inside the resolve loop, each entry executed at once | HD7, HD8, HD11 |

### Mine

| # | Change | Result |
|---|---|---|
| O1 | keys `>= 32` | red: HD9, TD1 |
| O2 | keys `> 33` | red: HD6, HD9, TD2, TD4 |
| O3 | key length up to 65 | red: HD9, TD2 |
| O4 | key `[a-zA-Z…]` | red: HD7, HD9, TD2 |
| O4b | key `{0,64}` | red: TD2 |
| O5 | value `>= 1024` | red: HD1, HD9, TD1, TD7 |
| **O6** | value counted as `value.runes.length` | **survived** (R-1) |
| O7 | C1 upper `< 0x9F` | red: TD2 |
| O8 | C1 lower `0x80` | red: TD2 |
| **O8b** | C1 lower `0x7E` | **survived** (R-2) |
| O8c | C1 upper `0xA0` | red: TD1 |
| O9 | C0 `< 0x1F` | red: TD2 |
| O9b | C0 `<= 0x20` | red: 18 tests |
| O10 | expander detaches only handles that were root children (misses a nested instance) | red: TD8 |
| O11 | expander drops the `tree[h] != null` guard (detaches live tables) | red: HD12, TD7, TD7b, TD8, TD9, TD10 |
| O12 | the details cache ignores `stateId` | red: HD8, HD10, HD11 |
| O13 | `invalid_data` for any data | red: HD6, TD6 |
| O13b | `invalid_data` never raised | red: HD6, TD6 |
| O14 | a kept payload's inner `data` map re-sorted on write | red: HD6, TD4 |
| O15 | an entry equal to the current data still makes a step | red: HD8 |
| O16 | the duplicate-key check without `trim()` | red: HD7 |
| O17 | `fromJson` accepts extra top-level keys | red: TD4 |
| O18 | `fromJson` accepts `{"data":{}}` as data | red: TD4 |
| O19 | no `_refreshFlags` after the edit | red: HD11 |
| O20 | the rollback skips the derived inverses | red: TD10 |
| O21 | the detach applied but its inverse not recorded | red: HD12, TD7, TD7b, TD8, TD10 |
| O22 | `{}` on a kept payload treated as a no-op | red: HD6 |
| O23 | no-geometry details drop `data` | red: HD6, HD8 |
| O24 | data equality by keys only | red: TD3 |
| **O25** | the cheap path disabled (always wrap) | **survived**: an equivalent mutant for every valid plan (R-5) |

## Findings

### R-1 (Low, test gap): the UTF-16-unit limit is not pinned against a character count

- **Evidence:**
  - O6 survived: `if (value.runes.length > kTableDataMaxValueLength)`, with all 23 tests passing.
  - `value1024` is `'ş' * 1000 + 'x' * 24` (`test/tables/table_data_test.dart:33`, `test/host/table_data_test.dart:42`). Every unit in it is in the BMP, so units and runes coincide. E-6 says "UTF-16 units".
- **Fix:** add to TD1 and TD2 (and HD9 if wanted):
  - `'\u{1F37D}' * 512` accepted (1024 units, 512 runes);
  - `'${'x' * 1023}\u{1F37D}'` refused (1025 units, 1024 runes).

  Verified in the probe clone: this assertion passes at `2193fca` and goes red under O6.

### R-2 (Low, test gap and duplication): U+007E's side of the C1 range is unpinned, and the rule is copied rather than shared

- **Evidence:**
  - O8b survived: `(u >= 0x7E && u <= 0x9F)`, with all 23 tests passing.
  - The predicate at `table_data_component.dart:48-50` is a copy of `table_numbers.dart:31-35`. The plan's wording ("the limits as one function"; "the table numbers' rule") is met in meaning, but two copies can drift apart.
- **Fix:**
  - Assert `{'a': 'a~b'}` accepted in TD1. Verified red under O8b in the probe clone.
  - Optionally, extract `bool isControlCodeUnit(int u)` in `table_numbers.dart` and use it from both functions.

### R-3 (Ruling on the implementer's finding 1): relaxing HD12 is acceptable

- **Evidence:**
  - `AddNodeCommand` re-adds through `DocumentTree._link`, which appends (`jet_cad_2d/lib/src/document/tree.dart:557-570`). The codec writes `children` in stored order (`json_codec.dart:56, 63`).
  - So any delete and undo of a non-last child changes the encoding's order. This predates Slice 2, happens with or without data, and does not change what is drawn (draw order is by handle).
- **What the spec asks for:** E-9 gate 3 asks that "a delete … removes the component and undo restores it". Byte equality was the plan's killer wording, not the spec's.
- **Why the relaxation is enough:** HD12 still pins three things, and M-H27, O11 and O21 turn it red:
  - the `jetcad.table_data` section byte-equal;
  - the restored handle last among the root's children;
  - the whole encoding equal once children are sorted.

  TD7 pins strict byte equality, through undo, redo and undo again, with the real expander on the root's last table.
- **No other way through the view:** a strict-bytes Delete through the view is impossible on this fixture. Its last root child is `9`, and selecting `9` hits R-4.
- **What should still happen (controller's bookkeeping, not this commit):**
  - record the amended M-H27 killer under the plan's *Spec points to settle* (as S-7, or with S-6);
  - log "`AddNodeCommand` does not restore the child's index" as an engine follow-up beside O-8. The host-visible symptom: after Delete then Undo, `designJson()` differs from the saved bytes while `dirty` reads false.

  Task 3's M-H25 diff is by instance, so this does not affect it.

### R-4 (Ruling on the implementer's finding 2): pre-existing, not reachable from the UI; out of scope

- **Evidence:**
  - Probe P5 raises `Offset argument contained a NaN value` on `select({'9'})` at both `2193fca` and `14e6c7f`.
  - Table `9`'s placement is `Transform2(1e306, 0, 0, 1e-306, …)` (`test/host/embedding_fixture.dart:117`).
  - The editor has no free scale for an instance. Change size keeps the placement's linear part (`symbol_section.dart:196-222`), and the select tool only moves, turns and mirrors.
- **Who can reach it:** only a hand-edited or foreign file with non-finite corners reaches it. A real user working only in the UI cannot. It is a debug assertion; a release build draws garbage grips rather than crashing (not verified on a device).
- **Fix:** a separate render-package task (`SelectionOverlayPainter._paintGrips` skips non-finite points). It does not block Task 2.

### R-5 (Info): the cheap path skips the detach on a plan with no servable definition

- **Evidence:**
  - O25 (always wrap) survived.
  - Data can only be written to a table, and a table needs a `SeatingComponent` definition, so a plan without one has no data that `setTableData` wrote.
  - Only a hand-edited file carrying `jetcad.table_data` on a non-table, in a plan with no servable symbol, keeps an orphan on delete. 0.3.0 does the same.
- **Fix:** none needed. Optionally, widen the comment at `table_label_system.dart:48` to say so.

### R-6 (Info): "verbatim" means re-encoded by the codec, not source text

- **Evidence:**
  - A kept payload is held as decoded JSON and written with the engine's `jsonEncode`. `dart run` of `jsonEncode(jsonDecode('{"data":{"a":1e3,"b":1.50}}'))` prints `{"data":{"a":1000.0,"b":1.5}}`.
  - Byte-for-byte therefore holds for every payload this codec wrote (HD6, TD4), which is what E-9 gate 2 needs. It does not hold for arbitrary hand-written number spellings. The whole file is re-encoded anyway.
- **Fix:** none in code. Task 5's guide, if it says "kept as read", should say "kept as read (re-encoded)".

## Note on the reviewer's scratch space

My first gate run wrote into `scratchpad/gates/`, which already held another
review's stale files from 2026-10-08 (`sha` `5022cc9`). Before I stopped and
restarted in `scratchpad/s2t2-gates/`, it overwrote that directory's `run.sh`
and `jet_cad_floor_plan.test.log`. Nothing in the repository was affected.
