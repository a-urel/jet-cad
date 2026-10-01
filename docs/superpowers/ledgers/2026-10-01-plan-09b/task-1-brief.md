# Task 1 brief — symbol search (spec D3)
Read common.md in this directory first and follow it. HEAD eb50a53. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/b1/.
Do plan Task 1 exactly (apps/floor_planner/lib/symbols/symbol_search.dart pure Dart; test/symbols/symbol_search_test.dart).
Read apps/floor_planner/lib/symbols/symbol_library.dart (SymbolEntry, SymbolLibrary) and test/support/symbol_fixtures.dart first. Pick test terms from the REAL asset's names/tags/categories (assets/library/furniture.jetlib, read with dart:io File and SymbolLibrary.decode) so that 'name alone', 'tag alone', 'category alone' each hit ONLY that field for the symbol asserted (check this in the test itself, so a future content change cannot make it vacuous).
Mutants: M-09l, M-09s (both arms). Gates: app (790 + new), analyze, format; engine/render unchanged (state it).
