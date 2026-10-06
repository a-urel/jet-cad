// Generated from lib/src/l10n/strings.dart (spec 14d L1 as amended,
// V-10): a language whose every word is recorded as it is handed out, so a
// test can tell a word the planner asked for from a literal it did not.
// Regenerate with the plan's script when a member is added.
import 'package:jet_cad_floor_plan/src/l10n/strings.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show LayerNameProblem;
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart'
    show NumberingWarning;
import 'package:jet_cad_floor_plan/src/tables/table_numbers.dart'
    show TableNumberProblem;

class RecordingFloorPlanStrings implements FloorPlanStrings {
  RecordingFloorPlanStrings(this.inner);

  final FloorPlanStrings inner;

  /// Every string handed out.
  final Set<String> handedOut = {};

  /// Records [s] as handed out and returns it.
  String record(String s) {
    handedOut.add(s);
    return s;
  }

  @override
  String get languageCode => inner.languageCode;

  @override
  String get decimalSeparator => inner.decimalSeparator;

  @override
  String get toolSelect => record(inner.toolSelect);

  @override
  String get toolLine => record(inner.toolLine);

  @override
  String get toolPolyline => record(inner.toolPolyline);

  @override
  String get toolRectangle => record(inner.toolRectangle);

  @override
  String get toolBox => record(inner.toolBox);

  @override
  String get toolWall => record(inner.toolWall);

  @override
  String get toolDoor => record(inner.toolDoor);

  @override
  String get toolWindow => record(inner.toolWindow);

  @override
  String get toolGap => record(inner.toolGap);

  @override
  String get toolRoom => record(inner.toolRoom);

  @override
  String get toolSeparator => record(inner.toolSeparator);

  @override
  String get toolDimension => record(inner.toolDimension);

  @override
  String get toolCircle => record(inner.toolCircle);

  @override
  String get toolArc => record(inner.toolArc);

  @override
  String get toolText => record(inner.toolText);

  @override
  String get toolSymbol => record(inner.toolSymbol);

  @override
  String get fill => record(inner.fill);

  @override
  String get tabTools => record(inner.tabTools);

  @override
  String get tabSymbols => record(inner.tabSymbols);

  @override
  String get objectSnapOn => record(inner.objectSnapOn);

  @override
  String get objectSnapOff => record(inner.objectSnapOff);

  @override
  String get edited => record(inner.edited);

  @override
  String get undo => record(inner.undo);

  @override
  String get redo => record(inner.redo);

  @override
  String get exportEllipsis => record(inner.exportEllipsis);

  @override
  String get printEllipsis => record(inner.printEllipsis);

  @override
  String get controlKey => record(inner.controlKey);

  @override
  String get shiftKey => record(inner.shiftKey);

  @override
  String get exportTitle => record(inner.exportTitle);

  @override
  String get exportAction => record(inner.exportAction);

  @override
  String get cancel => record(inner.cancel);

  @override
  String get searchSymbols => record(inner.searchSymbols);

  @override
  String get clear => record(inner.clear);

  @override
  String get loadingSymbols => record(inner.loadingSymbols);

  @override
  String get symbolsFailed => record(inner.symbolsFailed);

  @override
  String get retry => record(inner.retry);

  @override
  String get tableTitle => record(inner.tableTitle);

  @override
  String get width => record(inner.width);

  @override
  String get height => record(inner.height);

  @override
  String get thickness => record(inner.thickness);

  @override
  String get justifyLeft => record(inner.justifyLeft);

  @override
  String get justifyCentre => record(inner.justifyCentre);

  @override
  String get justifyRight => record(inner.justifyRight);

  @override
  String get position => record(inner.position);

  @override
  String get flipHinge => record(inner.flipHinge);

  @override
  String get flipSwing => record(inner.flipSwing);

  @override
  String get name => record(inner.name);

  @override
  String get area => record(inner.area);

  @override
  String get value => record(inner.value);

  @override
  String get aligned => record(inner.aligned);

  @override
  String get horizontal => record(inner.horizontal);

  @override
  String get vertical => record(inner.vertical);

  @override
  String get end1 => record(inner.end1);

  @override
  String get end2 => record(inner.end2);

  @override
  String get endFixed => record(inner.endFixed);

