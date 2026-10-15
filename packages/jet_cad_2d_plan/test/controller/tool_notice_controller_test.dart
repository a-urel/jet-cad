// Spec 3a C1.2: PlanController.toolNotice is the active tool's notice, for
// a host composing PlanCanvas and the panels itself; textOf puts a KitText
// into words, the host's first, in the current locale.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/mark_kit.dart';
import '../support/notice_kit.dart';
import '../support/throwing_kit.dart';

PlanController controller({KitNames words = KitNames.empty}) {
  final c = PlanController(kits: [markKit(), noteKit], words: words);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'TN-controller the active tool\'s notice: set, followed, cleared when '
      'another tool is armed, read again when it comes back, gone with a '
      'new plan (M-TN-active, M-TN-copy)', () {
    final c = controller();
    expect(c.toolNotice.value, isNull);
    var heard = 0;
    c.toolNotice.addListener(() => heard++);
    expect(c.selectTool(noteToolId), isTrue);
    final note = c.toolFor(noteToolId)! as NoteTool;
    // M-TN-copy: the wrapper's listener never added.
    note.said.value = busy('Mark 1');
    expect(c.toolNotice.value, busy('Mark 1'));
    expect(heard, 1);
    note.said.value = busy('Mark 2');
    expect(c.toolNotice.value, busy('Mark 2'));
    // M-TN-active: `_onTools` does not rebind.
    expect(c.selectTool('plan.select'), isTrue);
    expect(c.toolNotice.value, isNull);
    note.said.value = busy('Mark 3');
    expect(c.toolNotice.value, isNull, reason: 'not the active tool');
    expect(c.selectTool(noteToolId), isTrue);
    expect(c.toolNotice.value, busy('Mark 3'));
    c.newPlan();
    expect(c.toolNotice.value, isNull);
    expect(c.activeTool.value, 'plan.select');
  });

  test(
      'TN-textOf the host\'s word first, then the kit\'s, in the current '
      'locale, its placeholders filled; an id no one words is itself '
      '(M-TN-textOf-host, M-TN-textOf-locale)', () {
    final c = controller(
        words: const KitNames({
      'tr': {'text:note.busy': 'İşaretli: {name}'},
      'de': {'text:acme.hint': 'Hinweis {n}'},
    }));
    expect(c.textOf(busy('Mark 1')), 'Already marked: Mark 1');
    c.reportLocale(const Locale('tr'));
    // M-TN-textOf-host: the kit's own names only ('Zaten işaretli: Mark 1').
    expect(c.textOf(busy('Mark 1')), 'İşaretli: Mark 1');
    c.reportLocale(const Locale('de'));
    // M-TN-textOf-locale: English always.
    expect(c.textOf(const KitText('text:acme.hint', {'n': 4})), 'Hinweis 4');
    expect(c.textOf(busy('Mark 1')), 'Already marked: Mark 1',
        reason: 'no German: English');
    expect(
        c.textOf(const KitText('text:acme.none', {'n': 4})), 'text:acme.none');
    expect(c.textOf(const KitText('text:note.busy')), 'Already marked: {name}');
  });

  testWidgets(
      'TN-boundary a boom tool whose notice getter throws, armed: no notice, '
      'one diagnostic, the plan goes on (M-TN-guard-getter)', (tester) async {
    final boom = ThrowingKit(failing: ['notice']);
    final c = PlanController(kits: [boom.kit]);
    addTearDown(c.dispose);
    expect(c.selectTool('boom.tool'), isTrue);
    expect(c.toolNotice.value, isNull);
    await tester.pump();
    expect([
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.hookFailed) d.subject
    ], [
      'boom.tool'
    ]);
    expect(c.selectTool('plan.select'), isTrue);
  });
}
