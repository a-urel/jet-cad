### Task 3: docs, results and the record

**Files:**
- Modify: `CHANGELOG.md` (**Unreleased**)
- Create: `docs/superpowers/notes/2026-10-10-node-components-results.md`
- Modify: `STATUS.md` (In flight)
- Modify: the spec's status line (implemented, the branch)

- [ ] **Step 1: CHANGELOG, Unreleased** (replacing *"Nothing yet."*):

```markdown
- **Deleting a node removes everything attached to it.** A deleted
  group's, nested group's or instance's components — including data a
  newer release wrote — now go with it, as a table's host data already
  did in 0.4.0; Undo brings them back exactly. Plans are unchanged
  (schema 9): orphaned entries an older release left in a plan load and
  save as they are.
- **For code that builds commands by hand:** `RemoveNodeCommand` now
  declares `{structure, components}`, so a permission profile that denies
  components refuses a node delete (and the undo of a node add). A
  re-parent built as `RemoveNodeCommand` then `AddNodeCommand` must pass
  `components: doc.components.snapshotOf(handle)` to the re-add to keep
  the node's components; without it the node comes back empty.
```

- [ ] **Step 2: the results note.** Record: the spec and plan; each
  task's commits; the gate summaries; every mutant M-1 to M-17 with its
  killing test and the red line; the tests re-pinned and why; what
  discharges the host embedding spec's F-14, Slice 2 orphaning note and
  **O-8**, and that its line on walls and rooms orphaning
  (`host-embedding-api-design.md:587-589`) overstated (spec F-8); the
  out-of-scope items O-1 to O-7 unchanged.

- [ ] **Step 3: STATUS.** The In flight entry names the plan, the
  branch, the results note and the next step (the human's look, then
  the merge on their word; the ledger archived onto the branch before the
  merge).

- [ ] **Step 4: commit.**

```bash
git add CHANGELOG.md STATUS.md docs/superpowers
git commit -m "docs: node-components results, CHANGELOG and STATUS"
```

## After the tasks

A whole-branch review by a fresh reviewer, its fixes, then the ledger
archived to `docs/superpowers/ledgers/2026-10-09-node-components-on-delete/`
as the branch's last commit. Merge into `main` and push only on the
human's word.
