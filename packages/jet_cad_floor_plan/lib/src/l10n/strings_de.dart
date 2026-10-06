// The planner's words in German (spec 14d L1).
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show
        LayerNameBadCharacter,
        LayerNameDuplicate,
        LayerNameEdgeSpace,
        LayerNameEmpty,
        LayerNameProblem,
        LayerNameTooLong;

import '../host/floor_plan_types.dart'
    show DuplicateNumber, NumberingWarning, Unnumbered;
import '../tables/table_numbers.dart'
    show TableNumberProblem, kTableNumberMaxLength;
import 'strings.dart';

/// The planner's words in German.
class FloorPlanStringsDe extends FloorPlanStrings {
  const FloorPlanStringsDe();

  @override
  String get languageCode => 'de';

  @override
  String get decimalSeparator => ',';

  @override
  String layerNameProblem(LayerNameProblem problem) => switch (problem) {
        LayerNameEmpty() => 'Ein Ebenenname darf nicht leer sein.',
        LayerNameEdgeSpace() =>
          'Ein Ebenenname darf nicht mit einem Leerzeichen beginnen oder enden.',
        LayerNameTooLong(:final max) =>
          'Ein Ebenenname darf höchstens $max Zeichen lang sein.',
        LayerNameBadCharacter(:final character) =>
          'Ein Ebenenname darf $character nicht enthalten.',
        LayerNameDuplicate(:final existing) =>
          'Eine Ebene namens $existing gibt es bereits.',
      };

  @override
  String tableNumberProblem(TableNumberProblem problem) => switch (problem) {
        TableNumberProblem.length => '1 bis $kTableNumberMaxLength Zeichen',
        TableNumberProblem.control => 'Keine Zeilenumbrüche oder Steuerzeichen',
      };

  @override
  String tableNumberUsed(String number) =>
      'Die Nummer $number ist bereits vergeben';

  @override
  String numberingWarning(NumberingWarning warning) => switch (warning) {
        DuplicateNumber(:final number, :final count) =>
          'Die Nummer $number wird von $count Tischen verwendet',
        Unnumbered(:final seats) => seats == 1
            ? 'Ein Tisch mit 1 Platz hat keine Nummer'
            : 'Ein Tisch mit $seats Plätzen hat keine Nummer',
      };

  @override
  String roomOccupied(String name) => 'Bereits ein Raum: $name';
}
