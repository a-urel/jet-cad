# Plan 07 — walls: results

**Plan:** [2026-09-24-walls.md](../plans/2026-09-24-walls.md).
**Spec:** [2026-09-24-walls-design.md](../specs/2026-09-24-walls-design.md)
(revision 1, amended at execution; see "Spec amendments" below).
**Mutation log:** [plan-07-mutation-log.md](plan-07-mutation-log.md).
**Spike:** [2026-09-24-walls-spike-findings.md](2026-09-24-walls-spike-findings.md)
(branch `spike/07-walls` at `45aecb6`, never merged).
**Branch:** `plan-07/walls`, cut from `spec-07/walls` at `f2daba5` (`main`
`22957d1` + spec `dfb6969` + plan `f2daba5`), in the session worktree
`.claude/worktrees/walls`.
**Tasks 1–10 are at `f2daba5..330797c`. Task 11, this note, is the next
commit.** The final whole-branch review comes after it. The ledger archive
(`docs/superpowers/ledgers/2026-09-24-walls/`) is the branch's last commit,
after that review.
**Ledger:** `.superpowers/sdd/2026-09-24-walls/progress.md` (git-ignored
while in flight). It is the source for every ruling, deferral and
measurement quoted below that this task did not run itself. Each such
figure names the ledger as its source.
**Environment:** a Linux x86_64 cloud container, Flutter 3.47.2 / Dart
3.13.2 at `/root/flutter`. `flutter build macos --release` and the look are
the human's (Ruling 07-6).

---

## What was measured

### The four gate lines, pasted with exit codes

Run by this task, in full, with `CI=true`, on the final code tree:
`330797c` plus Task 11's one code edit, `WG21`'s title. Each command ran
separately so each has its own exit code. `git status --short` showed no
`analysis_options.yaml` after the run.

**`packages/jet_cad_2d`**: `CI=true dart test`:

```
00:12 +972 -2: Some tests failed.

Failing tests:
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
```

Exit 1. **972 pass, and exactly the two standing Linux-only hash tests**
(Ruling 07-7; spike finding 7). `dart analyze`: `No issues found!`, exit
0. `dart format --output=none --set-exit-if-changed .`: `Formatted 144
files (0 changed) in 0.46 seconds.`, exit 0.

**`packages/jet_cad_2d_flutter`**: `CI=true flutter test`:

```
00:45 +931 ~1 -7: Some tests failed.

Failing tests:
  test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  ... and 3 more
```

Exit 1. The runner truncates the list. The `[E]` lines in the same
transcript name all seven failures:

```
test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas) [E]
test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas) [E]
test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas) [E]
test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas) [E]
test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas) [E]
test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas) [E]
test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 2 (RenderBackend.canvas) [E]
```

**931 pass, 1 standing skip, and exactly the seven standing failures:**
`text_ladder` rungs 1–5 (standing everywhere) and `text_lod_ladder` rungs
1–2 (Linux-only goldens, Ruling 07-7 as extended in the ledger).
`flutter analyze`: `No issues found! (ran in 1.2s)`, exit 0. `dart format`:
`Formatted 177 files (0 changed) in 0.58 seconds.`, exit 0.

**`apps/dev_harness_2d`**: `CI=true flutter test --concurrency=1`:

```
00:38 +82: All tests passed!
```

Exit 0. `flutter analyze`: `No issues found! (ran in 1.0s)`, exit 0. `dart
format`: `Formatted 22 files (0 changed) in 0.10 seconds.`, exit 0.

**`apps/floor_planner`**: `CI=true flutter test`:

```
00:22 +138: All tests passed!
```

Exit 0. `flutter analyze`: `No issues found! (ran in 1.0s)`, exit 0. `dart
format`: `Formatted 32 files (0 changed) in 0.14 seconds.`, exit 0.
`flutter build web --release`:

```
Compiling lib/main.dart for the Web...                             39.0s
✓ Built build/web
```

Exit 0. **`flutter build macos --release` is OWED:** the container cannot
build macOS (Ruling 07-6).

### Branch-point and final counts, and why they moved

