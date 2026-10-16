// Sub-project 4a R2 H2: a host's own symbols come as a small kit,
// `PlanKit(id: '<host>', symbols: [...])`, with no further API. The host
// kit (one library built in memory, kit "acme") is loaded beside the test
// kit's own library; both show in the gallery and either places.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/symbol_fixtures.dart';
import '../support/test_kit.dart';
import '../support/tool_events.dart';

const String posKey = 'acme.item.pos@1';

/// The host's kit: one library, built in memory, one symbol.
PlanKit acmeKit() => symbolKit('acme', [
      SymbolLibrarySource(
          label: 'acme', read: () async => itemsBytes('acme', ['pos']))
    ]);

/// The key@version of each symbol instance in [c]'s document, by the
/// component on its definition.
List<String> placedKeys(PlanController c) {
  final d = c.document;
  return [
    for (final n in d.tree.nodes.whereType<InstanceNode>())
      if (d.components.get<SymbolComponent>(n.definition) case final s?)
        '${s.key}@${s.version}'
  ];
}

void main() {
  testWidgets(
      'H2 a host kit\'s symbol shows in the gallery beside another kit\'s '
      'and is placed from it, off the origin', (tester) async {
    final c = controllerFor(kits: [unitKit(), acmeKit()]);
    await tester.runAsync(() async {
      for (var i = 0;
          i < 50 && c.symbolsState.value == SymbolsState.loading;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(c.symbolsState.value, SymbolsState.ready);
    expect(c.symbolById(posKey), isNotNull, reason: 'the host\'s symbol');
    expect(c.symbolById(tableSymbolId), isNotNull, reason: 'the other kit\'s');

    await pumpApp(
        tester,
        Row(children: [
          SizedBox(width: 300, child: PlanSymbolGallery(controller: c)),
        ]));
    await tester.pump();
    expect(find.byKey(const Key('symbol-cell-$posKey')), findsOneWidget);
    expect(find.byKey(const Key('symbol-cell-$tableSymbolId')), findsOneWidget);

    await tester.tap(find.byKey(const Key('symbol-cell-$posKey')));
    await tester.pump();
    expect(c.armedSymbol.value?.id, posKey);
    expect(c.activeTool.value, PlanToolIds.symbol);
    useTestCamera(c);
    expect(placedKeys(c), isEmpty);
    tapAt(c, Vector2(5300.5, -2100.25));
    expect(placedKeys(c), [posKey]);
  });
}
