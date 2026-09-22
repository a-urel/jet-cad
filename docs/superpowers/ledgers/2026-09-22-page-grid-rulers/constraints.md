# Global constraints binding every Plan 04 task (verbatim from the plan)

- The frame path allocates nothing per entity in steady state, and O(1) per flush. `query_allocation_test.dart` and `paint_allocation_test.dart` stay green unedited. The chrome painters are outside the vertices sink path; their per-frame work is O(lines) with lines bounded, and the grid's point list is a `sublistView` of a buffer grown once.
- Draw order is ascending handle value. Nothing here writes geometry.
- Geometric decisions use `Tolerance`; stored value comparisons are exact `==`. `PageComponent ==` and preset recognition are exact; pixel thresholds are plain comparisons.
- Screen coordinates only into `dart:ui` from the chrome painters (spec Invariant 5). No rebase, no absolute world coordinate.
- Never commit a rewrite of `analysis_options.yaml`. `git status --short` before every commit; `git checkout --` any `analysis_options.yaml` that `pub get` rewrote (yaml only — never a `.dart`).
- Never synthesize test output. Run the command, paste what it printed, including the exit code.
- Before firing a mutation, back the file up with `cp`, and restore from that copy. Never `git checkout --` a file to revert a mutation.
- Prefix every test command with `CI=true`.
- Commit trailer, exactly: `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Check with `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.
- Code, comments and commit messages in English.
- `apps/dev_harness_2d` is untouched. 82 tests at the branch point.
- `DraftCanvas`, `DraftPainter`, `CameraGestureDetector`, `InteractionLayer`, `SelectionOverlayPainter` are untouched. `TileCache` changes by exactly the D13 skip.
- Every fixture is off the identity. The standard fixture: page origin (7350, −1230), A4 landscape, 1:50, metres; camera `cameraAt(0.137, const Offset(-611.5, 412.25))`. Never scale 1.0, never a page at (0, 0), never a square sheet.
- Every task ends green on its package's gate line (`CI=true dart test`/`flutter test`, analyze, `dart format --output=none --set-exit-if-changed .`); the render layer's `flutter test` exits 1 on the five pre-existing `text_ladder_golden_test.dart` failures and on nothing else.
- Implementers never dispatch subagents and never run mutation sweeps that the brief does not ask for (Plan 02 Ruling P-4).
