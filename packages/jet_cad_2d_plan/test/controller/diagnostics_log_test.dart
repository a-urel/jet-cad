// The controller's DiagnosticsLog (spec P4 "Diagnostics"): removeWhere, the
// way a problem that went away leaves the bar (final review I3).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/controller/diagnostics_log.dart';

KitDiagnostic unreadable(String kit, String source) => KitDiagnostic(
    kitId: kit,
    subject: source,
    code: KitDiagnosticCode.libraryUnreadable,
    message: 'the library "$source" could not be read');

void main() {
  test(
      'DL-1 removeWhere drops the matching diagnostics, tells the listeners '
      'once, and forgets them: the same problem is reported again later', () {
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    final hook = KitDiagnostic(
        kitId: 'cafe',
        subject: 'cafe.table',
        code: KitDiagnosticCode.hookFailed,
        message: 'generate: boom');
    log
      ..add(unreadable('cafe', 'tables'))
      ..add(hook)
      ..add(unreadable('deco', 'lamps'));
    var told = 0;
    log.addListener(() => told++);
    log.removeWhere((d) => d.code == KitDiagnosticCode.libraryUnreadable);
    expect(log.value, [hook]);
    expect(told, 1);
    // Nothing matches: nothing changes, nobody is told.
    log.removeWhere((d) => d.code == KitDiagnosticCode.symbolDuplicate);
    expect(told, 1);
    // M-DL-1: removeWhere keeping the `_seen` keys: the log refuses the
    // same source's next failure as a repeat.
    expect(log.add(unreadable('cafe', 'tables')), isTrue);
    expect(log.value, [hook, unreadable('cafe', 'tables')]);
    expect(log.add(hook), isFalse, reason: 'a kept one still dedupes');
  });
}
