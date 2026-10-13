# SDD ledger — plan: docs/superpowers/plans/2026-10-13-package-readmes.md

Spec: docs/superpowers/specs/2026-10-13-package-readmes-design.md (rev 1, A1-A4). Branch feat/package-readmes, base 2dfdcc1 (plan f585e02).

## Pre-flight scan

| Rows | Produces → consumes | Found |
|---|---|---|
| T1 → T3 | `SymbolLibraryReady` on the barrel → T3's `_ready` | consistent |
| T2 → T3, T4 | shots.dart (`pumpScene`, `settle`, `shoot`, `kRatio`, `kWide`, `kPanel`) → scenes | consistent; T3/T4 may change `kRatio` const (Step 4) |
| T2, T6 | both edit root workspace list, ci.yml, DL2 count (+3 each) | sequential, no clash |
| T5, T6 | both edit ci-tools analyze/format lists | sequential, no clash |
| T5 → T8 | check_screenshots red on real packages until T8 adds `screenshots:` | intended (plan T5 Step 5); branch not pushed, CI not run between |
| T6 → T8 | probe files mirror README dart blocks | T8 must keep them in step (stated in T8 Files) |
| T2, T6 → T7 | new pubspecs at ^0.7.1 → T7 raises all to ^0.7.2 | T7 Step 2 names both |
| T7 → T8 | version 0.7.2 → T8's tag-pinned URLs checked against pubspec version | consistent order |
| T1 self | test (B-R10, B1 set) vs exports with `show` (B1 requires show) | consistent |
| T2 self | SH3 vs `updating` early return | consistent |
| T3 self | `_controller` hides the loader vs `_ready(tester, symbols)` | plan says keep the loader local; ruling R1 |
| T4 self | stage uses names assumed exported | plan says verify against barrel, stop if not public |
| T5 self | SS1-SS13 messages vs implementation strings | each expectation matched by a message substring (checked by hand) |
| T6 self | renderer probe imports jet_cad_2d barrel; README must say so | ruling R2 |
| T7 self | Step 4 order: commit before dry run | consistent (dry run needs a clean tree) |
| T8 self | screenshots field + README URLs vs check_screenshots rules | consistent |
| T9 self | ledger archive vs final review | consistent |

