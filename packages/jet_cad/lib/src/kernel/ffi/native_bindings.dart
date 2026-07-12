import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import '../kernel_types.dart';

typedef _CreateSessionC = ffi.Uint64 Function();
typedef _DisposeSessionC = ffi.Void Function(ffi.Uint64);
typedef _ExecuteC = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Pointer<Utf8>);
typedef _VersionC = ffi.Pointer<Utf8> Function();
typedef _FreeC = ffi.Void Function(ffi.Pointer<Utf8>);

/// Raw synchronous bindings to libjet_cad_native. Blocking — only call
/// from a worker isolate (FfiKernelBridge wraps every call in Isolate.run).
class NativeBindings {
  NativeBindings(String libraryPath)
      : _lib = ffi.DynamicLibrary.open(libraryPath) {
    _createSession = _lib
        .lookupFunction<_CreateSessionC, int Function()>('jc_create_session');
    _disposeSession = _lib.lookupFunction<_DisposeSessionC, void Function(int)>(
        'jc_dispose_session');
    _execute = _lib.lookupFunction<_ExecuteC,
        ffi.Pointer<Utf8> Function(int, ffi.Pointer<Utf8>)>('jc_execute');
    _version = _lib
        .lookupFunction<_VersionC, ffi.Pointer<Utf8> Function()>('jc_version');
    _free = _lib
        .lookupFunction<_FreeC, void Function(ffi.Pointer<Utf8>)>('jc_free');
  }

  final ffi.DynamicLibrary _lib;
  late final int Function() _createSession;
  late final void Function(int) _disposeSession;
  late final ffi.Pointer<Utf8> Function(int, ffi.Pointer<Utf8>) _execute;
  late final ffi.Pointer<Utf8> Function() _version;
  late final void Function(ffi.Pointer<Utf8>) _free;

  int createSession() => _createSession();

  void disposeSession(int session) => _disposeSession(session);

  String _takeString(ffi.Pointer<Utf8> ptr) {
    // jc_execute/jc_version return nullptr on allocation failure (documented
    // in jet_cad_native.h); surface that as a typed exception instead of
    // crashing on toDartString(). Pointer.address == 0 rather than
    // `ptr == ffi.nullptr`: both work for a real Pointer<Utf8>, but address
    // comparison is the unambiguous, allocation-free check.
    if (ptr.address == 0) {
      throw const KernelException('native allocation failure');
    }
    try {
      return ptr.toDartString();
    } finally {
      _free(ptr);
    }
  }

  String execute(int session, String commandJson) {
    final cmd = commandJson.toNativeUtf8();
    try {
      return _takeString(_execute(session, cmd));
    } finally {
      malloc.free(cmd);
    }
  }

  String version() => _takeString(_version());
}
