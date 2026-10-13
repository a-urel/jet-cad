# Global constraints (verbatim from the plan) and project rules


- Versions: `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_floor_plan` at `0.7.2`; every live-line dependency on them `^0.7.2` (D10, from Task 7 on; `^0.7.1` before).
- Funding, verbatim, in the three published pubspecs: `https://github.com/sponsors/a-urel`, `https://buymeacoffee.com/yazemo` (D3). `.github/FUNDING.yml`: `github: a-urel`, `buy_me_a_coffee: yazemo`.
- The engine's README has **no image** (spec Decision 6).
- Screenshots: renderer R1–R5, planner P1–P6, files and order as spec D5; each PNG ≤ 1 MB, each package's total ≤ 4 MB, descriptions 10–160 characters, ≤ 10 entries (D6, D7).
- README image URLs: `https://raw.githubusercontent.com/a-urel/jet-cad/<package>-v0.7.2/packages/<package>/doc/screenshots/<file>` — absolute, tag-pinned (D6).
- Scenes use the barrels; `package:jet_cad_floor_plan/editor.dart` only for `startupPlan`, `symbolThumbnailDocument`, `searchSymbols`, `SymbolWords`, `symbolIdOf` (spec D4, A2).
- The generator never compares pixels (D4). The standing failure and skip lists do not change.
- Never run `dart pub publish` without `--dry-run`. Never push, tag or merge: the human's word only.
- **Never commit `analysis_options.yaml`.** Check `git status --short` after every pub operation.
- Never synthesize test output; quote what commands print. Never `git checkout` a file to revert a mutation: copy it aside, restore from the copy, `cmp`.
- Code, comments and commit messages in English; every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Every task ends green: the CLAUDE.md gate of each package it touches; for `tool/ci`: `cd tool/ci && dart test`, plus `dart run tool/ci/check_guide.dart` from the root.
- Worktree-guarded sessions refuse bash loops and `$VAR` pipelines: run commands one by one.


## Project rules (CLAUDE.md)

## Non-negotiables

- **The frame path allocates nothing per entity in steady state, and O(1) per flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` measure it.
- **Draw order is ascending handle value**, stable across undo, save, load and purge.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them in this workspace.
- **Never synthesize test output.** Reviewers verify claims independently; a fabricated transcript invalidates the task.
- Code, comments and commit messages in English.

## Every task ends green

```sh
cd packages/jet_cad_2d       && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_gpu     && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

## Testing bar

Defects in this codebase surface through **mutation testing and differential
testing**, not through reading. The dominant failure mode is the **degenerate
fixture** — a test that passes because every fixture sits at the identity
transform, the origin, or a default attribute. A new test is only worth landing
if a named mutation makes it go red.
