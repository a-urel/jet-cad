// Spec 14d L7: a new layer is named in the language of the moment, its N
// counted over every built-in language's pattern, as the table folds names
// (M-14d-k); the sample plan names its rooms in its language.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer;
import 'package:jet_cad_floor_plan/src/l10n/numbered_names.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings_de.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings_en.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings_tr.dart';
import 'package:jet_cad_floor_plan/src/layers/layer_panel.dart';
import 'package:jet_cad_floor_plan/src/parametric/live_objects.dart';
import 'package:jet_cad_floor_plan/src/parametric/room.dart';
import 'package:jet_cad_floor_plan/src/startup_plan.dart';

DraftDocument withLayers(List<String> names) {
  final doc = DraftDocument.empty();
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  for (final name in names) {
    doc.tables.layers.add(LayerRecord(
      handle: doc.handleSeed.next(),
      name: name,
      color: const IndexedColor(2),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false,
    ));
  }
  return doc;
}

void main() {
  test('NN1 a layer\'s N is counted over every language (M-14d-k)', () {
    final doc = withLayers(['Layer 1', 'katman 2', 'Ebene 4', 'Layer 05']);
    expect(nextLayerName(doc, const FloorPlanStringsDe()), 'Ebene 3');
    expect(nextLayerName(doc, const FloorPlanStringsTr()), 'Katman 3');
    expect(nextLayerName(doc), 'Layer 3');
    final full = withLayers(['Layer 1', 'Ebene 2', 'Katman 3']);
    expect(nextLayerName(full, const FloorPlanStringsTr()), 'Katman 4');
  });

  test('NN2 a name of another shape takes no N', () {
    for (final name in ['Layer 0', 'Layer 2 ', 'Layer', 'Raum 2a', 'Oda']) {
      expect(
          numberedNameIndex(
              name, (s, n) => s.layerName(n), const FloorPlanStringsEn()),
          isNull,
          reason: name);
    }
    expect(
        numberedNameIndex(
            'Oda 7', (s, n) => s.roomName(n), const FloorPlanStringsDe()),
        7);
  });

  testWidgets('NN3 the sample plan names its rooms in its language',
      (tester) async {
    List<String> roomsOf(FloorPlanStrings strings) {
      final measurer = FlutterTextMeasurer();
      final doc = startupPlan(measurer, strings: strings);
      final names = [
        for (final h in liveObjectsOf<RoomParams>(doc))
          doc.components.get<RoomParams>(h)!.name
      ];
      doc.dispose();
      measurer.clear();
      return names;
    }

    expect(roomsOf(const FloorPlanStringsEn()), contains('Bedroom 2'));
    expect(roomsOf(const FloorPlanStringsTr()),
        containsAll(['Hol', 'Yatak odası 1', 'Mutfak', 'Yemek odası']));
    expect(roomsOf(const FloorPlanStringsDe()), contains('Küche'));
  });
}
