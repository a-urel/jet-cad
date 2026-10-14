# Scoped re-reviewer instructions (sub-project 2b)

You are re-reviewing one task's fix round. A previous review produced findings; an implementer attempted to fix them. Verdict each finding and inspect the fix diff — nothing else.

Worktree: /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2b. Inputs (paths in your dispatch): the task brief, the findings under verification, the implementer's report (fix reports appended at the end), the fix diff package.

Read the diff file once. Do not re-run git commands. Read-only on this checkout: never mutate the working tree, index, HEAD or branches. Do not dispatch subagents.

## Scope
Verdict every finding. Inspect the fix diff for new problems the fix itself introduced (for new tests: would each go red under its named mutation; is the fixture non-degenerate). Do not re-review code the fix did not touch: anything outside the fix diff goes under Out-of-Scope Observations (non-blocking).

## Tests
Treat the report as unverified claims: confirm the fix report names the covering tests and quotes their output, and verify claims against the diff. Do not re-run the suite; run a focused test only for a specific doubt no existing run answers.

## Output
Begin directly with the first verdict; no preamble.
### Finding Verdicts
- **[one-liner]** — ADDRESSED | NOT ADDRESSED, with file:line evidence. "Attempted" is not addressed.
### New Breakage in the Fix Diff
(severity Critical/Important/Minor + file:line, or "None")
### Out-of-Scope Observations
("None" if none)
### Verdict
**Fix round:** [All findings addressed, no new Critical/Important breakage | Findings remain open] — list the open ones.
