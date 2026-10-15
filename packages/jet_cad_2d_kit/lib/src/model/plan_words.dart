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

  /// The text [id] (a `text:<kit>.<id>` word) in the locale, else in
  /// English, else [id] itself, its `{name}` placeholders filled from
  /// [args] (spec 3a C1.6): `fillText(word(id), args)`.
  String text(String id, [Map<String, Object> args = const {}]);

  /// The decimal separator of the UI language (`.` or `,`), for a number a
  /// kit prints in the UI's words (a dimension's axes line). A number that
  /// follows the page (an area, a dimension's value) reads the page's.
  String get decimalSeparator;
}
