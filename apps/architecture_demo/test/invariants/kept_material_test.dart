// DKM1 / DKM2: the demo is shadcn all through; what it keeps of Material is a
// list (empty), not an accident.
//
// DKM1 scans `lib/` (comments and string literals stripped, so prose that
// names `Scaffold` does not count) for every Material widget constructor,
// every `Theme.of(` read and every Material dialog or menu function; each hit
// must be on [kKeptMaterial] (file, exact construct, count, reason). An
// import of `material.dart` must be an explicit `show` of non-widget symbols
// and be on [kKeptImports]. An entry no hit uses is red too (a stale entry).
// DKM2: no `Icons.` (Material's icon set) is left in `lib/`: Lucide only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One kept Material construct: [construct] is the class name (with the
/// named constructor or `.of` that follows it), [count] its uses in [file].
class KeptMaterial {
  const KeptMaterial(this.file, this.construct, this.count, this.reason);

  final String file;
  final String construct;
  final int count;
  final String reason;
}

/// One kept `import 'package:flutter/material.dart' show ...`.
class KeptImport {
  const KeptImport(this.file, this.shown, this.reason);

  final String file;
  final String shown;
  final String reason;
}

/// Every Material construct `lib/` keeps: none.
const List<KeptMaterial> kKeptMaterial = [];

/// Every `material.dart` import `lib/` keeps: only a `show` of non-widgets.
const List<KeptImport> kKeptImports = [
  KeptImport('lib/main.dart', 'ThemeMode',
      'ShadApp.themeMode takes Material\'s ThemeMode enum; no widget comes with it'),
];

/// Material-library widgets, theme reads and dialog / menu functions.
const List<String> _materialNames = [
  'Material',
  'MaterialApp',
  'Scaffold',
  'AppBar',
  'Drawer',
  'AlertDialog',
  'SimpleDialog',
  'Dialog',
  'IconButton',
  'TextButton',
  'ElevatedButton',
  'FilledButton',
  'OutlinedButton',
  'FloatingActionButton',
  'InkWell',
  'InkResponse',
  'Ink',
  'Divider',
  'VerticalDivider',
  'ListTile',
  'CheckboxListTile',
  'SwitchListTile',
  'RadioListTile',
  'Checkbox',
  'Switch',
  'Radio',
  'Slider',
  'DropdownButton',
  'DropdownMenu',
  'DropdownMenuItem',
  'PopupMenuButton',
  'PopupMenuItem',
  'PopupMenuDivider',
  'MenuAnchor',
  'MenuItemButton',
  'SegmentedButton',
  'Tooltip',
  'TextField',
  'TextFormField',
  'InputDecorator',
  'InputDecoration',
  'Chip',
  'ChoiceChip',
  'FilterChip',
  'ActionChip',
  'Card',
  'TabBar',
  'TabBarView',
  'DefaultTabController',
  'CircularProgressIndicator',
  'LinearProgressIndicator',
  'Scrollbar',
  'ScrollbarTheme',
  'SnackBar',
  'BottomSheet',
  'SelectableText',
  'AdaptiveTextSelectionToolbar',
  'Badge',
  'ExpansionTile',
  'ToggleButtons',
  'NavigationBar',
  'NavigationRail',
  'NavigationDrawer',
  'CircleAvatar',
  'SearchBar',
  'Autocomplete',
  'ReorderableListView',
  'RefreshIndicator',
  'Theme',
  'ThemeData',
  'ButtonStyle',
  'MaterialPageRoute',
  'MaterialLocalizations',
  'TextSelectionTheme',
  'ListTileTheme',
  'showDialog',
  'showModalBottomSheet',
  'showMenu',
  'showDatePicker',
  'showTimePicker',
];

final _construct =
    RegExp(r'\b(' '${_materialNames.join('|')}' r')(<[^>()]*>)?(\.\w+)?\(');

final _materialImport =
    RegExp(r'''import\s+['"]package:flutter/material\.dart['"]([^;]*);''');

Map<String, String> _sources(String Function(String) clean) {
  final dir = Directory('lib');
  if (!dir.existsSync()) throw StateError('scanned directory missing: lib');
  return {
    for (final f in dir.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart'))
        f.path.replaceAll(r'\', '/'): clean(f.readAsStringSync()),
  };
}

/// The source without its `//` comments (a comment may name a component).
String _noComments(String text) => text
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

/// Also without single-line string literals (a string may name one).
String _code(String text) => _noComments(text).replaceAll(
    RegExp(r'''r?'(?:\\.|[^'\\\n])*'|r?"(?:\\.|[^"\\\n])*"'''), "''");

void main() {
  final sources = _sources(_code);
  final importSources = _sources(_noComments);

  test('DKM1 every Material construct and import in lib/ is on the list', () {
    // 'file|construct' -> uses.
    final hits = <String, int>{};
    for (final e in sources.entries) {
      for (final m in _construct.allMatches(e.value)) {
        final key = '${e.key}|${m.group(1)}${m.group(3) ?? ''}';
        hits[key] = (hits[key] ?? 0) + 1;
      }
    }
    final kept = {
      for (final k in kKeptMaterial) '${k.file}|${k.construct}': k.count,
    };
    expect(kept.length, kKeptMaterial.length, reason: 'a duplicate entry');
    expect(kKeptMaterial.every((k) => k.reason.length > 20), isTrue,
        reason: 'every entry says why');
    final unlisted = {
      for (final e in hits.entries)
        if (kept[e.key] != e.value)
          e.key: 'found ${e.value}, kept ${kept[e.key]}',
    };
    expect(unlisted, isEmpty, reason: 'a Material construct off the list');
    final unused = [
      for (final k in kept.keys)
        if (!hits.containsKey(k)) k,
    ];
    expect(unused, isEmpty, reason: 'kept but unused (a stale entry)');

    // 'file|shown' for every material.dart import: a bare or `hide` import
    // brings every widget, so it reads as 'file|*'.
    final imports = <String>{};
    for (final e in importSources.entries) {
      for (final m in _materialImport.allMatches(e.value)) {
        final tail = (m.group(1) ?? '').trim();
        final show = RegExp(r'^show\s+([\s\S]*)$').firstMatch(tail);
        final shown = show == null
            ? '*'
            : show.group(1)!.split(',').map((s) => s.trim()).join(', ');
        imports.add('${e.key}|$shown');
      }
    }
    final keptImports = {
      for (final k in kKeptImports) '${k.file}|${k.shown}',
    };
    expect(keptImports.length, kKeptImports.length, reason: 'a duplicate');
    expect(kKeptImports.every((k) => k.reason.length > 20), isTrue,
        reason: 'every import says why');
    expect(imports.difference(keptImports), isEmpty,
        reason: 'a material.dart import off the list (or without `show`)');
    expect(keptImports.difference(imports), isEmpty,
        reason: 'kept import unused (a stale entry)');
  });

  test('DKM2 no Icons. in lib/ (Lucide only)', () {
    final found = [
      for (final e in sources.entries)
        if (e.value.contains(RegExp(r'(?<![A-Za-z])Icons\.'))) e.key,
    ];
    expect(found, isEmpty);
  });
}
