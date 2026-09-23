# Plan 03 — grips and transform: results

**Plan:** [2026-09-23-grips-and-transform.md](../plans/2026-09-23-grips-and-transform.md).
**Spec:** [2026-09-23-grips-and-transform-design.md](../specs/2026-09-23-grips-and-transform-design.md)
(revision 2, amended at execution 2026-09-23 — see "Spec amendments" below).
**Mutation log:** [plan-03-mutation-log.md](plan-03-mutation-log.md).
**Branch:** `plan-03/grips-and-transform`, worktree
`.claude/worktrees/plan-03-grips-and-transform`, cut from `main` at `e376ced`.
**Twelve tasks: Tasks 1–11 at `e376ced..7879e36`; Task 12 (the gate lines,
this note, the spec amendments, STATUS and the roadmap) on top of them.
Executed on `plan-03/grips-and-transform`, not merged — the merge is the
human's decision. The final whole-branch review ran at `136af89` ("With
fixes"); its fix wave is `722904b` (tests), `0cac4f4` (the shift mid-drag
fix), `509b9f3` (a doc comment) and a docs commit. The ledger is archived
after the fix wave's re-review, as the branch's last commit before the merge
(Ruling T12-a). Exit gate 15 of 16; criterion 16, the human's look, is
OWED.**
**Ledger (per-task briefs, reports, review diffs, every ruling):**
`.superpowers/sdd/2026-09-23-grips-and-transform/` (git-ignored while the
plan is in flight; archived to
`docs/superpowers/ledgers/2026-09-23-grips-and-transform/` before the merge).

---

## What was measured

### The four gate lines, pasted

Run once, in full, on the final tree of Tasks 1–11 (HEAD `7879e36`, `git
status --short` clean), by one script that ran each command in its package
directory and appended its exit code. Ruling T11-a moved Task 11's gate run
here, so this was the only full four-line run on the branch until the final
fix wave's, pasted in the next subsection. Every
summary line below is what the command printed.

**`packages/jet_cad_2d`**: `CI=true dart test`:

```
00:03 +890: All tests passed!
```

Exit 0. `dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 130
files (0 changed) in 0.23 seconds.` Exit 0.

**`packages/jet_cad_2d_flutter`**: `CI=true flutter test`:

