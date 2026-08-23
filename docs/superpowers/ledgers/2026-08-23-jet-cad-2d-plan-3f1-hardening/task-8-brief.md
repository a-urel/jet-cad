## Task 8: the exit gate

**Files:**
- Create: `docs/superpowers/notes/2026-08-23-plan-3f1-results.md`
- Create: `docs/superpowers/notes/plan-3f1-mutation-log.md`
- Modify: `STATUS.md`

**Interfaces:**
- Consumes: every task's report and every mutation transcript.
- Produces: the results of record.

- [ ] **Step 1: Run the whole gate, both packages, from a clean tree**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git status --short
cd packages/jet_cad_2d         && CI=true dart test    && dart analyze    && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter       && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd .. && git status --short jet_cad_2d_flutter/test/golden
```

Record the test counts verbatim. The golden `git status` must be empty.

- [ ] **Step 2: Score all seventeen criteria**

Write `docs/superpowers/notes/2026-08-23-plan-3f1-results.md` with one row per
criterion: number, claim, the command that proves it, the observed result, and
PASS / MISS / UNEVALUABLE. Criterion 17 is scored by whichever branch of Task 7
ran. **Never synthesize a transcript**; if a criterion was not run, mark it
UNEVALUABLE and say why.

The note must also carry, in its own section, anything this plan did **not**
close — at minimum:

- **Permitted divergence 5** — overlapping translucent strokes on a triangle
  soup. Untouched by this plan, still unexercised by any fixture.
- **The malformed-layer asymmetry**, mirrored rather than fixed (spec accepted
  gap 2).
- **Ruling 4's `kParagraphCacheLimit` raise**, still unspent, still carrying its
  measured 3,876.
- **Whatever Task 7's probe decided**, in full.

- [ ] **Step 3: Write the mutation log**

Write `docs/superpowers/notes/plan-3f1-mutation-log.md` with one section per
mutant M1–M17: the exact edit, the exact command, the verbatim output, and
whether it was killed. A mutant that no criterion reddened is recorded as a
**survivor with its reason** — never quietly dropped. Plan 3f's log carries
three such entries and they are the most useful rows in it.

- [ ] **Step 4: Update `STATUS.md`**

- A "Plan 3f.1 — hardening" section under the roadmap, before the 3g section:
  what landed, the criteria score, the commit range, links to both notes.
- Amend the **Plan 3g** section: trap 4 (`InstanceNode` carries 2 of 6 fields)
  is **closed** — say so rather than deleting the trap, so a reader of the
  older notes can follow the thread.
- Add to 3g's inheritance the cache-key cardinality consequence: `StyleContext`
  compares `linetypeScale` with `==` and hashes it, so once the four fields
  carry real values, instances that used to share a definition picture no
  longer do — and because the scale is a product accumulated down the tree, two
  chains whose scales are mathematically equal but reached by different factors
  are different doubles and therefore different keys. A reason 3g may want a
  quantised scale band in its key rather than the raw double.
- Record whether the Flutter package now has a working allocation meter.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/notes/2026-08-23-plan-3f1-results.md \
        docs/superpowers/notes/plan-3f1-mutation-log.md \
        STATUS.md
git commit -m "docs: Plan 3f.1 results, mutation log, and STATUS update"
```

---

## Self-review

**Spec coverage.** Decisions 1–4 → Tasks 1–4. Decision 5's hazard → the
anti-degenerate rule in Global Constraints, enforced in every Section 1 fixture
and in Task 3's explicit note that the `1.0` guard test is not the proof.
Decision 6 → Tasks 5 and 6, with the rig and `dart_test.yaml` untouched.
Decisions 7–9 → Task 7, including the full-revert stop clause and the explicit
refusal to write a trap-5 gate here. Criteria 1–17 map to Tasks 2, 3, 2, 3, 2,
2, 2, 2, 4, 1, 4, 5, 5, 6, 6, 6, 7. Mutants M1–M17 map to Tasks 2, 2, 2, 3, 3,
2, 2, 2, 2, 1+4, 1, 5, 5, 5, 6, 6, 6.

**Every identifier in this plan was read from the tree while writing it**, not
recalled: `DraftDocumentCodec.encode`/`.decode` and the `'nodes'` key
(`json_codec.dart:36,56,92`), `RecordingDrawSink` and `TextOp.text`
(`draw_sink.dart:289,267,270`), `VerticesDrawSink`'s constructor
(`vertices_draw_sink.dart:105-111`), `leavesByOwner()` (`reference_walk.dart:41`),
`liveMetricsCount`/`liveParagraphCount` (`flutter_text_measurer.dart:109,112`),
`kByBlock = -2` / `kLineweightDefault = -3` / `byBlockLinetype = Handle(3)`
(`style.dart:6,9,12,107`), and the seven `_canvasCalls++` sites
(`canvas_draw_sink.dart:137,152,159,168,189,200,226`). The first draft of this
plan sent the implementer to re-derive four of those; a plan that outsources
its own signatures sends someone to debug a fabricated one.

**One thing is deliberately left to the implementer:** Task 4's `v5Document()`
derives its fixture by encoding a real document and removing four keys, rather
than hand-writing the codec's JSON shape. That is not a gap — a hand-written
shape would be a second, drifting copy of the contract, and one that silently
fails to parse proves less than nothing about a migration.

**Task independence.** Section 3 (Task 7) depends on nothing and can run first
if its probe result is wanted early. Tasks 5 and 6 depend on nothing in
Section 1. Within Section 1 the order is forced: 1 → 2 → 3 → 4.
