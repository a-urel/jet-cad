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
}
