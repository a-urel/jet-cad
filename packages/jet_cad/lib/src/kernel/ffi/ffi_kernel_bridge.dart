import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../document/entity.dart';
import '../kernel_bridge.dart';
import '../kernel_types.dart';
import 'ffi_worker.dart';

/// [KernelBridge] backed by the OCCT shim (libjet_cad_native).
///
/// Every command runs on one long-lived worker isolate (dlopen'd once,
/// lazily spawned on first use) and is serialized per session (one command
/// in flight — OCCT sessions are not thread-safe). The worker isolate is
/// also the stable home thread for the upcoming GL context. Error envelopes
/// surface as [KernelException].
class FfiKernelBridge implements KernelBridge {
  FfiKernelBridge(this.libraryPath);

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

  /// In-flight (and, once completed, terminal) dispose futures keyed by
  /// session. Lets a second concurrent [disposeSession] call join the same
  /// dispose instead of racing it or silently no-op-ing before completion.
  final Map<int, Future<void>> _disposals = {};

  Future<FfiWorker>? _workerFuture;
  bool _shutdownRequested = false;

  /// The shutdown gate. MUST be called synchronously at admission time —
  /// when the public method is invoked — never from inside a queued
  /// continuation: work admitted before [shutdown] drains (shutdown awaits
  /// it); only work arriving after throws. A continuation re-consulting
  /// this after the flag flipped would reject already-admitted work.
  Future<FfiWorker> _worker() {
    if (_shutdownRequested) {
      throw StateError('FfiKernelBridge is shut down');
    }
    return _workerFuture ??= FfiWorker.spawn(libraryPath);
  }

