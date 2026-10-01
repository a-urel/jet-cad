# Task 3 report: SymbolLibrary, the loader that validates (+ Task 2b)

Commits (branch plan-09/symbol-library-core, not pushed):
- f9e4c33 feat(app): the symbol library loader
- 5b9237f test(app): SC6 checks each omitted SymbolComponent field on its own (Task 2b)

## Restart handling
The lost implementer's three untracked files were read in full and every rule re-derived from spec D5.
Kept the draft, with one change: a polyline payload must have zero scalars (the draft let scalars through
the malformed check). Added test R20c. Files: apps/floor_planner/lib/symbols/symbol_library.dart,
test/support/symbol_fixtures.dart, test/symbols/symbol_library_test.dart. lib/symbols/ is pure Dart
(dart:convert, dart:typed_data, jet_cad_2d only).

## Gates (real tails, after both commits)
- app: `+659: All tests passed!` (608 + 46 Task 3 + 5 Task 2b); analyze `No issues found!`; format `0 changed`
- engine: `+1121 -2` (the 2 standing generate_document failures); analyze `No issues found!`; format 0 changed
- render: `+974 ~1 -7` (1 skip, 7 standing text ladders); analyze `No issues found!`; format 0 changed
analysis_options.yaml not committed (packages/jet_cad one is modified by pub, left unstaged).

## Mutant matrix M-09j
Mutation: `throw SymbolLibraryError(` becomes `SymbolLibraryError(` on that line (backup in scratchpad t3/, restored, diff exit 0 after each).
Real output lines (only the listed tests went red; everything else green):
| Rule | file:line (symbol_library.dart) | red test(s) |
|---|---|---|
| unreadable bytes | 91 (custom: `rethrow;`, as the generic form does not compile) | `+6 -1: R00 bytes the codec cannot read are refused` |
| codec repaired a cycle | 102 | `+7 -1: R08 a definition cycle the codec repaired` |
| instance in library | 112 | `+8 -1: R06 an instance in the library` |
| group in library | 116 | `+9 -1: R07 a group in the library` |
| no SymbolComponent | 131 (custom: `continue;`) | `+10 -1: R01 without a symbol component` |
| duplicate (key, version) | 135 | `+11 -1: R02 a repeated key and version` |
| key case / white space | 140 | `+13 -1: R03`, `+13 -2: R03b` |
| tag not lower-case | 145 | `+15 -1: R03c` |
| children non-empty (leaf handle) | 149 | `+16 -1: R04 a leaf handle in children` |
| non-finite basePoint | 155 | `+17 -1: R05` |
| leaf owner not a definition | 168 (custom: `continue;`) | `+18 -1: R09` |
| text/fill/attrib | 177 | `+19 -1 R10 text`, `-2 fill`, `-3 attrib` |
| point | 181 | `+22 -1: R11` |
| layer | 215 | `+23 -1: R12` |
| linetype (DASHED 6) | 221 | `+24 -1: R13` |
| text style | 225 | `+25 -1: R14` |
| colour | 229 | `+26 -1: R15` |
| lineweight | 233 | `+27 -1: R16` |
| transparency | 237 | `+28 -1: R17` |
| flags | 241 | `+29 -1: R18`, `+29 -2: R18b` |
| linetypeScale | 245 | `+31 -1: R19` |
| malformed payload | 259 | `+32 -1: R20`, `-2 R20b`, `-3 R20c` |
| coordinate non-finite / beyond 1e6 | 264 | `+35 -1 R21`, `-2 R21b`, `-3 R21c`, `-4 R21d` |
| non-finite scalar | 270 | `+39 -1: R22` |
| zero-length line | 276 | `+40 -1: R23` |
| polyline under 2 vertices | 280 | `+41 -1: R24` |
| circle radius <= 0 | 285 | `+42 -1: R25`, `-2 R25b` |
| arc radius <= 0 | 289 | `+44 -1: R26` |
| zero sweep | 292 | `+45 -1: R27` |
Sites sharing one rule (R03 pair, R10 x3, R18 x2, R20 x3, R21 x4, R25 x2) go red together because they share a throw; each site has at least its own case.

## Task 2b (owed m-T2-1)
SC6 rewritten: a control (full map reads back equal) plus one test per omitted field (key, name, category,
tags, version), each asserting FormatException naming the field. Mutants (fromJson tolerates the missing field
via `?? default`), each alone, each red on exactly its own case:
name `+7 -1 ... without "name"`, tags `+9 -1 ... without "tags"`, version `+10 -1 ... without "version"`,
key `+6 -1`, category `+8 -1`. symbol_component.dart restored after each (diff exit 0).

## Findings / decisions / open
- Spec D5 says "polyline with a non-finite bulge": this codebase has no bulge (polyline payload has empty scalars;
  straight segments only). The rule became "a polyline carries no scalars" (R20c) plus the generic finite-scalar check. Spec should be amended.
- The codec repairs a definition cycle by dropping the instance that closes it, so a nested-instance rule alone
  could not see it; the loader also refuses any codec Diagnostic (line 102, R08). Fills also produce codec diagnostics
  only for fills; the fill-kind case (R10) passed through the kind rule.
- Extra rules beyond D5 (from spec D3): key lower-case without white space, tags lower-case.
- Non-finite numbers in tests use a sentinel replaced by `1e999` in the JSON text (jsonDecode reads it as infinity).
- Fixtures: basePoints off origin, leaves off origin, versions 3/2/1, 3 tags each, file order of leaves not handle order.
- Two generic mutants (91, 131, 168) cannot be written as "delete the throw" because flow analysis needs the branch to exit; used rethrow/continue instead.
