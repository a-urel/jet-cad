// The controller's diagnostics (spec 2a P4 "Diagnostics"): a listenable
// list of KitDiagnostic. The plan's own (a missing kit, a newer kit, a
// component that does not read, a failed rollback, an unsavable plan) are
// cleared when the plan is replaced; the kit set's stay. Task 11 adds the
// dedupe by (kit id, subject, code).
import 'package:flutter/foundation.dart';
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

  @override
  List<KitDiagnostic> get value => _value;

  void report(KitDiagnostic diagnostic) => reportAll([diagnostic]);

  void reportAll(Iterable<KitDiagnostic> diagnostics) {
    final added = diagnostics.toList();
    if (added.isEmpty) return;
    _value = List.unmodifiable([..._value, ...added]);
    notifyListeners();
  }

  /// Drops the [planScoped] diagnostics: the plan they spoke of is gone.
  void clearPlanScoped() {
    final kept = [
      for (final d in _value)
        if (!planScoped.contains(d.code)) d,
    ];
    if (kept.length == _value.length) return;
    _value = List.unmodifiable(kept);
    notifyListeners();
  }
}
