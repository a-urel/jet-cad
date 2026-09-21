# SDD ledger — plan: docs/superpowers/plans/2026-09-21-floor-planner-app-skeleton.md

Spec: docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md (revision 2). Branch `plan-01/app-skeleton` in worktree `.claude/worktrees/plan-01-app-skeleton`, cut from `main` at `717b9cd`.

## Baseline at the branch point (717b9cd)

- `apps/dev_harness_2d`: **82** tests, all pass (`flutter test --concurrency=1`). This is criterion 10's number.
- `packages/jet_cad_2d`: 798 pass.
- `packages/jet_cad_2d_flutter`: 663 pass, 1 skip, **5 fail** — all five rungs of `test/golden/text_ladder_golden_test.dart`, `Pixel test failed, 0.04%, 195px diff` (rung 1; the others alike). Goldens were recorded 2026-08-24 (`eb3f800`); the SDK is 3.47.2. STATUS.md:545 already records the golden suite as "NOT re-run" since 2026-08-29.
- `flutter pub get` rewrote `packages/jet_cad/analysis_options.yaml`; restored with `git checkout --`.

Ruling: the five text-golden failures are pre-existing Skia/SDK drift, out of this plan's scope — this plan's flutter-package bar is "663 pass, 1 skip, the same five golden failures and no other", recorded per task; re-recording goldens is a separate decision for the human — cost if wrong: a real text regression introduced by this plan hides behind the same five names (mitigated: the five are text-ladder rungs and this plan draws no text).

Ruling: Task 1 Step 1's `git worktree add ../jet-cad-plan-01` is replaced by the native worktree already created at `.claude/worktrees/plan-01-app-skeleton` on `plan-01/app-skeleton` — same branch, harness count measured above — cost if wrong: none.

## Pre-flight conflict scan

| pair / task | produces vs consumes | found |
|---|---|---|
| T1 → T3, T8 | `CameraController(initial, {minScale, maxScale})` | fixture and shell call it with that shape — consistent |
| T2 → T3, T4, T5, T8, T9 | `GesturePolicy.{wheelZooms, wheelPans, mouseWheel, wheelZoomStep, panButtons, forBrowser, forPlatform}` | every consumer uses those names; M-01q mutates `forBrowser` — consistent |
| T3 → T4 → T5 | one `Listener` in `camera_gesture_detector.dart`, each task adds one handler | additive, sequential — consistent |
| T3 fixture → T4, T5 | `fitOffOrigin, pumpDetector, screenOf, globalFocus, kLocalFocus, kWorldProbe, kDetectorSize` | used with those names — consistent |
| T6 → T7, T8 | app pubspec deps (`jet_cad_2d`, `jet_cad_2d_flutter`, `vector_math`) | `vector_math` unused by T7/T8 sources — harmless (no unused-dep lint) |
| T7 → T8 | `startupPlan, kMinScale, kMaxScale, kPlanOriginX/Y, kPlanWidth/Height` | consistent |
| T9 rows vs T1/T3/T4/T5 code | each edit names a line that exists in the task's code block | M-01c's `Offset(200, 150)` is the 400×300 box centre in local coords — consistent |
| T1 self | tests vs code: bounds tests expect landing within `Tolerance`, silent second push | code has both — consistent |
| T3 self | drifting-pinch expectation | fixed in plan self-review; matches pan-then-zoom order in code |
| T4 self | modifier test expects zoom under both policies | code checks modifier first — consistent |
| T6 self | `flutter_lints ^6.0.0` vs generated | plan says keep generated — no conflict |
| T8 self | shell test reads `PlannerView.document/camera` | fields are public finals — consistent |
| Global vs T6 | "never commit analysis_options rewrite" vs committing the app's generated file | Ruling 01-1 in the plan covers it |
| Rubric vs plan | any test asserting nothing? | T5's left/right-button tests assert `same(before)` — they assert; no verbatim logic duplication mandated |

Scan clean apart from the two rulings above.

