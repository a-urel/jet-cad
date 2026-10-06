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
}
