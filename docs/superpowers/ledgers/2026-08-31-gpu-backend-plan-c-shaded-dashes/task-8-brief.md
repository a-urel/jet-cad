### Task 8: The shaders, and the Dart that has to say the same thing

**Files:**
- Modify: `shaders/cad_stroke.vert`
- Modify: `shaders/cad_stroke.frag`
- Regenerate: `assets/shaders/cad.shaderbundle`
- Modify: `test/support/instance_expander.dart`
- Test: `test/gpu/instance_expander_test.dart`

**Interfaces:**
- Produces: `ExpandedTriangles` gaining `Float32List dashVaryings` (three
  floats per vertex: `t`, `fracStart`, `fracEnd`), and
  `expandInstances(..., {required double dashScale})`.

**Plan B's Ruling B6 governs this task.** `test/support/instance_expander.dart`
is `cad_stroke.vert` transcribed into Dart statement for statement, because
`flutter test` has no GPU. Any line added to the shader that is not added to
the expander is a line no test in this package can see. **Edit them in the same
commit, in the same order, with the same variable names.**

- [ ] **Step 1: Write the failing expander tests**

In `test/gpu/instance_expander_test.dart`:

```dart
  test('a solid instance signals solid with a negative fracStart', () {
    final e = expandInstances(solidStrokeBuffer, 1, Transform2.identity(),
        dashScale: 1.0);
    for (var v = 0; v < ResidentGeometry.cornerVertexCount; v++) {
      expect(e.dashVaryings[v * 3 + 1], lessThan(0.0));
    }
  });

  test('t runs from phase/period to (phase + length)/period across the quad', () {
    // A 30-unit segment, period 18, phase 3.
    final e = expandInstances(oneDashedStroke, 1, Transform2.identity(),
        dashScale: 1.0);
    final ts = <double>[/* the six vertices' t */];
    expect(ts.reduce(math.min), closeTo(3.0 / 18.0, 1e-6));
    expect(ts.reduce(math.max), closeTo((3.0 + 30.0) / 18.0, 1e-6));
  });

  test('t is measured in COLLECTION units, so the camera cancels', () {
    // The same instance expanded at two different device scales must give
    // the same t at every vertex. This is the design's central claim: the
    // reference's period grows with the camera and so does the distance, so
    // the ratio does not move. A t that changed here would mean the pattern
    // stretching or compressing under zoom -- the defect this plan exists
    // to remove, reintroduced in the shader.
    final a = expandInstances(oneDashedStroke, 1,
        Transform2.scale(1.0, 1.0), dashScale: 1.0);
    final b = expandInstances(oneDashedStroke, 1,
        Transform2.scale(4.0, 4.0), dashScale: 4.0);
    for (var i = 0; i < a.dashVaryings.length; i += 3) {
      expect(b.dashVaryings[i], closeTo(a.dashVaryings[i], 1e-6));
    }
  });

  test('a collapsed non-representative instance produces a degenerate '
      'triangle', () {
    // period 18 collection units at dashScale 0.1 -> 1.8 live logical px,
    // under kDashCollapsePx.
    final e = expandInstances(twoElementDashedStroke, 2, Transform2.identity(),
        dashScale: 0.1);
    // Instance 0 is the representative: real positions, solid varying.
    expect(e.dashVaryings[1], lessThan(0.0));
    expect(area(triangleOf(e, instance: 0, triangle: 0)), greaterThan(0.0));
    // Instance 1 collapses to a point.
    final second = ResidentGeometry.cornerVertexCount;
    expect(area(triangleOf(e, instance: 1, triangle: 0)), 0.0);
  });

  test('the collapse threshold is the dasher\'s own value', () {
    expect(kExpanderDashCollapsePx, kDashCollapsePx /* the engine's own top-level constant, 3.0 */,
        reason: 'GLSL cannot read a Dart constant, so cad_stroke.vert '
            'restates 3.0 as a literal; this assertion is what keeps the '
            'restatement honest, the same way kMinMiterCosine is kept');
  });

  test('a point instance is never dashed', () {
    final e = expandInstances(pointBuffer, 1, Transform2.identity(),
        dashScale: 1.0);
    expect(e.dashVaryings[1], lessThan(0.0));
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
```

- [ ] **Step 3: Rewrite `cad_stroke.vert`**

Header additions first — the file's existing header keeps its two paragraphs
and gains one:

```
// **Dashes are decided here and tested one line away.** The vertex stage
// turns the instance's `dash` quad into a single varying, `t`, which is the
// pattern-space coordinate at this vertex; the fragment stage keeps the
// fragment when `fract(t)` lands inside the element's own extent. `t` is
// measured in COLLECTION units, and the live camera does not appear in it at
// all: the reference's on-screen period is proportional to the camera scale
// (`draft_painter.dart`'s `_dashScale` folds in `toScreen.scaleMagnitude`)
// and so is the distance along the primitive, so the ratio is scale-free.
// The camera reaches this file for one purpose only -- deciding whether the
// pattern has collapsed to solid.
```

The body:

