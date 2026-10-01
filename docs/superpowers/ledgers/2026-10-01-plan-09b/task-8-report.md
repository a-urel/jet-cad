# Task 8 report — the Symbols tab

Commit: af704cf `feat(app): the Symbols tab` (on 76e5f8b).
Files: apps/floor_planner/lib/symbols/symbol_panel.dart (new),
apps/floor_planner/test/symbols/symbol_panel_test.dart (new, 14 tests).
main.dart untouched (Task 9).

## Gates (app only; engine and render untouched by this task, unchanged)
- `CI=true flutter test`: `02:58 +873: All tests passed!` (859 + 14)
- `CI=true flutter analyze`: `No issues found! (ran in 1.3s)`
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 151 files (0 changed)`
- `CI=true flutter build web --release`: `✓ Built build/web`

## Decisions
- Keys: `symbol-search`, `symbol-search-clear` (the field's x while non-empty),
  `symbol-search-empty` (the "No symbols match "<query>"" text),
  `symbol-search-clear-empty` (its Clear), `symbol-loading`, `symbol-failed`,
  `symbol-error`, `symbol-retry`.
- R-B8-1: `SymbolPanel` takes an extra optional `measurer` (default
  `InsertionPointMeasurer()`) for `prepareDocument`; the plan's signature has
  none. A symbol holds no text. Task 9 may pass the document's. Cost if wrong: none.
- R-B8-2: `permissions` is a `DraftPermissions` value (the shell rebuilds the
  panel); `kSymbolPlacementNeeds` = structure, geometry, components.
- R-B8-3: `onSelect(SymbolEntry)` maps the gallery id back through a map of the
  loaded library's entries; `symbolIdOf` and `symbolThumbnailDocument` are
  top-level (the gallery's builder calls the latter).
- cellColor = `colorScheme.surfaceContainerLowest`; foreground =
  `foregroundFor(cellColor.toARGB32() & 0xFFFFFF)` (black on the light cell, tested).
- The Retry, the x and the empty-result Clear are under `ExcludeFocus`.
- No pixel is read in this task's tests, so none needs `runAsync`.

## Mutants
Driver scratchpad/b8/mut.sh (cp backup, one-line replace in
lib/symbols/symbol_panel.dart, run test/symbols/symbol_panel_test.dart in the
foreground, cp back; every restore printed `restore diff exit=0`). Lines at
af704cf. All red.

| id | line | mutation | red (real output) |
|---|---|---|---|
| M-09b7 | 217 | `ShellShortcutGuard(` -> `KeyedSubtree(` | `+6 -1: the field and the shell's keys typing r, w and m in the field fires no shortcut (M-09b7) [E]` |
| M-09b8 Esc | 222 | the Escape binding removed | `+7 -1: ... Esc in the field hands the focus back to the canvas, and does not reach the shell (M-09b8) [E]` |
| M-09b8 Enter | 233 | `onEditingComplete` removed | `+8 -1: ... Enter in the field hands the focus back to the canvas (M-09b8) [E]` |
| M-09b8 tap-outside | 234 | `onTapOutside` removed | `+9 -1: ... a tap outside the field hands the focus back to the canvas (M-09b8) [E]` (+ the M-09b22 test, which ends on a canvas-focus check) |
| M-09b9 | 159 | active-tool check dropped (`entry == null`) | `+10 -1: the gallery the highlight follows the active tool and the armed entry (M-09b9) [E]` |
| M-09b10 | 174 | `onRetry: () {}` | `+2 -1: states a failed load shows its message and Retry; Retry reaches ready (M-09b10) [E]` |
| M-09b22 | 28 | `Capability.components` dropped from the needs | `+11 -1: the gallery a tap reports the entry; a denied structure, geometry or components disables the cells (M-09b22) [E]` |
| thumbnail turned | 43 | `quarterTurns: 1` | `+13 -1: the gallery the thumbnail document is the placer's identity output ... [E]` |
| thumbnail offset | 43 | `at: basePoint * 2` | same test `[E]` |
| thumbnail mirrored | 43 | `mirrored: true` | same test `[E]` |
| foreground ignored | 199 | `foreground: 0xFFFFFF` | `+12 -1: the gallery the cells are the entries: id key@version, label the name, the thumbnail key the id [E]` |

## Open
- `typing r/w/m ... filters` (spec Testing): `sendKeyEvent` in a widget test
  inserts no text, so the guard test proves the counts stay 0 and the field
  keeps focus; filtering is proven separately by `enterText('bed')`.
- Task 9: pass `measurer` if wanted (R-B8-1); wire `onSelect` to arm + `_activate`.
