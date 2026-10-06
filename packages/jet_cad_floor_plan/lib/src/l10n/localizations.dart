// The planner's localizations (spec 14d L2, revision 2): its delegate, the
// locales it speaks, and the delegates a host's MaterialApp lists for them.
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'strings.dart';

/// The locales the planner speaks: English, German, Turkish.
const List<Locale> floorPlanSupportedLocales = [
  Locale('en'),
  Locale('de'),
  Locale('tr'),
];

/// The planner's delegate and Flutter's three, for a host's
/// `MaterialApp.localizationsDelegates` (V-4: a host that lists `de` or
/// `tr` in `supportedLocales` needs Flutter's, or Material widgets throw).
const List<LocalizationsDelegate<Object>> floorPlanLocalizationsDelegates = [
  FloorPlanLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The planner's [LocalizationsDelegate]: the built-in language of the
/// resolved locale, English for any other. Optional: without it,
/// [FloorPlanStrings.of] picks the same language from the locale.
abstract final class FloorPlanLocalizations {
  static const LocalizationsDelegate<FloorPlanStrings> delegate =
      _FloorPlanStringsDelegate();
}

final class _FloorPlanStringsDelegate
    extends LocalizationsDelegate<FloorPlanStrings> {
  const _FloorPlanStringsDelegate();

  /// Every locale: an unknown one is answered in English.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FloorPlanStrings> load(Locale locale) =>
      SynchronousFuture(FloorPlanStrings.forLocale(locale));

  @override
  bool shouldReload(_FloorPlanStringsDelegate old) => false;
}
