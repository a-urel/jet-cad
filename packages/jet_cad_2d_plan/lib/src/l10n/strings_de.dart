// The plan library's words in German (spec P5; ported from
// jet_cad_floor_plan's strings_de.dart, spec 14d L1).
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show
        LayerNameBadCharacter,
        LayerNameDuplicate,
        LayerNameEdgeSpace,
        LayerNameEmpty,
        LayerNameProblem,
        LayerNameTooLong;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch, UnitKinds;

import '../units/unit_label.dart' show UnitLabelProblem, kUnitLabelMaxLength;
import '../units/unit_problems.dart'
    show BadLabel, DuplicateLabel, Unlabelled, UnitLabelWarning;
import 'strings.dart';

/// The plan library's words in German.
class PlanStringsDe extends PlanStrings {
  const PlanStringsDe();

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
  String get toolSelect => 'Auswählen';

  @override
  String get toolLine => 'Linie';

  @override
  String get toolPolyline => 'Polylinie';

  @override
  String get toolRectangle => 'Rechteck';

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
  String get newDocument => 'Neu';

  @override
  String get open => 'Öffnen…';

  @override
  String get save => 'Speichern';

  @override
  String get saveAs => 'Speichern unter…';

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
  String get name => 'Name';

  @override
  String get size => 'Größe';

  @override
  String get rotation => 'Drehung';

  @override
  String get mirror => 'Spiegeln';

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
  String get pageDecimalSeparator => 'Dezimaltrennzeichen';

  @override
  String get paper => 'Papier';

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
  String get lockedNoLayer =>
      'Gesperrte Objekte können die Ebene nicht wechseln';

  @override
  String get layer => 'Ebene';

  @override
  String get color => 'Farbe';

  @override
  String get colorNone => 'Keine';

  @override
  String get colorRefused => 'Farben sind hier nicht änderbar';

  @override
  String colorName(PlanSwatch swatch) => switch (swatch) {
        PlanSwatch.red => 'Rot',
        PlanSwatch.orange => 'Orange',
        PlanSwatch.yellow => 'Gelb',
        PlanSwatch.green => 'Grün',
        PlanSwatch.teal => 'Petrol',
        PlanSwatch.blue => 'Blau',
        PlanSwatch.purple => 'Lila',
        PlanSwatch.grey => 'Grau',
      };

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

  @override
  String layerName(int n) => 'Ebene $n';

  @override
  String get lockedHint => 'Dieses Objekt ist gesperrt';

  @override
  String get sectionFailed => 'Dieser Abschnitt kann nicht angezeigt werden';

  @override
  String get planDamaged =>
      'Eine Bearbeitung ist fehlgeschlagen; der Plan ist möglicherweise '
      'beschädigt';

  @override
  String get merge => 'Zusammenlegen';

  @override
  String get split => 'Trennen';

  @override
  String get number => 'Nummer';

  @override
  String get label => 'Bezeichnung';

  @override
  String get capacity => 'Plätze';

  @override
  String get rotateLeft => '90° nach links drehen';

  @override
  String get rotateRight => '90° nach rechts drehen';

  @override
  String labelProblem(UnitLabelProblem problem) => switch (problem) {
        UnitLabelProblem.length => '1 bis $kUnitLabelMaxLength Zeichen',
        UnitLabelProblem.control => 'Keine Zeilenumbrüche oder Steuerzeichen',
      };

  @override
  String labelUsed(String label) => 'Die Nummer $label ist bereits vergeben';

  @override
  String labelWarning(UnitLabelWarning warning) => switch (warning) {
        DuplicateLabel(:final label, :final count) =>
          'Die Nummer $label wird von $count Tischen verwendet',
        Unlabelled(:final kind, :final capacity) => kind == UnitKinds.table
            ? (capacity == 1
                ? 'Ein Tisch mit 1 Platz hat keine Nummer'
                : 'Ein Tisch mit $capacity Plätzen hat keine Nummer')
            : '${unitKind(kind) ?? kind} mit $capacity '
                '${capacity == 1 ? 'Platz' : 'Plätzen'} hat keine Nummer',
        BadLabel(:final label, :final problem) =>
          '„$label" ist keine Bezeichnung: ${labelProblem(problem)}',
      };

  @override
  String? unitKind(String kind) => switch (kind) {
        UnitKinds.table => 'Tisch',
        UnitKinds.seat => 'Sitzplatz',
        _ => null,
      };
}
