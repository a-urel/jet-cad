# Context every implementer of this plan needs (the controller's notes)

- Worktree: /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/kit-architecture, branch feat/kit-architecture. Never cd outside it. Never push, merge, tag or publish (`dart pub publish --dry-run` only).
- You never dispatch subagents.
- Global constraints and the file structure bind every task: global-constraints.md in this directory.
- Spec, for intent where the brief is silent: docs/superpowers/specs/2026-10-13-kit-contract-design.md (read its "Amendments while planning" section); umbrella docs/superpowers/specs/2026-10-13-kit-architecture-design.md.
- Commit trailer, exactly: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (the human's rule; not your own model name).
- Stage files by explicit path only. Never stage any analysis_options.yaml (`flutter pub get` rewrites three existing ones; run `git status --short` after pub operations and leave them).
- Run the Commit step BEFORE the Mutation check step. Mutate committed files only; revert each with `git checkout -- <file>` and confirm `git diff --quiet -- <file>` exits 0. Never restore from /tmp copies.
- The worktree guard may refuse bash loops or `$VAR` pipelines: run commands one by one.
- Never synthesize test output: quote what commands print.
- Known, not yours: locally `packages/jet_cad_2d` generate_document_test (2 hash tests) and `packages/jet_cad_2d_flutter` text-ladder goldens fail on the clean main checkout too (macOS environment). If a CLAUDE.md gate of those packages shows exactly those failures, report them as pre-existing; anything else failing there is yours to investigate.
- Earlier tasks are committed on the branch; read their files for the interfaces your brief's "Consumes" block names.
