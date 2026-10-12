// The Selection panel's Colour row (plan colours spec PC-9): nine
// swatches, None and the palette's eight hues, setting the colour of every
// selected room and table in one undo step. It keeps no state: the panel
// rebuilds it on every selection and document change, as it does the Layer
// picker.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../host/editor_capabilities.dart';
import '../l10n/strings.dart';
import '../parametric/live_objects.dart';
import '../parametric/room.dart';
import '../tables/table_color_component.dart';
import '../tables/table_index.dart';
import 'plan_color.dart';

/// The rooms among [keys], in key order, each once.
List<Handle> _rooms(DraftDocument doc, Iterable<SelectionKey> keys) => [
      for (final h in {for (final k in keys) k.target})
        if (isLiveObject<RoomParams>(doc, h)) h,
    ];

/// The tables among [keys], in key order, each once: a key whose target is
/// a live table's instance (`isTable`: root-level). Per key, with no survey
/// of the document: the panel asks on every build, hover notifications
/// included (14a review R-7).
List<Handle> _tables(DraftDocument doc, Iterable<SelectionKey> keys) {
  if (keys.isEmpty) return const [];
  return [
    for (final h in {for (final k in keys) k.target})
      if (isTable(doc, h)) h,
  ];
}

/// What [pickedColors] lists for a table whose payload is kept: equal to no
/// swatch's name, so it marks nothing and differs from every name.
const String _keptMarker = '\u0001';

/// The colour of each key's object, as the picker reads it: a room's or a
/// table's stored name (null for none; a table whose payload is kept lists
/// a marker that is no swatch's name); rooms first, then tables, each in
/// key order. Keys that are neither are not listed.
List<String?> pickedColors(DraftDocument doc, Iterable<SelectionKey> keys) => [
      for (final h in _rooms(doc, keys))
        doc.components.get<RoomParams>(h)!.color,
      for (final h in _tables(doc, keys))
        switch (doc.components.get<FloorPlanTableColor>(h)) {
          null => null,
          final c when c.isKept => _keptMarker,
          final c => c.name,
        },
    ];

/// The one command that sets [color] (null: none) on every room and table
/// among [keys], labelled 'Colour'; null when none would change.
DraftCommand? recolorCommand(
    DraftDocument doc, Iterable<SelectionKey> keys, FloorPlanColor? color) {
  final name = color?.name;
  final wanted = color == null ? null : FloorPlanTableColor(color);
  final edits = <DraftCommand>[
    for (final h in _rooms(doc, keys))
      if (doc.components.get<RoomParams>(h)! case final p when p.color != name)
        SetComponentCommand<RoomParams>(h, p.copyWith(color: name)),
    for (final h in _tables(doc, keys))
      if (doc.components.get<FloorPlanTableColor>(h) != wanted)
        SetComponentCommand<FloorPlanTableColor>(h, wanted),
  ];
  return edits.isEmpty ? null : CompoundCommand(edits, label: 'Colour');
}

/// Why the picker is read-only for [keys], or null when it acts:
/// `strings.readOnlyDocument` when the permissions refuse `components` or
/// `RoomType().editCapability` for a room among [keys]; the strings'
/// `colorRefused` when [capabilities].recolor is false.
String? colorPickerBlocked(DraftDocument doc, Iterable<SelectionKey> keys,
    FloorPlanEditorCapabilities capabilities, FloorPlanStrings strings) {
  final permissions = doc.commands.permissions;
  if (!permissions.allows(Capability.components) ||
      (_rooms(doc, keys).isNotEmpty &&
          !permissions.allows(const RoomType().editCapability))) {
    return strings.readOnlyDocument;
  }
  if (!capabilities.recolor) return strings.colorRefused;
  return null;
}

/// The swatch colour of [rgb] (PC-9): as the canvas shows it, re-toned on a
/// dark canvas. The one place the planner turns a palette hue into a Color.
Color swatchColor(int rgb, int? darkCanvasPaper) => Color(0xFF000000 |
    (darkCanvasPaper == null
        ? rgb
        : darkCanvasTone(rgb, darkCanvasPaper & 0xFFFFFF)));

class ColorPicker extends StatelessWidget {
  const ColorPicker(
      {super.key,
      required this.document,
      required this.selection,
      required this.capabilities,
      this.darkCanvasPaper});

  final DraftDocument document;
  final SelectionController selection;
  final FloorPlanEditorCapabilities capabilities;

  /// The dark canvas's paper, ARGB, while the canvas re-tones; null on a
  /// light canvas.
  final int? darkCanvasPaper;

  void _choose(FloorPlanColor? color, FloorPlanStrings strings) {
    final keys = selection.keys;
    if (colorPickerBlocked(document, keys, capabilities, strings) != null) {
      return;
    }
    final command = recolorCommand(document, keys, color);
    if (command == null) return;
    try {
      document.commands.execute(command);
    } on ArgumentError {
      // Refused: the dispatcher rolled it back.
    } on StateError {
      // Refused: the dispatcher rolled it back.
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = FloorPlanStrings.of(context);
    final keys = selection.keys;
    final blocked = colorPickerBlocked(document, keys, capabilities, strings);
    final colors = pickedColors(document, keys);
    // The sentinel stands for "mixed": it equals no swatch's name, so no
    // swatch is marked. A stored unknown name equals none either.
    final common = colors.toSet().length == 1 ? colors.first : '\u0000';
    final scheme = Theme.of(context).colorScheme;
    Widget swatch(String key, String label, Color? fill, bool marked,
            VoidCallback onTap) =>
        Tooltip(
          message: blocked ?? label,
          child: Semantics(
            button: true,
            selected: marked,
            enabled: blocked == null,
            label: label,
            child: InkWell(
              key: Key('color-swatch-$key'),
              onTap: blocked == null ? onTap : null,
              customBorder: const CircleBorder(),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: marked ? scheme.primary : scheme.outline,
                      width: marked ? 3 : 1),
                ),
                child: fill == null
                    ? Icon(Icons.block, size: 14, color: scheme.outline)
                    : null,
              ),
            ),
          ),
        );
    return Column(
      key: const Key('color-picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.color),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          swatch('none', strings.colorNone, null, common == null,
              () => _choose(null, strings)),
          for (final c in FloorPlanColor.values)
            swatch(
                c.name,
                strings.colorName(c),
                swatchColor(c.rgb, darkCanvasPaper),
                common == c.name,
                () => _choose(c, strings)),
        ]),
      ],
    );
  }
}