```
00:12 +851 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Exit 1. **851 pass, 1 pre-existing skip, and exactly the five pre-existing
`text_ladder_golden_test.dart` failures named above (`text ladder rung
1..5`, `RenderBackend.canvas`), and nothing else.** The paths are shortened
here. The run printed them in full under the worktree, and no other file
appears in the failing list. The Plan 01 baseline ruling stands, as it did
through Plans 02 and 04: the goldens were recorded on 2026-08-24 on SDK
3.47.2, and the difference is pixel drift, not a regression. `flutter
analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.5s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 159
files (0 changed) in 0.29 seconds.` Exit 0.

**`apps/dev_harness_2d`**: `CI=true flutter test --concurrency=1`:

```
00:20 +82: All tests passed!
```

Exit 0: **82 tests**, the same as at the branch point. This plan does not
touch the harness (`git diff --stat main..HEAD -- apps/dev_harness_2d` is
empty; Task 11 pasted it in the mutation log). `flutter analyze`:

```
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 22
files (0 changed) in 0.05 seconds.` Exit 0.

**`apps/floor_planner`**: `CI=true flutter test`:

```
00:01 +26: All tests passed!
```

Exit 0: **26 tests**. `flutter analyze`:

```
Analyzing floor_planner...
No issues found! (ran in 0.9s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 8
files (0 changed) in 0.03 seconds.` Exit 0. `flutter build macos --release`:

```
Building macOS application...
Xcode 27 no longer requires macOS binaries to support the x86_64 architecture. To build ARM-only macOS apps now, run: "flutter config --enable-macos-arm64-only". This will become the default behavior in a future Flutter release.
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.1MB)
```

Exit 0. `flutter build web --release`:

```
Compiling lib/main.dart for the Web...
Wasm dry run succeeded. Consider building and testing your application with the `--wasm` flag. See docs for more info: https://docs.flutter.dev/platform-integration/web/wasm
Use --no-wasm-dry-run to disable these warnings.
Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons). This usually means you are referring to font families in an IconData class but not including them in the assets section of your pubspec.yaml, are missing the package that would include them, or are missing "uses-material-design: true".
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7736 bytes (99.5% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Compiling lib/main.dart for the Web...                             24.4s
✓ Built build/web
```

Exit 0. **Both builds printed `✓ Built`.** The `cupertino_icons` font
warning, the Wasm dry-run note and the Xcode arm64 note are informational.
None of them fails the build.

Each `flutter` command printed a `pub get` banner (`Got dependencies`, with
10 packages that have newer incompatible versions). `git status --short` was
clean before the run and clean after it. **No `analysis_options.yaml` was
rewritten, so none needed restoring.**

The startup clamp line printed by `startup_plan_test.dart` is the same as in
Plans 01, 02 and 04:

```
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
```

### The four gate lines again, after the final fix wave

Run in full on HEAD `509b9f3` (the fix wave's last code commit; only docs
follow it), `git status --short` clean before and after, one package at a
time, each command's exit code captured. The summary lines, as printed:

- **`packages/jet_cad_2d`**: `00:03 +890: All tests passed!` (exit 0);
  `dart analyze`: `No issues found!` (exit 0); `dart format`: `Formatted 130
  files (0 changed) in 0.23 seconds.` (exit 0).
- **`packages/jet_cad_2d_flutter`**: `00:12 +854 ~1 -5: Some tests failed.`
  (exit 1), the failing list being exactly `text ladder rung 1` … `rung 5`
  `(RenderBackend.canvas)` in `test/golden/text_ladder_golden_test.dart`;
  `flutter analyze`: `No issues found! (ran in 1.4s)` (exit 0); `dart
  format`: `Formatted 159 files (0 changed) in 0.30 seconds.` (exit 0).
  **854 = 851 + the fix wave's three new tests** (M-03bj, M-03bk, M-03bl);
  M-03bh and M-03bi extended P2 and P4 in place.
- **`apps/dev_harness_2d`**: `00:19 +82: All tests passed!` (exit 0);
  `No issues found! (ran in 1.0s)` (exit 0); `Formatted 22 files (0
  changed) in 0.05 seconds.` (exit 0).
- **`apps/floor_planner`**: `00:01 +26: All tests passed!` (exit 0); `No
  issues found! (ran in 0.9s)` (exit 0); `Formatted 8 files (0 changed) in
  0.03 seconds.` (exit 0); `✓ Built
  build/macos/Build/Products/Release/floor_planner.app (51.1MB)` (exit 0);
  `✓ Built build/web` (exit 0).

No `analysis_options.yaml` was rewritten.

### Where the counts differ from the plan's sums, and why

The plan's Task 12 predicted each count as the branch point plus the tests
this plan lands. The branch point was engine 862, render layer 797 + 1 skip
+ the five goldens, harness 82 and app 21 (Task 1's run, recorded in the
ledger). Three suites ran more tests than predicted. The difference is the
tests that the reviews added. No planned test is missing, and each step is
visible in the task reports.

| suite | branch point | planned additions | planned total | ran | difference |
|---|---|---|---|---|---|
| `jet_cad_2d` | 862 | +11 (grips) +6 (rigid) +9 (drag snap) | 888 | **890** | **+2** |
| `jet_cad_2d_flutter` | 797 | +1 (O1) +7 (C) +1 (I1) +11 (D) +19 (T, W) +6 (P) +1 (K1) | 843 | **851** | **+8** |
| `dev_harness_2d` | 82 | 0 | 82 | **82** | 0 |
| `floor_planner` | 21 | +4 (A1–A4) | 25 | **26** | **+1** |

- **Engine, +2: Task 10's addendum.** It added two tests:
  - `grips_test.dart`'s `an arc end stretch landing within tolerance of a
    full turn is degenerate (M-03ay)`;
  - `drag_snap_test.dart`'s `a reused DragPoint clears objectKind and grid
    between calls (M-03az)`.

  The step-by-step counts were 862 → 873 (Task 1) → 879 (Task 2) → 888
  (Task 3) → 890 (Task 10).
- **Render layer, +8.** Two sources:
  - **Task 7's fix round added 3 tests** (Rulings T7-a and T7-b):
    - the two cursor-lifecycle tests in `interaction_cursor_test.dart`
      (`didUpdateWidget`, and reparenting through a `GlobalKey`);
    - the stale-press test, `a grip or a box gone between the press and the
      slop leaves the press a click`.

    The round's other two fixes, the listener leak and the centre grip's
    base, strengthened T14 and T8 in place and added no test.
  - **Task 10's addendum added 5 tests**:
    - `grip_cache_test.dart`: M-03ba and M-03bb;
    - `select_tool_drag_test.dart`: M-03be;
    - `selection_overlay_grips_test.dart`: M-03bf/M-03bf′ (one test) and
      M-03bg.

  The step-by-step counts were 797 → 805 (Task 4) → 806 (Task 5) → 817
  (Task 6) → 836 (Task 7) → 839 (Task 7's fix round) → 846 (Task 8) → 851
  (Task 10).
- **App, +1: Task 9 added a fifth test**, `replacing the shell mid-drag
  disposes cleanly, no exception (M-03ao, shell)`. The Task 7 review deferred
  it to Task 9: a planner removed mid-drag hits the same deactivate-assert
  class that Task 7's cursor fix addressed. The counts were 21 → 26.

In total, Task 10's addendum added seven tests (2 engine and 5 render), one
for each controller-added mutant that needed one.

### The differential (criterion 3)

This is `rigid_transform_test.dart`'s `differential: 200 seeded rigid
transforms agree with an independent oracle (M-03h, M-03m)`. It uses seed
`0x5EED0003` and 200 trials. Rotations are drawn from `(−2π, 2π)`, excluding
multiples of `π/2`, and translations go up to `1e6`. The oracle samples each
curve from its stored values. It shares no code with `rigidTransformLeaf`.
The tolerance is `max(1e-12, 256·2⁻⁵²·max(2e6, |a|, |b|))` (Ruling 03-16).
The test's printed line from the gate run above, pasted:

```
03 differential: seed 0x5EED0003, 200 trials, worst residual per kind: {point: 0.0, line: 2.9103830456733704e-10, polyline: 4.656612873077393e-10, circle: 4.656612873077393e-10, arc: 4.656612873077393e-10, text: 4.656612873077393e-10}
```

The worst residual per kind, transcribed from that line:

| kind | worst |
|---|---|
| point | 0.0 |
| line | 2.91e-10 |
| polyline | 4.66e-10 |
| circle | 4.66e-10 |
| arc | 4.66e-10 |
| text | 4.66e-10 |

**Derived reasoning, not pasted output.** The paragraph below is this
note's arithmetic about the pasted line; no command printed it. Every
residual is at most 2⁻³¹ ≈ 4.66e-10: two ulps of a coordinate just
under 2e6, one ulp of a coordinate above 2²¹ ≈ 2.1e6, the magnitudes the
trials reach. That is about 240 times inside the ~1.1e-7 bound. The smallest
angle error the mutants make, `r·θ ≥ 1.5e-3`, is 10⁴ times larger than the
bound.

### Mutation summary

**68 exercised: 65 killed, 1 designed survivor (M-03e), 2 equivalent
(M-03ai's ordinal clause; `GripDrag._capture`'s `read` → `peek`), both by
construction.** Task 10's sweep exercised 62 (60 killed, M-03e, M-03ai's
variant); the final fix wave added six.
- **The spec's 27 (M-03a…M-03aa):** 26 killed, and M-03e survived as
  designed. Its standing 1-ulp companion (Ruling 03-20) is green in the same
  run: `==` catches one ulp and `Tolerance` does not.
- **M-03ah′**, the second `worldBoundsOf` case: killed.
- **The plan's 23 (M-03ab…M-03ax, Ruling 03-17):** 23 killed.
  - M-03ab and M-03as were re-expressed against the code as it now stands.
  - M-03ah is killed by O1, not by C2. C2 compares against the same mutated
    `worldBoundsOf`.
- **M-03ai's variant.** Dropping the ordinal tie-break is equivalent: the
  candidates are built in ascending ordinal within each key, so the clause
  can never be true where it is tested.
- **The controller's 10 (M-03ay…M-03bg, including M-03bf′):** 10 killed.
  - Seven new tests landed for them, each in its own commit.
  - M-03bc and M-03bd were already guarded, by the extended T14 and by T8
    pressed 5 px off the grip.
- **The final review's 5 (M-03bh…M-03bl):** 5 killed.
  - M-03bh (the grip x projection's `m.c` → `m.b`) and M-03bi (the rotation
    disc at its anchor) extended P2 and P4 in place. M-03bh survives under
    `gripCamera` alone: a y-flipped rotation has `b == c` bit for bit. P2
    also runs under `gripCamera(flipY: false)`, and that iteration kills it.
  - M-03bj (the circle reshape preview's origin), M-03bk (grip-to-grip hover
    repaint) and M-03bl (shift mid-drag re-targets at once, a production
    fix in `0cac4f4`) each got a new test.
- **`GripDrag._capture`'s `read` → `peek`:** equivalent. `GeometryStore`
  installs fresh buffers on `replace`, so a captured view never sees a later
  edit. The whole render suite stayed at its standing five golden failures
  under it.

Each mutant followed the same procedure:
1. a `cp`-backed one-edit change to a production file (M-03e edits a test's
   assertion instead);
2. the named test run with `CI=true`;
3. a restore from the copy, confirmed with `diff`.

No `git checkout --` was used on any `.dart` file. The Task 10 reviewer fired
M-03a, M-03i, M-03u, M-03bf and M-03n again independently and got the logged
failures each time.

**Both allocation gates are green and unedited.** `query_allocation_test.dart`
(5 tests) and `paint_allocation_test.dart` (3 tests) were pasted by Task 11
in the mutation log's "Invariants and greps" section. Both run again inside
the 890 and 851 above, and in the 890 and 854 of the fix wave's run. Task 11's greps are pasted there too, and each came
back as required:
- the invariants' tests are unedited;
- the frame-path files and the harness are untouched;
- no `dart:ui` in the engine's two new files;
- no root-transform read on the drag path;
- three `drawRawPoints` and no `Rect` in `_paintGrips`.

Two extra grep hits (a comment and a `.multiply(...)`) were confirmed as
pattern false positives.

---

## Exit gate

The spec's sixteen criteria, each with its witness.

| # | criterion | verdict | witness |
|---|---|---|---|
| 1 | `leafGrips` returns D3's set for every kind, in owner space, with the closed-polyline rule | **PASS** | `grips_test.dart`: `the grip set per kind, in owner space (M-03y)`, `isClosedPolyline is an exact stored-value test`; `grip_cache_test.dart` (C1): `grips of the selected root leaves, in world, in ascending handle order (M-03y)` |
| 2 | A stretch moves the grabbed coordinate and nothing else; an arc's derived end within `Tolerance` | **PASS**, with Ruling 03-1 | `grips_test.dart`: `a line stretch writes the grabbed pair and copies the rest`, `a polyline middle-vertex stretch moves that vertex and nothing else (M-03o)`, `a closed room corner moves as one: first and last pairs stay == (M-03r)`, `an arc start stretch keeps the sweep direction and the end, both signs (Ruling 03-1)`, `an arc end stretch on a negative sweep stays negative (M-03n)`, `a circle radius grip sets r = \|target − centre\|; degenerate is null`, `an arc radius grip copies the angles`. The derived end angle is compared by `cos` and `sin`, i.e. modulo 2π (Ruling 03-1) |
| 3 | `rigidTransformLeaf` passes the differential | **PASS**, with Ruling 03-16 | `rigid_transform_test.dart` (R6): `differential: 200 seeded rigid transforms agree with an independent oracle (M-03h, M-03m)`. Seed `0x5EED0003`, 200 trials, worst residual per kind pasted above |
| 4 | A body drag and a centre grip move the whole selection; on-grid stays on-grid | **PASS**, with Ruling 03-9 | `select_tool_drag_test.dart`: `a body drag moves the selection under a rotated camera (M-03a)` (T2), `a centre grip moves the whole selection from the grip itself (M-03at, Ruling 03-9)` (T8), `with grid snap on, on-grid geometry stays on the grid (M-03s)` (T5) |
| 5 | A rotated group and an instance compose `T.multiply(node.transform)`; the definition and the other instance are untouched | **PASS** | `grip_drag_test.dart`: `a rotated group moves by T.multiply(node.transform) (M-03i)` (D2), `an instance move rewrites the instance node, never the definition (M-03c)` (D3) |
| 6 | Rotation about the box centre (arcs by `arcBounds`, points by position); shift steps 15° | **PASS** | `outline_cache_test.dart` (O1): `worldBoundsOf: an arc by arcBounds, a point by its position (M-03ah)`; `grip_cache_test.dart` (C2): `the selection box is the union of worldBoundsOf; fills alone have none (M-03ah)`; `select_tool_drag_test.dart`: `a rotation turns about the selection box centre, far from the origin (M-03j)` (T11), `shift steps the rotation by 15° (M-03w)` (T12) |
| 7 | One drag is one `CompoundCommand` labelled `Move`, `Rotate` or `Stretch`; a no-op adds none | **PASS** | `grip_drag_test.dart`: `a move is one CompoundCommand labelled Move, members in ascending handle order (M-03an)` (D1), `a rotate is labelled Rotate and turns an arc's start angle (M-03h)` (D4), `a reshape is one CompoundCommand labelled Stretch` (D5), `a drag that changes nothing builds no command (M-03p)` (D6); `select_tool_drag_test.dart`: `no command during a drag; release adds exactly one Compound "Move" (M-03d, invariants 1 and 4)` (T3), `a drag back to the press pixel, or snapped back onto its base, adds nothing (M-03p)` (T4) |
| 8 | Undo restores with `==`; M-03e is the designed survivor with its 1-ulp check | **PASS**, with Ruling 03-20 | `grip_drag_test.dart`: `undo restores every stored value with == (spec D11; M-03e is the designed survivor)` (D10), `the undo assertion enforces ==: one ulp is caught (M-03e companion, Ruling 03-20)` (D11); the mutation log's M-03e entry |
| 9 | Escape, pointer cancel, activation and revalidation are byte-identical; a drag past the edge continues | **PASS** | `select_tool_drag_test.dart`: `every key-down and repeat is the drag's; Escape cancels byte-identically (M-03aa, M-03l)` (T15), `a pointer cancel leaves the document byte-identical (M-03ao)` (W1), `tool activation cancels a drag byte-identically (M-03ao)` (T16), `removing the layer mid-drag cancels byte-identically (M-03ao)` (W3), `a document change mid-drag: release dispatches nothing (M-03t)` (T17), `a move dragged past the layer's edge continues and lands (M-03ap)` (W2); app: `replacing the shell mid-drag disposes cleanly, no exception (M-03ao, shell)` |
| 10 | A stretch lands exactly on an endpoint; object beats grid; ortho overridden and re-pinned; F3 off | **PASS** | `drag_snap_test.dart`: `an object snap overrides ortho, and is copied out of the scratch (invariant 7)` (S3), `an object snap beats a nearer grid point (M-03g)` (S4), `a grid snap re-pins the ortho axis afterwards (M-03q)` (S6), `object snap off never snaps to an object: the grid wins (M-03x)` (S7); `select_tool_drag_test.dart`: `a stretch released near an endpoint lands on it exactly (M-03au)` (T9); `planner_grips_test.dart`: `a stretch through the shell lands exactly on an endpoint, and cmd+Z restores it with == (A1, M-03au)`, `F3 turns object snap off: osnap-text says so and the drag lands on the grid (A2, M-03x)` |
| 11 | Permissions at press, and all-or-nothing at release | **PASS**, with Rulings 03-5 and 03-6 | `grip_cache_test.dart` (C5): `leaf grips are not live under a geometry denial (M-03ad)`; `select_tool_drag_test.dart`: `permissions at press: no leaf grips, a refused move stays a click, an instance still moves (M-03ad, M-03av)` (T13), `class 3b: a refused move never runs before the click toggles once, net (Ruling 03-6; M-03be)`; `selection_overlay_grips_test.dart` (P4): `no leaf grips are drawn under a geometry denial; the rotation grip still is, at its centre (M-03ad, M-03bi)`; `grip_drag_test.dart` (D8): `a refused member cancels the whole drag (M-03k)` |
| 12 | Grips in O(1) draw calls; the cap at `kMaxGrips` | **PASS**, with Ruling 03-10 | `selection_overlay_grips_test.dart` (P2): `grips are one drawRawPoints per colour at 10 grips and at 300, and the hot grip one more, each at its grip (invariant 6, M-03v, M-03aq, M-03bh)`, and `the stretch buffer is reallocated only when the count changes, and never draws a stale grip (Ruling 03-10; M-03bf, M-03bf')`; `grip_cache_test.dart` (C4): `the cap: kMaxGrips grips are kept, kMaxGrips + 1 keep none (M-03z)` |
| 13 | Every named mutant fired and killed, except M-03e | **PASS** | [plan-03-mutation-log.md](plan-03-mutation-log.md): **68 exercised: 65 killed, 1 designed survivor (M-03e), 2 equivalent (M-03ai's ordinal clause; `GripDrag._capture`'s `read` → `peek`), both by construction**. That covers the spec's 27, `ah′`, the plan's 23, M-03ai's variant, the controller's 10, and the final review's 5 (M-03bh…M-03bl) with the `read` → `peek` equivalent |
| 14 | The allocation invariants pass unchanged | **PASS**, with Ruling 03-12 | `query_allocation_test.dart` (5) and `paint_allocation_test.dart` (3) are green and unedited: Task 11's transcripts are in the mutation log, and both run inside the 890 and 851 above, and inside the fix wave's 890 and 854 |
| 15 | The four gate lines, the five goldens only, both builds | **PASS with the one recorded exception** | pasted above, twice (Task 12's run, and the fix wave's): `jet_cad_2d` **890**; `jet_cad_2d_flutter` **851, then 854 after the fix wave, pass, 1 skip, and only the five `text_ladder_golden_test.dart` failures**; `dev_harness_2d` **82**; `floor_planner` **26**; `flutter build macos --release` and `flutter build web --release` both printed `✓ Built`. Every `analyze` and `format` exited 0, and no `analysis_options.yaml` was rewritten |
| 16 | A human looked, on macOS, in Chrome and in Firefox from `build/web` | **OWED: not looked at; the human looks after this branch is presented** | the checklist below |

**15 of 16 PASS; criterion 16 is OWED.** No criterion is a MISS. No device
run and no visual judgement happened in this session, and none was simulated
to fill criterion 16 in.

---

## The look: OWED, not looked at

**Not looked at. The human looks after this branch is presented, and the
merge is theirs to decide.** Run it on each platform:
- **macOS:** `cd apps/floor_planner && flutter run -d macos --release`;
- **Chrome:** `cd apps/floor_planner && flutter run -d chrome --release`;
- **Firefox:** `build/web`, served statically (`cd
  apps/floor_planner/build/web && python3 -m http.server`).

There are thirteen items per platform. Record each one as **seen / not seen /
could not judge**.

### macOS: `flutter run -d macos --release`

1. **Grips** on a selected wall, a room, an arc and the door swing. Look for:
   - squares of 8 px;
   - the centre grips in the move colour;
   - the hover's hot grip.

   ☐ seen ☐ not seen ☐ could not judge
2. **A wall end stretched onto another wall's end**, with the endpoint
   marker showing, and landing on it.
   ☐ seen ☐ not seen ☐ could not judge
3. **A body move of three objects with grid snap on**: they stay on the
   grid.
   ☐ seen ☐ not seen ☐ could not judge
4. **The rotation grip above the selection box.** A rotate, then a shift
   rotate in 15° steps.
   ☐ seen ☐ not seen ☐ could not judge
5. **Escape mid-drag**: the preview vanishes and nothing changes.
   ☐ seen ☐ not seen ☐ could not judge
6. **Undo after each drag** with **cmd+Z**: one step per drag.
   ☐ seen ☐ not seen ☐ could not judge
7. **F3 toggles `osnap-text`.** (The browser question is for Chrome and
   Firefox; see those lists.)
   ☐ seen ☐ not seen ☐ could not judge
8. **The cursor**:
   - precise over a grip;
   - grab over the rotation grip;
   - move over a selected body;
   - grabbing while rotating.

   ☐ seen ☐ not seen ☐ could not judge
9. **A room corner stretched until the room self-intersects**: the preview
   shows the outline, and the fill drops on release.
   ☐ seen ☐ not seen ☐ could not judge
10. **Snapping to the dragged object's own ghost**: does it feel sticky?
    ☐ seen ☐ not seen ☐ could not judge
11. **A drag carried past the canvas edge** continues.
    ☐ seen ☐ not seen ☐ could not judge
12. **Grid snap with a fixed `gridStepMm` skipping the drawn minor lines.**
    **Not reachable from the app**: 04's panel does not expose
    `gridStepMm`. Recorded here, not looked at.
13. **Grips and drags with the page grid visible**: 04's chrome (sheet,
    grid, rulers) underneath. Check that the grips, the preview, the guide
    line and the snap markers read clearly over it.
    ☐ seen ☐ not seen ☐ could not judge

