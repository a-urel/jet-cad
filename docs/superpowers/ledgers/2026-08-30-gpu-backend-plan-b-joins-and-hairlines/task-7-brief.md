### Task 7: The shader learns three kinds

**Files:**
- Modify: `shaders/cad_stroke.vert`
- Modify: `shaders/cad_stroke.frag` (comment only)
- Regenerate: `assets/shaders/cad.shaderbundle`

**Interfaces:**
- Consumes: the record layout and the corner buffer (Task 2).
- Produces: nothing Dart-visible. **Task 8's expander is the transcription of
  this file and must be written from it, not beside it.**

**Nothing in `flutter test` reaches this file.** The gate is Task 8's expander,
Task 9's pixel differential and Task 11's device run. Write it carefully and
read it twice.

- [ ] **Step 1: Rewrite `cad_stroke.vert`**

```glsl
// Expands one instance into a screen-space primitive, branching on its kind.
//
// **Authored for OpenGL ES 100.** `impellerc` emits the `openglEs` stage the
// web loader reads and transpiles to ES 300, and ES 100 has no bitwise
// operators and no integer attributes -- hence a float kind tag and a vec4
// colour rather than a packed uint32, and a `<` dispatch rather than a
// switch.
//
// **Everything scale-dependent happens HERE, at the live camera.** The
// instance buffer holds a centreline, a corner or a centre in collection
// space plus a half-width in device pixels; expanding any of it at collection
// time would thicken the drawing with the camera. That is why joins are a
// kind and not collector geometry: a miter is a function of the live
// half-width.
//
// **`test/support/instance_expander.dart` is this file, in Dart.** It is what
// the suite can actually run. Any edit here that is not mirrored there is a
// divergence no test in this package can see -- change them together.

uniform FrameInfo {
  mat4 mvp;            // collection space -> normalized device coordinates
  vec2 half_viewport;  // device pixels / 2
} frame_info;

// Per vertex: two triangles, six corners.
// `corner.x` picks the endpoint (0 = p0, 1 = p1), `corner.y` picks the side
// (-1 or +1). `join_weight` selects one of (V, A, B, M) for the join branch,
// which needs six distinct roles where `corner` offers only four.
in vec2 corner;
in vec4 join_weight;

// Per instance.
in float kind;
in vec2 p0;
in vec2 p1;
in vec2 p2;
in float half_width;  // device pixels
in vec4 color;

out vec4 v_color;

// Impeller's conversion of Flutter's default miter limit of 4:
// `2 * (1 / limit)^2 - 1` (`stroke_path_geometry.cc:442`). A corner is
// mitred up to about a 151-degree turn and bevelled past it. Restated as a
// literal because GLSL cannot read `VerticesDrawSink.kMinMiterCosine`;
// `instance_expander.dart` asserts the two agree.
const float kMinMiterCosine = -0.875;

vec2 to_pixels(vec2 p) {
  vec4 clip = frame_info.mvp * vec4(p, 0.0, 1.0);
  return clip.xy * frame_info.half_viewport;
}

void main() {
  vec2 px;

  if (kind < 0.5) {
    // kKindStroke: two triangles around a centreline.
    vec2 a = to_pixels(p0);
    vec2 b = to_pixels(p1);
    vec2 delta = b - a;
    float len = length(delta);
    // Reachable, not merely defensive. The collector's guard runs on
    // `double` before the values are narrowed to float32, and two distinct
    // doubles can collapse to one float; separately, two distinct floats can
    // still project to the same device pixel at extreme zoom-out. A NaN here
    // is a whole frame of nothing.
    vec2 dir = len > 0.0 ? delta / len : vec2(1.0, 0.0);
    vec2 normal = vec2(-dir.y, dir.x);
    px = mix(a, b, corner.x) + normal * half_width * corner.y;

  } else if (kind < 1.5) {
    // kKindJoin: the notch at a corner, as the bevel (V, A, B) plus the
    // miter tip (A, M, B). Exactly `VerticesDrawSink._emitJoin`, in device
    // pixels, which is the space that function works in too.
    vec2 v = to_pixels(p0);
    vec2 prev = to_pixels(p1);
    vec2 next = to_pixels(p2);

    vec2 in_delta = v - prev;
    vec2 out_delta = next - v;
    float in_len = length(in_delta);
    float out_len = length(out_delta);
    vec2 d0 = in_len > 0.0 ? in_delta / in_len : vec2(1.0, 0.0);
    vec2 d1 = out_len > 0.0 ? out_delta / out_len : d0;

    float cross_z = d0.x * d1.y - d0.y * d1.x;

    if (cross_z == 0.0 || in_len == 0.0 || out_len == 0.0) {
      // Collinear: either straight through, where the quads already meet, or
      // a reversal, where both the miter and the bevel are degenerate. The
      // reference emits nothing; collapsing every corner onto the vertex
      // gives two zero-area triangles, which is the same picture.
      px = v;
    } else {
      // The outer side of the turn is the one away from it: a left turn
      // (cross > 0) opens a notch on the right.
      float s = cross_z > 0.0 ? -half_width : half_width;
      vec2 n0 = vec2(-d0.y, d0.x) * s;
      vec2 n1 = vec2(-d1.y, d1.x) * s;
      vec2 a = v + n0;
      vec2 b = v + n1;

      // Bevel by default: with M at A the tip triangle (A, M, B) has zero
      // area and disappears, which is what the reference's early return
      // achieves by not emitting it.
      vec2 m = a;
      if (dot(d0, d1) >= kMinMiterCosine) {
        vec2 sum = n0 + n1;
        float sum_len = length(sum);
        if (sum_len > 0.0 && half_width > 0.0) {
          vec2 mu = sum / sum_len;
          // `n0` has length `half_width`, so this is the cosine of half the
          // included angle.
          float cos_half = dot(mu, n0) / half_width;
          if (cos_half > 0.0) {
            m = v + mu * (half_width / cos_half);
          }
        }
      }

      px = join_weight.x * v + join_weight.y * a + join_weight.z * b +
           join_weight.w * m;
    }

  } else {
    // kKindPoint: a square of the stroke's width centred on p0. Both axes
    // are expanded here, in device pixels, so the dot stays square and stays
    // the same size at every zoom -- which is what the reference gets for
    // free by computing its `+/- half` in device space.
    vec2 c = to_pixels(p0);
    px = c + vec2((corner.x * 2.0 - 1.0) * half_width, corner.y * half_width);
  }

  gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
  v_color = color;
}
```