Ruling R1: T3 keeps the `SymbolLibraryLoader` in a local the scene passes to both `FloorPlanController(symbols:)` and `_ready` — the plan's own fallback — cost if wrong: none, test-only code.
Ruling R2: if `jet_cad_2d_flutter`'s barrel does not re-export `DraftDocument`/`SpatialIndex`, the renderer README's example says to add both packages (as the engine's says for vector_math) and the probe imports both barrels — cost if wrong: one README sentence.
Ruling R3: check_screenshots stays red from T5 to T8 — the plan orders the check before the data it checks; nothing pushes in between — cost if wrong: none (no CI run on this branch before merge).

## Tasks
Task 1: dispatched (BASE f585e02, implementer sonnet a0d24d30121664f9f)
Task 1: implementer DONE_WITH_CONCERNS 3e83ffe (removed 3 now-unnecessary test imports outside file list; accepted for review); reviewer sonnet dispatched on f585e02..3e83ffe
Task 1: ⚠️ resolved by controller: no other prose in guide/READMEs/CHANGELOGs says the barrel lacks TableNumberProblem (grep); mutation error lines 95/101 vs B-R10 at 94/100 now: one-line shift from the header the formatter joined after the run — consistent.
Task 1: minor (deferred): packages/jet_cad_floor_plan/test/example_test.dart:79-80 stale comment "The loaded state is not host API: the test reads it from src/."
Task 1: complete (commits f585e02..3e83ffe, review clean)
Task 2: dispatched (BASE 3e83ffe, implementer sonnet)
Task 2: implementer NEEDS_CONTEXT (nothing committed): FT2's (0.02, 0.6) bound passes Ahem tofu (0.333) — M-FT2 survives; plan's M-SH3 is not a mutation (SH3 returns early when updating).
Ruling R4: FT2 compares against a tofu reference drawn in the same test (the icon's codepoint in an unloaded family, i.e. Ahem) and requires the icon's ink to be under half the reference's and above 0.02 — a relative bound kills M-FT2 without a magic threshold tuned to one glyph — cost if wrong: one test rewrite.
Ruling R5: M-SH3 becomes `if (updating)` -> `if (true)` inside `shoot` (the implementer's variant) — the plan's variant is unreachable by construction — cost if wrong: none.
Task 2: implementer DONE 12990fb (FT2 relative per R4; M-FT2 red both ways; M-SH3 per R5); reviewer dispatched on 3e83ffe..12990fb
Task 2: ⚠️ resolved: trailers checked (Opus 5.5, the human's instruction); no analysis_options.yaml in 12990fb; archive sizes before are in task-2-report.md (229/226/462 KB) for the results note.
Task 2: minor (deferred): SH3 watches only jet_cad_floor_plan's doc dir; the package path interpolation in shoot is untested.
Task 2: complete (commits 3e83ffe..12990fb, review clean)
Task 3: dispatched (BASE 12990fb, implementer opus — scene composition and eyes-on judgment)
Task 3: implementer DONE_WITH_CONCERNS 08dfe6e: ruler labels in P1/P2 are test-font boxes (RulerPainter's label TextStyle has no family; flutter test's --use-test-fonts maps a family-less paragraph to the test font whatever is loaded — 22 names tried); P5 band over tables 1-3; scenes' app theme names Roboto for captions/chips; _ready starts the loader (selection mode never does).
Ruling R6: insert Task 3b before Task 4 — RulerFrame passes the ambient DefaultTextStyle's fontFamily to RulerPainter's label style (null family = today's style, unchanged), a test killed by a named mutation, the renderer's CHANGELOG 0.7.2 says so (no longer "no code change"); then regenerate P1/P2. Why: the spec requires real fonts in every picture (D4) and no public API reaches the rulers' labels; on a device the ambient family is the app's own font, so the rulers then match the host's text — cost if wrong: one small published behavior change in the renderer to revert before release; the human sees it in "Rulings I made" before merge.
Task 3: ⚠️ resolved: setTablesColor refused in selection mode — the scene colours in design then switches (line 177), as the report says; accepted, test-only.
Task 3: minor (deferred): P5 band ends mid table 1 (half-covered); P1 palette list cut at 800 px ("Text" half visible); _fonts theme (Roboto for captions/chips) is scene-side — README/pubspec descriptions must not claim it.
Task 3: complete (commits 12990fb..08dfe6e, review clean; ruler boxes routed to Task 3b by R6)
Task 3b: dispatched (BASE 08dfe6e, implementer sonnet, brief task-3b-brief.md written by the controller)
Task 3b: implementer DONE_WITH_CONCERNS 5600f4f (lib+test) d1f873b (P1/P2 regenerated, ruler digits real): renderer expect_failures exits 1 — text_lod_ladder rungs 1-2 pass on this Mac.
Ruling R7: the two passing text_lod rungs are the known macOS difference (STATUS "Owed to the human", macOS: "the render package's text lod ladder rungs 1 and 2 pass there, so its standing set differs from Linux's"), not a regression of Task 3b, which touches no ladder code; the renderer's gate on this machine is judged by "only those two differ" — cost if wrong: a Linux CI red at the next push, visible at once.
Task 3b: minor (deferred): ruler_frame.dart build reindented (expression -> block body, ~145 lines of diff noise); RF-c has no chrome-differs/family-matches case.
Task 3b: complete (commits 08dfe6e..d1f873b, review clean)
Task 4: dispatched (BASE d1f873b, implementer opus)
Task 4: implementer DONE 28ec7f4 (5 PNGs, 667,288 bytes, kRatio 1.5; SymbolWords not on editor.dart — scene uses e.name/g.category via searchSymbols' default; GripCache in ToolContext for grips; drags start on empty space with a guard; R5 collapses all but Bathroom); controller eyes-on R3: good
Task 4: ⚠️ resolved: SymbolWords is listed in the plan's Global Constraints (not the spec) as allowed from editor.dart but is not exported there; unused — the results note records the plan's list was wrong.
Task 4: minor (deferred): _x0/_y0 copy the unexported kPlanOriginX/Y; R5 collapses all but Bathroom (D5's "one category open", accepted); thumbnail wait is 40 rounds + eyes-on.
Task 4: complete (commits d1f873b..28ec7f4, review clean)
Task 5: dispatched (BASE 28ec7f4, implementer sonnet)
Task 5: implementer DONE 06d8a1a (SS1-13, tool/ci +90, mutations red; real packages red per R3)
Task 5: minor (deferred): boundary mutations survive (> vs >= at exactly 1 MB, 4 MB, 10 entries — SS2/SS5 test one past each limit only); any non-tag https image (e.g. a badge) is flagged in the two READMEs (plan-mandated; Task 8 keeps them badge-free); missing .pubignore/README throws a raw trace; ./path gives a second "not in the README" line.
Task 5: complete (commits 28ec7f4..06d8a1a, review clean)
Task 6: dispatched (BASE 06d8a1a, implementer sonnet)
Task 6: implementer DONE 34cb012 (RM1-4, tool/ci +94, DL2 21; R2 applied: renderer README names dart pub add jet_cad_2d jet_cad_2d_flutter)
Task 6: ⚠️ resolved: the engine README names vector_math ("dart pub add jet_cad_2d vector_math"); the planner README's snippets use the main barrel only; no CI script enumerates workspace members besides SC16 (packages/ only).
Task 6: minor (deferred): renderer README says `dart pub add` where `flutter pub add` is idiomatic; probe imports not checked against README prose.
Task 6: complete (commits 06d8a1a..34cb012, review clean)
Task 7: dispatched (BASE 34cb012, implementer sonnet; brief amended for R6)
Task 7: implementer DONE 4ba29d0 (dry runs 0 warnings; archives engine 229 KB, renderer 813 KB, planner 781 KB; root CHANGELOG gained a 'Latest releases' paragraph)
Task 7: ⚠️ routed: dry runs re-run in Task 8 Step 9 after funding/screenshots land.
Task 7: minor (deferred): host-guide.md:2271/2275 lines past 80 columns; root CHANGELOG "Latest releases" names Task 8 items — re-read after Task 8.
Task 7: complete (commits 34cb012..4ba29d0, review clean)
Task 8: dispatched (BASE 4ba29d0, implementer sonnet; brief amended)
Task 8: implementer DONE 2927476 (checks green; dry runs 0 warnings; 229/814/782 KB; PNGs in listings)
Task 8: minor (deferred): R3's "entity under the mouse highlighted" (pubspec description + README caption) is not distinguishable in selection_grips.png — soften or render the hover visibly; root README OCCT paragraph not wrapped at 80; double blank lines after R1/P1; "a host asks for them in its theme" vague (name FloorPlanTheme / guide section).
Task 8: complete (commits 4ba29d0..2927476, review clean)
Task 9: dispatched (BASE 2927476, implementer sonnet; Steps 1-4 only, the final review is the controller's)
Task 9: implementer DONE d8ccf7c (Steps 1-4; full gate run, quoted in the note)
Task 9: minor (deferred): STATUS pana step has no command (point to the 0.7.1 note's git-archive recipe); checklist does not say push main before tags; STATUS:3 two adjacent parentheticals, "main carries release 0.7.0" stale; "Next: ... R-10's exports as a 0.x candidate" stale.
Task 9: complete (commits 2927476..d8ccf7c, review clean)
Final review: dispatched (opus, 51125b6..d8ccf7c)
Final review (opus): Ready to merge with fixes — I1 no CI run, five jobs never exercised (apps/floor_planner, apps/restaurant_demo, jet_cad_restaurant_symbols, host-probe + old probes, tool/screenshots on Linux); I2 STATUS checklist gaps (no step 0 merge/push/CI, pana has no command, cd assumes root, STATUS:3 and :581 stale); minors 3-12.
Ruling R8: the fix wave runs the unexercised gates locally (the three packages' tests with the standing comparison, host_probe.sh at file://<worktree> and HEAD, the four old probes) and records them; a real CI run needs a push, which is the human's word — offered at hand-off as a PR from feat/package-readmes — cost if wrong: a Linux-only red found at PR time, before any publish.
Ruling R9: item 11 (push the three tags before publishing) is not adopted — the spec accepts the broken-image window and a failed publish would force moving a pushed tag — cost if wrong: minutes of broken images per package on pub.dev.
Ruling R10: item 12 gets a one-line dartdoc note on RulerFrame (the family follows the ambient DefaultTextStyle; under a bare MaterialApp that is the debug fallback's) — cost if wrong: none.
Final fix wave: dispatched (sonnet, findings file final-findings.md)
Final fix wave: DONE f683f5c..6596fce (13 items; local gates green incl. floor_planner/restaurant_demo/restaurant_symbols, host_probe.sh, old probes v0.3.0-v0.6.0; dry runs 0 warnings)
Final re-review (sonnet): items 1, 3-13 addressed; item 2(a) step 0 and 2(b) pana command NOT addressed; the note's "Final review" item 2 and the fix report claim they were (inaccurate record).
Ruling R11: no second fix wave (the process allows one); the two open items and the note's inaccurate claim are documentation the human executes, so they are surfaced at hand-off with an offer to fix them in one reviewed commit on the human's word, before the merge — cost if wrong: the human publishes from a checklist missing its merge step and the pana command, or the record keeps a false completion claim.
