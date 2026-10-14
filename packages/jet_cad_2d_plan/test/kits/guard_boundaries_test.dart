// Spec P4 "The failure boundary", the remaining rows: grips (that object
// has none, a drag in flight refused), an attachment provider (taken as no
// attachment), a section builder (a small box in its place; a widget it
// returned that fails shows Flutter's ErrorWidget in its place only), and
// the log (once per kit, subject and code; never notifying mid-frame).
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart';
import 'package:jet_cad_2d_plan/src/kits/section_boundary.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class _Grips implements ObjectGripProvider {
  final Set<String> failing = {};
  int calls = 0;
  void _maybe(String m) {
    calls++;
    if (failing.contains(m)) throw StateError(m);
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    _maybe('gripsOf');
    return const [Grip(GripRole.stretch, 0, 7010, 3020)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    _maybe('drag');
    return TransformNodeCommand(
        group, Transform2.translation(world.x, world.y));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    _maybe('preview');
    return [(EntityKind.line, linePayload(Vector2.zero(), world))];
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    _maybe('movable');
    return true;
  }
}

final class _Edge implements AttachmentProvider {
  _Edge(this.fails);
  final bool fails;
  int calls = 0;
  @override
  String get kind => 'test-edge';
  @override
  Attachment? attach(AttachmentQuery query) {
    calls++;
    if (fails) throw StateError('edge');
    return null;
  }
}

AttachmentQuery query() => AttachmentQuery(
    footprint: Aabb2.fromPoints([Vector2(-300, -200), Vector2(300, 200)]),
    current: Transform2.translation(7010, 3020),
    pointer: Vector2(7100.5, 3050.25),
    capture: 120,
    edgeCapture: 60,
    mirrored: false,
    mayRotate: true,
    exclude: const {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'F-B1 a grip provider that throws: that object has no grips from then '
      'on, a drag is refused, it does not move; one diagnostic for its type',
      () {
    final d = DraftDocument.empty();
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    final inner = _Grips()..failing.add('gripsOf');
    final grips =
        GuardedGrips(inner, typeIdOf: (doc, group) => 'box.square', log: log);
    const group = Handle(4321);
    const grip = Grip(GripRole.stretch, 0, 7010, 3020);
    final world = Vector2(7100.5, 3100.25);
    // M-F-B1a: GuardedGrips.gripsOf calling the inner bare.
    expect(grips.gripsOf(d, group), isEmpty);
    final d1 = log.entries.value.single;
    expect((d1.kitId, d1.subject, d1.code),
        ('box', 'box.square', KitDiagnosticCode.hookFailed));
    inner.failing.clear();
    final calls = inner.calls;
    // M-F-B1b: the `_failed` set not consulted: the object gets grips again.
    expect(grips.gripsOf(d, group), isEmpty);
    expect(grips.drag(d, group, grip, world), isNull);
    expect(grips.preview(d, group, grip, world), isEmpty);
    expect(grips.movable(d, group), isFalse);
    expect(inner.calls, calls, reason: 'the failed object is not asked again');
    // Another object: the inner's; its own failures one at a time.
    const other = Handle(4322);
    expect(grips.gripsOf(d, other), hasLength(1));
    for (final m in ['drag', 'preview', 'movable']) {
      final g = GuardedGrips(_Grips()..failing.add(m),
          typeIdOf: (doc, group) => 'box.square', log: log);
      // M-F-B1c/d/e: `drag`, `preview`, `movable` each calling the inner
      // bare.
      expect(() => g.drag(d, other, grip, world), returnsNormally, reason: m);
      expect(() => g.preview(d, other, grip, world), returnsNormally,
          reason: m);
      expect(() => g.movable(d, other), returnsNormally, reason: m);
    }
  });

  test(
      'F-B2 an attachment provider that throws is taken as no attachment, '
      'with one diagnostic naming its kit and kind', () {
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    final healthy = _Edge(false);
    expect(guardAttachment('box', healthy, query(), log.add), isNull);
    expect(healthy.calls, 1);
    expect(log.entries.value, isEmpty);
    // M-F-B2: guardAttachment calling `provider.attach` bare.
    expect(guardAttachment('box', _Edge(true), query(), log.add), isNull);
    final d = log.entries.value.single;
    expect((d.kitId, d.subject, d.code),
        ('box', 'test-edge', KitDiagnosticCode.hookFailed));
  });

  testWidgets(
      'F-B3 a section builder that throws shows the small box in its place; '
      'a widget it returned that fails shows ErrorWidget there only; the '
      'diagnostic is published after the frame', (tester) async {
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    final phases = <SchedulerPhase>[];
    log.entries.addListener(
        () => phases.add(SchedulerBinding.instance.schedulerPhase));
    Widget panel(Widget? Function(BuildContext) builder) => MaterialApp(
            home: Scaffold(
                body: Column(children: [
          const Text('beside'),
          // Bounded: ErrorWidget fills what it is given.
          SizedBox(
              height: 120,
              child: KitSectionBoundary(
                  kitId: 'box',
                  typeId: 'box.square',
                  log: log,
                  builder: builder)),
        ])));

    // M-F-B3a: KitSectionBoundary.build calling `builder` bare.
    await tester.pumpWidget(panel((_) => throw StateError('section')));
    expect(find.byKey(const Key('kit-section-failed')), findsOneWidget);
    expect(find.text('This section could not be shown'), findsOneWidget);
    expect(find.text('beside'), findsOneWidget);
    expect(log.entries.value.single.subject, 'box.square');
    // M-F-B3b: `addAfterFrame` notifying at once (inside the build).
    expect(phases, isNot(contains(SchedulerPhase.persistentCallbacks)));

    await tester.pumpWidget(panel((_) => const _Exploding()));
    expect(tester.takeException(), isA<StateError>());
    expect(find.byType(ErrorWidget), findsOneWidget);
    expect(find.text('beside'), findsOneWidget,
        reason: 'the plan stays usable');
  });

  test(
      'F-B4 the log keeps one diagnostic per kit, subject and code, in '
      'arrival order', () {
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    KitDiagnostic d(String kit, String? subject, KitDiagnosticCode code) =>
        KitDiagnostic(kitId: kit, subject: subject, code: code, message: 'm');
    expect(
        log.add(d('box', 'box.square', KitDiagnosticCode.hookFailed)), isTrue);
    // M-F-B4: the dedupe key without `code`.
    expect(
        log.add(d('box', 'box.square', KitDiagnosticCode.componentUnreadable)),
        isTrue);
    expect(
        log.add(d('ring', 'box.square', KitDiagnosticCode.hookFailed)), isTrue);
    expect(log.add(d('box', null, KitDiagnosticCode.hookFailed)), isTrue);
    expect(
        log.add(d('box', 'box.square', KitDiagnosticCode.hookFailed)), isFalse);
    expect([
      for (final e in log.entries.value) (e.kitId, e.subject, e.code)
    ], [
      ('box', 'box.square', KitDiagnosticCode.hookFailed),
      ('box', 'box.square', KitDiagnosticCode.componentUnreadable),
      ('ring', 'box.square', KitDiagnosticCode.hookFailed),
      ('box', null, KitDiagnosticCode.hookFailed),
    ]);
  });
}

class _Exploding extends StatelessWidget {
  const _Exploding();
  @override
  Widget build(BuildContext context) => throw StateError('child build');
}
