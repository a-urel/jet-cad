# Task 8 report: mutation testing, twelve pre-committed mutations

Branch `plan-d/fills`. Deliverable:
`docs/superpowers/notes/plan-d-mutation-log.md` (new, committed) — full diffs,
commands and verbatim output for all twelve rows. This report summarises the
same run; the log is the record of authority for exact text.

## Method followed

For every mutation: `cp` the target file to `/tmp` (either the per-mutation
`/tmp/plan-d-backup.dart` / `/tmp/plan-d-backup-expander.dart` /
`/tmp/plan-d-backup-record.dart` the brief's own snippet uses, or the
once-per-file originals kept in `/tmp/plan-d-mutation-backups/`), apply
exactly one mutation, run the suite or the table's named test file, capture
the actual failure text, then restore with `cp` from the backup and confirm
`git status --short` is clean before moving to the next row. `git checkout --`
was never used on any mutated file — only ever mentioned in this report and
the brief as the thing not to do. Every restore's checksum
(`md5 <file>`) was checked against the pre-mutation checksum and matched
every time.

`lib/src/vertices_draw_sink.dart` and `packages/jet_cad_2d` were never
touched, mutated or otherwise.

## Kill tally

**12 of 12 mutations fired. 11 were killed on the first shot. 1 (M-D4)
survived its first shot, exposed a genuine gap in an existing assertion, and
was killed after that gap was closed with two new `expect` lines.**

| id | mutation | verdict |
|---|---|---|
| M-D1 | `fillPolygon` → `_coveredArgb` | KILLED — `geometry_collector_test.dart` |
| M-D2 | `fillCircle` → `_coveredArgb` | KILLED — `geometry_collector_test.dart` (reproduces the earlier round's `0.0745` alpha exactly) |
| M-D3 | fill branch reads `half_width` | KILLED — `instance_expander_test.dart` |
| M-D4 | fold `M` onto `p2` instead of `p1` | **SURVIVED, then KILLED** (see below) |
| M-D5 | point branch stays `else`, fill inserted before it | KILLED — `instance_expander_test.dart` (4 tests) |
| M-D6 | `fillCircle` fans at `steps + 1` | KILLED — `geometry_collector_test.dart` |
| M-D7 | `fillPolygon` walks triangulation backwards | KILLED — `geometry_collector_test.dart` |
| M-D8 | `fillPolygon` drops zero-area triangles | KILLED — `geometry_collector_test.dart` |
| M-D9 | `data` sorts by kind | KILLED — `fill_order_test.dart` (all 3 assertions, reproduces the earlier round exactly) |
| M-D10 | `writeFill` leaves `dashPeriod` unwritten | KILLED — `instance_record_test.dart` |
| M-D11 | `writeFill` writes `halfWidth: 1` | KILLED — `instance_record_test.dart` |
| M-D12 | fan starts at `2π/steps` | KILLED — `geometry_collector_test.dart` |

## The one survivor, in full: M-D4

**Mutation:** in `test/support/instance_expander.dart`'s fill branch (mutated
here rather than in the untestable GLSL, per the brief), fold the miter-tip
role `M` onto `p2` instead of `p1`:

```diff
-        px = c.wv * a0x + (c.wa + c.wm) * a1x + c.wb * a2x;
-        py = c.wv * a0y + (c.wa + c.wm) * a1y + c.wb * a2y;
+        px = c.wv * a0x + c.wa * a1x + (c.wb + c.wm) * a2x;
+        py = c.wv * a0y + c.wa * a1y + (c.wb + c.wm) * a2y;
```

**Why it survived.** `ResidentGeometry.kCornerVertices`'s fold triangle has
exactly one vertex wired to `wm`; that vertex's position becomes whichever
of `p1`/`p2` the mutation adds `wm`'s weight onto. Folding onto *either*
point makes triangle 1's three vertices `(p1, p1, p2)` (correct) or
`(p1, p2, p2)` (mutant) — both have two literally coincident vertices, and a
triangle with two coincident vertices has **exactly zero signed area under
both assignments**, by the same algebraic identity either way (substituting
`v4=v3` or `v4=v5` into the shoelace formula both give `0`). The pre-existing
test, `'a fill expands to its three corners and one degenerate triangle'`,
asserted only that area — so it could never have told the two fold targets
apart, no matter how it was run. This is a real coverage gap in the
assertion, not equivalence between the mutant and the correct program: the
raw vertex value genuinely differs (`a1x` vs `a2x`), the test simply never
read it.

**The fix — the one test this task adds.** Two more `expect` lines, appended
to that same test in `test/gpu/instance_expander_test.dart`, pinning the
M-weighted vertex's raw position (`positions[8]`, `positions[9]`) to `p1`'s
known value directly:

```dart
expect(e.positions[8], closeTo(40, 1e-6),
    reason: 'M must fold onto p1 (A), not p2 (B)');
expect(e.positions[9], closeTo(12, 1e-6));
```

Verified against the correct code first: `flutter test
test/gpu/instance_expander_test.dart` — all 19 tests passed, so the new
assertion is not itself broken. M-D4 was then re-applied and killed the new
assertion specifically:

```
Expected: a numeric value within <0.000001> of <40>
  Actual: <25.0>
   Which:  differs by <15.0>
M must fold onto p1 (A), not p2 (B)
```

`instance_expander.dart` was restored from backup afterward (checksum
verified against the pre-mutation original); the two new `expect` lines in
`test/gpu/instance_expander_test.dart` are the only source change this task
keeps.

## The three gate commands, on the fully restored tree

```
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

```
00:02 +798: All tests passed!
Analyzing jet_cad_2d...
No issues found!
Formatted 113 files (0 changed) in 0.16 seconds.
```

```
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

```
00:06 +565 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
Formatted 92 files (0 changed) in 0.14 seconds.
```

565 tests, 1 pre-existing skip — the same count as the pre-mutation baseline
run at the start of this task, since M-D4's fix extended an existing test
with two more assertions rather than adding a new `test(...)` block.

## `git status` before commit

```
 M packages/jet_cad_2d_flutter/test/gpu/instance_expander_test.dart
?? docs/superpowers/notes/plan-d-mutation-log.md
```

No `analysis_options.yaml` appeared in status at any point in this task.
