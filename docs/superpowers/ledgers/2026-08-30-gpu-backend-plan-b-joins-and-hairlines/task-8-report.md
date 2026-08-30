# Task 8 report: the vertex shader, in Dart

Commit: `fffefc5` on `plan-b/joins-and-hairlines` (base `f67bda5`).

## Files

- Created `packages/jet_cad_2d_flutter/test/support/instance_expander.dart`
- Created `packages/jet_cad_2d_flutter/test/gpu/instance_expander_test.dart`
- Modified `packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart`
  (one-line doc citation fix)

`packages/jet_cad_2d` was not touched.

## Source read first

Read `packages/jet_cad_2d_flutter/shaders/cad_stroke.vert` in full before
writing or trusting the brief's sample. Also read, to pin the interfaces the
brief could not know:

- `packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart`
  (`InstanceFieldOffset`, `kKindStroke/Join/Point`, `writeStroke/Join/Point`)
- `packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart`
  (`kCornerVertices`, `kFloatsPerCorner`)
- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
  (`kMinMiterCosine`, `_emitJoin`, `_colors` as `Int32List`)
- `packages/jet_cad_2d/lib/src/geometry/transform2.dart` (`Transform2`,
  `scaleMagnitude`)
- `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart`
  (`observe(Float32List, Int32List)`, uses `.toUnsigned(32)` internally)
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` (established
  convention for comparing `Int32List` colours against ARGB literals)

## TDD evidence

### Before: failing run (verbatim)

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
...
00:00 +0: loading .../test/gpu/instance_expander_test.dart
test/gpu/instance_expander_test.dart:8:8: Error: Error when reading 'test/support/instance_expander.dart': No such file or directory
import '../support/instance_expander.dart';
       ^
test/gpu/instance_expander_test.dart:15:12: Error: Undefined name 'kExpanderMinMiterCosine'.
    expect(kExpanderMinMiterCosine, VerticesDrawSink.kMinMiterCosine);
           ^^^^^^^^^^^^^^^^^^^^^^^
test/gpu/instance_expander_test.dart:22:17: Error: Method not found: 'expandInstances'.
...
00:00 +0 -1: loading .../test/gpu/instance_expander_test.dart [E]
  Failed to load "...instance_expander_test.dart":
  Compilation failed for testPath=...
00:00 +0 -1: Some tests failed.
exit=1
```

This matched the brief's expected failure (`Target of URI doesn't exist`)
plus the compile-time fallout of the other undefined symbols, since the test
file references `kExpanderMinMiterCosine` and `expandInstances` from the same
missing file.

### After: passing run (verbatim)

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
...
00:00 +0: loading .../test/gpu/instance_expander_test.dart
00:00 +0: the miter cosine matches the reference constant
00:00 +1: a horizontal stroke expands to the quad the reference builds
00:00 +2: a right-angle join is mitred, and the tip is at the outer corner
00:00 +3: a hairpin turn is bevelled: the tip triangle has zero area
00:00 +4: a collinear join collapses onto its vertex
00:00 +5: a point expands to a square of the stroke width
00:00 +6: half-width does not scale with the transform
00:00 +7: All tests passed!
exit=0
```

## Statement-by-statement correspondence, `cad_stroke.vert` <-> the Dart

