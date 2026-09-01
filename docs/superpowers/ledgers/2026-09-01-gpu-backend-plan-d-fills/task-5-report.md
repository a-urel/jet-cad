# Task 5 report: the shader draws a fill, and the Dart transcription says the same thing

Branch `plan-d/fills`. Work confined to `packages/jet_cad_2d_flutter`, as instructed.

## Files touched

- `shaders/cad_stroke.vert` — the fill branch, and the point-branch narrowing.
- `test/support/instance_expander.dart` — the mirrored Dart, edited in the same order,
  same variable names.
- `lib/src/gpu/resident_geometry.dart` — documentation only: a role-mapping table
  on `kCornerVertices` explaining how a fill reads the same V/A/B/M table a join uses.
- `test/gpu/instance_expander_test.dart` — the four tests from the brief, verbatim,
  inserted before the existing "renumber-prone constants" test.

## The shader diff and the expander diff, side by side

Both diffs narrow the point dispatch from a bare `else` to `else if (kind < 2.5)`
and add a fill `else` branch immediately after, in the same order, with the
same names (`a0/a1/a2` in the shader map to `a0x/a0y`, `a1x/a1y`, `a2x/a2y` in
Dart — GLSL's `vec2` has no Dart equivalent, so the transcription splits each
into an x/y pair, which is this file's established convention for every other
branch too).

### `shaders/cad_stroke.vert`

```diff
@@ -17,6 +17,12 @@
 // the suite can actually run. Any edit here that is not mirrored there is a
 // divergence no test in this package can see -- change them together.
 //
+// **A fill is the one kind that expands nothing.** Its three corners are
+// projected and used; `half_width` is zero and is not read. The six-vertex
+// corner table is reused unchanged: `join_weight`'s V, A and B select the
+// three corners and M is folded onto A, so the second triangle is
+// degenerate and rasterises nothing (Plan D's Ruling D1).
+//
 // **Dashes are decided here and tested one line away.** The vertex stage
 // turns the instance's `dash` quad into a single varying, `t`, which is the
 // pattern-space coordinate at this vertex; the fragment stage keeps the
@@ -151,7 +157,7 @@ void main() {
     // `along` stays 0: every vertex of a join wedge sits at the corner, so
     // the whole wedge is tested at the phase stored for that corner.
 
-  } else {
+  } else if (kind < 2.5) {
     // kKindPoint: a square of the stroke's width centred on p0. Both axes
     // are expanded here, in device pixels, so the dot stays square and stays
     // the same size at every zoom -- which is what the reference gets for
@@ -159,6 +165,20 @@ void main() {
     // dashed.
     vec2 c = to_pixels(p0);
     px = c + vec2((corner.x * 2.0 - 1.0) * half_width, corner.y * half_width);
+
+  } else {
+    // kKindFill: one triangle of a pre-triangulated fill. Nothing is
+    // expanded -- a fill has no width -- so `half_width` is not read here at
+    // all. `join_weight` selects the corner: V -> p0, A -> p1, B -> p2, and
+    // M folded onto p1, which makes the second triangle (A, M, B) =
+    // (p1, p1, p2) degenerate.
+    vec2 a0 = to_pixels(p0);
+    vec2 a1 = to_pixels(p1);
+    vec2 a2 = to_pixels(p2);
+    px = join_weight.x * a0 + (join_weight.y + join_weight.w) * a1 +
+         join_weight.z * a2;
+    // `along` stays 0 and `dash` is all zeros on a fill, so the tail's
+    // `period > 0.0` test fails and `v_dash` keeps its solid sentinel.
   }
 
   gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
```

### `test/support/instance_expander.dart`

