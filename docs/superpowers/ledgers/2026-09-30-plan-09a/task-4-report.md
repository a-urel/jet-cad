# Task 4 report: the placer

Commit: see `git log` (subject `feat(app): the symbol placer`), on plan-09/symbol-library-core, not pushed.
Files: `apps/floor_planner/lib/symbols/symbol_placer.dart` (new), `apps/floor_planner/test/symbols/symbol_placer_test.dart` (new, 24 tests).
`packages/jet_cad/analysis_options.yaml` is modified by pub and left unstaged.

## Gates (real tails)
- app: `03:42 +683: All tests passed!` (659 + 24); analyze `No issues found!`; format `Formatted 134 files (0 changed)`
- engine: `00:21 +1121 -2: Some tests failed.` (the 2 standing generate_document failures); analyze `No issues found!`; format `Formatted 160 files (0 changed)`
- render: `00:58 +974 ~1 -7: Some tests failed.` (1 skip, 7 standing text ladders); analyze `No issues found!`; format `Formatted 178 files (0 changed)`

## Design as built
- `placementTransform`: `translation(at).multiply(rot(q)).multiply(scale(+-1,1)).multiply(translation(-basePoint))`; cos/sin from constant tables indexed by `((q % 4) + 4) % 4`; every stored component passed through `v == 0 ? 0.0 : v`.
- `InstanceStyle` defaults equal InstanceNode's (ByBlockColor, kByBlock, kByBlock, byBlockLinetype, 1.0); test P8b asserts it against a real InstanceNode.
- `placeSymbol`: all handles allocated at construction in order definition, leaves ascending, instance; reuse only when the definition still exists (decision below); name `key@version`, `#2`, `#3`; commands AddDefinition, SetComponent<SymbolComponent>, AddEntity per leaf, AddNode. Pure Dart (imports: jet_cad_2d, vector_math, two sibling files). No table write, no purge.
- Undo of the component: the compound's own inverse contains `SetComponentCommand(h, previous=null)`, which detaches. Verified by test P9 (`withComponent` empty after undo) and by mutant M-09f2.

## Mutant matrix
Procedure: cp backup to scratchpad t4/, mutate, run `flutter test test/symbols/symbol_placer_test.dart`, cp back, `diff` exit 0 (every run printed `restore diff exit 0`). Runner: t4/mut.py, t4/all.py, t4/again.py. Line numbers are in symbol_placer.dart at the commit. Real output lines, first red each (others listed by count):

| id | line | mutation | red test(s), real output line |
|---|---|---|---|
| M-09a | 51 | translation(-basePoint) -> translation(0,0) | `+0 -1: placementTransform P1 the base point lands on at...` |
| M-09b | 84 | found definition discarded (`definition = null`) so every placement copies (the obvious `if (false &&` does not compile) | `+6 -1: placeSymbol P7 two placements of one symbol...`; also P8c, P11, P15 |
| M-09c1 | 49 | drop rotation (identity) | `+0 -1: P1`, `+0 -2: P2`, `+1 -3: P4` |
| M-09c2 | 50 | drop mirror (scale 1,1) | `+0 -1: P1`, `+2 -2: P4` |
| M-09d color | 135 | `color: const ByBlockColor()` | `+7 -1: P8 color reaches the instance`, `+12 -2: P8c` |
| M-09d lineweight | 136 | kByBlock | `+8 -1: P8 lineweight`, P8c |
| M-09d transparency | 137 | kByBlock | `+9 -1: P8 transparency`, P8c |
| M-09d linetype | 138 | byBlockLinetype | `+10 -1: P8 linetype`, P8c |
| M-09d linetypeScale | 139 | 1.0 | `+11 -1: P8 linetypeScale`, P8c |
| M-09e | 98-103 | AddDefinitionCommand omitted | 10 red: `+5 -1: P6`, P7, P8c, P9, P10, P11, P12, P13, P15, P16 |
| M-09f1 | 124 | instance command inserted first, so undo removes the definition while the instance still names it | `+4 -1: P5`, `+13 -2: P9`, P10, P16 |
| M-09f2 | 103-113 | component attached directly to the registry instead of by SetComponentCommand (undo leaves it) | `+4 -1: P5`, `+13 -2: P9`, P10, `+19 -4: P17` |
| M-09h | 82 | lookup ignores version | `+16 -1: P11 an older version beside a newer one...` |
| M-09i | 117 | leaves keep the library's handles | `+4 -1: P5`, `+14 -2: P10`, P11 |
| M-09n | 49 | `Transform2.rotation(q * pi/2)` | `+2 -1: P3`, P4, `+17 -3: P14` |
| M-09o | 114/117 | leaf handles allocated descending, added in library order | `+5 -1: P6`, `+20 -2: P16` |
| M-09t | 94-96 | `#n` suffix loop deleted | `+17 -1: P12 a foreign definition named like the symbol...` (the variant `name = base;` inside the loop never terminates, so the loop was deleted) |
| M-09v | 50-51 | translation(-base) applied before scale (order R.T.S) | `+0 -1: P1` (P1 runs q 0-3 with off-origin at and basePoint) |
| M-09w | n/a | tool is 09b; owed there (R/M consumption and ghost use placementTransform) | not expressible here |
| extra clean | 52 | `-0.0` not normalised | `+2 -1: P3`, `+18 -2: P14` |
| extra orphan | 83 | orphan component reused | `+18 -1: P13 a component whose definition is gone is not reused` |

I also ran a f3 idea (entities before definition) but the edit I wrote was a no-op (`All tests passed!`); it is not a mutant and is not claimed. M-09f1 already covers "undo cannot remove the definition".
Two compile failures on the first attempts of M-09b/f1/f2 (bad mutation text) were redone correctly; those are not counted as red.

## P-6 item 3: validate() on a saved plan with symbols
Test P15 places sofa (rotated, mirrored, coloured, lineweight 70), nightstand (q=3) and a second sofa, then prints: `P-6 item 3: validate() on the saved plan -> 0 diagnostics []`. The decoded plan also validates empty, re-encodes byte-identical, and a placement after load reuses the loaded definition. validate() does not look at components, so a component on a definition (or an orphan one) is silent.

## Decisions and findings
- Reuse requires `doc.tree.definition(h) != null`: a SymbolComponent outlives a removed definition (RemoveDefinitionCommand does not clear it, purge neither), and P13 shows an orphan would otherwise make an instance point at nothing. Mutant X-orphan proves the guard is tested.
- `Transform2` has no `==`; tests compare `toJson()` (stored values exact) or `Tolerance.eqPoint` for geometry decisions.
- A refused or undone placement moves the handle seed (F-8); tests compare documents with `handleSeed` stripped (`encodedNoSeed`) and assert separately that execute/undo/redo allocate nothing (P5).
- Permissions: the compound reports `{structure, geometry, components}` (asserted in P5) for 09b's check before allocation; a denied `components` (P17) and a read-only document (P18) refuse and change nothing.
- Spec points left open or slightly off: D6 says the lookup may scan definitions; P-3's `withComponent` is used. The spec does not say what a component-without-definition means; the guard above is my ruling. AddNodeCommand does not check that the instance's definition exists, so M-09f1's ordering is accepted on execute and only fails on undo.
- Not covered here (owed): the spatial index and painter under a placed instance (Task 6), M-09w (09b).