## Tasks
Task 1: minor (deferred): no test pins the tolerance-tie boundary of the second clamp check (`> 0` vs `>= 0` on `compare(current * f, maxScale)`); a mutant there would likely survive.
Task 1: complete (commits 717b9cd..8b6194d, review clean)
Task 2: complete (commits 8b6194d..4e98999, review clean; reviewer's ⚠️ on the jet_cad_2d gate resolved by the baseline: 798 green, package untouched)
Task 3: minor (deferred): no test isolates the `scale == _gestureZoom` short-circuit on a non-first update (a repeated identical scale mid-gesture must not call zoomAt again).
Task 3: minor (deferred): no test isolates the `Offset.zero` pan skip on a non-first, zero-pan update.
Task 3: complete (commits 4e98999..be97169, review clean; concerns were a test-count wobble and whitespace-only formatting)
Task 4: Ruling: the spec's `enum ScrollAction` collides with Flutter's exported `class ScrollAction` (`widgets/scrollable_helpers.dart:410`); a consumer importing `material.dart` and this package cannot name the enum unqualified — renamed to `ScrollSignalAction` in `gesture_policy.dart`, the widget and the tests, and the `hide ScrollAction` workaround removed; spec and plan text updated in Task 10's owed-lines step — cost if wrong: a name the spec did not choose, one rename to undo.
Task 4: minor (deferred): no test combines a trackpad-kind scroll with a modifier held (precedence says zoom).
Task 4: fix round 1/5 (1 addressed pending re-review — ScrollAction renamed to ScrollSignalAction, hide clause removed; commits ed6dc24..36711e5)
Task 4: complete (commits be97169..36711e5, review clean after fix round 1)
Task 5: minor (deferred): no test for a button chord (middle | left) — the `!= 0` guard pans; untested.
Task 5: complete (commits 36711e5..6a4c494, review clean)
Task 6: Ruling: `flutter create` (Flutter 3.47.2) generates a `lib/main.dart` using dot-shorthand syntax that needs Dart 3.13, and the brief's `sdk: ^3.5.0` (the workspace floor) disables it — the generated counter app is replaced by a minimal placeholder `main.dart` at language 3.5 rather than raising the app's floor above every other member; Task 8 overwrites the file — cost if wrong: none beyond Task 8 (which was always going to replace it).
Task 6: complete (commits 6a4c494..472c46e, review clean after the unblock ruling; reviewer's ⚠️ on screenRect and lockfile ignores resolved: environment-dependent nib value, `*.lock` is gitignored)
Task 7: Ruling: the brief's `${kMinScale}` / `${kMaxScale}` interpolation braces raise two `unnecessary_brace_in_string_interps` infos; "analyze clean" means `No issues found!` at every severity in this repo, so the braces go (fix round 1) — cost if wrong: none.
Task 7: minor (deferred): seven furniture `p.rect` calls repeat `lineweight: 25, color: _furnitureColor`; a `furniture()` wrapper would remove it.
Task 7: minor (deferred): the front door opens into the kitchen band, not a hall — plausibility nit for the human's look.
Task 7: fix round 1/5 (1 addressed pending re-review — interpolation braces dropped, analyze No issues found; commits 38d8c9b..5dadd17)
Task 7: complete (commits 472c46e..5dadd17, review clean after fix round 1; count 523; STARTUP fit scale 0.095 px/mm, 95x out, 1052.6x in)
Task 8: minor (deferred, plan-mandated): chrome-slot test asserts only width > 0, not the 44/240/280 sizes.
Task 8: minor (deferred, plan-mandated): no test drives a second layout to exercise the `_fitted` guard; verified by reading.
Task 8: complete (commits 5dadd17..7fcc400, review clean; web build of the package succeeded — criterion 2; the macOS look is Task 10's)
Task 9: Ruling: M-01b survived because the pinch witness sends a constant cumulative scale (1.5 × 3) and the widget's exact-equality guard (Ruling 01-4) lets only the first update through — a degenerate fixture; the test now ramps 1.2 → 1.5 → 2.0 and expects 2.0 (the mutant compounds to 3.6); widget unchanged; spec M-01b wording updated in Task 10 — cost if wrong: none; the ramp is the realistic gesture.
Task 9: fix round 1/5 dispatched (M-01b re-fire after the fixture fix)
Task 9: fix round 1/5 (M-01b killed after the ramped-pinch fixture fix; commits 98b5d69..5cab91a)
Task 9: minor (deferred): the log lacks Plan F's closing pointer to the gate run in the task report.
Task 9: complete (commits 7fcc400..5cab91a, review clean after fix round 1; 16 fired / 16 killed / 1 equivalent)
Task 10: minor (deferred): the note's self-review misdescribes which spec edit spans two hunks; the note omits Plan F's one-paragraph 'shipped' summary.
Task 10: fix round 1/5 dispatched (Ruling 01-3 misstated in the note and STATUS; header commit range)
Task 10: fix round 1/5 (rulings restated verbatim, commit range corrected; commits b6d64a9..531998a) — re-review pending
Task 10: Ruling: the human look (brief Steps 1-2) cannot be performed by a subagent; the results note records every criterion-12 item OWED and the gate as 11 of 12 — cost if wrong: none; the look happens when the branch is presented.
Task 10: complete (commits 5cab91a..531998a, review clean after fix round 1)

## Final review
Final review (opus, 717b9cd..531998a): With fixes. Important: (1) criterion 11 reported PASS 'all exit 0' while jet_cad_2d_flutter's flutter test exits 1 on the five baseline goldens — reword; (2) zoom arm on a scroll signal with dy == 0 (horizontal wheel) zooms out by 1/1.1 — guard, witness, spec D3 amendment; (3) Ruling 01-2's _fitted latch has no witness — resize test. Minors folded into the fix wave: (4) unbounded lower early return fires at scale <= 1e-9 (minScale > 0.0 qualifier); (5) button pan uses event.delta not localDelta. Deferred-minor triage: only T8's second-layout item must be fixed (= Important 3); all others leave. Rulings: all stand.
Final fix wave dispatched (one implementer, fix base 531998a)
Final fix wave: 5 commits 531998a..29b75cd (gate row reworded; dy==0 guard + M-01r; resize witness + M-01s; minScale > 0 qualifier; localDelta) — scoped re-review pending
Final fix wave re-review: all 5 addressed, no new breakage. Parked — M-01r's log tail omits the Expected: line — Ruling: the fuller transcript is in final-fix-report.md and the Actual/summary lines match it; not re-dispatched — cost if wrong: a cosmetic gap in one log row.
Final review: complete at 29b75cd