### Chrome: `flutter run -d chrome --release`

The same thirteen items, with **ctrl+Z** in place of cmd+Z for item 6.

1. Grips on a wall, a room, an arc and the door swing (8 px, move-colour
   centres, the hot grip). ☐ seen ☐ not seen ☐ could not judge
2. A wall end stretched onto another wall's end, with the marker, landing on
   it. ☐ seen ☐ not seen ☐ could not judge
3. A body move of three objects with grid snap on stays on the grid. ☐ seen
   ☐ not seen ☐ could not judge
4. The rotation grip; a rotate, then a shift rotate in 15° steps. ☐ seen ☐
   not seen ☐ could not judge
5. Escape mid-drag: the preview vanishes and nothing changes. ☐ seen ☐ not
   seen ☐ could not judge
6. Undo after each drag with **ctrl+Z**, one step per drag. ☐ seen ☐ not seen
   ☐ could not judge
7. F3 toggles `osnap-text`. **Does the browser's find-next also fire?** If
   it does, the finding picks another key (spec, Open questions). ☐ seen ☐
   not seen ☐ could not judge
8. The cursor: precise, grab, move, grabbing. ☐ seen ☐ not seen ☐ could not
   judge
9. A self-intersecting room corner stretch: the preview shows the outline,
   and the fill drops on release. ☐ seen ☐ not seen ☐ could not judge
