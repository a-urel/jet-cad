import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../document/entity.dart';
import '../kernel_bridge.dart';
import '../kernel_types.dart';
import 'native_bindings.dart';

/// Top-level so Isolate.run can invoke it with only sendable captures.
String _executeInIsolate((String, int, String) args) {
  final (libPath, session, cmd) = args;
  return NativeBindings(libPath).execute(session, cmd);
}

/// [KernelBridge] backed by the OCCT shim (libjet_cad_native).
///
/// Every command runs the blocking native call in a worker isolate and is
/// serialized per session (one command in flight — OCCT sessions are not
/// thread-safe). Error envelopes surface as [KernelException].
class FfiKernelBridge implements KernelBridge {
  FfiKernelBridge(this.libraryPath) : _bindings = NativeBindings(libraryPath);

  factory FfiKernelBridge.auto() {
    final path = locateLibrary();
    if (path == null) {
      throw StateError('jet_cad native library not found; build it with '
          'tool/build_native.sh or set JET_CAD_NATIVE_LIB');
    }
    return FfiKernelBridge(path);
  }

  /// Env override, then the dev build location. Null when absent.
  static String? locateLibrary() {
    final env = Platform.environment['JET_CAD_NATIVE_LIB'];
    if (env != null && File(env).existsSync()) return env;
    final ext = Platform.isMacOS ? 'dylib' : 'so';
    final dev = 'build/native/libjet_cad_native.$ext';
    if (File(dev).existsSync()) return File(dev).absolute.path;
    return null;
  }

  final String libraryPath;
  final NativeBindings _bindings;

  // Entries are removed once a session's dispose completes (see
  // disposeSession below), so this stays bounded by concurrently *live*
  // sessions, not lifetime session count.
  final Map<int, Future<void>> _queues = {};

  /// Sessions whose [disposeSession] has been invoked (possibly still
  /// awaiting in-flight commands). Commands enqueued after that point get
  /// a fast, typed rejection instead of racing the native dispose and
  /// surfacing a confusing kernel "unknown session" error.
  ///
  /// Unlike [_queues], entries here are never removed: this grows by one
  /// int per disposed session for the lifetime of the bridge instance.
  /// Bounded by session churn (a long-lived app creating/disposing many
  /// sessions over its lifetime), not by concurrently live sessions —
  /// acceptable for a per-process handle count, revisit if that changes.
  final Set<int> _disposing = {};

  Future<Map<String, Object?>> _run(
      SessionHandle session, Map<String, Object?> cmd) {
    if (_disposing.contains(session.value)) {
      throw StateError('session is disposed');
    }
    // Copied to a local: the closure below runs via Isolate.run, which
    // rejects any captured variable that (transitively) isn't sendable.
    // Capturing `this.libraryPath` directly would drag `this` — and with
    // it `_bindings`, which holds a DynamicLibrary — into the closure.
    final path = libraryPath;
    final prev = _queues[session.value] ?? Future<void>.value();
    final job = prev.then((_) async {
      final raw = await Isolate.run(
          () => _executeInIsolate((path, session.value, jsonEncode(cmd))));
      final envelope = (jsonDecode(raw) as Map).cast<String, Object?>();
      if (envelope['ok'] != true) {
        throw KernelException(envelope['error']?.toString() ?? 'unknown');
      }
      final result = envelope['result'];
      return result is Map
          ? result.cast<String, Object?>()
          : <String, Object?>{};
    });
    _queues[session.value] = job.then((_) {}, onError: (_) {});
    return job;
  }

  @override
  Future<SessionHandle> createSession(RenderTarget target) async =>
      SessionHandle(_bindings.createSession());

  @override
  Future<void> disposeSession(SessionHandle session) async {
    // Idempotent: a second call while (or after) the first is disposing
    // is a no-op. The synchronous add-before-await means any command
    // enqueued after this call starts is rejected by _run, while commands
    // already in the queue complete before the native dispose below.
    if (_disposing.contains(session.value)) return;
    _disposing.add(session.value);
    await (_queues[session.value] ?? Future<void>.value());
    _queues.remove(session.value);
    _bindings.disposeSession(session.value);
  }

