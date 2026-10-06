// The panels' numbers in a language (spec 14d L12, L15, revision 2): the
// language's decimal separator, never a grouping; the parser strict about
// the separator, but tolerant of the other one where a device's keyboard
// offers only that one and nothing can be misread (V-12).
import '../panel_number.dart';
import 'strings.dart';

/// [v] as [panelNumberText] shows it, with [strings]' decimal separator.
String formatPanelNumber(double v, FloorPlanStrings strings) {
  final text = panelNumberText(v);
  final sep = strings.decimalSeparator;
  return sep == '.' ? text : text.replaceAll('.', sep);
}

final RegExp _threeDigits = RegExp(r'^[0-9]{3}$');

/// [text] read as a number in [strings]' language, or null (V-12): the
/// language's separator; or the other one, when it occurs once, the
/// language's does not occur, and it is not followed by exactly three
/// digits -- `1.5` is 1.5 in German, `1.600` is refused, as `1,600` is in
/// English. Otherwise as `double.tryParse` reads it.
double? parsePanelNumber(String text, FloorPlanStrings strings) {
  final own = strings.decimalSeparator;
  final other = own == '.' ? ',' : '.';
  var t = text.trim();
  if (t.contains(other)) {
    final parts = t.split(other);
    if (parts.length != 2 || t.contains(own)) return null;
    if (_threeDigits.hasMatch(parts[1])) return null;
    t = '${parts[0]}.${parts[1]}';
  } else if (own != '.') {
    t = t.replaceAll(own, '.');
  }
  return double.tryParse(t);
}
