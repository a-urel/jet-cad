# Final whole-branch review — fix wave

Applied against `plan-d/fills`, ahead of the merge of thirteen offered
commits. Two commits: one for the code/test fixes (I2 + three Minor items
touching `packages/jet_cad_2d_flutter`), one for the documentation fixes
(I1 + three Minor items touching `STATUS.md` and `docs/superpowers/notes/`).

`packages/jet_cad_2d` and `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
were not touched. No `analysis_options.yaml` appeared in `git status --short`
at any point.

Commits:
- `3b5e55b` — `fix(gpu): extend the shader/Dart-transcription guard to the fill threshold`
- `eabca9e` — `docs: correct STATUS.md's main position and round out Plan D's notes`

---

## I1 — STATUS.md's false claim about `main`

**Verified against git, not assumed:**

```
$ git log --oneline -1 main
bde9196 docs: Plan D, fills and the order gate they make testable

$ git rev-list --count 3a61b45..bde9196
4

$ git log --oneline 3a61b45..bde9196
bde9196 docs: Plan D, fills and the order gate they make testable
e347238 Merge: load carries globalLinetypeScale, and every other header field
5069a6e fix(codec): load carries globalLinetypeScale, and every other header field
ddf938c docs: STATUS.md points at Plan C's merge, not at the in-flight branch

$ git diff --stat 3a61b45 5069a6e -- packages/jet_cad_2d/
 packages/jet_cad_2d/lib/src/codec/json_codec.dart |  1 +
 packages/jet_cad_2d/test/codec/json_codec_test.dart | 28 ++++++++++++++++++++++
 2 files changed, 29 insertions(+)
