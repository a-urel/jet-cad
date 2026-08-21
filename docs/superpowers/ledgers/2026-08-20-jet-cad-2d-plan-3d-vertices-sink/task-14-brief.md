### Task 14: The mutation log

The spike ran 33 mutants against the sink and killed 32, with one not
applicable. Phase A added nine more. Every one gets run, and every survivor
gets a test or a recorded reason.

**Files:**
- Create: `docs/superpowers/notes/plan-3d-mutation-log.md`

- [ ] **Step 1: Write the runner**

A backup-based script, in the scratchpad and not committed. **Never
`git checkout` a file to revert a mutation** — Plan 3c's Task 10 lost a full
task's work that way. Copy the file aside before the edit and restore it in a
`finally`, whatever happens in between.

Model it on `mutate13.py` from Plan 3c's ledger: apply, run the narrowest suite
that should catch it, and if that stays green widen to both full suites so a
survivor is a measured survivor rather than an unlooked-for one.

- [ ] **Step 2: Run every mutant in the design document's table**

J1 through J9, B1, B2, A1, V1, P1, and the spike's 33. For each, record: the
mutation as a diff, the test that went red, and the assertion message.

- [ ] **Step 3: Close every survivor**

A survivor is either a missing test — write it, watch the mutant die — or a
mutation the frame path cannot reach, which is recorded as **not applicable**
with the reason and the file:line that makes it unreachable. Those are the only
two outcomes. "Accepted risk" is not one.

- [ ] **Step 4: Write the log**

One section per mutant: id, the mutation, the killer, the assertion. A table at
the top with the tally. Model it on
`docs/superpowers/notes/plan-3c-mutation-log.md`.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/notes/plan-3d-mutation-log.md
git commit -m "docs: Plan 3d mutation log"
```

---

