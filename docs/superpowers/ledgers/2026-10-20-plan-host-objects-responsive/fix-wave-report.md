# Fix wave report: the first fit

Status: DONE. Commit: see `git log -1` (fix(plan): the first fit shows the whole page on a narrow canvas).

Cause (not phone-specific, not an axis or canvas-size bug): `DocumentSession` seeds `PageNotifier` before the host `build` runs; the notifier hears the build's page only from the document's async change stream, after the frame whose post-frame callback performs the first fit. The canvas fit read `page.value` = the default A4 sheet (14.85 x 10.5 m at 1:50), not the Salon's A3. Width-limited on the phone (cut at ~17 m), also too tight on desktop. Probe: fit size (351, 636) page A4 landscape.
Fix: `_open` in plan_controller.dart sets `session.page.value` from the document right after `_runBuild`.

Test: packages/jet_cad_2d_plan/test/editor/first_fit_test.dart (375x812, 800x1280, 1440x900; controller built inside the first build with an A3 page build; whole sheet maps inside chrome-canvas). Red before the fix (3 fails), green after.
Mutation: removing the added assignment -> all 3 red (+0 -3); restored.

Side effect: apps/restaurant_demo/test/look_test.dart DL1/DL2 had pixel-count premises that depended on the over-tight zoom; window raised to 2300x1450 (kWindow, premise size only, no assertion changed).

Screenshot regenerated (throwaway test deleted): whole sheet visible.

Gates: plan (--enable-vmservice) +1633 All passed, analyze clean, format clean; integration +240 All passed, clean; restaurant_demo +112 All passed, clean; architecture_demo +176 All passed, clean.
