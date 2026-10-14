# Context every implementer of this plan needs (the controller's notes)

- Worktree: /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a, branch feat/plan-library-2a. Never cd outside it. Never push, merge, tag or publish (`dart pub publish --dry-run` only).
- You never dispatch subagents.
- Global constraints, the Review Focus, the file structure, the Shared interfaces and the planning rulings bind every task: global-constraints.md in this directory. Read it before your brief.
- Spec, for intent where the brief is silent: docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md (revision 3 plus the P3 separator correction); umbrella docs/superpowers/specs/2026-10-13-kit-architecture-design.md; contract docs/superpowers/specs/2026-10-13-kit-contract-design.md.
- The plan's code was written by planners; only Tasks 3-5 were compiled before. Your job includes making it compile and pass. When the brief's code is wrong (a name, a signature, an import), fix it minimally, keep the brief's intent, tests and named mutations, and list every deviation in your report under "Deviations from the brief" with the reason. If the fix would change a Shared interface or another task's contract, stop: report NEEDS_CONTEXT.
- Commit trailer, exactly: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (the human's rule; not your own model name).
- Stage files by explicit path only. Never stage an existing analysis_options.yaml (`flutter pub get` rewrites three; run `git status --short` after pub operations and leave them). The one exception is Task 6's new packages/jet_cad_2d_plan/analysis_options.yaml, committed once.
- Run the Commit step BEFORE the Mutation step. Mutate committed files only; revert each with `git checkout -- <file>` and confirm `git diff --quiet -- <file>` exits 0. Never restore from /tmp copies.
- Run the format gate locally every time (`dart format .` then `dart format --output=none --set-exit-if-changed .`).
- The worktree guard may refuse bash loops or `$VAR` pipelines: run commands one by one.
- Never synthesize test output: quote what commands print.
- Known, not yours: locally `packages/jet_cad_2d` generate_document_test (2 hash tests) and `packages/jet_cad_2d_flutter` text-ladder goldens fail on the clean main checkout too (macOS environment). If a gate of those packages shows exactly those failures, report them as pre-existing; anything else failing there is yours.
- Earlier tasks are committed on the branch; read their files for the interfaces your brief's "Consumes" block names. The ledger at .superpowers/sdd/2026-10-14-plan-library-2a/progress.md records rulings that bind later tasks.
