// KM1 / KM2: what the chrome keeps of Material is a list, not an accident.
//
// KM1 scans `lib/` (comments stripped, as `test/l10n/shadcn_words_test.dart`
// does) for every Material widget constructor and every `Theme.of(` read;
// each hit must be on [kKeptMaterial], with the file, the exact construct,
// how many times and why. A hit off the list is a Material part the chrome
// should have moved to its shadcn part; an entry no hit uses is red too.
// KM2: no `Icons.` (Material's icon set) is left in `lib/`.
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

/// Every Material construct `lib/` keeps. Canvas-owned reads: the canvas
/// paints with the Material theme (its background, paper, brightness), the
/// chrome reads `planShadThemeOf`.
const List<KeptMaterial> kKeptMaterial = [
  // The canvas files.
  KeptMaterial('lib/src/canvas/plan_canvas.dart', 'Theme.of', 2,
      'the canvas background, paper and brightness come from the Material theme (SV3)'),
  KeptMaterial('lib/src/canvas/text_entry_overlay.dart', 'TextField', 1,
      'the in-canvas text entry edits a drawing on the canvas, not a chrome field'),
  KeptMaterial('lib/src/canvas/text_entry_overlay.dart', 'Theme.of', 1,
      'the entry\'s fill is the canvas paper, a Material theme read'),
  KeptMaterial('lib/src/canvas/text_entry_overlay.dart', 'InputDecoration', 1,
      'the same in-canvas entry\'s decoration (the Material TextField needs one)'),
  // The Material theme the host sets.
  KeptMaterial('lib/src/theme/plan_theme.dart', 'Theme.of', 2,
      'PlanTheme is a Material ThemeExtension; it is read off the ambient ThemeData'),
  KeptMaterial('lib/src/chrome/shad_scope.dart', 'Theme.of', 2,
      'the shadcn theme is derived from the host\'s Material ThemeData when no ShadTheme is above'),
  // Host slots.
  KeptMaterial('lib/src/chrome/host_slot.dart', 'Material', 1,
      'PlanHostSlot: the transparent Material a host\'s own Material widgets need above them'),
  KeptMaterial('lib/src/panels/plan_property_panel.dart', 'Material', 1,
      'the property panel\'s root is the host slot of the sections a kit or host adds'),
  KeptMaterial('lib/src/panels/plan_page_panel.dart', 'Material', 1,
      'the page panel\'s root is the host slot of whatever a host puts in the panel'),
  KeptMaterial('lib/src/panels/plan_layer_panel.dart', 'Material', 1,
      'the layer panel\'s root is the host slot of the layer field and its menus'),
  KeptMaterial('lib/src/service/view/plan_service_view.dart', 'Material', 1,
      'the service view\'s transparent Material: the host slot of its bar and canvas'),
  // The canvas-owned Theme reads outside lib/src/canvas.
  KeptMaterial('lib/src/service/view/plan_service_view.dart', 'Theme.of', 3,
      'the view\'s canvas background, paper and brightness (SV3) and the PlanTheme extension merge'),
  KeptMaterial('lib/src/editor/plan_editor.dart', 'Theme.of', 1,
      'the editor\'s PlanTheme extension merge for the canvas'),
  KeptMaterial('lib/src/panels/plan_layer_panel.dart', 'Theme.of', 1,
      'the layer swatch ink is computed against the canvas background, a Material read'),
  KeptMaterial('lib/src/panels/plan_property_panel.dart', 'Theme.of', 1,
      'the colour row\'s dark-canvas paper follows the canvas\'s brightness'),
  KeptMaterial('lib/src/editor/editor_layout.dart', 'Theme.of', 1,
      'the drawer scrim: shadcn has no scrim colour'),
  // Parts shadcn has no counterpart for.
  KeptMaterial('lib/src/editor/plan_editor.dart', 'Scaffold', 2,
      'the page frame the editor\'s Overlay, focus and host Material come from'),
  KeptMaterial('lib/src/panels/plan_layer_panel.dart', 'Scrollbar', 1,
      'shadcn has no scrollbar; the layer list keeps the platform one'),
  KeptMaterial('lib/src/panels/plan_layer_panel.dart', 'ScrollbarTheme', 1,
      'colours the layer list\'s Scrollbar with the shadcn border colour'),
  KeptMaterial(
      'lib/src/panels/plan_symbol_gallery.dart',
      'CircularProgressIndicator',
      1,
      'shadcn has no spinner; coloured with the shadcn primary'),
  KeptMaterial(
      'lib/src/chrome/text_field.dart',
      'AdaptiveTextSelectionToolbar.editableText',
      1,
      'the platform selection toolbar of the text field\'s context menu (no shadcn one)'),
  KeptMaterial(
      'lib/src/chrome/text_field.dart',
      'AdaptiveTextSelectionToolbar.buttonItems',
      1,
      'the same toolbar, built from the field\'s own items'),
  KeptMaterial('lib/src/export/export_dialog.dart', 'MaterialLocalizations.of',
      1, 'the dialog barrier\'s dismiss label is the framework\'s own word'),
];

/// Class names of Material-library widgets and theme reads. A hit is a name
/// (with its generic arguments and one named constructor) followed by `(`.
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
  'PopupMenuButton',
  'PopupMenuItem',
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

void main() {
  final sources = _sources();

  test('KM1 every Material construct in lib/ is on kKeptMaterial, none unused',
      () {
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
  });

  test('KM2 no Icons. in lib/ (Lucide only)', () {
    final found = [
      for (final e in sources.entries)
        if (e.value.contains(RegExp(r'(?<![A-Za-z])Icons\.'))) e.key,
    ];
    expect(found, isEmpty);
  });
}
