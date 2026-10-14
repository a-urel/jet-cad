// Spec P4 "The failure boundary", through the controller with the throwing
// kit: a kit's factories and disposals that throw during a document swap
// leave the swap complete (Task 8's review: before the guard, the
// controller was left half-swapped and the old session undisposed), and a
// kit tool's getter that throws answers its safe default.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/throwing_kit.dart';

List<(String, String?, KitDiagnosticCode)> keysOf(
        List<KitDiagnostic> diagnostics) =>
    [for (final d in diagnostics) (d.kitId, d.subject, d.code)];

void main() {
  testWidgets(
      'F-10 a swap whose kit factories and disposals throw completes: the '
      'new plan is open, the tool disabled, the type without grips, one '
      'diagnostic each, and the old session let go after the frame',
      (tester) async {
    final boom = ThrowingKit();
    final c = controllerFor(kits: [boom.kit]);
    final old = c.document;
    expect(c.toolFor('boom.tool'), isNotNull, reason: 'premise: made healthy');
    boom.failing.addAll([
      'toolCreate',
      'gripsCreate',
      'toolDispose',
      'gripsDispose',
      'cacheDispose',
    ]);
    // M-F10a: `runKitFactories` calling `type.gripsFor(s)` bare: newPlan
    // throws BoomFailure after the old products are gone.
    // M-F10b: `GuardedTool.dispose` without its catch, M-F10c:
    // `disposeKitProducts` calling a provider's `dispose` bare, M-F10d: it
    // calling `shared.dispose()` without `onError`: an old product's
    // dispose throws out of newPlan before the new document opens.
    c.newPlan();
    expect(c.document, isNot(same(old)));
    expect(c.activeTool.value, 'plan.select');
    expect(c.isToolDisabled('boom.tool'), isTrue);
    expect(c.selectTool('boom.tool'), isFalse);
    // The old products' disposals first (the tool, the block's grips, the
    // kit's shared cache); the new factories' failures then repeat the
    // tool's and the block's, once each.
    expect(keysOf(c.diagnostics.value), [
      ('boom', 'boom.tool', KitDiagnosticCode.hookFailed),
      ('boom', 'boom.block', KitDiagnosticCode.hookFailed),
      ('boom', null, KitDiagnosticCode.hookFailed),
    ]);
    expect(old.commands.isDisposed, isFalse, reason: 'its views go first');
    await tester.pump();
    expect(old.commands.isDisposed, isTrue);
  });

  testWidgets(
      'F-12 a kit tool whose isMidShape throws: undo still acts (the '
      'getter answers false); one diagnostic, published after the frame',
      (tester) async {
    final boom = ThrowingKit();
    final c = controllerFor(kits: [boom.kit]);
    expect(
        c.execute(addDrafted(c.document, EntityKind.line,
            linePayload(Vector2(-2100.5, 640.25), Vector2(1300.75, -980.5)),
            layer: ReservedHandles.layerZero)),
        isTrue);
    expect(c.selectTool('boom.tool'), isTrue);
    boom.failing.add('toolMidShape');
    // M-F12: GuardedTool.isMidShape calling the inner bare: undo throws.
    c.undo();
    expect(c.document.commands.canUndo, isFalse, reason: 'undone');
    expect(c.diagnostics.value, isEmpty, reason: 'not at once');
    await tester.pump();
    expect(keysOf(c.diagnostics.value),
        [('boom', 'boom.tool', KitDiagnosticCode.hookFailed)]);
  });
}
