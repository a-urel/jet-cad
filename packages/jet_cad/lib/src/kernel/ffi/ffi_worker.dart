import 'dart:async';
import 'dart:isolate';

import '../kernel_types.dart';
import 'native_bindings.dart';

/// Request: (id, op, session, payload). Reply: (id, ok, value, errorType,
/// errorMessage). All fields are sendable primitives.
typedef _Request = (int, String, int, String?);
typedef _Reply = (int, bool, Object?, String?, String?);

/// One long-lived worker isolate owning a single dlopen'd [NativeBindings].
///
/// Every native call for a bridge runs on this isolate's thread, giving the
/// GL context a stable home thread (native code still re-makes-current per
/// command defensively). Replaces the per-command Isolate.run + dlopen from
/// Plan 2, which was too slow for render-rate command traffic.
class FfiWorker {
  FfiWorker._(this._isolate, this._commands, this._replies);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;
  bool _shutdown = false;

  static Future<FfiWorker> spawn(String libraryPath) async {
    final ready = ReceivePort();
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      (ready.sendPort, replies.sendPort, libraryPath),
      debugName: 'jet_cad_ffi_worker',
    );
    final commands = await ready.first as SendPort;
    ready.close();
    final worker = FfiWorker._(isolate, commands, replies);
    replies.listen(worker._onReply);
    return worker;
  }

  Future<Object?> request(String op, int session, String? payload) {
    if (_shutdown) {
      throw StateError('FfiKernelBridge is shut down');
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _commands.send((id, op, session, payload));
    return completer.future;
  }

  Future<void> shutdown() async {
    if (_shutdown) return;
    _shutdown = true;
    await Future.wait(
        _pending.values.map((c) => c.future.catchError((_) => null)));
    _commands.send(null);
    _replies.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }

  void _onReply(Object? message) {
    final (id, ok, value, errorType, errorMessage) = message as _Reply;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (ok) {
      completer.complete(value);
    } else if (errorType == 'KernelException') {
      completer.completeError(KernelException(errorMessage ?? 'kernel error'));
    } else {
      completer.completeError(
          StateError('native worker failure ($errorType): $errorMessage'));
    }
  }

  static void _workerMain((SendPort, SendPort, String) args) {
    final (readyPort, replyPort, libraryPath) = args;
    final bindings = NativeBindings(libraryPath);
    final commands = ReceivePort();
    readyPort.send(commands.sendPort);
    commands.listen((Object? message) {
      if (message == null) {
        commands.close();
        return;
      }
      final (id, op, session, payload) = message as _Request;
      try {
        final Object? value = switch (op) {
          'createSession' => bindings.createSession(),
          'disposeSession' => _void(() => bindings.disposeSession(session)),
          'execute' => bindings.execute(session, payload!),
          'version' => bindings.version(),
          _ => throw StateError('unknown worker op: $op'),
        };
        replyPort.send((id, true, value, null, null));
      } on KernelException catch (e) {
        replyPort.send((id, false, null, 'KernelException', e.message));
      } catch (e) {
        replyPort.send((id, false, null, e.runtimeType.toString(), '$e'));
      }
    });
  }

  static Object? _void(void Function() fn) {
    fn();
    return null;
  }
}
