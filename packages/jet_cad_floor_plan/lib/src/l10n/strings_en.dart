// The planner's words in English (spec 14d L1): today's literals, byte for
// byte, so English is unchanged on screen.
import 'strings.dart';

/// The planner's words in English.
class FloorPlanStringsEn extends FloorPlanStrings {
  const FloorPlanStringsEn();

  @override
  String get languageCode => 'en';

  @override
  String get decimalSeparator => '.';
}
