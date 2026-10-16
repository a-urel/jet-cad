// The web's warning when a tab with unsaved work closes (spec 12a D11,
// decision 7): the `ExitGuard` the host arms while the document is dirty,
// and the selection of the platform's implementation by conditional
// export. `exit_guard_web.dart` (a `beforeunload` listener) where JS
// interop exists, `exit_guard_stub.dart` (nothing to do: macOS asks
// through the app's exit request) otherwise. Tests inject a fake.
//
// The web package is not imported here: this file is read on every
// platform. That import lives only in `exit_guard_web.dart` (plan 12a's
// grep).
export 'exit_guard_stub.dart'
    if (dart.library.js_interop) 'exit_guard_web.dart';

/// Asks the platform to warn before the app goes away with unsaved work
/// (spec 12a D11). The host arms it exactly while the document is dirty and
/// disposes it with itself.
abstract interface class ExitGuard {
  /// Whether closing now should warn.
  set armed(bool value);

  /// Disarms the guard for good.
  void dispose();
}
