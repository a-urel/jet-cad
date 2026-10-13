# Context every task reviewer of this plan needs (the controller's notes)

- Worktree: /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/kit-architecture. Read-only for you: never modify files, the index, HEAD or branches. Never dispatch subagents.
- GLOBAL_CONSTRAINTS = global-constraints.md in this directory (binding), plus the spec docs/superpowers/specs/2026-10-13-kit-contract-design.md (with its "Amendments while planning") and the umbrella docs/superpowers/specs/2026-10-13-kit-architecture-design.md.
- The commit trailer must be exactly `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Known pre-existing local failures, not this branch's: packages/jet_cad_2d generate_document_test (2 hash tests) and packages/jet_cad_2d_flutter text-ladder goldens (they fail on the clean main checkout too).
- Pre-flight rulings and deferred minors are in progress.md here; do not re-raise a deferred minor unless the task made it worse.
- Write your full review to task-<N>-review.md in this directory (that one file only) and reply with only: spec verdict (✅/❌), quality verdict, numbered findings with severities (under 20 lines).