Branch-point counts are the ledger's first entry, measured on this
container at `f2daba5`.

| suite | branch point | final (this run) | moved |
|---|---|---|---|
| `jet_cad_2d` | +951 -2 | **+972 -2** | +21 |
| `jet_cad_2d_flutter` | +923 ~1 -7 | **+931 ~1 -7** | +8 |
| `dev_harness_2d` | +82 | **+82** | 0 |
| `apps/floor_planner` | +69 | **+138** | +69 |

- **Engine +21:** `RG1`–`RG11` (11: regions, Task 1; `RG9` and `RG10` from
  its review round; `RG11`, the generated colour, from Task 6b); `NC1`–`NC4`
  (4, Task 2); `DG1`–`DG5` (5, Task 3 and its fix round); `G11` (1, the
  nested-guard fix, Task 3). Task 6's `e882160` added one
  `drag_snap_test.dart` test for the per-tool snap mask, and `f751d4a`
  removed it with the mask, so it nets to zero. The failures are the same
  two tests as at the branch point.
- **Render layer +8:** `OG1`–`OG5` (7 tests, because `OG4` is a group of
  three: the group node, a child's payload and a child added; Task 7), and
  `L7` in `line_tool_test.dart` (1, Task 6 review round 1: other tools
  still do not snap `nearest`). `e882160`'s `snap_marker_test.dart` change
  was reverted by `f751d4a`. The skip and the seven failures are the
  branch point's.
- **Harness 0:** no task touches `apps/dev_harness_2d`.
- **App +69:** `WG1`–`WG21` (21), `WP1`–`WP4` (4), `WR1`–`WR12` (12),
  `WT1`–`WT17` plus `RF2` (18: `WT8`–`WT13` from Task 6's review rounds,
  `WT14` from Task 6c, `WT15`–`WT17` the Task 6 minors carried into Task 8,
  `RF2` from Task 5's review), `EG1`–`EG5` (5), `WP5` (1, `wall_paint_test.dart`,
  Task 6b), `WS1`–`WS6` plus `WS7 (Wall)` and `WS7 (Box)` (8). 06's `SE1`–`SE10`
  are unchanged and green.

The plan named `WG1`–`WG15`, `WR1`–`WR12`, `WT1`–`WT7`, `EG1`–`EG5`,
`WS1`–`WS7`, `RG1`–`RG8`, `NC1`–`NC4` and `DG1`–`DG2`. Everything over
that came from review rounds, each pinned by a mutant in the log or the
ledger.

### NC4 — the neighbour search's cost, before and after (Ruling 07-5)

JIT, in a container, median of five runs, printed and not asserted. **The
figures below are not a controlled benchmark, so this note gives the
method for each rather than one speed-up factor.**

**Before**, from the ledger (Task 2). The implementer ran `NC4` against
the **unmodified** `lib` (06's O(n²) survey, twice per edit), run 1:

| n | line draw | move |
|---|---|---|
| 100 | 2.32 ms | 3.46 ms |
| 300 | 7.24 ms | 6.26 ms |
| 600 | 19.35 ms | 19.56 ms |

The Task 2 reviewer's M-07o stand-in (neighbours computed for every object)
measured **12.63 / 12.72 ms at n = 600** (ledger). The two "before" figures
differ by about 1.5× at the same n, which is the size of the noise in this
setting. 06's final review measured 0.7 / 4.3 / 16 ms (JIT, spec D10).

**After**, from the ledger (Task 2, the test file run alone): n=100 line
0.59 ms, move 0.96 ms; n=300 line 1.25, move 1.23; n=600 line 1.95, move
2.16.

**After, run by this task.** In the full engine gate above, concurrent with
the other test files:

```
NC4 n=100 line draw median 0.62 ms [0.66, 0.59, 0.55, 0.62, 0.63]; move median 0.84 ms [0.99, 0.84, 0.80, 0.83, 1.00]
NC4 n=300 line draw median 1.75 ms [1.75, 2.22, 1.80, 1.52, 1.56]; move median 2.06 ms [2.03, 2.06, 2.17, 2.14, 1.99]
NC4 n=600 line draw median 3.12 ms [3.12, 4.15, 2.79, 3.45, 2.50]; move median 3.34 ms [3.34, 2.36, 2.22, 4.71, 3.80]
```

And alone (`CI=true dart test test/parametric/neighbour_cost_test.dart
--plain-name 'NC4'`, `00:00 +1: All tests passed!`, exit 0):

```
NC4 n=100 line draw median 1.47 ms [1.57, 1.11, 1.47, 1.55, 1.29]; move median 1.81 ms [2.18, 1.79, 1.81, 1.81, 1.70]
NC4 n=300 line draw median 1.11 ms [1.11, 1.14, 1.06, 1.20, 1.04]; move median 1.69 ms [2.35, 1.69, 1.61, 1.66, 2.45]
NC4 n=600 line draw median 2.89 ms [1.75, 1.85, 2.89, 2.94, 3.00]; move median 3.26 ms [3.26, 3.27, 4.33, 3.12, 3.13]
```

In the run alone, n = 100 is slower than n = 300 because it runs first,
while the JIT is still cold. **The asserted part is the counter, not the
time:** `NC1` requires 0 overlap tests for a root line among 300 objects,
and `NC2` requires exactly `(1 + closure) × (n − 1)` for a move. M-07o
gives 179,400 (= 2n(n − 1)) and is killed by `NC1` (log). A line draw
still costs O(n) (the survey's `reach` per object), which is the remaining
slope from 100 to 600.

### WT12 — the Wall tool's per-hover cost at 600 walls

Printed, not asserted. **Before** the Task 6 round-2 fix, the reviewer
measured **214 µs per hover** at n = 600 (JIT; ledger). Each hover rebuilt
world walls from the document for every wall, even with no chain pending.
**After** (`fa94a83`: an early return with no chain, and a `Float64List`
cache rebuilt on a document change), the implementer measured 5.46 µs
(band scan 2.48 µs) and the re-reviewer 5.44 µs (ledger). This task's app
gate printed:

```
WT12 n=600: median per hover 5.72 us (whole pointer move), band scan alone 2.70 us
```

### WG14 — the accepted hole and fallback rates

Spike Q5b's generator, 20,000 nodes, fixed seed. This task's app gate
printed:

```
WG14 nodes 20000 with a hole 152 (0.76%); walls 49887 fell back 54 (0.11%)
```

That is the same as the Task 4 implementer's figures (ledger). The spike
measured 0.78% and 0.11% with its own corner rule. On this branch's
per-wall rotated groups, that rule gave 1.19% holes and 0.17% fallbacks,
against 0.76% and 0.11% through the node's reference point (ledger, Task 4
deviation 1; spec D5.2's amendment). `WG14` asserts < 1.5% and < 0.5%.
That bound would not catch a regression to the spike's rule. `WG12` does.

### Mutation tally

From [plan-07-mutation-log.md](plan-07-mutation-log.md): **51 fired, 51
killed, 0 survived; 4 equivalent (recorded, not fired); 1 N/A.**

- **The spec's named mutants:** 19 (M-07a…M-07s), plus 6 variants at a
  second site or in a second form: M-07e′ (the planner's payload
  comparison), M-07h's two halves, M-07i's node-cap site, and M-07k's "no
  owner" and "highest owner". All 25 were killed.
- **The tasks' extras:** 26 fired, all killed: geometry 8, band joining 6,
  grips 5, panel 3, planner and engine cost 3, colour 1.
- **One finding, fixed:** M-07i at the node's non-owner cap was not killed
  by `WG6`, the spec's named fixture. Only `WG8` killed it in the file.
  `WG6` is degenerate for this mutant: two of its walls have a face
  through the node point. `WG21` landed on the controller's ruling
  (`330797c`), and M-07i was re-fired red against it.
- **Equivalent:** M-07n at `outline`'s call site (equivalent for
  triangulation, not for stored bits); a region emitted after the
  centreline (the planner orders regions first); self in `others`
  (`classify` drops it); `ParametricEdit.apply`'s guard restore (never
  observed).
- **N/A:** the snap-mask mutant. Task 6c removed the mask.
- **Independent re-fire:** the Task 9 reviewer re-fired 11 mutants in 14
  runs, exactly as logged (ledger).

### Smoke tests (the controller's, from the ledger)

These are not the look. The controller built the web app with local
CanvasKit (`--no-web-resources-cdn`, because the proxy's CA is not trusted
by Chromium for gstatic) and drove it with Playwright and the container's
Chromium.

1. **After Task 6: walls rendered white.** W drew a closed room and a T
   with mitred corners, but the bands were paper white. Layer 0 is
   `IndexedColor(7)`, and `aciToRgb(7)` is `0xFFFFFF`. No test rendered a
   wall's colour. **Fixed in Task 6b (`e13d2cb`):** walls carry an explicit
   `kWallColor`, pinned by `RG11` and the pixel test `WP5`. The implementer
   found that no ACI-7 contrast rule exists anywhere (spec D3's
   amendment).
2. **The re-run at `e13d2cb`:** walls black, the room mitred, the T clean.
   It confirmed a **pre-existing defect outside 07**: a line drawn with L
   and a box drawn with B render white (ByLayer on layer 0). The human
   deferred it to a post-07 `fix/` branch.
3. **Skew with grid snap on.** The walls came out slightly skewed. The
   controller first blamed the Wall tool's widened `nearest` snap, which
   pulled clicks onto the sample plan's hatch lines, and `f751d4a`
   removed it. The re-run at `f751d4a` showed walls black and the room
   still slightly skewed with object snap on. **With F3 off the room lands
   exactly on the grid**, with crisp mitres and a clean T. So the skew is
   03 D8's standard object snap: an endpoint or intersection of the dense
   hatch within the aperture beats the grid. It is not a Wall-tool defect,
   and the first diagnosis was only partly right. `f751d4a` stands on its
   own merit, because band joining makes every joint and `nearest` would
   pull clicks onto any line. Recorded for the look.

### The invariants and greps (Task 10, corrected)

Task 10 was done by the Task 9 reviewer, read-only (ledger). Two of the
plan's greps were broken, and the plan now carries an "Amended at
execution" note. This task re-ran the corrected forms on the final tree:

```
$ grep -rnE "^\s*(import|export)\s+.(package:flutter|dart:ui)" packages/jet_cad_2d/lib apps/floor_planner/lib/parametric/wall_geometry.dart
exit 1   (no match: nothing imports Flutter or dart:ui)
$ grep -rn handleSeed.next packages/jet_cad_2d/lib/src/parametric/
exit 1   (no match)
$ grep -n "Tolerance.standard" apps/floor_planner/lib/parametric/wall*.dart
exit 1   (no match: joins use wallJoin)
$ git diff f2daba5 -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l
0
$ git diff f2daba5 --stat -- packages/jet_cad_2d_flutter/lib
 .../jet_cad_2d_flutter/lib/src/grip_cache.dart     |  67 +++++++++--
 packages/jet_cad_2d_flutter/lib/src/grip_drag.dart | 126 +++++++++++++++++++--
 .../jet_cad_2d_flutter/lib/src/select_tool.dart    |  33 +++++-
 3 files changed, 203 insertions(+), 23 deletions(-)
```

The loose grep (`grep -rn "package:flutter\|dart:ui"`) matches three
pre-existing doc comments (`text_metrics.dart:16`, `tables.dart:38`,
`dasher.dart:47`) and no import. The barrel needed no change: it already
exports `grip_cache.dart` and `grip_drag.dart`. The ledger also records:
the invariant tests passing (query +5, paint +3), the engine `lib` diff
limited to `parametric/` plus `drafting.dart` (`draftRecord`'s colour), and
no `analysis_options.yaml` commit. At `330797c`, `git rev-list --count
f2daba5..330797c` is 26, and 26 commit bodies carry `Co-Authored-By:
Claude Opus 5.5`, re-measured by this task.

---

## Exit gate

The spec's thirteen criteria and where each is witnessed:

| # | criterion | witness | state |
|---|---|---|---|
| 1 | the four gate lines on the human's macOS machine; both release builds | Linux: the four lines above, with only the standing failures (2 engine hash tests; 5 `text_ladder` + 2 Linux-only `text_lod_ladder` goldens), and `flutter build web --release` `✓ Built`. **`flutter build macos --release` and the macOS run of the four lines: the human's machine** | **OWED** |
| 2 | a single wall's documented outline per justification | `WG1` (coordinates, rotated wall), `WR1` | PASS |
| 3 | L mitres asymmetrically at a non-right angle; T butts; X crosses; three-way closes, by coordinates | `WG2`, `WR2` (67° L, oracle corners); `WG4`, `WG19`, `WR5` (T); `WG5`, `WR5` (X); `WG6`, `WG21` (three-way) | PASS |
| 4 | move or delete regenerates neighbours in one undo step; undo/redo exact | `WR3`, `WR4`, `WR7`, `RF2`, `EG3`, `WS2`, `WS4` | PASS |
| 5 | load → save byte-identical; `drift()` empty after load | `WR6` (with the one-ulp control, M-07e), `RG4` | PASS |
| 6 | every stored outline triangulates | `WG13` (10,000 random nodes), `WG7`, `WG12`, `WG14` | PASS |
| 7 | `diagnostics()` names D6's accepted cases, and only those | `WR9`, `WG14` (one reporter per hole, naming every member), `DG1`–`DG5` | PASS |
| 8 | the neighbour search is O(k·n), measured and pinned | `NC1`–`NC3` (counter), `NC4` (times above) | PASS |
| 9 | the allocation invariants pass unchanged | the invariant tests' diff against `f2daba5` is empty; both pass in the gates | PASS |
| 10 | draw order ascending; a wall's children keep their handles | `RG1`, `RG2`, `WR1`, `WR3`, `WR4` | PASS |
| 11 | the pinned panel target holds (M-07p) | `WS7 (Wall)`, `WS7 (Box)` | PASS |
| 12 | every named mutant killed, logged | the mutation log: 51 fired, 51 killed | PASS |
| 13 | the human's look: Wall tool, joints, end grips, Wall section; macOS, Chrome, Firefox | see below | **OWED** |

**11 of 13 PASS; criteria 1 and 13 are OWED.** Criterion 1's Linux half is
green. Its macOS half, and the macOS release build, are the human's.
Criterion 13 has one partial observation: **the human pulled `dcbc831` on
macOS; the app runs and the Wall panel shows up** (ledger). That is not the
look. Nothing was simulated to fill in either criterion.

### Review Focus items and their tests

1. A closed rectangular room with W: `WT4`.
2. Delete one wall of an L; cmd+Z restores the mitre: `WR7`, and `RF2`
   through the shell.
3. Drag the shared corner of an L with the end grip: `EG3`.
4. A justification change on a joined wall: `WS4`.
5. An X, then a T onto it: `WR5`.

---

## Criterion 13: the human's look — OWED

**Not looked at, apart from the partial macOS observation above.** Run it
on each platform:

- **macOS:** `cd apps/floor_planner && flutter run -d macos --release`;
- **Chrome:** `cd apps/floor_planner && flutter run -d chrome --release`;
- **Firefox:** `build/web`, served statically
  (`cd apps/floor_planner/build/web && python3 -m http.server`).

The same six items on each platform. Record each as **seen / not seen /
could not judge**. Use cmd on macOS and ctrl in a browser.

1. **The Wall tool:** W, then clicks draw a chained run, one wall per
   click, as black bands. Clicking the start closes a room. Enter or Esc
   ends a chain, and cmd/ctrl+Z then removes the last wall. ☐ seen ☐ not
   seen ☐ could not judge
2. **Joints:** an L at a non-right angle with different thicknesses mitres
   cleanly; a T butts the near face; an X crosses; a three-way node
   closes with no gap. ☐ seen ☐ not seen ☐ could not judge
3. **Delete and undo:** delete one wall of an L; the survivor's end
   squares; cmd/ctrl+Z restores the mitre. ☐ seen ☐ not seen ☐ could not
   judge
4. **End grips:** a selected wall shows two end grips. Dragging an L's
   shared corner moves both walls and keeps the mitre; one undo restores.
   ☐ seen ☐ not seen ☐ could not judge
5. **The Wall section:** select one wall; Thickness and Justification
   appear; a change moves the joined corners and is one undo step. With W
   active, the section edits the tool's settings and the next wall uses
   them. Typing W in the field does not switch tools, and Esc works after
   Enter. ☐ seen ☐ not seen ☐ could not judge
6. **The pinned target:** select wall A, type a thickness, then click wall
   B. A takes the value and B does not. ☐ seen ☐ not seen ☐ could not
   judge

**Known behaviour to expect** (not 07 defects, recorded so the look does
not rediscover them): with object snap on, the sample plan's dense hatch
can pull a click off the grid (turn F3 off to draw on the grid); a line
drawn with L or a box drawn with B renders white (deferred `fix/` item);
the snap marker can sit at the raw point while the band and the commit go
to the centreline (debt below).

**Nothing above is ticked on the human's behalf.**

---

## Debt

One line each, from the ledger. None is fixed by this task.

- **Task 2 (06 debt):** no test pins "overlap by more than
  `Tolerance.standard.linear`" (touching boxes are not neighbours); mutant T
  survives.
- **Task 6 m5:** the snap marker is drawn at the unmapped point while the
  rubber band and the commit go to the joined point on the centreline.
  Cosmetic.
- **Task 6 m6:** a click near an X crossing tees onto the lower handle,
  with the stem's end about 50 mm inside the other wall's band. `drift()`
  and `diagnostics()` stay empty. Recorded in spec D11's amendment.
- **Task 7:** a grip drag makes no T (no band joining on a grip drop).
  Spec D11's amendment.
- **Task 6b:** the planner never rewrites a record's colour, so a future
  `kWallColor` change needs a migration. Spec D3's amendment.
- **The hole:** 0.76% of plausible nodes on this branch (0.78% in the
  spike) leave a visible hole, accepted and reported by `wall.hole`. Spike
  options 2 and 3 are the path if real plans hit it.
- **For 08:** a neighbour's overlapping fill can cover an opening cut near
  a joint (spec D6, open questions).
- **For 10:** rooms should derive from faces and centrelines, not from
  these polygons (spec open questions).
- **Task 8 m3:** after both Box fields, tapping the panel background
  refocuses Width (focus history); the reviewer's `_handBack` fix is
  recorded.
- **Task 8 m1 (documented):** a live pinned target loses its typed text if
  its section hides while it has focus. The UI cannot reach it.
- **Task 6 m3 (no action):** the band cache's document-switch
  re-subscribe is untested. The UI cannot reach it (`late final`
  document).

**Found and deferred to a post-07 `fix/` branch (the human's decision):**

- **ByLayer drafting on layer 0 renders white:** Plan 05's tools (L and the
  rest) and 06's boxes. It is barely visible off the page and invisible on
  white paper. The cause is the same as walls' (spec D3's amendment).
- **The Page panel's field keeps focus after Enter,** so the shell's letter
  shortcuts are dead until the canvas is clicked. The Selection panel's
  fields were fixed in 07 (`dcbc831`).
- **Box m3:** after both Box fields, tapping the panel background
  refocuses Width (Task 8 m3 above).

---

## Rulings

### The plan's rulings, 07-1…07-8

- **07-1 (spec amended, D11):** undo mid-chain is swallowed; Esc, Enter
  or a click on the chain's last point ends the chain. Cost if wrong: one
  extra Esc.
- **07-2:** wall geometry is pure-Dart app code. Cost: none.
- **07-3 (spec amended, D4; plan amended):** the anchor rule. Its bound is
  corrected to "the anchor within `wallJoin.linear` of every member". Cost
  if wrong: a pathological cluster computes inconsistent caps, and
  `drift()` stays empty.
- **07-4:** two ends in one direction keep free caps. Cost: none.
- **07-5:** D10 is measured by `NC4` and pinned by the counter. Cost: none.
- **07-6:** the container cannot build macOS; the macOS build and the look
  are the human's. Cost: criterion 1's macOS half is owed.
- **07-7 (extended in the ledger):** the Linux-only failures are the
  engine's two hash tests and, in the render layer, `text_lod_ladder` rungs
  1–2 as well as the five `text_ladder` rungs. Cost if wrong: a real
  `text_lod` regression would hide here; the human's macOS gate still
  checks it.
- **07-8:** `RegionRect` duplicates nothing of the wall. Cost: none.

### The controller's rulings in flight, from the ledger

- **T1:** a direct fill edit throws the command's own `StateError` (spec D8
  amended). Cost: a caller that catches only `GeneratedGeometryError` sees
  a `StateError`.
