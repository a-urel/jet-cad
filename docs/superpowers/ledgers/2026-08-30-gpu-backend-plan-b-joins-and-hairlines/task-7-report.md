# Task 7 report: the shader learns three kinds

## Files changed

- `packages/jet_cad_2d_flutter/shaders/cad_stroke.vert` — rewritten to branch
  on `kind` and build the join wedge and point square, per the brief's Step 1
  code verbatim.
- `packages/jet_cad_2d_flutter/shaders/cad_stroke.frag` — header comment
  replaced verbatim per the brief's Step 2; body (`v_color` → `frag_color`)
  untouched.
- `packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle` — regenerated.

Commit: `d7499db` — "feat(gpu): the vertex shader builds join wedges and point
squares"

## Step 3: `tool/build_shaders.sh` output

```
$ cd packages/jet_cad_2d_flutter && ./tool/build_shaders.sh
wrote assets/shaders/cad.shaderbundle
exit=0
```

No reflection failure on the first attempt — no attribute had to be touched
to keep it live. See "attribute read sites" below for why each of `corner`,
`join_weight`, `kind`, `p0`, `p1`, `p2`, `half_width` and `color` survives the
optimizer.

## Step 4: bundle verification (byte-level, not `strings`)

```
$ cd packages/jet_cad_2d_flutter && python3 - <<'PY'
import re
b = open('assets/shaders/cad.shaderbundle','rb').read()
print('size', len(b))
for tag in (b'#version 100', b'#version 120', b'#version 300 es'):
    print(tag.decode(), b.count(tag))
print('entry points:', sorted(set(re.findall(rb'Cad\w+', b))))
PY
size 30072
#version 100 2
#version 120 2
#version 300 es 0
entry points: [b'CadStrokeFragment', b'CadStrokeVertex']

$ sha256sum assets/shaders/cad.shaderbundle
0a7b07b44cdf2cffacb789a5aa8912fbbf6d084b2c980cd3c5a6c08d666cadcf  assets/shaders/cad.shaderbundle
```

Two `#version 100` occurrences (one per entry point: `CadStrokeVertex`,
`CadStrokeFragment`), confirming the `openglEs` stage compiled and is present
for both stages, not just the `openglDesktop` (`#version 120`) stage which is
also present (also two occurrences, one per entry point, as expected — both
stages are always emitted by `--runtime-stage-gles` alongside metal/vulkan).
Both entry point names present. New SHA-256:
`0a7b07b44cdf2cffacb789a5aa8912fbbf6d084b2c980cd3c5a6c08d666cadcf`.

## Attribute read sites (why reflection cannot fold any of them away)

`kind` is a per-instance attribute, not a compile-time constant, so `impellerc`
cannot statically prove any branch of the `if (kind < 0.5) / else if (kind <
1.5) / else` dispatch dead — every attribute read inside any one branch is
reachable at runtime.

