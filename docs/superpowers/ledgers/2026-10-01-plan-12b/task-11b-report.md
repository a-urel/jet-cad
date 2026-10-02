# Task 11b report — the final review's fixes

Base HEAD 35af9b9. Scratch: scratchpad/l11b/.

## Step 1 (engine + app) — commit 064965c `fix: the final review's fixes to plan 12b`

- `packages/jet_cad_2d/lib/src/document/layer_commands.dart`: `SetLayerCommand` user form calls `layerNameError` only when `record.name != old.name`; doc comment updated.
- `packages/jet_cad_2d/test/document/layer_commands_test.dart`: new test — loaded layers `Walls:Ext` (ACI 4) and ` Walls` (ACI 6), reloaded through the codec, can be hidden / locked / recoloured (one undo step each, undo restores bytes), a rename to `Walls|Ext`, `Walls `, `` is refused with bytes and undo depth unchanged.
- `apps/floor_planner/lib/layers/layer_panel.dart`: `_execute` catches `ArgumentError` and `StateError` (comment `// Refused: nothing changed.`, as `LayerPicker._choose`). A first draft returned a bool so `_add` would not select a refused add; dropped before the commit as redundant (build() already clears a `_selected`/`_editing` the table lacks) and unpinnable.
- `apps/floor_planner/test/layers/layer_panel_test.dart`: two tests — the eye of a `Walls:Ext` layer hides it (one command); a refused hide (A made current by a direct header write the panel does not observe, so the built eye stays enabled) leaves the encoded bytes, undo depth and record unchanged and `takeException()` is null.

### Gates at 064965c (CI=true, PATH=/root/flutter/bin)

- engine `dart test`: `00:18 +1226 -2: Some tests failed.` (the 2 standing: generate_document_test.dart "the default document is the one Plan 2 measured, byte for byte", "both text fractions default to zero and change nothing"; +1 test vs 1225). `dart analyze`: `No issues found!`. format: `Formatted 168 files (0 changed) in 0.61 seconds.`
- render `flutter test`: `01:00 +1187 ~1 -7: Some tests failed.` (unchanged). `flutter analyze`: `No issues found! (ran in 1.5s)`. format: `Formatted 208 files (0 changed) in 0.64 seconds.` `--tags golden`: `00:33 +28 -7: Some tests failed.` — text ladder rungs 1-5 and text lod ladder rungs 1-2 (RenderBackend.canvas), the standing 7.
- app `flutter test`: `03:33 +993: All tests passed!` (+2 vs 991). `flutter analyze`: `No issues found! (ran in 1.9s)`. format: `Formatted 175 files (0 changed) in 0.82 seconds.`
- dev_harness_2d `flutter analyze`: `No issues found! (ran in 1.2s)`.
- Allocation invariant tests untouched and inside the green/standing runs above.

### Mutants (cp to scratchpad/l11b/, one edit, named test file, cp back, diff exit 0 each time)

| Id | Mutation | Test file | Real output |
|---|---|---|---|
| M11b-1 | layer_commands.dart:293 `if (record.name != old.name) {` -> `if (true) {` (the unconditional check) | engine test/document/layer_commands_test.dart | `SetLayerCommand a loaded layer whose stored name fails D4 can be hidden, … (final review finding 1) [E]` / `Invalid argument (name): A layer name cannot contain :.: "Walls:Ext"`; `00:00 +42 -1: Some tests failed.` |
| M11b-1 (app) | same | app test/layers/layer_panel_test.dart | `Expected: false` `Actual: <true>`; `a loaded layer whose stored name fails D4: its eye hides it, one command (final review finding 1) [E]`; `00:08 +25 -1: Some tests failed.` |
| M11b-1b | layer_commands.dart:293 -> `if (false) {` (no name check at all) | engine layer_commands_test.dart | `Expected: throws <Instance of 'ArgumentError'>` `Actual: <Closure: () => void>` on M-LP-8, "a rename to an invalid name is refused…", and the new test (3 red) |
| M11b-2 | layer_panel.dart:152 `} on ArgumentError {` -> `} on UnsupportedError {` (drop the catch) | app layer_panel_test.dart | `Expected: null` `Actual: ArgumentError:<Invalid argument (record): The current layer cannot be hidden.: …`; `a command the document refuses is caught: … [E]`; `00:08 +25 -1: Some tests failed.` |

Unpinned: the `on StateError` arm of `LayerPanel._execute` (no panel action reaches a StateError from a sound document; kept for parity with `LayerPicker._choose` and the Selection section, as the brief asks).

Decision: the app "refused command" fixture makes A the effective current layer by a direct `doc.header.currentLayer` write, which the panel does not listen to (it follows the dispatcher's changes and the table's), so A's eye stays enabled until the next rebuild and its press dispatches a hide the user form refuses (decision 7). A `DuplicateHandleError` from `+` was considered and rejected: it implements `Exception`, not `ArgumentError`/`StateError`, so it is outside the catch the brief names (and unreachable: the handle comes from the seed).

- web `CI=true flutter build web --release` (floor_planner) at 064965c: `Compiling lib/main.dart for the Web... 52.7s`, `✓ Built build/web`.
- `git status --short` empty after each commit (analysis_options.yaml not rewritten this time).

## Step 2 (docs) — commit 93312dd `docs: the final review's fixes to the plan 12b results`

- Line numbers verified at the branch: `generate_document_test.dart` constants at :66, :68, :251, :253; a real run on Linux reports `Expected: <1593811103237081036>` `Actual: <-565808937189420354>` at `65:5` and `250:5` (one actual per test, confirming Finding 2).
- Results note: look-list fingerprint step reworded as two runs (:66/:251 then :68/:253); the "every task had … reviewer" sentence corrected (10b c3ab7ca, 11a 1f2788a/35af9b9 reviewed only by the final review); task table rows 10/11a corrected, an 11b row added, the engine-frozen note qualified; new section "The final whole-branch review" (verdict Ready with fixes, Findings 1-4 with resolution, the 32-mutant sample by id); M11b-1, -1b, -2 in the notable-mutants table; gates of record moved to 064965c (engine 1,226 = …+1 (11b); app 993 = …+2 (11b); web 52.7s); found-not-fixed gains the unpinned `on StateError` arm and Finding 4.
- Spec "Amended at execution (Plan 12b)": a D1/D4 line for the name check only on a rename (and the panel's catch).
- Not done (not in this brief): archiving the ledger to docs/superpowers/ledgers/ (Finding 3 mentions it "as planned"; left to the controller/merge step).
- Gates: the docs commit changes only Markdown; gates of record are those at 064965c above.
