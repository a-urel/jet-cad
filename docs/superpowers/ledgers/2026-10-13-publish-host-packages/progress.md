# SDD ledger — plan: docs/superpowers/plans/2026-10-13-publish-host-packages.md

Spec: docs/superpowers/specs/2026-10-13-publish-host-packages-design.md (rev 2, approved 2026-10-13).
Branch feat/publish-host-packages, start 690ed4c (main d41e5f6). Human chose subagent-driven (2026-10-13).

## Pre-flight scan

| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T1 → T2, T3 | T1 sets both packages' `version: 0.7.1` and hosted lines; T2/T3 edit the rest of the same pubspecs | consistent; T2/T3 must not touch the dependency lines |
| T1 → DL tests | DL2 requires every sibling constraint `^0.7.1` | no later task changes a constraint: consistent |
| T2 / T3 | both add `test/example_test.dart` and `example/lib/main.dart` in their own package | no shared file |
| T2, T3 → T4 | T4's dry-run job needs LICENSE, CHANGELOG, `.pubignore` of T2/T3 | order holds (T4 after T3) |
| T4 / T6 | both edit `.github/workflows/ci.yml` (T4 `publishable`, T6 `ci-tools` file lists) | sequential, different jobs |
| T5 → T6 | T5 produces `check_host_lock.dart <lock> --ref <sha>`; T6's `host_probe.sh` calls it so | consistent |
| T5 / T6 | both edit `tool/ci/test/scripts_test.dart` (T5 adds SC16; T6 adds SC17, rewrites SC14) | sequential; T6 must keep SC16 |
| T6 → T7 | T7's note records T6's probe runs and M-PR1 | consistent |
| T1 self | test code vs pubspec edits; DL2 premise count "set exactly at Step 3" | consistent |
| T2 self | test asserts pick at (300,301) edge, example draws circle (300,250) r50 | consistent |
| T3 self | test needs `SymbolLibraryLoaded` reachable from a public library | plan allows the implementer to import the library that exports it |
| T4 self | M-CI1 dirties a tracked file then restores | consistent |
| T5 self | HL-C3 hosted entry replaces a git entry in the green fixture | consistent |
| T6 self | Step 7 commits before probing; Step 8 is that commit | consistent |
| T7 self | the plan's last line (workspace deletion, from the skill) vs repo convention | ruling R-2 |

Ruling R-1: On macOS the render package's `expect_failures.dart` reports the text-lod-ladder rungs 1–2 passing and the five text-ladder goldens failing; a task is green there when exactly those differ — STATUS records the macOS standing set as differing (not ruled), and `main` at 133cf03 shows the same five — cost if wrong: a real golden regression hidden behind the macOS difference; CI (Linux) compares exactly and would catch it.
Ruling R-2: At the end the workspace's ledger is archived to docs/superpowers/ledgers/2026-10-13-publish-host-packages/ as the branch's last commit, not deleted — CLAUDE.md and the repo's merged plans archive their ledger before the merge — cost if wrong: one extra docs commit.
Ruling R-3: The no-Codex rule binds every reviewer dispatch (memory: the human, 2026-10-10) — cost if wrong: none.

