# Task 8 brief — app: replacing and closing a dirty document (plan 12a, spec D10, D11, D12 Swift)

You are the implementer for **Task 8** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there.

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-30-document-lifecycle.md` (the header,
"Rulings made here" P-2, "Global constraints", "Gates", and **Task 8**, P-3–P-6);
the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
**whole** (D10, D11, D12, D14 in full, with S-14, S-17, S-18, T-7, T-8,
T-13's `@objc`, U-7; the Testing entries this task owns; M-12a-2's exit
half, 10, 25, 26). Then the ledger's `t5-report.md`, `t5-review.md` (m-3:
**re-fire R6**, the missing `identical(document, encoded.document)` guard
before `markSaved`, in your nested-flow tests), `t5b-review.md` (n-2),
`t6-report.md`, `t7-report.md` (the settle as landed), and
`apps/floor_planner/lib/document_host.dart`, `main.dart`,
`macos/Runner/MainFlutterWindow.swift`, `AppDelegate.swift`.

Do exactly Task 8's checklist. Additions from reviews: (n-2) a replace
test from a **titled, dirty** document replaced after Don't Save (New and
Open sample) must end untitled with no location — fire the Task 5
review's R3 (`fileName ?? _fileName` in `replace`) against it; (m-3)
re-fire R6 in the nested-flow test (a swap during a held write). The Swift
edit cannot be built here: keep it minimal, `@objc`, commented with spec
D11, and say so. The web `beforeunload` guard behind a conditional
import; the web build must compile it. Earlier tasks are below you; other
agents review in separate worktrees — do not touch them. **Also run
`CI=true flutter build web --release`.**

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t8-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
Never synthesize output. Never commit `analysis_options.yaml`. Commit; do
NOT push.

Run all three packages' gates (the plan's Gates block); engine +1106 -2 and render
+974 ~1 -7 must be unchanged; app at the branch HEAD's count + your new
tests (every existing test stays green).

Commit message from the plan, ending with the two trailers. Write
`.superpowers/sdd/plan-12a/t8-report.md` and return it: hash; the API as
landed; every test with what it pins; every mutant with its red test and
line; gates with summaries and exit codes; deviations; anything found
outside scope (reported, not fixed).
