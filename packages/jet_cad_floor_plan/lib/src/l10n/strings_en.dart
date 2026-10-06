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

  @override
  String get toolSelect => 'Select';

  @override
  String get toolLine => 'Line';

  @override
  String get toolPolyline => 'Polyline';

  @override
  String get toolRectangle => 'Rectangle';

  @override
  String get toolBox => 'Box';

  @override
  String get toolWall => 'Wall';

  @override
  String get toolDoor => 'Door';

  @override
  String get toolWindow => 'Window';

  @override
  String get toolGap => 'Gap';

  @override
  String get toolRoom => 'Room';

  @override
  String get toolSeparator => 'Separator';

  @override
  String get toolDimension => 'Dimension';

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
  String get tableTitle => 'Table';

  @override
  String get width => 'Width';

  @override
  String get height => 'Height';

  @override
  String get thickness => 'Thickness';

  @override
  String get justifyLeft => 'Left';

  @override
  String get justifyCentre => 'Centre';

  @override
  String get justifyRight => 'Right';

  @override
  String get position => 'Position';

  @override
  String get flipHinge => 'Flip hinge';

  @override
  String get flipSwing => 'Flip swing';

  @override
  String get name => 'Name';

  @override
  String get area => 'Area';

  @override
  String get value => 'Value';

  @override
  String get aligned => 'Aligned';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertical';

  @override
  String get end1 => 'End 1';

  @override
  String get end2 => 'End 2';

  @override
  String get endFixed => 'Fixed';

  @override
  String get leftFace => 'left face';

  @override
  String get centreline => 'centreline';

  @override
  String get rightFace => 'right face';

  @override
  String get size => 'Size';

  @override
  String get rotation => 'Rotation';

  @override
  String get mirror => 'Mirror';

  @override
  String get number => 'Number';

  @override
  String get seats => 'Seats';

  @override
  String get rotateLeft => 'Rotate 90° left';

  @override
  String get rotateRight => 'Rotate 90° right';

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
  String get paper => 'Paper';

  @override
  String axesTurned(String degrees) => 'Axes turned $degrees°';

  @override
  String endOnWall(String wall, bool atStart, String side) =>
      'Wall $wall, ${atStart ? 'start' : 'end'}, $side';

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
  String get layer => 'Layer';

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
  String roomName(int n) => 'Room $n';

  @override
  String layerName(int n) => 'Layer $n';

  @override
  String get sampleHall => 'Hall';

  @override
  String get sampleKitchen => 'Kitchen';

  @override
  String get sampleBath => 'Bath';

  @override
  String get sampleLiving => 'Living';

  @override
  String get sampleDining => 'Dining';

  @override
  String sampleBedroom(int n) => 'Bedroom $n';
}