- **T1:** a boundary edit's `GeneratedGeometryError` names the fill (spec
  D8 amended). Cost: cosmetic.
- **T1:** `RG7`'s added-region case runs on an existing object. Cost: none.
- **T1:** `RG2` checks re-triangulation by equality and by area. Cost: none.
- **T3:** all four review minors were taken at once, including the nested
  `_applying` guard bug inherited from 06. Cost: none.
- **T3:** the `apply()` save/restore is defensive and unpinned; its mutant
  is equivalent. Cost: none reachable.
- **T4:** wedge corners are computed through the node's reference point
  (spec D5.2 amended). Cost: corners shift by at most `wallJoin.linear`.
- **T4:** deviations 2–4 and 6 were accepted as reported. Cost: none.
- **T4:** a wall owning holes at both ends reports the union of members.
  Cost: one diagnostic for two nodes.
- **T4:** Ruling 07-3's bound corrected (spec D4 and plan amended). Cost:
  none.
- **T5:** D12 is one diagnostic per code per wall (spec D12 amended). Cost:
  one entry for two rare nodes.
- **T5:** M-07l is defined at the view level (mutant table amended). Cost:
  none.
- **T6:** a per-tool snap mask with `nearest` (`e882160`). Superseded by
  the smoke ruling below and removed in `f751d4a`. Cost if wrong: one
  engine parameter and one render getter.
