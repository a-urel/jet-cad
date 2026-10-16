# Task 3 report: host gaps H1-H4

Status: DONE_WITH_CONCERNS (see concerns; no behaviour was changed).
Commit: feat(plan): PlanToolIds public; host kits, two views and userCamera pinned (one commit, amended once to add CHANGELOG and an import fix).

Gates (plan): flutter test --enable-vmservice: "02:03 +1563: All tests passed!" (before the unused-import fix); after the fix, analyze clean, format 0 changed, and the new/barrel tests re-run green. Integration (--enable-vmservice): "+228: All tests passed!", analyze "No issues found!", format 0 changed.

Files: lib/jet_cad_2d_plan.dart (export PlanToolIds), plan_controller.dart (doc comments on the class and canvasRect), test/barrel_test.dart, test/host/{tool_ids,host_kit,two_views}_test.dart, test/service/view/user_camera_test.dart, CHANGELOG.md.

Mutations (each run on committed code, reverted with git checkout, git diff --quiet passed):
- H1 drop the barrel export: tool_ids_test and barrel_test red (compile error).
- H2 `_symbols = _named(load.symbols.where(startsWith('test.')))`: host_kit_test red.
- H3 `_canvasRect.value ??= global` (keep the first placed): two_views_test red.
- H4 `_userCamera` always wraps the gesture detector: user_camera_test (flag off) red, scale changed (pinch/wheel). `_pans = true` in service_tool.dart: red at "a drag does not pan". The wheel lives in the engine's CameraGestureDetector, so "ignore the flag for the wheel" alone is not reachable from this package; the detector mutation covers pinch and wheel together.

Concerns / decisions:
1. H3 premise differs from the spec's wording. PlanCanvas asserts (debug) on a second canvas for one controller, so two views means two PlanServiceViews (the parity row M-DT-11). "Last placed" holds, but placed means "last to report a changed rect" (first report or a move/resize). Two views mounted in the same frame report in an undefined order: a view still owing the plan's first fit reports after one that does not, so the FIRST view won when both were mounted together. Documented in the class comment; the test mounts the second view later, re-places the first by resizing, then unmounts. The guide (Task 5) should say "mount the driving view after the others".
2. H3 "camera": the camera itself is shared; what the last-placed canvas drives is canvasRect, hence zoomBy's default focus (tested).
3. H2 test kit is built in memory with existing helpers (symbolKit, itemsBytes) beside unitKit; placed through the gallery cell then the symbol tool.

## Fix round 1
The report path already did remove-then-insert (`_canvases..remove(view)..[view] = global`), so a report did move a view to the end; the survived mutation came from the test, not the code. Added a comment there and fixed the doc ("most recent reporter among the rest takes over").
New three-view test in two_views_test.dart: A, B, C mounted (C drives); A resized (A drives), B resized (B drives); B unmounted -> A (the latest remaining reporter; not C, not the first); A unmounted -> C. (Positioned children keyed, else removing B remounted C.)
Mutations, each red then reverted: `.last` -> `.first` at the fallback; the `remove(view)` dropped from the report path. 
Full plan suite --enable-vmservice: "02:01 +1564: All tests passed!"; analyze and format clean. Integration: see the run below the commit.
