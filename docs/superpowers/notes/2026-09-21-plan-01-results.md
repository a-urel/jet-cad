# Plan 01 — the app skeleton: results

**Plan:** [2026-09-21-floor-planner-app-skeleton.md](../plans/2026-09-21-floor-planner-app-skeleton.md).
**Spec:** [2026-09-21-floor-planner-app-skeleton-design.md](../specs/2026-09-21-floor-planner-app-skeleton-design.md)
(revision 2), D1–D8, the gesture table, the clamp, the startup document, the
window, the eleven gate commands, all sixteen named mutants and E-01e′.
**Mutation log:** [plan-01-mutation-log.md](plan-01-mutation-log.md).
**Branch:** `plan-01/app-skeleton`, worktree
`.claude/worktrees/plan-01-app-skeleton`, cut from `main` at `717b9cd`. **Ten
tasks done, `717b9cd..b6d64a9` (Tasks 1–9 at `..5cab91a`; Task 10, this note,
at `b6d64a9` and its fix). NOT merged — the merge is the human's
decision, after the look this note leaves OWED.**
**Ledger (per-task briefs, reports, review diffs, every ruling):**
`.superpowers/sdd/2026-09-21-floor-planner-app-skeleton/`.

---

## What this plan's own premises measured false

Four corrections. No threshold was moved to make a criterion pass; each is
recorded with the task that found it.

1. **`flutter create`'s generated `main.dart` does not compile at this
   workspace's language floor.** Task 6's brief expected the generated
   counter app to stand as a placeholder until Task 8. Flutter 3.47.2
   generates a `lib/main.dart` using dot-shorthand syntax that needs Dart
   3.13, and the brief's `sdk: ^3.5.0` (the workspace floor) disables it.
   Raising the app's floor above every other workspace member to keep one
   throwaway file was rejected; the generated file was replaced by a minimal
   placeholder at language 3.5, which Task 8 overwrites anyway (ledger,
   Task 6).
