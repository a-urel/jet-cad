// Spec 2a P2, "The keyboard": the file commands call the host's callbacks;
// Undo and Redo; F3 for snapping; F for Fill; Escape back to plan.select;
// the tool letters in use. Ported from the shell's bindings
// (jet_cad_floor_plan/lib/src/planner_shell.dart:1444-1469, spec 05 D5,
// 12a D6, host embedding C-5, C-7, S-16, S-26), the capabilities read from
// PlanPermissions. Text fields keep their keys: PlanTextKeys around
// everything (Slice 4 Task 7 finding 1), and PlanShortcutGuard around each
// of the plan's fields (built from planLetterKeys).
import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;

import '../controller/plan_controller.dart';
import '../editor/plan_tool_palette.dart' show fillOffered;
import '../export/editor_page_flows.dart' show exportRunnable;
import '../l10n/locale_scope.dart';
import '../tools/generic_tools.dart';
import 'plan_shortcut_guard.dart';
import 'tool_letters.dart';

/// The plan's keys around [child] (a host's layout of the plan's widgets).
///
/// - [shortcuts] false binds none of them and closes the select tool's
///   idle keys (Delete, Backspace, Escape), so every key reaches the host;
///   a gesture's own keys stay (a drag's Escape, a drawing tool's Escape
///   and Enter, plan.symbol's R and M). The controller's commands stay
///   callable.
/// - The file chords are bound for the callbacks given; a chord whose
///   command cannot act now (a shape part-way; no page for Print; for
///   Export, no page and no exporter that needs none) consumes the key and
///   does nothing (S-26).
class PlanShortcuts extends StatefulWidget {
  const PlanShortcuts({
    super.key,
    required this.controller,
    required this.child,
    this.shortcuts = true,
    this.onNew,
    this.onOpen,
    this.onSave,
    this.onSaveAs,
    this.onExport,
    this.onPrint,
  });

  final PlanController controller;
  final Widget child;
  final bool shortcuts;
  final Future<void> Function()? onNew;
  final Future<void> Function()? onOpen;
  final Future<void> Function()? onSave;
  final Future<void> Function()? onSaveAs;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onPrint;

  @override
  State<PlanShortcuts> createState() => _PlanShortcutsState();
}

class _PlanShortcutsState extends State<PlanShortcuts> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_applyIdleKeys);
    _applyIdleKeys();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_applyIdleKeys);
      widget.controller.addListener(_applyIdleKeys);
      PlanLocaleScope.push(context, widget.controller);
    }
    _applyIdleKeys();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_applyIdleKeys);
    super.dispose();
  }

  /// The select tool's idle keys are the shortcuts (S-16). The gates are
  /// per document, so this runs again after a swap (the controller
  /// notifies).
  void _applyIdleKeys() =>
      widget.controller.selectGates.idleKeys = widget.shortcuts;

  /// Runs a file command when it can act: no shape part-way (spec 12a D6),
  /// and a page for Print (spec 13 D9); for Export a page or an exporter
  /// that needs none (spec 13 D8, P2: with only the built-in exporters,
  /// the page).
  void _run(Future<void> Function() run,
      {bool Function(PlanController c)? can}) {
    final c = widget.controller;
    if (c.toolController.active.isMidShape) return;
    if (can != null && !can(c)) return;
    unawaited(run());
  }

  static bool _hasPage(PlanController c) => c.page.value != null;

  Map<ShortcutActivator, VoidCallback> _bindings(PlanController c) {
    if (!widget.shortcuts) return const {};
    final p = c.permissions;
    final m = <ShortcutActivator, VoidCallback>{};
    void file(List<SingleActivator> chords, Future<void> Function()? run,
        {bool Function(PlanController c)? can}) {
      if (run == null) return;
      for (final chord in chords) {
        m[chord] = () => _run(run, can: can);
      }
    }

    file(kNewChords, widget.onNew);
    file(kOpenChords, widget.onOpen);
    file(kSaveChords, widget.onSave);
    file(kSaveAsChords, widget.onSaveAs);
    if (p.export) file(kExportChords, widget.onExport, can: exportRunnable);
    if (p.print) file(kPrintChords, widget.onPrint, can: _hasPage);
    // Spec P2: widget-facing commands consult the flags; the controller's
    // undo() and redo() do nothing mid-shape.
    if (p.undo) {
      for (final chord in kUndoChords) {
        m[chord] = c.undo;
      }
      for (final chord in kRedoChords) {
        m[chord] = c.redo;
      }
    }
    // Spec 03 D10: one toggle per press, never per key repeat; only while
    // snapping is allowed (S-14). The canvas writes the flag below this
    // widget, inside a build: c.snapping tells this builder after the frame.
    if (c.snappingAllowed) {
      m[const SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false)] =
          c.snap.toggleObjectSnap;
    }
    // Spec 05 D5: the letters, then Fill, then Escape. Only the allowed
    // letters are bound; a refused one bubbles (C-5). A letter the
    // permissions allow stays bound when selectTool would still refuse its
    // tool (a factory that threw, needs the engine denies): the key is
    // consumed and nothing arms, as the shell's under `runtime` (A12),
    // while the palette greys that row.
    for (final e in planToolEntries(c)) {
      final key = e.key;
      if (key != null && p.allowsTool(e.id)) {
        m[SingleActivator(key, includeRepeats: false)] =
            () => c.selectTool(e.id);
      }
    }
    if (fillOffered(c)) {
      m[const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false)] =
          () {
        if (c.document.commands.permissions.allows(Capability.geometry)) {
          c.fill.value = !c.fill.value;
        }
      };
    }
    // An idle drawing tool leaves Escape unhandled; it arrives here.
    m[const SingleActivator(LogicalKeyboardKey.escape)] = () {
      if (c.activeTool.value != PlanToolIds.select) {
        c.selectTool(PlanToolIds.select);
      }
    };
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return PlanTextKeys(
      child: ListenableBuilder(
        // A permissions change, a document swap or the canvas's snapping
        // option rebinds.
        listenable: Listenable.merge([c, c.snapping]),
        builder: (context, child) =>
            CallbackShortcuts(bindings: _bindings(c), child: child!),
        child: widget.child,
      ),
    );
  }
}
