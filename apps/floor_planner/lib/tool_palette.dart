import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// One palette row and its shortcut (spec 05 D5).
final class PaletteEntry {
  const PaletteEntry({
    required this.keyName,
    required this.label,
    required this.shortcut,
    required this.logicalKey,
    required this.tool,
    required this.drawing,
  });

  final String keyName;
  final String label;
  final String shortcut;
  final LogicalKeyboardKey logicalKey;
  final Tool tool;

  /// A drawing tool: disabled while geometry is denied.
  final bool drawing;
}

/// Spec 05 D5, D13: the tools and the Fill toggle, in the left panel.
///
/// **It never takes focus** (`ExcludeFocus`, Ruling 05-6), so the canvas
/// keeps it and the shell's shortcuts keep working after a click here.
class ToolPalette extends StatelessWidget {
  const ToolPalette({
    super.key,
    required this.entries,
    required this.tools,
    required this.fill,
    required this.geometryAllowed,
    required this.onSelect,
  });

  final List<PaletteEntry> entries;
  final ToolController tools;
  final ValueNotifier<bool> fill;
  final bool geometryAllowed;
  final void Function(Tool tool) onSelect;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
        // Like the page panel: the `chrome-left` slot paints its own
        // background (a `ColoredBox`), so the tiles need a `Material` of
        // their own in between to paint their ink on.
        child: Material(
          color: Colors.transparent,
          child: ListenableBuilder(
            listenable: Listenable.merge([tools, fill]),
            builder: (context, _) => ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final e in entries)
                  ListTile(
                    key: Key(e.keyName),
                    dense: true,
                    selected: identical(tools.active, e.tool),
                    enabled: !e.drawing || geometryAllowed,
                    title: Text(e.label),
                    trailing: Text(e.shortcut),
                    onTap: () => onSelect(e.tool),
                  ),
                const Divider(),
                CheckboxListTile(
                  key: const Key('tool-fill'),
                  dense: true,
                  title: const Text('Fill'),
                  secondary: const Text('F'),
                  value: fill.value,
                  onChanged:
                      geometryAllowed ? (v) => fill.value = v ?? false : null,
                ),
              ],
            ),
          ),
        ),
      );
}