## Tasks
Task 1: dispatched (implementer sonnet, agent ab1d2347e8904d2a4, BASE 690ed4c)
Task 1: implementer DONE (4d74b5b); review dispatched (sonnet, agent a77bad5548015b77a)
Task 1: ⚠️ resolved by controller: trailer present; jet_cad_2d at 0.7.1; package_config resolves the render package locally.
Task 1: minor (deferred): dependency_lines_test.dart if without braces (style; analyze clean).
Task 1: minor (deferred): DL1's regex misses a flow-style git map; DL2 catches it by value. DL3 covers path, not git, though the header names both.
Task 1: complete (commits 690ed4c..4d74b5b, review clean)
Task 2: dispatched (implementer sonnet, BASE 4d74b5b)
Task 2: implementer DONE_WITH_CONCERNS (09153e8): pana 40/160; engine README stale; Aabb2.inflate absent (expandedBy used).
Ruling R-4: pana for a dependent cannot be measured before its dependency is on pub.dev (pana resolves outside the workspace; jet_cad_2d 0.7.1 answers 404) — the results note records 40/160 with that reason, and the human's checklist runs pana after each dependency is published (already D1's lower-bound step) — cost if wrong: a pana defect (docs, analysis on the archive) found only at publication time; mitigated by the dry run, dart doc 0 warnings and the gates on the same files.
Ruling R-5: packages/jet_cad_2d/README.md's "the Flutter packages … are not published on pub.dev" sentence is rewritten in Task 7 (no engine version bump: the README reaches pub.dev with the engine's next release) — cost if wrong: pub.dev's engine page keeps the stale sentence until then.
Task 2: review dispatched (sonnet, agent a62a6ec8b38417cf6)
Task 2: ⚠️ resolved by controller: R-1 covers the lod rungs; dry run re-run on 09153e8: exit 0, "Package has 0 warnings.", 226 KB, no test/build/shaders; LICENSE cmp same; trailer present.
Task 2: minor (deferred): geometry_collector.dart's comment still names test/support/instance_expander.dart and frame_info.dart, absent from the archive.
Task 2: minor (deferred): README snippet uses `size` undefined (fragment; full example linked).
Task 2: minor (deferred): README names jet_cad_floor_plan, not yet on pub.dev (true after the planner's publish).
Task 2: complete (commits 4d74b5b..09153e8, review clean)
Task 3: dispatched (implementer sonnet, BASE 09153e8)
Task 3: implementer DONE_WITH_CONCERNS (5eec301): editor.dart hides readBundledLibrary; SymbolLibraryReady (not Loaded) imported from src in the test; M-FX1 red via the loader's ArgumentError, not the entries assertion; CHANGELOG cites a guide section Task 6 writes; pana 40/160 (R-4).
Ruling R-6: editor.dart's `hide readBundledLibrary` stands though D4 publishes barrels as they stand — the package still exports the symbol from symbol_sources.dart (its one home), editor.dart is internal by its own header, the hide removes dart doc's ambiguous-export warning, and nothing imports it from editor.dart (grep) — cost if wrong: a caller importing editor.dart for readBundledLibrary must import symbol_sources.dart instead.
Task 3: review dispatched (sonnet, agent a3d1c667da5c5b3e5)
Task 3: review Approved with 2 Important: (1) CHANGELOG.md:49 "a plan either saves opens in the other" garbled (plan text); (2) CHANGELOG/README cite the guide's "The restaurant symbols", not yet written (plan-mandated).
Ruling R-7: finding (2) stands as written — Task 6 writes that subsection under exactly the heading "The restaurant symbols" in the host guide §1, and its dispatch carries this — cost if wrong: a dangling reference in the planner's CHANGELOG until Task 6 lands (before any merge).
Task 3: minor (deferred): M-FX1 dies on the loader's ArgumentError; the `library.entries` isNotEmpty assertion is exercised by no named mutant.
Task 3: minor (deferred): README says symbol_sources.dart holds "the sources and their loader's Flutter side"; it exports SymbolLibrarySource, furnitureSymbolSource, readBundledLibrary, SymbolNames (the loader is on the main barrel).
Task 3: minor (deferred): README's `mySymbolSource` placeholder name.
Task 3: fix round 1 dispatched (resume implementer) for finding (1)
Task 3: fix round 1/5 (1 addressed, 0 open; commits 5eec301..e2869e5)
Task 3: minor (deferred): CHANGELOG.md:25 runs ~88 columns in a ~76-column paragraph.
Task 3: complete (commits 09153e8..e2869e5, review clean after fix round 1)
Task 4: dispatched (implementer haiku, BASE e2869e5)
Task 4: implementer DONE (c9eed8a)
Task 4: review dispatched (haiku)
Task 4: ⚠️ resolved by controller: the renamed check name breaks no required check — `gh api .../branches/main/protection` answers "Branch not protected" and rulesets is [].
Task 4: trailer note: the human's instruction fixes the trailer to Claude Opus 5.5; kept on every commit.
Task 4: complete (commits e2869e5..c9eed8a, review clean)
Task 5: dispatched (implementer sonnet, BASE c9eed8a)
Task 5: implementer DONE_WITH_CONCERNS (2f88612): the brief's M-LK1 premise was wrong (a hosted entry has no resolved-ref, so the ref clause catches it); HL-C3b added (right ref, source: path) kills M-LK1. SC16 was taken; the CLI test is SC21.
Ruling R-8: Task 6's package_root test is SC22 (the next number after SC21), and Task 6 keeps SC21 untouched — the plan's SC17 name predates SC16–SC21 — cost if wrong: none (a test name).
Task 5: review dispatched (sonnet)
Task 5: review Approved, 0 Critical, 0 Important; ⚠️ host_probe.sh does not pass --ref yet (Task 6's step).
Task 5: minor (deferred): lockEntryFields gives RangeError, not FormatException, on a quoted `"jet_cad_*":` key (lockPackages accepts quotes; pub never writes them).
Task 5: minor (deferred): check_host_lock's success line does not say the ref check ran.
Task 5: minor (deferred): `--ref ''` exits 1, not 2.
Task 5: complete (commits c9eed8a..2f88612, review clean)
Task 6: dispatched (implementer sonnet, agent a6cb581a3ce6d34d3, BASE 2f88612), carrying R-7, R-8
Task 6: implementer DONE_WITH_CONCERNS (4712baa): probe + 4 old probes green locally; M-PR1 red at resolution (exit 69); SC22 resolves symlinks (macOS /private/var); bare `dart analyze` in tool/ci reports host_probe/lib/main.dart's missing restaurant_names.dart (CI's file list excludes it); guide intro still "covers release 0.7.0".
Ruling R-9: the host guide's intro names the release a host depends on — "covers `jet_cad_floor_plan` 0.7.1", linking the planner's CHANGELOG (the root CHANGELOG becomes an index in Task 7); the "Since 0.7.0" feature markers stay (0.7.1 is packaging only) — folded into Task 6's fix round — cost if wrong: one sentence.
Task 6: review dispatched (sonnet)
Task 6: review Approved, 0 Critical, 0 Important; minors: SC22 does not test the trailing-slash strip; the guide's rules omit D9's "a symbol change reaches hosts with a planner release" and the loader-duplicate reason for the never-restaurantSymbolSource rule.
Task 6: fix round 1 dispatched (resume implementer): R-9 + the two minors above.
Task 6: fix round 1/5 (3 addressed, 0 open; commits 4712baa..ede7283); scoped re-review by controller (13-line diff): text matches D9/F-8, SC22 mutant red per report; controller re-ran tool/ci dart test (+77) and check_guide (56 blocks).
Task 6: minor (deferred): host_probe.sh header still says the restaurant package reaches the planner at the full sha (true for the override).
Task 6: complete (commits 2f88612..ede7283, review clean after fix round 1)
Task 7: dispatched (implementer sonnet, agent aba951b38cb976f00, BASE ede7283), carrying R-1, R-4, R-5, R-6, R-9
Task 7: implementer DONE (3ca02d8): all gates green (R-1 set exactly); dry runs 229/226/462 KB, 0 warnings; barrel audit: SymbolLibraryState and TableNumberProblem unexported in planner signatures (recorded as 0.x candidates, D4); amended twice before hand-back (unpushed).
Task 7: review dispatched (sonnet)
Task 7: review Changes requested (minor): 1 Important — the note's D4 bullets say SymbolLibraryState/TableNumberProblem are in no public library, but editor.dart (internal, outside semver) exports both; host-guide.md:151-154's "implement FloorPlanStrings" needs TableNumberProblem. Minors: STATUS.md:536 stale "guide names 0fa649e"; note header claims the ledger archived; Resume lacks the branch-CI line.
Ruling R-10: the unexported SymbolLibraryState/TableNumberProblem stay unexported in 0.7.1 (spec D4: barrels published as they stand); the note records them as 0.x export candidates with the FloorPlanStrings consequence, and the hand-off names them to the human — cost if wrong: a host implementing FloorPlanStrings imports editor.dart until a 0.x release exports the enum (adding an export is non-breaking).
Task 7: fix round 1 dispatched (resume implementer)
Task 7: fix round 1/5 (4 addressed, 0 open; commits 3ca02d8..c660947); controller read the 30-line docs diff: D4 bullets now name editor.dart; tableNumberProblem is abstract, so any direct FloorPlanStrings class needs the enum (strengthens R-10's hand-off question).
Task 7: complete (commits ede7283..c660947, review clean after fix round 1)
Final review: dispatched (opus) on main..c660947
Final review (opus): With fixes. 0 Critical; Important: (1) STATUS D7 step unworkable (restaurant files absent without overrides); (2) R-10 — recommends exporting SymbolLibraryState family + TableNumberProblem before 0.7.1. Minors 1-8; deferred triage: fix the planner README symbol_sources sentence (T3) and host_probe.sh header (T6); leave the rest.
Ruling R-11: R-10 stands for this fix wave (spec D4, approved by the human, publishes barrels as they stand; widening the published API is the human's call) — the wave applies the reviewer's fallback (the guide steers a custom FloorPlanStrings to a built-in language's subclass), and the hand-off asks the human whether to add the two exports before publishing — cost if wrong: one more small commit after the human's answer.
Ruling R-12: the restaurant names file is copied verbatim, no sed — symbol_sources.dart is a host-facing public library exporting SymbolNames (reviewer verified), so the rewrite is a needless host step — cost if wrong: host_probe.sh and the guide revert to the rewrite; the probe re-run catches a failure.
Ruling R-13: final-review Minors 7 (root CHANGELOG "published" before the publish: the spec's accepted window) and 8 (example test calls symbols.load itself) are left and recorded — cost if wrong: a stale word for the hours between merge and publish; a test that does not pin the example's own load call.
Final fix wave: dispatched (implementer sonnet, BASE c660947)
Final fix wave: implementer DONE (ce69050 F1-F9, a45f87f probe re-run + M-CP1 recorded): tool/ci +77, check_guide 56, planner dry run 0 warnings, probe exit 0, M-CP1 red (restaurant_names.dart missing), tree clean. The reviewer's report transcribed to final-review.md by the controller.
Final fix wave: scoped re-review dispatched (sonnet) on c660947..a45f87f
Final fix wave: scoped re-review (sonnet): F2-F8 addressed; F1 (no mkdir for the untracked assets/) and F9 (the note's "Final review" claimed the report was not kept) open — both doc-only.
Final fix wave: residuals fixed by the controller (124c50a): STATUS's D7 block gains `mkdir -p tool/ci/host_probe/assets`; the note's "Final review" lists the reviewer's measurements from final-review.md. No probe re-run needed (docs only).
Ruling R-14: the two residuals are closed by the controller's own commit rather than a sixth dispatch — they are two doc edits, each quoted from the re-review — cost if wrong: none beyond a reread.
Final: branch complete at 124c50a; ledger archived next (R-2); merge, push, tag and publish wait for the human; R-10/R-11 (the two exports before 0.7.1) is the human's question.