10. Snapping to the dragged object's own ghost: sticky? ☐ seen ☐ not seen ☐
    could not judge
11. A drag past the canvas edge continues. ☐ seen ☐ not seen ☐ could not
    judge
12. Grid snap with a fixed `gridStepMm`: **not reachable from the app**.
    Recorded, not looked at.
13. Grips and drags with the page grid visible. ☐ seen ☐ not seen ☐ could not
    judge

### Firefox: `build/web`, served statically

The same thirteen items again, from the release web build rather than
`flutter run`, with **ctrl+Z** for item 6.

1. Grips on a wall, a room, an arc and the door swing (8 px, move-colour
   centres, the hot grip). ☐ seen ☐ not seen ☐ could not judge
2. A wall end stretched onto another wall's end, with the marker, landing on
   it. ☐ seen ☐ not seen ☐ could not judge
3. A body move of three objects with grid snap on stays on the grid. ☐ seen
   ☐ not seen ☐ could not judge
4. The rotation grip; a rotate, then a shift rotate in 15° steps. ☐ seen ☐
   not seen ☐ could not judge
5. Escape mid-drag: the preview vanishes and nothing changes. ☐ seen ☐ not
   seen ☐ could not judge
6. Undo after each drag with **ctrl+Z**, one step per drag. ☐ seen ☐ not seen
   ☐ could not judge
