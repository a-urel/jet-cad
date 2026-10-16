// 3a Task 27 (Appendix A D-46; spec C1.1, C1.7, C3.3): the property
// panel over the real kit. An opening's section is titled by its kind
// (`PlanType.title`), and a door's flips are `ActionProperty`s shown for a
// door only (`visible`): a tap is one step that flips the one field. Over
// the sample flat (its doors and windows), at 1440 x 900.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

import '../support/canvas_rig.dart';

/// The sample's first opening of [kind], by handle.
Handle firstOf(DraftDocument d, OpeningKind kind) =>
    (d.components.withComponent<OpeningParams>().toList()
          ..sort((a, b) => a.value.compareTo(b.value)))
        .firstWhere((o) => d.components.get<OpeningParams>(o)!.kind == kind);

void main() {
  testWidgets(
      'IP-title an opening\'s section is titled by its kind: Door for a '
      'door, Window for a window (D-46, the title hook)', (tester) async {
    final c = sampleFlatController();
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    final title = byKey('section-${ArchitectureTypes.opening}');
    for (final (kind, word) in const [
      (OpeningKind.door, 'Door'),
      (OpeningKind.window, 'Window'),
    ]) {
      c.activeSelection.replace([SelectionKey.root(firstOf(c.document, kind))]);
      await tester.pump();
      expect(tester.widget<Text>(title).data, word, reason: kind.name);
    }
  });

  testWidgets(
      'IP-door-actions a door shows Flip hinge and Flip swing; a tap flips '
      'that field alone in one step; a window shows neither (D-46: '
      'ActionProperty and visible)', (tester) async {
    final c = sampleFlatController();
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    final d = c.document;
    final door = firstOf(d, OpeningKind.door);
    c.activeSelection.replace([SelectionKey.root(door)]);
    await tester.pump();
    final p0 = d.components.get<OpeningParams>(door)!;
    final depth = d.commands.undoDepth;
    await tester.tap(field('flip-swing'));
    await tester.pump();
    final p1 = d.components.get<OpeningParams>(door)!;
    expect(p1.swing, isNot(p0.swing), reason: 'the swing flipped');
    expect(p1.hinge, p0.hinge, reason: 'the hinge kept');
    expect(d.commands.undoDepth, depth + 1, reason: 'one step');
    await tester.tap(field('flip-hinge'));
    await tester.pump();
    final p2 = d.components.get<OpeningParams>(door)!;
    expect(p2.hinge, isNot(p1.hinge), reason: 'the hinge flipped');
    expect(p2.swing, p1.swing, reason: 'the swing kept');
    final window = firstOf(d, OpeningKind.window);
    c.activeSelection.replace([SelectionKey.root(window)]);
    await tester.pump();
    expect(byKey('section-${ArchitectureTypes.opening}'), findsOneWidget,
        reason: 'premise: the window\'s section');
    expect(field('flip-hinge'), findsNothing);
    expect(field('flip-swing'), findsNothing);
  });
}
