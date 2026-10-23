// The alignment-guide switch (alignment guides spec, "The setting").
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Whether the alignment guides show and snap: the user's choice
/// ([userOn], starts true) and the canvas's allowance ([allowed], starts
/// true) together. Every tool reads [on]; the bars' toggle writes
/// [userOn] through [toggle], which survives a mode switch.
///
/// A [PlanController] owns one and disposes it.
final class PlanGuideSettings extends ChangeNotifier {
  bool _userOn = true;
  bool _allowed = true;
  bool _noticeOwed = false;
  bool _disposed = false;

  /// Whether guides show and snap now: [allowed] and [userOn].
  bool get on => _allowed && _userOn;

  /// The user's choice, from the bars' toggle.
  bool get userOn => _userOn;

  /// The canvas's allowance, off when a host turns guides off.
  bool get allowed => _allowed;

  /// Flips [userOn] and notifies at once.
  void toggle() {
    _userOn = !_userOn;
    notifyListeners();
  }

  /// Written by the canvas in `initState` and `didUpdateWidget`, inside a
  /// build, where a listener may not be marked dirty: [allowed] changes now
  /// (the tools read it at once) and the notification follows after the
  /// frame, as `PlanController.snappingAllowed`'s does.
  @internal
  set allowed(bool value) {
    if (value == _allowed) return;
    _allowed = value;
    if (_noticeOwed) return;
    _noticeOwed = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _noticeOwed = false;
        if (!_disposed) notifyListeners();
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