```glsl
uniform FrameInfo {
  mat4 mvp;            // collection space -> normalized device coordinates
  vec2 half_viewport;  // device pixels / 2
  float dash_scale;    // live LOGICAL pixels per collection unit
} frame_info;

in vec2 corner;
in vec4 join_weight;

// Per instance. `kind` and `half_width` share one attribute because GLSL
// ES 100 guarantees only eight vertex attributes and `dash` takes the eighth.
in vec2 kind_half;   // (kind, half width in device pixels)
in vec2 p0;
in vec2 p1;
in vec2 p2;
in vec4 color;
in vec4 dash;        // (period, phase, fracStart, fracEnd), collection units

out vec4 v_color;

// (t, fracStart, fracEnd). A NEGATIVE fracStart means "solid" and the
// fragment stage skips the test entirely -- one sentinel rather than a
// second varying.
out vec3 v_dash;

const float kMinMiterCosine = -0.875;

// `kDashCollapsePx`, restated because GLSL cannot read a Dart
// constant; `instance_expander.dart` asserts the two agree.
const float kDashCollapsePx = 3.0;

vec2 to_pixels(vec2 p) {
  vec4 clip = frame_info.mvp * vec4(p, 0.0, 1.0);
  return clip.xy * frame_info.half_viewport;
}

void main() {
  float kind = kind_half.x;
  float half_width = kind_half.y;
  vec2 px;

  // Distance from the primitive's start to this vertex, in COLLECTION units.
  float along = 0.0;

  if (kind < 0.5) {
    // ... the existing stroke branch, unchanged ...
    px = mix(a, b, corner.x) + normal * half_width * corner.y;
    // Collection units, taken from the attributes rather than from `a` and
    // `b`: `to_pixels` has already applied the live camera to those, and the
    // camera must not appear in `t`.
    along = corner.x * length(p1 - p0);

  } else if (kind < 1.5) {
    // ... the existing join branch, unchanged ...
    // `along` stays 0: every vertex of a join wedge sits at the corner, so
    // the whole wedge is tested at the phase stored for that corner.

  } else {
    // ... the existing point branch, unchanged. A point is never dashed.
  }

  gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
  v_color = color;

  // The dash decision. `dash.x` is signed: zero is solid, and a negative
  // value marks the one instance per primitive that draws solid when the
  // pattern collapses.
  v_dash = vec3(0.0, -1.0, 0.0);
  float period = abs(dash.x);
  if (period > 0.0) {
    if (period * frame_info.dash_scale < kDashCollapsePx) {
      // Collapsed. The reference stops dashing and draws the whole primitive
      // (`draft_painter.dart:629-631` takes `dashPolyline`'s false return and
      // calls `polyline` with the untouched points), so the representative
      // keeps its solid `v_dash` and every sibling collapses to a point.
      if (dash.x > 0.0) {
        gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
      }
    } else {
      v_dash = vec3((dash.y + along) / period, dash.z, dash.w);
    }
  }
}
```

- [ ] **Step 4: Rewrite `cad_stroke.frag`**

Keep the whole existing comment — it is a record of two corrections — and add
the test:

```glsl
in vec4 v_color;
in vec3 v_dash;   // (t, fracStart, fracEnd); a negative fracStart means solid
out vec4 frag_color;

void main() {
  // `discard` rather than a zero alpha: a transparent fragment still writes
  // depth on hardware that has it and still costs a blend. The spec's budget
  // discussion already names the cost of this line -- "the shaded-dash
  // `discard` defeats early-Z" -- so it is a known price, not a surprise.
  if (v_dash.y >= 0.0) {
    float f = fract(v_dash.x);
    if (f < v_dash.y || f >= v_dash.z) {
      discard;
    }
  }
  frag_color = v_color;
}
```

**Half-open, `[start, end)`, matching `dasher.dart`'s own `b > a` emission
test.** A closed interval would double-cover the boundary between two adjacent
drawn elements — which no standard pattern has, since drawn elements are
separated by gaps — but would also draw a zero-width element as one fragment
wide, where the reference draws nothing.

- [ ] **Step 5: Regenerate and verify the bundle**

```sh
cd packages/jet_cad_2d_flutter && sh tool/build_shaders.sh
shasum -a 256 assets/shaders/cad.shaderbundle
strings -a assets/shaders/cad.shaderbundle | grep -c "attribute "
```

Record the hash in the task report. **If `impellerc` fails with "Could not
complete reflection on generated shader", the cause is almost always an
attribute the optimizer folded away** — check that every one of the eight is
read on a path the compiler cannot prove dead.

- [ ] **Step 6: Mirror all of it in `instance_expander.dart`**

`expandInstances` gains `{required double dashScale}` and
`ExpandedTriangles` gains `dashVaryings`. The dash block goes **at the end of
the per-vertex loop, in the same order as the shader**, reading
`kExpanderDashCollapsePx` for the threshold. Split `kind_half` the same way:
read `kind` and `halfWidth` from `InstanceFieldOffset.kind` and
`InstanceFieldOffset.halfWidth` — which are now adjacent, which is the point.

Update the file's header to say the dash varying is transcribed too.

- [ ] **Step 7: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Expected: `test/gpu/resident_pixel_differential_test.dart` fails to compile —
`expandInstances` now needs `dashScale`. Pass `1.0` there for now; Task 9 gives
that file a real dashed arm.

- [ ] **Step 8: Commit**

```sh
git add packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/assets packages/jet_cad_2d_flutter/test
git commit -m "feat(shaders): the dash test, in GLSL and in the Dart that stands in for it"
```

---

