## Task 9: mutation testing, the results note, and the exit gate

**Files:**
- Create: `docs/superpowers/notes/plan-3f-mutation-log.md`
- Create: `docs/superpowers/notes/2026-08-22-plan-3f-results.md`
- Modify: `STATUS.md`

**Interfaces:**
- Consumes: everything.
- Produces: the results of record.

**Mutation procedure — the mutation, the test and the restore run in ONE shell call.** A `trap ... EXIT` spread across two Bash calls fires before the test runs, so the mutation is never measured. Plan 3e lost a full agent run to that.

```bash
cp target.dart /tmp/target.dart.bak && \
  (apply the mutation) && \
  (CI=true flutter test ... ; echo "EXIT=$?") ; \
  cp /tmp/target.dart.bak target.dart
```

**Never `git checkout` a file to revert a mutation** — it restores HEAD and silently wipes every uncommitted change in that file.

- [ ] **Step 1: Run all fifteen named mutants**

| # | mutation | expected killer |
|---|---|---|
| 1 | move the LOD test after `measure()` | row 1 |
| 2 | `<` to `<=` at the threshold | the exact-threshold test in `text_lod_test.dart` |
| 3 | drop `chain.scaleMagnitude`, cull on world height alone | row 5 |
| 4 | drop `_culledText++` | row 4 |
| 5 | reference walk reads the painter's decision | the non-identity differential fixture |
| 6 | merge the two maps back into one | row 10 |
| 7 | `metricsLimit` defaulted to `kParagraphCacheLimit` | row 10, in layouts |
| 8 | remove the `DraftCanvas` guard | row 8 |
| 9 | `measure()` does not store metrics | rows 1 and 10 |
| 10 | apply LOD inside `entityBounds` | row 6 |
| 11 | `culledTextCount` not reset per frame | the two-frame test |
| 12 | keep the metrics probe paragraph instead of disposing it | the ladder's distinct-key column |
| 13 | `DraftCanvas.dispose()` keeps calling `clear()` | row 11 |
| 14 | `minTextCapPixels` left out of `didUpdateWidget` | the prop-update test |
| 15 | `DraftPainter.minTextCapPixels` defaulted to `0.0` | a bare-`DraftPainter` text test that passes no knob |

For each, record: the exact diff applied, the command run, the verbatim output, and the verdict — **killed**, **equivalent with the argument**, or **unmeasurable with the reason**.

**A named killer is not a killer until it has fired.** Plan 3c had four of twenty spec mutants survive the very suite named for them. If a mutant survives, that is a result: write the number, say what it implies, and either add the test that kills it or record it as a gap.

- [ ] **Step 2: Write the mutation log**

Create `docs/superpowers/notes/plan-3f-mutation-log.md` with one section per mutant: the diff, the command, the output, the verdict. No summary that is not derivable from the rows.

- [ ] **Step 3: Run the thirteen failable criteria**

| # | row | threshold |
|---|---|---|
| 1 | whole-drawing camera, repeat frame, new layouts | 0 (baseline 4,140) |
| 2 | whole-drawing camera, repeat frame, paragraph evictions | 0 (baseline 4,140) |
| 3 | working-set camera, layouts and paragraph evictions | 0 |
| 4 | `culledTextCount`, whole-drawing camera | > 0 |
| 5 | `culledTextCount`, working-set camera | 0 |
| 6 | `doc.extents` at `minTextCapPixels` 0 and 1000 | bit-identical |
| 7 | picking a text entity, at both thresholds | same hit |
| 8 | `DraftCanvas` over a document with the default measurer | throws, naming the fix |
| 9 | differential oracle, LOD on, both cameras | passes |
| 10 | extents-sweep non-interference | layouts 0, paragraph evictions 0 |
| 11 | split view: dispose one canvas | the other's `layoutCount` unchanged |
| 12 | `measurer.clear()` | every live paragraph `debugDisposed` |
| 13 | mutation log | every mutant killed, argued equivalent, or recorded unmeasurable |

Row 10's procedure: paint one frame at the working-set camera warm; call `invalidateDerived()` then read `doc.extents` in full; repaint at the same camera; read new paragraph layouts and paragraph evictions.