- [ ] **Step 2: Correct the fragment shader's comment**

Replace `cad_stroke.frag`'s header with:

```glsl
// Hard-edged, and it stays that way for now.
//
// The gate this backend is measured by is a pixel differential against
// `VerticesDrawSink`, which has no antialiasing path at all -- `flush()`
// submits `Vertices.raw` through `drawVertices` with per-vertex colours, and
// the word does not appear in the file. At one-to-two device-pixel stroke
// widths, edge pixels are most of the ink, so a coverage fade here would
// differ from the reference by most of a channel on most inked pixels and
// break spec criterion 1 outright. Antialiasing becomes possible when
// something other than the reference sink is the oracle.
//
// (An earlier version of this comment said antialiasing was Plan B's. It is
// not; Plan B's Ruling B3 records why.)
```

- [ ] **Step 3: Rebuild the bundle**

```bash
cd packages/jet_cad_2d_flutter && ./tool/build_shaders.sh
```

Expected: `wrote assets/shaders/cad.shaderbundle`, exit 0.

**If it fails with "Could not complete reflection on generated shader"**, an
attribute is declared but folded away by the optimizer. Every one of `corner`,
`join_weight`, `kind`, `p0`, `p1`, `p2`, `half_width` and `color` must be read
on a path the compiler cannot prove dead. Report which attribute you had to
touch and how.

- [ ] **Step 4: Verify the bundle carries an ES 100 stage**

The bundle is a flatbuffer; `strings` is not evidence, because the
`openglDesktop` stage uses `#version 120` with identical `attribute` syntax and
Plan A lost a review round to counting both. Decode it instead:

```bash
cd packages/jet_cad_2d_flutter
python3 - <<'PY'
import re
b = open('assets/shaders/cad.shaderbundle','rb').read()
print('size', len(b))
for tag in (b'#version 100', b'#version 120', b'#version 300 es'):
    print(tag.decode(), b.count(tag))
print('entry points:', sorted(set(re.findall(rb'Cad\w+', b))))
PY
sha256sum assets/shaders/cad.shaderbundle 2>/dev/null || shasum -a 256 assets/shaders/cad.shaderbundle
```

Expected: at least one `#version 100` occurrence, and both entry points
present. Paste the output and the new SHA-256 into the report; `STATUS.md` and
Task 11's results note both record it.

- [ ] **Step 5: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/assets
git commit -m "feat(gpu): the vertex shader builds join wedges and point squares"
```

---

