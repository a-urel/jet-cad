// Spec 3a C1.3, C1.9 (Task 5): a kit's document preparation and a host's
// build are declared by the contract; the plan library runs them.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test(
      'PB0 PlanKit carries its prepare, null by default; PlanBuild is the '
      "contract's", () {
    // A premise of the declarations, exempt from the mutation rule: without
    // the field or the export this file does not compile.
    final calls = <DraftDocument>[];
    final void Function(DraftDocument) prepare = calls.add;
    final kit = PlanKit(id: 'sample', version: '0.1.0', prepare: prepare);
    expect(kit.prepare, same(prepare));
    expect(const PlanKit(id: 'sample', version: '0.1.0').prepare, isNull);
    expect(kit.validate(), isEmpty, reason: 'prepare needs no word');
    void noop(DraftDocument document, KitWords words) {}
    final PlanBuild build = noop;
    expect(build, isA<void Function(DraftDocument, KitWords)>());
  });
}
