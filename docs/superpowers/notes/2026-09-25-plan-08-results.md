# Plan 08 — openings: results

**Plan:** [2026-09-25-openings.md](../plans/2026-09-25-openings.md)
(amended at execution; see "Plan amendments" below).
**Spec:** [2026-09-25-openings-design.md](../specs/2026-09-25-openings-design.md)
(revision 1, amended at execution; see "Spec amendments" below).
**Mutation log:** [plan-08-mutation-log.md](plan-08-mutation-log.md).
**Spike:** [2026-09-25-openings-spike-findings.md](2026-09-25-openings-spike-findings.md)
(branch `spike/08-openings` at `634fa7c`, never merged).

**Branch:** `plan-08/openings`, cut from `spec-08/openings` at `e30386a`
(`main` `357bea6` + spike note `11f26bc` + spec `75c6c0f`, `48173e2` + plan
`9be697f` + amendment `e30386a`), in the worktree
`.claude/worktrees/plan-openings`.

**Commits:**
- Tasks 1–14 and their fix rounds: `328df0b..de66cd2`. Task 15 needed no
  commit.
- Task 16: `6b3b944` (the Task 14 review's minors), then the commit that
  adds this note.
- After it came the final whole-branch review ("With fixes", ledger) at
  `5739442`, and its **final fix wave**: the commit that adds the
  "Final fix wave" paragraphs of this note (code, tests and documents).
  Then comes the ledger archive
  (`docs/superpowers/ledgers/2026-09-25-openings/`) as the branch's last
  commit.
- The human authorised two pushes, at `c71d3b1` (after Task 6) and at
  `2670033` (after Task 11), and a third "when Task 16 is done" (ledger).
  This task pushed nothing.

**Ledger:** `.superpowers/sdd/2026-09-25-openings/progress.md`
(git-ignored while in flight). It is the source for every verdict,
ruling, deferral and measurement below that this task did not run
itself, and each such figure says so.

**Environment:** a Linux x86_64 cloud container, Flutter 3.47.2 / Dart
3.13.2 at `/root/flutter`. `flutter build macos --release`, the macOS run
of the gate lines and the look are the human's (Ruling 08-20).

---

## What was measured

### The four gate lines, pasted with exit codes

Run by this task, in full, with `CI=true`, on the final code tree `6b3b944`
(this note's commit changes documents only). Each command ran separately,
with its output saved to its own log in the session scratchpad
(`plan08/t16-g-*.log`). `git status --short` was empty after the run: no
`analysis_options.yaml`.

**`packages/jet_cad_2d`**, `CI=true dart test`:

```
00:13 +1014 -2: Some tests failed.

Failing tests:
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
```

- Exit 1: 1,014 pass, and the two failures are exactly the two standing
  Linux-only hash tests (Ruling 08-20).
- `dart analyze`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 147
  files (0 changed) in 0.52 seconds.`, exit 0.

**`packages/jet_cad_2d_flutter`**, `CI=true flutter test`:

```
00:43 +936 ~1 -7: Some tests failed.
```

Exit 1. The runner's list is truncated ("... and 3 more"); the `[E]`
lines in the same transcript name all seven failures:

```
/home/user/jet-cad/.claude/worktrees/plan-openings/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas) [E]
/home/user/jet-cad/.claude/worktrees/plan-openings/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas) [E]
/home/user/jet-cad/.claude/worktrees/plan-openings/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas) [E]
/home/user/jet-cad/.claude/worktrees/plan-openings/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas) [E]
/home/user/jet-cad/.claude/worktrees/plan-openings/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas) [E]
/home/user/jet-cad/.claude/worktrees/plan-openings/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas) [E]
/home/user/jet-cad/.claude/worktrees/plan-openings/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 2 (RenderBackend.canvas) [E]
```

- 936 pass and 1 standing skip. The seven failures are exactly the
  standing ones: `text_ladder` rungs 1–5 and the Linux-only
  `text_lod_ladder` rungs 1–2.
- `flutter analyze`: `No issues found! (ran in 1.3s)`, exit 0.
- `dart format`: `Formatted 177 files (0 changed) in 0.56 seconds.`,
  exit 0.

**`apps/dev_harness_2d`**, `CI=true flutter test --concurrency=1`:

```
00:33 +82: All tests passed!
```

- Exit 0.
- `flutter analyze`: `No issues found! (ran in 0.9s)`, exit 0.
- `dart format`: `Formatted 22 files (0 changed) in 0.09 seconds.`,
  exit 0.

**`apps/floor_planner`**, `CI=true flutter test`:

```
00:44 +232: All tests passed!
```

- Exit 0.
- `flutter analyze`: `No issues found! (ran in 0.8s)`, exit 0.
- `dart format`: `Formatted 52 files (0 changed) in 0.28 seconds.`,
  exit 0.
- `flutter build web --release`, exit 0:

  ```
  Compiling lib/main.dart for the Web...                             36.7s
  ✓ Built build/web
  ```

**`flutter build macos --release` is OWED:** the container cannot build
macOS (Ruling 08-20).

### The final fix wave's gate lines

Run by the fix wave, in full, with `CI=true`, on its code tree (the
working tree of the fix-wave commit), each command separately with its
output in its own log (`plan08/ffw/ffw-g-*.log` in the session
scratchpad). `git status --short` afterwards listed only the fix wave's
own files: no `analysis_options.yaml`.

```
engine   CI=true dart test          00:12 +1014 -2: Some tests failed.   (exit 1)
           the two standing failures: test/testing/generate_document_test.dart
             "both text fractions default to zero and change nothing"
             "the default document is the one Plan 2 measured, byte for byte"
         dart analyze               No issues found!                                  (exit 0)
         dart format                Formatted 147 files (0 changed) in 0.46 seconds.  (exit 0)
render   CI=true flutter test       00:43 +936 ~1 -7: Some tests failed.              (exit 1)
           the seven standing failures: text_ladder rungs 1-5, text_lod_ladder rungs 1-2
         flutter analyze            No issues found! (ran in 1.2s)                    (exit 0)
         dart format                Formatted 177 files (0 changed) in 0.54 seconds.  (exit 0)
harness  CI=true flutter test --concurrency=1   00:32 +82: All tests passed!          (exit 0)
         flutter analyze            No issues found! (ran in 0.8s)                    (exit 0)
         dart format                Formatted 22 files (0 changed) in 0.09 seconds.   (exit 0)
app      CI=true flutter test       00:44 +244: All tests passed!                     (exit 0)
         flutter analyze            No issues found! (ran in 0.9s)                    (exit 0)
         dart format                Formatted 54 files (0 changed) in 0.33 seconds.   (exit 0)
         flutter build web --release   Compiling lib/main.dart for the Web... 37.8s
                                       ✓ Built build/web                              (exit 0)
