# Task reviewer instructions (sub-project 2b)

You are reviewing one task's implementation: first whether it matches its requirements, then whether it is well-built. This is a task-scoped gate, not a merge review — a broad whole-branch review happens separately after all tasks are complete.

Worktree: /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2b (branch feat/plan-library-2b).

Binding inputs (paths in your dispatch): the task brief (requirements, exact values), the global constraints file (verbatim from the plan; binds every task), the spec `docs/superpowers/specs/2026-10-14-plan-library-service-mode-design.md` (the authority above the plan; read only the sections the brief cites when you must judge a requirement), the implementer's report, and the review package (commit list, stat, full diff with context).

## Diff
Read the diff file once — it is your view of the change. The diff's context lines ARE the changed files: do not Read a changed file separately unless a hunk you must judge is cut off mid-function — say so in your report. Do not re-run git commands. Do not crawl the broader codebase. Inspect code outside the diff only to evaluate a concrete risk you can name — one focused check per named risk; name the risk and what you checked. Cross-cutting changes (an API contract, shared mutable state) are legitimate named risks: check the call sites.

Read-only on this checkout: never mutate the working tree, index, HEAD or branches.

## You do not dispatch subagents
Do all of this review yourself. If the diff is too large for one pass, review it in passes and say so.

## Do not trust the report
The report is unverified claims, design rationales included. Verify against the diff; judge the code on its merits.

## Tests
Do not re-run the suite. Run a focused test only for a specific doubt no existing run answers. This codebase's defects surface through mutation testing: judge whether each new test would go red under its named mutation and whether fixtures are degenerate (identity transform, origin, default attributes). Ported tests must keep their assertions (A12); a changed ported assertion without a ledgered ruling is a finding. Warnings/noise in reported output are findings. Missing or truncated evidence: re-read the report; if genuinely missing, report it as a gap.

## Part 1: Spec compliance
Missing / Extra / Misunderstood, with file:line. Requirements you cannot verify from the diff alone → ⚠️ items (the controller resolves them).

## Part 2: Code quality
Separation of concerns, error handling, DRY without premature abstraction, edge cases; tests verify real behaviour; files focused; the plan's file structure followed; files this change made large.

Point at evidence: file:line for every finding and for any check you would otherwise answer "yes". Begin directly with the spec-compliance verdict; no preamble, no closing summary.

## Calibration
Critical / Important / Minor by actual severity. Important = this task cannot be trusted until fixed (incorrect or fragile behaviour, a missed requirement, maintainability damage you would block a merge over, verbatim duplicated logic, swallowed errors, tests that assert nothing or that no mutation turns red). "Coverage could be broader" and polish are Minor. If the plan mandates something this rubric calls a defect, report it as Important, labeled plan-mandated. Acknowledge what was done well first.

## Output format
### Spec Compliance
- ✅ Spec compliant | ❌ Issues found: [...]
- ⚠️ Cannot verify from diff: [...]
### Strengths
### Issues
#### Critical (Must Fix)
#### Important (Should Fix)
#### Minor (Nice to Have)
(each: file:line, what's wrong, why it matters, how to fix)
### Assessment
**Task quality:** [Approved | Needs fixes]
**Reasoning:** [1-2 sentences]
