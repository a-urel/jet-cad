### Task 5: The shader draws a fill, and the Dart transcription says the same thing

**Files:**
- Modify: `shaders/cad_stroke.vert`
- Regenerate: `assets/shaders/cad.shaderbundle`
- Modify: `test/support/instance_expander.dart`
- Modify: `lib/src/gpu/resident_geometry.dart` (documentation only)
- Test: `test/gpu/instance_expander_test.dart`

**Interfaces:**
- Consumes: `kKindFill`, `writeFill`.
- Produces: no signature change. `expandInstances` handles kind 3.

**Ruling B6 governs this task.** `instance_expander.dart` is `cad_stroke.vert`
transcribed statement for statement, because `flutter test` has no GPU. Edit
them in the same commit, in the same order, with the same variable names.

**No new attribute and no new record float** — the eight-attribute ES 100
ceiling is not approached by this task, and that is worth stating in the task
report because it is the single risk Plan C spent a ruling on.

- [ ] **Step 1: Write the failing expander tests**

```dart
  test('a fill expands to its three corners and one degenerate triangle', () {
    final data = Float32List(kFloatsPerInstance);
    writeFill(data, 0,
        x0: 10, y0: 10, x1: 40, y1: 12, x2: 25, y2: 38, argb: 0xFF2E7D32);
    final e = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);

    // Triangle 0 is (p0, p1, p2), in that vertex order.
    expect(e.positions[0], closeTo(10, 1e-6));
    expect(e.positions[1], closeTo(10, 1e-6));
    expect(e.positions[2], closeTo(40, 1e-6));
    expect(e.positions[3], closeTo(12, 1e-6));
    expect(e.positions[4], closeTo(25, 1e-6));
    expect(e.positions[5], closeTo(38, 1e-6));

    // Triangle 1 is (p1, p1, p2): zero area, so it rasterises nothing.
    final area = (e.positions[8] - e.positions[6]) *
            (e.positions[11] - e.positions[7]) -
        (e.positions[9] - e.positions[7]) * (e.positions[10] - e.positions[6]);
    expect(area, 0.0,
        reason: 'the second triangle of a fill instance must be degenerate');
  });

  test('a fill is not expanded by a half-width, at any camera', () {
    // The defect this catches: a fill routed through the stroke branch, or a
    // fill branch that read `half_width`. Either one grows the triangle by a
    // device-pixel margin, so its corners move away from the projected
    // points -- and the amount would change with the camera.
    final data = Float32List(kFloatsPerInstance);
    writeFill(data, 0,
        x0: 10, y0: 10, x1: 40, y1: 12, x2: 25, y2: 38, argb: 0xFF2E7D32);
    // Deliberately poison the half-width slot: a correct fill branch ignores
    // it. `writeFill` writes zero there, so without this the assertion could
    // not tell "ignored" from "zero".
    data[InstanceFieldOffset.halfWidth] = 9.0;

    final t = Transform2.translation(120, -35)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(1.7, 0.6));
    final e = expandInstances(data, 1, t, dashScale: 1.0);
    expect(e.positions[0], closeTo(t.a * 10 + t.c * 10 + t.e, 1e-4));
    expect(e.positions[1], closeTo(t.b * 10 + t.d * 10 + t.f, 1e-4));
  });

  test('a fill is solid: the dash test never runs on it', () {
    final data = Float32List(kFloatsPerInstance);
    writeFill(data, 0,
        x0: 10, y0: 10, x1: 40, y1: 12, x2: 25, y2: 38, argb: 0xFF2E7D32);
    final e = expandInstances(data, 1, Transform2.identity(), dashScale: 0.01);
    for (var v = 0; v < ResidentGeometry.cornerVertexCount; v++) {
      expect(e.dashVaryings[v * 3 + 1], lessThan(0.0),
          reason: 'a negative fracStart is the solid sentinel; a fill must '
              'carry it at every camera, collapse scale included');
    }
  });

  test('a point is still a point after the fill branch lands', () {
    // The regression this guards: adding `else { fill }` without narrowing
    // the point branch to `else if (kind < 2.5)` draws every fill as a
    // one-pixel square -- or, with the branches swapped, every point as a
    // triangle. Both directions are silent.
    final data = Float32List(kFloatsPerInstance);
    writePoint(data, 0, x: 20, y: 30, halfWidth: 4, argb: 0xFF102030);
    final e = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);
    final xs = <double>[for (var v = 0; v < 6; v++) e.positions[v * 2]];
    final ys = <double>[for (var v = 0; v < 6; v++) e.positions[v * 2 + 1]];
    expect(xs.reduce(math.max) - xs.reduce(math.min), closeTo(8, 1e-6));
    expect(ys.reduce(math.max) - ys.reduce(math.min), closeTo(8, 1e-6));
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
```
Expected: the first three fail — kind 3 currently falls into the point branch
and draws an 8-device-pixel square at `p0`.