  @override
  String get leftFace => record(inner.leftFace);

  @override
  String get centreline => record(inner.centreline);

  @override
  String get rightFace => record(inner.rightFace);

  @override
  String get size => record(inner.size);

  @override
  String get rotation => record(inner.rotation);

  @override
  String get mirror => record(inner.mirror);

  @override
  String get number => record(inner.number);

  @override
  String get seats => record(inner.seats);

  @override
  String get rotateLeft => record(inner.rotateLeft);

  @override
  String get rotateRight => record(inner.rotateRight);

  @override
  String get pageTitle => record(inner.pageTitle);

  @override
  String get customSize => record(inner.customSize);

  @override
  String get portrait => record(inner.portrait);

  @override
  String get landscape => record(inner.landscape);

  @override
  String get scale => record(inner.scale);

  @override
  String get grid => record(inner.grid);

  @override
  String get snapToGrid => record(inner.snapToGrid);

  @override
  String get pageBreaks => record(inner.pageBreaks);

  @override
  String get paper => record(inner.paper);

  @override
  String get layersLocked => record(inner.layersLocked);

  @override
  String get selectLayerToDelete => record(inner.selectLayerToDelete);

  @override
  String get layerZeroUndeletable => record(inner.layerZeroUndeletable);

  @override
  String get currentLayerUndeletable => record(inner.currentLayerUndeletable);

  @override
  String get layerInUse => record(inner.layerInUse);

  @override
  String get layers => record(inner.layers);

  @override
  String get newLayer => record(inner.newLayer);

  @override
  String get deleteLayer => record(inner.deleteLayer);

  @override
  String get mixed => record(inner.mixed);

  @override
  String get readOnlyDocument => record(inner.readOnlyDocument);

  @override
  String get plainGroupNoLayer => record(inner.plainGroupNoLayer);

  @override
  String get layer => record(inner.layer);

  @override
  String get moveSelectionToLayer => record(inner.moveSelectionToLayer);

  @override
  String get hiddenLayerNotCurrent => record(inner.hiddenLayerNotCurrent);

  @override
  String get currentLayer => record(inner.currentLayer);

  @override
  String get makeCurrent => record(inner.makeCurrent);

  @override
  String get currentLayerNotHidden => record(inner.currentLayerNotHidden);

  @override
  String get hideLayer => record(inner.hideLayer);

  @override
  String get showLayer => record(inner.showLayer);

  @override
  String get unlockLayer => record(inner.unlockLayer);

  @override
  String get lockLayer => record(inner.lockLayer);

  @override
  String get layerColour => record(inner.layerColour);

  @override
  String get sampleHall => record(inner.sampleHall);

  @override
  String get sampleKitchen => record(inner.sampleKitchen);

  @override
  String get sampleBath => record(inner.sampleBath);

  @override
  String get sampleLiving => record(inner.sampleLiving);

  @override
  String get sampleDining => record(inner.sampleDining);

  @override
  String layerNameProblem(LayerNameProblem problem) =>
      record(inner.layerNameProblem(problem));

  @override
  String tableNumberProblem(TableNumberProblem problem) =>
      record(inner.tableNumberProblem(problem));

  @override
  String tableNumberUsed(String number) =>
      record(inner.tableNumberUsed(number));

  @override
  String numberingWarning(NumberingWarning warning) =>
      record(inner.numberingWarning(warning));

  @override
  String roomOccupied(String name) => record(inner.roomOccupied(name));

  @override
  String selectedCount(int count) => record(inner.selectedCount(count));

  @override
  String dpi(int dpi) => record(inner.dpi(dpi));

  @override
  String noSymbolsMatch(String query) => record(inner.noSymbolsMatch(query));

  @override
  String axesTurned(String degrees) => record(inner.axesTurned(degrees));

  @override
  String endOnWall(String wall, bool atStart, String side) =>
      record(inner.endOnWall(wall, atStart, side));

  @override
  String missingLayer(String hex) => record(inner.missingLayer(hex));

  @override
  String colourName(int aci) => record(inner.colourName(aci));

  @override
  String roomName(int n) => record(inner.roomName(n));

  @override
  String layerName(int n) => record(inner.layerName(n));

  @override
  String sampleBedroom(int n) => record(inner.sampleBedroom(n));
}
