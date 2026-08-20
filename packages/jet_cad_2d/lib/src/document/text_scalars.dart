import '../store/geometry_store.dart';

/// Reads a scalar that a document written before Plan 3c does not carry.
///
/// A text entity written at schema 3 holds exactly one scalar — its height —
/// so `scalars[1..3]` is a `RangeError` on every such document. The payload is
/// **not** padded on load: padding would write geometry the file did not
/// contain and would make `save(load(save(d))) == save(d)` compare a padded
/// payload against an unpadded one.
double scalarOr(GeometryPayload payload, int index, double fallback) =>
    index < payload.scalars.length ? payload.scalars[index] : fallback;
