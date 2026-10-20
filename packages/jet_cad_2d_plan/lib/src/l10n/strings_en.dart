// The plan library's words in English (spec P5; ported from
// jet_cad_floor_plan's strings_en.dart, spec 14d L1).
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

/// The plan library's words in English.
class PlanStringsEn extends PlanStrings {
  const PlanStringsEn();

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
  String get toolSelect => 'Select';

  @override
  String get toolLine => 'Line';

  @override
  String get toolPolyline => 'Polyline';

  @override
  String get toolRectangle => 'Rectangle';

  @override
  String get toolCircle => 'Circle';

  @override
  String get toolArc => 'Arc';

  @override
  String get toolText => 'Text';

  @override
  String get toolSymbol => 'Symbol';

  @override
  String get fill => 'Fill';

  @override
  String get tabTools => 'Tools';

  @override
  String get tabSymbols => 'Symbols';

  @override
  String get openToolsPanel => 'Tools and symbols';

  @override
  String get openPropertiesPanel => 'Properties';

  @override
  String get openServicePanel => 'Details';

  @override
  String get objectSnapOn => 'OSNAP';

  @override
  String get objectSnapOff => 'osnap off';

  @override
  String get edited => 'Edited';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get newDocument => 'New';

  @override
  String get open => 'Open…';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save As…';

  @override
  String get exportEllipsis => 'Export…';

  @override
  String get printEllipsis => 'Print…';

  @override
  String get controlKey => 'Ctrl';

  @override
  String get shiftKey => 'Shift';

  @override
  String get exportTitle => 'Export';

  @override
  String get exportAction => 'Export';

  @override
  String get cancel => 'Cancel';

  @override
  String get searchSymbols => 'Search symbols';

  @override
  String get clear => 'Clear';

  @override
  String get loadingSymbols => 'Loading symbols…';

  @override
  String get symbolsFailed => 'The symbols could not be loaded.';

  @override
  String get retry => 'Retry';

  @override
  String selectedCount(int count) => '$count selected';

  @override
  String dpi(int dpi) => '$dpi dpi';

  @override
  String noSymbolsMatch(String query) => 'No symbols match "$query"';

  @override
  String get name => 'Name';

  @override
  String get size => 'Size';

  @override
  String get rotation => 'Rotation';

  @override
  String get mirror => 'Mirror';

  @override
  String get pageTitle => 'Page';

  @override
  String get customSize => 'Custom';

  @override
  String get portrait => 'Portrait';

  @override
  String get landscape => 'Landscape';

  @override
  String get scale => 'Scale';

  @override
  String get grid => 'Grid';

  @override
  String get snapToGrid => 'Snap to grid';

  @override
  String get pageBreaks => 'Page breaks';

  @override
  String get pageDecimalSeparator => 'Decimal separator';

  @override
  String get paper => 'Paper';

  @override
  String get layersLocked => 'Layers cannot be changed in this document';

  @override
  String get selectLayerToDelete => 'Select a layer to delete it';

  @override
  String get layerZeroUndeletable => 'Layer 0 cannot be deleted';

  @override
  String get currentLayerUndeletable => 'The current layer cannot be deleted';

  @override
  String get layerInUse => 'This layer is in use';

  @override
  String get layers => 'Layers';

  @override
  String get newLayer => 'New layer';

  @override
  String get deleteLayer => 'Delete layer';

  @override
  String get mixed => 'Mixed';

  @override
  String get readOnlyDocument => 'Read-only document';

  @override
  String get plainGroupNoLayer =>
      'A plain group has no layer: it cannot be moved';

  @override
  String get lockedNoLayer => 'Locked objects cannot change layer';

  @override
  String get layer => 'Layer';

  @override
  String get color => 'Colour';

  @override
  String get colorNone => 'None';

  @override
  String get colorRefused => 'Colours are not editable here';

  @override
  String colorName(PlanSwatch swatch) => switch (swatch) {
        PlanSwatch.red => 'Red',
        PlanSwatch.orange => 'Orange',
        PlanSwatch.yellow => 'Yellow',
        PlanSwatch.green => 'Green',
        PlanSwatch.teal => 'Teal',
        PlanSwatch.blue => 'Blue',
        PlanSwatch.purple => 'Purple',
        PlanSwatch.grey => 'Grey',
      };

  @override
  String get moveSelectionToLayer => 'Move the selection to a layer';

  @override
  String get hiddenLayerNotCurrent => 'A hidden layer cannot be current';

  @override
  String get currentLayer => 'Current layer';

  @override
  String get makeCurrent => 'Make current';

  @override
  String get currentLayerNotHidden => 'The current layer cannot be hidden';

  @override
  String get hideLayer => 'Hide layer';

  @override
  String get showLayer => 'Show layer';

  @override
  String get unlockLayer => 'Unlock layer';

  @override
  String get lockLayer => 'Lock layer';

  @override
  String get layerColour => 'Layer colour';

  @override
  String missingLayer(String hex) => 'Missing layer $hex';

  @override
  String colourName(int aci) => switch (aci) {
        1 => 'Red',
        2 => 'Yellow',
        3 => 'Green',
        4 => 'Cyan',
        5 => 'Blue',
        6 => 'Magenta',
        7 => 'Foreground',
        8 => 'Dark grey',
        9 => 'Light grey',
        _ => '$aci',
      };

  @override
  String layerName(int n) => 'Layer $n';

  @override
  String get lockedHint => 'This object is locked';

  @override
  String get sectionFailed => 'This section could not be shown';

  @override
  String get planDamaged => 'An edit failed and the plan may be damaged';

  @override
  String get merge => 'Merge';

  @override
  String get split => 'Split';

  @override
  String get number => 'Number';

  @override
  String get label => 'Label';

  @override
  String get capacity => 'Seats';

  @override
  String get rotateLeft => 'Rotate 90° left';

  @override
  String get rotateRight => 'Rotate 90° right';

  @override
  String labelProblem(UnitLabelProblem problem) => switch (problem) {
        UnitLabelProblem.length => '1 to $kUnitLabelMaxLength characters',
        UnitLabelProblem.control => 'No line breaks or control characters',
      };

  @override
  String labelUsed(String label) => 'Number $label is already used';

  @override
  String labelWarning(UnitLabelWarning warning) => switch (warning) {
        DuplicateLabel(:final label, :final count) =>
          'Number $label is used by $count tables',
        Unlabelled(:final kind, :final capacity) => capacity == 1
            ? 'A ${_kindLower(kind)} with 1 seat has no number'
            : 'A ${_kindLower(kind)} with $capacity seats has no number',
        BadLabel(:final label, :final problem) =>
          '"$label" is no label: ${labelProblem(problem)}',
      };

  String _kindLower(String kind) => (unitKind(kind) ?? kind).toLowerCase();

  @override
  String? unitKind(String kind) => switch (kind) {
        UnitKinds.table => 'Table',
        UnitKinds.seat => 'Seat',
        _ => null,
      };
}