  Future<Map<String, Object?>> _run(
      SessionHandle session, Map<String, Object?> cmd) {
    if (_disposing.contains(session.value)) {
      throw StateError('session is disposed');
    }
    final workerFuture = _worker(); // admission-time capture (see _worker)
    final prev = _queues[session.value] ?? Future<void>.value();
    final job = prev.then((_) async {
      final worker = await workerFuture;
      final raw = await worker.request(
          'execute', session.value, jsonEncode(cmd)) as String;
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

  /// Like [_run], but discards the result — for commands whose envelope
  /// carries no payload.
  Future<void> _runVoid(SessionHandle session, Map<String, Object?> cmd) =>
      _run(session, cmd);

  @override
  Future<SessionHandle> createSession(RenderTarget target) async {
    // _worker() must stay the first expression: an async body runs
    // synchronously until its first suspension, so this is an
    // admission-time shutdown check (see _worker).
    final worker = await _worker();
    final handle = await worker.request('createSession', 0, null) as int;
    final session = SessionHandle(handle);
    if (target is TextureTarget) {
      // Real dimensions arrive with the first resizeViewport (layout-time);
      // 32x32 placeholder keeps initViewer's size check honest.
      await _run(session, {
        'cmd': 'initViewer',
        'width': 32,
        'height': 32,
        'pixelRatio': 1.0,
      });
    }
    return session;
  }

  @override
  Future<void> disposeSession(SessionHandle session) {
    // Joining semantics (Plan 2 carry-over): a dispose in flight is THE
    // dispose — every caller awaits the same future; afterwards it is a
    // completed no-op.
    final existing = _disposals[session.value];
    if (existing != null) return existing;
    final future = _disposeImpl(session);
    _disposals[session.value] = future;
    return future;
  }

  Future<void> _disposeImpl(SessionHandle session) async {
    // Idempotent: the synchronous add-before-await means any command
    // enqueued after this call starts is rejected by _run, while commands
    // already in the queue complete before the native dispose below.
    _disposing.add(session.value);
    final workerFuture = _worker(); // admission-time capture (see _worker)
    await (_queues[session.value] ?? Future<void>.value())
        .catchError((_) => null);
    final worker = await workerFuture;
    await worker.request('disposeSession', session.value, null);
    _queues.remove(session.value);
  }

  @override
  Future<KernelVersionInfo> versionInfo() async {
    // _worker() first for the same admission-time reason as createSession.
    final worker = await _worker();
    final raw = await worker.request('version', 0, null) as String;
    final v = (jsonDecode(raw) as Map).cast<String, Object?>();
    return KernelVersionInfo(
      kernelVersion: v['kernelVersion']! as String,
      occtVersion: v['occtVersion']! as String,
    );
  }

  /// Shuts down the worker isolate. FFI-specific lifecycle (not part of
  /// [KernelBridge]): drains work admitted before this call — queued
  /// commands AND in-flight disposals — then shuts the worker down. Any
  /// command issued after this call throws [StateError]. Idempotent.
  Future<void> shutdown() async {
    if (_shutdownRequested) return;
    _shutdownRequested = true;
    final workerFuture = _workerFuture;
    if (workerFuture == null) return;
    final worker = await workerFuture;
    // Snapshot both maps: admission is synchronous, so everything admitted
    // before this call is already present; nothing new can be admitted
    // (_worker throws once _shutdownRequested is set). Disposals are
    // tracked separately from _queues and must drain too, or the native
    // session release racing worker.shutdown() would be dropped (leak).
    await Future.wait([
      for (final f in _queues.values) f.catchError((_) => null),
      for (final f in _disposals.values) f.catchError((_) => null),
    ]);
    await worker.shutdown();
  }

  Future<CreateResult> _create(
          SessionHandle s, Map<String, Object?> cmd) async =>
      CreateResult.fromJson(await _run(s, cmd));

  /// Runs a raw JSON command against [session].
  ///
  /// Dev-harness and test hook only: production callers use the typed
  /// [KernelBridge] methods. Queued per session like every other command.
  Future<Map<String, Object?>> debugExecute(
          SessionHandle session, Map<String, Object?> command) =>
      _run(session, command);

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

  @override
  Future<int> resizeViewport(SessionHandle session, int widthPx, int heightPx,
      double pixelRatio) async {
    final result = await _run(session, {
      'cmd': 'resizeViewport',
      'width': widthPx,
      'height': heightPx,
      'pixelRatio': pixelRatio,
    });
    return result['surfaceId']! as int;
  }

  @override
  Future<void> renderFrame(SessionHandle session) =>
      _runVoid(session, {'cmd': 'renderFrame'});

  @override
  Future<void> orbitStart(SessionHandle session, double xPx, double yPx) =>
      _runVoid(session, {'cmd': 'cameraOrbitStart', 'x': xPx, 'y': yPx});

  @override
  Future<void> orbit(SessionHandle session, double xPx, double yPx) =>
      _runVoid(session, {'cmd': 'cameraOrbit', 'x': xPx, 'y': yPx});

  @override
  Future<void> pan(SessionHandle session, double dxPx, double dyPx) =>
      _runVoid(session, {'cmd': 'cameraPan', 'dx': dxPx, 'dy': dyPx});

  @override
  Future<void> zoom(SessionHandle session, double factor) =>
      _runVoid(session, {'cmd': 'cameraZoom', 'factor': factor});

  @override
  Future<void> fitAll(SessionHandle session) =>
      _runVoid(session, {'cmd': 'cameraFit'});

  @override
  Future<PickResult?> pick(
      SessionHandle session, double xPx, double yPx, PickFilter filter) async {
    final result = await _run(session, {
      'cmd': 'pick',
      'x': xPx,
      'y': yPx,
      'filter': filter.name,
    });
    final hit = result['hit'];
    if (hit == null) return null;
    return PickResult.fromJson((hit as Map).cast<String, Object?>());
  }

  @override
  Future<void> setSelection(SessionHandle session, List<EntityId> ids) =>
      _runVoid(session, {
        'cmd': 'setSelection',
        'ids': [for (final id in ids) id.value],
      });
}
