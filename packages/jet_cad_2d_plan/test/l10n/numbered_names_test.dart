// Spec 14d L7: a new layer is named in the language of the moment, its N
// counted over every built-in language's pattern (M-14d-k). Ported from
// jet_cad_floor_plan (2a Task 9): NN2's layer-name loop; NN1 (nextLayerName)
// is Task 18's, NN3 (the sample plan's rooms) sub-project 3's.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/l10n/numbered_names.dart';

void main() {
  test('NN2 a layer name of another shape takes no N', () {
    for (final name in ['Layer 0', 'Layer 2 ', 'Layer', 'Raum 2a', 'Oda']) {
      expect(
          numberedNameIndex(
              name, (s, n) => s.layerName(n), const PlanStringsEn()),
          isNull,
          reason: name);
    }
  });

  test('W-NN4 a layer name in another built-in language counts', () {
    // M-W-NN4: `numberedNameIndex` comparing with `current` only (the
    // built-in languages left out of its list) answers null here.
    expect(
        numberedNameIndex(
            'Katman 7', (s, n) => s.layerName(n), const PlanStringsDe()),
        7);
    expect(
        numberedNameIndex(
            'Ebene 12', (s, n) => s.layerName(n), const PlanStringsEn()),
        12);
    // Folded: the fold given meets a case difference.
    expect(
        numberedNameIndex(
            'KATMAN 3', (s, n) => s.layerName(n), const PlanStringsEn(),
            fold: (s) => s.toLowerCase()),
        3);
  });
}
