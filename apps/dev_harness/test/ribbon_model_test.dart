import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_dev_harness/ribbon/ribbon_model.dart';

void main() {
  test('a tool with no callback is decorative', () {
    const decorative = RibbonTool('Extrude', IconData(0xe000));
    expect(decorative.isDecorative, isTrue);
    expect(decorative.onPressed, isNull);
  });

  test('a tool with a callback is live', () {
    var fired = false;
    final live = RibbonTool('Box', const IconData(0xe001),
        onPressed: () => fired = true);
    expect(live.isDecorative, isFalse);
    live.onPressed!();
    expect(fired, isTrue);
  });

  test('tabs nest groups and tools', () {
    const tab = RibbonTab('Model', [
      RibbonGroup('Primitives', [RibbonTool('Box', IconData(0xe001))]),
    ]);
    expect(tab.title, 'Model');
    expect(tab.groups.single.title, 'Primitives');
    expect(tab.groups.single.tools.single.label, 'Box');
  });
}
