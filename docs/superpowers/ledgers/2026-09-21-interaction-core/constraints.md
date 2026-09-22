## Global Constraints

Copied from `CLAUDE.md` and the spec; this plan's additions marked.

- **The frame path allocates nothing per entity in steady state, and O(1)
  per flush.** `query_allocation_test.dart` and `paint_allocation_test.dart`
  stay green unedited. **This plan adds:** `SelectionOverlay.paint`
  allocates nothing per key (its two `Paint`s and its transform matrix are
  fields; paths are rebuilt only when the rebase origin or the selection
  changes); the hover pick allocates nothing per entity.
- **Draw order is ascending handle value.** Both band walks sort before
  reporting (M-02z). Nothing here writes to the document except through
  `RemoveEntityCommand` and `RemoveNodeCommand`.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.** Nothing in this plan introduces a tolerance comparison; the pick
  radius and the band are query parameters. `scale == _gestureZoom`-style
  stored comparisons stay exact.
- **No absolute world coordinate reaches `dart:ui`.** The overlay builds its
  `ui.Path` in the space rebased by `rebaseOriginFor` (spec D9, M-02v).
- **Never commit a rewrite of `analysis_options.yaml`** (Ruling 01-1).
  `git status --short` before every commit; `git checkout --` any
  `analysis_options.yaml` that `pub get` rewrote.
- **Never synthesize test output.** Run the command, paste what it printed,
  including the exit code.
- **Before firing a mutation, back the file up with `cp`, and restore from
  that copy.** Never `git checkout --` a file to revert a mutation.
- **Prefix every test command with `CI=true`.**
- Code, comments and commit messages in English.
- **`apps/dev_harness_2d` is untouched.** 82 tests at the branch point.
- **`DraftCanvas`, `DraftPainter`, `CameraGestureDetector`, `TileCache` are
  untouched.** None of their files is in this plan's diff.
- **Every fixture is off the identity.** Cameras via `fitOffOrigin` or a
  scale ≠ 1 with a non-zero translation; geometry off the origin; every
  instance at the reference placement `(300, −200)`, 30°, ×1.5 or another
  placement with all three non-trivial; every band fixture has a straddling
  entity; the overlay precision fixture at `kDefaultOriginX`.
- **Overlay tests never rebuild the widget between a controller mutation
  and the assertion** — a repaint may only come from the listenable.
- **Every task ends green.** The eleven gate commands (spec, criterion 12):

  ```sh
  cd packages/jet_cad_2d         && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/floor_planner          && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --debug && flutter build web
  ```

  Tasks 1–2 run the `jet_cad_2d` line. Tasks 3–9 run the
  `jet_cad_2d_flutter` line (its `flutter test` exits 1 on the five
  pre-existing `text_ladder_golden_test.dart` failures and on nothing else —
  the 01 baseline ruling; paste the summary line and check the failing names
  are those five). Task 10 adds the `floor_planner` line. Tasks 11 and 12
  run all four.

