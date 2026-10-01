# Task 1 report — symbol search (spec D3)

Commit: d4e85f6 `feat(app): symbol search` (parent eb50a53).

Files:
- apps/floor_planner/lib/symbols/symbol_search.dart (new, pure Dart: imports only symbol_library.dart)
- apps/floor_planner/test/symbols/symbol_search_test.dart (new, 11 tests)

## Gates (app only; engine and render untouched by this task, not re-run)

```
02:36 +801: All tests passed!          (flutter test: 790 baseline + 11 new)
No issues found! (ran in 3.8s)         (flutter analyze)
Formatted 142 files (0 changed) in 0.75 seconds.   fmt exit 0
```

## Test terms (from the real asset, each checked in-test to hit only its field over all 27 entries)
- name alone: `three` -> sofa.three@1 ("Three-seat sofa"; also proves the name is lower-cased)
- tag alone: `couch` -> sofa.three@1; `closet` -> bed.wardrobe@1
- category alone: `living` -> the 4 Living Room symbols (also proves the category is lower-cased)
- two terms: `dining` (7) and `chair` (3) -> `dining chair` = [dining.chair@1]; cross-field `couch living` -> sofa; `couch closet` -> none

## Mutants
Each by cp backup to scratchpad/b1, one-line sed, `CI=true flutter test test/symbols/symbol_search_test.dart` in the foreground, cp back, `diff` exit 0 every time (`restored diff=0`). Lines are in lib/symbols/symbol_search.dart at d4e85f6.

| Id | Line | Mutation | Red tests (of 11) | Real output |
|---|---|---|---|---|
| M-09l | 49 | tag disjunct -> `false \|\|` | tag alone; terms on different fields; upper case; order/empty groups; non-contiguous category | tag alone, test:88 `Expected: ['sofa.three@1']` / `Actual: []` |
| M-09s (every->any) | 36 | `terms.every(` -> `terms.any(` | two terms both required; different fields; white space runs; upper case; blank query; non-contiguous | two terms, test:115 `Expected: ['dining.chair@1']` / `Actual: [` (9 ids) |
| M-09s (category ignored) | 50 | category disjunct -> `false` | category alone; terms on different fields | category alone, test:103 `Expected: ['sofa.three@1', 'armchair@1', 'table.coffee@1', 'tv.unit@1']` / `Actual: []` |
| extra: query not lower-cased | 25 | `query.toLowerCase().split` -> `query.split` | upper case | red |
| extra: name not lower-cased | 48 | `e.name.toLowerCase()` -> `e.name` | name alone; upper case | red |
| extra: empty groups kept | 40 | `if (symbols.isNotEmpty)` -> `if (true)` | name alone; category alone; order/empty groups; different fields | red |
| extra: split on a single space | 11 | `RegExp(r'\s+')` -> `RegExp(' ')` | blank query; white space runs | red |
| extra: category order by first match | 33 | seed a category only when the symbol matches | "a category keeps its library place when its first symbol fails" (only this one) | red |

## Decisions / deviations
- The plan says "a two-symbol fixture". Used instead: the shared 09a fixture (P-2; three symbols, Living Room not contiguous in library order) and a hand-built three-entry fixture (Study, Lounge, Study). Two symbols cannot express the case the last test needs: a category whose first symbol fails the query must still precede a later category. Only that test kills the "category order by first match" mutant; the real asset's categories are contiguous, so it cannot.
- "The library's category order" read as first appearance over **all** entries (SymbolLibrary.categories), not over the matches.
- Return type uses a public typedef `SymbolGroup = ({String category, List<SymbolEntry> symbols})`, the plan's record type exactly. Group symbol lists are unmodifiable.
- The key is not searched (spec: name, tags, category).
- Engine and render untouched (diff is two new app files); not re-run.

## Open issues
None.

## Task 1b (review findings 1-3, test-only)

Commit: 7bed823 `test(app): symbol search pins substrings, the key and tag case (1b)` (parent 674f717). Only apps/floor_planner/test/symbols/symbol_search_test.dart changed (11 -> 16 tests); no lib change.

Changes:
- `fieldsHit` now lists the key too; `hitsOnly` takes a `List<SymbolEntry>`. Because "three" also hits the key `sofa.three`, the name-alone prefix term became `three-seat` (a name-only hit, still proving the name is lower-cased).
- New mid-word single-field tests on the asset, each through `hitsOnly` plus an in-test check that the term does not begin the field: `seats` (name only, the 4 seat-count dining tables), `top` (tag `worktop` only, kitchen.island@1), `room` (category only: all symbols except Kitchen and Office, including Bathroom).
- A hand-built two-entry fixture (Den): `wing` sits only in the key `chair.wingback` and finds nothing; `chair.wingback` finds nothing; `armchair` (its name) finds it. The mixed-case tag `Reading` is found by `reading`, `READING`, `rEaDiNg`. (The loader would refuse a mixed-case tag; the fixture bypasses it to pin the search's own case handling.)

Gate (app; engine/render untouched):
```
03:40 +819: All tests passed!
No issues found! (ran in 1.6s)
Formatted 145 files (0 changed) in 0.68 seconds.   fmt=0
```

Mutants (lib/symbols/symbol_search.dart, cp backup to scratchpad/b1b, restored diff=0 each):

| Mutation | Line | Result: red tests |
|---|---|---|
| name contains -> startsWith | 48 | RED: "a term inside the name finds a symbol" |
| tag contains -> startsWith | 49 | RED: "a term inside a tag finds a symbol" |
| category contains -> startsWith | 50 | RED: "a term inside the category finds a symbol" |
| match on key instead of name | 48 | RED: "the name alone…", "a term inside the name…", "a term in the key alone finds nothing" |
| key also searched (`\|\| e.key.contains(term)`) | 50 | RED: "a term in the key alone finds nothing" |
| tags compared case-sensitively (`tag.contains`) | 49 | RED: "a mixed-case tag is found in any case" |
| M-09l (re-fired) | 49 | RED, 7 tests |
| M-09s every->any (re-fired) | 36 | RED, 6 tests |
| M-09s category ignored (re-fired) | 50 | RED, 3 tests |
