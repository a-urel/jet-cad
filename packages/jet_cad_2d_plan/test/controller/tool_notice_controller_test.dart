// Spec 3a C1.2: PlanController.toolNotice is the active tool's notice, for
// a host composing PlanCanvas and the panels itself; textOf puts a KitText
// into words, the host's first, in the current locale.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
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
  test(
      'TN-unbind the controller stops listening to a tool\'s notice when '
      'another speaking tool is armed and when the plan is replaced; a '
      'stale listener changes no value, so its count is the witness '
      '(M-TN-unbind-switch)', () {
    final made = <_Counted>[];
    addTearDown(() {
      for (final n in made) {
        n.dispose();
      }
    });
    final c = PlanController(kits: [markKit(), noteKit, _tellKit(made)]);
    addTearDown(c.dispose);
    var heard = 0;
    c.toolNotice.addListener(() => heard++);
    expect(c.selectTool(_tellToolId), isTrue);
    final tell = made.single;
    expect(tell.listened, isTrue, reason: 'premise: the controller listens');
    tell.value = busy('Tell 1');
    expect(c.toolNotice.value, busy('Tell 1'));
    expect(heard, 1);
    // Another tool that speaks: the switch must let go of the old one.
    expect(c.selectTool(noteToolId), isTrue);
    expect(c.toolNotice.value, isNull);
    expect(heard, 2);
    tell.value = busy('Tell 2');
    expect(c.toolNotice.value, isNull);
    expect(heard, 2, reason: 'a stale listener copies the current value');
    // M-TN-unbind-switch: the old tool's notice is still listened to.
    expect(tell.listened, isFalse);
    expect(c.selectTool(_tellToolId), isTrue);
    expect(c.toolNotice.value, busy('Tell 2'));
    expect(tell.listened, isTrue);
    c.newPlan();
    expect(c.toolNotice.value, isNull);
    expect(made, hasLength(2), reason: 'premise: one tool per document');
    expect(tell.listened, isFalse, reason: 'the old plan\'s tool');
    expect(made.last.listened, isFalse, reason: 'plan.select is armed');
  });

  test(
      'TN-unbind-dispose a disposed controller no longer listens to the '
      'active tool\'s notice (M-TN-unbind-dispose)', () {
    final made = <_Counted>[];
    addTearDown(() {
      for (final n in made) {
        n.dispose();
      }
    });
    final c = PlanController(kits: [markKit(), _tellKit(made)]);
    expect(c.selectTool(_tellToolId), isTrue);
    final tell = made.single;
    tell.value = busy('Tell 1');
    expect(c.toolNotice.value, busy('Tell 1'));
    expect(tell.listened, isTrue, reason: 'premise: the controller listens');
    c.dispose();
    // M-TN-unbind-dispose: the listener outlives the controller.
    expect(tell.listened, isFalse);
  });
}

const String _tellToolId = 'tell.mark';

/// A notice that tells whether anyone listens. The test owns it, so it
/// outlives the tool and its document.
final class _Counted extends ValueNotifier<KitText?> {
  _Counted() : super(null);

  bool get listened => hasListeners;
}

/// A speaking tool over a notice it does not own.
final class _Teller extends Tool implements ToolNotice {
  _Teller(this.said);

  final _Counted said;

  @override
  ValueListenable<KitText?> get notice => said;

  @override
  String get name => 'Tell';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}

/// Kit "tell": one speaking tool per document, each over a new notice
/// added to [made].
PlanKit _tellKit(List<_Counted> made) => PlanKit(
      id: 'tell',
      version: '1.0.0',
      tools: [
        PlanTool(
            id: _tellToolId,
            icon: Icons.campaign,
            letter: 'T',
            create: (_) {
              final said = _Counted();
              made.add(said);
              return _Teller(said);
            }),
      ],
      names: const KitNames({
        'en': {'tool:tell.mark': 'Tell'},
      }),
    );
