# Task 4b report

Status: DONE_WITH_CONCERNS

Commits: 1233a6ca fix(plan): settling finishes an open text entry and hands panel focus back (lib + tests SET-1, SET-2 in test/panels/page_scale_field_test.dart); 1b00fdaa fix(demo): the document name fits the bar at 800 px; the settle cases run.

## Library
- TextEntryOverlay (lib/src/canvas/text_entry_overlay.dart) registers a settle with the controller (initState; re-registered on controller swap; released in dispose): if tool.isPending, tool.finish(tools.context) (commit as Enter, one step; _onPending hands the focus back to the canvas).
- PlanPagePanelState.resyncScale now calls _scaleFocus.handBack() before the re-sync.
- Gates, jet_cad_2d_plan: `01:..+1554: All tests passed!`, `No issues found!`, `Formatted 299 files (0 changed)`. jet_cad_2d_integration `+227: All tests passed!`.
- Mutations (run on committed code, reverted with git checkout --, git diff --quiet passed):
  - M-SET-1 drop the overlay's registerSettle: SET-1 red (Expected: contains 'Kitchen', Actual empty).
  - M-SET-2 drop _scaleFocus.handBack() in resyncScale: SET-2 red (primary focus is the PanelFieldFocusNode, not the canvas).

## App
- Four skips removed (ST2, ST3, ST4-focus, ST8), cases unchanged, all pass (document_settle_test: 11 passed). Header comment updated.
- DC12 restored at 800x600 (name bound assertion now 160). DC12c range restored only to its measured floor: 1000 -> 776 px.
- Measurement: name widget maxWidth 160 in _DocumentTitle. The fixed part is 616 + maxWidth (856 at 240). By running DC12c with the loop floor lowered: 776 passes, 775 overflows by 1.00 px. 160 fits 800 px leaving 24 px for the status.
- CONCERN: the old DC12c range (704 -> 656 px) cannot be restored by narrowing alone: 656 needs maxWidth 40 (the library's bar needs 576 px by itself, the Open sample button 40, the name the rest), a name widget that shows almost nothing. DC12c keeps "Decided: premise impossible (the range)" with floor 776.
- Mutation M-width: maxWidth 160 -> 240: DC12 and DC12c red; reverted, clean.
- Gates app: `+94: All tests passed!`, `No issues found!`, `Formatted 27 files (0 changed)`.

## Fix round 1
- Item 1: packages/jet_cad_2d_plan/test/canvas/text_entry_settle_test.dart TES-2 (unmounted overlay: a later save commits nothing, entry stays pending) and TES-3 (controller swap: old controller's settle gone, new one's settles it). Mutations, each run on committed code and reverted (`git diff --quiet` passed): drop release in dispose -> TES-2 red; drop release in didUpdateWidget -> TES-3 red; drop re-registration in didUpdateWidget -> TES-3 red.
- Item 5: SET-1 moved to that file as TES-1 (mutation named in its description); SET-2 stays in page_scale_field_test.dart.
- Item 2: ST4 merged back into one case with canvasFocused(); ST4-focus and the stale note deleted; header updated.
- Item 3: undo depth in ST1 is exact again (2, then 3) as in the old test; the only difference, `dirty == false` in place of the private savedState check, is stated in the header.
- Item 4: DocumentSession.isDisposed; `_flow`'s finally skips busy when disposed; `_write` returns true before markSaved/named when the host is unmounted (a second hazard found by the test: markSaved on the disposed controller). Test DS8 unmounts the app during a held write: no error. Mutations: drop the isDisposed check -> DS8 red ("ValueNotifier<bool> was used after being disposed"); drop the `!mounted` return -> DS8 red (same message, from markSaved).
- Gates: plan `+1556: All tests passed!`, analyze `No issues found!`, format 0 changed; integration `+227: All tests passed!`; app `+94: All tests passed!`, `No issues found!`, format 0 changed.
- Commits: fix(demo) ST4/DS8 lib+tests; test(plan) text_entry_settle_test.
