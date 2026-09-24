# Plan 07 mutation log -- M-07a..s and the tasks' extras

**Tally: 51 fired, 51 killed, 0 survived; 4 equivalent (recorded, not
fired); 1 N/A.**

- **The spec's named mutants, M-07a..M-07s:** 19, plus 6 variants at a
  second site or in a second form (M-07e', M-07h's two halves, M-07i's
  node-cap site, M-07k's "no owner" and "highest owner"). All 25 killed.
- **One finding, now fixed:** the spec's fixture for M-07i's node-cap
  site is "a three-way node under mixed justification". That is `WG6`,
  and `WG6` passes under this mutant; in the file, only `WG8` killed it.
  `WG6` is a degenerate fixture for this mutant. In it, two walls have a
  face through the node point, so the insertion mostly repeats an
  existing vertex. Where it does add one, it falls outside what `WG6`
  samples.

  The controller ruled the fixture in. It landed as `WG21`: a three-way
  node under mixed justification where the node point is on no ring. The
  site was re-fired against `WG21`, which kills it. See the M-07i entry.
- **The tasks' extras:** 26 fired, all killed:
  - geometry: 8;
  - band joining: 6;
  - grips: 5;
  - panel: 3;
  - planner and engine cost: 3;
  - colour: 1.
- **Equivalent, not fired:** 4. See the Equivalent mutants section.
- **N/A:** 1. No snap-mask mutant exists, because Task 6c removed the
  `nearest` snap.

**Tree.** Every mutant was fired against `plan-07/walls` at `dcbc831`. The
one exception is M-07i's re-fire against `WG21`, which ran on `dcbc831`
with `WG21` added to the test file, the tree committed as `330797c`;
`lib/` is identical between the two (Task 9 review, minor m2).
`git status --short` was empty between batches.

**Procedure, per mutant.** The driver is
`t9-fire.py` in the session scratchpad
(`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/`).
For each mutant it does the following, in order:

1. `cp` the target file to `t9-<id>-<basename>` in the scratchpad.
2. Apply the edit. Each `old` string must occur exactly once, or nothing
   is written.
3. Print `diff <backup> <file>`. That diff is the edit, pasted below.
4. Run the narrowed command with `CI=true`: `flutter test` for
   `apps/floor_planner` and `packages/jet_cad_2d_flutter`, `dart test` for
   `packages/jet_cad_2d`. The command names one test file and one test by
   `--plain-name`. The exceptions are two re-fires of M-07i's node-cap
   site, which run whole files or the probe; see that entry.
5. Save the whole output to `t9-<id>-run<n>.log`.
6. `cp` the backup back, then `diff` the backup against the file.

Every `diff` after a restore exited 0.

The red lines below are pasted from those logs, verbatim:

- the failing test's `[E]` line;
- the matcher's `Expected` / `Actual` / `Which` lines, with the
  continuation line where a value wraps;
- the failing assertion's location;
- the run's last summary line.

A multi-line `Expected:` list is cut after its first line; the full text
is in the log.

**Baselines.** Each of the 35 distinct narrowed commands was first run on
the clean tree. Every one matched exactly one test, or `OG4`'s group of
three, and passed. So each red below is the mutant's doing, and no
`--plain-name` matched nothing. From `t9-baseline.txt`, for example:

```
(cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG6 a three-way node') exit 0 | ['00:00 +1: All tests passed!']
(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'OG4 a document change mid-drag') exit 0 | ['00:00 +3: All tests passed!']
```

**Rulings that change where or how a mutant is fired** (the ledger):

- **M-07l** is defined at the view level: a wall squares its end where a
  neighbour's own outline falls back. `outline()` alone cannot express it
  (Task 5 ruling).
- **M-07n** is fired in `simplifyRing` and killed by `WG12`'s spliced ring.
  Its call site in `outline` is equivalent for triangulation (Task 4).
- **M-07e** is killed by `WR6`'s one-ulp control.
- **M-07g** is fired in the engine's `_closure`.
- **The snap mask:** Task 6c removed the Wall tool's `nearest` snap and its
  mask plumbing. There is no snap-mask mutant to fire.

---

## The named mutants

### M-07a — the corner along the average of the two directions, at the symmetric distance

`wedge`'s corner is replaced by `hub + bisector · (t/2 / sin(sweep/2))`,
taking the first wall's half-thickness.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07a-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382a383
  >   final c2 = c == null ? null : hub + (x.a + y.a).normalized() * (x.wall.t / 2 / math.sin(s / 2));
  384c385
  <   if (c != null && (s < math.pi / 2 || (c - hub).length <= limit)) return [c];
  ---
  >   if (c2 != null && (s < math.pi / 2 || (c2 - hub).length <= limit)) return [c2];
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG2 the 67'` (exit 1)

  ```
  00:00 +0 -1: WG2 the 67° L, 200 centre against 115 left: two corners shared bitwise, each equal to the oracle (M-07a, M-07b, M-07f, M-07i) [E]
    Expected: false
      Actual: <true>
    test/wall_geometry_test.dart 79:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07a-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG2`. The first failure is `expectSound`'s
  `o.fellBack` is false, at line 37, called from line 79. A's ring with the
  bisector corner is not simple, so A falls back to square ends.

### M-07b — one wall's half-thickness for both sides

The second face of the wedge is offset by the first end's half-width
instead of its own.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07b-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382c382
  <   final c = intersect(x.leftPoint(hub), x.a, y.rightPoint(hub), y.a);
  ---
  >   final c = intersect(x.leftPoint(hub), x.a, hub + y.nOut * ((x.right - x.left) / 2), y.a);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG2 the 67'` (exit 1)

  ```
  00:00 +0 -1: WG2 the 67° L, 200 centre against 115 left: two corners shared bitwise, each equal to the oracle (M-07a, M-07b, M-07f, M-07i) [E]
    Expected: a value less than <0.000001>
      Actual: <46.17031604028998>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 90:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07b-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG2`. The shared corner is 46.17 mm from the
  oracle's meet of A's +100 face and B's +115 face.

### M-07c — every joint treated as a node (no T)

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07c-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  199c199
  <   if (through != null) return Tee(through);
  ---
  >   // M-07c: no T
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG4 the T at 58'` (exit 1)

  ```
  00:00 +0 -1: WG4 the T at 58°: the stem butts the near face of a 200 right-justified wall; the through wall stays four points (M-07c, M-07r) [E]
    Expected: a value less than <0.000001>
      Actual: <30.470357693925628>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 133:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07c-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG4`. Without the T, the stem's cap points lie
  30.47 mm off the through wall's near face.

### M-07d — endpoints compared with `==`

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07d-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  102c102
  < bool _joined(Vector2 a, Vector2 b) => (a - b).length <= wallJoin.linear;
  ---
  > bool _joined(Vector2 a, Vector2 b) => a.x == b.x && a.y == b.y;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG15 a joint one ulp'` (exit 1)

  ```
  00:00 +0 -1: WG15 a joint one ulp apart at the far origin still shares two corners (M-07d) [E]
    Expected: an object with length of <2>
      Actual: []
       Which: has length of <0>
    test/wall_geometry_test.dart 548:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR2 the 67'` (exit 1)

  ```
  00:00 +0 -1: WR2 the 67° L, each wall in its own group: two corners shared in world, each equal to the oracle; also with a joint one ulp apart (M-07h, M-07d) [E]
    Expected: an object with length of <2>
      Actual: []
       Which: has length of <0>
    test/wall_regen_test.dart 217:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07d-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG15` (geometry) and by `WR2`'s one-ulp case
  (through the planner). In both, a joint one ulp apart shares no corners
  where two are expected.

### M-07e — the round trip compared within a tolerance

The spec's mutant is the save comparison: the test's `sameSave` loosened
to 1e-6 on every number.

- **file:** `apps/floor_planner/test/wall_regen_test.dart`; backup `t9-M-07e-wall_regen_test.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  31c31,49
  < bool sameSave(String a, String b) => a == b;
  ---
  > bool sameSave(String a, String b) {
  >   bool near(Object? x, Object? y) {
  >     if (x is num && y is num) return (x - y).abs() <= 1e-6;
  >     if (x is List && y is List) {
  >       if (x.length != y.length) return false;
  >       for (var i = 0; i < x.length; i++) {
  >         if (!near(x[i], y[i])) return false;
  >       }
  >       return true;
  >     }
  >     if (x is Map && y is Map) {
  >       if (x.length != y.length) return false;
  >       return x.keys.every((k) => y.containsKey(k) && near(x[k], y[k]));
  >     }
  >     return x == y;
  >   }
  > 
  >   return near(jsonDecode(a), jsonDecode(b));
  > }
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR6 load'` (exit 1)

  ```
  00:00 +0 -1: WR6 load -> save is byte-identical, drift() is empty after reload, typed components equal; a one-ulp perturbed outline is not (M-07e) [E]
    Expected: false
      Actual: <true>
    test/wall_regen_test.dart 362:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07e-wall_regen_test.dart apps/floor_planner/test/wall_regen_test.dart`; `diff` exit 0.
- **result:** KILLED by `WR6`'s control, at line 362 of the mutated file
  (line 344 unmutated): `expect(sameSave(enc(off), saved), isFalse)`. The
  one-ulp-perturbed save compares equal under the tolerance.

### M-07e' — the planner's payload comparison within a tolerance

This is the same defect on the engine side. `_samePayload` compares
coordinates within `Tolerance.standard.linear` (1e-9), so `drift()` no
longer sees a one-ulp change.

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t9-M-07e-planner-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  116c116
  <     if (a.coords[i] != b.coords[i]) return false;
  ---
  >     if ((a.coords[i] - b.coords[i]).abs() > Tolerance.standard.linear) return false;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR6 load'` (exit 1)

  ```
  00:00 +0 -1: WR6 load -> save is byte-identical, drift() is empty after reload, typed components equal; a one-ulp perturbed outline is not (M-07e) [E]
    Expected: [1300]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/wall_regen_test.dart 346:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07e-planner-regeneration.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0.
- **result:** KILLED by `WR6`: `expect(driftOf(off), [hA])` finds nothing
  drifted.

### M-07f — justification ignored (always centred)

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07f-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  48,49c48,49
  <         Justification.left => (t, 0),
  <         Justification.right => (0, -t),
  ---
  >         Justification.left => (t / 2, -t / 2),
  >         Justification.right => (t / 2, -t / 2),
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG2 the 67'` (exit 1)

  ```
  00:00 +0 -1: WG2 the 67° L, 200 centre against 115 left: two corners shared bitwise, each equal to the oracle (M-07a, M-07b, M-07f, M-07i) [E]
    Expected: a value less than <0.000001>
      Actual: <62.46572170064423>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 90:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG1 a free wall'` (exit 1)

  ```
  00:00 +0 -1: WG1 a free wall is the rectangle between its face offsets, per justification (M-07f) [E]
    Expected: a value less than <0.000001>
      Actual: <99.99999999990277>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 63:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07f-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG2` (B is left-justified: the corner is 62.47 mm
  from the oracle) and by `WG1` (a left-justified free wall's face is
  100 mm from its rectangle).

### M-07g — only the moved wall regenerates (closure = seeds)

This is fired in the engine's `_closure`, as the ledger rules.

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t9-M-07g-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  105,106d104
  <       for (final s in seeds) ...before.neighboursOf(s),
  <       for (final s in seeds) ...after.neighboursOf(s),
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR3 moving B off A'` (exit 1)

  ```
  00:00 +0 -1: WR3 moving B off A is one undo step: A's end squares, by coordinates; undo and redo are exact (M-07g) [E]
    Expected: true
      Actual: <false>
    test/wall_regen_test.dart 243:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07g-regeneration.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0.
- **result:** KILLED by `WR3`, line 243. A is not the free rectangle
  `rectOf(a, 100, -100)` after B moves off: A was never regenerated, so its
  end is still mitred.

### M-07h — the group transform dropped in `generate`

Both halves at once: world walls built with the identity, and the outline
taken back to local space with the identity.

- **file:** `apps/floor_planner/lib/parametric/wall.dart`; backup `t9-M-07h-wall.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  104c104
  <   return p == null ? null : WorldWall(h, p, view.toWorld(h));
  ---
  >   return p == null ? null : WorldWall(h, p, Transform2.identity());
  150c150
  <     final toLocal = view.toWorld(self).invert();
  ---
  >     final toLocal = Transform2.identity();
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR2 the 67'` (exit 1)

  ```
  00:00 +0 -1: WR2 the 67° L, each wall in its own group: two corners shared in world, each equal to the oracle; also with a joint one ulp apart (M-07h, M-07d) [E]
    Expected: an object with length of <2>
      Actual: []
       Which: has length of <0>
    test/wall_regen_test.dart 217:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07h-wall.dart apps/floor_planner/lib/parametric/wall.dart`; `diff` exit 0.

Each half alone:

- **file:** `apps/floor_planner/lib/parametric/wall.dart`; backup `t9-M-07h-world-wall.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  104c104
  <   return p == null ? null : WorldWall(h, p, view.toWorld(h));
  ---
  >   return p == null ? null : WorldWall(h, p, Transform2.identity());
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR2 the 67'` (exit 1)

  ```
  00:00 +0 -1: WR2 the 67° L, each wall in its own group: two corners shared in world, each equal to the oracle; also with a joint one ulp apart (M-07h, M-07d) [E]
    Expected: a value less than <0.000001>
      Actual: <4657117.742178211>
       Which: is not a value less than <0.000001>
    test/wall_regen_test.dart 217:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07h-world-wall.dart apps/floor_planner/lib/parametric/wall.dart`; `diff` exit 0.

- **file:** `apps/floor_planner/lib/parametric/wall.dart`; backup `t9-M-07h-local-wall.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  150c150
  <     final toLocal = view.toWorld(self).invert();
  ---
  >     final toLocal = Transform2.identity();
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR2 the 67'` (exit 1)

  ```
  00:00 +0 -1: WR2 the 67° L, each wall in its own group: two corners shared in world, each equal to the oracle; also with a joint one ulp apart (M-07h, M-07d) [E]
    Expected: an object with length of <2>
      Actual: []
       Which: has length of <0>
    test/wall_regen_test.dart 217:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07h-local-wall.dart apps/floor_planner/lib/parametric/wall.dart`; `diff` exit 0.
- **result:** KILLED by `WR2` in all three forms. Both walls together, or
  `toLocal` alone, leave no shared corner. `WorldWall` alone puts the
  corner 4.66 km from the oracle.

### M-07i — the node point used as a cap vertex

**Site 1, the mitre** (`WG2`, the 67° L):

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07i-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  289c289
  <         return (points: [left, right], ownsHole: false); // the mitre
  ---
  >         return (points: [left, hub, right], ownsHole: false); // the mitre
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG2 the 67'` (exit 1)

  ```
  00:00 +0 -1: WG2 the 67° L, 200 centre against 115 left: two corners shared bitwise, each equal to the oracle (M-07a, M-07b, M-07f, M-07i) [E]
    Expected: an object with length of <4>
      Actual: [
       Which: has length of <5>
    test/wall_geometry_test.dart 81:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07i-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG2`: A's ring has five points, not four (the
  notch).

