# Task 5 review (81a3271 + a5e38a0) - independent

Verdict: Approved (two minor findings, non-blocking).

Gates (mine): app `02:53 +768: All tests passed!`, analyze No issues, format 0 changed; engine `00:16 +1121 -2` (standing); render `00:47 +974 ~1 -7` (standing); `flutter build web --release` "Built build/web" and build/web/assets/assets/library/furniture.jetlib exists (33423 bytes). `dart run tool/generate_furniture_library.dart` printed "wrote assets/library/furniture.jetlib: 33423 bytes" and `git status` stayed clean: regeneration is byte-identical. Final git status: only packages/jet_cad/analysis_options.yaml; every mutant restored (diff exit 0, asset included).

Content (furniture_catalog.dart, all 25 read): dimensions realistic mm (table 1600x900/2000x900, round d1100, chair 450, double bed 1600x2000, sofa 2000x900, tub 1700x750, etc.); every shape lies inside its [0,w]x[0,h] frame by construction; the base point is the centre or front-centre, inside the bounds and off the origin for every symbol; keys lower-case dotted and unique; exactly the six categories; >= 2 lower-case tags; version 1; lines, polylines, arcs, circles only. Interior detail is coherent (hob burners fit within 520 deep, toilet bowl arc centre (200,200) r200 closes the tank rectangle, pillows inside the bed). Nothing implausible found; the tub drain at the left and tap at the right end is a taste question only.

Findings
1. MINOR (test gap) furniture_catalog.dart `_rect` (PolylineShape closed): making every rectangle open (`closed: false`) and regenerating leaves all 85 tests green (`+85: All tests passed!`). An open outline would be a visible defect and nothing pins closure.
2. MINOR: a category swapped on one symbol (bed.single -> Kitchen, regenerated) stays green: the category list test pins only the six names in order, not each symbol's category.
3. INFO: the asset read path is exercised only via `File('assets/library/furniture.jetlib')` in tests; the real rootBundle load is 09b. The pubspec declaration is pinned by a regex test (removal red).

Mutant matrix (real output, furniture_library_test.dart)
- bed.double basePoint (0,0), asset regenerated: RED `the decoded library every base point is off the origin` (+84 -1)
- stale asset (catalog 2000->2010 not regenerated): RED `the asset the committed bytes equal the built library`
- every leaf kind forced to point, not regenerated: RED decode test and bytes test, `SymbolLibraryError: leaf 13 of 12 is a point: not allowed in a symbol`
- pubspec asset declaration removed: RED `the asset is declared in the pubspec`
- duplicate key, regenerated: RED `built library decodes through the loader` (`repeats the key and version`) plus placement tests
- tag upper-cased, regenerated: RED same test (`the tag "Table" is not lower-case`)
- size slip (table 16x9), regenerated: RED `plausible size ... dining.table.four`
- bed.single category swapped, regenerated: GREEN (finding 2)
- all rectangle polylines open, regenerated: GREEN (finding 1)