- [ ] **Step 3: Add the shader branch**

In `cad_stroke.vert`, add to the header:

```
// **A fill is the one kind that expands nothing.** Its three corners are
// projected and used; `half_width` is zero and is not read. The six-vertex
// corner table is reused unchanged: `join_weight`'s V, A and B select the
// three corners and M is folded onto A, so the second triangle is
// degenerate and rasterises nothing (Plan D's Ruling D1).
```

Narrow the point branch and add the fill branch:

```glsl
  } else if (kind < 2.5) {
    // kKindPoint: a square of the stroke's width centred on p0. Both axes
    // are expanded here, in device pixels, so the dot stays square and stays
    // the same size at every zoom -- which is what the reference gets for
    // free by computing its `+/- half` in device space. A point is never
    // dashed.
    vec2 c = to_pixels(p0);
    px = c + vec2((corner.x * 2.0 - 1.0) * half_width, corner.y * half_width);

  } else {
    // kKindFill: one triangle of a pre-triangulated fill. Nothing is
    // expanded -- a fill has no width -- so `half_width` is not read here at
    // all. `join_weight` selects the corner: V -> p0, A -> p1, B -> p2, and
    // M folded onto p1, which makes the second triangle (A, M, B) =
    // (p1, p1, p2) degenerate.
    vec2 a0 = to_pixels(p0);
    vec2 a1 = to_pixels(p1);
    vec2 a2 = to_pixels(p2);
    px = join_weight.x * a0 + (join_weight.y + join_weight.w) * a1 +
         join_weight.z * a2;
    // `along` stays 0 and `dash` is all zeros on a fill, so the tail's
    // `period > 0.0` test fails and `v_dash` keeps its solid sentinel.
  }
```

- [ ] **Step 4: Regenerate and verify the bundle**

```sh
cd packages/jet_cad_2d_flutter && sh tool/build_shaders.sh
shasum -a 256 assets/shaders/cad.shaderbundle
strings -a assets/shaders/cad.shaderbundle | grep -c "attribute "
```

Record the hash and the attribute count in the task report. The count must be
**8**, unchanged — this task adds no attribute. If `impellerc` fails with
*"Could not complete reflection on generated shader"*, the cause is an
attribute the optimizer folded away; check that all eight are still read on a
path the compiler cannot prove dead.

- [ ] **Step 5: Mirror it in `instance_expander.dart`**

In the per-vertex loop, narrow the point branch to `else if (kind < 2.5)` and
append:

```dart
      } else {
        // kKindFill: one triangle of a pre-triangulated fill. Nothing is
        // expanded -- a fill has no width -- so `halfWidth` is not read here
        // at all. `join_weight` selects the corner: V -> p0, A -> p1,
        // B -> p2, and M folded onto p1, which makes the second triangle
        // (A, M, B) = (p1, p1, p2) degenerate.
        final a0x = toX(x0, y0), a0y = toY(x0, y0);
        final a1x = toX(x1, y1), a1y = toY(x1, y1);
        final a2x = toX(x2, y2), a2y = toY(x2, y2);
        px = c.wv * a0x + (c.wa + c.wm) * a1x + c.wb * a2x;
        py = c.wv * a0y + (c.wa + c.wm) * a1y + c.wb * a2y;
      }
```

Update the file's header to say the fill branch is transcribed too, and update
`resident_geometry.dart`'s `kCornerVertices` doc with the role mapping table
from Ruling D1 — that data is unchanged, but a reader of the join-only
explanation would not know a fourth kind reads it.

- [ ] **Step 6: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Expected: PASS, all of it.

- [ ] **Step 7: Commit**

```sh
git status --short
git add shaders/cad_stroke.vert assets/shaders/cad.shaderbundle test/support/instance_expander.dart lib/src/gpu/resident_geometry.dart test/gpu/instance_expander_test.dart
git commit -m "feat(gpu): the vertex shader draws a fill triangle"
```

---