- **`corner`** — read in the stroke branch (`mix(a, b, corner.x)`, `corner.y`
  as the side sign) and in the point branch (`corner.x`, `corner.y` build the
  square's four corners). Not read in the join branch, but reachable via the
  other two.
- **`join_weight`** — read only in the join branch, in the final blend
  `join_weight.x * v + join_weight.y * a + join_weight.z * b + join_weight.w
  * m`. Reachable whenever an instance carries `kKindJoin`.
- **`kind`** — read directly in both dispatch comparisons (`kind < 0.5`,
  `kind < 1.5`); always evaluated.
- **`p0`** — read in all three branches (`to_pixels(p0)` as the stroke's
  first endpoint, the join's vertex `v`, and the point's centre `c`).
- **`p1`** — read in the stroke branch (`to_pixels(p1)` as the second
  endpoint) and the join branch (`to_pixels(p1)` as `prev`).
- **`p2`** — read only in the join branch (`to_pixels(p2)` as `next`).
  Reachable whenever an instance carries `kKindJoin`.
- **`half_width`** — read in all three branches: stroke (`normal *
  half_width * corner.y`), join (`s = ... half_width`, the `cos_half`
  division, the `reach` multiply), point (both offset components).
- **`color`** — read unconditionally: `v_color = color;` runs on every
  invocation regardless of `kind`.

## Line-by-line check of the join branch against `_emitJoin`

Read `VerticesDrawSink._emitJoin`
(`packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart:405-448`) and
the brief's join branch side by side, term by term:

| `_emitJoin` (Dart, device pixels) | `cad_stroke.vert` join branch | Match |
|---|---|---|
| `cross = d0x*d1y - d0y*d1x` | `cross_z = d0.x*d1.y - d0.y*d1.x` | identical |
| `if (cross == 0) return;` (nothing emitted) | `if (cross_z == 0.0 \|\| in_len == 0.0 \|\| out_len == 0.0) px = v;` (both triangles zero-area) | same decision; the shader's extra `in_len == 0.0 \|\| out_len == 0.0` disjunct is a necessary addition, not a divergence — see below |
| `s = cross > 0 ? -half : half` | `s = cross_z > 0.0 ? -half_width : half_width` | identical |
| `n0x=-d0y*s, n0y=d0x*s`; `n1x=-d1y*s, n1y=d1x*s` | `n0 = vec2(-d0.y, d0.x) * s`; `n1 = vec2(-d1.y, d1.x) * s` | identical |
| `a = v + n0; b = v + n1` | `a = v + n0; b = v + n1` | identical |
| `_emitTriangle(v, a, b)` — bevel is `(V, A, B)` | triangle 0's `join_weight` row is `(1,0,0,0)/(0,1,0,0)/(0,0,1,0)` → `(V,A,B)` | identical role order |
| `if (d0·d1 < kMinMiterCosine) return;` (bevel only) | `if (dot(d0, d1) >= kMinMiterCosine) { ... }` else `m` stays `a` (bevel only) | identical, inverted as an early-return vs. a guarded block |
| `mx,my = n0+n1`; `if (mlen == 0) return;` | `sum = n0+n1`; `if (sum_len > 0.0 && half_width > 0.0) { ... }` | same guard; `&& half_width > 0.0` is a defensive addition (see below), inert whenever `half_width >= 0`, which every caller guarantees |
| `mx/=mlen; my/=mlen` (unit bisector) | `mu = sum / sum_len` | identical |
| `cosHalf = (mx*n0x+my*n0y)/half; if (cosHalf<=0) return;` | `cos_half = dot(mu, n0)/half_width; if (cos_half > 0.0) { ... }` | identical, same inversion pattern |
| `reach = half/cosHalf; m = v + mu*reach` | `m = v + mu * (half_width / cos_half)` | identical |
| `_emitTriangle(a, m, b)` — tip is `(A, M, B)` | triangle 1's `join_weight` row is `(0,1,0,0)/(0,0,0,1)/(0,0,1,0)` → `(A,M,B)` | identical role order |

Every arithmetic step, sign, and guard direction matches `_emitJoin` exactly.
I did not find a defect in this branch. Two apparent divergences, both
checked and found to be necessary rather than wrong:

1. **The `in_len == 0.0 \|\| out_len == 0.0` disjunct.** `_emitJoin` never
   receives a zero-length `d0`/`d1` because its caller (`_runTo`/`_endRun`)
   only calls it with directions from segments `_emitSegment` already
   rejected as zero-length upstream, in `double` precision, in collection
   space. The shader has no such upstream guarantee: `p0`/`p1`/`p2` are
   collection-space points that go through `to_pixels` (the `mvp` transform)
   independently, and — exactly as the stroke branch's own comment says for
   the identical situation — "two distinct doubles can collapse to one
   float; separately, two distinct floats can still project to the same
   device pixel at extreme zoom-out." Without this guard, `d0` or `d1`
   would take the arbitrary fallback direction `vec2(1.0, 0.0)`, from which a
   spurious nonzero `cross_z` and a bogus wedge could be constructed at a
   point where no real corner exists. This is the same class of defence the
   stroke branch already carries for the same reason, not a behavioural
   difference from `_emitJoin` for any input `_emitJoin` can actually be
   called with.
2. **The `&& half_width > 0.0` conjunct** before dividing by `half_width` in
   `cos_half`. `_emitJoin` has no equivalent check, but every caller passes a
   non-negative `half`; when `half_width == 0`, `n0` and `n1` are already
   `(0,0)`, so `sum_len` is already `0.0` and the branch is skipped by the
   `sum_len > 0.0` half of the same condition regardless. The added conjunct
   is redundant for every reachable input, not a change in behaviour.

I also checked the stroke and point branches against their references
(`_emitQuad`/`_emitSegment` for the stroke geometry, `point()`'s
`_emitSegment(px-half, py, px+half, py, half, ...)` for the square) and the
attribute/offset names in `cad_stroke.vert` against
`ResidentGeometry.kInstanceVertexLayout` and `kCornerVertices`
(`lib/src/gpu/resident_geometry.dart:70-173`): attribute names (`corner`,
`join_weight`, `kind`, `p0`, `p1`, `p2`, `half_width`, `color`), the
`join_weight` role assignment per vertex (`(V,A,B,M)` in that column order,
triangle 0 = `(V,A,B)`, triangle 1 = `(A,M,B)`), and `kMinMiterCosine =
-0.875` (`2 * (1/4)^2 - 1`) against `VerticesDrawSink.kMinMiterCosine`'s
definition all match exactly.

**No defect found in this task's sample GLSL.** Unlike Tasks 3–6, which each
found a real defect (missing `ResolvedStyle` named parameters, a missing
import, an `_endRun` seam ordering bug), Task 2's report also found none in
its own sample code blocks — this is not unprecedented for this plan.

## Gate output

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:05 +463 ~1: All tests passed!
exit=0
```

(`~1` is `test/rig/paint_microbench_test.dart` (suite), explicitly tagged
`rig` and skipped by design — "Skip: run explicitly: flutter test --tags rig
--run-skipped" — pre-existing and unrelated to this task.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
exit=0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 85 files (0 changed) in 0.12 seconds.
exit=0
```

`git status --short` before commit showed only the three intended files
(`assets/shaders/cad.shaderbundle`, `shaders/cad_stroke.frag`,
`shaders/cad_stroke.vert`) — no `analysis_options.yaml` appeared.

## Commit

`d7499db` — "feat(gpu): the vertex shader builds join wedges and point
squares"
