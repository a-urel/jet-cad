// The words rules of the shadcn chrome (spec "Words (G6)"): the text
// field is the one place a `ShadInput` is built, with the library's
// adaptive text toolbar and no keyboard toolbar; the components that would
// bring their own words (search, date and time pickers, calendar) are not
// used; every shadcn identifier in `lib/` is on a list this test holds, so
// a new one is a decision.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every shadcn identifier the library's source uses. An entry that no
/// longer appears in `lib/` is red too, as in `theme_colours_test.dart`.
const List<String> kAllowedShad = [
  'ShadButton',
  'ShadCheckbox',
  'ShadCheckboxTheme',
  'ShadColorScheme',
  'ShadContextMenu',
  'ShadContextMenuController',
  'ShadContextMenuItem',
  'ShadDialog',
  'ShadDialogRoute',
  // A tooltip's touch strategy (1.0.2): no words.
  'ShadHoverStrategies',
  'ShadHoverStrategy',
  'ShadIconButton',
  'ShadInput',
  'ShadMouseAreaSurface',
  'ShadMouseCursorProvider',
  'ShadOption',
  'ShadPopoverController',
  'ShadSelect',
  'ShadSelectController',
  'ShadSeparator',
  'ShadSwitch',
  'ShadSwitchTheme',
  'ShadTextTheme',
  'ShadTheme',
  'ShadThemeData',
  'ShadTooltip',
  'LucideIcons',
];

Map<String, String> _sources() {
  final dir = Directory('lib');
  if (!dir.existsSync()) throw StateError('scanned directory missing: lib');
  return {
    for (final f in dir.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart'))
        f.path.replaceAll(r'\', '/'): _code(f.readAsStringSync()),
  };
}

/// The source without its `//` comments: a comment may name a component.
String _code(String text) => text
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

const _textField = 'lib/src/chrome/text_field.dart';

void main() {
  final sources = _sources();

  test('SW1 every ShadInput( in lib/ is inside lib/src/chrome/text_field.dart',
      () {
    final outside = [
      for (final e in sources.entries)
        if (e.key != _textField && e.value.contains(RegExp(r'\bShadInput\(')))
          e.key,
    ];
    expect(outside, isEmpty);
    expect(sources[_textField], contains('ShadInput('),
        reason: 'the one place builds it');
  });

  test(
      'SW2 text_field.dart passes contextMenuBuilder and no keyboardToolbarBuilder',
      () {
    final text = sources[_textField]!;
    expect(text, contains('contextMenuBuilder:'));
    expect(text, isNot(contains('keyboardToolbarBuilder')));
  });

  test('SW5 ShadTooltip( appears only under lib/src/chrome/', () {
    final outside = [
      for (final e in sources.entries)
        if (!e.key.startsWith('lib/src/chrome/') &&
            e.value.contains(RegExp(r'\bShadTooltip\b')))
          e.key,
    ];
    expect(outside, isEmpty);
    expect(sources.entries.any((e) => e.value.contains('ShadTooltip(')), isTrue,
        reason: 'the chrome builds it');
  });

  test(
      'SW3 no withSearch, ShadDatePicker, ShadTimePicker, ShadCalendar in lib/',
      () {
    final found = [
      for (final e in sources.entries)
        for (final w in [
          'withSearch',
          'ShadDatePicker',
          'ShadTimePicker',
          'ShadCalendar'
        ])
          if (e.value.contains(w)) '${e.key}: $w',
    ];
    expect(found, isEmpty);
  });

  test('SW4 every shadcn identifier used in lib/ is in kAllowedShad', () {
    final used = <String>{};
    for (final text in sources.values) {
      for (final m
          in RegExp(r'\b(Shad[A-Z]\w*|LucideIcons)\b').allMatches(text)) {
        used.add(m.group(0)!);
      }
    }
    expect(used.difference(kAllowedShad.toSet()), isEmpty,
        reason: 'used but not allowed');
    expect(kAllowedShad.toSet().difference(used), isEmpty,
        reason: 'allowed but unused (a stale entry)');
    expect(kAllowedShad.toSet().length, kAllowedShad.length,
        reason: 'duplicate entry');
  });
}
