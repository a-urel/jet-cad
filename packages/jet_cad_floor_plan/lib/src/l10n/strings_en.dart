// The planner's words in English (spec 14d L1): today's literals, byte for
// byte, so English is unchanged on screen.
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

/// The planner's words in English.
class FloorPlanStringsEn extends FloorPlanStrings {
  const FloorPlanStringsEn();

  @override
  String get languageCode => 'en';

  @override
  String get decimalSeparator => '.';

  @override
  String layerNameProblem(LayerNameProblem problem) => switch (problem) {
        LayerNameEmpty() => 'A layer name cannot be empty.',
        LayerNameEdgeSpace() =>
          'A layer name cannot start or end with a space.',
        LayerNameTooLong(:final max) =>
          'A layer name can be at most $max characters.',
        LayerNameBadCharacter(:final character) =>
          'A layer name cannot contain $character.',
        LayerNameDuplicate(:final existing) =>
          'A layer named $existing already exists.',
      };

  @override
  String tableNumberProblem(TableNumberProblem problem) => switch (problem) {
        TableNumberProblem.length => '1 to $kTableNumberMaxLength characters',
        TableNumberProblem.control => 'No line breaks or control characters',
      };

  @override
  String tableNumberUsed(String number) => 'Number $number is already used';

  @override
  String numberingWarning(NumberingWarning warning) => switch (warning) {
        DuplicateNumber(:final number, :final count) =>
          'Number $number is used by $count tables',
        Unnumbered(:final seats) => seats == 1
            ? 'A table with 1 seat has no number'
            : 'A table with $seats seats has no number',
      };

  @override
  String roomOccupied(String name) => 'Already a room: $name';
}
