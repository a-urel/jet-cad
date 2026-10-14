// Spec P4 "Diagnostics": the controller's kit diagnostics, one per kit id,
// subject and code, in arrival order, as a listenable list. The plan's own
// (a missing kit, a newer kit, a component that does not read, a failed
// rollback, an unsavable plan) are cleared when the plan is replaced; the
// kit set's stay. Task 8 made the minimal log; Task 11 makes it the
// boundary's: deduplicated, and safe to add to from a build or a paint.
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final class DiagnosticsLog extends ChangeNotifier
    implements ValueListenable<List<KitDiagnostic>> {
  /// The codes that belong to one plan.
  static const Set<KitDiagnosticCode> planScoped = {
    KitDiagnosticCode.kitMissing,
    KitDiagnosticCode.kitNewer,
    KitDiagnosticCode.componentUnreadable,
    KitDiagnosticCode.rollbackFailed,
    KitDiagnosticCode.damagedUnsavable,
  };

  List<KitDiagnostic> _value = const [];
  final Set<(String, String?, KitDiagnosticCode)> _seen = {};
  List<KitDiagnostic>? _pending;
  bool _disposed = false;

  @override
  List<KitDiagnostic> get value => _value;

  /// The log itself, as the boundary's callers name it.
  ValueListenable<List<KitDiagnostic>> get entries => this;

  List<KitDiagnostic> get _current => _pending ?? _value;

  bool _isNew(KitDiagnostic d) => _seen.add((d.kitId, d.subject, d.code));

  void _publish(List<KitDiagnostic> next) {
    _pending = null;
    _value = List.unmodifiable(next);
    notifyListeners();
  }

  /// Adds [diagnostic] and tells the listeners now; false (and nothing
  /// changes) when its kit, subject and code are already in the log. Not
  /// for a build or a paint: use [addAfterFrame] there.
  bool add(KitDiagnostic diagnostic) {
    if (!_isNew(diagnostic)) return false;
    _publish([..._current, diagnostic]);
    return true;
  }

  /// Task 8's name for [add].
  void report(KitDiagnostic diagnostic) => add(diagnostic);

  /// Adds each new one of [diagnostics], then tells the listeners once.
  void reportAll(Iterable<KitDiagnostic> diagnostics) {
    final next = [..._current];
    for (final d in diagnostics) {
      if (_isNew(d)) next.add(d);
    }
    if (next.length == _current.length) return;
    _publish(next);
  }

  /// Adds [diagnostic] at once (a second one of the same kit, subject and
  /// code is refused at once), and tells the listeners after the current
  /// frame: for a failure inside a build or a paint.
  bool addAfterFrame(KitDiagnostic diagnostic) {
    if (!_isNew(diagnostic)) return false;
    final first = _pending == null;
    _pending = List<KitDiagnostic>.unmodifiable([..._current, diagnostic]);
    if (first) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          final next = _pending;
          if (next != null && !_disposed) _publish(next);
        })
        ..ensureVisualUpdate();
    }
    return true;
  }

  /// Drops every diagnostic [test] holds for and forgets its kit, subject
  /// and code, so a later one of the same is reported again; tells the
  /// listeners when one was dropped. For a problem that went away (a
  /// symbol library read on a retry).
  void removeWhere(bool Function(KitDiagnostic diagnostic) test) {
    final current = _current;
    final kept = <KitDiagnostic>[];
    for (final d in current) {
      if (test(d)) {
        _seen.remove((d.kitId, d.subject, d.code));
      } else {
        kept.add(d);
      }
    }
    if (kept.length == current.length) return;
    _publish(kept);
  }

  /// Drops the [planScoped] diagnostics: the plan they spoke of is gone, so
  /// the next plan may report them again.
  void clearPlanScoped() {
    final current = _current;
    final kept = [
      for (final d in current)
        if (!planScoped.contains(d.code)) d,
    ];
    _seen.removeWhere((key) => planScoped.contains(key.$3));
    if (kept.length == current.length) return;
    _publish(kept);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