**If a failable row misses: record the number and stop.** Plan 3b's Task 4 stop clause is the precedent. Do not tune the threshold until the row complies — say what the number implies for Plan 3g's text LOD and stop.

- [ ] **Step 4: Run the full green gate**

```bash
cd packages/jet_cad_2d          && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter        && CI=true flutter test && CI=true flutter test --tags golden && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d    && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../packages/jet_cad_2d    && dart run benchmark/query_throughput.dart
```

`snap at dirty threshold` is the known carried failure from Plan 2. It is not a regression.

- [ ] **Step 5: Write the results note**

Create `docs/superpowers/notes/2026-08-22-plan-3f-results.md`: every criterion with its measured number and verdict, the threshold ladder table, the per-site margin table from Task 6, the measured distinct-key count, whether Low Power Mode was on, and the exact Flutter and framework versions from `flutter --version`.

State explicitly what this plan did **not** close: permitted divergence 5 (overlapping translucent strokes on a triangle soup), still live and still unexercised; the metrics-lookup allocation, unmeasurable without `vm_service` in the Flutter suite; and the step-function shape of the corpus's text pressure.

- [ ] **Step 6: Update STATUS.md**

Replace the "In flight" Plan 3f section from Task 1 with the finished account: exit gate result, links to both notes, and what Plan 3g inherits — a working text LOD, the threshold ladder, the measured distinct-key count, and the unresolved question of whether a cached picture may contain text at all, since a picture is baked per scale band while LOD is a function of continuous scale.

Refresh the suite table by **running** the suites, not by reading this plan.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/notes STATUS.md
git commit -m "docs: Plan 3f results, mutation log and exit gate"
```

---

## Self-review

**Spec coverage.** Section 1's ownership → Task 4. The split cache, both bounds, both constructor parameters, per-map counters, probe disposal, the insert assertion → Task 2. The counter-rename call sites and the microbench premise → Task 3. Disposal ownership and its three tests → Task 4 (split view, teardown) and Task 4 Step 5 (harness lifecycle). Section 2's LOD test and placement, the constant, the disable knob, `didUpdateWidget` → Task 5. The reference walk, the recording helpers, the second blast radius → Task 6. Documented alternatives → Task 5 Step 3's constant doc comment. Section 3's thirteen criteria, fifteen mutants, the golden ladder, the rig → Tasks 7, 8, 9. The renumbering → Tasks 1 and 9.

**One spec item is deliberately deferred rather than dropped:** `kMetricsCacheLimit`'s measured justification. Task 2 sets it from the spec's arithmetic and says in the doc comment that the figure is derived; Task 8 Step 5 replaces that sentence with the measured count. A plan that demanded the measurement in Task 2 would need the rig before the class it measures.

**Type consistency.** `paragraphEvictionCount` / `metricsEvictionCount` / `liveMetricsCount` / `paragraphLimit` / `metricsLimit` are introduced in Task 2 and used with those exact names in Tasks 3, 8 and 9. `culledTextCount` / `minTextCapPixels` / `kMinTextCapPixels` are introduced in Task 5 and used with those exact names in Tasks 6, 7, 8 and 9. `harnessMeasurer` is introduced in Task 4 and used in Task 4 only. `textLodDifferentialDocument` is introduced and used in Task 6.

**Known plan risk, stated rather than hidden.** Task 6 Step 1's fixture is complete code, but three of its numbers — the text heights 40, 172 and 800 — are derived from the fit arithmetic rather than measured, because `ViewportTransform.fit`'s margin cannot be computed from here. The step therefore requires the implementer to print all three on-screen cap heights before proceeding and to state them in the report, and says explicitly that a fixture which does not straddle the threshold gets new heights rather than a new threshold. A fixture tuned by moving `kMinTextCapPixels` tests nothing, and one written at the identity transform is the degenerate fixture this repository names as its dominant defect class.

**One more thing an implementer should not have to rediscover.** Task 2 leaves the tree in a state where `flutter analyze` fails on `paint_microbench_test.dart` — that file reads the old `evictionCount` and Task 3 owns it. This is the single place in the plan where a task does not end analyze-clean on every package, it is deliberate rather than an oversight, and Task 2 Step 5 says so. Merging the two would put a rig rewrite and a cache rewrite behind one reviewer's gate.
