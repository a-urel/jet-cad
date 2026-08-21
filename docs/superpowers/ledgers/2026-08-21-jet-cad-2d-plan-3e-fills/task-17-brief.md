## Task 17: Mutation testing, the exit gate, and the results note

**Files:**
- Create: `docs/superpowers/notes/plan-3e-mutation-log.md`
- Create: `docs/superpowers/notes/<the day it is written>-plan-3e-results.md`, dated like its siblings
- Modify: `STATUS.md`
- Modify: `CLAUDE.md` **only if** a non-negotiable turns out not to describe this backend — and then only to record that it does not. **The plan may not amend the rule it is measured against.**

- [ ] **Step 1: Re-run every mutation this plan named**

Every mutant from Tasks 1–15, on today's merged code, with the `cp`/`trap`
harness. **Never `git checkout` a file to revert one.** Record each as killed,
survived, unreachable, or equivalent — with the argument, never silently.

- [ ] **Step 2: Add the mutants no task owns**

The cross-task ones, which are where this plan is most exposed:

| mutation | the fixture property that kills it |
|---|---|
| key the cache by `geomIndex` | **purge a document containing fills and draw again** |
| drop dependent fills from `SetEntityGeometry`'s `touched` | edit a boundary, then pick or cull **inside the new-but-outside-the-old region** |
| make `AddRegionCommand` two composed commands | assert no observer sees a fill whose boundary is missing |
| populate the cache lazily on first draw | the allocation gate, on a corpus with fills |
| let the codec skip `_rebuildFills` | the same gate, after a load |

- [ ] **Step 3: Run the whole gate**

```sh
cd packages/jet_cad_2d       && dart test && dart analyze && dart format --output=none --set-exit-if-changed . \
  && dart test test/invariants/query_allocation_test.dart \
  && dart run benchmark/query_throughput.dart   # `snap at dirty threshold` is the known carried failure
cd packages/jet_cad_2d_flutter && flutter test && flutter test --tags golden \
  && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d && flutter analyze
```

- [ ] **Step 4: Write the results note**

Every failable criterion, with its number:

| criterion | threshold |
|---|---|
| allocations per fill in a steady-state frame | **zero** |
| 10,000 entities with fills on, vertices backend | under 16.67 ms |
| a fill's cost in `canvasCalls` on the vertices backend | **zero** |
| ink agreement, opaque fills | stray and uncovered each ≤ 1 % of `canvasInkPixels`, with `canvasInkPixels > 4000` |
| translucent seam difference | measured against the real engine; routing fires above 0.5 % at 8/255, or any pixel at 32/255 |
| `skippedFillCount` on the rig corpus | **0** |
| a malformed fill in a loaded document | reported by `validate()` with the matching code, nothing mutated |
| triangulation entries after `purge()` | drawing unchanged, byte for byte |
| cache entries after removing every fill's boundary | **zero** |
| load-time triangulation cost | measured and recorded |
| the mutation log | every mutant killed or argued equivalent |

**If a failable row misses: record the number and stop.** Plan 3b's Task 4 stop
clause is the precedent. Say what it implies for 3f; do not tune until it
complies.

The note must state **whether macOS Low Power Mode was on** — read it with
`pmset -g | grep lowpowermode` and record the value.

- [ ] **Step 5: Update `STATUS.md`**

Commit **ranges**, never a count: a count is falsified by the commit that
writes it.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/notes STATUS.md
git commit -m "docs: Plan 3e results, mutation log, and the exit gate"
```

---

## Notes for whoever executes this

- **`git status --porcelain` after every `flutter test` or `flutter drive`.** `flutter pub get` rewrites three `analysis_options.yaml` files and `flutter drive` rewrites `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`. Neither is ever committed.
- **Never `git checkout` a file to revert a mutation.** Plan 3c's Task 10 lost a full task's work that way. `cp` aside, restore in a `trap`.
- **Never synthesize test output.** Reviewers verify claims independently.
- **The named mutation is the deliverable, not the test.** A task whose new tests stay green under its own named mutations is not done, whatever the suite says.
- **Work happens directly on `main`** for this plan. There is no worktree, so `.superpowers/sdd/<plan-slug>/` lives in the main checkout and must be archived to `docs/superpowers/ledgers/` in the same way a worktree plan's is.
