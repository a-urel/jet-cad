# Task 1 report: STATUS.md renumbering, 3f to 3g

## Step 1: classification

Verbatim output of `grep -n "3f" STATUS.md` (before any edits):

```
270:draw-call dispatch. That finding is what makes a picture cache (**Plan 3f**,
365:**Next**: pick a plan from the roadmap below. **Plan 3f (caches and tiles)**
371:short follow-up before or alongside 3f.
436:4. **Whole-drawing thrash → the picture cache's text LOD (Plan 3f).** 4,140
622:implies for fills and the picture cache (**3e and 3f** under the current
633:moved up one: **fills is 3e** and **the picture cache is 3f**. That is the
635:and it is the numbering the rest of this file uses — every `3d`/`3e`/`3f` above
692:fill's own internal triangulation seam), not this one. Open for 3f or a
697:### Plan 3f — the definition/tile picture cache
700:with a sink that batches across residuals: 3f must decide whether a cached
743:   frame is measured, hiding a first-draw allocation completely. **If 3f's
748:   command, not by a draw`), not the allocation gate — 3f needs the
752:**Do not design 3f against a fixed op-count ceiling.** The web whole-drawing
754:session-dependent CanvasKit failure explains it with no code at fault. What 3f
```

Fourteen lines, matching the expected line numbers exactly.

| Line | Quoted text | Verdict |
|---|---|---|
| 270 | "That finding is what makes a picture cache (**Plan 3f**," | renumber |
| 365 | "**Next**: pick a plan from the roadmap below. **Plan 3f (caches and tiles)**" | renumber |
| 371 | "short follow-up before or alongside 3f." | renumber |
| 436 | "**Whole-drawing thrash → the picture cache's text LOD (Plan 3f).**" | split |
| 622 | "implies for fills and the picture cache (**3e and 3f** under the current" | prose, leave |
| 633 | "moved up one: **fills is 3e** and **the picture cache is 3f**. That is the" | prose, leave |
| 635 | "and it is the numbering the rest of this file uses — every `3d`/`3e`/`3f` above" | prose, leave |
| 692 | "fill's own internal triangulation seam), not this one. Open for 3f or a" | renumber |
| 697 | "### Plan 3f — the definition/tile picture cache" | renumber |
| 700 | "with a sink that batches across residuals: 3f must decide whether a cached" | renumber |
| 743 | "frame is measured, hiding a first-draw allocation completely. **If 3f's" | renumber |
| 748 | "command, not by a draw\`), not the allocation gate — 3f needs the" | renumber |
| 752 | "**Do not design 3f against a fixed op-count ceiling.** The web whole-drawing" | renumber |
| 754 | "session-dependent CanvasKit failure explains it with no code at fault. What 3f" | renumber |

Ten `renumber`, three `prose, leave`, one `split` — matching the brief.

## Step 2: renumber the ten

Each `renumber` line's `3f` was changed to `3g`, and the section heading
`### Plan 3f — the definition/tile picture cache` became
`### Plan 3g — the definition/tile picture cache`.

## Step 3: note beside the prose lines

Immediately after the paragraph containing the old `:633` line (now ending
"...**.**"), added the exact note given in the brief:

```markdown
**Renumbered again on 2026-08-22.** Text wiring and text LOD were split out of
the picture cache and took the `3f` slot, so **the picture cache is now 3g**.
The sentence above describes the *earlier* move and is left as written: it is
the record of why the numbers shifted the first time, not a statement about the
current numbering.
```

## Step 4: split of :436, and the new Plan 3f section

`:436` became:

```markdown
4. **Whole-drawing thrash → text LOD (Plan 3f), split from the picture cache,
   now Plan 3g.** 4,140
```

Under `## Roadmap after 3d`, before the (renumbered) `### Plan 3g` heading,
added the exact section given in the brief:

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

## Step 5: verification

Verbatim output of
`grep -n "3f" STATUS.md | grep -v "text wiring\|text LOD\|Renumbered again\|Plan 3f — text\|plan-3f"`
(after all edits):

```
623:implies for fills and the picture cache (**3e and 3f** under the current
634:moved up one: **fills is 3e** and **the picture cache is 3f**. That is the
636:and it is the numbering the rest of this file uses — every `3d`/`3e`/`3f` above
643:the picture cache and took the `3f` slot, so **the picture cache is now 3g**.
```

Four lines came back, not the three the brief predicted. The first three
(623, 634, 636) are exactly the original `prose, leave` lines (line numbers
shifted down by one because of the Step 3 insertion above them). The fourth
(643) is the *second physical line* of the new Step 3 note itself: the note's
first line contains "Renumbered again" and is filtered out by the grep, but
the brief's own verbatim text hard-wraps that sentence across two lines, and
the wrap boundary puts the ``3f`` slot`` clause on the next line, which
contains none of the filter's five substrings. I inserted the Step 3 text
exactly as given in the brief (task instructions say to use the brief's
values verbatim), so I did not alter its wrapping to dodge the filter.

Content-wise this fourth line is not a stale reference — it is the note's own
correct restatement that text wiring "took the `3f` slot" and "the picture
cache is now 3g", which is the whole point of Step 3. No line in either the
full `3f` grep or the earlier `renumber`/`split` set was missed or left
incorrect; the only discrepancy is against the brief's literal "expected
three lines" count, which did not account for its own note text wrapping
across the filter boundary.

## Step 6: commit

```
git add STATUS.md
git commit -m "docs: the picture cache is 3g; text wiring and LOD take 3f"
```

Result: commit `5d4ef7a` on `main`, `STATUS.md` only (1 file changed, 30
insertions, 11 deletions). Confirmed via `git status`/`git diff --cached
--stat` before committing that none of `apps/dev_harness/analysis_options.yaml`,
`apps/dev_harness/macos/Podfile`, or
`apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj` (pre-existing local
modifications, unrelated to this task) were staged.
