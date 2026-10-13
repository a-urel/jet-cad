### Task 12: The exit gate

**Files:**
- Create: `docs/superpowers/notes/2026-10-13-kit-contract-results.md` (the results of record)
- No code changes. A failure here goes back to the task that owns the code.

**Interfaces:**
- Consumes: everything of Tasks 1-11.
- Produces: the evidence the whole-branch review reads.

- [ ] **Step 1: A clean tree.** `git status --short` prints nothing (no stray `analysis_options.yaml` rewrite staged or committed: `git log --name-only main..HEAD | grep analysis_options` prints only `packages/jet_cad_2d_kit/analysis_options.yaml`).

- [ ] **Step 2: The package gate** (spec exit gate, first line). Run: `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`. Expected: `All tests passed!`, `No issues found!`, format exit 0.

- [ ] **Step 3: The tools gate** (second line). Run: `cd tool/ci && dart test`, then from the root `dart run tool/ci/check_kit_deps.dart`. Expected: `All tests passed!`; `kit dependencies: 1 package(s) checked, none names the plan library or another kit`.

- [ ] **Step 4: The three CLAUDE.md gates** (third line; no old package changed, but run):
  - `cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_gpu && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`

- [ ] **Step 5: The publish dry run** (fourth line). Run: `cd packages/jet_cad_2d_kit && dart pub publish --dry-run`. Expected: exit 0 and `Package has 0 warnings.`; the file list holds `LICENSE`, `README.md`, `CHANGELOG.md`, `example/example.dart`, `lib/authoring.dart`, `lib/jet_cad_2d_kit.dart`. `cmp LICENSE packages/jet_cad_2d_kit/LICENSE` from the root is silent. **Never** run it without `--dry-run`.

- [ ] **Step 6: The constraints, checked by hand.**
  - The old packages are untouched: `git diff --stat main...HEAD -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d packages/jet_cad_2d_flutter packages/jet_cad_2d_gpu apps` prints nothing.
  - No `dart:io` under `lib/`: `grep -rn "dart:io" packages/jet_cad_2d_kit/lib` prints nothing.
  - No Flutter in the model or the authoring toolkit: `grep -rln "package:flutter\|dart:ui" packages/jet_cad_2d_kit/lib/src/model packages/jet_cad_2d_kit/lib/src/authoring packages/jet_cad_2d_kit/lib/authoring.dart` prints nothing (P1 holds the graph; this is the reviewer's quick look).
  - No plan library, no kit: `grep -rn "jet_cad_2d_plan\|jet_cad_2d_kit_" packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_kit/lib` prints only the example line in `bundled_library.dart`'s doc comment (`packages/jet_cad_2d_kit_restaurant/assets/...`): a comment, which `check_kit_deps.dart` rightly ignores.
  - The sample kit regenerates to the committed bytes: run `cd packages/jet_cad_2d_kit && dart run test/fixtures/sample_kit/generate.dart`, then `git diff --quiet -- test/fixtures/sample_kit/sample.jetlib test/fixtures/sample_kit/sample_snapshot.json` must exit 0 (the files are committed, so any difference shows).

- [ ] **Step 7: The results of record.** Create `docs/superpowers/notes/2026-10-13-kit-contract-results.md` with: the branch head SHA; each gate command of Steps 2-5 with its **quoted** last lines (copied from the terminal, never retyped or summarised into numbers that were not printed); the test count of `packages/jet_cad_2d_kit` as `flutter test` printed it; a table of every mutation of Tasks 1-11 (ID, file, the change, the test that went red, as recorded in each task's report); the plan decisions of this plan, one line each; the spec gaps found (Appendix below). Commit:

```bash
git add docs/superpowers/notes/2026-10-13-kit-contract-results.md
git commit -m "$(cat <<'EOF'
docs: the kit contract's symbol side, results of record

The exit gate's transcripts, the mutation table and the plan decisions
of sub-project 1 (jet_cad_2d_kit), for the whole-branch review.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Hand over.** The independent review of the whole branch (spec exit gate, last line) is the coordinator's next step; nothing is pushed, tagged, merged or published from this task.

---

## Appendix: spec gaps found while planning

All eight were taken into the specs in `1525dfe` ("Amendments while planning"); the plan follows the amended text. Kept here as the record of why.

1. **K3 vs K2, rules 5 and 8.** K2's constructors refuse a bad key, tag, target kind or family, and the codec builds components while it decodes, so those faults never reach a validator as written; Task 4 reads components through guarded factories that report them under rules 5 and 8.
2. **K3, millimetres.** The format holds millimetre units, but no rule refuses other units; Task 4 refuses them under rule 2.
3. **K3 rule 14 vs today's allow-list.** "Linetype and colour by block" refuses the BYLAYER and CONTINUOUS values today's validator accepts (its L5); Task 4 follows K3 and inverts L5.
4. **K3, "naming both kits".** Rule 5 puts every key under its own library's kit, so a `key@version` can only repeat between two libraries of one kit; Task 5 names the libraries by position as well.
5. **K4, "two kits never share a word id".** `category:<English category>` carried no kit id, so two kits could share one (`category:Bar`). Amended: `category:<kit id>/<English category>`; Tasks 5, 6, 9 and 10 use it.
6. **Umbrella A2 vs K5.** A2's table gives `SymbolLibrarySource` its `KitNames`, and A2's sketch declares `const PlanKit restaurantKit`; K5 puts the names on `PlanKit`, and its source line `read: bundledLibrary(...)` is a call, so the descriptor cannot be `const`. The plan follows K5 (A2 calls its sketch a sketch), and `docs/kits.md` shows a `final` descriptor.
7. **K7 check 5.** Words are by key and names by version; the spec does not say which version's English a word is compared with. Task 9 uses the newest.
8. **K3 rule 9** ("a `UnitComponent` with a `family`") was ambiguous. Amended: a unit definition whose `SymbolComponent` has a `family` (Task 4).
