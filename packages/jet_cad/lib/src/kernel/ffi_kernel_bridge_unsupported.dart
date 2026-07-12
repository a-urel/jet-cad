import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../document/entity.dart';
import 'kernel_bridge.dart';
import 'kernel_types.dart';

/// Stub for platforms without dart:ffi (web). Construction always throws.
///
/// Implements [KernelBridge] with the exact method surface of the real
/// dart:ffi-backed implementation. This is required for static analysis,
/// not just runtime correctness: `dart analyze` resolves a conditional
/// export's *default* branch only — it never evaluates `dart.library.ffi`
/// per target platform the way the compiler/VM does at build/run time — so
/// every call site that imports `FfiKernelBridge` is checked against this
/// stub's shape. Without matching members here, `flutter analyze` reports
/// spurious `undefined_method` errors on the real, working call sites.
class FfiKernelBridge implements KernelBridge {
  FfiKernelBridge(String libraryPath) {
    throw UnsupportedError('FfiKernelBridge requires dart:ffi');
  }

  factory FfiKernelBridge.auto() = FfiKernelBridge._throw;

  FfiKernelBridge._throw() : this('');

  static String? locateLibrary() => null;

  Never _unsupported() =>
      throw UnsupportedError('FfiKernelBridge requires dart:ffi');

  @override
  Future<SessionHandle> createSession(RenderTarget target) => _unsupported();

  @override
  Future<void> disposeSession(SessionHandle session) => _unsupported();

  @override
  Future<KernelVersionInfo> versionInfo() => _unsupported();

  @override
  Future<CreateResult> makeBox(SessionHandle session, Vec3 size) =>
      _unsupported();

  @override
  Future<CreateResult> extrude(
          SessionHandle session, FaceId face, double depth) =>
      _unsupported();

  @override
  Future<CreateResult> booleanOp(
          SessionHandle session, BodyId a, BodyId b, BoolOp op) =>
      _unsupported();

  @override
  Future<CreateResult> fillet(
          SessionHandle session, List<EdgeId> edges, double radius) =>
      _unsupported();

  @override
  Future<void> transform(
          SessionHandle session, List<BodyId> bodies, Matrix4 matrix) =>
      _unsupported();

  @override
  Future<List<CreateResult>> importStep(
          SessionHandle session, Uint8List bytes) =>
      _unsupported();

  @override
  Future<Uint8List> exportStep(SessionHandle session, List<BodyId> bodies) =>
      _unsupported();

  @override
  Future<KernelSnapshot> snapshotBodies(
          SessionHandle session, List<BodyId> bodies) =>
      _unsupported();

  @override
  Future<void> restoreBodies(SessionHandle session, KernelSnapshot snapshot) =>
      _unsupported();

  @override
  Future<void> deleteBodies(SessionHandle session, List<BodyId> bodies) =>
      _unsupported();

  @override
  Future<KernelSnapshot> saveSnapshot(SessionHandle session) => _unsupported();

  @override
  Future<void> restoreSession(SessionHandle session, KernelSnapshot snapshot) =>
      _unsupported();

  Future<Map<String, Object?>> debugExecute(
          SessionHandle session, Map<String, Object?> command) =>
      _unsupported();
}
