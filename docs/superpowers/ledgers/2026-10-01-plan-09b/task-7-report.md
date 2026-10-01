# Task 7 report — the placement tool's keys and permissions

Commit: 67688a1 `feat(app): the placement tool's keys and permissions` (on c975d1d).
Files: apps/floor_planner/lib/symbols/symbol_place_tool.dart,
apps/floor_planner/test/symbols/symbol_place_tool_test.dart (14 new tests:
groups `keys` (11) and `permissions` (3); file now 28). Nothing under packages/ changed.

## Gate (app)
```
03:37 +857: All tests passed!          (843 + 14)
No issues found! (ran in 1.4s)
Formatted 149 files (0 changed) in 0.78 seconds.   format_exit=0
✓ Built build/web
```

## Behaviour (onKey)
- armed null or any KeyUpEvent -> ignored.
- R / M with no Ctrl/Meta/Alt (HardwareKeyboard, as PlacementTool._hasModifier):
  KeyDown steps (R +1, Shift+R -1, quarterTurns kept in 0..3; M toggles) and
  notifies; KeyRepeat handled, no effect. Armed idle and mid-press.
- not pressed: everything else ignored.
- pressed: Esc KeyDown -> cancel(ctx) (drops the press and hides the ghost,
  same path as pointer cancel, R-B6-1), handled; F/F3 KeyDown with no
  modifier -> ignored; everything else (incl. repeats, Ctrl+Z, Ctrl+F, Ctrl+R) handled.
- `_place`: `static const needs = {structure, geometry, components}`;
  `if (!needs.every(ctx.document.commands.permissions.allows)) return;` before placeSymbol.

## Decisions
- D7-1 key-ups always bubble (as PlacementTool, whose onKey returns ignored for
  KeyUpEvent first). R/M key-ups are therefore ignored, not consumed; spec only
  speaks of key-down/repeat.
- D7-2 Esc mid-press uses `cancel(ctx)`, so the ghost hides until the next hover
  (as a pointer cancel). Alternative (keep ghost) equally in spec.
- D7-3 Shift+M also toggles the mirror (only Ctrl/Meta/Alt are excluded by spec).
- D7-4 Mid-press Ctrl+R / Ctrl+M are swallowed (the mid-press rule wins: every
  other key is swallowed); idle they bubble (tested).
- R-B6-2 kept: re-arming keeps turns and mirror.
- Tests feed HardwareKeyboard.instance directly (`handleKeyEvent` down/up in a
  try/finally) under TestWidgetsFlutterBinding.ensureInitialized(), added at
  the top of main.

## Fixtures (P-3)
Placement at gridOf(pB)/gridOf(pC) ~ (81377, -36904), (76402, -45518), chair base
point off the origin, camera 0.05 px/mm; expected transforms computed with
placementTransform(at, basePoint, turns, mirrored) and compared exactly on
a..f; a precondition test checks the 8 turn/mirror linear parts are distinct.
Cases: R, Shift+R, M, M again, R-R-M, Shift+R mid-press, R mid-press, repeat,
modifiers (Ctrl/Meta/Alt/Ctrl+Shift with R, Ctrl/Meta/Alt with M), Esc
mid-press then moves + up (ghostAt stays, seed unchanged, undoDepth 0, next press places).
Permissions: each capability denied alone (with R and M set): no throw, seed
unchanged, no instance, no definition, undoDepth 0; then all allowed -> places (1 turn, mirrored).

## Mutants
Driver scratchpad/b7/mut.sh (cp backup, one-line replace, run
test/symbols/symbol_place_tool_test.dart in the foreground, cp back; every
restore printed `restore diff exit=0`). Lines at 67688a1. All red.

| id | line | mutation | red (real output) |
|---|---|---|---|
| M-09b3 R wrong way | 215 | `? 1 : -1` | `+15 -1: keys R turns the next placement one quarter turn counter-clockwise [E]` (+ 7 more) |
| M-09b3 Shift+R ignored | 215 | `? 1 : 1` | `+16 -1: keys Shift+R turns it clockwise [E]`, `+17 -2: keys keys compose ... [E]` |
| M-09b3 M no mirror | 218 | `_mirrored = _mirrored;` | `+17 -1: keys M toggles the mirror [E]` (+4) |
| M-09b5 | 227 | `cancel(ctx)` removed | `+21 -1: keys Esc mid-press cancels: the remaining moves and the up place nothing [E]` |
| M-09b20 | 211 | `if (true &&` (modifiers not checked) | `+19 -1: keys Ctrl, Meta or Alt with R or M is ignored and changes nothing [E]` |
| M-09b21 | 213 | `if (true) {` (repeat steps) | `+20 -1: keys a key repeat is consumed with no effect [E]` |
| F/F3 swallowed | 232 | `return KeyEventResult.handled;` | `+22 -1: keys mid-press F and F3 bubble; W, Z, Ctrl+Z and Ctrl+F are swallowed [E]` |
| M-09w structure | 81 | dropped from needs | `+25 -1: permissions a denied structure ... [E]` / `PermissionDeniedError: "Place Office chair" needs structure` |
| M-09w geometry | 82 | dropped | `+26 -1: permissions a denied geometry ... [E]` / `... needs geometry` |
| M-09w components | 83 | dropped | `+27 -1: permissions a denied components ... [E]` / `... needs components` |
| M-09b2 | 261 | `placeSymbol(ctx.document, entry, at: at);` before the check | `+25 -1/-2/-3: permissions a denied structure/geometry/components ... [E]` |
| no check | 261 | the check removed | the 3 permission tests, `PermissionDeniedError` |
| idle swallows | 224 | no-press guard removed | `+19 -1: keys Ctrl, Meta or Alt ... [E]`, `+22 -2: keys armed, not pressed: every key but R and M bubbles [E]` |
| inert not checked | 206 | `armed.value == null ||` removed | `+24 -1: keys idle (nothing armed) every key bubbles and changes nothing [E]` |
| R/M not notifying | 220 | `notifyListeners()` removed | `+15 -1: keys R turns ... [E]`, `+17 -2: keys keys compose ... [E]` |

## Open
- Shell-level checks (R reaching the tool through InteractionLayer, W choosing
  Wall, Esc reaching `_escape`) are Task 9's.
