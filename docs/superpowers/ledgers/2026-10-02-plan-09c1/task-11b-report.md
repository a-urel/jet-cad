# Task 11b report — the results of record (plan 09c-1)

Status: **done**, committed `c1ea23c` `docs: plan 09c-1 results` (parent `8f5f601`), both trailers, not pushed.
Staged by explicit path: 4 files, +680 −4. `packages/jet_cad/analysis_options.yaml` is still modified by pub get and was not staged.

## Files
- `docs/superpowers/notes/2026-10-02-plan-09c1-results.md` (new, 586 lines), in the 09b note's form:
  - header: branch, spec rev 4 approval, plan, ledger link (resolves after the archive commit);
  - what 09c-1 delivers;
  - the task table, with the b-rounds and the cherry-picks `7b26eb7`, `b3284f1`, `90f0d97`;
  - "What the execution found": C-0..C-5, R-C1-1..R-C11a-3, N-2/N-3, the Task 4 differential's inherited findings;
  - gates of record (my runs, below);
  - mutants per task (P-8, compiled from the reports and reviews), the survivors and why accepted;
  - Found, not fixed;
  - Owed to 09c-2;
  - The human's look: the spec's 09c-1 list plus the hourglass glyph (R-C7-1), the 2400 wardrobe's handles (Task 3 review note 4) and the hob's 520 mm depth in a run. Nothing is marked done.
  - The final whole-branch review is described as still to come; its sample is left for that review to record.
- `docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md`:
  - the Status line now says 09c-1 executed on `plan-09c/wall-attach` (not merged), amended at execution, 09c-2 unwritten;
  - a new "## Amended at execution (Plan 09c-1)" section covering D13 (R-C10-1), D6/D8 marker (C-5, R-C7-1), D6 keys (R-C7-2..4), D11 (R-C1-1..4), D2 (R-C2-1/2, R-C3-1..3, 3b's duplicate tag), D9 (the pre-09c fixture, 3b), D3 (R-C4-1..4, R-C6-4), D4 (R-C6-1..6), D5 (R-C5-1..3), D10 (R-C9-1/2), D12 (R-C8-1, R-C8b-1).
- `roadmap/09-symbol-library.md`, Status paragraph: the "Sub-project 09 is complete" sentence is replaced by a 09c sentence. It records spec rev 4 approved 2026-10-02, 09c-1 executed on `plan-09c/wall-attach` (plan and results links), merge pending the human's word, look owed, and 09c-2 unwritten.
- `roadmap/00-README.md`: the 09 row gains the 09c spec, the 09c-1 plan and the results, recorded as "09c-1 executed on `plan-09c/wall-attach`; merge pending the human's word; macOS and web look OWED. 09c-2 unwritten". The status sentence below the table gets the same addition. This mirrors how `47ccd78` recorded 09b before its merge. No merge is claimed.

## Gates (run on `8f5f601` before the commit, sequentially, one script, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

Logs are in `scratchpad/task11b/*.log`, with a summary in `gates_summary.log`.

| Gate | Real output |
|---|---|
| engine `dart test` | `00:22 +1237 -2: Some tests failed.` The 2 failures are `generate_document_test.dart` ("the default document is the one Plan 2 measured, byte for byte", "both text fractions default to zero and change nothing"). |
| engine analyze / format | `No issues found!` / `Formatted 168 files (0 changed)` |
| render `flutter test` | `01:11 +1187 ~1 -7: Some tests failed.` The 7 `[E]` are text_ladder rungs 1–5 and text_lod_ladder rungs 1–2 (`RenderBackend.canvas`). The skip is the `rig`-tagged test. |
| render analyze / format | `No issues found! (ran in 2.1s)` / `Formatted 208 files (0 changed)` |
| app `flutter test` | `04:58 +1169: All tests passed!` |
| app analyze / format | `No issues found! (ran in 2.1s)` / `Formatted 184 files (0 changed)` |
| app `flutter build web --release` | `✓ Built build/web` |
| `apps/dev_harness_2d` analyze | `No issues found! (ran in 1.3s)` |

These match the expected engine 1,237 + 2, render 1,187 + 1 skip + 7, and app 1,169. The app count's derivation is in the note: 993 plus each task's added tests.

## Other checks
- `git diff 904970d HEAD --stat -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants`: empty.
- No `analysis_options.yaml` in `git diff 904970d HEAD --stat`.
- `git diff 904970d HEAD -- packages/jet_cad_2d_flutter` and `-- apps/dev_harness_2d`: both empty.
- Engine `lib/` unchanged since `a5a6b35`. App `lib/` unchanged since `2a1f8c2`.
- Purity:
  - An import/export grep for `package:flutter|dart:ui` in `wall_attach.dart` and `symbol_box.dart` finds nothing (exit 1). The only text hits are the comments stating the rule.
  - A transitive-closure script (`scratchpad/task11b/closure.py`) gives 20 files for `wall_attach.dart` and 17 for `symbol_box.dart`, with no Flutter or `dart:ui` import. These match the counts in the Task 6 and Task 4 reports.

## Notes for the controller
- I did not touch the 09 spec (`2026-09-30`) or the 09b spec. 09c amends their D14 limits and R-B6-3 / R-B9-2. The brief did not ask for cross-notes there; 09b's results commit had added one to the 09 spec.
- The ledger `progress.md` was not edited. Row 11 still says "11b (docs) in progress".
- The note's "final whole-branch review's sample" is a placeholder sentence ("to be recorded by that review").
