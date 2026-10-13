// Specs K5 and K7 share one problem type: a code and a message.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('KP1 value equality over the code and the message', () {
    const a = KitProblem(KitProblemCode.badKitId, '"Sample" is not a kit id');
    expect(a,
        const KitProblem(KitProblemCode.badKitId, '"Sample" is not a kit id'));
    expect(
        a.hashCode,
        const KitProblem(KitProblemCode.badKitId, '"Sample" is not a kit id')
            .hashCode);
    expect(
        a,
        isNot(const KitProblem(
            KitProblemCode.emptyVersion, '"Sample" is not a kit id')));
    // M-KP1: compare the codes only.
    expect(a, isNot(const KitProblem(KitProblemCode.badKitId, 'another')));
    expect('$a', 'badKitId: "Sample" is not a kit id');
  });
}
