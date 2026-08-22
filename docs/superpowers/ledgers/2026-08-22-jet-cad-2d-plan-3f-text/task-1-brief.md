## Task 1: STATUS.md renumbering, 3f to 3g

**Files:**
- Modify: `STATUS.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing in code. It clears a naming collision — every later task writes "3f" meaning *this* plan, and `STATUS.md` currently uses "3f" for the picture cache.

**Why this is not `sed`.** `STATUS.md` holds fourteen occurrences of `3f`. Three of them are prose *about the previous renumbering* and rewriting them destroys the history that explains why the numbers moved. One more splits rather than renumbers.

- [ ] **Step 1: List the fourteen and classify each**

Run:

```bash
grep -n "3f" STATUS.md
```

Expected: fourteen lines, at `:270`, `:365`, `:371`, `:436`, `:622`, `:633`, `:635`, `:692`, `:697`, `:700`, `:743`, `:748`, `:752`, `:754`.

Write the classification into the task report as a table — line, quoted text, and one of `renumber` / `prose, leave` / `split`. The three at `:622`, `:633` and `:635` are `prose, leave`: they read "fills is 3e and the picture cache is 3f" and "every `3d`/`3e`/`3f` above was swept", which are statements about what happened when the vertices sink took the 3d slot. `:436` is `split`: "Whole-drawing thrash → the picture cache's text LOD (Plan 3f)" names an item this plan takes, so it becomes "Plan 3f" meaning text LOD, while the picture cache around it becomes 3g.

- [ ] **Step 2: Renumber the ten**

Edit each `renumber` line so `3f` reads `3g`, and change the section heading `### Plan 3f — the definition/tile picture cache` to `### Plan 3g — the definition/tile picture cache`.

- [ ] **Step 3: Add a note beside the prose lines**

Immediately after the paragraph containing `:633`, add:

```markdown
**Renumbered again on 2026-08-22.** Text wiring and text LOD were split out of
the picture cache and took the `3f` slot, so **the picture cache is now 3g**.
The sentence above describes the *earlier* move and is left as written: it is
the record of why the numbers shifted the first time, not a statement about the
current numbering.
```

- [ ] **Step 4: Add the Plan 3f section**

Under `## Roadmap after 3d`, before the 3g section, add:

```markdown
### Plan 3f — text wiring and level of detail

In flight. Spec:
[docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md](docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md).
Plan:
[docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md](docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md).

Two defects: a document built the ordinary way carries `InsertionPointMeasurer`
and draws no text without reporting anything, and the painter and the sink read
different measurers. Plus text LOD, which is the one of Plan 3g's four
subsystems that depends on none of the other three.
```

- [ ] **Step 5: Verify no stale reference remains**

Run:

```bash
grep -n "3f" STATUS.md | grep -v "text wiring\|text LOD\|Renumbered again\|Plan 3f — text\|plan-3f"
```

Expected: exactly the three `prose, leave` lines and nothing else.

- [ ] **Step 6: Commit**

```bash
git add STATUS.md
git commit -m "docs: the picture cache is 3g; text wiring and LOD take 3f"
```

---

