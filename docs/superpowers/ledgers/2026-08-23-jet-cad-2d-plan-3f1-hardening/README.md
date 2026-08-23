# Plan 3f.1 ledger — hardening before the picture cache

Archived on 2026-08-23, on `main`, **before** the working directory
`.superpowers/sdd/2026-08-23-jet-cad-2d-plan-3f1-hardening/` was removed. That
ordering is deliberate: Plan 3e recorded that archiving after deleting the
workspace loses the record entirely.

- **Spec (binding authority):**
  [docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md](../../specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md)
- **Plan:**
  [docs/superpowers/plans/2026-08-23-jet-cad-2d-plan-3f1-hardening.md](../../plans/2026-08-23-jet-cad-2d-plan-3f1-hardening.md)
- **Results of record:**
  [docs/superpowers/notes/2026-08-23-plan-3f1-results.md](../../notes/2026-08-23-plan-3f1-results.md)
- **Mutation log:**
  [docs/superpowers/notes/plan-3f1-mutation-log.md](../../notes/plan-3f1-mutation-log.md)

## What is here

`progress.md` is the controller's ledger: the pre-flight conflict scan, every
ruling with what it would cost if wrong, every deferred minor, and the
corrections made to the plan's own premises while it ran. `task-N-brief.md` is
what each implementer was given; `task-N-report.md` is what it returned, with
every mutation transcript verbatim. `final-fix-report.md` covers the single fix
wave that followed the whole-branch review. The `review-*.diff` files are the
packages each reviewer read.

## Commit range

`c078677..846ac38` — eight tasks in seven commits plus the final fix wave.
**Task 7 produced no commit**: its probe came back red, a pre-committed stop
clause fired, and the whole section was reverted. That is the plan working as
designed, and its finding is the most portable thing here.

## The one thing worth reading if you read nothing else

The results note's section on this plan's own recurring failure mode. Four
times a stated cause was stronger than the evidence behind it — twice in
documents the controller wrote, once in a task report, once inside the
mutation log that names the failure mode. Every one was caught by someone
**running** something rather than reading it: three rounds of external spec
review read past the first, and the fourth was found by a reviewer who stopped
inspecting an API and looked at the running process instead.
