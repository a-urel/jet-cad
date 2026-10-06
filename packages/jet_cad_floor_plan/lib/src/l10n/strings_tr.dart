// The planner's words in Turkish (spec 14d L1).
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

/// The planner's words in Turkish.
class FloorPlanStringsTr extends FloorPlanStrings {
  const FloorPlanStringsTr();

  @override
  String get languageCode => 'tr';

  @override
  String get decimalSeparator => ',';

  @override
  String layerNameProblem(LayerNameProblem problem) => switch (problem) {
        LayerNameEmpty() => 'Katman adı boş olamaz.',
        LayerNameEdgeSpace() => 'Katman adı boşlukla başlayamaz veya bitemez.',
        LayerNameTooLong(:final max) =>
          'Katman adı en fazla $max karakter olabilir.',
        LayerNameBadCharacter(:final character) =>
          'Katman adı $character içeremez.',
        LayerNameDuplicate(:final existing) =>
          '$existing adlı bir katman zaten var.',
      };

  @override
  String tableNumberProblem(TableNumberProblem problem) => switch (problem) {
        TableNumberProblem.length =>
          '1 ile $kTableNumberMaxLength karakter arası',
        TableNumberProblem.control =>
          'Satır sonu veya kontrol karakteri olamaz',
      };

  @override
  String tableNumberUsed(String number) =>
      '$number numarası zaten kullanılıyor';

  @override
  String numberingWarning(NumberingWarning warning) => switch (warning) {
        DuplicateNumber(:final number, :final count) =>
          '$number numarası $count masada kullanılıyor',
        Unnumbered(:final seats) => '$seats kişilik bir masanın numarası yok',
      };

  @override
  String roomOccupied(String name) => 'Zaten bir oda: $name';
}
