// The architecture kit as a host sees it. A host passes `architectureKit` to
// the plan library -- `PlanController(kits: [architectureKit])`, and a
// `PlanEditor` over it (the plan library's package) -- which this package
// does not depend on, nor does its example (umbrella A1). What the example shows
// is the descriptor itself, and the one hook a new plan runs: `prepare`,
// which gives a document the separators' DASHED linetype.
//
// The kit is a Flutter library (its tools draw with Flutter's icons): the
// example is analysed with the package, and test/example_test.dart runs it.
import 'dart:async' show unawaited;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

/// The kit's descriptor, line by line: its id and version, its types, its
/// tools with their letters, what `validate` finds, and what `prepare`
/// writes into a bare engine document.
List<String> describeArchitectureKit() {
  final kit = architectureKit;
  final problems = kit.validate();
  final doc = DraftDocument.empty();
  kit.prepare?.call(doc);
  final dashed = doc.tables.linetypes[ReservedHandles.dashedLinetype];
  unawaited(doc.dispose());
  return [
    '${kit.id} ${kit.version}: ${kit.types.length} types, '
        '${kit.tools.length} tools',
    for (final type in kit.types)
      '${type.id}${type.exported ? '' : ' (not exported)'}',
    for (final tool in kit.tools) '${tool.id} (${tool.letter})',
    problems.isEmpty
        ? 'validate: no problems'
        : 'validate: ${problems.length} problems',
    dashed == null
        ? 'prepare: no DASHED record'
        : 'prepare: ${dashed.name} at handle ${dashed.handle.value}',
  ];
}

void main() {
  for (final line in describeArchitectureKit()) {
    print(line);
  }
}
