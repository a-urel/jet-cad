/// [v] as the shell shows a stored number: in a Selection panel field, in
/// the Page panel's scale field and in the status line's scale. The text is
/// one the fields' parser (`double.tryParse`) reads back as exactly [v],
/// sign of zero included, so a commit of a shown value writes nothing. A
/// whole number below 2^53 in magnitude shows without ".0" ("200");
/// anything else is Dart's shortest round-trip form ("0.1",
/// "100000000000000000000.0", "1e+300", "-0.0").
///
/// Not `v.round()` (fix/post-11): on the VM it saturates at 2^63 - 1, so
/// 1e20 showed "9223372036854775807". In the Selection panel the focus loss
/// after Enter wrote a second, silent undo step storing 9.22e18; in the
/// Page panel a later Enter on the unchanged text did; the status line
/// read "1:9223372036854775807".
String panelNumberText(double v) => v.abs() < 9007199254740992 && // 2^53
        v == v.truncateToDouble() &&
        !(v == 0 && v.isNegative)
    ? v.toInt().toString()
    : v.toString();
