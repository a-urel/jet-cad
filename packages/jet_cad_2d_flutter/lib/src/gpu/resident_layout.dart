import 'instance_record.dart';

/// The resident backend's buffer layout that needs no GPU: the corner table
/// every instance is expanded over, and what a buffer of instance records
/// costs.
///
/// **Here, not on `ResidentGeometry`,** because `ResidentGeometry` lives in
/// `jet_cad_2d_gpu` with the GPU types it holds, while this data is read by
/// core as well: `ResidentCollection.byteLength` prices a collection with
/// [byteLengthFor], and the test expander (`test/support/instance_expander.dart`)
/// mirrors the vertex shader over [kCornerVertices]. `ResidentGeometry`
/// uploads this same table and binds it with a stride of [kFloatsPerCorner].
abstract final class ResidentLayout {
  /// The six per-vertex records: two triangles, not a triangle strip, because
  /// a strip cannot mix kinds and Plans C and D add kinds to this same buffer.
  ///
  /// **Six floats per vertex: `corner.xy` then `join_weight.xyzw`.**
  ///
  /// `corner` is the quad parameterisation Plan A shipped — `x` picks the
  /// endpoint (0 = p0, 1 = p1), `y` picks the side (-1 or +1) — and the
  /// stroke and point branches still read only it.
  ///
  /// `join_weight` exists because the join branch needs **six distinct
  /// vertex roles** and `corner` alone offers only four: `(1,-1)` and `(0,1)`
  /// each appear twice, since the two triangles share the quad's diagonal.
  /// A join's two triangles are the bevel `(V, A, B)` and the miter tip
  /// `(A, M, B)` — four distinct points across six vertices, and the
  /// duplicated corners need *different* roles in each triangle, so they
  /// cannot be told apart by `corner`. The weight vector selects one of
  /// `(V, A, B, M)` per vertex, and the shader reads the position as
  /// `w.x*V + w.y*A + w.z*B + w.w*M` — no float-equality test on an index,
  /// which ES 100 makes unpleasant.
  ///
  /// Triangle 0 is `(V, A, B)` and triangle 1 is `(A, M, B)`. Both wind
  /// **either way** depending on the turn direction, because `_emitJoin`
  /// flips the outer side with the sign of the cross product — which is why
  /// `GpuDrawBackend.render` pins `CullMode.none`.
  ///
  /// **A fill (Plan D's Ruling D1) reads this same table, with its own role
  /// mapping.** A fill has only three points, not a join's four, so `M` is
  /// folded onto `A` rather than computed:
  ///
  /// | role | join reads      | fill reads |
  /// |------|------------------|------------|
  /// | V    | the corner       | `p0`       |
  /// | A    | the incoming leg | `p1`       |
  /// | B    | the outgoing leg | `p2`       |
  /// | M    | the miter tip    | `p1` (== A)|
  ///
  /// Triangle 0 is therefore `(p0, p1, p2)` — the fill's real triangle — and
  /// triangle 1 is `(p1, p1, p2)` — zero area, so it rasterises nothing. A
  /// reader who has only seen the join-branch explanation above would not
  /// know this table is shared with a fourth kind; this paragraph is that
  /// pointer.
  ///
  /// **Not `@visibleForTesting` any more.** It was, while `create` was the
  /// only production reader and lived in the same library. Now
  /// `ResidentGeometry` (package `jet_cad_2d_gpu`) uploads it from another
  /// package: production data read across packages, not a test hook.
  static const List<double> kCornerVertices = <double>[
    // corner.x corner.y | join_weight V, A, B, M
    0, -1, /*  */ 1, 0, 0, 0, // triangle 0, vertex 0 -> V
    0, 1, /*   */ 0, 1, 0, 0, // triangle 0, vertex 1 -> A
    1, -1, /*  */ 0, 0, 1, 0, // triangle 0, vertex 2 -> B
    1, -1, /*  */ 0, 1, 0, 0, // triangle 1, vertex 0 -> A
    0, 1, /*   */ 0, 0, 0, 1, // triangle 1, vertex 1 -> M
    1, 1, /*   */ 0, 0, 1, 0, // triangle 1, vertex 2 -> B
  ];

  /// Floats per entry in the corner buffer: `corner` (2) + `join_weight` (4).
  static const int kFloatsPerCorner = 6;

  /// The number of per-vertex records in [kCornerVertices] — six today, two
  /// triangles' worth. Derived rather than restated: `GpuDrawBackend.render`
  /// reads this instead of a hardcoded `6` in its `pass.draw` call, and
  /// `test/support/instance_expander.dart` reads it for the same reason, so
  /// a kind Plans C or D add to this buffer moves the draw call and the
  /// test expander together instead of leaving either at a stale count.
  static int get cornerVertexCount =>
      kCornerVertices.length ~/ kFloatsPerCorner;

  /// Bytes a buffer of [instances] records occupies, plus [patchInstances]
  /// more records -- every patch sub-buffer's instances, summed, at the same
  /// per-record price as the main buffer's.
  static int byteLengthFor(int instances, {int patchInstances = 0}) =>
      (instances + patchInstances) * kFloatsPerInstance * 4;
}
