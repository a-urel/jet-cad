## Global Constraints

These are copied from `CLAUDE.md` and the spec.

- **Pure-Dart engine.** Nothing under `packages/jet_cad_2d` imports Flutter
  or `dart:ui`.
- **`unused_import` and `unused_element` are errors in
  `jet_cad_2d_flutter`** and in the app.
- **The frame path allocates nothing new.** `query_allocation_test.dart`
  and `paint_allocation_test.dart` stay green and **unedited**.
  Regeneration runs on edits only.
- **Draw order is ascending handle value.** A child keeps its handle across
  regeneration.
- **Geometric decisions use `Tolerance`; stored-value comparisons are exact
  `==`.**
  - The decisions: the inside test, the minimum piece length, and the reach
    overlap.
  - The stored values: the planner's payload comparison, and component
    equality.
- **World is root space.** Never read or write the root's transform.
- **Never commit `analysis_options.yaml`.** Run `git status --short` before
  every commit.
- **Never `git checkout --` a `.dart` file.** Back it up with `cp`, restore
  from that copy, and `diff` to prove the restore.
- **Never synthesize test output.** Paste what ran, with the summary line
  and the exit code.
- **Prefix every test command with `CI=true`.**
- **Code, comments and commit messages in English.**
- **Every commit ends with the trailer, exactly:** `Co-Authored-By: Claude
  Opus 5.5 <noreply@anthropic.com>`.
- **Format before the gate:** `dart format <files you touched>`.
- **Every fixture is off the identity.**
  - Engine objects sit at `atA = translation(7010, 3020) · rotation(π/6)`
    and relative to it. They are never at the origin, never at 0° or 90°,
    and never at scale 1 except where the group transform is rigid by
    design.
  - **Every relational fixture is rotated** (spec, Testing).
  - Relational tests assert the clip counts, **A 5 and B 3**, so a fixture
    that stops overlapping goes red.
- **Every task ends green.** The gate lines:

  ```sh
  cd packages/jet_cad_2d         && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd packages/jet_cad_2d_flutter && CI=true flutter test ; flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/floor_planner          && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --release && flutter build web --release
  ```

  - **The standing exception:** the render layer exits 1 on the five
    `text_ladder_golden_test.dart` failures and on nothing else.
  - **Which lines each task runs:**
    - Tasks 1–4: the engine line, plus the render line, because the engine
      barrel grows.
    - Task 5: the render line.
    - Tasks 6–8: the app line as well.
    - Tasks 10–11: all four.
  - **Branch-point counts** at `6adf03d`: engine **911**; render layer
    **923** + 1 skip + the five goldens; harness **82**; app **46**.

