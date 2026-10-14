// Ported from jet_cad_floor_plan/lib/src/planner_shell.dart:1702-1752
// (2a Task 17): the shell's _FrameSafeRelay, which the property panel
// listens to the selection through (HR1).
import 'package:flutter/foundation.dart' show ChangeNotifier, Listenable;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;

/// [_source]'s notifications, forwarded at once, except while a frame
/// builds ([SchedulerPhase.persistentCallbacks]): then one is held and
/// delivered after that frame, the pattern of
/// `FloorPlanController.toolChanged` (Task 4 review R-2). A pointer event,
/// a key and a host call arrive between frames, so they are forwarded at
/// once; [deliver] hands a held one on earlier, from its owner's update.
class FrameSafeRelay extends ChangeNotifier {
  FrameSafeRelay(this._source) {
    _source.addListener(_onSource);
  }

  final Listenable _source;

  /// A notification is held for after the frame.
  bool _held = false;

  /// The post-frame delivery is scheduled.
  bool _due = false;
  bool _disposed = false;

  void _onSource() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      _held = false;
      notifyListeners();
      return;
    }
    _held = true;
    if (_due) return;
    _due = true;
    binding.addPostFrameCallback((_) {
      _due = false;
      deliver();
    });
  }

  /// Delivers the held notification now, if any; only where every listener
  /// may be marked dirty (between frames, or in its owner's update).
  void deliver() {
    if (_disposed || !_held) return;
    _held = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _source.removeListener(_onSource);
    super.dispose();
  }
}
