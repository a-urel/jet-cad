// Spec 3a C1.10 (decision 6): a frozen object's references are locked. A
// door whose type's code fails for it alone is frozen on load (spec 2a E2);
// its host wall then cannot be edited or deleted (PlanLocked, the lock
// hint), so it never regenerates uncut beside the frozen door or leaves the
// door naming a dead handle. A wall whose door is live edits as usual.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/opening_support.dart';

/// The architecture kit, its opening type failing in `generate` for
/// [poisoned] alone, as a kit's code that breaks on one object does. The
/// rest is the kit's own.
PlanKit poisonedKit(Handle poisoned) => PlanKit(
      id: architectureKit.id,
      version: architectureKit.version,
      symbols: architectureKit.symbols,
      types: [
        for (final t in architectureKit.types)
          if (t.id == ArchitectureTypes.opening)
            PlanType<OpeningParams>(
                id: t.id,
                fromJson: OpeningParams.fromJson,
                parametric: _Poisoned(
                    t.parametric as ParametricType<OpeningParams>, poisoned))
          else
            t,
      ],
      tools: architectureKit.tools,
      attachments: architectureKit.attachments,
      names: architectureKit.names,
      prepare: architectureKit.prepare,
    );

final class _Poisoned extends ParametricType<OpeningParams> {
  const _Poisoned(this.inner, this.poisoned);

  final ParametricType<OpeningParams> inner;
  final Handle poisoned;

  @override
  Capability get editCapability => inner.editCapability;

  @override
  Aabb2 reach(OpeningParams params, Transform2 toWorld) =>
      inner.reach(params, toWorld);

  @override
  Iterable<Handle> references(OpeningParams params) => inner.references(params);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    if (self == poisoned) throw StateError('the test\'s failing door');
    return inner.generate(view, self);
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) =>
      inner.diagnose(view, self);
}

void main() {
  testWidgets(
      'OT-frozen-host (spec 3a C1.10) a frozen door locks its host wall: an '
      'edit of the wall is refused with the lock hint and a delete is '
      'refused, the plan unchanged; a wall whose window is live edits in '
      'one step', (tester) async {
    late Handle a, door, b;
    final text = openingPlanText(shellPage, (d) {
      a = d.handleSeed.next();
      d.commands.execute(
          addWall(d, a, plan(0, 0), plan(5000, 0), 200, Justification.right));
      door = d.handleSeed.next();
      d.commands.execute(addOpening(
          d, door, OpeningParams(a, 1730, 900, OpeningKind.door),
          at: doorGroup));
      b = d.handleSeed.next();
      d.commands.execute(addWall(
          d, b, plan(0, 2500), plan(4000, 3100), 150, Justification.left));
      d.commands.execute(addOpening(d, d.handleSeed.next(),
          OpeningParams(b, 2000, 1200, OpeningKind.window)));
    });
    final c = PlanController(kits: [poisonedKit(door)], json: text);
    addTearDown(c.dispose);
    await pumpEditor(tester, c, centre: plan(2500, 1200), scale: 0.15);
    final doc = c.document;
    // ignore: invalid_use_of_internal_member
    expect(c.frozen, {door}, reason: 'premise: the door alone, on load');
    expect([for (final d in c.diagnostics.value) d.code],
        contains(KitDiagnosticCode.hookFailed));
    // The plan unchanged: its state, entities by handle (`canon`); a
    // refused edit is applied and inverted (locks.dart), which may leave
    // the entity slots in another order (06 D11: slot order is history).
    final before = canon(doc);

    final pa = doc.components.get<WallParams>(a)!;
    expect(
        c.execute(
            SetComponentCommand<WallParams>(a, pa.copyWith(thickness: 250))),
        isFalse,
        reason: 'an edit of the frozen door\'s host');
    expect(c.lockHint.value, isTrue);
    expect(canon(doc), before);
    expect(doc.commands.undoDepth, 0);

    // ignore: invalid_use_of_internal_member
    c.selection.replace([SelectionKey.root(a)]);
    await tester.pump();
    // The edit above set the hint: reset, so the delete must set it again
    // (the plan's frozen_references_test FL-delete: the selection's gate
    // refuses a locked object before any command, the hint set by the
    // select tool's delete command itself, refused as locked).
    c.lockHint.value = false;
    expect(c.deleteSelection(), isFalse, reason: 'a delete of it');
    expect(c.execute(deleteLikeSelectTool(doc, a)), isFalse,
        reason: "the select tool's delete command");
    expect(c.lockHint.value, isTrue, reason: 'the delete shows the hint');
    expect(doc.tree[a], isNotNull);
    expect(canon(doc), before);

    final pb = doc.components.get<WallParams>(b)!;
    expect(
        c.execute(
            SetComponentCommand<WallParams>(b, pb.copyWith(thickness: 180))),
        isTrue,
        reason: 'control: a live door\'s host');
    expect(doc.components.get<WallParams>(b)!.thickness, 180);
    expect(doc.commands.undoDepth, 1);
  });
}