`to_pixels` is not transcribed as a separate function; it is inlined as
`toX`/`toY`, computing `Transform2.transformPoint` in closed form (avoids a
`Vector2` allocation per vertex, consistent with the "test-only, but do not
give a later reader the idea the allocation rule moved" instruction). The
shader's two-step `mvp` then `half_viewport` is one `Transform2` argument,
`collectionToDevice`, per the brief's own note that the composition is the
same affine map either way.

### Branch: `kind < 0.5` (stroke)

| GLSL | Dart |
|---|---|
| `vec2 a = to_pixels(p0);` | `ax = toX(x0,y0), ay = toY(x0,y0);` |
| `vec2 b = to_pixels(p1);` | `bx = toX(x1,y1), by = toY(x1,y1);` |
| `vec2 delta = b - a;` | `dx = bx-ax, dy = by-ay;` |
| `float len = length(delta);` | `len = sqrt(dx*dx+dy*dy);` |
| `dir = len>0.0 ? delta/len : vec2(1,0);` | `dirX/dirY` ternary, same |
| `normal = vec2(-dir.y, dir.x);` | `nx = -dirY, ny = dirX;` |
| `px = mix(a,b,corner.x) + normal*half_width*corner.y;` | `px = ax+(bx-ax)*c.x+nx*halfWidth*c.y; py = ay+(by-ay)*c.x+ny*halfWidth*c.y;` (`mix(a,b,t) == a+(b-a)*t`, expanded per-component since Dart uses floats not `vec2`) |

### Branch: `kind < 1.5` (join)

| GLSL | Dart |
|---|---|
| `v/prev/next = to_pixels(p0/p1/p2);` | `vx,vy / pxp,pyp / nxp,nyp` |
| `in_delta = v-prev; out_delta = next-v;` | `inX,inY / outX,outY`, same |
| `in_len/out_len = length(...);` | `inLen/outLen = sqrt(...)` |
| `d0 = in_len>0.0 ? in_delta/in_len : vec2(1,0);` | `d0x/d0y`, same |
| `d1 = out_len>0.0 ? out_delta/out_len : d0;` | `d1x/d1y`, same |
| `cross_z = d0.x*d1.y - d0.y*d1.x;` | `crossZ`, same |
| `if (cross_z==0.0 \|\| in_len==0.0 \|\| out_len==0.0) px = v;` | same three-way `\|\|`, `px=vx; py=vy;` — see the divergence note below, transcribed verbatim per the brief's finding #1 |
| `else { s = cross_z>0.0 ? -half_width : half_width; ... }` | same |
| `n0 = vec2(-d0.y,d0.x)*s; n1 = vec2(-d1.y,d1.x)*s;` | `n0x/n0y`, `n1x/n1y`, same |
| `a = v+n0; b = v+n1;` | `ax,ay / bx,by`, same |
| `vec2 m = a;` | `mx=ax, my=ay;` |
| `if (dot(d0,d1) >= kMinMiterCosine) { ... }` | `if (d0x*d1x+d0y*d1y >= kExpanderMinMiterCosine)` |
| `sum = n0+n1; sum_len = length(sum);` | `sumX,sumY / sumLen`, same |
| `if (sum_len>0.0 && half_width>0.0) { ... }` | same |
| `mu = sum/sum_len;` | `muX,muY`, same |
| `cos_half = dot(mu,n0)/half_width;` | `cosHalf`, same |
| `if (cos_half>0.0) { m = v+mu*(half_width/cos_half); }` | `if (cosHalf>0) { reach=halfWidth/cosHalf; mx=vx+muX*reach; my=vy+muY*reach; }` |
| `px = w.x*v + w.y*a + w.z*b + w.w*m;` | `px = c.wv*vx+c.wa*ax+c.wb*bx+c.wm*mx; py = ...` — see the NaN-poisoning note below, transcribed as-is per the brief's finding #2 |

### Branch: `else` (point)

| GLSL | Dart |
|---|---|
| `vec2 c = to_pixels(p0);` | `cx = toX(x0,y0), cy = toY(x0,y0);` |
| `px = c + vec2((corner.x*2.0-1.0)*half_width, corner.y*half_width);` | `px = cx+(c.x*2.0-1.0)*halfWidth; py = cy+c.y*halfWidth;` (`c` here is the corner-table entry, distinct from the shader's local `c` which is the projected centre — same collision of the letter, different variable, kept because the shader also shadows `corner` this way) |

### The two mandated comments

Both findings are transcribed verbatim as required, each with the comment
the task specified, at the exact site:

- The `inLen == 0 \|\| outLen == 0` guard, in `instance_expander.dart` lines
  134-149: states that this file runs the formula in `double` against
  collection-space points re-projected through `toX`/`toY` (mirroring the
  shader's own re-projection), so it will not reproduce the float32 collapse
  the real GLSL can hit at extreme zoom-out — it takes the branch the sink
  and this Dart file agree on, while the GLSL alone can diverge.
- The blend `px = c.wv*vx + ...`, lines 180-194: states that `0.0*Inf ==
  NaN` in IEEE 754, so a non-finite `m` would poison all six vertices
  including triangle 0 (which never reads `m`), and that it is unreachable
  today because the `>= kExpanderMinMiterCosine` guard bounds `reach` to at
  most `4 * halfWidth` — bounding this is what keeps `m` finite, not the
  blend arithmetic itself — and that Task 9's differential cannot see this
  because both arms would produce the same NaN and read as agreement.

## M-B5 and M-B6 mutation transcripts

Backup taken before either mutation:

```
$ cp test/support/instance_expander.dart <scratchpad>/ie.bak
```

### M-B5: expand the quad at collection scale

Edit applied (`halfWidth` multiplied by `t.scaleMagnitude` at the point it
is read from the record):

```diff
-    final halfWidth = data[o + InstanceFieldOffset.halfWidth];
+    final halfWidth = data[o + InstanceFieldOffset.halfWidth] * t.scaleMagnitude;
```

```
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +6: half-width does not scale with the transform
00:00 +6 -1: half-width does not scale with the transform [E]
  Expected: a numeric value within <0.001> of <8>
    Actual: <40.0>
     Which:  differs by <32.0>
  the width did not

  test/gpu/instance_expander_test.dart 138:5  main.<fn>

00:00 +6 -1: Some tests failed.
```

Red on exactly the predicted test (`half-width does not scale with the
transform`), and no other test. `40.0` is `8 * 5` — the 5x scale from
`Transform2.scale(5,5)` leaking into the width, confirming the mutation did
what it claims.

Restoration:

```
$ cp <scratchpad>/ie.bak test/support/instance_expander.dart
$ diff <scratchpad>/ie.bak test/support/instance_expander.dart && echo RESTORED-IDENTICAL
RESTORED-IDENTICAL
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +7: All tests passed!
```

### M-B6: always miter

Edit applied (guard replaced with an always-true condition, keeping the
`if`/body structure intact so the "delete the guard" mutation is a single
localized change rather than a reflow of the block):

```diff
-          if (d0x * d1x + d0y * d1y >= kExpanderMinMiterCosine) {
+          if (true) {
```

```
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +3: a hairpin turn is bevelled: the tip triangle has zero area
00:00 +3 -1: a hairpin turn is bevelled: the tip triangle has zero area [E]
  Expected: a numeric value within <0.0001> of <100.0>
    Actual: <900.02001953125>
     Which:  differs by <800.02001953125>
  M collapses onto A, so (A, M, B) has no area

  test/gpu/instance_expander_test.dart 86:5  main.<fn>

00:00 +3 -1: Some tests failed.
```

Red on exactly the predicted test (`a hairpin turn is bevelled`), and no
other test.

Restoration:

```
$ cp <scratchpad>/ie.bak test/support/instance_expander.dart
$ diff <scratchpad>/ie.bak test/support/instance_expander.dart && echo RESTORED-IDENTICAL
RESTORED-IDENTICAL
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +7: All tests passed!
```

## Hand-derivation of the 90-degree miter test, independent of the brief

Instance: `v=(100,0)`, `prev=(0,0)`, `next=(100,100)`, `half=4`,
`Transform2.identity()` (so device-space coordinates equal the raw inputs).

```
in_delta  = v - prev = (100, 0)          in_len  = 100
out_delta = next - v = (0, 100)          out_len = 100
d0 = in_delta / in_len   = (1, 0)
d1 = out_delta / out_len = (0, 1)

cross_z = d0.x*d1.y - d0.y*d1.x = 1*1 - 0*0 = 1        (> 0 -> left turn)
s = -half = -4                                          (outer side flips)

n0 = (-d0.y, d0.x) * s = (-0, 1) * -4 = (0, -4)
n1 = (-d1.y, d1.x) * s = (-1, 0) * -4 = (4, 0)

a = v + n0 = (100, 0) + (0, -4) = (100, -4)
b = v + n1 = (100, 0) + (4, 0)  = (104, 0)

dot(d0, d1) = 1*0 + 0*1 = 0            (>= -0.875, so it miters)

sum = n0 + n1 = (4, -4)
sum_len = sqrt(4^2 + (-4)^2) = sqrt(32) = 4*sqrt(2)

mu = sum / sum_len = (4, -4) / (4*sqrt2) = (1/sqrt2, -1/sqrt2)

cos_half = dot(mu, n0) / half
         = (mu.x*n0.x + mu.y*n0.y) / 4
         = ((1/sqrt2)*0 + (-1/sqrt2)*(-4)) / 4
         = (4/sqrt2) / 4
         = 1/sqrt2                      (> 0)

reach = half / cos_half = 4 / (1/sqrt2) = 4*sqrt2 ~= 5.65685

m = v + mu*reach
  = (100, 0) + (1/sqrt2, -1/sqrt2) * 4*sqrt2
  = (100, 0) + (4, -4)
  = (104, -4)
```

`M` is vertex index 4 (the corner table's `join_weight` column w for row 4
is `(0,0,0,1)`), so `out.positions[8], out.positions[9]` should read
`(104, -4)`. The test asserts `closeTo(104, 1e-3)` and `closeTo(-4, 1e-3)`,
which the code satisfies. This matches the brief's stated numbers, but was
worked independently from the geometry (not copied) as required — this task
was told the brief's numbers have been wrong before elsewhere in this plan,
and this time they check out.

## Full gate output, verbatim, with exit codes

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:05 +469 ~1: .../tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:05 +470 ~1: All tests passed!
exit=0
```

(470 tests passed; the `~1` markers are Flutter's own skip-count notation
from pre-existing tests unrelated to this task, not failures — nothing in
this run failed.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
exit=0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 87 files (0 changed) in 0.11 seconds.
exit=0
```

Note: the first `dart format` run, before this fix, printed `Changed
test/gpu/instance_expander_test.dart` and exited `1` — the file I wrote by
hand did not match `dart format`'s line-wrapping for one long test name.
Ran `dart format test/gpu/instance_expander_test.dart` to fix it (only
whitespace changed — the reformatted test name split across two lines), then
reran the full `flutter test` suite and the format check above to confirm
both green after the reformat, per the "printing `(N changed)` IS a
failure" instruction.

`git status --porcelain` was checked after every write and again
immediately before the commit; `analysis_options.yaml` never appeared in it,
so nothing needed to be checked out.

## Defects found in the brief's sample code

Two, both concrete and both blocking (confirmed by actually running the
code, not by inspection):

**1. The `library;` directive was placed after the `import` statements.**
The brief's Step 3 sample opens with five `import` lines, then a doc
comment, then a bare `library;` directive. Dart requires the library
directive (including the unnamed, doc-comment-only form) to be the first
directive in the file — the analyzer rejected it outright:

```
The library directive must appear before all other directives.
Try moving the library directive before any other directives.
(library_directive_not_first)
```

Fixed by moving the doc comment and `library;` above the imports, which is
where the pattern is used correctly everywhere else in this codebase
(`instance_record.dart` and every other file with a library doc comment
follow this order). No behavioural change — pure reordering.

**2. The Step 1 test's colour assertion cannot pass against `Int32List`
colours with the alpha byte's high bit set, and the brief did not apply
the fix this codebase already uses everywhere else for exactly this
case.** `ExpandedTriangles.colors` is `Int32List` per the brief's own
interface (matching `TriangleRasterizer.observe(Float32List, Int32List)`
and `VerticesDrawSink._colors`, both established in earlier tasks). The
brief's test wrote:

```dart
expect(out.colors.every((c) => c == 0xFF112233), isTrue);
```

`0xFF112233` has its top bit set (alpha `0xFF`), so storing it into an
`Int32List` slot and reading it back yields a negative number
(`-15654349`,) via ordinary two's-complement sign extension — `Int32List`
is signed. Comparing that against the positive literal `0xFF112233` is
always `false`, independent of any bug in `expandInstances`, and I
confirmed the round-trip is otherwise exact:

```
$ dart run  # into a scratch script
data = Float32List(4) with 0xFF112233 packed via the same /255.0 scheme
_argbOf-style reconstruction -> 0xFF112233 == 0xFF112233  -> true (as ints)
colors[0] = 0xFF112233 (into an Int32List)  -> reads back -15654349
-15654349 == 0xFF112233  -> false
```

`vertices_draw_sink_test.dart` establishes the fix this codebase already
uses at every one of its own colour assertions against this same
`Int32List` convention: `.toUnsigned(32)` before comparing to the ARGB
literal (`sink.debugColors()[0].toUnsigned(32) == 0xFF000000`, etc., and
`TriangleRasterizer.observe` does the identical `colors[t].toUnsigned(32)`
internally). Fixed the test to match:

```dart
expect(out.colors.every((c) => c.toUnsigned(32) == 0xFF112233), isTrue);
```

with a comment recording why. This is a test-file fix, not an
`expandInstances` fix — the expander's colour packing was already correct
(verified independently before touching the test, per the round-trip check
above).

## Status

DONE. Commit `fffefc5`. 7/7 new tests pass; full package suite 470/470
green; `flutter analyze` clean; `dart format --set-exit-if-changed` clean
(after fixing one self-inflicted formatting miss, confirmed with a second
full gate run). No concerns carried forward — the one bounded, documented
divergence (the collinear/degenerate-join guard) and the one
currently-unreachable NaN-poisoning property are both exactly what the task
asked to be transcribed and commented, not defects to fix.

---

# Fix round 1

FIX_BASE: `fffefc5`. Fix commit: `f01ee5a` on `plan-b/joins-and-hairlines`.

Four items from the coordinator's review.

## Important 1: the doc citation was still half-true

`lib/src/gpu/instance_record.dart:63-69` named the right file
(`test/gpu/instance_expander_test.dart`) but kept the old claim that it
"compares its output against the reference sink" -- that test's only contact
with `VerticesDrawSink` is `expect(kExpanderMinMiterCosine,
VerticesDrawSink.kMinMiterCosine)`. Reworded to describe what actually gates
what, and to mark Task 9's differential as forward-looking and not yet
written:

```diff
 /// `cad_stroke.vert`'s attribute list is a third, independent copy — GLSL
 /// cannot read a Dart constant — and `test/support/instance_expander.dart` is
 /// a fourth. The expander is the one that is *gated*: it reads these same
-/// constants, and `test/gpu/instance_expander_test.dart` compares its
-/// output against the reference sink, so a drift between this file and the
-/// expander goes red in `flutter test`. A drift between either and the GLSL
-/// still needs a device run or a hand-check against `impellerc`'s reflection.
+/// constants, and `test/gpu/instance_expander_test.dart` pins the
+/// expander's own arithmetic today, so a drift between this file and the
+/// expander goes red in `flutter test`. `test/gpu/resident_pixel_differential_test.dart`
+/// (Task 9, not written yet) is the one that will compare the expander's
+/// output against the reference sink pixel for pixel. A drift between
+/// either and the GLSL still needs a device run or a hand-check against
+/// `impellerc`'s reflection.
```

## Important 2: the degenerate fixture, a new test, and M-B13/M-B14

Every existing fixture transform was `Transform2.identity()` (six tests) or
`Transform2.scale(5,5)` (one test) -- in both, `b`, `c`, `e` and `f` are
zero, so `toX`/`toY`'s use of `t.b`, `t.c`, `t.e`, `t.f` is untested by any
existing assertion. Added a stroke-branch test using
`Transform2(2, 0.5, -1, 3, 10, 10)` -- the same hand-built,
every-coefficient-non-zero transform `geometry_collector_test.dart` already
uses for its own residual tests -- with the derivation worked independently
below (not copied from the code) and reproduced in the test's own comment.

### Hand derivation

`t = Transform2(2, 0.5, -1, 3, 10, 10)`, so `a=2, b=0.5, c=-1, d=3, e=10,
f=10`.

```
toX(x,y) = t.a*x + t.c*y + t.e = 2x -  y + 10
toY(x,y) = t.b*x + t.d*y + t.f = 0.5x + 3y + 10
```

Instance: `writeStroke(x0:0, y0:0, x1:100, y1:0, halfWidth:4)`.

```
a = toPixels(0,0)   = (2*0 - 0 + 10, 0.5*0 + 0 + 10)     = (10, 10)
b = toPixels(100,0) = (2*100 - 0 + 10, 0.5*100 + 0 + 10) = (210, 60)

delta = b - a = (200, 50)
len = sqrt(200^2 + 50^2) = sqrt(40000 + 2500) = sqrt(42500)
    = sqrt(2500 * 17) = 50*sqrt(17)

dir = delta / len = (200/(50*sqrt17), 50/(50*sqrt17)) = (4/sqrt17, 1/sqrt17)
normal = (-dir.y, dir.x) = (-1/sqrt17, 4/sqrt17)

corner 0 = (0,-1): px = a + (b-a)*0 + normal*half*(-1) = a - normal*4
         = (10 - 4*(-1/sqrt17), 10 - 4*(4/sqrt17))
         = (10 + 4/sqrt17, 10 - 16/sqrt17)
corner 1 = (0, 1): px = a + normal*4
         = (10 - 4/sqrt17, 10 + 16/sqrt17)
corner 2 = (1,-1): px = a + (b-a)*1 - normal*4 = b - normal*4
         = (210 + 4/sqrt17, 60 - 16/sqrt17)
```

Numerically (`sqrt17 = 4.1231056256...`): `4/sqrt17 = 0.9701425001`,
`16/sqrt17 = 3.8805700006`. So corner 0 is `(10.9701425, 6.11943)`, corner 1
is `(9.0298575, 13.88057)`, corner 2 is `(210.9701425, 56.11943)`. This
matches the test's assertions (`out.positions[0..5]`) and the actual run's
output (`10.970142500145332` was the first `Expected:` value the mutation
runs below printed, confirming the derivation and the un-mutated code
agree).

### M-B13: transpose

```diff
-  double toX(double x, double y) => t.a * x + t.c * y + t.e;
-  double toY(double x, double y) => t.b * x + t.d * y + t.f;
+  double toX(double x, double y) => t.a * x + t.b * y + t.e;
+  double toY(double x, double y) => t.c * x + t.d * y + t.f;
```

```
$ cp test/support/instance_expander.dart <scratchpad>/ie2.bak
$ <apply the diff above>
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +6: half-width does not scale with the transform
00:00 +7: a stroke under a transform with every coefficient non-zero matches by hand
00:00 +7 -1: a stroke under a transform with every coefficient non-zero matches by hand [E]
  Expected: a numeric value within <0.001> of <10.970142500145332>
    Actual: <8.211145401000977>
     Which:  differs by <2.7589970991443558>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/instance_expander_test.dart 171:5          main.<fn>

00:00 +7 -1: cad_stroke.vert still carries the three renumber-prone constants
00:00 +8 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/instance_expander_test.dart: a stroke under a transform with every coefficient non-zero matches by hand
```

Red on exactly the new test, and only that one -- the GLSL-source test that
ran immediately after it (no GPU/transform involvement) stayed green.

Restoration:

```
$ cp <scratchpad>/ie2.bak test/support/instance_expander.dart
$ diff <scratchpad>/ie2.bak test/support/instance_expander.dart && echo RESTORED-IDENTICAL
RESTORED-IDENTICAL
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +9: All tests passed!
```

### M-B14: drop the translation

```diff
-  double toX(double x, double y) => t.a * x + t.c * y + t.e;
-  double toY(double x, double y) => t.b * x + t.d * y + t.f;
+  double toX(double x, double y) => t.a * x + t.c * y;
+  double toY(double x, double y) => t.b * x + t.d * y;
```

```
$ <apply the diff above>
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +7: a stroke under a transform with every coefficient non-zero matches by hand
00:00 +7 -1: a stroke under a transform with every coefficient non-zero matches by hand [E]
  Expected: a numeric value within <0.001> of <10.970142500145332>
    Actual: <0.9701424837112427>
     Which:  differs by <10.00000001643409>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/instance_expander_test.dart 171:5          main.<fn>

00:00 +7 -1: cad_stroke.vert still carries the three renumber-prone constants
00:00 +8 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/instance_expander_test.dart: a stroke under a transform with every coefficient non-zero matches by hand
```

Red on exactly the new test, differing by exactly `10.0` -- the dropped
`e=10` translation, confirming the mutation does what it claims and nothing
else is affected.

Restoration:

```
$ cp <scratchpad>/ie2.bak test/support/instance_expander.dart
$ diff <scratchpad>/ie2.bak test/support/instance_expander.dart && echo RESTORED-IDENTICAL
RESTORED-IDENTICAL
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +9: All tests passed!
```

## Minor 7 (promoted): a test that reads `cad_stroke.vert` itself

No test in the package previously read the `.vert` file, so a GLSL edit not
mirrored in the Dart transcription was invisible by construction. Added:

```dart
test('cad_stroke.vert still carries the three renumber-prone constants', () {
  // Partial net, not a substitute for Ruling B6's human diff: this pins
  // the three literals a shader edit is most likely to silently renumber
  // ... It reads the GLSL as text and checks for the constants, not the
  // arithmetic around them -- a change to the *formula* that keeps these
  // three literals untouched (for example, Task 8's own M-B5/M-B6
  // mutations) is invisible to this test and remains a human diff against
  // instance_expander.dart.
  final source = File('shaders/cad_stroke.vert').readAsStringSync();
  expect(RegExp(r'kMinMiterCosine\s*=\s*-0\.875').hasMatch(source), isTrue, ...);
  expect(RegExp(r'kind\s*<\s*0\.5').hasMatch(source), isTrue, ...);
  expect(RegExp(r'kind\s*<\s*1\.5').hasMatch(source), isTrue, ...);
});
```

The comment states explicitly that this is a partial net: it pins constants,
not arithmetic, and the arithmetic remains a human diff by Ruling B6. The
file reads via a package-root-relative path (`File('shaders/cad_stroke.vert')`),
which resolved correctly on the first run -- `flutter test`'s working
directory is the package root, confirmed by the test passing without any
path adjustment.

## Minor 3: the backwards NaN-comment clause

The old clause claimed a differential "would see both arms agree ... even
if this arithmetic were the thing that regressed." That is backwards: if
`m` alone went non-finite, the expander's triangle 0 (which reads `m` via
`c.wm`, even though its own weight for `V, A, B` should be zero for
triangle-0 vertices -- the *blend line itself* runs for every vertex,
poisoning it via `0.0 * NaN`) would go `NaN`, while the reference's
triangle 0 never touches `m` at all and would stay finite -- a differential
would *disagree*, i.e. catch it. Replaced with the narrower, correct claim:
the poisoning path is unreachable today because the guard bounds `reach`,
so no differential exercises it at all -- there being nothing to diverge on
is different from the two arms silently agreeing.

## Minor 4: the "same affine map" overclaim

`clip.xy * half_viewport` is viewport-centred and y-up; a direct
collection-to-device-pixel `Transform2` is not necessarily either. The old
doc asserted they were "the same affine map", which is not literally true.
Reworded to explain why the substitution is sound anyway: every branch is
built from differences of already-projected points, so a shared translation
cancels out outright; a y-flip reverses the cross product's sign and
therefore which side `crossZ > 0` calls "outer", but `n0` and `n1` are both
derived from the same flipped space, so the output is the mirror image of
the un-flipped picture -- which is the geometrically correct result for a
y-flipped space, not a broken one.

## Full gate output, verbatim, with exit codes

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
...
00:00 +0: the miter cosine matches the reference constant
00:00 +1: a horizontal stroke expands to the quad the reference builds
00:00 +2: a right-angle join is mitred, and the tip is at the outer corner
00:00 +3: a hairpin turn is bevelled: the tip triangle has zero area
00:00 +4: a collinear join collapses onto its vertex
00:00 +5: a point expands to a square of the stroke width
00:00 +6: half-width does not scale with the transform
00:00 +7: a stroke under a transform with every coefficient non-zero matches by hand
00:00 +8: cad_stroke.vert still carries the three renumber-prone constants
00:00 +9: All tests passed!
test exit=0
```

```
$ flutter test
...
00:05 +471 ~1: .../tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:05 +472 ~1: All tests passed!
test exit=0
```

(472 tests, up from 470 before this round -- the two new tests. The `~1`
markers are Flutter's pre-existing skip-count notation, unrelated to this
task; nothing failed.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
analyze exit=0
```

The first `dart format --set-exit-if-changed .` run in this round printed
`Changed test/gpu/instance_expander_test.dart` and exited `1` -- the new
tests' line-wrapping (the long test-name string and the `test(...)` call)
did not match `dart format`'s own wrapping. Ran `dart format
test/gpu/instance_expander_test.dart` (whitespace-only change: reflowed the
`test(...)` call and its name string), then reran the single test file, the
full suite, and the format check again to confirm all green after the
reformat:

```
$ dart format --output=none --set-exit-if-changed .
Formatted 87 files (0 changed) in 0.11 seconds.
format exit=0
```

`git status --porcelain` was checked before staging and again immediately
before the commit; `analysis_options.yaml` never appeared, so nothing
needed `git checkout --`.

## Status

DONE. Fix commit `f01ee5a` on top of FIX_BASE `fffefc5`. 9/9 tests in
`instance_expander_test.dart`; 472/472 full package suite; `flutter
analyze` clean; `dart format --set-exit-if-changed` clean. No new
concerns.
