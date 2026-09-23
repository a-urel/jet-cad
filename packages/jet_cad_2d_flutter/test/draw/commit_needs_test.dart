import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/draw_fixture.dart';

class _Probe extends RectangleTool {
  int builds = 0;
  bool run(ToolContext ctx, Set<Capability> needs) => commit(ctx, () {
        builds++;
        return CompoundCommand(const [], label: 'never');
      }, needs: needs);
}

void main() {
  test('CN1 a denied member of needs stops the build (M-06u)', () {
    final s = drawScene();
    final probe = _Probe();
    final rig = drawRig(s.document, probe, objectSnap: false);
    s.document.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: true, structure: false);
    expect(probe.run(rig.context, {Capability.structure, Capability.geometry}),
        isFalse);
    expect(probe.builds, 0);
  });

  test('CN2 the default is geometry alone, as in 05', () {
    final s = drawScene();
    final probe = _Probe();
    final rig = drawRig(s.document, probe, objectSnap: false);
    s.document.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: false, structure: true);
    expect(probe.run(rig.context, const {Capability.geometry}), isFalse);
    expect(probe.builds, 0);
  });
}