- **T6:** the chain keeps its first and last points; self-snap to the last
  point only once a wall is down (plan amended). Cost: none.
- **T6 (I1):** band joining: a point in a wall's band goes to the nearer
  endpoint within one thickness, else onto the centreline; lowest handle
  (spec D11 amended). Cost: a click meant to start a free wall inside a
  band joins it.
- **T6:** band joining is gated on object snap (F3). Cost: with F3 off, a
  free wall can be drawn inside a band.
- **T6 (I2):** a hover with no chain returns early; the world walls are
  cached and rebuilt on a document change; the scan allocates nothing.
  Cost: a large plan's hover is a linear scan; an index cull is the
  follow-up.
- **T6:** m4 taken; m5 deferred (cosmetic); m6 recorded for the spec.
- **Smoke (6b):** walls get an explicit colour, not an ACI-7 contrast rule
  (none exists). Cost: a future colour change needs a migration.
- **Smoke (6c):** the Wall tool drops `nearest`; band joining alone makes
  T's and nodes (spec D11 amended). Cost: a click just outside a band's
  edge no longer snaps onto the face.
- **Human:** the white ByLayer drafting defect goes to a separate `fix/`
  branch after 07.
- **T7:** a grip drag does not band-join (spec D11 amended). Cost: a T is
  made with the Wall tool, not by dragging a grip.