7. F3 toggles `osnap-text`. **Does the browser's find-next also fire?** If
   it does, the finding picks another key. ☐ seen ☐ not seen ☐ could not
   judge
8. The cursor: precise, grab, move, grabbing. ☐ seen ☐ not seen ☐ could not
   judge
9. A self-intersecting room corner stretch: the preview shows the outline,
   and the fill drops on release. ☐ seen ☐ not seen ☐ could not judge
10. Snapping to the dragged object's own ghost: sticky? ☐ seen ☐ not seen ☐
    could not judge
11. A drag past the canvas edge continues. ☐ seen ☐ not seen ☐ could not
    judge
12. Grid snap with a fixed `gridStepMm`: **not reachable from the app**.
    Recorded, not looked at.
13. Grips and drags with the page grid visible. ☐ seen ☐ not seen ☐ could not
    judge

### Four things to know before looking

- **World is root space.** The drag never reads or writes the root's
  transform. `OutlineCache` and `TileCache` disagree with the canvas and the
  index about it, but the two agree while it is the identity. That is the
  first debt item below.
- **Dragged objects stay snappable at their stored position** (spec D8), as
  in AutoCAD's MOVE. Item 10 asks whether that feels sticky.
- **A move lands within one rounding; a stretch lands exactly.** When a
  vertex must coincide with another object's vertex bit for bit, stretch it
  (spec D8).
