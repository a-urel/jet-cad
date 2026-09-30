# Task 4 brief — app: DocumentFiles (plan 12a, spec D9, D12 entitlements)

You are the implementer for **Task 4** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there.

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-30-document-lifecycle.md` (the header,
"Rulings made here" P-2, "Global constraints", "Gates", and **Task 4**);
the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
D9 (with S-15, S-16, T-12), D12 and R-6. Then the published sources of
`file_selector` 1.1.0 / `file_selector_macos` / `file_selector_web` 0.9.5
(fetch them into your scratch prefix with curl from pub.dev if the pub
cache lacks them) for the exact API.

Do exactly Task 4's checklist. App only (lib, test/support, pubspec,
macos entitlements). Earlier tasks are below you; other agents review in
separate worktrees — do not touch them. **Also run `CI=true flutter build
web --release` in the app** and report it. The real macOS/web
implementations get no widget test (the plan says why); make sure
`flutter analyze` sees both files (conditional imports) and the web build
compiles the web one.

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t4-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
Never synthesize output. Never commit `analysis_options.yaml`. Commit; do
NOT push.

Run all three packages' gates (the plan's Gates block); engine +1106 -2 and render
+974 ~1 -7 must be unchanged; app 520 + your new tests.

Commit message from the plan, ending with the two trailers. Write
`.superpowers/sdd/plan-12a/t4-report.md` and return it: hash; the API as
landed; every test with what it pins; every mutant with its red test and
line; gates with summaries and exit codes; deviations; anything found
outside scope (reported, not fixed).
