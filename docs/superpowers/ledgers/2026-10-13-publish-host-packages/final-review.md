# Final whole-branch review: feat/publish-host-packages, main d41e5f6..c660947

Reviewer: an Opus subagent (no Codex, R-3), read-only, in passes. The controller transcribed this record from the reviewer's hand-back.

## Measured independently

The reviewer measured these in a throwaway worktree at c660947, which it then removed.

- **Dry runs (`dart pub publish --dry-run`):**
  - `jet_cad_2d_flutter`: exit 0, 226 KB, 0 warnings.
  - `jet_cad_floor_plan`: exit 0, 462 KB, 0 warnings.
- **Archive listings:**
  - The renderer's has no `test/`, `build/` or `shaders/`.
  - The planner's has `furniture.jetlib`, `Roboto-Regular.ttf` and `Roboto_LICENSE.txt`, and no `test/`, `tool/` or `build/`.
  - `git status` stayed clean after `flutter pub get`.
- **README snippets:** every snippet and name in both READMEs analysed against its barrel. Result: "No issues found!".
- **`names.dart`:** after the (then) sed rewrite it analyses clean against `jet_cad_floor_plan.dart`.
- **API audit (analyzer-based) over the host barrels:**
  - Renderer: none.
  - Planner: `SymbolLibraryState` and `TableNumberProblem`, plus `ExportChoice` and `ExportFontCache`, which are reached only through `@internal` members. This confirms the note's D4 audit.
- **Lib changes since v0.7.0:** in both packages, the only non-comment change is `editor.dart`'s `hide readBundledLibrary`.
- **The engine at c660947:** differs from 1dc167d only in its README.
- **Tests:**
  - `tool/ci` `dart test`: +77, all passed.
  - `check_guide`: 56 blocks.
  - Both example tests pass.
- **Repository:** `a-urel/jet-cad` is PUBLIC.

## Verdict

**With fixes.** 0 Critical.

## Important

1. STATUS Resume, D7 step: as written, it cannot work. The restaurant files are absent once the overrides are removed. Fixed as F1.
2. R-10: the reviewer recommends exporting the `SymbolLibraryState` family and `TableNumberProblem` from `jet_cad_floor_plan.dart` before 0.7.1. The human decides (R-11).

## Minor

1. Publish the engine before merging this branch, so the README matches the tag. Use "the commit main points at after the merge". Fixed as F2.
2. ci.yml probe job name is stale. Fixed as F3.
3. `host_probe.sh` header's full-sha rationale is stale. Fixed as F4.
4. The guide's recipe lacks its imports, and the import rewrite is unnecessary. Fixed as F5 (R-12).
5. The guide's schema-10 bullet lacks 0.7.1. Fixed as F8.
6. Results note: the `package_root` path, R-10 not listed, and the archive still owed. Fixed as F9; the archive is the controller's last commit.
7. Root CHANGELOG says "are published" before the publish. Left (R-13).
8. The planner's example test calls `symbols.load` itself. Left (R-13).

## Deferred-minor triage

**Fix before publish:**
- The planner README's `symbol_sources.dart` sentence (T3). Done as F6.
- The `host_probe.sh` header (T6). Done as F4.

**Leave**, every other ledger minor:
- T1: braces; DL1 flow-style.
- T2: the comment naming test files; the `size` fragment; the planner name.
- T3: M-FX1's entries assertion; the `mySymbolSource` placeholder; the 88-column line.
- T5: RangeError; the success line; `--ref ''`.
- T6: bare `dart analyze`.

## Declined to judge

- pana scores (R-4).
- Whether pub.dev's server accepts `resolution: workspace`; the local dry run accepts it, and the engine set the precedent.
- Linux CI results, because the branch is not pushed.
- Dry run on main after a version exists.
- The released probes' reliance on the restaurant override (F-11).
- A v0.7.0 old probe.
- The dormant `packages/jet_cad` `publish_to`.
- The full gate suites, for which the reviewer relied on the task reports.