2. **The spec's `enum ScrollAction` collides with a Flutter export.**
   `widgets/scrollable_helpers.dart:410` already exports a class named
   `ScrollAction`; a consumer importing `material.dart` alongside this
   package could not name the enum unqualified. Renamed to
   `ScrollSignalAction` throughout `gesture_policy.dart`, the widget and the
   tests, and the spec's `hide ScrollAction` workaround removed rather than
   kept (ledger, Task 4; spec corrected in this task's Step 4).
3. **The pinch witness was a degenerate fixture, and M-01b survived it on
   the first shot.** The witness sent the same cumulative `scale: 1.5`
   three times; the widget's own exact-equality coalescing guard
   (`if (scale == _gestureZoom) return;`, Ruling 01-4) let only the first
   update ever reach `zoomAt`, where the running denominator is always
   `1.0` by construction — the mutant and the original therefore produced
   the identical number. Fixed by ramping the witness's cumulative scale
   through three different values (`1.2 → 1.5 → 2.0`) and asserting the
   ramp's landing ratio (`2.0`) rather than the repeated value's own
   product (`3.6`); re-fired, M-01b is now KILLED (ledger, Task 9, fix
   round 1).
4. **The brief's own test file tripped the analyzer it was meant to
   satisfy.** `${kMinScale}` / `${kMaxScale}` in `startup_plan_test.dart`'s
   `print` raised two `unnecessary_brace_in_string_interps` infos.
   "Analyze clean" in this repository means `No issues found!` at every
   severity, so the braces were dropped (`$kMinScale` / `$kMaxScale`);
   nothing else in the line changed (ledger, Task 7, fix round 1).

---

## What was measured

### Harness

The branch-point count and the head count are the same, and no file under
`apps/dev_harness_2d` differs from the branch point
(`git diff --stat 717b9cd..HEAD -- apps/dev_harness_2d` is empty, confirmed
in this task):

| | branch point (`717b9cd`) | head (`5cab91a`) |
|---|---|---|
| `apps/dev_harness_2d` | **82** | **82** |

(Task 9 report, gate line 3.)

### The three suites and the app, at the head

| suite | count |
|---|---|
| `jet_cad_2d` | **798** pass |
| `jet_cad_2d_flutter` | **702** pass, 1 skip, and the same five pre-existing failures in `test/golden/text_ladder_golden_test.dart` (0.04% pixel drift, goldens from 2026-08-24, SDK 3.47.2) — the ledger's baseline ruling, not this plan's regression |
| `apps/floor_planner` | **7** tests, both builds `✓ Built` |

(`jet_cad_2d` and `jet_cad_2d_flutter` counts and the golden-drift wording
from the ledger's baseline section and Task 9's report; `floor_planner`'s 7
tests and both `✓ Built` lines from the Task 9 report's fourth gate block.)

### The startup document (D5) and the clamp check (D4)

Entity count **523**, within the 500–1,000 band (Task 7 report). The
`STARTUP` line, verbatim, from `startup_plan_test.dart`'s fourth test:

```
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
```

(Task 7 report.) Read as the two clamp ratios D4 asked to be checked and
recorded: at 1440×900 the fitted scale is **0.095 px/mm**, with **95.0×**
headroom out to `kMinScale = 0.001` and **1052.6×** headroom in to
`kMaxScale = 100.0`. Both constants are unchanged; this is the sanity check
D4 owed against the startup document's actual units, not a new number.

### The first web build

`flutter build web` for `apps/floor_planner` is the first time
`jet_cad_2d_flutter` has ever been compiled for web with the package
actually imported (spec D6, criterion 2). Tail, pasted from the Task 8
report:

```
Compiling lib/main.dart for the Web...
Wasm dry run succeeded. Consider building and testing your application with the `--wasm` flag. See docs for more info: https://docs.flutter.dev/platform-integration/web/wasm
Use --no-wasm-dry-run to disable these warnings.
Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons). This usually means you are referring to font families in an IconData class but not including them in the assets section of your pubspec.yaml, are missing the package that would include them, or are missing "uses-material-design: true".
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7736 bytes (99.5% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Compiling lib/main.dart for the Web...                             23.6s
✓ Built build/web
```

And `flutter build macos --debug`'s tail, from the same report:

```
Building macOS application...
✓ Built build/macos/Build/Products/Debug/floor_planner.app
```

The `cupertino_icons` font warning is a standard tree-shaking notice,
unrelated to the package under test, not an error.

---

## The look — OWED, itemised

**No human looked at the running app in this session.** This task ran in a
headless sandbox, as a subagent, with no display, no `flutter run`, no
browser. Every item below is listed verbatim from the brief's Steps 1 and 2
and marked as its controller ruled: **OWED — not looked at; the human looks
after this branch is presented.** Nothing here is "seen", "not seen" or
"could not judge" — those verdicts require an eye, which this session did
not have.

### Step 1: macOS

`cd apps/floor_planner && flutter run -d macos --profile`.

1. A two-finger scroll pans; the drawing follows the fingers with no drift
   and no stick, and does not change size. **OWED — not looked at; the
   human looks after this branch is presented.**
2. A pinch zooms and the point between the fingers stays put. **OWED — not
   looked at; the human looks after this branch is presented.**
3. A mouse-wheel notch zooms under the cursor, not about the window centre
   (cursor near a corner). **OWED — not looked at; the human looks after
   this branch is presented.**
4. Zoom in past the maximum and out past the minimum: the view comes to
   rest without a jump and does not creep. **OWED — not looked at; the
   human looks after this branch is presented.**
5. A two-finger scroll with cmd held still pans (D3, desktop row). **OWED —
   not looked at; the human looks after this branch is presented.**
6. A middle-button drag pans; a left-button drag does nothing. **OWED — not
   looked at; the human looks after this branch is presented.**
7. The walls close; every door swings into a room; the tile grids are
   square. **OWED — not looked at; the human looks after this branch is
   presented.**

### Step 2: Browser — Chrome or Safari, then Firefox

`cd apps/floor_planner && flutter run -d chrome --release`, then the same
`flutter build web` served from `build/web` and opened in Firefox.

1. Chrome/Safari: a two-finger trackpad scroll pans and a mouse-wheel notch
   zooms. Firefox: both pan. **OWED — not looked at; the human looks after
   this branch is presented.**
2. A trackpad pinch zooms about the pointer (both). **OWED — not looked at;
   the human looks after this branch is presented.**
3. ctrl+wheel zooms and does not zoom the page (both), noting which machine
   and browser for the real ctrl+wheel `HardwareKeyboard` path on a Mac
   browser. **OWED — not looked at; the human looks after this branch is
   presented.**
4. A ctrl+wheel notch with a mouse, judged for coarseness (spec D3, ≈1.65×
   on Windows/Linux browsers; the 1.1× path on macOS). **OWED — not looked
   at; the human looks after this branch is presented.**
5. A middle-button drag pans and does not start the browser's autoscroll.
   **OWED — not looked at; the human looks after this branch is
   presented.**
6. The bounds come to rest without a jump. **OWED — not looked at; the
   human looks after this branch is presented.**

The heuristic's misclassification, if seen, is likewise **OWED — not
looked at; the human looks after this branch is presented.**

Exit-gate criterion 12 is therefore **OWED**, not PASS.

**Addendum, 2026-09-21, after the merge (`bae5f73`).** The human ran the
app on macOS from `main` (`flutter run -d macos`, debug) and judged the
Step 1 look as a whole: **LGTM**. The seven Step 1 items were not itemised
by the human, so they stay listed above as written; the verdict of record
is the whole-run LGTM. Step 2 (Chrome or Safari, then Firefox on
`build/web`) has not been looked at and stays OWED. Criterion 12 is
therefore **half discharged**: macOS seen, browsers OWED.

**Second addendum, 2026-09-21, later the same day.** The human then looked
in both browser families from `main`: Chrome via `flutter run -d chrome
--release`, and Firefox on the same `build/web` served statically
(`python3 -m http.server`). Both judged as a whole: **LGTM**. The six Step 2
items were not itemised by the human; the verdict of record is the
whole-run LGTM per browser. Criterion 12 is now **fully discharged**:
macOS, Chrome and Firefox all seen. The heuristic's misclassification was
not reported.

---

## Mutation summary

**Sixteen named mutations (M-01a..M-01q, M-01h struck by spec) fired: 16
killed, 0 survived. M-01b survived on the first shot** — a degenerate
fixture, the pinch witness sending a repeated, non-rising cumulative
`scale` — **and was killed after the fixture fix in round 1**, which ramps
the pinch witness's cumulative scale `1.2 → 1.5 → 2.0`. **One
spec-declared-equivalent mutation, E-01e′** (the `gesture_policy.dart`
`forPlatform` mutant: `kIsWeb` is compile-time `false` on the VM, so
`forPlatform()`'s branch never changes under `flutter test`) **fired and
its green run recorded.** Full transcripts: `plan-01-mutation-log.md`.

| id | verdict |
|---|---|
| M-01a | KILLED |
| M-01b | KILLED (round 1) — SURVIVED on the first shot (degenerate fixture), re-fired against the ramped witness |
| M-01c | KILLED |
| M-01d | KILLED |
| M-01e | KILLED |
| M-01f | KILLED |
| M-01g | KILLED |
| M-01i | KILLED |
| M-01j | KILLED |
| M-01k | KILLED |
| M-01l | KILLED |
| M-01m | KILLED |
| M-01n | KILLED |
| M-01o | KILLED |
| M-01p | KILLED |
| M-01q | KILLED |
| E-01e′ | EQUIVALENT (declared, spec D2) — fired, green run recorded |

(Verdicts and totals from `plan-01-mutation-log.md`'s Summary section and
the Task 9 report.)

---

## Rulings

Every ruling made on this plan, verbatim from the ledger and the plan
document.

**The plan's own rulings**, from the plan document's "Rulings made here
rather than left to an implementer" section, quoted.

- **Ruling 01-1** — the app's `analysis_options.yaml` is committed once, at
  scaffold, and never again. The spec's architecture block says "generated
  and NOT committed"; what `CLAUDE.md`'s "never commit
  `analysis_options.yaml`" has always meant in this repo is never commit
  the rewrite `flutter pub get` makes to a tracked one.
- **Ruling 01-2** — the first fit happens at the real viewport, once. The
  spec says the app "shows the startup plan"; it does not say who fits the
  camera — `PlannerShell` constructs the camera fitted to a nominal
  1440×900, and `PlannerView` re-fits it once, on its first layout, to the
  size it actually got.
- **Ruling 01-3** — the bound decisions use `Tolerance.standard` (linear
  `1e-9`), a `static const` in `camera_controller.dart`, not a constructor
  parameter. The spec says `Tolerance`; it does not say which, and a scale
  between `0.001` and `100` sits where `1e-9` is many ulps wide and far
  below anything a gesture produces.
- **Ruling 01-4** — a `PointerPanZoomUpdate` whose `scale` equals the
  running value does not call `zoomAt`. A two-finger scroll reports
  `scale == 1.0` on every update; calling `zoomAt(anchor, 1.0)` would build
  a new transform and notify for nothing — the check is exact `==` on a
  stored event field (spec invariant 6).

**Rulings made during execution.**

- **The golden-baseline ruling** (ledger, baseline section) — the five
  text-golden failures in `jet_cad_2d_flutter` are pre-existing Skia/SDK
  drift (goldens recorded 2026-08-24, SDK 3.47.2), out of this plan's
  scope; this plan's flutter-package bar is "702 pass, 1 skip, the same
  five golden failures and no other," recorded per task; re-recording
  goldens is a separate decision for the human.
- **The worktree ruling** (ledger, baseline section) — Task 1 Step 1's
  `git worktree add ../jet-cad-plan-01` is replaced by the native worktree
  already created at `.claude/worktrees/plan-01-app-skeleton` on
  `plan-01/app-skeleton` — same branch, harness count measured above; cost
  if wrong: none.
- **Task 4's rename** — the spec's `enum ScrollAction` collides with
  Flutter's exported `class ScrollAction`
  (`widgets/scrollable_helpers.dart:410`); a consumer importing
  `material.dart` and this package cannot name the enum unqualified —
  renamed to `ScrollSignalAction` in `gesture_policy.dart`, the widget and
  the tests, and the `hide ScrollAction` workaround removed; spec and plan
  text updated in this task's Step 4; cost if wrong: a name the spec did
  not choose, one rename to undo.
- **Task 6's placeholder `main.dart`** — `flutter create` (Flutter 3.47.2)
  generates a `lib/main.dart` using dot-shorthand syntax that needs Dart
  3.13, and the brief's `sdk: ^3.5.0` (the workspace floor) disables it —
  the generated counter app is replaced by a minimal placeholder
  `main.dart` at language 3.5 rather than raising the app's floor above
  every other member; Task 8 overwrites the file; cost if wrong: none
  beyond Task 8 (which was always going to replace it).
- **Task 7's interpolation-brace ruling** — the brief's `${kMinScale}` /
  `${kMaxScale}` interpolation braces raise two
  `unnecessary_brace_in_string_interps` infos; "analyze clean" means
  `No issues found!` at every severity in this repo, so the braces go (fix
  round 1); cost if wrong: none.
- **Task 9's M-01b fixture ruling** — M-01b survived because the pinch
  witness sends a constant cumulative scale (1.5 × 3) and the widget's
  exact-equality guard (Ruling 01-4) lets only the first update through — a
  degenerate fixture; the test now ramps 1.2 → 1.5 → 2.0 and expects 2.0
  (the mutant compounds to 3.6); widget unchanged; spec M-01b wording
  updated in this task's Step 4; cost if wrong: none — the ramp is the
  realistic gesture.
- **This task's OWED-look ruling** — Steps 1 and 2 of the brief (running
  the app on macOS and in two browser families and judging it by eye)
  cannot be performed by a subagent in a headless sandbox; every item is
  recorded **OWED — not looked at; the human looks after this branch is
  presented**, and exit-gate criterion 12 is OWED, not PASS.

---

## Deferred

Every `minor (deferred)` line from the ledger, verbatim.

- Task 1: no test pins the tolerance-tie boundary of the second clamp check
  (`> 0` vs `>= 0` on `compare(current * f, maxScale)`); a mutant there
  would likely survive.
- Task 3: no test isolates the `scale == _gestureZoom` short-circuit on a
  non-first update (a repeated identical scale mid-gesture must not call
  `zoomAt` again).
- Task 3: no test isolates the `Offset.zero` pan skip on a non-first,
  zero-pan update.
- Task 4: no test combines a trackpad-kind scroll with a modifier held
  (precedence says zoom).
- Task 5: no test for a button chord (middle | left) — the `!= 0` guard
  pans; untested.
- Task 7: seven furniture `p.rect` calls repeat `lineweight: 25, color:
  _furnitureColor`; a `furniture()` wrapper would remove it.
- Task 7: the front door opens into the kitchen band, not a hall —
  plausibility nit for the human's look.
- Task 8: chrome-slot test asserts only width > 0, not the 44/240/280
  sizes (plan-mandated).
- Task 8: no test drives a second layout to exercise the `_fitted` guard;
  verified by reading (plan-mandated).
- Task 9: the log lacks Plan F's closing pointer to the gate run in the
  task report.

---

## Exit gate

Pre-committed in the spec. No threshold was moved to make a criterion
pass.

| # | criterion | verdict |
|---|---|---|
| 1 | `apps/floor_planner` builds and runs on macOS and shows the startup plan, non-empty, off-origin | **PASS** — `flutter build macos --debug` `✓ Built` (Task 8/9 reports); `planner_shell_test.dart`'s off-origin/non-empty test green |
| 2 | `flutter build web` succeeds — first web build of `jet_cad_2d_flutter` ever attempted | **PASS** — `✓ Built build/web` (Task 8 report, pasted above) |
| 3 | Desktop trackpad two-finger scroll pans and does not zoom, from a non-identity transform | **PASS** — `camera_gesture_trackpad_test.dart` green |
| 4 | Pinch zooms about the anchor, cumulative handling correct | **PASS** — same file, M-01b killed after the round-1 fixture fix |
| 5 | Mouse wheel zooms 1.1× per notch about the pointer | **PASS** — `camera_gesture_signal_test.dart` green |
| 6 | Scroll signals: trackpad-kind pans under both policies; mouse-kind zooms under `wheelZooms`/pans under `wheelPans`; direction asserted; modifier zooms under both; `PointerScaleEvent` compounds; `forBrowser` answers both ways | **PASS** — signal test green, M-01e/M-01f/M-01g/M-01m/M-01n/M-01p/M-01q all killed |
| 7 | Middle-button drag pans on both policies; left does nothing on either | **PASS** — `camera_gesture_button_test.dart` green, M-01i killed |
| 8 | Camera rests on `minScale`/`maxScale` within `Tolerance` from one oversized zoom each way; a second push notifies no listener | **PASS** — `camera_controller_test.dart` green, M-01j/M-01k/M-01l/M-01o killed |
| 9 | All sixteen mutants fired and killed, E-01e′ fired and recorded equivalent | **PASS** — 16 killed (M-01b after round-1), E-01e′ equivalent (mutation log) |
| 10 | Harness passes at its branch-point count; `git diff --stat main..HEAD -- apps/dev_harness_2d` empty | **PASS** — 82 at branch point, 82 at head; diff empty (verified in this task) |
| 11 | All eleven gate commands exit 0; no `analysis_options.yaml` rewrite after Task 6's | **PASS with one recorded exception** — ten commands exit 0; `jet_cad_2d_flutter`'s `flutter test` exits 1 on the five pre-existing `text_ladder_golden_test.dart` failures, per the baseline ruling (golden drift from 2026-08-24, SDK 3.47.2), and on nothing else; `git status --short` clean in this task except the five files this commit carries |
| 12 | A human looked, on macOS and in both browser families, and each item recorded seen/not seen/could not judge | **PASS (after the merge) — macOS, Chrome and Firefox each looked at on 2026-09-21, whole-run verdict LGTM per platform; items not itemised (see the two addenda above)** |

**12 of 12 PASS** (criterion 12 discharged after the merge, on 2026-09-21: macOS, Chrome and Firefox LGTM). No criterion is a MISS.

---

## Files this task touched

- `docs/superpowers/notes/2026-09-21-plan-01-results.md` — this file.
- `docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md` —
  D4's check recorded, Ruling 01-1's line corrected, `ScrollAction` →
  `ScrollSignalAction` throughout, M-01b's wording corrected, one open
  question struck.
- `roadmap/00-README.md` — the 01 row's Executed column.
- `roadmap/01-app-skeleton.md` — the status line.
- `STATUS.md` — a Plan 01 section and the Resume-here paragraph about
  sub-project 01.
