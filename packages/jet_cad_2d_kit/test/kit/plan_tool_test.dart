// Spec 2a P1, P3: PlanTool and its settings. Two tools whose settings are of
// different types `S` are held in one list and edited through their erased
// fields, under the VM's runtime checks (Review Focus 3).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;

import '../support/code_fixtures.dart';
import '../support/tool_fixtures.dart';

void main() {
  test('PT12 a tool settings field: its word, its value, its store', () {
    final tool = slabTool();
    final stored = <Object>[];
    final fields = tool.settings!
        .fieldsOf(tool.settings!.initial, stored.add, toolId: tool.id);
    expect([for (final f in fields) f.wordId],
        ['property:test.slab.width', 'property:test.slab.finish']);
    expect([for (final f in fields) f.value], [900.5, Finish.oiled]);
    final next = fields[0].commit!(1200.25);
    expect(next, const SlabSettings(width: 1200.25));
    // M-PT12: drop `onCommit: store`: nothing is stored.
    expect(stored, [const SlabSettings(width: 1200.25)]);
    expect(() => fields[1].commit!(Finish.waxed), throwsArgumentError);
    expect(() => fields[0].commit!(299), throwsArgumentError);
    expect(stored, hasLength(1));
    expect(
        () => tool.settings!
            .fieldsOf(const PostSettings(), stored.add, toolId: tool.id),
        throwsArgumentError);
  });

  test('PT13 two settings types in one list of tools', () {
    // Review Focus 3, a positive control: the settings are reached only
    // through the erased PlanToolSettings<Object> and PropertyField.
    final tools = [slabTool(), postTool()];
    final values = <String, Object>{
      for (final t in tools) t.id: t.settings!.initial,
    };
    for (final tool in tools) {
      final fields = tool.settings!.fieldsOf(
          values[tool.id]!, (v) => values[tool.id] = v,
          toolId: tool.id);
      final first = fields.first;
      first.commit!(first.value is bool ? true : 1500.0);
    }
    expect(values, {
      'test.slab': const SlabSettings(width: 1500),
      'test.post': const PostSettings(round: true),
    });
    expect(tools[0].letter, 'S');
    expect(tools[0].needs, {Capability.structure, Capability.geometry});
    expect(tools[1].letter, isNull);
    expect(tools[1].needs, isEmpty);
    expect('${tools[0]}', 'PlanTool(test.slab)');
  });
}