```

`5069a6e` adds exactly one new test to `jet_cad_2d`
(`json_codec_test.dart`'s `'every header field survives save and load'`);
its `dash_differential_test.dart` counterpart in `jet_cad_2d_flutter` is a
modification of an existing test, not a new one, confirmed by reading its
diff — no `+test(` line.

```
$ git diff --stat bde9196..plan-d/fills -- packages/jet_cad_2d/
(empty)

$ cd packages/jet_cad_2d && dart test | tail -3
00:02 +798: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +798: All tests passed!
```

Plan D's own commit range touches nothing under `packages/jet_cad_2d`, and
that package's test count on `plan-d/fills` (798) is produced by running the
suite that `main` already carries at `bde9196` — Plan C's 797 plus the one
codec-fix test.

**Change:** rewrote STATUS.md's opening block (the `**Verified against**`
paragraph and the suite-count paragraph) to:
- state `main` is at `bde9196`, not `3a61b45`, and is not unchanged since
  Plan C's merge;
- name the two commits (`5069a6e`, `e347238`) and the one test they add;
- say explicitly that `plan-d/fills`'s `jet_cad_2d` count of 798 is
  inherited from `main`, with the exact `git diff --stat` command a reader
  can run to confirm Plan D never touches that package;
- correct "main's own counts" from `797 / 540 / 72` to `798 / 540 / 72`.

## I2 — the shader/Dart-transcription guard did not cover the fill threshold

**File:** `packages/jet_cad_2d_flutter/test/gpu/instance_expander_test.dart`

Added a fourth `expect` to the existing `RegExp` test for `kind < 2.5`
(the point/fill dispatch threshold `shaders/cad_stroke.vert` line 160) and
retitled the test from "three renumber-prone constants" to "four", updating
its doc comment (`kKindFill` alongside `kKindStroke`/`kKindJoin`/`kKindPoint`,
confirmed present in `instance_record.dart` at lines 50/55/68/81).

**Mutation proof**, exactly as specified — backup to the session scratchpad,
never `git checkout --`:

```
$ cp packages/jet_cad_2d_flutter/shaders/cad_stroke.vert <scratchpad>/cad_stroke.vert.backup
$ sed -i '' 's/} else if (kind < 2\.5) {/} else if (kind < 2.75) {/' \
    packages/jet_cad_2d_flutter/shaders/cad_stroke.vert
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
...
00:00 +18: cad_stroke.vert still carries the four renumber-prone constants
00:00 +18 -1: cad_stroke.vert still carries the four renumber-prone constants [E]
  Expected: true
    Actual: <false>
  the point/fill dispatch threshold -- without it a reverted `else` draws every fill as a point, or the reverse, and every pixel and expander test in this package runs through the Dart transcription, so a GLSL-only regression here turns nothing red

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/instance_expander_test.dart 445:5          main.<fn>

00:00 +18 -1: Some tests failed.
EXIT CODE: 1
```

Restored and verified clean:

```
$ cp <scratchpad>/cad_stroke.vert.backup packages/jet_cad_2d_flutter/shaders/cad_stroke.vert
$ git status --short
 M STATUS.md
 M packages/jet_cad_2d_flutter/test/gpu/instance_expander_test.dart
```

(`cad_stroke.vert` itself shows no diff — the restore was exact.) Re-run
confirmed green:

```
00:00 +18: cad_stroke.vert still carries the four renumber-prone constants
00:00 +19: All tests passed!
EXIT CODE: 0
```

The shader bundle (`assets/shaders/cad.shaderbundle`) was not touched or
regenerated.

## 3 — resident_geometry.dart's stale vertex-layout doc

**File:** `packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart`,
around line 133.

Changed "**Carries three kinds, not one**, since Plan B ... strokes, joins
and points (`kKindStroke`/`kKindJoin`/`kKindPoint`)" to "**Carries four
kinds, not one**, since Plan D ... strokes, joins, points and fills
(`kKindStroke`/`kKindJoin`/`kKindPoint`/`kKindFill`)", matching the
corner-table doc 60 lines above.

## 4 — resident_pixel_differential_test.dart's backwards channel comment

**File:** `packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart`,
around line 279.

`0xFF102030` under this codebase's `0xAARRGGBB` convention is R=0x10,
G=0x20, B=0x30. The comment read "R=0x30 G=0x20 B=0x10" (backwards) and its
arithmetic list was in the matching B,G,R order. Corrected the label to
"0xAARRGGBB, so R=0x10 G=0x20 B=0x30" and reordered the arithmetic to
`0x10+0x20=0x30, 0x20+0x20=0x40, 0x30+0x20=0x50` (R, G, B). No test
behaviour changed — the tint is symmetric, as the original comment noted.

## 5 — debugTintResident's constraint lived only in a caller's comment

**File:** `packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart`,
the `debugTintResident` parameter's doc comment above `measureResidentColor`.

Added a new paragraph stating the constraint generally: a tint is only a
clean per-channel offset while no channel carries across a byte boundary,
since the tint is added to the packed `0xAARRGGBB` value as a whole, not
lane by lane — a caller must choose the value against the actual corpus
colour under test. The specific arithmetic verification for this branch's
one caller (`resident_pixel_differential_test.dart`) was left in place as a
local check, now backed by the general rule on the parameter's own doc.

## 6 — plan-d-mutation-log.md's M-D5 section omitted the transcription note

**File:** `docs/superpowers/notes/plan-d-mutation-log.md`, M-D5's **File:**
line.

M-D3 and M-D4 both state the mutation targets `test/support/instance_expander.dart`
as a stand-in for the shader because the suite has no GPU; M-D5 only named
the file. Added the same clause: "(Dart transcription, same reason as M-D3
and M-D4 — `flutter test` has no GPU, so this stands in for
`shaders/cad_stroke.vert` itself)."

## 7 — the 8 MB budget row's missing fill fraction

**File:** `docs/superpowers/notes/2026-09-01-plan-d-results.md`, the
"Against the budget, and against Plan C" section.

160 fill instances / 114,717 total = 0.14%. Added a paragraph after the
existing PASS discussion stating the fraction, citing Ruling D7 (a fill
record wastes ten of its sixteen floats, 40 of 64 bytes) and its ~6.25 KB
cost at this corpus's fill count, and stating explicitly that this PASS
measures "fills at this corpus's fill fraction fit," not "fills fit" in
general — a higher fill-fraction corpus would pay the same per-instance
waste at a larger share of the budget.

## 8 — the criterion table's missing CPU-only qualifier

**File:** `docs/superpowers/notes/2026-09-01-plan-d-results.md`, immediately
above the "Exit gate — 8 of 9" criterion table.

Added one sentence: criteria 1–4 are measured through the Dart transcription
(`test/support/instance_expander.dart`) plus `TriangleRasterizer`, not on a
GPU — the same qualifier Criterion 6's buffer measurement already carries,
restated once where a reader of the table alone will see it.

---

## Three-package gate — verbatim

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:06 +565 ~1: All tests passed!
EXIT: 0

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
EXIT: 0

$ dart format --output=none --set-exit-if-changed .
Formatted 92 files (0 changed) in 0.14 seconds.
EXIT: 0

$ cd ../jet_cad_2d && dart test
...
00:02 +798: All tests passed!
EXIT: 0

$ dart analyze
Analyzing jet_cad_2d...
No issues found!
EXIT: 0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
EXIT: 0

$ cd ../../apps/dev_harness_2d && flutter test --concurrency=1
...
00:13 +73: All tests passed!
EXIT: 0

$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
EXIT: 0

$ dart format --output=none --set-exit-if-changed .
Formatted 18 files (0 changed) in 0.08 seconds.
EXIT: 0
```

`git status --short` before each commit showed no `analysis_options.yaml`.
