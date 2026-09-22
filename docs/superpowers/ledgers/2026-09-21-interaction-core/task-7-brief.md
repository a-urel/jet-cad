### Task 7: `selection_style.dart` and `OutlineCache`

**Files:**
- Modify: `lib/src/selection_style.dart` (the rest of the constants)
- Create: `lib/src/outline_cache.dart`
- Test: `test/outline_cache_test.dart`

**Read the review note's B2 first.** The path is built in **rebased**
space; the world geometry is kept as `Float64List`s.

**Interfaces:**

```dart
const Color kSelectionColor = Color(0xFF1E6FE8);
const Color kHoverColor = Color(0x991E6FE8);
const Color kWindowBandColor = Color(0xFF1E6FE8);
const Color kCrossingBandColor = Color(0xFF2E9E5B);
const int kBandFillAlpha = 0x22;
const double kSelectionStrokePixels = 2.0;
const double kHoverStrokePixels = 1.5;

class OutlineCache {
  OutlineCache(this.document, this.selection);   // listens to both selection and document.changes
  /// Rebuilds the rebased paths if [origin] differs from the tag; returns
  /// the path for [key] or null.
  Path? pathFor(SelectionKey key, Vector2 origin);
  Vector2 get origin;                          // the current tag
  @visibleForTesting Float64List? debugWorldSegmentsOf(SelectionKey key);
  void dispose();
}
```

The world record per key: a `List<_Outline>` where `_Outline` is one of
`_Segments(Float64List coords)` (polyline chain, `moveTo` first, `lineTo`
rest), `_Arc(cx, cy, r, start, sweep)` (a circle is `sweep = 2π`) — all in
**world** doubles. Building: `SelectionKey.target` → a leaf (its payload
through `transformOfLeaf`-composed world transform: use
`document.tree.accumulatedTransform(owner)` for a group owner, identity for
the root), a group (every owned leaf recursively, each through its owner's
accumulated transform), an instance (walk `definition.children` and
`leavesByOwner()[definition]` with `node.transform` composed, recursing into
nested instances and groups; the same every-leaf enumeration Task 6's
cascade uses, but through transforms). Circles and arcs under a non-uniform
transform: emit the transformed centre with `radius × scaleMagnitude` and
the world start angle from the transformed start point, sweep sign flipped
under a negative determinant — the pick's rule. Text: four corners via
`textBoxOf` and its `local` transform.

`pathFor`: if `origin != _origin`, for every key rebuild `Path()`: for
segments, `moveTo(x0 - ox, y0 - oy)` then `lineTo`; for arcs,
`addArc(Rect.fromCircle(center: Offset(cx - ox, cy - oy), radius: r),
start, sweep)`. Note `addArc` sweeps in **screen** angle sense under the
y-flip; the painter applies the world→screen transform to the whole path, so
the world angles are right here — the y-flip is in the matrix.

- [ ] **Step 1: Failing tests**

1. **M-02v** — `'the path is built in rebased space'`: a line from
   `(kDefaultOriginX + 10, 20)` to `(kDefaultOriginX + 110, 20)`; select;
   `origin = rebaseOriginFor(visibleWorld)` for a camera fitted around it;
   `pathFor(key, origin).getBounds()` has `left == 10 + (kDefaultOriginX -
   origin.x)` to 1e-6 — and, the discriminating half, `getBounds().left`
   is **not** within 0.25 of `kDefaultOriginX + 10` (a world-space path
   would put it there and float32 would round it).
2. `'the origin tag rebuilds once per change, not per call'`: a counter on
   rebuilds via `@visibleForTesting int debugRebuilds`; two `pathFor` calls
   with the same origin → 1; a new origin → 2.
3. **M-02w** — `'a DocChange inside a selected instance rebuilds the outline'`:
   select an instance; `SetEntityGeometryCommand` on a leaf in its
   definition; pump a microtask; `debugWorldSegmentsOf(key)` moved.
4. `'an instance outline composes the placement'`: instance at
   `kPlacement`; the segments equal `kPlacement.transformPoint` of the
   leaf's endpoints to 1e-9.
5. `'a grouped leaf inside a definition composes the group transform too'`.
6. `'a circle under a non-uniform instance scale is emitted with the geometric-mean radius'`.
7. `'keys dropped from the selection leave the cache'`.

- [ ] **Step 2: Implement, run, gate line, commit**

```sh
git add lib/src/selection_style.dart lib/src/outline_cache.dart test/outline_cache_test.dart
git commit -m "feat(overlay): the rebased outline cache and the selection style constants"
```

---

