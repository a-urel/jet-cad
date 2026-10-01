# Task 2 brief — the library loader and its wiring (spec D2, R-4)
Read common.md in this directory first and follow it. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/b2/.
Do plan Task 2 exactly. Read first: apps/floor_planner/lib/main.dart (FloorPlannerApp, PlannerShell constructor and state), document_host.dart (how the shell is built, keyed per document, ~:518-527), test/ files that pump FloorPlannerApp (grep -rln "FloorPlannerApp(" apps/floor_planner/test) so you keep them green unchanged.
Notes: rootBundle in widget tests: try the real default read in a testWidgets (the asset is declared in pubspec); if it hangs or fails, use tester.runAsync, and if still impossible record why and test through DefaultAssetBundle.
Do NOT add any UI: the shell only stores 'symbols'. Do NOT add the thumbnail cache parameter yet (Task 3 adds the cache; Task 9 wires it).
Mutants: M-09b10 (retry does nothing), a failure swallowed as loading, the host not passing symbols. Gates: app (current count + new), analyze, format, flutter build web --release; engine/render unchanged (state it).