- **T7:** `WallGrips`' preview caches the joined-end set per grip;
  degenerate walls at a corner are not moved; with components denied, an
  object grip is drawn but a press stays a click. Cost: cosmetic.
- **T8 (I1):** in tool mode, every valid keystroke writes the settings
  (spec D11 amended). Cost: a partial number is the setting while typing.
- **T8 (problem 1):** the Selection panel's fields return focus on Enter
  and on a tap outside now; the Page panel's field goes to the `fix/`
  branch. Cost: none.
- **T8 deviations accepted:** `WS7` split into Wall and Box; the tool's
  settings take precedence over a selected wall while the tool is active;
  `Handle.none` as the settings target; a field re-pins after a commit.
- **T9:** `WG21` landed; M-07i re-fired against it. Cost: one test.
- **T10:** no code change; the two broken greps are corrected in this
  note and the plan. Cost: none.

---

## Spec amendments

In [2026-09-24-walls-design.md](../specs/2026-09-24-walls-design.md), each a
paragraph beginning "**Amended at execution (Plan 07)**", placed at the end
of the section it amends. Nothing original is rewritten.

- **Header:** a pointer to the amendments and to this note.
- **Evidence and D1:** `boxCatalog` and `installBoxes` are gone, replaced
  by `catalog.dart`'s `parametricCatalog` and `installParametric`.
