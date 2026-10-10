import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'l10n/strings.dart';

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

  /// The row's words in a language (spec 14d L5): read at build.
  final String Function(FloorPlanStrings strings) label;
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
    this.showFill = true,
    this.toolChanges,
  });

  final List<PaletteEntry> entries;
  final ToolController tools;

  /// What the rows rebuild on for the active tool: [tools] when null. The
  /// shell passes a relay of it that holds a notification sent during a
  /// build until after the frame (Task 4 review R-2).
  final Listenable? toolChanges;
  final ValueNotifier<bool> fill;
  final bool geometryAllowed;
  final void Function(Tool tool) onSelect;

  /// Whether the Fill row shows (host embedding API spec S-9 f): false
  /// while no fill-capable tool is offered. Its divider goes with it.
  final bool showFill;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
        // Like the page panel: the `chrome-left` slot paints its own
        // background (a `ColoredBox`), so the tiles need a `Material` of
        // their own in between to paint their ink on.
        child: Material(
          color: Colors.transparent,
          child: ListenableBuilder(
            listenable: Listenable.merge([toolChanges ?? tools, fill]),
            builder: (context, _) {
              final strings = FloorPlanStrings.of(context);
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final e in entries)
                    ListTile(
                      key: Key(e.keyName),
                      dense: true,
                      selected: identical(tools.active, e.tool),
                      enabled: !e.drawing || geometryAllowed,
                      title: Text(e.label(strings)),
                      trailing: Text(e.shortcut),
                      onTap: () => onSelect(e.tool),
                    ),
                  if (showFill) ...[
                    const Divider(),
                    CheckboxListTile(
                      key: const Key('tool-fill'),
                      dense: true,
                      title: Text(strings.fill),
                      secondary: const Text('F'),
                      value: fill.value,
                      onChanged: geometryAllowed
                          ? (v) => fill.value = v ?? false
                          : null,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      );
}
