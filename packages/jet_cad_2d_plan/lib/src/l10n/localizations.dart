// The plan library's localizations (spec P5 "Words"; ported from
// jet_cad_floor_plan's localizations.dart, spec 14d L2): its delegate, the
// locales it speaks, and the delegates a host's MaterialApp lists for them.
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'strings.dart';

/// The locales the plan library speaks: English, German, Turkish.
const List<Locale> planSupportedLocales = [
  Locale('en'),
  Locale('de'),
  Locale('tr'),
];

/// The plan library's delegate and Flutter's three, for a host's
/// `MaterialApp.localizationsDelegates` (a host that lists `de` or `tr` in
/// `supportedLocales` needs Flutter's, or Material widgets throw).
const List<LocalizationsDelegate<Object>> planLocalizationsDelegates = [
  PlanLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The plan library's [LocalizationsDelegate]: the built-in language of the
/// resolved locale, English for any other. Optional: without it,
/// [PlanStrings.of] picks the same language from the locale.
abstract final class PlanLocalizations {
  static const LocalizationsDelegate<PlanStrings> delegate =
      _PlanStringsDelegate();
}

final class _PlanStringsDelegate extends LocalizationsDelegate<PlanStrings> {
  const _PlanStringsDelegate();

  /// Every locale: an unknown one is answered in English.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<PlanStrings> load(Locale locale) =>
      SynchronousFuture(PlanStrings.forLocale(locale));

  @override
  bool shouldReload(_PlanStringsDelegate old) => false;
}