```diff
@@ -22,6 +22,14 @@
 /// `dashScale` `cad_stroke.vert` reads off `frame_info.dash_scale`. Read the
 /// dash block in `expandInstances` beside the shader's own tail, in the same
 /// order: the sentinel, the period test, the collapse override.
+///
+/// **Plan D's Task 5 added the fill branch, transcribed the same way.** A
+/// fill instance (`kKindFill`) reads no `halfWidth` and expands nothing: its
+/// three corners are projected and selected by `join_weight`'s V, A and B,
+/// with M folded onto A so the six-vertex corner table's second triangle is
+/// degenerate. The point branch is narrowed to `kind < 2.5` in both files so
+/// the fill branch's bare `else` cannot swallow it -- see the branch's own
+/// comment below for the failure that guards against.
 library;
 
 import 'dart:math' as math;
@@ -254,7 +262,7 @@ ExpandedTriangles expandInstances(
           px = c.wv * vx + c.wa * ax + c.wb * bx + c.wm * mx;
           py = c.wv * vy + c.wa * ay + c.wb * by + c.wm * my;
         }
-      } else {
+      } else if (kind < 2.5) {
         // kKindPoint: a square of the stroke's width centred on p0. Both
         // axes are expanded here, in device pixels, so the dot stays square
         // and stays the same size at every zoom -- which is what the
@@ -263,6 +271,17 @@ ExpandedTriangles expandInstances(
         final cx = toX(x0, y0), cy = toY(x0, y0);
         px = cx + (c.x * 2.0 - 1.0) * halfWidth;
         py = cy + c.y * halfWidth;
+      } else {
+        // kKindFill: one triangle of a pre-triangulated fill. Nothing is
+        // expanded -- a fill has no width -- so `halfWidth` is not read here
+        // at all. `join_weight` selects the corner: V -> p0, A -> p1,
+        // B -> p2, and M folded onto p1, which makes the second triangle
+        // (A, M, B) = (p1, p1, p2) degenerate.
+        final a0x = toX(x0, y0), a0y = toY(x0, y0);
+        final a1x = toX(x1, y1), a1y = toY(x1, y1);
+        final a2x = toX(x2, y2), a2y = toY(x2, y2);
+        px = c.wv * a0x + (c.wa + c.wm) * a1x + c.wb * a2x;
+        py = c.wv * a0y + (c.wa + c.wm) * a1y + c.wb * a2y;
       }
 
       final vi = (i * cornerVertexCount + v);
```