- **D3:** walls carry an explicit `kWallColor` black through `Generated`'s
  `color`. ByLayer on layer 0 renders white, because no ACI-7 contrast rule
  exists. The planner never rewrites a record's colour.
- **D4:** the membership anchor rule's true bound; the counterexample.
- **D5.2:** wedge corners intersect faces placed through the node's
  reference point (0.76% against 1.19% holes).
- **D5.3:** "never an outline vertex" means never **inserted**.
- **D6:** the spike's "485 refusals before, 0 after" was removed by the
  lobe split, not by simplification; `simplifyRing` is a guard.
- **D8:** a fill edit's own `StateError`; a boundary edit's error names the
  fill; `Generated` gains `color`, used only when a child is added.
- **D10:** `NC2` also asserts the exact count; `< 10 × n` holds only for a
  small closure.
- **D11:** Ruling 07-1; band joining (endpoint within one thickness else a
  T, lowest handle, gated on object snap, an allocation-free cache); no
  `nearest`; the X-crossing click; no band joining on a grip drag;
  `ObjectGripProvider.preview`; object stretch grips need `components` and
  `geometry`; tool-mode keystrokes; tool mode takes precedence; Enter and a
  tap outside return focus; re-pin after a commit.
- **D12:** one diagnostic per code per wall; the union at both ends.
- **The mutant table:** M-07i's named test is `WG2`/`WG21`; M-07l is
  defined at the view level; M-07n is fired in `simplifyRing`, and its call
  site is equivalent.

