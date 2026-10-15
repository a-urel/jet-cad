// The words a property or a section reads through its object (spec 3a
// C1.1, rulings R-P4, R-P7): pure, so the property specs stay free of
// Flutter. KitWords (the plan's view, with its locale) implements it.
//
// Pure Dart: no Flutter, no dart:io.

/// A kit's words at the plan's current locale, as a property reads them.
abstract interface class PlanWords {
  /// The word [wordId] in the locale, else in English, else [wordId] itself
  /// (a missing word shows its id, never nothing).
  String word(String wordId);

  /// The word [wordId] in the locale, else in English, else null.
  String? maybe(String wordId);
}
