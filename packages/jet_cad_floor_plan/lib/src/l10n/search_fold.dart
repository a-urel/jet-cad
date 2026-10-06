// The symbol search's fold (spec 14d L11, revision 2): both the query and
// the names are folded, so `kose` finds `Köşe`, `ISIK` finds `ışık`, and
// either language's letters meet. Search only: never applied to a stored
// value.

const Map<String, String> _fold = {
  'ı': 'i',
  '\u0307': '', // the combining dot `İ` lower-cases into
  'ä': 'a',
  'ö': 'o',
  'ü': 'u',
  'ß': 'ss',
  'ğ': 'g',
  'ş': 's',
  'ç': 'c',
  'â': 'a',
  'î': 'i',
  'û': 'u',
};

/// [s] lower-cased and folded: `İ`, `I` and `ı` meet at `i`; the German
/// and Turkish letters meet their plain ones.
String searchFold(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final c = String.fromCharCode(rune);
    out.write(_fold[c] ?? c);
  }
  return out.toString();
}
