// Spec 2a P2, "The widgets": the generic tools, then each kit's, grouped in
// load order, labelled by tool:<id>; the Fill toggle. Ported from
// jet_cad_floor_plan/lib/src/tool_palette.dart (spec 05 D5, D13): the rows
// come from the controller (planToolEntries) instead of the shell's list.
//
// It never takes focus (ExcludeFocus, Ruling 05-6), so the canvas keeps it
// and the shortcuts keep working after a click here.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kitOfKey;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../chrome/icon_button.dart';
import '../chrome/rows.dart';
import '../chrome/shad_scope.dart';
import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';
import '../shortcuts/tool_letters.dart';
import '../tools/generic_tools.dart';

/// Whether a fill-capable tool is offered (host embedding spec S-9 f): the
/// Fill row and F only then.
bool fillOffered(PlanController controller) =>
    genericTools.any((t) => t.fills && controller.permissions.allowsTool(t.id));

/// [toolId]'s label: the plan library's word for a generic tool, else the
/// kit's `tool:<id>` word in the controller's locale (English where the
/// kit has none), else the id itself.
String planToolLabel(
    BuildContext context, PlanController controller, String toolId) {
  final s = PlanStrings.of(context);
  return switch (toolId) {
    PlanToolIds.select => s.toolSelect,
    PlanToolIds.line => s.toolLine,
    PlanToolIds.polyline => s.toolPolyline,
    PlanToolIds.rectangle => s.toolRectangle,
    PlanToolIds.circle => s.toolCircle,
    PlanToolIds.arc => s.toolArc,
    PlanToolIds.text => s.toolText,
    PlanToolIds.symbol => s.toolSymbol,
    _ => controller
            .namesOf(kitOfKey(toolId))
            ?.word(controller.locale.value.languageCode, 'tool:$toolId') ??
        toolId,
  };
}

/// The tools of [controller] and the Fill toggle. With [compact] the same
/// tools show as icon buttons (the tablet's tool strip), labelled by their
/// tooltips; the keys are the rows'.
class PlanToolPalette extends StatefulWidget {
  const PlanToolPalette(
      {super.key, required this.controller, this.compact = false});

  final PlanController controller;
  final bool compact;

  @override
  State<PlanToolPalette> createState() => _PlanToolPaletteState();
}

class _PlanToolPaletteState extends State<PlanToolPalette> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanToolPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  /// Whether `selectTool(id)` would arm the tool now (Task 12's rule):
  /// made for the current document (a factory that threw leaves its tool
  /// out, spec P4), offered by the permissions, and every need allowed by
  /// the document's engine permissions.
  static bool _enabled(PlanController c, PlanToolEntry e) {
    if (c.isToolDisabled(e.id)) return false;
    if (!c.permissions.allowsTool(e.id)) return false;
    final needs = c.needsOf(e.id);
    if (needs == null) return false;
    final engine = c.document.commands.permissions;
    return needs.every(engine.allows);
  }

  @override
  Widget build(BuildContext context) => PlanShadScope(child: _body(context));

  Widget _body(BuildContext context) {
    final c = widget.controller;
    return ExcludeFocus(
      child: ListenableBuilder(
        // The controller notifies on a permissions change and a document
        // swap (Tasks 8, 12).
        listenable: Listenable.merge([c, c.activeTool, c.fill, c.locale]),
        builder: (context, _) {
          final strings = PlanStrings.of(context);
          final geometry =
              c.document.commands.permissions.allows(Capability.geometry);
          final active = c.activeTool.value;
          final rows = <Widget>[];
          String? group;
          for (final e in planToolEntries(c)) {
            if (group != null && e.kitId != group) {
              rows.add(
                  ShadSeparator.horizontal(key: Key('tool-group-${e.kitId}')));
            }
            group = e.kitId;
            final label = planToolLabel(context, c, e.id);
            if (widget.compact) {
              rows.add(PlanIconButton(
                key: Key('tool-${e.id}'),
                label: label,
                icon: e.icon,
                selected: active == e.id,
                onPressed: _enabled(c, e) ? () => c.selectTool(e.id) : null,
              ));
              continue;
            }
            rows.add(PlanListRow(
              key: Key('tool-${e.id}'),
              leading: Icon(e.icon, size: 18),
              selected: active == e.id,
              onTap: _enabled(c, e) ? () => c.selectTool(e.id) : null,
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(label)),
                if (e.letter != null) ...[
                  const SizedBox(width: 12),
                  Text(e.letter!),
                ],
              ]),
            ));
          }
          if (fillOffered(c) && widget.compact) {
            rows
              ..add(const ShadSeparator.horizontal())
              ..add(PlanIconButton(
                key: const Key('tool-fill'),
                label: strings.fill,
                icon: LucideIcons.paintBucket,
                selected: c.fill.value,
                onPressed: geometry ? () => c.fill.value = !c.fill.value : null,
              ));
          } else if (fillOffered(c)) {
            rows
              ..add(const ShadSeparator.horizontal())
              ..add(Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: [
                  PlanCheckRow(
                    key: const Key('tool-fill'),
                    label: strings.fill,
                    value: c.fill.value,
                    onChanged: geometry ? (v) => c.fill.value = v : null,
                  ),
                  const Spacer(),
                  const Text('F'),
                ]),
              ));
          }
          return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8), children: rows);
        },
      ),
    );
  }
}