- **The adaptive grid step follows the zoom** (04's D6, Ruling 03-11). A
  body move from an on-grid object moves by a lattice vector at the current
  zoom's step.

---

## Rulings

### The plan's rulings, 03-1…03-21

Each ruling is one line, with what it costs if it is wrong. The ones marked
**(spec amended)** are written into the spec below.

- **03-1 (spec amended, D3 and criterion 2):** an arc's derived end angle is
  compared modulo 2π (by `cos`/`sin` within `Tolerance.standard.angular`),
  because `atan2` returns `(−π, π]` and a stored start need not. Cost if
  wrong: none; the same direction is what "the untouched end stays" means.
- **03-2:** D2's "grip index" tie-break is the ordinal in `leafGrips`' list
  (`GripRef.ordinal`), because `Grip.index` repeats across roles. Cost:
  none; coincident grips within one object need a zero-length segment.
- **03-3 (spec amended, D7):** the reshape preview is drawn through a new
  `Tool.paintWorldOverlay(Canvas, Vector2 origin, double scale)`, called
  inside the overlay's matrix block, since `paintOverlay` has no origin
  parameter. Cost: one more `Tool` member with a default.
- **03-4:** the overlay reads the grips from `tools.context.grips`, so what
  is drawn and what is hit come from one cache. Cost: the painter depends
  on `ToolController.context`, which it already holds.
- **03-5:** permissions are read live, never cached: `leafGripsLive` at
  press, at hover and per frame. Cost: one bool read per frame.
- **03-6 (spec amended, D2):** the press-time capability check runs when the
  press crosses the slop, before any drag starts. A refusal makes the press
  click-only, and class 3b's selection is not changed at the slop. Cost:
  none; the release check covers the gap.
- **03-7:** the camera listener is added in `_enter` for move, rotate and
  reshape, and removed only in `_endDrag`, which every exit goes through.
  Cost if wrong: a leaked listener. **Corrected at execution:** the cost
  sentence named T14's "a camera change after release leaves no preview"
  as the guard. The Task 7 review showed that check cannot fail. The guard
  is now T14's listener count, one listener per live drag (M-03bc).
- **03-8 (spec amended, D5):** `KeyRepeatEvent` is consumed during a drag
  too, because a held cmd+Z auto-repeats and the shell's binding includes
  repeats. Cost: none; the release revalidation would have caught it.
- **03-9:** a centre grip moves the whole selection, with the base at the
  grip's own world point (exit criterion 4 over "What this delivers"). Cost:
  a one-object selection behaves the same either way.
- **03-10 (spec amended, D6):** grip buffers are sized exactly and
  reallocated only when the count changes. Grips are projected in doubles
  and only screen coordinates are narrowed. Cost: a reallocation at
  selection-change rate.
- **03-11 (spec amended, D8):** `dragGridStepMm(PageComponent?, double)`
  lives in `drag_snap.dart`. It returns `page.gridStepMm` exactly, else the
  adaptive `minorMm ?? majorMm`. Cost: none; it is 04's D6 rule, stated
  once, and 05 inherits it.
- **03-12 (spec amended, invariant 5):** the per-event cost names three O(1)
  allocations: `snapToGrid`'s `Vector2`, `GridScale.pick`'s `GridScale`, and
  the camera listener's `screenToWorld`. None is per entity. Cost: none to
  the frame path.
- **03-13:** release re-targets from the up event before building the
  command. Cost: none; it makes M-03p's "back to the press pixel" exact.
- **03-14:** the rotation angle is normalised to `(−π, π]` before
  shift-rounding. Cost: none; the geometry is the same either way.
- **03-15 (spec amended, D6):** `GripCache.rotatable` is `box != null`,
  because a fill has no outline and so a fills-only selection has no box.
  Cost: none; a separate non-fill flag would be an equivalent mutant.
- **03-16 (spec amended, Testing):** the differential's tolerance scale is
  `max(2e6, |a|, |b|)`. Near-zero samples of 2e6-sized operands fail
  spuriously otherwise. Cost: none; the bound still sits far below `r·θ ≥
  1.5e-3`.
- **03-17 (spec amended, Testing):** the plan adds M-03ab…M-03ax, one per
  test that guards spec behaviour with no named mutant. M-03ah fires twice
  (`ah′`). Cost: 24 more mutant runs.
- **03-18:** the shell's test seam is `PlannerShell({Key? key,
  DraftDocument? document, ViewportTransform? initialCamera})`. A test
  document carries a `FlutterTextMeasurer`, and a test sets its camera after
  the first pump. Cost: two optional parameters.
- **03-19:** `GripCache` listens to the `SelectionController` and to the
  `OutlineCache`, never to `document.changes`. It skips a selection
  notification whose key set is unchanged, which is a hover change. Cost if
  wrong: a stale box, or a reset hot grip; M-03al and M-03ba guard it.
- **03-20:** M-03e's companion is a standing test in `grip_drag_test.dart`,
  and M-03e is logged as the designed survivor. Cost: none.
- **03-21:** only one 02 test changes, the renamed "5 px move from a hit"
  band test, which now carries `D12` in its name. Cost: none; every other
  02 tool test has `grips == null`.

### The controller's rulings, from the ledger

- **Pre-flight, the archive:** the skill says to delete the workspace at the
  end. That is replaced by the repo convention: archive the ledger to
  `docs/superpowers/ledgers/2026-09-23-grips-and-transform/` as the branch's
  last commit. Cost if wrong: none.
- **Pre-flight, the models:**
  - implementers ran on Sonnet, because the plan carries complete code;
  - task reviewers ran on Sonnet for engine Tasks 1–3 and on Opus for
    Tasks 4–9, which carry the interaction and overlay subtleties;
  - the final review runs on Opus.

  Cost if wrong: a missed defect surfaces at the final review.
- **T2-a:** a commit's `Co-Authored-By` trailer names the model that
  actually wrote it, which replaces the plan's fixed Opus 5.5 trailer and
  its grep check. `abd0d28` (Task 1, written by Sonnet with an Opus 5.5
  trailer) is left as it is, rather than rewriting history. Cost if wrong:
  trailer inconsistency in the log only.
- **T7-a:** the Task 7 review found two Important test gaps that the plan
  itself mandated: T14's post-release check could not fail, and the centre
  grip was pressed on its exact pixel. Both were fixed in Task 7, because
  the spec's testing bar outranks the plan text. Cost if wrong: none, tests
  only.
- **T7-b:** two minors entered the same fix round:
  - M1, the layer's `didUpdateWidget` and `activate` were untested;
  - M3, a stale press-time grip index or box could `RangeError` after an
    undo inside the slop.

  M3 was a reachable crash, and M1's tests are the only guard for the
  layer fix's reparent path. Cost if wrong: a few extra test lines.
- **T11-a:** Task 11 ran the allocation invariants and the greps but not the
  four gate lines its brief lists. It was not re-dispatched. Task 12 runs
  all four on the final tree (above), which covers Task 11's run. Cost if
  wrong: none; the final-tree run is the stronger evidence.
- **T12-a:** Task 12 does Steps 1–4 only. Step 5's ledger archive runs after
  the final whole-branch review and its fix wave, so the archive stays the
  last commit before the merge. Cost if wrong: none.
- **F-a:** one fix wave carries the final review's full list, Task 12's
  Important (the STATUS branch map) and the reviewer's fix-before-merge
  triage. The shift-mid-drag minor is fixed rather than deferred: it is a
  small, user-visible interaction bug in this plan's own feature. Cost if
  wrong: a small extra production diff, covered by a named mutant (M-03bl).
- **F-b:** the two other sessions' fix branches are recorded in STATUS, not
  merged or touched by this plan. Their merge order relative to this branch
  is the human's decision. Cost if wrong: a doc conflict at merge time,
  resolved by whichever merges second.

---

## Debt

**Named by the plan:**

- **The root-transform disagreement** (spec, Open questions; still open).
  `OutlineCache` and `TileCache` apply the root's transform to root-level
  nodes. The canvas, the index and the oracle do not. It is harmless while
  nothing writes the root's transform. The fix is to pin it to the identity,
  with a `validate` check or by refusing `TransformNodeCommand` on the root,
  or else to make every walk apply it. That is its own task. **Its fix is
  committed on `fix/root-transform-identity` at `776f201`** (another
  session's, cut from `main` at `c09b747`), **not merged.** It pins the
  root's transform to the identity. It edits this plan's spec and
  `STATUS.md`, so whichever of the two branches merges second resolves the
  doc conflict; the order is the human's decision.
- **Grips as widgets** give up screen-reader and keyboard access. This is
  recorded for 12 (the app shell), which owns accessibility.
- **Snapping to the dragged object's ghost** is kept (D8). If the look finds
  it sticky, the fix is an exclusion set on `snapInto`: an engine query
  change with its own allocation argument.
- **Move exactness is within one rounding**, not bit-exact (D8). A stretch
  is exact.
- **The preview of an unfillable room** shows the outline, not the lost
  fill (D3). It is item 9 of the look.
- **F3 in a browser.** Chrome binds F3 to find-next. It is item 7 of the
  look; if the browser acts on it, the finding picks another key.

**Named by the final review:**

- **The move/rotate preview's point crosses allocate** four `Offset`s per
  selected point per frame. That is 02's existing cross pattern, which the
  Task 8 brief mandated. It breaches the frame-path rule ("nothing per
  entity in steady state") for point keys, and `paint_allocation_test` does
  not gate it.

**Out of scope, from the ledger:**

- **`PageComponent.copyWith(gridStepMm: <int>)` throws**
  (`page_component.dart` 168–170 casts with `as double?`). It is a
  pre-existing Plan 04 bug, found by the Task 3 review. **Its fix is
  committed on `fix/page-copywith-num` at `8385753`** (another session's,
  cut from `main` at `e376ced`), **not merged.**

**Deferred minors that no later task closed**, grouped by task, one line
each:

- **Task 1:**
  - `grips.dart`'s `pointCount == 0` guards on the circle and arc branches
    are untested.
  - The radius-or-null sequence is duplicated between the circle and arc
    radius cases.
- **Task 2:**
  - `rigidTransformLeaf`'s arc and text branches discard `transformedBy`'s
    scalars copy: one throwaway `Float64List` per call, at release rate only.
  - The arc branch's `scalars.length >= 2` guard is unreachable, because an
    arc always carries three scalars. Inherited from the brief.
- **Task 4:**
  - C2's title still names M-03ah, though O1 is the killer. The mutation log
    records this.
  - O1's `maxY` reason text is inaccurate.
  - C6's title says "nearest".
  - `grip_cache.dart`'s root-owner filter is untested. It is defensive,
    because `resolveHit` only yields root keys.
  - `selection.keys.toSet()` and `worldBoundsOf`'s per-vertex allocations
    happen at event and rebuild rate, not on the frame path.
- **Task 6:**
  - M-03t's "gone" assertion lacks an `isNotNull` re-assert after the
    `instA` undo.
  - M-03p's `undoDepth == 0` assertion is vacuous at the `GripDrag` level.
    The tool-level T4 owns invariant 1.
  - `GripDrag.capabilities` (from the capture type) and the member
    capabilities are two sources of truth.
  - The leaf-capture sequence is duplicated between the reshape and
    `_capture`.
- **Task 7:**
  - M-03s's fixture page origin (7000, 3000) sits on the absolute lattice,
    so an origin-ignoring grid would pass T5.
  - `_endDrag` resets the cursor to `defer` until the next hover.
  - A stale-body click release still uses the press-time `_downKey` (02's
    behaviour).
- **Task 8:**
  - The snap marker's insertion, intersection and grid geometry is only
    partly asserted. The rotation grip's stem and radius, and the guide's
    1.0 and the marker's 1.5 strokes, are unasserted.
- **Task 9:**
  - The `initialCamera` seam and the no-page `ViewportTransform.fit`
    fallback are never exercised by a test (`main.dart` 51–53, 86–91).
  - The shell builds an unused `FlutterTextMeasurer` when a document is
    injected.
  - The report's prose miscounts (834 against the pasted +846). This is
    ledger prose only; the controller verified that only app files changed.

**Closed by a later task** (for the record, and not debt):
- Task 1's near-2π branch (M-03ay);
- Task 3's `DragPoint` reuse (M-03az);
- Task 4's hover skip and nearest-wins (M-03ba, M-03bb), with the ordinal
  clause logged as equivalent;
- Task 4's construction-order check (Task 9 builds `GripCache` after
  `OutlineCache`);
- Task 5's cursor mutant (M-03ab);
- Task 7's 3b refuse-before-toggle (M-03be);
- Task 7's shell mid-drag removal (Task 9's fifth test);
- Task 7's M-03ab row and D5 amendment (the log and this task);
- Task 8's buffer rule (M-03bf, M-03bf′);
- Task 8's arc preview branch (M-03bg);
- Task 8's production repaint merge (Task 9, `PlannerView._repaint` includes
  `grips`);
- **closed by the final fix wave:**
  - Task 1's barrel order: `lib/jet_cad_2d.dart`'s exports are in sorted
    order, `grips.dart` and `drag_snap.dart` included (checked with `sort
    -c`), so the line is dropped. The render barrel's four Plan 03 exports
    sit in sorted position too. That barrel as a whole is not sorted
    (`vertices_draw_sink.dart` at line 8, and `gpu/gpu_facade.dart`'s
    commented `show` export ahead of the rest of the `gpu/` block), but
    that ordering predates this plan, which added four lines and moved
    none;
  - Task 6's `read → peek` swap, fired and logged as equivalent;
  - Task 7's `onPointerExit`, documented at the method as unreachable
    mid-drag (the host never forwards an exit while a pointer is captured);
  - Task 8's circle preview branch (M-03bj);
  - Task 8's preview-cross allocation, promoted to named debt above.

---

## Spec amendments

Recorded where each applies, in
[2026-09-23-grips-and-transform-design.md](../specs/2026-09-23-grips-and-transform-design.md).
Each is a paragraph beginning "**Amended at execution (Plan 03,
2026-09-23):**", appended at the end of the relevant section. Nothing
original was rewritten.

- **D2:** Ruling 03-6 (the capability check at the slop crossing; 3b's
  selection is untouched when it refuses) and Ruling 03-9 (a centre grip
  moves the whole selection from the grip itself).
- **D3:** Ruling 03-1. The derived end angle is compared modulo 2π, and exit
  criterion 2's "within `Tolerance`" means the same direction.
- **D5:** Ruling 03-8 (`KeyRepeatEvent` is consumed too). Two changes from
  Task 7's fix round are recorded with it:
  - **The cursor** is a `ValueNotifier<MouseCursor>` mirror rendered by a
    `ValueListenableBuilder` around only the `MouseRegion`. It goes quiet
    while the layer leaves the tree, and `activate` unmutes it. It replaces
    the `ListenableBuilder` on the `ToolController`, which asserted
    (`markNeedsBuild` during build) when a mid-drag removal made the tool
    notify from `deactivate`.
  - **The press-time `GripRef` is found again at the slop.** A grip or box
    that went stale after an undo inside the slop makes the press a click.
- **D6:** Ruling 03-10 (exact-size buffers, projected in doubles, and only
  screen coordinates narrowed) and Ruling 03-15 (`rotatable` is `box !=
  null`).
- **D7:** Ruling 03-3 (`Tool.paintWorldOverlay`).
- **D8:** Ruling 03-11 (`dragGridStepMm`).
- **Invariant 5:** Ruling 03-12 (the three per-event O(1) allocations).
- **Testing:** Ruling 03-16 (the differential's scale), Ruling 03-17's
  M-03ab…M-03ax table with ids, mutations and tests, and the
  controller-added M-03ay…M-03bg from the task reviews. The final fix wave
  appended one more paragraph: M-03bh…M-03bl, the `read` → `peek`
  equivalent, the 68-mutant tally, and why M-03bh's test also runs under an
  unflipped camera.

---

## Files this task touched

- `docs/superpowers/notes/2026-09-23-plan-03-results.md`: this file.
- `docs/superpowers/specs/2026-09-23-grips-and-transform-design.md`: the
  amendments above, appended. Nothing was rewritten.
- `docs/superpowers/notes/plan-03-mutation-log.md`: two prose slips in the
  tally, flagged by the Task 10 review. The sum reads 60 killed (it said
  61), and the controller's mutants are described as "7 new tests; M-03bc
  and M-03bd already guarded".
- `STATUS.md`: a Plan 03 section, the header's "Last updated" paragraph,
  and the "Resume here" section.
- `roadmap/03-grips-and-transform.md`: the status line.
- `roadmap/00-README.md`: the 03 row in the status table.

Task 12 touched no code.

## Files the final fix wave touched

- `packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart`: P2
  and P4 extended (M-03bh, M-03bi), and the circle preview test (M-03bj).
- `packages/jet_cad_2d_flutter/test/support/grip_fixture.dart`:
  `gripCamera` gained `flipY` (default `true`).
- `packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart`: the
  grip-to-grip hover test (M-03bk) and the shift mid-drag test (M-03bl).
- `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`: `onKey`
  re-targets on a shift key-down or key-up mid-drag; a doc comment on
  `onPointerExit`.
- `packages/jet_cad_2d/lib/src/document/grips.dart`: the θ = 0 doc comment,
  qualified for a height-only text.
- This note, the mutation log, the spec's Testing section (appended) and
  `STATUS.md` (the branch map, the fix branches, Plan 04's merged state, and
  the counts).