  @override
  Future<KernelVersionInfo> versionInfo() async {
    final v = (jsonDecode(_bindings.version()) as Map).cast<String, Object?>();
    return KernelVersionInfo(
      kernelVersion: v['kernelVersion']! as String,
      occtVersion: v['occtVersion']! as String,
    );
  }

  Future<CreateResult> _create(
          SessionHandle s, Map<String, Object?> cmd) async =>
      CreateResult.fromJson(await _run(s, cmd));

  @override
  Future<CreateResult> makeBox(SessionHandle s, Vec3 size) =>
      _create(s, {'cmd': 'makeBox', 'size': size.toJson()});

  @override
  Future<CreateResult> extrude(SessionHandle s, FaceId face, double depth) =>
      _create(s, {'cmd': 'extrude', 'face': face.value, 'depth': depth});

  @override
  Future<CreateResult> booleanOp(
          SessionHandle s, BodyId a, BodyId b, BoolOp op) =>
      _create(s, {'cmd': 'boolean', 'a': a.value, 'b': b.value, 'op': op.name});

  @override
  Future<CreateResult> fillet(
          SessionHandle s, List<EdgeId> edges, double radius) =>
      _create(s, {
        'cmd': 'fillet',
        'edges': [for (final e in edges) e.value],
        'radius': radius,
      });

  // transform/restoreBodies/deleteBodies/restoreSession are marked `async`
  // (not a bare `=> _run(...)` pass-through) so the synchronous
  // "session is disposed" StateError that `_run` can throw before its first
  // await arrives to callers as a failed Future, matching every other
  // method on this bridge instead of surfacing as a synchronous throw.
  @override
  Future<void> transform(
          SessionHandle s, List<BodyId> bodies, Matrix4 matrix) async =>
      await _run(s, {
        'cmd': 'transform',
        'bodies': [for (final b in bodies) b.value],
        'matrix': matrix.storage.toList(),
      });

  @override
  Future<List<CreateResult>> importStep(
      SessionHandle s, Uint8List bytes) async {
    final result =
        await _run(s, {'cmd': 'importStep', 'dataB64': base64Encode(bytes)});
    return [
      for (final r in result['bodies']! as List)
        CreateResult.fromJson((r as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<Uint8List> exportStep(SessionHandle s, List<BodyId> bodies) async {
    final result = await _run(s, {
      'cmd': 'exportStep',
      'bodies': [for (final b in bodies) b.value],
    });
    return base64Decode(result['dataB64']! as String);
  }

  @override
  Future<KernelSnapshot> snapshotBodies(
      SessionHandle s, List<BodyId> bodies) async {
    final result = await _run(s, {
      'cmd': 'snapshotBodies',
      'bodies': [for (final b in bodies) b.value],
    });
    return KernelSnapshot(base64Decode(result['dataB64']! as String));
  }

  @override
  Future<void> restoreBodies(SessionHandle s, KernelSnapshot snapshot) async =>
      await _run(s, {
        'cmd': 'restoreBodies',
        'dataB64': base64Encode(snapshot.bytes),
      });

  @override
  Future<void> deleteBodies(SessionHandle s, List<BodyId> bodies) async =>
      await _run(s, {
        'cmd': 'deleteBodies',
        'bodies': [for (final b in bodies) b.value],
      });

  @override
  Future<KernelSnapshot> saveSnapshot(SessionHandle s) async {
    final result = await _run(s, {'cmd': 'saveSnapshot'});
    return KernelSnapshot(base64Decode(result['dataB64']! as String));
  }

  @override
  Future<void> restoreSession(SessionHandle s, KernelSnapshot snapshot) async =>
      await _run(s, {
        'cmd': 'restoreSession',
        'dataB64': base64Encode(snapshot.bytes),
      });
}
