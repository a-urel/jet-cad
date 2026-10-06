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
}
