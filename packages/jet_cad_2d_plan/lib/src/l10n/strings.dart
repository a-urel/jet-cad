// The plan library's own words (spec P5 "Words"): one abstract class, a
// member per string -- a getter for a fixed one, a method for one with
// values or a count -- and one implementation per built-in language, so the
// compiler refuses a language that misses a word. A host may subclass a
// language and provide it through its own delegate. Ported from
// jet_cad_floor_plan's FloorPlanStrings (spec 14d L1, L2): its generic
// words; a kit's words come from KitNames (KitWords).
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show LayerNameProblem;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;

import '../units/unit_label.dart' show UnitLabelProblem;
import '../units/unit_problems.dart' show UnitLabelWarning;
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_tr.dart';

/// The plan library's words in one language.
abstract class PlanStrings {
  const PlanStrings();

  /// The words of [context]'s scope: those a [Localizations] scope provides
  /// through a `LocalizationsDelegate<PlanStrings>`, else the built-in
  /// language of the resolved locale, else English. Never throws.
  static PlanStrings of(BuildContext context) =>
      Localizations.of<PlanStrings>(context, PlanStrings) ??
      forLocale(Localizations.maybeLocaleOf(context));

  /// The built-in language for [locale]'s language code, English for any
  /// other (or none).
  static PlanStrings forLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'de' => const PlanStringsDe(),
        'tr' => const PlanStringsTr(),
        _ => const PlanStringsEn(),
      };

  /// The language's code: `en`, `de` or `tr` for the built-in ones.
  String get languageCode;

  /// The decimal separator of the panels' numbers (L12): `.` or `,`.
  String get decimalSeparator;

  // Values the engine and the planner hand out (L6, L5).

  /// Why a name cannot be a layer's.
  String layerNameProblem(LayerNameProblem problem);

  // The shell (Task 3): tools, the status line, commands, dialogs.

  /// The Select tool.
  String get toolSelect;

  /// "Line".
  String get toolLine;

  /// "Polyline".
  String get toolPolyline;

  /// "Rectangle".
  String get toolRectangle;

  /// "Circle".
  String get toolCircle;

  /// "Arc".
  String get toolArc;

  /// "Text".
  String get toolText;

  /// "Symbol".
  String get toolSymbol;

  /// The Fill toggle.
  String get fill;

  /// "Tools".
  String get tabTools;

  /// "Symbols".
  String get tabSymbols;

  /// The phone bar's left button: "Tools and symbols".
  String get openToolsPanel;

  /// The bar's right button: "Properties".
  String get openPropertiesPanel;

  /// "OSNAP".
  String get objectSnapOn;

  /// "osnap off".
  String get objectSnapOff;

  /// "Edited".
  String get edited;

  /// "Undo".
  String get undo;

  /// "Redo".
  String get redo;

  /// The host's file commands (2a spec P2, `PlanEditor(onNew:, onOpen:,
  /// onSave:, onSaveAs:)`), as the floor planner app words them: "New".
  String get newDocument;

  /// "Open…".
  String get open;

  /// "Save".
  String get save;

  /// "Save As…".
  String get saveAs;

  /// "Export…".
  String get exportEllipsis;

  /// "Print…".
  String get printEllipsis;

  /// The Control key in a shortcut.
  String get controlKey;

  /// The Shift key in a shortcut.
  String get shiftKey;

  /// "Export".
  String get exportTitle;

  /// "Export".
  String get exportAction;

  /// "Cancel".
  String get cancel;

  /// "Search symbols".
  String get searchSymbols;

  /// "Clear".
  String get clear;

  /// "Loading symbols…".
  String get loadingSymbols;

  /// "The symbols could not be loaded.".
  String get symbolsFailed;

  /// "Retry".
  String get retry;

  /// The status line's selection count.
  String selectedCount(int count);

  /// A resolution in the Export dialog.
  String dpi(int dpi);

  /// A search that matches no symbol.
  String noSymbolsMatch(String query);

  // The panels (Task 4).

  /// "Name".
  String get name;

  /// "Size".
  String get size;

  /// "Rotation".
  String get rotation;

  /// "Mirror".
  String get mirror;

  /// "Page".
  String get pageTitle;

  /// "Custom".
  String get customSize;

  /// "Portrait".
  String get portrait;

  /// "Landscape".
  String get landscape;

  /// "Scale".
  String get scale;

  /// "Grid".
  String get grid;

  /// "Snap to grid".
  String get snapToGrid;

  /// "Page breaks".
  String get pageBreaks;

  /// "Decimal separator": the caption of the page's own separator, the
  /// one the plan's text prints with (not [decimalSeparator]).
  String get pageDecimalSeparator;

  /// "Paper".
  String get paper;

  // The layer panel, row and picker (Task 4).

  /// "Layers cannot be changed in this document".
  String get layersLocked;

  /// "Select a layer to delete it".
  String get selectLayerToDelete;

  /// "Layer 0 cannot be deleted".
  String get layerZeroUndeletable;

  /// "The current layer cannot be deleted".
  String get currentLayerUndeletable;

  /// "This layer is in use".
  String get layerInUse;

  /// "Layers".
  String get layers;

  /// "New layer".
  String get newLayer;

  /// "Delete layer".
  String get deleteLayer;

  /// "Mixed".
  String get mixed;

  /// "Read-only document".
  String get readOnlyDocument;

  /// "A plain group has no layer: it cannot be moved".
  String get plainGroupNoLayer;

  /// The layer picker's reason when a locked object is in the selection
  /// (2a spec P4: a lock loses a layer change).
  String get lockedNoLayer;

  /// "Layer".
  String get layer;

  /// The Colour picker's title (plan colours spec PC-9).
  String get color;

  /// The picker's swatch for no colour.
  String get colorNone;

  /// The picker's tooltip when the host refuses `recolor`.
  String get colorRefused;

  /// [swatch]'s name, for its swatch's tooltip and semantics label.
  String colorName(PlanSwatch swatch);

  /// "Move the selection to a layer".
  String get moveSelectionToLayer;

  /// "A hidden layer cannot be current".
  String get hiddenLayerNotCurrent;

  /// "Current layer".
  String get currentLayer;

  /// "Make current".
  String get makeCurrent;

  /// "The current layer cannot be hidden".
  String get currentLayerNotHidden;

  /// "Hide layer".
  String get hideLayer;

  /// "Show layer".
  String get showLayer;

  /// "Unlock layer".
  String get unlockLayer;

  /// "Lock layer".
  String get lockLayer;

  /// "Layer colour".
  String get layerColour;

  /// A layer the document does not have, by its handle.
  String missingLayer(String hex);

  /// The name of ACI colour [aci], 1 to 9, in the colour menu.
  String colourName(int aci);

  // Names written into the document once (Task 5, L7).

  /// A new layer's name.
  String layerName(int n);

  // The plan library's own notices (sub-project 2a).

  /// The canvas's short hint when an edit would change a locked object
  /// (spec P4 "Locks").
  String get lockedHint;

  /// What stands in a property section whose kit code failed (spec P4
  /// "The failure boundary").
  String get sectionFailed;

  /// The warning a damaged plan shows (spec P4: a rollback that threw).
  String get planDamaged;

  // The units and the service mode (sub-project 2b).

  /// The service bar's Merge.
  String get merge;

  /// The service bar's Split.
  String get split;

  /// The label field's title for a numbered unit ("Number").
  String get number;

  /// The label field's title for an assigned unit ("Label").
  String get label;

  /// The capacity read-out's title (today's "Seats").
  String get capacity;

  /// "Rotate 90° left".
  String get rotateLeft;

  /// "Rotate 90° right".
  String get rotateRight;

  /// Why a text cannot be a unit's label (the text rule).
  String labelProblem(UnitLabelProblem problem);

  /// A label another unit already holds.
  String labelUsed(String label);

  /// One of the plan's labelling problems.
  String labelWarning(UnitLabelWarning warning);

  /// The contract's unit kinds' words: `table` and `seat`; null for any
  /// other kind (a kit words its own, `unit:<kit>/<kind>`).
  String? unitKind(String kind);
}
