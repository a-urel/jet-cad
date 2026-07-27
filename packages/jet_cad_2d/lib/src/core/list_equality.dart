/// Element-wise list comparison, used by every value type in this package that
/// holds a list field.
///
/// One shared helper rather than a private copy per file: the bodies would be
/// identical, and a fix applied to four of five copies is worse than no helper
/// at all.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
