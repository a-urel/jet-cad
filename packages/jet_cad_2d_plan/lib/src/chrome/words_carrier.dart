// The words contract of the chrome parts (spec "Words (G6)"): a part
// reports every string it can put on screen, so a test can check each
// against the string tables without opening a menu or a popover.

/// A chrome part that knows its own words.
abstract interface class PlanWordsCarrier {
  /// Every string the part can show: its label, tooltip, placeholder, error
  /// and suffix, and the label of every menu entry or option, whether the
  /// menu or popover is open or not.
  Iterable<String> get visibleWords;
}
