import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../document/entity.dart';
import 'kernel_types.dart';

/// Coarse, asynchronous command contract between the pure-Dart document
/// layer and a geometry kernel backend (FFI shim in v1, WASM later).
///
/// Ids cross this boundary; geometry never does. Implementations MUST make
/// [restoreBodies] and [restoreSession] id-preserving: a snapshot restores
/// entities under the exact ids it was taken with. Undo/redo depends on it.
///
/// This interface is intentionally not frozen. Viewer, pick, and selection
/// methods arrive in the viewport phase, and the per-operation methods may
/// evolve into a generic execute(KernelCommand) dispatcher before v1.0.
abstract interface class KernelBridge {
  Future<SessionHandle> createSession(RenderTarget target);
  Future<void> disposeSession(SessionHandle session);
  Future<KernelVersionInfo> versionInfo();

  Future<CreateResult> makeBox(SessionHandle session, Vec3 size);
  Future<CreateResult> extrude(
      SessionHandle session, FaceId face, double depth);
  Future<CreateResult> booleanOp(
      SessionHandle session, BodyId a, BodyId b, BoolOp op);
  Future<CreateResult> fillet(
      SessionHandle session, List<EdgeId> edges, double radius);
  Future<void> transform(
      SessionHandle session, List<BodyId> bodies, Matrix4 matrix);

  Future<List<CreateResult>> importStep(SessionHandle session, Uint8List bytes);
  Future<Uint8List> exportStep(SessionHandle session, List<BodyId> bodies);

  Future<Uint8List> snapshotBodies(SessionHandle session, List<BodyId> bodies);
  Future<void> restoreBodies(SessionHandle session, Uint8List snapshot);

  /// Idempotent: deleting an unknown id is a silent no-op (undo paths may
  /// delete already-gone bodies). Implementations must preserve this.
  Future<void> deleteBodies(SessionHandle session, List<BodyId> bodies);

  Future<KernelSnapshot> saveSnapshot(SessionHandle session);
  Future<void> restoreSession(SessionHandle session, KernelSnapshot snapshot);
}
