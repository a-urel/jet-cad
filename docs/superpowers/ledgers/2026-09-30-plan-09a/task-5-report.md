# Task 5 report: the content, the generator, the asset

Commits (plan-09/symbol-library-core, not pushed): 81a3271 `feat(app): the furniture library`, a5e38a0 `test(app): the built furniture library decodes on its own`.

## Files
- apps/floor_planner/lib/symbols/furniture_catalog.dart (new): sealed FurnitureShape (Line, Polyline, Circle, Arc) and 25 symbols as data.
- apps/floor_planner/lib/symbols/build_library.dart (new): buildFurnitureLibrary().
- apps/floor_planner/tool/generate_furniture_library.dart (new); apps/floor_planner/assets/library/furniture.jetlib (new, 33,423 bytes); pubspec.yaml (flutter: assets).
- apps/floor_planner/test/symbols/furniture_library_test.dart (new, 85 tests).

## Symbols (25, six categories; size in mm, w x h; base point)
Dining Room: dining.table.four 1600x900 (800,450); dining.table.six 2000x900 (1000,450); dining.table.round d1100 (550,550); dining.chair 450x450 (225,225); dining.bench 1200x350 (600,175).
Kitchen: kitchen.base.600 600x600 (300,0); kitchen.sink 1200x600 (600,0); kitchen.hob 600x520 (300,0); kitchen.fridge 600x650 (300,0); kitchen.island 1800x900 (900,450).
Bed Room: bed.double 1600x2000 (800,1000); bed.single 900x2000 (450,1000); bed.nightstand 450x400 (225,0); bed.wardrobe 1800x600 (900,0).
Living Room: sofa.three 2000x900 (1000,0); armchair 850x850 (425,0); table.coffee 1100x600 (550,300); tv.unit 1600x450 (800,0).
Bathroom: bath.toilet 400x700 (200,0); bath.washbasin 600x450 (300,0); bath.tub 1700x750 (850,375); bath.shower 900x900 (450,450).
Office: office.desk 1400x700 (700,0); office.chair 600x600 (300,300); office.bookshelf 900x300 (450,0).
Every symbol: version 1, >= 2 lower-case tags, basePoint != (0,0), lines/polylines/arcs/circles only, interior detail (pillows, burners, seat backs, dividers). Handles ascend in catalog order (definition, then its leaves, then the next definition).

## Decisions
- Library document is DraftDocument.empty() + registerAppComponents + mm units, NOT prepareDocument: prepareDocument adds DASHED at handle 6, which I did not want in a library (no leaf may use it, and the document has no use for it). Decided: excluded.
- Leaf style: layer 0, linetype BYBLOCK, ByBlockColor, lineweight kByBlock, transparency kByBlock, flags 0. kByBlock is allow-list legal and resolves from the instance, whose default is also kByBlock (document default). Sensible resolution to be confirmed end to end in Task 6.
- Generator runs under plain `dart run tool/generate_furniture_library.dart` (output: `wrote assets/library/furniture.jetlib: 33423 bytes`); nothing in lib/symbols transitively imports Flutter, no restructuring needed. Tests use FlutterTextMeasurer-free InsertionPointMeasurer for prepareDocument.
- Unit-slip check: each symbol placed unrotated in a fresh document, extents between 100 and 4000 on each axis (25 tests).
- Placement tests: each symbol at (12345,-6789), quarter turns 1 (plain) and 3 (mirrored): doc.validate() empty, extents contain `at`.
- Spec nothing wrong found. Note: the spec lists 24-ish symbols; D7's list totals 25 (5+5+4+4+4+3).

## Gates (Linux container, CI=true)
- engine: +1121 -2 (2 standing); analyze clean; format clean.
- render: +974 ~1 -7 (standing text ladders); analyze, format clean.
- app: 683 + 84 = 767 at the first commit, all passed; then +1 test (85 new, 768 total); symbols directory run: +172 all passed; analyze: No issues found; format: 0 changed.
- `CI=true flutter build web --release`: `Compiling lib/main.dart for the Web... 50.8s` then `✓ Built build/web`; build/web/assets/assets/library/furniture.jetlib present.

## Mutants (scratch backups in scratchpad/t5, each restored, diff exit 0)
| Mutant | Red test | Real output |
|---|---|---|
| bed.double basePoint (0,0), asset regenerated | the decoded library every base point is off the origin (only it) | `+84 -1: Some tests failed.` |
| every leaf kind forced to point (build_library.dart), asset regenerated | decode tests (built-bytes decode, placement, size tests) | `SymbolLibraryError: leaf 13 of 12 is a point: not allowed in a symbol`; 82 failures |
| bed.double rect 2000 -> 2010 in catalog, asset not regenerated | the asset the committed bytes equal the built library (only it) | `+84 -1: Some tests failed.` |
The text-leaf variant was not fired separately: the loader's text/point rejections are covered by Task 3 (M-09j).

## Open issues
- None. packages/jet_cad/analysis_options.yaml stays modified and unstaged.
