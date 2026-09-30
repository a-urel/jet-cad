import 'package:floor_planner/exit_guard.dart';

/// An [ExitGuard] that records what the host told it (spec 12a D11,
/// Testing: "the fake `ExitGuard` is armed exactly while dirty").
class FakeExitGuard implements ExitGuard {
  /// Every value [armed] was set to, in order.
  final armings = <bool>[];

  /// Whether [dispose] was called.
  bool disposed = false;

  /// The last value set; false before any.
  bool get isArmed => armings.isNotEmpty && armings.last;

  @override
  set armed(bool value) {
    if (disposed) throw StateError('FakeExitGuard: armed after dispose');
    armings.add(value);
  }

  @override
  void dispose() => disposed = true;
}
