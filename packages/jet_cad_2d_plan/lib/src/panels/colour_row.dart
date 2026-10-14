// The property panel's colour row (spec 2a P3, "Colour"; plan colours spec
// PC-9): None and the plan's eight swatches over every selected object
// whose type has a colour target, in one step labelled Colour, gated by
// recolor. Ported from jet_cad_floor_plan/lib/src/colors/color_picker.dart:
// the closed list of rooms and tables (pickedColors, :18-53) becomes the
// types' colour targets (PlanType.colourOf, recolour); the swatches,
// marks, tooltips and semantics are today's. Placed units are today's
// tables (2b Task 10): `jetcad.unit_colour` on the instance.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../controller/plan_controller.dart';
import '../kits/guard.dart' show KitHookFailure;
import '../l10n/strings.dart';
import '../units/unit_components.dart' show UnitColour;
import 'kit_lookup.dart';

typedef ColourTargetOf = ({Handle handle, PlanType<Component> type});

/// The objects among [keys] whose type has a colour target, each once, in
/// key order: live objects (E1) that are not locked (spec P4).
List<ColourTargetOf> colourTargets(
    PlanController c, Iterable<SelectionKey> keys) {
  if (keys.isEmpty) return const [];
  final doc = c.document;
  return [
    for (final h in {for (final k in keys) k.target})
      if (!c.isLocked(h))
        if (c.catalog.typeIdOf(doc, h) case final typeId?)
          if (planTypeOf(c, typeId) case final type? when type.hasColour)
            (handle: h, type: type),
  ];
}

/// The placed units among [keys], each once, in key order, that the lock
/// does not cover (today's `_tables`, colors/color_picker.dart:24-35: a
/// key's target is a placed unit's instance). Per key, read from the
/// controller's cached index: the panel asks on every build, hovers
/// included.
List<Handle> unitColourTargets(PlanController c, Iterable<SelectionKey> keys) {
  if (keys.isEmpty) return const [];
  final index = c.unitIndex;
  return [
    for (final h in {for (final k in keys) k.target})
      if (index[h]?.generated == false && !c.isLocked(h)) h,
  ];
}

/// What [pickedColours] lists for a target whose colour `read` threw:
/// equal to no swatch's name, so it marks nothing.
const String _unreadable = '\u0001';

/// Each target's stored swatch name (null for none), in [colourTargets]'
/// order. A kit's colour `read` that throws (spec P4: every kit hook at the
/// contract's boundary) lists a name that marks nothing and is one
/// `hookFailed` diagnostic, published after the frame (a build reads it).
List<String?> pickedColours(PlanController c, Iterable<SelectionKey> keys) => [
      for (final t in colourTargets(c, keys)) _colourOf(c, t),
      for (final h in unitColourTargets(c, keys))
        switch (c.document.components.get<UnitColour>(h)) {
          null => null,
          // A payload of another shape marks nothing (today's _keptMarker).
          final u => u.name ?? _unreadable,
        },
    ];

String? _colourOf(PlanController c, ColourTargetOf t) {
  try {
    return t.type.colourOf(c.document, t.handle);
  } catch (error) {
    c.diagnosticsLog.addAfterFrame(KitDiagnostic(
        kitId: kitOfKey(t.type.id),
        subject: t.type.id,
        code: KitDiagnosticCode.hookFailed,
        message: 'colour read: $error',
        error: error));
    return _unreadable;
  }
}

/// The one command that sets [swatch] (null: none) on every target among
/// [keys], labelled 'Colour'; null when none would change. A kit's colour
/// `write` that throws is a [KitHookFailure] (hook `colour write`): the
/// recolour is refused whole.
DraftCommand? recolourCommand(
    PlanController c, Iterable<SelectionKey> keys, PlanSwatch? swatch) {
  final doc = c.document;
  final edits = <DraftCommand>[];
  for (final t in colourTargets(c, keys)) {
    final DraftCommand? edit;
    try {
      edit = t.type.recolour(doc, t.handle, swatch?.name);
    } catch (error) {
      throw KitHookFailure(
          kitOfKey(t.type.id), t.type.id, 'colour write', error);
    }
    if (edit != null) edits.add(edit);
  }
  final wanted = swatch == null ? null : UnitColour(swatch);
  for (final h in unitColourTargets(c, keys)) {
    if (doc.components.get<UnitColour>(h) != wanted) {
      edits.add(SetComponentCommand<UnitColour>(h, wanted));
    }
  }
  return edits.isEmpty ? null : CompoundCommand(edits, label: 'Colour');
}

/// Why the row is read-only for [keys], or null when it acts (today's
/// `colorPickerBlocked`, `color_picker.dart:72-86`):
/// [PlanStrings.readOnlyDocument] when the document's permissions refuse
/// `components` or a target type's edit capability; [PlanStrings.colorRefused]
/// when `recolor` is off.
String? colourRowBlocked(
    PlanController c, Iterable<SelectionKey> keys, PlanStrings strings) {
  final p = c.document.commands.permissions;
  if (!p.allows(Capability.components) ||
      colourTargets(c, keys)
          .any((t) => !p.allows(t.type.parametric.editCapability))) {
    return strings.readOnlyDocument;
  }
  if (!c.permissions.recolor) return strings.colorRefused;
  return null;
}

/// The swatch colour of [rgb] (PC-9): as the canvas shows it, re-toned on a
/// dark canvas. The one place the planner turns a palette hue into a Color.
Color swatchColor(int rgb, int? darkCanvasPaper) => Color(0xFF000000 |
    (darkCanvasPaper == null
        ? rgb
        : darkCanvasTone(rgb, darkCanvasPaper & 0xFFFFFF)));

class ColourRow extends StatelessWidget {
  const ColourRow({super.key, required this.controller, this.darkCanvasPaper});

  final PlanController controller;

  /// The dark canvas's paper, ARGB, while the canvas re-tones; null on a
  /// light canvas.
  final int? darkCanvasPaper;

  void _choose(PlanSwatch? swatch, PlanStrings strings) {
    final keys = controller.selection.keys;
    if (colourRowBlocked(controller, keys, strings) != null) return;
    final DraftCommand? command;
    try {
      command = recolourCommand(controller, keys, swatch);
    } on KitHookFailure catch (failure) {
      // Refused (spec P4): nothing is executed; one diagnostic, as
      // execute reports a hook failure.
      controller.diagnosticsLog.add(KitDiagnostic(
          kitId: failure.kitId,
          subject: failure.typeId,
          code: KitDiagnosticCode.hookFailed,
          message: '${failure.hook}: ${failure.error}',
          error: failure.error));
      return;
    }
    // A refusal is caught inside execute (the lock hint, the diagnostic).
    if (command != null) controller.execute(command);
  }

  @override
  Widget build(BuildContext context) {
    final strings = PlanStrings.of(context);
    final keys = controller.selection.keys;
    final blocked = colourRowBlocked(controller, keys, strings);
    final colors = pickedColours(controller, keys);
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
          for (final c in PlanSwatch.values)
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
