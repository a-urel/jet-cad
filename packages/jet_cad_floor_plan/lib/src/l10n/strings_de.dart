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

  @override
  String get tableTitle => 'Tisch';

  @override
  String get width => 'Breite';

  @override
  String get height => 'Höhe';

  @override
  String get thickness => 'Dicke';

  @override
  String get justifyLeft => 'Links';

  @override
  String get justifyCentre => 'Mitte';

  @override
  String get justifyRight => 'Rechts';

  @override
  String get position => 'Position';

  @override
  String get flipHinge => 'Anschlag wechseln';

  @override
  String get flipSwing => 'Aufschlag wechseln';

  @override
  String get name => 'Name';

  @override
  String get area => 'Fläche';

  @override
  String get value => 'Wert';

  @override
  String get aligned => 'Ausgerichtet';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertikal';

  @override
  String get end1 => 'Ende 1';

  @override
  String get end2 => 'Ende 2';

  @override
  String get endFixed => 'Fest';

  @override
  String get leftFace => 'linke Seite';

  @override
  String get centreline => 'Mittellinie';

  @override
  String get rightFace => 'rechte Seite';

  @override
  String get size => 'Größe';

  @override
  String get rotation => 'Drehung';

  @override
  String get mirror => 'Spiegeln';

  @override
  String get number => 'Nummer';

  @override
  String get seats => 'Plätze';

  @override
  String get rotateLeft => '90° nach links drehen';

  @override
  String get rotateRight => '90° nach rechts drehen';

  @override
  String get pageTitle => 'Seite';

  @override
  String get customSize => 'Benutzerdefiniert';

  @override
  String get portrait => 'Hochformat';

  @override
  String get landscape => 'Querformat';

  @override
  String get scale => 'Maßstab';

  @override
  String get grid => 'Raster';

  @override
  String get snapToGrid => 'Am Raster fangen';

  @override
  String get pageBreaks => 'Seitenumbrüche';

  @override
  String get paper => 'Papier';

  @override
  String axesTurned(String degrees) => 'Achsen um $degrees° gedreht';

  @override
  String endOnWall(String wall, bool atStart, String side) =>
      'Wand $wall, ${atStart ? 'Anfang' : 'Ende'}, $side';

  @override
  String get layersLocked =>
      'Ebenen können in diesem Dokument nicht geändert werden';

  @override
  String get selectLayerToDelete => 'Wählen Sie eine Ebene zum Löschen';

  @override
  String get layerZeroUndeletable => 'Ebene 0 kann nicht gelöscht werden';

  @override
  String get currentLayerUndeletable =>
      'Die aktuelle Ebene kann nicht gelöscht werden';

  @override
  String get layerInUse => 'Diese Ebene wird verwendet';

  @override
  String get layers => 'Ebenen';

  @override
  String get newLayer => 'Neue Ebene';

  @override
  String get deleteLayer => 'Ebene löschen';

  @override
  String get mixed => 'Gemischt';

  @override
  String get readOnlyDocument => 'Schreibgeschütztes Dokument';

  @override
  String get plainGroupNoLayer =>
      'Eine einfache Gruppe hat keine Ebene: Sie kann nicht verschoben werden';

  @override
  String get layer => 'Ebene';

  @override
  String get moveSelectionToLayer => 'Auswahl auf eine Ebene verschieben';

  @override
  String get hiddenLayerNotCurrent =>
      'Eine ausgeblendete Ebene kann nicht aktuell sein';

  @override
  String get currentLayer => 'Aktuelle Ebene';

  @override
  String get makeCurrent => 'Als aktuell festlegen';

  @override
  String get currentLayerNotHidden =>
      'Die aktuelle Ebene kann nicht ausgeblendet werden';

  @override
  String get hideLayer => 'Ebene ausblenden';

  @override
  String get showLayer => 'Ebene einblenden';

  @override
  String get unlockLayer => 'Ebene entsperren';

  @override
  String get lockLayer => 'Ebene sperren';

  @override
  String get layerColour => 'Ebenenfarbe';

  @override
  String missingLayer(String hex) => 'Fehlende Ebene $hex';

  @override
  String colourName(int aci) => switch (aci) {
        1 => 'Rot',
        2 => 'Gelb',
        3 => 'Grün',
        4 => 'Cyan',
        5 => 'Blau',
        6 => 'Magenta',
        7 => 'Vordergrund',
        8 => 'Dunkelgrau',
        9 => 'Hellgrau',
        _ => '$aci',
      };
}