The plan carries three "Amended at execution" notes: Ruling 07-3's bound,
Task 6's chain points and band joining, and Task 10's corrected greps.

---

## Files this task touched

- `docs/superpowers/notes/2026-09-24-plan-07-results.md`: this file.
- `docs/superpowers/specs/2026-09-24-walls-design.md`: the amendments
  above, appended.
- `docs/superpowers/plans/2026-09-24-walls.md`: three "Amended at
  execution" notes.
- `docs/superpowers/notes/plan-07-mutation-log.md`: `WG21`'s wording ("the
  node point is on no ring"), a title note under the M-07i re-fire (the
  pasted transcripts keep the old title as it ran), and the re-fire's tree
  (Task 9 review minors m1 and m2).
- `apps/floor_planner/test/wall_geometry_test.dart`: `WG21`'s title only,
  now "a three-way node under mixed justification: the node point is on no
  ring (M-07i at a node cap)". w2 is left-justified, so its zero face does
  run through the node, and the old title said otherwise. No behaviour
  change; the app gate above ran after it, and `CI=true flutter test
  test/wall_geometry_test.dart --plain-name 'WG21 a three-way node under
  mixed justification'` printed `00:00 +1: All tests passed!`, exit 0.
- `STATUS.md`: a Plan 07 section at the top, and the "Resume here"
  paragraph.
- `roadmap/07-walls.md`: the status line.
- `roadmap/00-README.md`: the 07 row of the status table.

**Branch files, `f2daba5..330797c`** (`git diff --stat`, 43 files, +8845
−209): the engine's `parametric_system.dart`, `regeneration.dart` and
`drafting.dart`; the render layer's `grip_cache.dart`, `grip_drag.dart` and
`select_tool.dart`; the app's `wall.dart`, `wall_geometry.dart`,
`wall_tool.dart`, `wall_grips.dart`, `catalog.dart`, `box.dart`,
`selection_panel.dart`, `main.dart` and `shortcut_guard.dart`; their tests;
the spike note and its images; the mutation log; the plan.
