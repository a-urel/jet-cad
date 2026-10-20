// Generated from lib/src/l10n/strings.dart (spec 14d L1 as amended,
// V-10; ported from jet_cad_floor_plan/test/l10n/recording_strings.dart):
// a language whose every word is recorded as it is handed out, so a test
// can tell a word the plan library asked for from a literal it did not.
// Regenerate when a member is added: one override per member, a String
// getter as `record(inner.x)`, a method returning String as
// `record(inner.x(...))`, `languageCode` and `decimalSeparator` delegated
// unrecorded.
import 'package:jet_cad_2d/jet_cad_2d.dart' show LayerNameProblem;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/src/l10n/strings.dart';
import 'package:jet_cad_2d_plan/src/units/unit_label.dart'
    show UnitLabelProblem;
import 'package:jet_cad_2d_plan/src/units/unit_problems.dart'
    show UnitLabelWarning;

class RecordingPlanStrings implements PlanStrings {
  RecordingPlanStrings(this.inner);

  final PlanStrings inner;

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
  String layerNameProblem(LayerNameProblem problem) =>
      record(inner.layerNameProblem(problem));

  @override
  String get toolSelect => record(inner.toolSelect);

  @override
  String get toolLine => record(inner.toolLine);

  @override
  String get toolPolyline => record(inner.toolPolyline);

  @override
  String get toolRectangle => record(inner.toolRectangle);

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
  String get openToolsPanel => record(inner.openToolsPanel);

  @override
  String get openPropertiesPanel => record(inner.openPropertiesPanel);

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
  String get newDocument => record(inner.newDocument);

  @override
  String get open => record(inner.open);

  @override
  String get save => record(inner.save);

  @override
  String get saveAs => record(inner.saveAs);

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
  String selectedCount(int count) => record(inner.selectedCount(count));

  @override
  String dpi(int dpi) => record(inner.dpi(dpi));

  @override
  String noSymbolsMatch(String query) => record(inner.noSymbolsMatch(query));

  @override
  String get name => record(inner.name);

  @override
  String get size => record(inner.size);

  @override
  String get rotation => record(inner.rotation);

  @override
  String get mirror => record(inner.mirror);

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
  String get pageDecimalSeparator => record(inner.pageDecimalSeparator);

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
  String get lockedNoLayer => record(inner.lockedNoLayer);

  @override
  String get layer => record(inner.layer);

  @override
  String get color => record(inner.color);

  @override
  String get colorNone => record(inner.colorNone);

  @override
  String get colorRefused => record(inner.colorRefused);

  @override
  String colorName(PlanSwatch swatch) => record(inner.colorName(swatch));

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
  String missingLayer(String hex) => record(inner.missingLayer(hex));

  @override
  String colourName(int aci) => record(inner.colourName(aci));

  @override
  String layerName(int n) => record(inner.layerName(n));

  @override
  String get lockedHint => record(inner.lockedHint);

  @override
  String get sectionFailed => record(inner.sectionFailed);

  @override
  String get planDamaged => record(inner.planDamaged);

  @override
  String get merge => record(inner.merge);
  @override
  String get split => record(inner.split);
  @override
  String get number => record(inner.number);
  @override
  String get label => record(inner.label);
  @override
  String get capacity => record(inner.capacity);
  @override
  String get rotateLeft => record(inner.rotateLeft);
  @override
  String get rotateRight => record(inner.rotateRight);
  @override
  String labelProblem(UnitLabelProblem problem) =>
      record(inner.labelProblem(problem));
  @override
  String labelUsed(String label) => record(inner.labelUsed(label));
  @override
  String labelWarning(UnitLabelWarning warning) =>
      record(inner.labelWarning(warning));
  @override
  String? unitKind(String kind) => switch (inner.unitKind(kind)) {
        null => null,
        final w => record(w),
      };
}
