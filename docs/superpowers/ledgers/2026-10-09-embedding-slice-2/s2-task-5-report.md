# Slice 2, Task 5 — demo, guide, probe, CHANGELOG, spec bookkeeping, gates: implementer's report

Branch `claude/exciting-pasteur-9m22jv`, from `49ad576`. Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.
Pushed: `49ad576..c276271`. No `analysis_options.yaml` touched or committed (`git status` clean after every commit and after the gates).
Not touched: `table_select_tool.dart`, `service_view.dart`, `floor_plan_view.dart`, `interaction_layer.dart`, `tool.dart` or their tests (Task 4 under review). No defect found in them.

## Commits

| SHA | What |
|---|---|
| `ae34b19` | feat(demo): Link tables, Unlinked, a double tap, moves, a pointer line and the design's changes |
| `7729ad5` | docs: the host guide's "Events and host data" and its probe |
| `c276271` | docs: the CHANGELOG's Unreleased gains Slice 2; the spec records O-10 and O-11 |

## 1. Demo (`apps/restaurant_demo`, `ae34b19`)

`lib/main.dart`, `lib/demo_strings.dart` (en, de, tr), new `test/events_test.dart`.

- **Design mode:** "Link tables" (`link-tables`). Every numbered table without `data['id']` gets `id = '<area>-<number>'.toLowerCase()`, beside the keys it already carries, through **one** `setTablesData`, so it is one undo step. Numbers that `numberingWarnings` reports as `DuplicateNumber` are left out, because the planner refuses an ambiguous link and the whole batch with it. Logged as "Salon: linked n tables". Beside it, "Unlinked: n" (`unlinked`) is E-8's recipe by id: `kDemoTableIds` (the POS's ids, salon-1..11 and teras-1..6) minus the ids that visible tables carry in `tableDetails`.
- **Service, `onTableDoubleTap`:** logs "Salon: table 7 opened (id salon-7)" or "(no id)". The id is read from the service copy's `tableDetails`.
- **Service, `onTablesMoved`:** logs "Salon: moved {3, 7}". The numbers are sorted, and an unnumbered table shows as "—".
- **Service, `onTableHover` and `onFloorTap`:** feed one pointer line (`pointer-line`), not the log:
  - "over table 7", "over no table", or "floor at −3.2, 0.8 m";
  - the floor point uses a real minus, and German and Turkish write a decimal comma;
  - it is a `ValueNotifier<PointerLine?>` behind a `ValueListenableBuilder`, so a hover rebuilds only that line;
  - it is cleared on a mode switch, an area switch, Revert and Reset layout (S-5's host duty).
- **`designChanges`:** one subscription per area, cancelled in `dispose`. It logs "table n added", "table n removed" and "plan replaced". `Changed` is not logged.
- **Deviation (forced by "existing tests unedited"):** Revert in the service used to put the kept layout back synchronously. With the new async "plan replaced" line, D16's `log.first == 'layout restored…'` would go red, because the async line lands after the sync restore. Mutant D2-M12 confirms this: D16 is red under it.
  - The restore now happens in the `FloorPlanPlanReplaced` handler, when the mode is selection. So the log reads "reloaded", then "plan replaced", then "layout restored".
  - Behaviour is the same apart from timing: it happens one microtask later, before the next frame, and also for any replacement in the service.
  - All 47 existing demo tests pass unedited.

**Tests** (`test/events_test.dart`, 8 tests, on the sample plans, with screen points from `tableDetails` and `worldToGlobal`):

| Test | What it checks |
|---|---|
| DE1 | Link with a shared number (2 renamed 1), 11 hidden, 5 carrying a POS id and a key of its own (`zeta`), 6 carrying `alpha: 'Masa 6.ğ'`:<br>- exactly 8 linked, other keys kept;<br>- undoDepth +1;<br>- Unlinked 11 → 4 (salon-1, -2, -5, -11);<br>- a second press: "linked 0", no step;<br>- Undo: back to the earlier data. |
| DE2 | Teras: teras-n; the buttons are design-only; the pointer line is service-only. |
| DE3 | A saved plan has `schemaVersion` 9 and carries `jetcad.table_data`. After an unlink and a change, Revert brings the ids back and `designJson() == stored` byte for byte, with dirty false. |
| DE4 | Double clicks with explicit stamps:<br>- 299 ms apart with the clock pumped 1 s: "opened (id salon-7)" after both "tapped 7" lines, and still selects;<br>- 301 ms apart with the clock pumped 0: no open;<br>- table 3 with data but no id: "(no id)". |
| DE5 | A drag of the selected {7, 3}: "moved {3, 7}" right after "layout changed"; service Undo logs no move; an unnumbered stool's drag gives "moved {—}". |
| DE6 | The pointer line:<br>- over 7, the floor (premise: `tableAt` null, on the canvas) and 10;<br>- a floor click with the same mouse: "floor at −3.2, 0.8 m", and the selection is cleared;<br>- hover never logs;<br>- cleared by reset, a mode switch and an area switch. |
| DE7 | `designChanges`:<br>- a placed unnumbered table: "table — added";<br>- the Delete key on 3: "removed"; `c.undo()`: "added";<br>- a rename is not logged;<br>- Revert in the design: "plan replaced" after "reloaded";<br>- Revert in the service after a drag: restored, then plan replaced, then reloaded, and `serviceEdited` true. |
| DE8 | German and Turkish: the button, Unlinked, the pointer lines (over, none, floor with a comma), opened, moved, linked, and Plan ersetzt. |

**Demo mutants** (script `scratchpad/mut/demo_mut.py`; each applied, run, and restored from a copy with an equality check):

| Mutant | Red |
|---|---|
| D2-M1 shared numbers not left out | DE1 |
| D2-M2 existing id overwritten | DE1 |
| D2-M3 other keys dropped | DE1 |
| D2-M4 one setTableData per table | DE1 |
| D2-M5 id not lower-case | DE1, DE2, DE4, DE8 |
| D2-M6 Unlinked ignores visibility | DE1 |
| D2-M7 opened reads the first id found | DE4, DE8 |
| D2-M8 unnumbered move dropped | DE5 |
| D2-M9 hover into the log | DE6, DE8 |
| D2-M10 no clear on reset | DE6 |
| D2-M11 Changed logged | DE1, DE7, DE8 |
| D2-M12 restore kept synchronous in `_revert` | **demo_test D16**, DE7, DE8 |
| D2-M13 PlanReplaced not logged | DE7, DE8 |
| D2-M14 hyphen for the minus | DE6, DE8 |
| D2-M15 no clear on a mode switch | DE6 |

(D2-M8's first form, which used a null-aware element, did not compile at language 3.5. It was re-run as `if (… != null) …!` and is red.)

## 2. Host guide (`docs/host-guide.md`, `7729ad5`)

- **New `### Events and host data`** after "Your own widgets on the tables", marked *Unreleased on `main`*:
  - **The four callbacks:**
    - `onTablesMoved`: once per drag after `onLayoutChanged`; never on Undo, Redo, reset or restore; not called if the host's `onLayoutChanged` replaces the copy.
    - `onTableDoubleTap`: on the same table, not merely the same number; 300 ms and 100 px between the downs; a locked table reports it, an unnumbered one does not; no double tap with a modifier; a third tap starts anew.
    - `onFloorTap`: after the selection logic, modifier or not (S-4); world mm, y up; an unnumbered table's tap is neither a table tap nor a floor tap.
    - `onTableHover`: only on a change; never for a finger; null off the canvas and over an interactive overlay.
  - **R-3's warning** is a bold paragraph.
  - **Hover:** the hovered table is kept in a `ValueNotifier`, because a `setState` that rebuilds the view would run every overlay builder. S-5: no null on a remount, so the host clears its own state on the mode and on a replaced plan.
  - **Host data (E-6):**
    - `setTableData` replaces the whole map; an empty map removes it; undoable, dirty, revision, designChanges; equal data is true with no edit.
    - False for a number that is unknown or ambiguous.
    - Hidden and locked tables take data.
    - `StateError` in the selection mode; the copy carries the data read only.
    - `setTablesData` is one step and all or nothing.
    - The limits, including UTF-16 units (an emoji counts two) and the control-character rule.
    - The component's shape.
    - Delete drops the data and Undo restores it; renumbering keeps it.
    - The lenient read: "kept as read (re-encoded)", read as empty, with `table.invalid_data` for editor code only.
    - **R-5:** the data is the host's to validate.
    - Schema 9.
  - **`designChanges` (E-5):**
    - A table is followed as itself; an undone delete is one `Added`; the order is that of `controller.tables`.
    - `PlanReplaced` in either mode; nothing for a failed load or for the selection mode.
    - Asynchronous, with one report per synchronous step.
    - Nothing on listen; a second listener may hear a preceding edit.
    - Tables are compared only while listened to.
    - `dispose` closes the stream (so no cancel is needed), and undelivered changes are dropped.
- **§ 7** gains the id form of the unplaced-tables recipe (`unplacedIds`, E-8).
- **§ 4:**
  - The view block names the four callbacks.
  - The dispose block gains `hovered.dispose()`, with a pointer to the new section.
  - The parenthetical is reworded.
- **The `data` bullet** in "Your own widgets" no longer says "empty in this release".
- **§ 8** gains a bullet naming the four callbacks.
- **§ 11** gains R-6's bold bullet beside schema 8: schema 9, with or without data; 0.3.0 and every earlier release refuse it; every terminal that shares stored plans moves together; 8 and 7 open unchanged; the service layout is unchanged.

## 3. Host probe (`tool/ci/host_probe/lib/main.dart`, `7729ad5`)

- **New blocks, verbatim:**
  - `unplacedIds`;
  - `tablesMoved`, `openBill`, `floorTapped`, `showHover`;
  - the `hovered` field and its `ValueListenableBuilder` line;
  - `controller.mode.addListener(() => hovered.value = null)`;
  - `linkTable` and `idOf`, `linkAll`;
  - `controller.designChanges.listen(designChanged)` and `designChanged`.
- **Wiring:** the view has the four callbacks, `dispose` disposes `hovered`, and a `link` button calls the data functions.
- **Format:** `dart format` changed only the non-guide button. `check_guide`: "all 32 code blocks are in the host probe".
- **Mutant:** in the probe, `openBill`'s `'the bill of $number'` was changed to `'the bill for $number'`.
  - `check_guide` printed "not in the host probe: dart: /// A drag in the service moved these tables: tell the other terminals." and exited 1.
  - The probe was restored from a copy (`cmp` equal), and `check_guide` then exited 0.

## 4. CHANGELOG (`c276271`)

- **Intro rewritten:** Slices 1 and 2; move every terminal that shares stored plans together, because 0.3.0 and earlier refuse schema 9 with or without data; service layouts are as in 0.3.0; CI keeps analysing the 0.3.0 probe.
- **Slice 1's `data` mention** now points to the host's data instead of "empty until a later slice".
- **New bullets:**
  - **Breaking for stored plans: schema 9**, in 0.2.0's form: why the bump, 8 and 7 open unchanged, the libraries are re-encoded, the service layout format is unchanged.
  - Your data on a table.
  - The design's changes, with the four classes.
  - The selection mode's four events, with the double tap not delayed.
  - `jet_cad_2d_flutter`: `ToolPointerEvent.timeStamp`.
  - `editor.dart`: `isControlCodeUnit` and `TableDiagnosticCodes.invalidData`.
- **Known limits extended:** the demo's new gestures are unchecked on a tablet or terminal; the strings are unread by native speakers; data is checked for shape, never for meaning.

## 5. Spec bookkeeping (`c276271`)

"Out of scope, recorded" gains two entries:

- **O-10:** an undone node removal re-appends the node at its parent's end. After Delete then Undo, `designJson()` differs in children order while `dirty` is false. The cause is `AddNodeCommand` linking through `DocumentTree._link`, `jet_cad_2d/lib/src/document/tree.dart:557-570`, which I verified appends. It is pre-existing and gets its own task, beside O-8.
- **O-11:** selecting a table with non-finite corners trips a NaN-offset debug assertion in `SelectionOverlayPainter._paintGrips`. It is unreachable from the UI and gets its own task.

## 6. Gates (real runs at `c276271`; logs in `scratchpad/gates/`)

| Package | Result |
|---|---|
| `packages/jet_cad_floor_plan` | test `05:58 +1585: All tests passed!`; analyze `No issues found!`; format 257 files, 0 changed |
| `apps/restaurant_demo` | test `00:32 +55: All tests passed!` (47 existing + 8 new); analyze clean; format 6 files, 0 changed |
| `apps/floor_planner` | test `01:59 +212: All tests passed!`; analyze clean; format 47 files, 0 changed |
| `packages/jet_cad_restaurant_symbols` | test `+97: All tests passed!`; analyze clean; format 15 files, 0 changed |
| `packages/jet_cad_2d` | runner `+1256 -2` (exit 1, as designed); comparison: "packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly" (exit 0); `dart analyze --fatal-infos` clean; format 170 files, 0 changed |
| `packages/jet_cad_2d_flutter` | runner `+1371 ~1 -7`; comparison: "packages/jet_cad_2d_flutter: 1379 tests; the standing failures and skips, exactly" (exit 0); analyze clean; format 224 files, 0 changed |
| `packages/jet_cad_2d_gpu` | `+20: All tests passed!`; comparison: "20 tests; the standing failures and skips, exactly"; analyze clean; format 10 files, 0 changed |
| `tool/ci` | `dart test` `+62: All tests passed!`; `dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart` clean; format (CI's file list, `host_probe/lib` included) 11 files, 0 changed; `dart run tool/ci/check_guide.dart` "all 32 code blocks are in the host probe" (exit 0) |
| host probe | `tool/ci/host_probe.sh file:///home/user/jet-cad 7729ad5ebd0d9bcfb47a42d77f8a3ddcc1c98006` exit 0. The lock has 40 packages, with no `flutter_scene`, `flutter_gpu`, `flutter_gpu_shaders`, `scene` or `jet_cad_2d_gpu`. Analyze "No issues found!"; web built; "no GPU renderer, no build hook; build/web is 42M" |
| v0.3.0's probe | `tool/ci/old_host_probe.sh v0.3.0`: "No issues found!" and "old host probe: v0.3.0's main.dart analyses against 7729ad5…" (exit 0); main.dart restored, tree clean |

The probe ran at `7729ad5`. `c276271` changes only the CHANGELOG and the spec.

A plain `dart analyze` in `tool/ci` with no file list reports 12 errors in `host_probe/lib`. That is the stale resolution of an earlier run, and CI does not analyse that way. After `host_probe.sh` resolved at the tip, the probe analyses clean.

**Web builds** (`rm -rf build; flutter build web --release`, at `c276271`):

| App | Result | `build/web` | `main.dart.js` | flutter_scene assets | `cad.shaderbundle` in main.dart.js |
|---|---|---|---|---|---|
| `apps/restaurant_demo` | `✓ Built build/web` (98.5 s) | 42M | 3,738,446 B (Slice 1: 3,724,155) | none (`assets/packages`: jet_cad_floor_plan, jet_cad_restaurant_symbols) | 0 |
| `apps/floor_planner` | `✓ Built build/web` (91.8 s) | 42M | 3,589,709 B (Slice 1: 3,587,061) | none | 0 |

## 7. Web smoke check

**Setup:**
- Headless Chromium through Playwright (`/opt/node-tools/node_modules/playwright`), viewport 1600×1000, `locale: 'en-US'`.
- CanvasKit was served from the build's own copy (`CK_DIR`).
- Semantics were enabled through `flt-semantics-placeholder`.
- The demo's `build/web` at `c276271` was copied to `scratchpad/s2t5/web-demo` and served by `python3 -m http.server`.

**Method:**
- Script `scratchpad/s2t5/smoke.js` (helper `lib.js`); output in `scratchpad/s2t5/smoke.log`; screenshots in `scratchpad/s2t5/shots/`.
- Table positions were found by a hover scan: the mouse moved over the canvas on a 20 px grid, and the pointer line's semantics node was read at each step.
- The log was read by scrolling the side panel to its end.

Output, verbatim:
```
design, before: ["Unlinked: 11"]
design, after Link tables: ["Unlinked: 0"]
log: ["Salon: linked 11 tables","Salon: edited"]
service, pointer line at start: [""]
hover scan: tables seen ["1","2","3","4","5","6","7","8","9","10","11"] points per table {"1":9,"2":9,"3":9,"4":20,"5":25,"6":12,"7":12,"8":1,"9":1,"10":1,"11":1}
table 7 at [820,540] table 3 at [640,450] a floor point [860,390]
mouse over table 7 -> ["over table 7"]
mouse over the floor -> ["over no table"]
click on the floor -> ["floor at 4.5, 3.6 m"]
hover and floor tap logged nothing: true
single click on table 3 -> ["Salon: tapped 3","Salon: selected {3}","Salon: mode Service"]
double click on table 7 -> ["Salon: table 7 opened (id salon-7)","Salon: tapped 7","Salon: tapped 7","Salon: selected {7}"]
drag of table 7 by (60, 40) -> ["Salon: moved {7}","Salon: layout changed"]
mouse over the moved table 7 -> ["over table 7"]
console errors: []
```

What this shows:
- **Salon, Link tables:** Unlinked went from 11 to 0.
- **Service, pointer line:** the mouse over a table and over the floor updates the pointer line, and a floor click shows the point in metres; neither is logged.
- **Single click:** it selects, with no "opened" line.
- **Double click on 7:** it logs its id after both taps.
- **Drag:** it logs the moved number after the layout line.
- **Console:** no console error.

In `5-double-click.png` the line reads "over no table" because the log read had moved the mouse off the canvas. That is expected.

## Findings

1. **Revert in the service now restores the kept layout from the `FloorPlanPlanReplaced` event, not synchronously** (see §1). This was forced by D16 staying unedited once a replaced plan is logged. Behaviour is unchanged apart from timing (one microtask, before the next frame). D2-M12 pins the reason.
2. **A remounted view's hover starts at null.** After a mode switch, moving from a table onto the floor reports nothing, because nothing changed for the new view. Only the next table entered reports. DE6 pins this as the package behaves (S-5). The guide's "clear your state yourself" covers it.
3. **Guide snippets must match `dart format`'s line breaks.** `check_guide` collapses whitespace, so a break after `(` would make a block mismatch. Every new block was taken from the formatted probe.
4. **The spec's E-6 says "a later release may relax a limit".** The guide says the same for a stored map outside the limits.
5. **No defect found in Task 4's files.** The smoke check and DE4–DE6 exercise them through the demo, and all behave as E-1 to E-4 and S-4/S-5 say.
6. **Not done here, as instructed:** the results note, STATUS and the roadmap row. The CI run on GitHub for `c276271` was not checked from here.
