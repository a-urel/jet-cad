# Task 6c report
Commit 971eb76 (test-only, apps/floor_planner/test/symbols/furniture_library_test.dart; no lib/asset change).
Gates: app flutter test 780 passed (776 + 4 new), analyze clean, format 0 changed. Engine/render not re-run (test-only app change).
New group "the outline and the category of each symbol":
- tables cover exactly the 25 shipped keys (hand-written closedPolylines and categories tables)
- every polyline leaf is closed (isClosedPolyline) and each symbol has its hand-written closed-polyline count
- first leaf is a closed polyline or a circle (circle only where table count is 0)
- each key is in its literal category
Mutants (catalog backed up, asset regenerated, restored by cp, regenerated; asset diff exit 0, catalog diff exit 0):
1. _rect closed:false + regen: 2 failures (closed-count test, outline test), "+87 -2: Some tests failed."
2. bed.single category -> kitchen + regen: 1 failure (Expected 'Bed Room', Actual 'Kitchen'), "+88 -1".
Final git status: only pre-existing " M packages/jet_cad/analysis_options.yaml" (not committed).
