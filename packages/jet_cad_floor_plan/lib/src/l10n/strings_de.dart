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

  @override
  String get toolSelect => 'Auswählen';

  @override
  String get toolLine => 'Linie';

  @override
  String get toolPolyline => 'Polylinie';

  @override
  String get toolRectangle => 'Rechteck';

  @override
  String get toolBox => 'Kasten';

  @override
  String get toolWall => 'Wand';

  @override
  String get toolDoor => 'Tür';

  @override
  String get toolWindow => 'Fenster';

  @override
  String get toolGap => 'Öffnung';

  @override
  String get toolRoom => 'Raum';

  @override
  String get toolSeparator => 'Trennlinie';

  @override
  String get toolDimension => 'Bemaßung';

  @override
  String get toolCircle => 'Kreis';

  @override
  String get toolArc => 'Bogen';

  @override
  String get toolText => 'Text';

  @override
  String get toolSymbol => 'Symbol';

  @override
  String get fill => 'Füllung';

  @override
  String get tabTools => 'Werkzeuge';

  @override
  String get tabSymbols => 'Symbole';

  @override
  String get objectSnapOn => 'OSNAP';

  @override
  String get objectSnapOff => 'OSNAP aus';

  @override
  String get edited => 'Geändert';

  @override
  String get undo => 'Rückgängig';

  @override
  String get redo => 'Wiederholen';

  @override
  String get exportEllipsis => 'Exportieren…';

  @override
  String get printEllipsis => 'Drucken…';

  @override
  String get controlKey => 'Strg';

  @override
  String get shiftKey => 'Umschalt';

  @override
  String get exportTitle => 'Exportieren';

  @override
  String get exportAction => 'Exportieren';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get searchSymbols => 'Symbole suchen';

  @override
  String get clear => 'Leeren';

  @override
  String get loadingSymbols => 'Symbole werden geladen…';

  @override
  String get symbolsFailed => 'Die Symbole konnten nicht geladen werden.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String selectedCount(int count) => '$count ausgewählt';

  @override
  String dpi(int dpi) => '$dpi dpi';

  @override
  String noSymbolsMatch(String query) => 'Keine Symbole zu „$query“';
}
