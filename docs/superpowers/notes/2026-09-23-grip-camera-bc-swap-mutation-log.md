# fix/grip-camera-bc-swap — mutation log

**Tally: 7 mutants fired, 7 killed. Each also survives HEAD's version of its
test, which is the finding.**

## The finding

Plan 03's final fix wave parked it (ledger
`docs/superpowers/ledgers/2026-09-23-grips-and-transform/progress.md`, the
"b/c-transposition blindness" ruling; results note
`2026-09-23-plan-03-results.md`, M-03bh). `gripCamera()` is
`rotation ∘ scale(s, −s)`, a reflection. Its linear part is symmetric, so the
matrix's `b` and `c` are bit-identical and an `m.b`/`m.c` transposition in a
projection changes nothing. Plan 03 added `gripCamera(flipY: false)` and gave
P2's grip draw positions a pass under it (M-03bh). Six other projection sites
had no such pass. No product camera exposes the swap today (fit, pan and zoom
keep `b == c`), so the defect class is latent: this is a form check.

Under `flipY: false`, `c = −b`. A swap in a projection then moves x by
`2·s·sin θ·y`. At the fixture's y ≈ 3000–3400 the observed misses were
2263–2456 px. M-03br swaps inside a product with the drag's `t.b`, so its miss
was about 100 px. None is a tolerance-edge kill.

## Branch

`fix/grip-camera-bc-swap`, cut from `plan-03/grips-and-transform` at
`66ed4c2`. That branch is **not merged** into `main`. The sites and
`gripCamera(flipY:)` exist only there. This branch descends from it, so it
merges cleanly after Plan 03 lands. The merge order is the human's decision.

## The tests

Each test now loops over `flipY` in `[true, false]`. Every assertion that
can fail under the swap carries `reason: 'flipY $flipY'`.

| Site | Test (file) |
|---|---|
| `GripCache.hitTest` | M-03ai, "hitTest: the nearest, then the greater handle, then the lower ordinal" (`grip_cache_test.dart`). New assertion: `corner` is non-negative, so a miss reads as an assertion failure and not as a `RangeError` on `grips[-1]` |
| `rotationGripOf` | P4, "no leaf grips are drawn under a geometry denial; the rotation grip still is, at its centre" (`selection_overlay_grips_test.dart`). **The oracle changed**: it was `rotationGripOf(...)`, the function under test, so a defect there moved the expectation with it and no camera could expose one. It now projects the box's four corners through `screenOf` |
| overlay `_hotPoint` | P2, "grips are one drawRawPoints per colour …". The hot-grip block now runs under both cameras (the stretch/centre block already did, M-03bh) |
| overlay `_drawPointCross` | M-03ae, "a selected point's preview cross sits at T(p)" |
| overlay outline `_matrix` and preview `_preview` composition | M-03u, "the move/rotate preview is drawn through worldToScreen ∘ T ∘ translate(origin)". It now also pins the outline pass (`transforms[0]`): each world point, rebased by `origin`, lands at `worldToScreen(p)` |
| `SelectTool._paintGuide` | P8/M-03ar, "a stretch draws its guide and the snap marker at the resolved target" |

## Mutants

Procedure, per mutant (`run.py` in the session scratchpad):
1. `cp` the production file to a backup.
2. Apply the one-token edit, asserting it matches exactly once.
3. Run the named test with `CI=true flutter test <file> --plain-name <name>`.
4. Write `git show HEAD:<test file>` to `test/zz_baseline_<file>`, run the
   same name against it, then delete it.
5. `cp` the backup back, then check that `git diff --quiet -- <file>` is
   clean and the file byte-compares equal to the backup.

All seven restored clean. No `.dart` file was restored with `git checkout`.

| ID | File, edit | New test | HEAD's test |
|---|---|---|---|
| M-03bm | `grip_cache.dart` `hitTest`: `dx = m.a·g.x + m.c·g.y …` → `m.b` | KILLED, M-03ai: `Expected: a non-negative value` `Actual: <-1>`, `flipY false: a grip is hit` | survived (`All tests passed!`) |
| M-03bn | `grip_cache.dart` `rotationGripOf`: `sx = m.a·x + m.c·y …` → `m.b` | KILLED, P4: `Expected: … within <1e-9> of <299.1777590671718>` `Actual: <2673.573626792444>`, `flipY false` | survived |
| M-03bo | `selection_overlay.dart`: `_hotPoint[0] = m.a·g.x + m.c·g.y …` → `m.b` | KILLED, P2: `… within <0.001> of <353.139686659536>` `Actual: <2616.26513671875>`, `flipY false` | survived |
| M-03bp | `selection_overlay.dart` `_drawPointCross`: `x = w.a·px + w.c·py …` → `w.b` | KILLED, M-03ae: `… of <382.2968981402182>` `Actual: <2838.4527065151688>`, `flipY false` | survived |
| M-03bq | `selection_overlay.dart`: `_matrix[12] = m.a·origin.x + m.c·origin.y …` → `m.b` | KILLED, M-03u (the outline pass): `… of <184.52285406199007>` `Actual: <2501.9633959689127>`, `flipY false` | survived |
| M-03br | `selection_overlay.dart` `_paintPreview`: `_preview[0] = m.a·t.a + m.c·t.b` → `m.b` | KILLED, M-03u (the preview pass): `… of <172.9816407425742>` `Actual: <272.86864675905935>`, `flipY false` | survived |
| M-03bs | `select_tool.dart` `_paintGuide`: `Offset(m.a·to.x + m.c·to.y …` → `m.b` | KILLED, P8: `… of <278.3450451017643>` `Actual: <2616.908091947942>`, `flipY false` | survived |

Each new-test run printed `+0 -1: Some tests failed.` Each HEAD-test run
printed `+1: All tests passed!`.

## Gate lines

All four were run with `CI=true` on this branch's tree, after every mutant
had been restored:
- `jet_cad_2d`: `+890: All tests passed!`
- `jet_cad_2d_flutter`: `+854 ~1 -5: Some tests failed.` The five failures
  are the standing `text_ladder_golden_test.dart` rungs 1–5 and nothing
  else. The count is unchanged because the `flipY` passes are loops inside
  existing tests.
- `dev_harness_2d`: `+82: All tests passed!`
- `floor_planner`: `+26: All tests passed!`

Every `analyze` printed `No issues found!`. Every
`dart format --output=none --set-exit-if-changed .` printed `(0 changed)`.
No `analysis_options.yaml` was rewritten.

## Not covered here

`apps/floor_planner/test/planner_grips_test.dart` builds its own camera, which
is also a reflection. It was not given a non-reflecting pass. Every site above
lives in `jet_cad_2d_flutter` and is now guarded there.