```

App `+244` = 232 + 12: `KJ1` (two tests), `KJ2`–`KJ6`, `OT1
(ffw-noFitRaw)`, `HF8`, `HF9`, `SG7`, `WB1`. The engine, the render
layer and the harness are unchanged by the fix wave.

### Branch-point and final counts, and why they moved

The branch-point counts are the ledger's (its "Branch-point counts": the
engine, render layer and app measured on `main` `357bea6`; the harness on
a scratch copy of `48173e2`; the spec branch adds documents only).

| suite | branch point | final (this run) | moved |
|---|---|---|---|
| `jet_cad_2d` | +987 -2 | **+1014 -2** | +27 |
| `jet_cad_2d_flutter` | +931 ~1 -7 | **+936 ~1 -7** | +5 |
| `dev_harness_2d` | +82 | **+82** | 0 |
| `apps/floor_planner` | +157 | **+232** | +75 |

Each step below is the ledger's count after the task named.

- **Engine +27:**
  - Task 1, 987 → 994: `RF1`–`RF5`, `RC1`, `RC2`;
  - Task 2, → 1,007: `CS1`–`CS7`, `LV1`, `DR1`, `DR2`, `RF6`–`RF8`;
  - its fix round, → 1,013: `CS8`–`CS11`, `DR3`, `LV2`;
  - Task 3's first commit, → 1,014: `CS12`.
- **Render layer +5:** `B12` (`markerPoint`, Task 10) and `MV1`–`MV4`
  (Task 11). The skip and the seven failures are the branch point's.
- **Harness 0:** no task touched `apps/dev_harness_2d`.
- **App +75:**

  | task | count after | added |
  |---|---|---|
  | 3 | 165 | +8 |
  | 4 | 171 | +6 |
  | 5, and its fix round | 178, 179 | +7, +1 |
  | 6 | 184 | +5 |
  | 7 | 190 | +6 |
  | 8 | 195 | +5 |
  | 9 | 203 | +8 |
  | 10 | 212 | +9 |
  | 11 | 217 | +5 |
  | 12, both commits | 221, 226 | +4, +5 |
  | 13, both commits | 229, 230 | +3, +1 |
  | 14's fix round | 231 | +1 |
  | 16's first commit (`SG6`) | 232 | +1 |
  | the final fix wave | 244 | +12 |

  The test IDs on the tree:
  - `OP1`, `HF1`–`HF9`;
  - `OG1`–`OG11` (`OG11` in four tests);
  - `OD1`, `OR1`–`OR8`, `RD1`, `DF1`, `RC3`;
  - `EP1`–`EP9` (`EP5` in two tests);
  - `OT1`–`OT5`;
  - `SG1`–`SG7` (`SG1` in three tests, `SG3` in two);
  - `KJ1`–`KJ6` (`KJ1` in two), `WB1` (the final fix wave);
  - `OS1`–`OS4` (`OS1` in two);
  - `SP1`–`SP6`.

  07's six wall test files are unedited (the greps below).

### RC1 and RC2 — the references survey's cost, next to 07's NC4 (D2)

**`RC1` is the asserted part.** A root line drawn among 300 Posts and 300
Pins makes exactly 1,200 `references` calls and 0 overlap tests. An edit
of one Pin also makes exactly 1,200, and `diagnostics()` exactly 600 (the
extension in Task 2). M-08n (a scan per referent) and X2-recall are red
on it (log).

**`RC2`** is 06's NC4 method: JIT, four warm-ups, the median of five,
printed and not asserted. Its n is the number of Posts, each with one
Pin, so **RC2 at n has 2n objects**. The Task 1 review's m-3 ruled the
comparison against NC4 at 2n. From this task's engine gate run, where it
ran concurrently with the other test files:

```
NC4 n=100 line draw median 0.63 ms [0.72, 0.63, 0.71, 0.61, 0.60]; move median 0.94 ms [1.11, 1.04, 0.94, 0.93, 0.93]
NC4 n=300 line draw median 1.79 ms [2.57, 5.17, 1.66, 1.79, 1.67]; move median 1.92 ms [1.95, 1.94, 1.92, 1.89, 1.83]
NC4 n=600 line draw median 2.65 ms [3.04, 4.65, 2.65, 1.98, 2.06]; move median 2.33 ms [2.96, 2.33, 2.89, 2.32, 2.20]
RC2 n=100 line draw median 2.04 ms [2.15, 2.00, 2.04, 5.67, 1.99]; move median 2.35 ms [2.35, 2.56, 2.92, 2.16, 2.15]
RC2 n=300 line draw median 2.56 ms [2.65, 2.50, 2.60, 2.56, 2.21]; move median 2.48 ms [4.92, 3.50, 2.45, 2.41, 2.48]
RC2 n=600 line draw median 4.56 ms [4.34, 7.90, 4.56, 4.32, 7.54]; move median 4.76 ms [6.08, 4.76, 6.25, 4.67, 4.65]
```

| objects | NC4 (n = objects) line / move | RC2 (n = objects / 2) line / move |
|---|---|---|
| 200 | no NC4 at 200 (100: 0.63 / 0.94; 300: 1.79 / 1.92) | 2.04 / 2.35 |
| 600 | 2.65 / 2.33 | 2.56 / 2.48 |
| 1,200 | no NC4 at 1,200 | 4.56 / 4.76 |

- **At equal object counts (600), RC2 and NC4 are within noise.** The
  references survey adds no visible cost to 07's line draw or move at
  that size.
- **Not a controlled benchmark.** RC2 at n = 100 runs first in its file
  and is the coldest. The single values spread by 2× within a run.
- **Earlier figures.** Task 1 printed RC2 medians of about 5–9 ms against
  NC4's 1.3–3 ms, which the ledger calls noisy. The Task 1 review
  measured about 7 allocations per referring object per survey, linear.

### RC3 — the same method in the app (Ruling 08-6)

Real walls, one door each, n walls; a root line draw and a wall move.
Printed in this task's app gate:

```
RC3 n=100 line draw median 5.07 ms [8.37, 5.07, 3.17, 5.17, 2.98]; move median 4.15 ms [4.15, 4.18, 4.06, 3.90, 6.07]
RC3 n=300 line draw median 2.55 ms [2.33, 2.17, 3.75, 2.87, 2.55]; move median 2.73 ms [3.92, 2.68, 2.60, 2.73, 5.18]
RC3 n=600 line draw median 5.03 ms [5.03, 4.97, 5.70, 4.10, 5.71]; move median 4.85 ms [6.49, 4.72, 4.85, 6.15, 4.83]
```

- n = 100 is slower than n = 300 because it runs first, while the JIT is
  cold.
- Task 7 measured about 5.3 ms for a line draw and 6.8 ms for a move at
  n = 600 (ledger).
- **At 600 walls, a root line draw costs about 5 ms,** almost all of it
  the two surveys' O(n) (Task 7's note). The move is no dearer than the
  line draw.

### The per-edit cost with 50 openings on one wall, and the memo

From the ledger, not re-run here.

- **Task 5 review:** before symbols, `diagnostics()` took 7.98 ms and an
  edit 3.22 ms.
- **Task 6** (a thickness edit):
  - 2.97 ms before symbols;
  - **21–27 ms** once each opening's symbol recomputed its host's cuts,
    without a memo;
  - **4.1–6.0 ms** with `hostCutsInView` memoised per view and host;
  - a move took 2.1–2.6 ms, and `diagnostics()` 1.2–1.7 ms.
- **Task 6 review:** about 5 ms at 50 openings, which is the pre-symbol
  cost again. With the memo off, the cost grows as n³. `cutsOf`'s
  admission is about n² log n per host, accepted. A staleness probe was
  green, and `rv6-globalMemo` (one memo for every view) was red in 17
  tests.

### OT4 — the opening tools' per-hover cost at 600 walls (Ruling 08-12)

Printed in this task's app gate:

```
OT4 n=600: median per hover over no wall 3.62 us (whole pointer move), host scan alone 1.98 us; over a wall, with the preview, 10.22 us
```

- Task 9 measured 3.68 µs over no wall and 10.56 µs over a wall (ledger).
- 07's Wall tool in the same run: `WT12 n=600: median per hover 5.28 us
  (whole pointer move), band scan alone 2.40 us`. 07's note had 5.72 µs
  and 2.70 µs.
- `OT4` also pins the no-preview path with counters: no preview is built,
  and the frame is rebuilt only after a document change.

### OG9 — the random property run

Printed in this task's app gate:

```
OG9: 1817 walls (300 T stems, 300 X walls, 1151 obstacles), 3235 openings (0 refused), 2647 pieces, 1145 clamped (0 by neither a corner nor a wall), 887 no-fit (321 to keep a piece; 682 covering openings added), 1113 overlapping pairs, 0 childless walls, 0 tiling violations, 0 walls with a piece that does not triangulate, 0 with a piece not simple and anticlockwise, 1858 cut-wall centreline ends at a stored endpoint (0 inexact), 0 trials whose diagnostics differ from the oracle; symbols: 973 doors, 1285 windows, 977 gaps, 0 off the oracle; 2348 fitting, 0 strictly inside their host's pieces; 887 no-fit, 9 of them inside their host's pieces (exempt, D12's limit); 440570 samples; 11288 ms
```

- **Every assertion held:** 0 refused edits, 0 tiling violations, 0
  childless walls, every piece simple, anticlockwise and triangulable.
- **On `OG9`'s generator only** (the final review's I1). Its joints are
  2–4-way nodes at random angles, T stems and X crossings; it never makes
  a slightly kinked joint into a wall of another thickness or
  justification with an opening clamped against it. There, at
  `5739442`, the final review's sweep refused **79 of 1,620** edits (bends
  of 0.25°–12°, both ways; 0° never). The fix wave's `KJ2` runs that
  sweep: **0 refused, 0 no-fit** (`KJ2: 1620 cases, 0 refused, 0 no-fit`,
  printed in the gate above). A wider search the fix wave ran as a
  scratch probe (7,776 kinked joints from 1e-7° to 179.9°, both ways,
  four thickness pairs, nine justification pairs, both ends, two widths)
  refused 238 at `5739442` and **0** after; 8 of its cases, all at a
  1e-6° kink, are now no-fit by the validity check (`KJ1`'s second
  test).
- **The fix wave's run of `OG9`** prints the same counts, bit for bit
  (10,929 ms): no `OG9` case changed.
- **Diagnostics:** `diagnostics()` equals the oracle's in every trial.
- **Symbols:** every one is on the oracle, and no fitting symbol lies
  inside its host's pieces.
- **The 9 no-fit symbols inside their host's pieces** are spec D12's
  recorded limit.
- **Unchanged since Task 7:** the symbol counts (973 doors, 1,285
  windows, 977 gaps, 2,348 fitting, 887 no-fit, 9 inside) are Task 7's
  (ledger). The clamp and keep-a-piece counts (1,145 clamped, 0 by
  neither; 321 made no-fit to keep a piece) are Task 5's fix round's.

**HF7** (the view and document adapters, bit for bit), in the same run:

```
HF7: 314 walls (209 cut), 525 openings, 384 fitting, 768 gap edges (182 beyond a dropped piece), 0 mismatches
```

### End drags: EP7, EP9 and the drift of 2,000 drags (D13)

Printed in this task's app gate:

```
EP7: 97 of 200 doors re-seated
EP9: 11 of 24 doors clamped by B's old end
```

- **`EP7`:** 97 of 200 flush doors would be clamped by an ulp under the
  old rewrite `L′ − (L − p)`. With `_seated`, all are stored where they
  are drawn, and 0 are clamped after (the assertion).
- **`EP9`:** the `moved:` neighbour half. On 24 L corners, 11 would be
  clamped by the neighbour's old end.
- **Drift:** the Task 8 review ran 2,000 random end drags. The maximum
  drift was **1.9e-7 mm**, a random walk with no creep (ledger).

### RD1 — the pixel check on Blueprint

Printed in this task's app gate:

```
RD1 leaf [1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00] body [0.00, 0.00, 0.00] paper 0.22
```

A door hinged beside a later piece is drawn white along its leaf, over
the black wall body.

### D18's figures (Task 13's probe, from the ledger)

Task 13's printing probe (`t13-probe.log` beside the ledger) matched
**every** figure of spec D18:

- **Entities:** 549 live entities.
- **Walls:** 72 children in 24 pieces (E1 2, E2 3, E3 5, E4 3, P1 3, P2 2,
  P3 3, P4 2, P5 1).
- **Openings:** 14 door and 24 window children.
- **Margins:** `SP4`'s tightest is 40.0 mm.
- **Extents:** `(12000, 8000, 26000, 17000)`, exact.
- **Clean:** `drift()` and `diagnostics()` are empty, the obstacle
  intervals are as the spec's tables give them, and all 15 cuts are
  unclamped.

The Task 13 reviewer's own probe agreed. It also found that no swing
reaches another wall (the minimum is 490 mm).

### The invariants and greps (Task 15, re-run by this task)

Task 15 was run read-only by the Task 14 reviewer (ledger). It found no
defect, and every grep had a positive control. This task re-ran the
plan's commands on the final tree, with `BASE=e30386a`
(`git merge-base HEAD spec-08/openings`); saved as `plan08/t16-greps.log`:

```
$ grep -rnE "^\s*(import|export)\s+.(package:flutter|dart:ui)" packages/jet_cad_2d/lib apps/floor_planner/lib/parametric/wall_geometry.dart apps/floor_planner/lib/parametric/opening_geometry.dart
exit 1
$ git diff "$BASE" -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l
0
$ grep -rn "Tolerance.standard" apps/floor_planner/lib/parametric/wall*.dart apps/floor_planner/lib/parametric/opening*.dart
exit 1
$ grep -rn "handleSeed.next" packages/jet_cad_2d/lib/src/parametric/
exit 1
$ grep -rnE "debugReferenceCalls\s*(=|\+\+|\+=)" packages/jet_cad_2d/lib
packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:446:    debugReferenceCalls++;
packages/jet_cad_2d/lib/src/parametric/regeneration.dart:28:int debugReferenceCalls = 0;
$ grep -rnE "TrueColor|kWallColor" apps/floor_planner/lib/parametric/opening.dart apps/floor_planner/lib/parametric/opening_geometry.dart
exit 1
$ git diff "$BASE" --stat -- packages/jet_cad_2d/lib
 .../lib/src/parametric/parametric_system.dart      | 103 ++++++-
 .../lib/src/parametric/regeneration.dart           | 301 +++++++++++++++++++--
 2 files changed, 383 insertions(+), 21 deletions(-)
$ git diff "$BASE" --stat -- packages/jet_cad_2d_flutter/lib
 .../lib/src/draw/placement_tool.dart               | 12 +++++--
 .../jet_cad_2d_flutter/lib/src/grip_cache.dart     | 40 ++++++++++++++++++----
 packages/jet_cad_2d_flutter/lib/src/grip_drag.dart | 24 ++++++++-----
 .../jet_cad_2d_flutter/lib/src/select_tool.dart    | 18 ++++++----
 4 files changed, 71 insertions(+), 23 deletions(-)
$ git diff "$BASE" --stat -- (07s six wall test files) | wc -l
0
$ grep -rn "spike_openings" apps packages
exit 1
$ git rev-list --count "$BASE"..HEAD
31
$ ... grep -c Co-Authored-By
31
$ ... grep -c Claude-Session
31
$ git log --name-only --format= "$BASE"..HEAD | grep -c analysis_options.yaml
0
```

Both allocation invariants pass in the gates above and are unedited
since the base. The engine's barrel exports `parametric_system.dart`
whole, so `ReferencePolicy` and `DanglingReferenceError` are exported
without an edit (Task 15, ledger). The loose grep
(`grep -rn "package:flutter\|dart:ui"`) matches three pre-existing doc
comments and no import (Task 15, ledger).

### Mutation tally

From [plan-08-mutation-log.md](plan-08-mutation-log.md): **228 fired,
220 killed, 0 survived; 8 equivalent (fired, and they survive as
argued); 8 N/A.** Two controls survive, as the spec says they must, and
are not counted. Before the final fix wave it stood at 214 fired, 207
killed, 7 equivalent; the fix wave fired 14 (below).

- **The spec's 37 named mutants: 50 fires, one per site or form, all
  killed** (Ruling 08-21).
  - M-08a was fired structurally, on a scratch copy; `OR1` goes red.
  - M-08b, M-08h and M-08i were each fired at four sites, M-08sn at
    three and M-08u at two.
  - M-08q2 was fired in two forms, and M-08pin against `OS2` and 07's
    two `WS7` tests.
- **The tasks' extras: 155 fired, all killed.** That includes 07's three
  band-joining mutants at their new sites in `wall_bands.dart`, and the
  Task 14 review's `own-defaultMovable`, killed by `SG6` in this task's
  first commit.
- **The first run's findings** (Task 14, `b1b4c98`: 204 killed, 1
  survived), both closed in its fix round, `de66cd2`:
  - **F1:** `t11-apertureDir` survived at the slide grip's copy of the
    aperture divisor. A new `SG1` case kills it.
  - **F2:** `OpeningGrips.movable` was a duplicate rule that nothing
    reached. The composite now delegates to it, and M-08i is killed
    there.
- **Two ledger "equivalents" are killed on this tree:** `rv7-invOrder`
  and `rv8-addForm`.
- **N/A:** six reviewer mutants whose edits were never written down, and
  two superseded by rulings (`X2-fillskip`, `X5-lowest`); their
  successors are fired.
- **Independent re-fire:** the Task 14 reviewer re-fired 31 log entries
  and reproduced every value and line (ledger).
- **The final review** (ledger) re-fired ten log entries, all killed, and
  fired ten of its own, `fr-X1`–`fr-X10`: six killed, and **`fr-X4`,
  `fr-X7`, `fr-X8`, `fr-X9` survived** the whole app suite at `5739442`.
- **The final fix wave fired 14,** each on its final code, all logged:
  - the four survivors, now killed: `fr-X4` by `HF8`, `fr-X7` by `HF9`,
    `fr-X8` by `SG7`, `fr-X9` by `WB1`;
  - I1's: `ffw-validPiece` (the validity check removed) red on `KJ1`'s
    1e-6° test and nowhere else in the app suite; `ffw-dropBacktrack`
    (the cleanup removed) red on `KJ1`, `KJ2` (79 no-fit), `KJ3`, `KJ4`
    and `KJ5`, **and it refuses nothing anywhere**: without the cleanup
    those openings become no-fit, not refused; `ffw-validNoSimple` and
    `ffw-validNoTri` (either half of the predicate) red on `KJ6`;
    `ffw-memoAlways` red on `KJ1`;
  - m1's: `ffw-noFitRaw` and `ffw-noFitLow` red on `OT1 (ffw-noFitRaw)`;
  - m2's siblings: `ffw-obstacleLive` red on `HF9`, `ffw-startBound` red
    on `WB1`;
  - **one equivalent,** `ffw-memoNever` (the admission's memo never
    consulted): it changes the cost, not the outcome, and the whole app
    suite passes.

### A capture observation (Task 13 review, ruled into this note)

The Task 13 reviewer captured the shell with a hand-built camera matrix,
and every LINE entity was dropped; fills and arcs drew. With
`ViewportTransform.fit`, everything drew. The diagnosis by the reviewer
of Tasks 14 and 15 (ledger):

- It is **not a render defect.** In flutter_test, the non-antialiased
  `drawVertices` skips a 1-px stroke quad centred on an integer device
  coordinate (`VerticesDrawSink`'s `kMinStrokeDevicePixels` floor).
- `fit`'s fractional translation avoids it, and device MSAA covers it.
- **Capture tests should avoid whole-pixel translations.**

---

## Exit gate

The spec's seventeen criteria and where each is witnessed:

| # | criterion | witness | state |
|---|---|---|---|
| 1 | the four gate lines on the human's macOS machine; `flutter build macos --release` and `flutter build web --release` | Linux half: the four lines above, with only the standing failures (the engine's 2 hash tests; the render layer's 5 `text_ladder` and 2 Linux-only `text_lod_ladder` goldens, and its skip), and `✓ Built build/web`. **The macOS build and the macOS run of the four lines: the human's machine** | **OWED** |
| 2 | both faces cut at the documented position and width; non-axis-aligned, rotated group, far origin, non-central | `OG1` (both faces' gap corners against the oracle; the door's leaf and arc), `OG9` | PASS |
| 3 | moving or rotating the host moves its openings; one undo step; exact undo and redo; a far move included | `OR1` (75 m move, then a rotate), `EP4`, `RF3`, `SG2` (a wall and its door moved together) | PASS |
| 4 | an end drag keeps openings put; a whole-wall move keeps stored positions | `EP1`–`EP9` (`EP7`–`EP9`: the re-seat and its neighbour half) | PASS |
| 5 | deleting the host cascades in one step, whatever deleted it; undo restores every child handle; `orphan` keeps and regenerates | `CS1`–`CS12`, `LV1`, `LV2`, `OR5`; the shell's "cmd+Z undoes a Delete" (E1 and its front door) | PASS |
| 6 | save → load → save byte-identical; `drift()` empty after load; a dangling reference reported, not repaired | `OR2` (fractional values), `SP6`, `DR2`, `OD1` | PASS |
| 7 | two openings cut correctly; overlapping ones cut their union, reported once per pair | `OG1`, `OG2`, `OG6` (with the nested door-in-window case) | PASS |
| 8 | clamping, obstacles and no-fit as D7, D8 and D11 say, diagnosed as D17 says, and only those | `OG2`–`OG7`, `OG11` (a)–(d), `OD1`, `HF3`–`HF6`; `OG9` compares `diagnostics()` with the oracle in every trial (0 differ) | PASS |
| 9 | every stored piece triangulates; the property run refuses nothing and finds no tiling violation | `OG9`: 0 refused, 0 tiling violations, 0 non-triangulable pieces, 0 childless walls. **At `5739442` this held on `OG9`'s generator only:** the final review's kink sweep refused 79 of 1,620 (I1). **After the final fix wave** (D8: every piece left valid; D9: the back-tracking vertex dropped): `KJ2`, that sweep, 0 refused and 0 no-fit; `KJ1` the review's repro lands and a 1e-6° kink is no-fit, not refused; `KJ3`–`KJ5` through the shell | PASS |
| 10 | the two-hop case regenerates (`drift()` empty) | `RF4`, `OR4` | PASS |
| 11 | the references survey is O(n), measured and pinned by its counter | `RC1` (exactly 1,200 calls, 0 overlap tests); `RC2` and `RC3` printed above | PASS |
| 12 | the allocation invariants pass unchanged | the invariants' diff against `e30386a` is empty; both pass in the gates | PASS |
| 13 | draw order ascending; an opening's children keep their handles; a fitting symbol is not covered by its host's pieces | `RD1` (pixels), `OR8`, `OG7`, `OG10`; `OG9`: 0 fitting symbols inside their host's pieces | PASS |
| 14 | the tools, the slide grip, the Opening section, and no move or rotate for openings | `OT1`–`OT5` (with `OT1 (ffw-noFitRaw)`: a no-fit tool position in `[0, L]`), `SG1`–`SG7`, `MV1`–`MV4`, `OS1`–`OS4`, `B12`, `WB1` | PASS |
| 15 | the sample plan as D18 says; the carried-over tests pass; `drift()` and `diagnostics()` empty | `SP1`–`SP6`, the shell's three sample-plan tests; Task 13's probe matched every D18 figure | PASS |
| 16 | every named mutant killed, M-08a structurally, all logged | the log: 37 names, 50 fires, all killed | PASS |
| 17 | the human's look on macOS, in Chrome and in Firefox | see below | **OWED** |

**15 of 17 PASS; criteria 1 and 17 are OWED.** Criterion 1's Linux half is
green. Nothing was simulated to fill in either owed criterion.

### Review Focus items and their tests

1. D on a wall near its corner: clamped, stored where drawn, no
   diagnostic. `OT1`.
2. Delete a wall with two doors, then cmd+Z: the doors come back, same
   child handles, one step. `OR5`, `CS1`.
3. Drag a wall's start grip along its line: its doors do not move. `EP1`.
4. Select a door and press Delete: the wall closes up; cmd+Z reopens it.
   `OR6`.
5. Type a width with D active, click the canvas without Enter: the door
   has the typed width. `OS3`.
6. Drag a selected door's body: nothing moves, nothing in the history;
   the slide grip moves it. `SG2`, `SG1`.
7. The sample plan on Blueprint: walls black, symbols white, nothing
   covered. `RD1`, `SP5`.

---

## OWED by the human

**Nothing below is ticked on the human's behalf.**

### Criterion 1's macOS half

- ☐ done ☐ not done: `cd apps/floor_planner && flutter build macos --release` → `✓ Built`.
- ☐ done ☐ not done: the four gate lines with `CI=true` on macOS (engine,
  render layer with only its standing failures, harness, app).

### Criterion 17: the look

Run it on each platform:

- **macOS:** `cd apps/floor_planner && flutter run -d macos --release`;
- **Chrome:** `cd apps/floor_planner && flutter run -d chrome --release`;
- **Firefox:** `build/web`, served statically
  (`cd apps/floor_planner/build/web && python3 -m http.server`).

Use cmd on macOS and ctrl in a browser. For each item and platform,
tick one box.

| # | item | macOS | Chrome | Firefox |
|---|---|---|---|---|
| 1 | **The Door tool (D) and its preview:** hovering a wall shows the door's leaf, arc and two jamb lines; the snap marker sits on the wall's centreline; a click places one door, centred at the click, swinging to the clicked side, hinged on the jamb nearer the wall's nearer end; the tool stays active; Esc returns to Select | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 2 | **The Window (N) and Gap (G) tools:** the same, with three lines for a window and one inset threshold line for a gap; nothing happens off a wall | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 3 | **Edge snaps:** with F3 on, an opening's edge snaps to a corner's straight end, to a T or X wall's edge, and to another opening's edge; with F3 off, it does not | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 4 | **Cuts at L, T and X:** both faces are cut cleanly; an opening clicked into a corner lands clamped beside it; no opening is placed under a T stem or a crossing; one that fits nowhere draws outside the wall | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 5 | **Moving a wall with openings,** and cmd/ctrl+Z: the openings go with it and come back | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 6 | **End-dragging a wall with openings** along its line: the openings stay where they are; one undo restores | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 7 | **Deleting a wall with openings:** they go with it; one undo brings the wall and all its openings back | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 8 | **The slide grip:** a selected opening shows one grip at its centre; dragging it slides the opening along the wall; dragging the opening's body moves nothing; no rotation grip for openings alone | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 9 | **The Opening section:** Width and Position commit one undo step each; a door's Flip hinge and Flip swing work; with D, N or G active the section edits the tool's width (a typed width then a canvas click places at that width); the pinned target: select opening A, type a width, click opening B; A takes it and B does not | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 10 | **The sample plan on White:** walls, doors and windows where the old double lines and symbols were; furniture clear of every door | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 11 | **The sample plan on Blueprint:** walls black, doors and windows white, no symbol covered | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |

**Known behaviour to expect,** recorded so the look does not rediscover
it. None of it is an 08 defect.

- **Near a short stub:** a door cannot be placed near a short T stub. The
  stub blocks about a metre of the host (the known limits below).
- **Near a corner:** a no-fit symbol next to a node can hide under its
  own host's corner lobe (D12's limit).
- **Next to another wall:** a door near an acute corner can swing over
  the other wall's band, and whichever is drawn later shows. Visible on
  Blueprint only.
- **On Blueprint,** the startup plan's finishes and furniture stay dark
  (fix/post-07's debt).

---

## Known limits

Recorded, not defects, each by a ruling:

- **Task 3's short-stem over-block.** Spec D7 crosses a T stem's faces
  with the host's near face as infinite lines, so a 100 mm stub blocks
  about 1,080 mm of the host where no stem lies (Task 3 re-review m1). It
  errs safe. Cost if wrong: a door cannot be placed near a short stub.
- **Task 3's parallel-skip jump.** A wall parallel to the host within
  `wallJoin.angular` is no obstacle. At 1e-9 rad nothing is blocked; at
  2e-9 rad the rest of the host is (Task 3 re-review m2). This is D7's
  collinear exemption. Cost if wrong: a door cannot be placed along a
  near-parallel wall.
- **D12's no-fit limit.** At a clamped acute corner or a node of three or
  more walls, a no-fit symbol drawn outside its host's strip can lie
  inside its host's own lobe. The Task 6 review found 28 of 481 no-fit
  symbols; this run's `OG9` found 9 of 887. Whether it shows depends on
  handle order. A no-fit opening already carries `opening.nofit`.
- **`storedCentreOf`'s give-up.** A stretch exactly `w` long whose `b − w`
  rounds below `a` holds no unclamped start. There the opening is placed
  clamped by one ulp and reported `opening.clamped` (spec D14's
  amendment; Task 9 review).
- **The oblique projection.** Under a non-uniformly scaled host, which
  only a file makes, the projection onto the centreline is done in local
  space, so it is oblique in world (spec D15's amendment).
- **`flutter_test` captures:** a 1-px non-antialiased stroke centred on a
  whole device pixel is skipped (the capture observation above). Capture
  tests should use a fractional translation.
- **A 600-wall line draw costs about 5 ms** (`RC3`), the two surveys'
  O(n). A plain edit among many walls is linear in the plan's size.
- **Acute joints and folded walls shrink the straight span** (spec D7's
  final-fix-wave amendment; the final review's m3). The span follows 07's
  caps: at a joint of about 12° or less between the walls, or at a wall
  folded back on another, the cap reaches far along the host, so an
  opening there is drawn clamped farther away, or is no-fit, and the span
  can be empty. The final review's fuzz set 93 such oracle disagreements
  aside, each app-correct by D7.
- **A hairline kink makes an end opening no-fit** (spec D8's
  final-fix-wave amendment). At a 1e-6° kink an end cap's vertex falls on
  the cut's jamb, and no valid end piece exists; an opening clamped
  against that end is no-fit rather than cut (`KJ1`'s second test). The
  fix wave's search found 8 such cases in 7,776, all at 1e-6°.
- **The admission now triangulates** each piece it has not yet judged
  (within one admission, a span judged valid is not judged again). A thickness edit on a wall with
  50 openings measured about 3.5–4.2 ms median against 2.8–3.5 ms at
  `5739442`, 61 repetitions, three runs each (a scratch probe, not a
  test; noisy).

## Debt

One line each. None is fixed by this plan.

- **06's bare `RemoveNodeCommand`** leaves a deleted object's own
  generated leaves with a dead owner (R4). 08's cascade is stricter for
  referrers. `CS4` asserts the debt as it is.
- **Paste, import, block explode and file merge must remap stored
  handles:** `OpeningParams.host` through `ParametricType.references` or a
  sibling hook (R4; spec Non-goals). No such path exists yet.
- **Rotate about a chosen base point** is its own follow-up branch after
  08, extending 03 (decision 12).
- **The Text tool's pending entry is lost on a web alt-tab**
  (fix/post-07's debt; `text_entry_overlay.dart` still uses the lifecycle
  guard the Scale field dropped). It is the other candidate for a `fix/`
  branch.
- **The opening tools' hover is a linear scan over the walls** (Ruling
  08-12). A culled scan through the spatial index is the follow-up.
- **A misplaced component on a nested group outlives its node** when the
  cascade removes it. The select tool does the same today (Task 2
  re-review).
- **`DF1`'s bitwise comparison adds little beyond `drift()`**, and its
  history-order mutants are equivalent (Task 7 review, Minor 2).
- **07's (pre-existing): a 1.6° three-wall node reached by an end drag
  stores a ~10.4 m zero-width spike along a face line** (the final
  review's m4). The outline is 07's; 08 inherits it through the caps.

---

## Reviews and rulings, per task

Every verdict and ruling below is the ledger's. Each reviewer ran the
gates and re-fired the task's mutants. "Minors → Task n" means copied
verbatim into Task n's brief (Ruling 08-21).

**Before Task 1.** The controller's pre-execution rulings:
- open question 1 → R1 amended (`48173e2`);
- plan finding 2 → D14's swing from the band's midline (Ruling 08-23,
  M-08z3; `e30386a`);
- the plan's other spec findings accepted as the plan handles them.

**Task 1** (`328df0b`), references and the closure.
- **Verdict:** Approved.
- **I-1**, a lost referent stayed visible to `paramsOf`: fixed in Task 2,
  with the broader rule that `paramsOf` answers null for any handle not
  a live object of the view's survey.
- **Minors m-1, m-2:** Task 2 added the tests.
- **Minor m-3:** RC2 gets four warm-ups, and this note compares it with
  NC4 at 2n.

**Task 2** (`5868948`, fix round `9f9d3a3`), the policy, the cascade and
dangling references.
- **Verdict:** Needs fixes. **Re-review:** Approved.
- **Fixed in the round:**
  - I-1: the cascade's geometry capability (`CS8`);
  - I-2: the whole cascade under one rollback (`CS9`);
  - m-1: fills first (`CS10`);
  - m-2: the ascending referent order (`DR3`);
  - m-3: subtree removal (`CS11`);
  - the broader `paramsOf` rule (`LV2`).
- **m-4:** not taken.
- **Re-review minors → Task 3's first commit:** fills of the whole doomed
  subtree first (`CS12`), and an instance under P1 (`CS11`).

**Task 3** (`db662ee`, `a70ad40`; spec `d15c5a1`; fix round `680f24b`),
`OpeningParams` and the host frame.
- **Verdict:** Approved. **Re-review:** Approved.
- **S1, ruled:** D7 amended by the controller. A T's interval also takes
  the points where B's faces cross the host's near face.
- **Minors m1–m4:** in the fix round.
- **m5 → Task 5**, and the M-08s note → Task 4.
- **Recorded, not fixed:** the short-stem over-block and the
  parallel-skip jump, both in the known limits above. The stale `HF3`
  bullet is amended in the plan.
- **The re-review's differential:** 20,000 random tees, worst difference
  9.2e-9.

**Task 4** (`4950c40`), the pieces.
- **Verdict:** Approved. 07's uncut path is byte-identical over 200
  random plans.
- **Finding:** a zero-piece wall. D8 amended: keep a piece (spec
  `5b74810`, revised by `0b300b1`).
- **Minors → Task 5:** m1 (merged cuts and short pieces, in D8), m2 (CCW
  asserted), m3 (`HostFrame.e`).

**Task 5** (`b74787b`; spec `0b300b1`; fix round `2b64812`), obstacles,
overlap and diagnostics.
- **Verdict:** Needs fixes. **Re-review:** Approved.
- **I-1**, the admission loop's "repeat" untested; and **S1**, admit in
  ascending handle order: D8 revised (`OG11` (a)–(d); `OG9` makes
  keep-a-piece cases).
- **S2 and m-1**, the degenerate host: `opening.nofit`, draws nothing
  (`OD1`).
- **S3 and m-2:** walls named by exact overlap in D17.
- **m-3:** left to Task 6, which removed `HostCuts.params`.
- **The cost carry:** Task 6 memoises if an edit costs more than a few
  ms.
- **Re-review m-1**, the exact corner comparison → Task 6.

**Task 6** (`f1073b7`; spec `c71d3b1`), the symbols.
- **Verdict:** Approved. The memo is sound; the arc is correct for all
  four hinge × swing cases under three justifications.
- **m-1:** D12's no-fit limit, recorded in the spec.
- **m-2 → Task 7:** `OG9` checks the symbols.
- **m-3:** D10's wording (own space).

**Task 7** (`762b268`), follows, cascades, saves.
- **Verdict:** Approved.
- **A runner slip:** a double backup of `parametric_system.dart`. It was
  caught by `git diff`, restored from the original, and the invalid runs
  were discarded.
- **Minor 1 → Task 8:** `OR2` fractional.
- **Minor 2**, and `rv7-invOrder` as equivalent: recorded. The log now
  counts `rv7-invOrder` killed.

**Task 8** (`127185a`, `71de39d`), end drags.
- **Verdict:** Approved. 2,000 random drags drift at most 1.9e-7 mm.
- **Minors m1–m3 → Task 9:** `EP6`, `EP5`'s start-drag case, and `EP1`'s
  reason text.
- **D13's "both ends moved":** noted for this task.

**Task 9** (`dc54f3f`, `267e66e`), the tools.
- **Verdict:** Approved. 07's three join mutants were re-fired at their
  new `wall_bands.dart` sites, red with 07's exact values.
- **Findings:**
  - `storedCentreOf`, the ulp correction: D14 amended here;
  - the handle prediction: removed in Task 10;
  - `hostAt` over non-live walls;
  - `OG9`'s generator moved to the fixture.
- **Minors m1–m5 → Task 10's first commit:** all taken. The handle is now
  allocated inside the build, and `WallBands` holds live walls only.

**Task 10** (`8408561`, `71c7047`), edge snaps and the marker.
- **Verdict:** Approved. The hover and the commit agree on 1,928 presses.
- **Minors → Task 11's first commit:**
  - m1: `OT3` tells drawn edges from stored ones;
  - m2: the aperture divides by `|toWorld · d|`.

**Task 11** (`b975db8`, `2670033`), the grips.
- **Verdict:** Approved. 03's and 07's grip tests are green; a mixed
  selection moves the rest in one step.
- **I1**, rooted in Task 8's rewrite: `p′` leaves a flush door clamped by
  an ulp, so the grip cannot re-seat it. Fixed in Task 12's first commit
  (`_seated`; the grip's no-change rule).
- **m1:** `SG1`'s nudge. **m2:** `SG4`.
- **m3:** `movableKey` stays public, recorded in the spec.

**Task 12** (`d0640e4`, `c9ba0e7`), the Opening section.
- **Verdict:** Approved. `_seated` never moves a door visibly, and the
  panel meets every 07 and fix/post-07 convention.
- **Minors m1–m4 → Task 13's first commit:** `EP9`, `EP8`, `OS1`'s bounds,
  `SG5`.

**Task 13** (`f197521`, `645a969`), the sample plan.
- **Verdict:** Approved. The reviewer's independent probe matched D18,
  and the renders look right on Blueprint and White.
- **Plan wrong:** the click point `(x0 + 100, y0)` selects E4. Amended in
  the plan.
- **Minors m1–m3 → Task 14's first commit.** The stale status-text comment
  → this task.
- **The capture observation → the final review's brief.** Diagnosed by
  the reviewer of Tasks 14 and 15; see above.

**Task 14** (`3d1713f`, `b1b4c98`, fix round `de66cd2`), the mutation
log.
- **Findings, ruled into the fix round:** F1 (`SG1`'s grip-site case) and
  F2 (the composite delegates).
- **Review:** Approved.
- **Minors → this task's first commit (`6b3b944`):**
  - Minor 1: `SG6`; `own-defaultMovable` red at line 627;
  - Minor 2: the log's note on shifted lines. This task found nine
    such entries; the review had counted five.

**Task 15:** done by the Task 14 reviewer, read-only. No defect.

**The final whole-branch review** (opus, at `5739442`; the first attempt
was interrupted by an API limit and re-dispatched), from the ledger.
- **Verdict:** With fixes. A fuzz of 41,892 steps (31,997 undo/redo
  pairs, 2,306 save/loads, 4,692 tool placements, 1,999 slides, 1,913
  cascade deletes) found 0 drift and 0 exceptions.
- **I1 (Important):** an opening clamped against a slightly kinked joint
  left a non-triangulable end piece, and the edit was refused: the Window
  tool placed nothing, the slide grip's `ArgumentError` escaped
  pointer-up, a neighbour's end drag was refused. 79 of 1,620 in its
  sweep. **Fixed** by the final fix wave: D8's admission checks every
  piece left (`isValidPiece`), and D9 drops the back-tracking vertex.
- **m1:** the tools stored a no-fit position outside `[0, L]`. **Fixed**
  (`OT1 (ffw-noFitRaw)`).
- **m2:** `fr-X4`, `fr-X7`, `fr-X8`, `fr-X9` survived. **Killed** by
  `HF8`, `HF9`, `SG7`, `WB1`.
- **m3:** criterion 9's caveat, D6's wording, D7's acute joints.
  **Written** (above, and in the spec).
- **m4:** 07's zero-width spike at a 1.6° three-wall node. **Recorded as
  07's debt.**

### The plan's own rulings

08-1 to 08-23 are in the plan, each with its cost. Those this task wrote
into the spec: 08-11 and 08-12 (D14), 08-14 and 08-15 (D15), 08-16 and
08-17 (D16), 08-1's renames and 08-6's `RC3` (Testing, D2, D13). 08-23
was already amended into D14 at planning.

---

## Spec amendments

In [2026-09-25-openings-design.md](../specs/2026-09-25-openings-design.md).

**Already amended in flight by the controller**, marked in place:
- **D7:** a T's interval includes the face crossings (Task 3 S1).
- **D8:** a wall keeps a piece, by admission in ascending handle order;
  a degenerate host's openings are no-fit and draw nothing (Tasks 4 and
  5).
- **D10:** the arc is anticlockwise in the opening's own space (Task 6
  m-3).
- **D12:** the no-fit limit (Task 6 m-1).
- **D14:** the swing from the band's midline (at planning, Ruling 08-23).
- **D17:** walls named by exact overlap; "a corner" only outside the span
  (Task 5 m-2 and S3).

**Written by this task,** each a paragraph beginning "**Amended at
execution (Plan 08)**" at the end of the section it amends:
- **Header:** a pointer to the amendments and to this note.
- **D2:** `RC1`'s extension; `RC2`'s four warm-ups and the 2n comparison;
  `RC3` (Ruling 08-6); the declared list; the `Peg` client.
- **D3:** none needed.
- **D4:** `paramsOf` hides a lost object; fills first over the whole
  subtree; one rollback for the whole cascade; the index hears the
  cascade; the re-parent case is reachable.
- **D5:** the refusal's order (`DR3`); the handle seed; `opening.orphan`
  against `parametric.dangling`.
- **D7:** the parallel skip; the two known limits; the frame's inputs.
- **D9:** the first and last centreline pieces end at the stored
  endpoints; anticlockwise asserted; a wall keeps a piece.
- **D13:** the re-seat through `storedCentreOf` when rounding alone would
  clamp; the adapter's `moved:`; which openings; "both moved" imprecise
  but harmless; `EG` → `EP` (Ruling 08-1); `EP1`'s fixture (Ruling
  08-10); the drift.
- **D14:** `storedCentreOf` (the ulp correction and its give-up); the
  handle allocated inside the build, with no prediction; the band cache
  (Ruling 08-11); the per-hover cost (Ruling 08-12); `OT2`'s hard cases.
- **D15:** `PlacementTool.markerPoint` (Ruling 08-14); the aperture in
  host-local units, world ÷ `|toWorld(host) · d|`; the snapped centre
  stored exactly; `edgeSnap`'s inputs; the slide grip on the resolved
  point (Ruling 08-15); the oblique projection under a non-uniform
  scale.
- **D16:** the grip's no-change rule (`==`, or within `wallJoin.linear`
  and not drawn clamped); `movable` everywhere (Ruling 08-16);
  `movableKey` as new public render API; `OpeningGrips.movable` as the one
  rule; the tool-mode sentinels (Ruling 08-17).
- **D18:** none; Task 13's probe matched every figure.
- **Architecture, Files:** the barrel is unchanged; the render layer adds
  `placement_tool.dart` and `movableKey`; `wall_bands.dart` is new;
  `tool_palette.dart` is unchanged (Ruling 08-22).
- **Testing, tests by area:** identifiers as built (`EP`, `RF6`–`RF8`,
  `CS6`–`CS12`, `DR3`, `LV1`–`LV2`, `MV1`–`MV4`, `B12`, `HF1`–`HF7`,
  `OG11`, `OD1`, `DF1`, `RC3`, `OT5`, `SG3`–`SG6`, `SP6`).
- **Named mutants:** 50 fires at every site; M-08m's and M-08s's
  fixtures.
- **Open questions:** each one's end. 1 resolved; 2, 3, 5–12 and 14
  built as written; 4 with D13's amendment; 13 resolved by the memo.

**Written by the final fix wave,** each a paragraph beginning
"**Amended at execution (final fix wave)**":
- **Header:** a pointer to them.
- **D6:** the tools and the slide grip stay in `[0, L]`, no-fit included
  (m1).
- **D7:** the known limit on acute and folded joints (m3); the document
  adapter's live walls; the frame's local-space fallback.
- **D8:** every piece left is valid; an opening that would leave an
  invalid piece is no-fit (I1); the slide grip reads the admission.
- **D9:** the back-tracking vertex is dropped; "every stored piece is
  valid" enforced, not only asserted (I1).
- **Testing, tests by area:** `KJ1`–`KJ6`, `OT1 (ffw-noFitRaw)`, `HF8`,
  `HF9`, `SG7`, `WB1`.

## Plan amendments

In [2026-09-25-openings.md](../plans/2026-09-25-openings.md), each a
paragraph beginning "**Amended at execution (Plan 08)**":
- **Ruling 08-16:** the composite delegates to `OpeningGrips.movable`.
- **Global Constraints:** `unused_import` is a warning in the app, and
  `flutter analyze` still exits 1 on it (checked by this task with a
  throwaway file, deleted).
- **Task 1:** the `Peg` type (`RF1` against X1-sort); `RC2`'s four
  warm-ups.
- **Task 2:** fills first, the subtree and one rollback (X2-fillskip
  superseded); `paramsOf`; `RC1` extended because X2-recall could not
  turn a line draw red; `CS7` reachable.
- **Task 3:** `HF3`'s WG19 bullet → amended D7 (`≈[2690.0, 3881.8]`);
  `HF1`'s bound 1e-8; the parallel skip.
- **Task 4:** `HostFrame.e`; Step 2 became `cutsOf` with keep-a-piece;
  the oracle's details; `OG9`'s counts.
- **Task 5:** M-08m's nested case; the 5e-7 touching cases; M-08q2's
  reporter; `OG11` is a new test ID; `OD1`'s degenerate host; exact
  clamp causes; X5-lowest superseded.
- **Task 6:** the arc's start in half the cases; the memo;
  `HostCuts.params` removed; `OG9` checks the symbols.
- **Task 7:** `OR2`'s integer values made fractional; the 600-wall line
  draw.
- **Task 8:** `_seated` and `moved:`; `EP5`'s drag back; `EP6`–`EP9`.
- **Task 9:** `storedCentreOf`; Step 3.4's formula predates Ruling 08-23;
  the handle allocated inside the build; the scan memo and live walls;
  `OG9`'s generator.
- **Task 10:** `edgeSnap` takes no frame; the local aperture; exact
  storage; the invalidate.
- **Task 11:** `OpeningGrips.movable` is false for an opening (the plan's
  "true" was a slip); the no-change rule; the candidates; `movableKey`.
- **Task 12:** the sentinels; no Position field in tool mode; `OS1`'s
  bounds.
- **Task 13:** the click point: `(x0 + 3000, y0)` for E1 and `(x0, y0 +
  4500)` for E4; `SP2` against the lowest finish; the probe matched.
- **Task 14:** 37 named mutants, not 36; the multi-site list as fired;
  the tally.
- **Mutant assignment:** M-08z3 → Task 9; the total is 37.

---

## Files this task touched

**First commit, `6b3b944`:**
- `apps/floor_planner/test/opening_grips_test.dart`: `SG6
  (own-defaultMovable)`.
- `apps/floor_planner/test/planner_shell_test.dart`: the status-text
  test's comment only. Its probe point is on E1's outer face; a
  throwaway probe (deleted) confirmed that it resolves to E1's group.
  Ruling 08-1 was lifted for this one comment.
- `docs/superpowers/notes/plan-08-mutation-log.md`: the tally, the
  shifted-lines note, the `own-defaultMovable` entry, and the app gate.

**Second commit** (this note's):
- `docs/superpowers/notes/2026-09-25-plan-08-results.md`: this file.
- `docs/superpowers/specs/2026-09-25-openings-design.md`: the amendments
  above.
- `docs/superpowers/plans/2026-09-25-openings.md`: the amendments above.
- `STATUS.md`: a Plan 08 section, the top paragraph, the branch map, and
  "Resume here".
- `roadmap/08-openings.md`: the status line.
- `roadmap/00-README.md`: the 08 row and the summary under the table.

**The final fix wave** (one commit):
- `apps/floor_planner/lib/parametric/opening_geometry.dart`: the
  back-tracking cleanup (`_dropBacktracks`), the piece predicate
  (`isValidPiece`), the admission's validity check and its span memo.
- `apps/floor_planner/lib/parametric/opening_tool.dart`: a no-fit
  position clamped to `[0, L]`.
- `apps/floor_planner/test/opening_kink_test.dart` (new): `KJ1`–`KJ6`.
- `apps/floor_planner/test/wall_bands_test.dart` (new): `WB1`.
- `apps/floor_planner/test/opening_geometry_test.dart`: `HF8`, `HF9`.
- `apps/floor_planner/test/opening_grips_test.dart`: `SG7`.
- `apps/floor_planner/test/opening_tool_test.dart`: `OT1
  (ffw-noFitRaw)`.
- `docs/superpowers/specs/2026-09-25-openings-design.md`,
  `docs/superpowers/notes/plan-08-mutation-log.md`, this note,
  `STATUS.md`.
- 07's six wall test files are unedited.
