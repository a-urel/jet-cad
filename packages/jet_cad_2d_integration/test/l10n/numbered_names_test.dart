// ignore_for_file: invalid_use_of_internal_member
// Spec 14d L7: a new layer is named in the language of the moment, its N
// counted over every built-in language's pattern, as the table folds names
// (M-14d-k); the sample plan names its rooms in its language.
// Ported from jet_cad_floor_plan/test/l10n/numbered_names_test.dart (NN3;
// NN1 and NN2 are 2a's) (3a Task 27, Appendix A D-24); assertions
// unchanged. The plan builds the sample in the language it was told
// (`newPlan(build:)`, spec C1.9): the strings become the reported locale,
// through `reportLocale`, @internal (ruling R-P9).
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

void main() {
  testWidgets('NN3 the sample plan names its rooms in its language',
      (tester) async {
    List<String> roomsOf(Locale locale) {
      final c = PlanController(kits: [architectureKit]);
      c.reportLocale(locale);
      c.newPlan(build: buildSampleFlat);
      final names = [
        for (final h in c.document.components.withComponent<RoomParams>())
          c.document.components.get<RoomParams>(h)!.name
      ];
      c.dispose();
      return names;
    }

    expect(roomsOf(const Locale('en')), contains('Bedroom 2'));
    expect(roomsOf(const Locale('tr')),
        containsAll(['Hol', 'Yatak odası 1', 'Mutfak', 'Yemek odası']));
    expect(roomsOf(const Locale('de')), contains('Küche'));
  });
}
