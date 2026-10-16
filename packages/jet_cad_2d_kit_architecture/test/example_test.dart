// The kit's published example (spec 3a C2; Appendix A D-18): the
// descriptor and the hook a new plan runs, over a bare engine document.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

// The example is not under lib/, so a relative path is the only way to it.
// ignore: avoid_relative_lib_imports
import '../example/main.dart';

void main() {
  test(
      'SC-example the example names the kit and its version, every tool '
      'with its letter, no problems, and the DASHED record its prepare '
      'writes', () {
    final lines = describeArchitectureKit();
    expect(
        lines.first,
        'architecture 0.1.0: ${architectureKit.types.length} types, '
        '${architectureKit.tools.length} tools');
    for (final tool in architectureKit.tools) {
      expect(lines, contains('${tool.id} (${tool.letter})'));
    }
    expect(lines, contains('validate: no problems'));
    // M-SC-10: the example without the prepare call.
    expect(lines.last, 'prepare: DASHED at handle 6');
  });
}