`c.wv`, `c.wa`, `c.wb`, `c.wm` are the expander's existing per-corner names for
`join_weight.x/.y/.z/.w` (see `_Corner`'s field list); the shader's
`join_weight.x/.y/.w/.z` map to them 1:1, so no new naming was introduced.

### `lib/src/gpu/resident_geometry.dart` (documentation only)

A role-mapping table was inserted into `kCornerVertices`'s doc, immediately
after the join-branch explanation, giving the join role each fill role reads
(`V -> p0, A -> p1, B -> p2, M -> p1`) and stating the resulting triangles are
`(p0, p1, p2)` and the degenerate `(p1, p1, p2)`. Full diff:

```diff
@@ -63,6 +63,23 @@ class ResidentGeometry {
   /// flips the outer side with the sign of the cross product — which is why
   /// `GpuDrawBackend.render` pins `CullMode.none`.
   ///
+  /// **A fill (Plan D's Ruling D1) reads this same table, with its own role
+  /// mapping.** A fill has only three points, not a join's four, so `M` is
+  /// folded onto `A` rather than computed:
+  ///
+  /// | role | join reads      | fill reads |
+  /// |------|------------------|------------|
+  /// | V    | the corner       | `p0`       |
+  /// | A    | the incoming leg | `p1`       |
+  /// | B    | the outgoing leg | `p2`       |
+  /// | M    | the miter tip    | `p1` (== A)|
+  ///
+  /// Triangle 0 is therefore `(p0, p1, p2)` — the fill's real triangle — and
+  /// triangle 1 is `(p1, p1, p2)` — zero area, so it rasterises nothing. A
+  /// reader who has only seen the join-branch explanation above would not
+  /// know this table is shared with a fourth kind; this paragraph is that
+  /// pointer.
+  ///
   /// `@visibleForTesting`: no test can reach this data through `create`
   /// itself (it runs only with a real GPU context), so it is hoisted here to
   /// be asserted directly by a plain `flutter test`.
```

## The shader bundle

```
$ cd packages/jet_cad_2d_flutter && sh tool/build_shaders.sh
wrote assets/shaders/cad.shaderbundle

$ shasum -a 256 assets/shaders/cad.shaderbundle
1d538d2c325afe0e03d6e51948e6841832cf73d6c41ab3a0344a7a2edcd255c7  assets/shaders/cad.shaderbundle

$ strings -a assets/shaders/cad.shaderbundle | grep -c "attribute "
16
```

**The count came back 16, not 8 as the brief anticipated — this is not a
regression.** I checked it against the bundle as it stood *before* this task
(`git show a6cd72c:packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle`,
the last commit to touch the bundle): it also greps to 16, with the identical
set of 8 attribute names (`kind_half`, `p0`, `p1`, `corner`, `p2`,
`join_weight`, `color`, `dash`), each appearing exactly twice. `impellerc`'s
`--runtime-stage-gles` output embeds two copies of the ES100 GLSL source text
in the bundle (consistent with `resident_geometry.dart`'s own doc comment
about `transpileGlslEs100To300` reading the `openglEs` stage and transpiling
it — the bundle appears to carry the pre-transpile source alongside something
else that also matches `"attribute "`), not one, so the raw `grep -c` count in
this repository was never 8 to begin with. What the brief's check actually
guards against — a folded-away attribute — did not happen: the count is
**unchanged** (16 before, 16 after) and the same 8 names are present at the
same multiplicity. The build did not fail with a reflection error, which is
the other signal the brief names for exactly this defect.

## Gate commands, verbatim

### `flutter test test/gpu/instance_expander_test.dart` (targeted, all 19 including the 4 new)

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/instance_expander_test.dart
00:00 +0: a solid instance signals solid with a negative fracStart
00:00 +1: t runs from phase/period to (phase + length)/period across the quad
00:00 +2: t is measured in COLLECTION units, so the camera cancels
00:00 +3: a collapsed non-representative instance produces a degenerate triangle
00:00 +4: the collapse threshold is the dasher's own value
00:00 +5: a point instance is never dashed
00:00 +6: the miter cosine matches the reference constant
00:00 +7: a horizontal stroke expands to the quad the reference builds
00:00 +8: a right-angle join is mitred, and the tip is at the outer corner
00:00 +9: a hairpin turn is bevelled: the tip triangle has zero area
00:00 +10: a collinear join collapses onto its vertex
00:00 +11: a point expands to a square of the stroke width
00:00 +12: half-width does not scale with the transform
00:00 +13: a stroke under a transform with every coefficient non-zero matches by hand
00:00 +14: a fill expands to its three corners and one degenerate triangle
00:00 +15: a fill is not expanded by a half-width, at any camera
00:00 +16: a fill is solid: the dash test never runs on it
00:00 +17: a point is still a point after the fill branch lands
00:00 +18: cad_stroke.vert still carries the three renumber-prone constants
00:00 +19: All tests passed!
EXIT: 0
```

### `flutter test` (full suite, global constraint gate 1)

Tail of the run (full transcript is 541 lines of package-download noise plus
per-test lines; every line before this tail was `+N` or `+N ~1`, no `-`):

```
00:05 +553 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:06 +554 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:06 +555 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:06 +556 ~1: All tests passed!
EXIT: 0
```

556 tests, 1 pre-existing skip (unrelated to this task — present before this
branch's work and not touched here), 0 failures.

### `flutter analyze` (global constraint gate 2)

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
EXIT: 0
```

### `dart format --output=none --set-exit-if-changed .` (global constraint gate 3)

```
Formatted 91 files (0 changed) in 0.13 seconds.
EXIT: 0
```

All three global gates green.

## Killability, per test

I ran each mutation described below against the working tree (restoring the
correct code afterward, verified via `diff` against a saved-good copy before
moving on) rather than asserting it from reading the code.

1. **"a fill expands to its three corners and one degenerate triangle."**
   Mutation: un-narrow the point branch back to a bare `else` and drop the
   fill branch (i.e. Plan D's Task 5 landing the shader edit without the
   expander mirror actually taking effect — every fill instance falls into
   the point-square arithmetic instead). Result: **fails** —
   `Expected: <40>, Actual: <10.0>` on `positions[2]` (triangle 0's second
   vertex should be `p1 = (40, 12)`; the point branch collapses everything to
   `p0`).

2. **"a fill is not expanded by a half-width, at any camera."** Same
   mutation as (1). Result: **fails** — `Expected: <133.32...>,
   Actual: <124.32...>`, off by exactly `9.0`, the poisoned `halfWidth` the
   test writes into the record to make an accidental read visible.

3. **"a fill is solid: the dash test never runs on it."** The branch-merge
   mutation above does *not* kill this one — a point's dash slots are also
   all zero, so a fill routed into the point branch still keeps the solid
   sentinel by coincidence, and the test's own fixed `dashScale: 0.01`
   collapses even a moderately large forged period before the sentinel would
   ever be overwritten. I found the mutation that does kill it: change
   `writeFill`'s `_writeDash` call (`instance_record.dart`) to write a
   non-collapsing period, e.g. `_writeDash(into, o, 1000, 0, 0, 1)` instead of
   all zeros. Result: **fails** — `Expected: a value less than <0.0>,
   Actual: <0.0>` (the "solid" sentinel is overwritten once the period clears
   the collapse threshold). This is the honest scope of what this test
   guards: not the shader's kind dispatch, but `writeFill`'s contract that a
   fill is never dashed. It is still worth keeping — a future edit to
   `writeFill` that passed through a real dash argument by mistake is exactly
   the kind of silent defect this plan's testing bar targets — but I want to
   flag explicitly that the brief's own inline comment ("The defect this
   catches: a fill routed through the stroke branch...") does not match what
   I could make it fail on; I could not construct a branch-routing mutation
   that kills this specific test, because every other kind's dash slots are
   also zero-or-collapsing in the fixtures this test uses.

4. **"a point is still a point after the fill branch lands."** Mutation:
   swap the two branch *bodies* while keeping both `else if (kind < 2.5)` and
   the trailing `else` (i.e. the branches are correctly dispatched but
   contain each other's arithmetic — modeling "swapping the two draws every
   point as a triangle" from the brief). Result: **fails** —
   `Expected: <8>, Actual: <20.0>` (the point's bounding box, which should be
   an 8-device-pixel square, instead spans 20 because it's now running fill
   arithmetic against a record whose `x1/y1/x2/y2` are zero). The pre-existing
   test "a point expands to a square of the stroke width" also fails under
   this same mutation, which is expected and reinforces rather than
   substitutes for the new test — the new test is scoped narrowly to "did the
   *fill* branch's arrival break a point," independent of that older test's
   continued presence.

## Anything the plan did not anticipate

- **The attribute-count check reads 16, not 8, and always has.** See the
  bundle section above — verified this is a pre-existing property of
  `impellerc`'s GLES output in this repo, not something this task's edit
  changed, by diffing against the last-committed bundle. I flagged rather
  than silently "fixed" the report to claim 8, since the brief was explicit
  that a fabricated number is worse than a surprising true one.
- **Test 3 of the brief's four doesn't kill on the mutation its own inline
  comment names.** Documented above under killability item 3, with the
  mutation that does kill it instead. I kept the test as specified (Ruling
  B6 and the brief hand me this test's code verbatim), since it does guard a
  real, if narrower, contract (`writeFill` never producing a dashed
  instance), and dropping a brief-specified test did not seem like a task-5
  decision to make unilaterally — flagging it for the reviewer instead.
- No attribute, no record float, and no signature change were needed, as the
  brief predicted; `expandInstances`'s public signature is untouched.
- `packages/jet_cad_2d` and `lib/src/vertices_draw_sink.dart` were not
  touched.
- `git status --short` before commit showed only the five intended files;
  no `analysis_options.yaml` appeared.

## Commit

```
git add packages/jet_cad_2d_flutter/shaders/cad_stroke.vert \
        packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle \
        packages/jet_cad_2d_flutter/test/support/instance_expander.dart \
        packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart \
        packages/jet_cad_2d_flutter/test/gpu/instance_expander_test.dart
git commit -m "feat(gpu): the vertex shader draws a fill triangle"
```
