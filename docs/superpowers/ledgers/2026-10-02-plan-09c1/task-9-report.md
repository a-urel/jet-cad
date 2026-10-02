# Task 9 report — leaf-equal reuse (spec D10)

Status: done, commit `a073fb5` `fix(app): do not reuse an edited symbol definition` (not pushed).

## Plan
- `isLeafEqual(DraftDocument, Handle, SymbolEntry)` in `lib/symbols/symbol_placer.dart`; the lookup in `placeSymbol` passes over a non-equal definition.
- Tests in `test/symbols/symbol_placer_test.dart`.

## Built
- `apps/floor_planner/lib/symbols/symbol_placer.dart`: public pure `isLeafEqual(DraftDocument, Handle, SymbolEntry)`;
  the lookup in `placeSymbol` adds `&& isLeafEqual(doc, h, entry)`, so a non-equal definition is passed over and the
  search continues; none left -> copy under the existing `#n` rule (unchanged code).
  Record comparison: the live record `copyWith(handle/owner/geomIndex := entry's)` `==` the entry's record, i.e. the
  record's own `==` covers every other field (kind, layer, linetype, linetypeScale, colour, lineweight, transparency,
  flags, text, tag, textStyle, textAttrs) and any field added later. Payload: `GeometryPayload ==` (coords and
  scalars, `listEquals<double>`, exact). Base point x/y exact; child nodes via `tree.childNodesOf(def.children)`
  (the tree's shared predicate, tolerating DXF leaf handles); leaf count of live entities owned by the definition;
  the doc's leaves sorted ascending by handle and paired with `entry.leaves` in list order (SymbolEntry's contract:
  ascending by handle).
- Not shared with the Task 3b helper (that helper compares a library to a pinned file; this one compares a document
  definition to an entry: not trivially the same).

## Tests added (test/symbols/symbol_placer_test.dart, group `leaf-equal reuse`)
Fixture `styledSofa()` (top of file): the fixture sofa (base point (900, 400)) with every leaf restyled away from
the defaults, distinct per leaf (colour Indexed/True, lineweight 50/25/18/35/13/9, transparency 77/12/200/90/45/3,
flags unpickable or invisible, linetype continuous, linetype scale 1.5/2.25/0.625/0.75/3.0/0.5), plus a text leaf
(4214, 'SOFA', textAttrs 0x12, at local (0.0, 655.5)) and an attrib leaf (4215, 'ACME'/'MAKER', textAttrs 0x21).
Placements: 30° rotation vector, mirrored, at (100000.25, -70000.75); the follow-up placement quarterTurns 3 mirrored
at (-4000.5, 8000.25).
- L1 x20 (`L1 <edit>: the found definition is passed over and the entry is copied as #2; the next placement reuses
  the copy`): edits = a leaf coordinate (+1e-9), a payload scalar (arc sweep +1e-9), a text scalar (height x2), the
  kind (line -> polyline), the layer (SetEntityLayerCommand to a new layer), the linetype, the colour, the lineweight,
  the transparency, the flags, the linetype scale (+2^-20), the text (SetEntityTextCommand), the tag
  (SetEntityTextCommand on the attrib), the text style, the text attributes, an extra leaf, a missing leaf (middle),
  a missing last leaf, a child node (GroupNode under the definition), a moved base point (+1e-9 in y). Each asserts:
  isLeafEqual false on the edited one; after placing: names [`sofa.three@3`, `sofa.three@3#2`], the instance on #2,
  liveCount + 6, isLeafEqual true on the copy; a third placement reuses the copy (two definitions, no new leaf).
  Record fields without an edit command are changed by Remove+Add of the same handle (`restyle`).
- L2 an unedited definition is reused: one definition, no new leaf (validate empty).
- L3 -0.0 vs 0.0 counts as equal (stated, not a mutant): text x coordinate and rotation scalar stored as -0.0.
- L4 isLeafEqual false for an instance handle and for an unknown handle.
- L5 the styled fixture is valid (validate empty after two placements) and its leaves are not defaults.

## Mutants (lib/symbols/symbol_placer.dart; each: cp backup, mutate, run symbol_placer_test.dart, cp back, diff = 0)
| Id | Line | Change | Red tests |
|---|---|---|---|
| M-09c-p (scalar) | :221 | payload compared with scalars taken from the entry (coords only) | L1 a payload scalar (arc's sweep); L1 a text scalar (the height) |
| M-09c-p (style) x12 | :218 | add `<field>: want.record.<field>` to the normalising copyWith, for each of color, lineweight, transparency, flags, linetypeScale, linetype, layer, kind, text, tag, textStyle, textAttrs | exactly the matching L1 test each (the colour / the lineweight / the transparency / the flags / the linetype scale / the linetype / the layer / the kind / the text / the tag / the text style / the text attributes) |
| M-09c-p (base point) | :199 | line deleted | L1 a moved base point |
| M-09c-bd (child nodes) | :200 | line deleted | L1 a child node |
| M-09c-bd (leaf count) | :208 | line deleted | L1 a missing last leaf; L1 an extra leaf (RangeError) |
| local: coords | :221 | payload compared with coords taken from the entry | L1 a leaf coordinate |
| local: no D10 | :114-115 | `&& isLeafEqual(...)` removed from the lookup (pre-09c behaviour) | all 20 L1 (`+34 -20`) |
| local: first match only | :114-119 | lookup stops at the first key/version match, then drops it if not leaf-equal | all 20 L1 (third placement makes `#3`: `Expected: [18, 26] Actual: [18, 26, 34]`) |
| local: owner not normalised | :217 | `owner:` line deleted | 27 red incl. L2, L3, P7, P8c, P11, P15, P19 (`+27 -27`) |

Note: a first attempt at "first match only" added the post-check without removing the in-loop check (an equivalent
mutant, all passed); re-fired correctly as above.
`L1 a missing leaf` (middle) is not killed by the leaf-count mutant alone (the pairing catches it: text vs circle);
it is owed the no-D10 mutant. `a missing last leaf` was added so the count mutant has its own red test.

## Gates (apps/floor_planner; engine and render untouched, not re-run)
- `CI=true flutter test`: `06:02 +1121: All tests passed!` (1,097 before this task + 24 new).
- `CI=true flutter analyze`: No issues found. `dart format --set-exit-if-changed .`: 180 files, 0 changed.
- `CI=true flutter build web --release`: `✓ Built build/web`.

## Proposed rulings
- R-C9-1: the record comparison is the record's own `==` after normalising handle, owner and geomIndex to the
  entry's, rather than a field list: a field later added to `EntityRecord` is compared automatically. Cost if wrong:
  none functionally; mutants are expressed as an extra copyWith field.
- R-C9-2: the entry side is paired in list order (SymbolEntry's documented ascending-handle order), not re-sorted.
  Cost if wrong: an entry built out of order would never be reused (a copy per placement); the library loader
  guarantees the order.
- R-C9-3: "the text style" edit uses a handle that names no text style (no command adds a text style); that case does
  not assert validate. Cost: none (isLeafEqual reads no table).

## Found, not fixed
- symbol_placer_test.dart group `the library entry is read-only to a placement`: comment says "a record has no `==`,
  a payload compares by identity" — both have value `==` today; stale comment (pre-existing).

## Reviewer: look hardest at
- That the 12 style mutants each kill exactly one test (normalising copyWith); and the leaf-count mutant's red tests.
- Cost: isLeafEqual scans all live slots per candidate definition (O(entities x candidates) per placement build);
  not on the frame path.