**Site 2, a node's non-owner cap** (the spec's "three-way node under mixed
justification"). The named test is now **`WG21`**; it was `WG6` when this
sweep began. The same insertion, in the straight cap every non-owner
returns. The first run, against `WG6`:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07i-node-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  326c326
  <       return (points: [left, right], ownsHole: false);
  ---
  >       return (points: [left, hub, right], ownsHole: false);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG6 a three-way node'` (exit 0)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp t9-M-07i-node-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result: `WG6` passes. This is the finding.** In `WG6`, w2 (115 left,
  into the node) and w3 (150 right, from the node) each have a face
  through the node point. So the node point is already a vertex of the
  central polygon (the test's own comment).

  A probe measured each wall's cap in both of `WG6`'s turns, with and
  without the mutant. It was a temporary test, deleted after the run.
  - **At 23°:** w2's cap already ends bitwise at the node point. Under the
    mutant it holds the node point twice, and `simplifyRing` removes the
    repeat. w3's cap does not take this return.
  - **At −53°:** w3's cap gains a repeat in the same way. w2's cap, which
    does not hold the node point on the clean tree, gains it as a new
    vertex: 2 points become 3.

  Nothing `WG6` asserts sees it. Every ring stays simple and
  triangulates, and no sample of the oracle's central polygon is covered
  twice.

  For this site the fixture is degenerate in exactly the way CLAUDE.md
  warns of: the node point sits on the faces, and the coverage check looks
  only inside the central polygon.

The mutant is still killed in the named file. The whole of
`wall_geometry_test.dart` (and, for completeness,
`wall_regen_test.dart`), under the same edit:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07i-node-file-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  326c326
  <       return (points: [left, right], ownsHole: false);
  ---
  >       return (points: [left, hub, right], ownsHole: false);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart` (exit 1)

  ```
  00:00 +7 -1: WG8 a 20° L: the two bands do not overlap (M-07j) [E]
    Expected: <0>
      Actual: <287>
    test/wall_geometry_test.dart 266:5                  main.<fn>
  00:00 +19 -1: Some tests failed.
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart` (exit 0)

  ```
  00:00 +12: All tests passed!
  ```
- **restore:** `cp t9-M-07i-node-file-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.

`WG8`'s 20° L clamps its outer wedge, so its non-owner end takes this same
path. The inserted node point overlaps the owner's walk: 287 samples
covered twice. `wall_regen_test.dart` stays green.

**The fixture, first as a probe.** A three-way node under mixed
justification where the node point is on no ring:

- w1: 200 centre, from the node at 10°;
- w2: 115 left, into the node from 130°;
- w3: 150 centre, from the node at 250°.

All three are at `plan(0, 0)` with the plan's 23° turn. w2's zero face
meets w3's −75 face at a 120° wedge, 87 mm out, so it is not clamped. The
node point is then a vertex of no ring, and the check "the node point is
on no ring" pins the site directly. The probe was a temporary
`apps/floor_planner/test/t9_probe_test.dart`, deleted after the run and
never committed. Its body:

```dart
final h = plan(0, 0);
final w1 = worldWall(11, h, polar(h, 10 + 23, 3000), 200);
final w2 = worldWall(12, polar(h, 130 + 23, 2000), h, 115, Justification.left);
final w3 = worldWall(13, h, polar(h, 250 + 23, 2500), 150);
final all = [w1, w2, w3];
final rings = [for (final w in all) ringOf(w, all)];
for (final o in rings) {
  expect(o.fellBack, isFalse);
  expect(o.hole, isNull);
  expect(o.ring.any((p) => (p - h).length < 1e-3), isFalse,
      reason: 'the node point is on no ring');
}
expect(overlapCensus([for (final o in rings) o.ring], h, 400), 0);
```

On the clean tree:
`cd apps/floor_planner && CI=true flutter test test/t9_probe_test.dart`
printed `00:00 +1: All tests passed!`, exit 0. Under the mutant:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07i-node-probe-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  326c326
  <       return (points: [left, right], ownsHole: false);
  ---
  >       return (points: [left, hub, right], ownsHole: false);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/t9_probe_test.dart` (exit 1)

  ```
  00:00 +0 -1: T9 probe: a three-way node with no face through the node point [E]
    Expected: false
      Actual: <true>
    test/t9_probe_test.dart 21:7                        main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07i-node-probe-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.

**Landed as `WG21`, on the controller's ruling.** It is the probe's
fixture, in `apps/floor_planner/test/wall_geometry_test.dart`:

- the far origin (`plan(0, 0)`), with the file's 23° turn (`rot`);
- each wall in its own rotated group (`worldWall`);
- `classify` confirms a node.

Every ring must be sound (`expectSound`: simple, triangulating, no
fallback, no hole). That keeps the fixture non-degenerate. The node point
must be on no ring, and the overlap census must be 0.

On the clean tree,
`cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG21 a three-way node'`
printed `00:00 +1: All tests passed!`.

Re-fire of M-07i at `wall_geometry.dart:326` against `WG21`:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07i-WG21-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  326c326
  <       return (points: [left, right], ownsHole: false);
  ---
  >       return (points: [left, hub, right], ownsHole: false);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG21 a three-way node'` (exit 1)

  ```
  00:00 +0 -1: WG21 a three-way node with no face through the node point: the node point is on no ring (M-07i at a node cap) [E]
    Expected: false
      Actual: <true>
    test/wall_geometry_test.dart 719:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07i-WG21-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG21`. Line 719 is the "node point is on no ring"
  check. The test fails there, not in `expectSound`, which runs first for
  each ring.
- **title (Task 11):** the red line above is pasted as it ran, under
  `WG21`'s first title, "with no face through the node point". That
  wording was wrong: w2 is left-justified, so its zero face does run
  through the node. Task 11 renamed the test "WG21 a three-way node under
  mixed justification: the node point is on no ring (M-07i at a node
  cap)". The probe's title in its own transcript above is left as it ran
  too. Title only; no behaviour changed, and `--plain-name 'WG21 a
  three-way node'` still matches it.

### M-07j — acute wedges clamped too

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07j-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  384c384
  <   if (c != null && (s < math.pi / 2 || (c - hub).length <= limit)) return [c];
  ---
  >   if (c != null && ((c - hub).length <= limit)) return [c];
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG8 a 20'` (exit 1)

  ```
  00:00 +0 -1: WG8 a 20° L: the two bands do not overlap (M-07j) [E]
    Expected: <0>
      Actual: <533>
    test/wall_geometry_test.dart 266:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07j-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG8`: 533 of the overlap census's samples lie in
  both bands of the 20° L.

### M-07k — the lobe owner not the lowest handle (two owners, or none)

Three forms: every member walks its lobe (two owners), nobody walks it
(no owner), and the highest handle walks it.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07k-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  316c316
  <         if (!owner) break;
  ---
  >         // M-07k: every member walks
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG6 a three-way node'` (exit 1)

  ```
  00:00 +0 -1: WG6 a three-way node, 200 centre / 115 left / 150 right: every ring simple, the central polygon covered exactly once (M-07k) [E]
    Expected: empty
      Actual: WhereIterable<int>:[
    test/wall_geometry_test.dart 188:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07k-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07k-none-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  309c309
  <         final owner = capsOn.first == i;
  ---
  >         final owner = false;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG6 a three-way node'` (exit 1)

  ```
  00:00 +0 -1: WG6 a three-way node, 200 centre / 115 left / 150 right: every ring simple, the central polygon covered exactly once (M-07k) [E]
    Expected: a value less than <0.000001>
      Actual: <100.00000000000398>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 178:9                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07k-none-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07k-highest-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  309c309
  <         final owner = capsOn.first == i;
  ---
  >         final owner = capsOn.last == i;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG6 a three-way node'` (exit 1)

  ```
  00:00 +0 -1: WG6 a three-way node, 200 centre / 115 left / 150 right: every ring simple, the central polygon covered exactly once (M-07k) [E]
    Expected: a value less than <0.000001>
      Actual: <100.00000000000398>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 178:9                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07k-highest-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG6` in all three forms:
  - **Two owners:** the central polygon is covered twice (`reason:
    overlap`).
  - **No owner, or the wrong one:** w1's ring lacks the oracle's central
    vertex. The nearest point is 100 mm away, at line 178.

  `WG6` runs twice, once with the lowest handle sorting second by angle and
  once with it sorting first.

### M-07l — the short-wall fallback also applied to neighbours (view level)

This follows the Task 5 ruling. `_outlineOf` leaves out of `others` every
neighbour whose own outline falls back, so a wall squares its end where a
neighbour fell back. That neighbour's outline is computed with the filter
off, so there is no recursion.

- **file:** `apps/floor_planner/lib/parametric/wall.dart`; backup `t9-M-07l-wall.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  110c110,111
  <     ParametricView view, WorldWall self) {
  ---
  >     ParametricView view, WorldWall self,
  >     [bool squareAtFallback = true]) {
  113c114,118
  <       if (_worldWall(view, n) case final w?) w,
  ---
  >       if (_worldWall(view, n) case final w?)
  >         if (!squareAtFallback ||
  >             w.degenerate ||
  >             !_outlineOf(view, w, false).fellBack)
  >           w,
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR8 a short wall'` (exit 1)

  ```
  00:00 +0 -1: WR8 a short wall between two nodes: moving the far neighbour of one node leaves nothing drifted (M-07l) [E]
    Expected: empty
      Actual: [1100]
    test/wall_regen_test.dart 383:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07l-wall.dart apps/floor_planner/lib/parametric/wall.dart`; `diff` exit 0.
- **result:** KILLED by `WR8`. After R moves, `run`'s `drift()` check
  (`reason: drift after Move`) finds L (1100) drifted. L's outline now
  depends on R through the short wall, which is the two-hop dependency
  06's one-hop closure does not regenerate.

### M-07m — a surplus region removed through its fill

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t9-M-07m-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  222c222
  <           e.key == EntityKind.fill ? _boundaryOf(t, c) : c,
  ---
  >           c,
  ```
- **command:** `cd packages/jet_cad_2d && CI=true dart test test/parametric/regions_test.dart --plain-name 'RG3 count'` (exit 1)

  ```
  00:00 +0 -1: RG3 count 1 -> 2 adds one region above the seed, fill first; 2 -> 1 removes the surplus pair, leaving no orphan (M-07m) [E]
    Expected: [1001, 1002, 1003, 1004]
      Actual: [1001, 1002, 1003, 1004, 1006]
       Which: at location [4] is [1001, 1002, 1003, 1004, 1006] which longer than expected
    test/parametric/regions_test.dart 211:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07m-regeneration.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0.
- **result:** KILLED by `RG3`. After 2 → 1, the orphaned boundary 1006
  survives its fill.

### M-07n — outline simplification removed

This is fired in `simplifyRing` itself, per the Task 4 ruling. The call
site is equivalent; see the Equivalent mutants section.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07n-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  463a464
  >   return r;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG12 a pinched node'` (exit 1)

  ```
  00:00 +0 -1: WG12 a pinched node (two corners exactly on the node): every ring triangulates; simplification removes the pinch (M-07n) [E]
    Expected: [
      Actual: [
       Which: at location [4] is [
    test/wall_geometry_test.dart 390:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07n-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG12`, line 390. The spliced ring keeps its
  repeated pinch, six points where four are expected.

### M-07o — neighbours computed for every object

`_survey` asks every object for its neighbours, as 06 did.

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t9-M-07o-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  97c97,101
  <   return _Survey(objects, reach, children, owned);
  ---
  >   final s = _Survey(objects, reach, children, owned);
  >   for (final h in order) {
  >     s.neighboursOf(h);
  >   }
  >   return s;
  ```
- **command:** `cd packages/jet_cad_2d && CI=true dart test test/parametric/neighbour_cost_test.dart --plain-name 'NC1 a root line'` (exit 1)

  ```
  00:00 +0 -1: NC1 a root line drawn among 300 objects performs no overlap test [E]
    Expected: <0>
      Actual: <179400>
    test/parametric/neighbour_cost_test.dart 113:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07o-regeneration.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0.
- **result:** KILLED by `NC1`: a root line drawn among 300 objects performs
  179,400 overlap tests. That is 2·n·(n − 1): both surveys, every object.

### M-07p — the panel's target read at focus loss

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t9-M-07p-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  249c249
  <     final target = f.pinned;
  ---
  >     final target = _targetOf(f.kind);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart --plain-name 'WS7 (Wall)'` (exit 1)

  ```
  00:02 +0 -1: WS7 (Wall) the commit target is pinned at focus gain: a selection change while a field has focus does not redirect its commit (M-07p); a pinned wall that dies drops the text [E]
  Expected: WallParams:<WallParams((589.5107255699113, 444.89701554295607) -> (-2120.8749622078612,
  -841.1082035345025), 260.0, centre)>
    Actual: WallParams:<WallParams((589.5107255699113, 444.89701554295607) -> (-2120.8749622078612,
  -841.1082035345025), 200.0, centre)>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/selection_panel_test.dart line 547
  00:02 +0 -1: Some tests failed.
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart --plain-name 'WS7 (Box)'` (exit 1)

  ```
  00:02 +0 -1: WS7 (Box) the commit target is pinned at focus gain: a selection change while a field has focus does not redirect its commit (M-07p) [E]
  Expected: [150, 70.0]
    Actual: [120.0, 70.0]
     Which: at location [0] is <120.0> instead of <150>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/selection_panel_test.dart line 636
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07p-selection_panel.dart apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0.
- **result:** KILLED by `WS7 (Wall)`: A keeps 200 where the pinned commit
  gives 260. It is also killed by `WS7 (Box)`: the first box keeps 120
  where 150 was typed. One edit covers both sections: `_commit` serves every
  field.

### M-07q — an end drag moves only the dragged wall

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t9-M-07q-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  84c84
  <         if ((w.endpoint(k) - at).length <= wallJoin.linear) ends.add((h, k));
  ---
  >         if ((w.endpoint(k) - at).length <= wallJoin.linear) {}
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_grips_test.dart --plain-name 'EG3 dragging'` (exit 1)

  ```
  00:02 +0 -1: EG3 dragging an L's shared end moves both walls' ends in one undo step, still mitred; a wall 3 mm off stays (Review Focus 3, M-07q) [E]
  Expected: [2932.404545989819, 1807.4357052622363]
    Actual: [2294.3935523279943, 1735.9040827811696]
     Which: at location [0] is <2294.3935523279943> instead of <2932.404545989819>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/wall_grips_test.dart line 243
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07q-wall_grips.dart apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0.
- **result:** KILLED by `EG3`, line 243 (`reason: A28 in its own group's
  local space`). The joined wall 0xA28 (2600) keeps its old end instead of
  following the drag.

### M-07r — the T's far face chosen

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-M-07r-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  265c265
  <       final off = me.a.dot(n) > 0 ? l : r;
  ---
  >       final off = me.a.dot(n) > 0 ? r : l;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG4 the T at 58'` (exit 1)

  ```
  00:00 +0 -1: WG4 the T at 58°: the stem butts the near face of a 200 right-justified wall; the through wall stays four points (M-07c, M-07r) [E]
    Expected: a value less than <0.000001>
      Actual: <200.00000000039103>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 133:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07r-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG4`: the stem's cap lies on the far face, 200 mm
  (the through wall's thickness) from the near one.

### M-07s — `reach` not expanded

- **file:** `apps/floor_planner/lib/parametric/wall.dart`; backup `t9-M-07s-wall.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  134c134
  <       ]).expandedBy(wallJoin.linear);
  ---
  >       ]);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_regen_test.dart --plain-name 'WR11 an axis-aligned L'` (exit 1)

  ```
  00:00 +0 -1: WR11 an axis-aligned L (0° and 90° in world) is a pair of neighbours and mitres (M-07s) [E]
    Expected: an object with length of <2>
      Actual: []
       Which: has length of <0>
    test/wall_regen_test.dart 511:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-M-07s-wall.dart apps/floor_planner/lib/parametric/wall.dart`; `diff` exit 0.
- **result:** KILLED by `WR11`. The axis-aligned L's two walls are not
  neighbours, so it does not mitre and shares no corners.

---

## The tasks' extras

### Geometry (Task 4 and its fix round)

**X-hub** — wedge faces through each end's own point, not the hub:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-X-hub-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382c382
  <   final c = intersect(x.leftPoint(hub), x.a, y.rightPoint(hub), y.a);
  ---
  >   final c = intersect(x.leftPoint(x.p), x.a, y.rightPoint(y.p), y.a);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG12 a pinched node'` (exit 1)

  ```
  00:00 +0 -1: WG12 a pinched node (two corners exactly on the node): every ring triangulates; simplification removes the pinch (M-07n) [E]
    Expected: an object with length of <2>
      Actual: WhereIterable<Vector2>:[Vector2:[4500000.0,1199999.9999999998]]
       Which: has length of <1>
    test/wall_geometry_test.dart 367:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-X-hub-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG12`: one shared corner where two are expected.

**X-anchor** — node members measured from this end, not the anchor:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-X-anchor-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  215c215
  <         if (_joined(w.endpoint(m), at)) End(w, m),
  ---
  >         if (_joined(w.endpoint(m), p)) End(w, m),
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG16 node membership'` (exit 1)

  ```
  00:00 +0 -1: WG16 node membership is measured from the anchor (Ruling 07-3): ends 1.8e-6 apart, each within tolerance of the lowest, form one watertight node [E]
    Expected: [71, 72, 73]
      Actual: [71, 72]
       Which: at location [2] is [71, 72] which shorter than expected
    test/wall_geometry_test.dart 576:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-X-anchor-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG16`: the third member is lost.

**X-samedir** — Ruling 07-4's same-direction exclusion removed:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-X-samedir-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  219c219
  <       if (!members.any((y) => !identical(x, y) && _sameDirection(x, y))) x,
  ---
  >       x,
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG17 two ends in one direction'` (exit 1)

  ```
  00:00 +0 -1: WG17 two ends in one direction keep free caps; the node is built from the rest (Ruling 07-4) [E]
    Expected: <Instance of 'Free'>
      Actual: <Instance of 'NodeJoint'>
       Which: is not an instance of 'Free'
    test/wall_geometry_test.dart 599:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-X-samedir-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG17`: an overlapping end joins the node instead of
  keeping a free cap.

**X-degenerate** — degenerate walls classified against:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-X-degenerate-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  192c192
  <       if (o.handle != self.handle && !o.degenerate) o,
  ---
  >       if (o.handle != self.handle) o,
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG18 a degenerate wall'` (exit 1)

  ```
  00:00 +0 -1: WG18 a degenerate wall has no ring and is never classified against (spec 07 D2) [E]
    Expected: [
      Actual: [
       Which: at location [0] is Vector2:<[4500005.569476132,1199893.7280646171]> instead of Vector2:<[4500078.146225698,1199924.5350670498]>
    test/wall_geometry_test.dart 633:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-X-degenerate-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG18`, line 633. A's ring among the degenerate
  walls is no longer A's ring in the plain L.

**X-holeowner** — every member reports the hole, not only the owner:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-X-holeowner-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  313c313
  <             ownsHole: owner && ring.length >= 3 && signedArea(ring) > 0
  ---
  >             ownsHole: ring.length >= 3 && signedArea(ring) > 0
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG14 plausible nodes'` (exit 1)

  ```
  00:00 +0 -1: WG14 plausible nodes (spike Q5b): hole rate < 1.5%, fallback rate < 0.5% [E]
    Expected: empty
      Actual: [
    test/wall_geometry_test.dart 529:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-X-holeowner-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG14`, line 529. Its `wrongHole` list, which
  records every hole node with other than exactly one reporter, is not
  empty.

**X2** — the shallow-T limit on the thinner wall:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-X2-min-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  269c269
  <       final limit = mitreLimit / 2 * math.max(me.wall.t, through.t);
  ---
  >       final limit = mitreLimit / 2 * math.min(me.wall.t, through.t);
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG19 a shallow T'` (exit 1)

  ```
  00:00 +0 -1: WG19 a shallow T squares its stem at its own end; a steeper one butts the near face (spec 07 D6: the limit is on the thicker wall) [E]
    Expected: a value less than <0.000001>
      Actual: <97.88730224557693>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 665:11                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-X2-min-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.

**X3** — the shallow-T clamp removed:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-X3-noclamp-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  270,273c270
  <       if (cl == null ||
  <           cr == null ||
  <           (cl - me.p).length > limit ||
  <           (cr - me.p).length > limit) {
  ---
  >       if (cl == null || cr == null) {
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG19 a shallow T'` (exit 1)

  ```
  00:00 +0 -1: WG19 a shallow T squares its stem at its own end; a steeper one butts the near face (spec 07 D6: the limit is on the thicker wall) [E]
    Expected: a value less than <0.000001>
      Actual: <549.8767406992237>
       Which: is not a value less than <0.000001>
    test/wall_geometry_test.dart 660:11                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-X3-noclamp-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** both KILLED by `WG19`.
  - **X2 (line 665):** it squares the 25° T. That T's corners lie within
    4 × 150 but beyond 4 × 57.5, so it should butt the near face; its cap
    point is 97.89 mm off it.
  - **X3 (line 660):** it butts the 10° T that should square. Its cap point
    is 549.88 mm from the square end.

**X-teelowest** — several T candidates: the highest handle:

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t9-X-teelowest-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  197c197
  <     if (through == null || o.handle.value < through.handle.value) through = o;
  ---
  >     if (through == null || o.handle.value > through.handle.value) through = o;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_geometry_test.dart --plain-name 'WG20 an end strictly inside'` (exit 1)

  ```
  00:00 +0 -1: WG20 an end strictly inside two centrelines (an X) tees onto the lower handle, whatever the order of the neighbours [E]
    Expected: <97>
      Actual: <98>
    test/wall_geometry_test.dart 685:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-X-teelowest-wall_geometry.dart apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0.
- **result:** KILLED by `WG20`: the end tees onto 98, not 97.

### Band joining (Task 6 fix rounds, Task 8's carried m1)

**No mapping** — a click inside a band is not mapped onto the wall:

- **file:** `apps/floor_planner/lib/parametric/wall_tool.dart`; backup `t9-B-nomap-wall_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  145d144
  <       if (_joinBandInto(ctx, point.x, point.y, joined)) point = joined;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT3 a click on a centreline'` (exit 1)

  ```
  00:02 +0 -1: WT3 a click on a centreline body makes a T whose stem butts the near face; a click on a centreline end makes a node [E]
  Expected: a value less than <0.000001>
    Actual: <18.02782955158721>
     Which: is not a value less than <0.000001>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/wall_tool_test.dart line 294
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-B-nomap-wall_tool.dart apps/floor_planner/lib/parametric/wall_tool.dart`; `diff` exit 0.

**Wrong side** — the band's faces mirrored:

- **file:** `apps/floor_planner/lib/parametric/wall_tool.dart`; backup `t9-B-wrongside-wall_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  219,220c219,220
  <       if (across > c[o + 7] + tol ||
  <           across < c[o + 8] - tol ||
  ---
  >       if (across > -c[o + 8] + tol ||
  >           across < -c[o + 7] - tol ||
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT3 a click on a centreline'` (exit 1)

  ```
  00:02 +0 -1: WT3 a click on a centreline body makes a T whose stem butts the near face; a click on a centreline end makes a node [E]
  Expected: a value less than <0.000001>
    Actual: <183.78780851798075>
     Which: is not a value less than <0.000001>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/wall_tool_test.dart line 139
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-B-wrongside-wall_tool.dart apps/floor_planner/lib/parametric/wall_tool.dart`; `diff` exit 0.

**No endpoint rule** — always the centreline projection, never the
endpoint within one thickness:

- **file:** `apps/floor_planner/lib/parametric/wall_tool.dart`; backup `t9-B-noend-wall_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  227c227
  <       if (along <= t || toEnd <= t) {
  ---
  >       if (false) {
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT3 a click on a centreline'` (exit 1)

  ```
  00:02 +0 -1: WT3 a click on a centreline body makes a T whose stem butts the near face; a click on a centreline end makes a node [E]
  Expected: [4503564.800075263, 1201839.075969993]
    Actual: [4503462.786708314, 1201786.4473995788]
     Which: at location [0] is <4503462.786708314> instead of <4503564.800075263>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/wall_tool_test.dart line 340
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-B-noend-wall_tool.dart apps/floor_planner/lib/parametric/wall_tool.dart`; `diff` exit 0.
- **result:** all three KILLED by `WT3`.
  - **No mapping (line 294):** the stem ends 18.03 mm off H's centreline,
    at the clicked grid point.
  - **Wrong side (line 139, in `expectTee`):** the stem ends 183.79 mm off
    the host's centreline. On H, a 200 centre host, the mirrored band is
    identical to the true one. So the miss is on `H2`, 240 left: a click
    in its one-sided band falls outside the mirrored band.
  - **No endpoint rule (line 340):** a click inside H's band within one
    thickness of its end tees onto the centreline instead of starting at
    H's end.

**F3 gate removed** — band joining with object snap off:

- **file:** `apps/floor_planner/lib/parametric/wall_tool.dart`; backup `t9-B-nogate-wall_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  206d205
  <     if (!(ctx.snap?.objectSnap ?? true)) return false;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT9 with object snap off'` (exit 1)

  ```
  00:02 +0 -1: WT9 with object snap off, a click in a wall's band joins nothing: it stays where it was clicked [E]
  Expected: a numeric value within <10.0> of <90>
    Actual: <3.447851574012098e-11>
     Which:  differs by <89.99999999996552>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/wall_tool_test.dart line 540
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-B-nogate-wall_tool.dart apps/floor_planner/lib/parametric/wall_tool.dart`; `diff` exit 0.
- **result:** KILLED by `WT9`, line 540. With F3 off, the stem's end is
  pulled onto the centreline, 3.4e-11 mm from it, instead of staying
  90 mm off, at the clicked grid point.

**No stale-mark in `accept`**:

- **file:** `apps/floor_planner/lib/parametric/wall_tool.dart`; backup `t9-B-nostale-wall_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  143d142
  <       _cacheStale = true;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT15 a click in the same synchronous task'` (exit 1)

  ```
  00:00 +0 -1: WT15 a click in the same synchronous task as an edit joins the band where the wall is now: a move, then an undo, each with no await (Task 6 review, m1) [E]
    Expected: [4501081.161956433, 1200524.1076453943]
      Actual: [4501104.605824143, 1200468.8773541872]
       Which: at location [0] is <4501104.605824143> instead of <4501081.161956433>
    test/wall_tool_test.dart 755:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-B-nostale-wall_tool.dart apps/floor_planner/lib/parametric/wall_tool.dart`; `diff` exit 0.
- **result:** KILLED by `WT15`: a click in the same synchronous task as a
  move joins the wall's old band.

**Highest handle first**:

- **file:** `apps/floor_planner/lib/parametric/wall_tool.dart`; backup `t9-B-highest-wall_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  211c211
  <     for (var i = 0, o = 0; i < _cachedWalls; i++, o += _stride) {
  ---
  >     for (var i = _cachedWalls - 1, o = (_cachedWalls - 1) * _stride; i >= 0; i--, o -= _stride) {
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT13 a click inside two crossing bands'` (exit 1)

  ```
  00:00 +0 -1: WT13 a click inside two crossing bands joins the lower handle (review round 2, m4) [E]
    Expected: a value less than <0.000001>
      Actual: <39.82050807558234>
       Which: is not a value less than <0.000001>
    test/wall_tool_test.dart 661:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-B-highest-wall_tool.dart apps/floor_planner/lib/parametric/wall_tool.dart`; `diff` exit 0.
- **result:** KILLED by `WT13`: the click joins the higher handle's
  centreline, 39.8 mm from the lower one's.

### Object grips (Tasks 7 and 8)

**Provider ignored** — `GripCache` never consults the provider:

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t9-P-provider-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  304c304
  <         final provider = objects;
  ---
  >         final ObjectGripProvider? provider = null;
  ```
- **command:** `cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'OG2 a provider'` (exit 1)

  ```
  00:00 +0 -1: OG2 a provider's grips appear for a selected root-level group only, in world, after the lower handles' grips [E]
    Expected: [25]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/object_grips_test.dart 159:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-P-provider-grip_cache.dart packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0.
- **result:** KILLED by `OG2`: the group has no grips.

**Revalidation dropped**, in three parts: the node check, the leaf count,
and each leaf's payload.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; backup `t9-P-reval-node-grip_drag.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  337,338c337
  <         case _ObjectCapture(:final handle, :final node, :final leaves):
  <           if (document.tree[handle] != node) return false;
  ---
  >         case _ObjectCapture(:final handle, :final leaves):
  ```
- **command:** `cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'OG4 a document change mid-drag'` (exit 1)

  ```
  00:00 +0 -1: OG4 a document change mid-drag cancels the object reshape the group node [E]
    Expected: empty
      Actual: [
    test/object_grips_test.dart 291:9                   main.<fn>.<fn>
  00:00 +2 -1: Some tests failed.
  ```
- **restore:** `cp t9-P-reval-node-grip_drag.dart packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; `diff` exit 0.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; backup `t9-P-reval-count-grip_drag.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  344d343
  <           if (owned != leaves.length) return false;
  ```
- **command:** `cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'OG4 a document change mid-drag'` (exit 1)

  ```
  00:00 +2 -1: OG4 a document change mid-drag cancels the object reshape a child added [E]
    Expected: empty
      Actual: [
    test/object_grips_test.dart 291:9                   main.<fn>.<fn>
  00:00 +2 -1: Some tests failed.
  ```
- **restore:** `cp t9-P-reval-count-grip_drag.dart packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; `diff` exit 0.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; backup `t9-P-reval-payload-grip_drag.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  347,350c347
  <             if (slot == null ||
  <                 e.ownerAt(slot) != handle ||
  <                 e.kindAt(slot) != entityKind ||
  <                 document.geometry.peek(e.geomIndexAt(slot)) != payload) {
  ---
  >             if (slot == null) {
  ```
- **command:** `cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'OG4 a document change mid-drag'` (exit 1)

  ```
  00:00 +1 -1: OG4 a document change mid-drag cancels the object reshape a child's payload [E]
    Expected: empty
      Actual: [
    test/object_grips_test.dart 291:9                   main.<fn>.<fn>
  00:00 +2 -1: Some tests failed.
  ```
- **restore:** `cp t9-P-reval-payload-grip_drag.dart packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; `diff` exit 0.
- **result:** each part KILLED by its own `OG4` case: "the group node", "a
  child added" and "a child's payload". In each, the provider's `drag` is
  called after a mid-drag document change.

**No-op guard** — an out-and-back object drag dispatches:

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; backup `t9-P-noop-grip_drag.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  275d274
  <             if (target.x == base.x && target.y == base.y) return null;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_grips_test.dart --plain-name 'EG1 a free end'` (exit 1)

  ```
  00:02 +0 -1: EG1 a free end drags to the resolved point, stored in its own group, the other end untouched; one undo step; a degenerate drop is refused, and a drag back onto the grip dispatches nothing [E]
  Expected: <0>
    Actual: <1>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/wall_grips_test.dart line 192
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-P-noop-grip_drag.dart packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; `diff` exit 0.
- **result:** KILLED by `EG1`, line 192. A drag back onto the grip leaves
  `undoDepth` 1 where it should be 0.

### Selection panel (Task 8 review round 1)

**`onChanged` removed** — tool-settings keystrokes reach the settings
only at focus loss:

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t9-S-onchanged-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  331c331
  <           if (f.pinned != _toolSettings) return;
  ---
  >           return;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart --plain-name 'WS6 with the Wall tool active'` (exit 1)

  ```
  00:02 +0 -1: WS6 with the Wall tool active the section edits the tool's settings (no undo step) and the next wall uses them; tool letters typed in the field do not switch tools [E]
  Expected: <400>
    Actual: <115.0>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/selection_panel_test.dart line 499
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-S-onchanged-selection_panel.dart apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0.
- **result:** KILLED by `WS6`: the mid-chain click's wall is built at 115,
  the old thickness, not the typed 400 (I1).

**No re-pin after a commit** — the field keeps its old pin:

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t9-S-repin-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  257c257
  <     f.pinned = f.focus.hasFocus ? _targetOf(f.kind) : null;
  ---
  >     f.pinned = f.focus.hasFocus ? f.pinned : null;
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart --plain-name 'WS7 (Wall)'` (exit 1)

  ```
  00:02 +0 -1: WS7 (Wall) the commit target is pinned at focus gain: a selection change while a field has focus does not redirect its commit (M-07p); a pinned wall that dies drops the text [E]
  Expected: WallParams:<WallParams((589.5107255699113, 444.89701554295607) -> (-2120.8749622078612,
  -841.1082035345025), 275.0, centre)>
    Actual: WallParams:<WallParams((589.5107255699113, 444.89701554295607) -> (-2120.8749622078612,
  -841.1082035345025), 150.0, centre)>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/selection_panel_test.dart line 562
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-S-repin-selection_panel.dart apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0.
- **result:** KILLED by `WS7 (Wall)`, line 562. Enter commits 275 onto A.
  Then the blur commits the field's shown text, C's 150, onto A again
  (I3).

**Dead-target check** — a dead pinned target falls back to the current
target:

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t9-S-deadtarget-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  249c249,252
  <     final target = f.pinned;
  ---
  >     var target = f.pinned;
  >     if (target != null && _read(f.kind, target) == null) {
  >       target = _targetOf(f.kind);
  >     }
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart --plain-name 'WS7 (Wall)'` (exit 1)

  ```
  00:02 +0 -1: WS7 (Wall) the commit target is pinned at focus gain: a selection change while a field has focus does not redirect its commit (M-07p); a pinned wall that dies drops the text [E]
  Expected: WallParams:<WallParams((402.8892971193418, -1198.7977924821898) -> (-62.85478356713429,
  -3184.5174230705015), 150.0, right)>
    Actual: WallParams:<WallParams((402.8892971193418, -1198.7977924821898) -> (-62.85478356713429,
  -3184.5174230705015), 333.0, right)>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/selection_panel_test.dart line 583
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-S-deadtarget-selection_panel.dart apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0.
- **result:** KILLED by `WS7 (Wall)`, line 583: the dead wall's typed 333
  lands on C (I2).

### Planner and engine cost (Tasks 1-3)

**matchbound** — a region's boundary also matched as a plain POLYLINE:

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t9-E-matchbound-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  165d164
  <       if (boundaries.contains(c)) continue;
  221a221
  >           if (!boundaries.contains(c))
  ```
- **command:** `cd packages/jet_cad_2d && CI=true dart test test/parametric/regions_test.dart --plain-name 'RG2 a width edit'` (exit 1)

  ```
  00:00 +0 -1: RG2 a width edit rewrites each boundary in place: handles kept, fill re-triangulated, one undo step, exact undo/redo [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/parametric/regions_test.dart 153:24  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-E-matchbound-regeneration.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0.
- **result:** KILLED by `RG2`. `expectRegionsWhole` (line 81, `reason:
  no orphan boundary: []`) finds no plain POLYLINE where exactly one, the
  open centreline, is expected. Once boundaries are no longer excluded
  from plain matching, the centreline's `Generated` is matched against a
  region's boundary.

**owner guard** — a fill naming a foreign boundary is accepted:

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t9-E-owner-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  178c178
  <         if (slot == null || t.entities.ownerAt(slot) != h) {
  ---
  >         if (slot == null) {
  ```
- **command:** `cd packages/jet_cad_2d && CI=true dart test test/parametric/regions_test.dart --plain-name 'RG9 a loaded fill'` (exit 1)

  ```
  00:00 +0 -1: RG9 a loaded fill naming a foreign or missing boundary: an edit throws StateError and nothing changes [E]
    Expected: throws <Instance of 'StateError'>
      Actual: <Closure: () => void>
       Which: returned <null>
    test/parametric/regions_test.dart 367:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-E-owner-regeneration.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0.
- **result:** KILLED by `RG9`: no `StateError`.

**nomemo** — the neighbour memo never hit:

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t9-E-nomemo-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  53d52
  <     if (cached != null) return cached;
  ```
- **command:** `cd packages/jet_cad_2d && CI=true dart test test/parametric/neighbour_cost_test.dart --plain-name 'NC2 moving one of 300'` (exit 1)

  ```
  00:00 +0 -1: NC2 moving one of 300 objects performs fewer than 10 × n tests: exactly one search per closure member, plus the seed's before [E]
    Expected: <2093>
      Actual: <2392>
    test/parametric/neighbour_cost_test.dart 142:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-E-nomemo-regeneration.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0.
- **result:** KILLED by `NC2`'s exact count: 2392 tests where the memo gives
  2093.

### Colour (Task 6b)

**`kWallColor` ByLayer** — layer 0's ACI 7 resolves to white:

- **file:** `apps/floor_planner/lib/parametric/wall.dart`; backup `t9-C-bylayer-wall.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  27c27
  < const DraftColor kWallColor = TrueColor(0x000000);
  ---
  > const DraftColor kWallColor = ByLayerColor();
  ```
- **command:** `cd apps/floor_planner && CI=true flutter test test/wall_paint_test.dart --plain-name 'WP5 a wall drawn with W'` (exit 1)

  ```
  00:02 +0 -1: WP5 a wall drawn with W paints a dark band on white paper, not a paper-white one (07 D3, smoke test) [E]
  Expected: a value less than <0.2>
    Actual: <0.9999999999999999>
     Which: is not a value less than <0.2>
    file:///home/user/jet-cad/.claude/worktrees/walls/apps/floor_planner/test/wall_paint_test.dart line 106
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp t9-C-bylayer-wall.dart apps/floor_planner/lib/parametric/wall.dart`; `diff` exit 0.
- **result:** KILLED by `WP5`, line 106. The band's luminance is 1.0, paper
  white, where < 0.2 is required.

---

## Equivalent mutants (recorded, not fired)

- **M-07n at `outline`'s call site** (`simplifyRing([...])` →
  `[...]`) is equivalent for triangulation, not for stored bits.
  - The lobes split at exactly repeated vertices, and the triangulator
    tolerates consecutive duplicates.
  - The Task 4 reviewer's probe: `simplifyRing` changed 567 of 700,076 raw
    rings and never changed a triangulation outcome.
  - After deviation (1), the hub rule, the pinched-node path is
    unreachable. That is why the named M-07n is fired in `simplifyRing`
    itself.
- **A region emitted after the centreline** (Task 5 reviewer): `_plan`
  plans every filled `Generated` before any plain one, whatever the order
  of `generate`'s list. The children's handles and payloads are identical.
- **Self in `others`** (Task 5 reviewer): `classify` drops `self` from
  `others` (`o.handle != self.handle`) before any test.
- **`ParametricEdit.apply`'s guard restore set to `false`** (Task 3
  re-review): `apply` is entered only through `execute`, and the expander
  refuses entry while the guard is armed. So the restored value is never
  observed.

## N/A

- **The snap-mask mutant:** there is none. Task 6c removed the Wall tool's
  `nearest` snap and e882160's mask plumbing; the tool uses the default
  mask. Band joining does every joint, and its mutants are above.

## Gate at commit

Run on `dcbc831` plus this note, with every mutant restored and
`git status --short` showing only this file:

```
packages/jet_cad_2d          dart test          00:15 +972 -2: Some tests failed.   (exit 1; the two Linux-only hash tests in generate_document_test.dart, standing)
                             dart analyze       No issues found!                     (exit 0)
                             dart format        Formatted 144 files (0 changed) in 0.72 seconds.  (exit 0)
packages/jet_cad_2d_flutter  flutter test       00:46 +931 ~1 -7: Some tests failed. (exit 1; text_ladder rungs 1-5 and text_lod_ladder rungs 1-2, standing)
                             flutter analyze    No issues found! (ran in 1.2s)       (exit 0)
                             dart format        Formatted 177 files (0 changed) in 0.55 seconds.  (exit 0)
apps/dev_harness_2d          flutter test --concurrency=1  00:33 +82: All tests passed!  (exit 0)
                             flutter analyze    No issues found! (ran in 1.5s)       (exit 0)
                             dart format        Formatted 22 files (0 changed) in 0.10 seconds.   (exit 0)
apps/floor_planner           flutter test       00:22 +137: All tests passed!        (exit 0)
                             flutter analyze    No issues found! (ran in 0.8s)       (exit 0)
                             dart format        Formatted 32 files (0 changed) in 0.14 seconds.   (exit 0)
                             flutter build web --release   ✓ Built build/web        (exit 0)
```

After `WG21` landed, the app line was re-run on the tree with it:

```
apps/floor_planner           flutter test       00:23 +138: All tests passed!        (exit 0)
                             flutter analyze    No issues found! (ran in 1.0s)       (exit 0)
                             dart format        Formatted 32 files (0 changed) in 0.15 seconds.   (exit 0)
                             flutter build web --release   ✓ Built build/web        (exit 0)
```
