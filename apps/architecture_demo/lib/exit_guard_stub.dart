// `ExitGuard` where there is no browser tab to guard (spec 12a D11):
// `exit_guard.dart` exports this by default. On macOS the host's
// `AppLifecycleListener` asks instead.
import 'exit_guard.dart';

/// The platform's [ExitGuard]: here, one that does nothing.
ExitGuard createExitGuard() => const _NoExitGuard();

class _NoExitGuard implements ExitGuard {
  const _NoExitGuard();

  @override
  set armed(bool value) {}

  @override
  void dispose() {}
}
