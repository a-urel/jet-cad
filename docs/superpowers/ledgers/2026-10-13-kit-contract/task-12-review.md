# Task 12 review (spec + quality)

### Spec Compliance
- Spec compliant. One file created (results note), no code touched; commit fea46c30 holds only it. Note carries SHA (b069a3f99fec1c51..., matches rev-parse), quoted gate tails, test count (+225), mutation table, plan decisions, spec gaps.
- Cannot verify from diff: the quoted transcripts are the implementer's; cross-checked only against task-12-report.md (consistent: +225, +106, +1289 -2, +1450 ~1 -5, +20, 0 warnings).

### Strengths
- Claims stay within the evidence: no "all mutations red" statement; deferred minors (surviving mutations such as T6 `!rest.contains('.')`, T4 tolerance boundaries) are listed separately and faithfully match progress.md.
- Spot-checked 12 mutation rows (M-V11/V0g, M-W2, M-K4/K4b/K6, M-S2, M-H2, M-D10, M-F12a/b, M-F15, M-N7) against the task reports: IDs and red tests match. M-L1/M-L3 honestly flagged "by ID only".
- Pre-existing failures are named exactly (2 generate_document tests; 5 text-ladder rungs, canvas) with counts matching the report.

### Issues
#### Critical
none
#### Important
none
#### Minor
1. Note, section 3 (last paragraph): "Both old-package failures are pre-existing and environmental (macOS)". "(macOS)" is not in the ledger or any report (ledger says only "environmental", CI arbiter). Also the ledger verified only the hash test on clean main (1b4670b); Task 1's report says the goldens were "Not verified against a clean base". The controller's brief says goldens fail on clean main too, so acceptable, but drop "(macOS)" or say it is the controller's ruling.
2. Note, end of mutation section: "Task 3 and Task 1 reports quote [E] markers rather than the full red lines; the ledger records that". Ledger records Task 3 only; the Task 1 report quotes no [E] markers at all (it names red tests by ID). Fix to "Task 3" or "Tasks 1 and 3 name tests without quoting red lines".
3. Omission: Task 1's report records `query_allocation_test` failing once in a full jet_cad_2d run (flaky, passed alone); the note's jet_cad_2d gate shows a clean "exactly 2 failures" with no mention. Not a false claim, but the note's "exactly" is for this run only; one line would be exact.
4. Table header says every mutation "ran on a committed file ... reverted with git diff --quiet exit 0"; M-P1 used a new probe file (deleted) and not every report states the diff check. Soften to "reverted as the reports record".

### Assessment
**Task quality:** Approved
**Reasoning:** The note is faithful to the reports and ledger and makes no overclaim about mutations; the minors are wording precision (unsupported "macOS", Task 1 attribution, one omitted flaky run).
