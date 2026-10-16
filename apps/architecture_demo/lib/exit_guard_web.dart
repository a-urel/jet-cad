// `ExitGuard` on the web (spec 12a D11, decision 7): while armed, a
// `beforeunload` listener asks the browser for its own generic warning
// before the tab closes or reloads; the browser offers no Save there. The
// only file of the app, with the other `*_web.dart` files, that imports the
// web package; `exit_guard.dart` exports it where JS interop exists. No
// widget test reaches it; `flutter analyze` reads it, `flutter build web`
// compiles it, and the human's look on the web covers it.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'exit_guard.dart';

/// The platform's [ExitGuard]: here, [WebExitGuard].
ExitGuard createExitGuard() => WebExitGuard();

/// Installs a `beforeunload` listener while armed and removes it when
/// disarmed or disposed.
class WebExitGuard implements ExitGuard {
  WebExitGuard();

  late final JSFunction _listener = _warn.toJS;
  bool _armed = false;

  /// `preventDefault()` is what current browsers read; a truthy
  /// `returnValue` is the legacy way (spec 12a D11).
  void _warn(web.BeforeUnloadEvent event) {
    event.preventDefault();
    event.returnValue = 'This plan has unsaved changes.';
  }

  @override
  set armed(bool value) {
    if (value == _armed) return;
    _armed = value;
    if (value) {
      web.window.addEventListener('beforeunload', _listener);
    } else {
      web.window.removeEventListener('beforeunload', _listener);
    }
  }

  @override
  void dispose() => armed = false;
}
