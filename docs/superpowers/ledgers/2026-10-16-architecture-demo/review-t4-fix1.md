# Re-review: fix round 1 of Tasks 4/4b (read-only)

Range: 1b00fdaa..e1111e50 (d4141133, e1111e50). I2 not re-raised (ruled).

## Per item
- I1 addressed. text_entry_settle_test.dart TES-2 (unmount) and TES-3 (controller swap) exist.
  Own run, mutation: line 146 of text_entry_overlay.dart (release in dispose) replaced by a comment ->
  `00:01 +2 -1`, TES-2 red ("Some tests failed"); `git checkout --`, `git diff --quiet` ok.
- M1 addressed. ST4 is one case again with `canvasFocused()` last; ST4-focus and the stale note are gone; header updated.
  Compared with apps/floor_planner ST4: every assertion is present (premises, files.writes length 1, stored scale 125 in
  the bytes, bytes == bytesOf, scale not committed, undoDepth 1, field shows the stored scale, dirty false, canvas focus).
  Only shell-only swaps (session -> controller, PanelFieldFocusNode -> panelFieldFocused(), panelNumberText(125) -> '125').
  The "premise impossible" note moved to ST7-open, where it is still true (its wording is now an over-long comment line; format gate reported 0 changed per the report).
- M2 addressed. ST1 depth is `expect(depth, 2)` again; the header states `dirty == false` replaces the private savedState read.
- M3 addressed. DocumentSession.isDisposed; `_flow` finally guarded; `_write` returns true when `!mounted`.
  Own run, mutation: document_host.dart:96 guard removed -> DS8 red (`+0 -1`); reverted, `git diff --quiet` ok.
- M4 addressed. SET-1 moved as TES-1 into canvas/text_entry_settle_test.dart, the mutation named in its description;
  SET-2 stays in page_scale_field_test.dart.

## New problems
- None confirmed. Unverified, by reading: after `_write` returns true on `!mounted`, a caller that is `_mayDiscard`
  (save inside New/Open) goes on to read `_controller.dirty` and may call `newPlan`/`load` on the disposed controller.
  Torn down mid-flow only; I did not run it. Low severity.
- DS8 asserts `takeException` null only; it does not assert that the file was written. Acceptable.

Verdict: all addressed.
