// The planner's words (spec 14d L1, L2, revision 2): one abstract class,
// a member per string -- a getter for a fixed one, a method for one with
// values or a count -- and one implementation per built-in language, so the
// compiler refuses a language that misses a word. A host may subclass a
// language and provide it through its own delegate.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show LayerNameProblem;

import '../host/floor_plan_types.dart' show NumberingWarning;
import '../tables/table_numbers.dart' show TableNumberProblem;

import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_tr.dart';

/// The planner's words in one language.
abstract class FloorPlanStrings {
  const FloorPlanStrings();

  /// The words of [context]'s scope (L2 as amended): those a
  /// [Localizations] scope provides through a
  /// `LocalizationsDelegate<FloorPlanStrings>`, else the built-in language
  /// of the resolved locale, else English. Never throws.
  static FloorPlanStrings of(BuildContext context) =>
      Localizations.of<FloorPlanStrings>(context, FloorPlanStrings) ??
      forLocale(Localizations.maybeLocaleOf(context));

  /// The built-in language for [locale]'s language code, English for any
  /// other (or none).
  static FloorPlanStrings forLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'de' => const FloorPlanStringsDe(),
        'tr' => const FloorPlanStringsTr(),
        _ => const FloorPlanStringsEn(),
      };

  /// The language's code: `en`, `de` or `tr` for the built-in ones.
  String get languageCode;

  /// The decimal separator of the panels' numbers (L12): `.` or `,`.
  String get decimalSeparator;

  // Values the engine and the planner hand out (L6, L5).

  /// Why a name cannot be a layer's.
  String layerNameProblem(LayerNameProblem problem);

  /// Why a text cannot be a table number.
  String tableNumberProblem(TableNumberProblem problem);

  /// A table number already used by another table.
  String tableNumberUsed(String number);

  /// One of the plan's numbering problems.
  String numberingWarning(NumberingWarning warning);

  /// The Room tool's notice: the face already holds a room.
  String roomOccupied(String name);

  // The shell (Task 3): tools, the status line, commands, dialogs.

  /// The Select tool.
  String get toolSelect;

  /// "Line".
  String get toolLine;

  /// "Polyline".
  String get toolPolyline;

  /// "Rectangle".
  String get toolRectangle;

  /// "Box".
  String get toolBox;

  /// "Wall".
  String get toolWall;

  /// "Door".
  String get toolDoor;

  /// "Window".
  String get toolWindow;

  /// "Gap".
  String get toolGap;

  /// "Room".
  String get toolRoom;

  /// "Separator".
  String get toolSeparator;

  /// "Dimension".
  String get toolDimension;

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

  /// The service bar's Merge and Split (table-groups spec G5).
  String get merge;
  String get split;

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

  /// "Table".
  String get tableTitle;

  /// "Width".
  String get width;

  /// "Height".
  String get height;

  /// "Thickness".
  String get thickness;

  /// "Left".
  String get justifyLeft;

  /// "Centre".
  String get justifyCentre;

  /// "Right".
  String get justifyRight;

  /// "Position".
  String get position;

  /// "Flip hinge".
  String get flipHinge;

  /// "Flip swing".
  String get flipSwing;

  /// "Name".
  String get name;

  /// "Area".
  String get area;

  /// "Value".
  String get value;

  /// "Aligned".
  String get aligned;

  /// "Horizontal".
  String get horizontal;

  /// "Vertical".
  String get vertical;

  /// "End 1".
  String get end1;

  /// "End 2".
  String get end2;

  /// "Fixed".
  String get endFixed;

  /// "left face".
  String get leftFace;

  /// "centreline".
  String get centreline;

  /// "right face".
  String get rightFace;

  /// "Size".
  String get size;

  /// "Rotation".
  String get rotation;

  /// "Mirror".
  String get mirror;

  /// "Number".
  String get number;

  /// "Seats".
  String get seats;

  /// "Rotate 90° left".
  String get rotateLeft;

  /// "Rotate 90° right".
  String get rotateRight;

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

  /// A dimension whose axes are turned by [degrees], already formatted.
  String axesTurned(String degrees);

  /// A dimension end on a wall: its handle, its start or end, its side.
  String endOnWall(String wall, bool atStart, String side);

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

  /// "Layer".
  String get layer;

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

  /// A new room's name.
  String roomName(int n);

  /// A new layer's name.
  String layerName(int n);

  /// The sample plan's "Hall".
  String get sampleHall;

  /// The sample plan's "Kitchen".
  String get sampleKitchen;

  /// The sample plan's "Bath".
  String get sampleBath;

  /// The sample plan's "Living".
  String get sampleLiving;

  /// The sample plan's "Dining".
  String get sampleDining;

  /// The sample plan's bedroom [n].
  String sampleBedroom(int n);
}
