// Spec 2b S1 "The output": 2a's GuardedType wraps E5's `instances` as it
// wraps `generate` (guard.dart): a throw is a KitHookFailure naming the hook
// `instances`, the engine rolls the edit back and `probe` returns it; through
// the controller, the boundary probes the type, freezes and locks the
// failing object, and the other objects still regenerate (2a P4, E2). The
// square sits off the origin, turned (box_kit.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart' show GuardedType;

import '../support/box_kit.dart';

/// A document with a page and a system over the guarded square
/// (guarded_type_test.dart's harness, the disc left out).
({DraftDocument doc, ParametricSystem system}) harness(Switches sw) {
  final d = DraftDocument.empty();
  PageComponent.register(d.components);
  d.commands.execute(SetComponentCommand<PageComponent>(
      d.rootHandle, PageComponent(scaleDenominator: 50)));
  final catalog = ParametricCatalog()
    ..register<SquareParams>(SquareParams.id, SquareParams.fromJson,
        GuardedType<SquareParams>('box', SquareParams.id, SquareType(sw)));
  final system = ParametricSystem(d, catalog)..install();
  return (doc: d, system: system);
}

Matcher failedInstances() => isA<KitHookFailure>()
    .having((f) => f.kitId, 'kitId', 'box')
    .having((f) => f.typeId, 'typeId', SquareParams.id)
    .having((f) => f.hook, 'hook', 'instances')
    .having((f) => f.error, 'error',
        isA<HookBoom>().having((b) => b.hook, 'hook', 'instances'));

List<KitDiagnostic> diagnosticsOf(PlanController c, KitDiagnosticCode code) => [
      for (final d in c.diagnostics.value)
        if (d.code == code) d
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const poisoned = SquareParams(side: 1200, poisoned: true);

  test(
      'PB-guard-1 a throwing instances is a KitHookFailure naming '
      '"instances": the edit rolled back, and probe returns it', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, poisoned);
    sw.failing.add('instances');
    final before = canon(h.doc);
    final depth = h.doc.commands.undoDepth;
    // M-PB-guard-a: GuardedType.instances calling the delegate bare (the
    // raw HookBoom escapes). M-PB-guard-b: `_fail('generate', e, s)` in it.
    expect(
        () => h.doc.commands.execute(SetComponentCommand<SquareParams>(
            s, poisoned.copyWith(side: 900.5))),
        throwsA(failedInstances()));
    expect(canon(h.doc), before, reason: 'rolled back');
    expect(h.doc.commands.undoDepth, depth);
    expect(h.system.probe(s), failedInstances());
  });

  test(
      'PB-guard-2 through the controller: the object frozen and locked, one '
      'diagnostic naming the hook, its geometry kept, the other square '
      'still regenerated', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final broken = addObject(d, atSquare, poisoned);
    final other = addObject(
        d, nearSquare(4000, -500, 0.25), const SquareParams(side: 500));
    final drawn = coordsOf(d, broken);
    sw.failing.add('instances');

    // The resize fails on the hook, the boundary probes the type, freezes
    // the broken square and retries: the retry touches a locked object.
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            broken, poisoned.copyWith(side: 900.5))),
        isFalse);
    expect(c.locked.value, {broken});
    expect(c.frozen, contains(broken));
    final failures = diagnosticsOf(c, KitDiagnosticCode.hookFailed);
    expect(failures, hasLength(1));
    expect((failures.single.kitId, failures.single.subject),
        ('box', SquareParams.id));
    expect(failures.single.message, startsWith('instances: '));
    expect(coordsOf(d, broken), drawn);

    final otherBefore = coordsOf(d, other);
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            other, const SquareParams(side: 650.5))),
        isTrue);
    expect(coordsOf(d, other), isNot(otherBefore), reason: 'regenerated');
  });
}
