# SDD ledger — plan: docs/superpowers/plans/2026-10-12-plan-colors-slice-2.md

Spec: docs/superpowers/specs/2026-10-12-plan-colors-design.md (revision 2, approved; Slice 1 merged at `ce0a4f9`).
Branch: feat/plan-colors-slice-2 (worktree .claude/worktrees/plan-colors-2), from `main` at `c429735`. Plan commit `b6ee305`.
Execution: subagent-driven, chosen by the human 2026-10-12 ("subagent-driven ile devam et").

## Pre-flight scan

| Rows | Produces / consumes | Found |
|---|---|---|
| T1 ↔ T4 | T1 produces `PageUnderlayFill`/`PageUnderlayPolygon`/`PageUnderlayCircle`, `drawPageUnderlay`, `underlay:` on both exports; T4 builds the list and passes it | consistent |
| T2 ↔ T3 | T2 produces `FloorPlanTableColor.colorValue`; T3's painter reads it | consistent |
| T2 ↔ T4 | T4's `tableColorUnderlay` reads `colorValue` | consistent |
| T2 ↔ T5 | T5 reads `name`/`isKept` and builds `FloorPlanTableColor(color)` | consistent |
| T3 ↔ T4 | T3 produces `kTableColorOpacity`, `FloorPlanTheme.tableColorOpacity`, the design mount (EX5's canvas side) | consistent |
| T2 ↔ T4 (file) | both edit `floor_plan_controller.dart`: T2 `_detailsOf` and the setters (`:1496-1597`), T4 `exportPlan`/`printPlan` (`:1320-1355`) | disjoint regions, sequential tasks |
| T1 self | PU1–PU5 against `drawPageUnderlay`; PU3 uses `exportPagePdf`'s `compress` (exists, `@visibleForTesting`); PU5's `RecordingDrawSink` exists (`draw_sink.dart`'s doc names it) | consistent |
| T2 self | TC1–TC9 against the component and the shared path; M-C11 declared engine-owned with TC8 its witness | consistent |
| T3 self | TF1–TF10 against the rung, the survey change, the mount; named exceptions for theme and painter tests | consistent |
| T4 self | EX1–EX5 against the underlay builder and the threaded opacity | consistent |
| T5 self | CP7–CP10 and CP1's pin; the pin may prove unreachable, the plan asks for the reason then | consistent |
| T6 self | docs, probe, gates | consistent |

Ruling 1: the skill's helper scripts are refused by the worktree guard; the controller does their work by hand (workspace mkdir, briefs cut with python, review packages as three plain git commands) — as in Slice 1 — costs, if wrong: nothing structural.

Ruling 2: the ledger is archived to `docs/superpowers/ledgers/2026-10-12-plan-colors-slice-2/` as the branch's last commit, not deleted (the repo's convention) — costs, if wrong: a docs directory to remove.

Ruling 3: commit trailers name the model that wrote the commit (the session's attribution rule), as in Slice 1 — costs, if wrong: amending trailers.

## Tasks
Task 1: dispatched (BASE b6ee305, implementer sonnet)
Task 1: implementer DONE (fd75018); deviations: PdfContent vertices already CTM-mapped; pdfTolerance (5 decimals); PU3 blanks the random /ID; M-PU-c killed by a recording-sink test (sinks push residuals lazily). Review dispatched (opus).
Task 1: minor (deferred): page_underlay_test.dart:302 comment says same length, but /ID replacement is shorter.
Task 1: minor (deferred): PageUnderlayPolygon does not validate triangles.length % 3 or index < count (page_underlay.dart:41-61).
Task 1: minor (deferred): @immutable with mutable typed-data fields; document ownership.
Task 1: minor (deferred): PU2 orders fills against strokes.first only.
Task 1: complete (commits b6ee305..fd75018, review clean)
Task 2: dispatched (BASE fd75018, implementer sonnet)
Task 2: implementer DONE (ebd5d1a); RED recorded after reverting lib to HEAD; TC9 Change size via changeSizeCommand with a hand-made symbol.
Ruling 4: FloorPlanTableDetail.toString appends ', color: …' only when color is non-null — the Global Constraints forbid changing an existing value's toString, and DC13/table_detail_test pin today's strings — costs, if wrong: one toString line and two re-pinned assertions.
Task 2: review dispatched (opus).
Task 2: minor (deferred): floor_plan_controller.dart:1575/:1630 the design check runs twice on the data path; a comment at :1575.
Task 2: minor (deferred): table_color_test.dart:421 local withColor shadows the helper.
Task 2: minor (deferred): no colour test applies TransformNodeCommand (move/turn/mirror keep it; shared with data).
Task 2: minor (deferred): null over an unknown-name payload ('magenta') untested.
Task 2: minor (deferred): a colour loaded on an unnumbered table not tested in tableDetails/diagnostics.
Task 2: complete (commits fd75018..ebd5d1a, review clean)
Task 3: dispatched (BASE ebd5d1a, implementer opus)
Task 3: implementer DONE (9cb886b, opus); TF8/TF9 need two pumps (the shell hears document changes on an async stream); M-C15 dies at TF8's first leg; theme_canvas_test's fullTheme ('every field set') lacks tableColorOpacity, left alone (not a named exception); table_status_painter_test needed no change. Review dispatched (opus).
Task 3: review — spec ✅ (frame path, rebuild key, both mounts, dark predicate checked; two pumps inherent to the shell's async change stream), 1 Important (Review Focus 2's on-screen Delete→Undo leg missing; TF8's title claims it) → fix round 1.
Ruling 5: Review Focus 2 binds Task 3 although TF8's step text omitted the delete — the plan's Review Focus section assigns it to TF8 explicitly — costs, if wrong: one extra test leg.
Task 3: minor (deferred): theme_canvas_test.dart:37-38 fullTheme ('every field set') lacks tableColorOpacity; not a named exception — final review to triage.
Task 3: minor (deferred): the design-mount allocation bar lives in table_fill_test TF9, not table_status_painter_test as the constraint words it.
Task 3: minor (deferred): light→dark on the design mount not asserted directly (symmetric through _fillPaper).
Task 3: minor (deferred): the plan's 'one pump' wording for TF8/TF9 is wrong for the test binding (two: the async change stream, then the frame).
Task 3: fix round 1/5 (1 addressed, 0 open; commits 9cb886b..e59969f: TF8b deletes a coloured table by the Delete key and undoes it on screen; M-C24 dies on it)
Task 3: complete (commits ebd5d1a..e59969f, review clean)
Task 4: dispatched (BASE e59969f, implementer sonnet)
Task 4: implementer DONE (f0be47c); fixture imported from table_fill_test.dart; _flowsFor reads the opacity through a mounted-guarded _tableColorOpacity(); EX3b pins Print's PDF alpha; apps/floor_planner calls exportBytes/exportPdfBytes with the default opacity. Review dispatched (opus).
Task 4: minor (deferred, FINAL REVIEW TRIAGE): export_bytes.dart:43-44 the Export→PDF opacity wire is unpinned (no PDF export at a non-default opacity).
Task 4: minor (deferred, FINAL REVIEW TRIAGE): the pixel sample (650,50) mirrors to (650,-50), still inside the quad — a lost reflection would pass the end-to-end pixel tests (EX1's matrix check still kills it).
Task 4: minor (deferred): floor_plan_view.dart:528-531 the mounted guard untested (its value moot: the flow is cancelled).
Task 4: minor (deferred): table_color_export_test imports table_fill_test.dart's helpers; move the fixture to test/support/.
Task 4: complete (commits e59969f..f0be47c, review clean)
Task 5: dispatched (BASE f0be47c, implementer sonnet)
Task 5: implementer DONE (b31fc5c); M-PC9-tool killed (CP1 re-selects through the rig after W; CP11 selects a table under selectTool(wall) via controller.select); apps/floor_planner reported 211 tests (212 before) — named risk for the review. Review dispatched (sonnet).
Task 5: review — spec ✅; named risk (a) a reporting artefact (the reviewer ran apps/floor_planner at b31fc5c: +212); 1 Important (plan-mandated): _tables calls tablesOf(doc) on every Selection panel build, bypassing the panel's R-7 survey cache (every hover notification rescans the document, even with an empty selection) → fix round 1.
Ruling 6: the panel's R-7 contract (a hover notification must not rescan the document) outranks the plan's code sketch for _tables — CLAUDE.md's frame-rate discipline and the survey's own 'never per frame' contract bind; the fix makes the table check O(selection) — costs, if wrong: a few lines and one counter test.
Task 5: minor (deferred): color_picker_test.dart:13-20 header paragraph pasted twice; :2-3 header still says rooms; no blank line before CP7.
Task 5: minor (deferred): dropping only the _openingToolMode conjunct survives (no test selects under an opening tool); pre-existing.
Task 5: fix round 1/5 (1 addressed, 0 open; commits b31fc5c..20dd1ba: isTable per key through a shared _isServable; TableSurvey.surveys counter; CP12 pins no survey across hovers; the plan's tablesOf form red)
Task 5: minor (deferred, FINAL REVIEW TRIAGE): isTable is now public through lib/editor.dart's barrel (a new editor API name, not in the CHANGELOG).
Task 5: minor (deferred): TableSurvey.surveys is process-global and never reset (CP12 uses a delta).
Task 5: complete (commits f0be47c..20dd1ba, review clean)
Task 6: dispatched (BASE 20dd1ba, implementer sonnet)
Task 6: implementer DONE (fcdda26); every gate green (engine 1290 / GPU 20 exact, render the macOS pair only, planner 1983, symbols 97, floor_planner 212, demo 68, tool/ci 64, check_guide 53 blocks, host probe + v0.3.0/v0.4.0/v0.5.1); added a CHANGELOG bullet for editor.dart's isTable; dropped STATUS's tool-mode pin note (CP1 covers it). Review dispatched (sonnet).
Task 6: minor (deferred): host-guide design-changes bullet line over 80 columns (not reflowed).
Task 6: complete (commits 20dd1ba..fcdda26, review clean)
Final review: dispatched (opus) over c429735..fcdda26.
Final review: Ready after fixes — 1 Important (Export→PDF opacity wire unpinned, export_bytes.dart:43-44), Minors to fix: CHANGELOG (tables in tablesOnly/readOnly rows, table.invalid_color, editor.dart exportBytes/exportPdfBytes' tableColorOpacity), theme_canvas_test fullTheme, opacity validated in tableColorUnderlay, two false '/ID same length' comments, color_picker_test header; can stay: the non-triangulating-top difference (document it), the design-mode survey per document change. Frame path, dark canvas, canvas↔export, schema, host surface checked clean.
Final fix wave: dispatched (sonnet, BASE fcdda26).
Final fix wave: re-review — all 7 addressed (commits fcdda26..20558f9: EX3c pins the Export→PDF opacity, M-PC7-c red; CHANGELOG (a)(b)(c); fullTheme; opacity validated in tableColorUnderlay; the non-triangulating-top note; two comments; color_picker_test header).
Final fix wave: deferred minor: no direct readOnly-preset table-colour test (CP9/CP4 cover its pieces); exportBytes/exportPdfBytes' new ArgumentError not in the CHANGELOG bullet.
Slice 2: complete (c429735..20558f9). 31 named mutants plus M-PC7-c and the extras, all killed except M-C11 (engine-owned, TC8 its witness). Reviewer reports were delivered as messages, not files; their findings are recorded above.
