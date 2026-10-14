// Spec 12b D9, D10, D11 and 2a spec P2: the Layers section of the right
// panel, over a PlanController. Ported from
// jet_cad_floor_plan/lib/src/layers/layer_panel.dart.
import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PageNotifier, displayPaperFor;

import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/numbered_names.dart';
import '../l10n/strings.dart';
import '../l10n/strings_en.dart';
import '../theme/plan_theme.dart';
import 'layer_row.dart';

/// How many rows the list shows before it scrolls (spec 12b D9: "about
/// six"), so the page panel below keeps its room.
const int kLayerListVisibleRows = 6;

/// [layers] in the panel's order (spec 12b D10): layer 0 first, then the
/// others by name under `toLowerCase()`, ties by handle. Independent of
/// creation order, so stable across undo, save and load.
List<LayerRecord> layersInPanelOrder(Iterable<LayerRecord> layers) {
  final out = layers.toList();
  int rank(LayerRecord r) => r.handle == ReservedHandles.layerZero ? 0 : 1;
  out.sort((a, b) {
    final byZero = rank(a).compareTo(rank(b));
    if (byZero != 0) return byZero;
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return a.handle.value.compareTo(b.handle.value);
  });
  return out;
}

/// The name the panel's + gives a new layer (spec 12b D4, spec 14d L7):
/// [strings]' `Layer N`, the smallest `N ≥ 1` that no layer's name already
/// takes in any built-in language (by `toLowerCase()`, the table's own
/// folding) and that [layerNameError] accepts in [target].
String nextLayerName(CommandTarget target,
    [PlanStrings strings = const PlanStringsEn()]) {
  final used = <int>{
    for (final r in target.tables.layers.records)
      if (numberedNameIndex(r.name, (s, n) => s.layerName(n), strings,
              fold: (s) => s.toLowerCase())
          case final n?)
        n,
  };
  for (var n = 1;; n++) {
    if (used.contains(n)) continue;
    final name = strings.layerName(n);
    if (layerNameError(target, name) == null) return name;
  }
}

/// The Layers section (spec 12b D9) of [controller]'s plan: a collapsible
/// list of every layer, one [LayerRow] each, with + and delete below.
///
/// **No copy of the layers.** Every build reads the controller's document;
/// the panel rebuilds on its `commands.changes`, its `tables.changes`, the
/// page (ACI 7's swatch follows the paper) and the controller (a document
/// swapped by `load`, `newPlan` or `import`, or new permissions), and moves
/// its subscriptions to a swapped-in document.
///
/// **Each user action is exactly one command**, through
/// `controller.execute`, which answers false for a refusal (`PlanLocked`,
/// `DanglingReferenceError`, `ArgumentError`, a kit's failure); a
/// `StateError` is caught here: nothing changed.
///
/// **Permissions:** every control is disabled while the controller's
/// `permissions.editLayers` is false or the document's permissions refuse
/// [Capability.structure] (D11); the list is still shown.
class PlanLayerPanel extends StatefulWidget {
  const PlanLayerPanel({super.key, required this.controller});

  final PlanController controller;

  @override
  State<PlanLayerPanel> createState() => PlanLayerPanelState();
}

class PlanLayerPanelState extends State<PlanLayerPanel> {
  StreamSubscription<DocChange>? _changes;

  /// The document and page notifier the subscriptions are on.
  DraftDocument? _bound;
  PageNotifier? _boundPage;

  /// Whether the list is shown. Per session, not stored.
  bool _open = true;

  /// The selected row's layer (for delete), or null.
  Handle? _selected;

  /// The layer whose name field is open, or null.
  Handle? _editing;

  final ScrollController _scroll = ScrollController();

  /// Whether the list is shown (the header toggles it).
  bool get isOpen => _open;

  /// The selected row's layer, or null.
  Handle? get selected => _selected;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _bind();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanLayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _bind();
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _unbind();
    _scroll.dispose();
    super.dispose();
  }

  /// A new document (load, newPlan, import) or new permissions: rebinds
  /// when the document is another one, rebuilds either way.
  void _onController() {
    if (!identical(_bound, widget.controller.document)) _bind();
    _refresh();
  }

  void _bind() {
    _unbind();
    final document = widget.controller.document;
    _bound = document;
    _changes = document.commands.changes.listen((_) => _refresh());
    document.tables.changes.addListener(_refresh);
    _boundPage = widget.controller.page..addListener(_refresh);
    _selected = null;
    _editing = null;
  }

  void _unbind() {
    _changes?.cancel();
    _changes = null;
    _bound?.tables.changes.removeListener(_refresh);
    _boundPage?.removeListener(_refresh);
    _bound = null;
    _boundPage = null;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  DraftDocument get _doc => widget.controller.document;

  bool get _allowed =>
      widget.controller.permissions.editLayers &&
      _doc.commands.permissions.allows(Capability.structure);

  /// Executes [command] through the controller. A refusal is caught: the
  /// dispatcher, the parametric system or the lock expander rolled it
  /// back, so nothing changed, and no gesture surfaces an exception.
  /// Nothing while the panel may not edit: a menu opened before
  /// `editLayers` was turned off still answers after it.
  void _execute(DraftCommand command) {
    if (!_allowed) return;
    try {
      // False: refused (a lock, which raises the hint, a dangling
      // reference, an ArgumentError, a kit's failure); nothing changed.
      widget.controller.execute(command);
    } on StateError {
      // Refused by the dispatcher: nothing changed.
    }
  }

  /// ACI 7's ink on the paper the canvas shows
  /// (`planner_shell.dart:327-342`): the page's background, a dark
  /// canvas's paper, or the canvas background (the theme's surface) for a
  /// plan without a page.
  int _foreground(BuildContext context) {
    final theme = Theme.of(context);
    final surface =
        PlanTheme.of(context)?.canvasBackground ?? theme.colorScheme.surface;
    return foregroundFor(displayPaperFor(
        page: widget.controller.page.value?.background,
        surface: surface.toARGB32(),
        brightness: theme.brightness));
  }

  /// One [SetLayerCommand] built from layer [h]'s record as the document
  /// holds it now, not as the last build saw it: another command may have
  /// landed since (a rename committed on blur by the same pointer-down,
  /// Task 9 review finding 1). [f] returns null for a no-op; a layer that is
  /// gone dispatches nothing.
  void _update(Handle h, LayerRecord? Function(LayerRecord live) f) {
    final live = _doc.tables.layers[h];
    if (live == null) return;
    final next = f(live);
    if (next != null) _execute(SetLayerCommand(next));
  }

  void _add() {
    final zero = _doc.tables.layers[ReservedHandles.layerZero]!;
    final handle = _doc.handleSeed.next();
    _execute(AddLayerCommand(LayerRecord(
      handle: handle,
      name: nextLayerName(_doc, PlanStrings.of(context)),
      color: const IndexedColor(7),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false,
    )));
    setState(() {
      _selected = handle;
      _editing = handle;
    });
  }

  void _delete(Handle layer) {
    _execute(RemoveLayerCommand(layer));
    setState(() => _selected = null);
  }

  /// Why the selected row cannot be deleted, or null when it can.
  String? _deleteBlocked(Handle? layer, PlanStrings strings) {
    if (layer == null) return strings.selectLayerToDelete;
    if (layer == ReservedHandles.layerZero) {
      return strings.layerZeroUndeletable;
    }
    if (layer == drawingLayer(_doc)) {
      return strings.currentLayerUndeletable;
    }
    if (!layerIsEmpty(_doc, layer)) return strings.layerInUse;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final layers = _doc.tables.layers;
    // A row the document no longer has (an undo, a delete) is neither
    // selected nor being renamed.
    if (_selected != null && !layers.contains(_selected!)) _selected = null;
    if (_editing != null && !layers.contains(_editing!)) _editing = null;
    final allowed = _allowed;
    if (!allowed) _editing = null;
    final current = drawingLayer(_doc);
    final foreground = _foreground(context);
    final rows = layersInPanelOrder(layers.records);
    final title = Theme.of(context).textTheme.titleSmall;
    final strings = PlanStrings.of(context);
    final blocked =
        allowed ? _deleteBlocked(_selected, strings) : strings.layersLocked;
    return Material(
      key: const Key('layers-panel'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: const Key('layers-header'),
              onTap: () => setState(() => _open = !_open),
              child: SizedBox(
                height: 32,
                child: Row(children: [
                  Expanded(child: Text(strings.layers, style: title)),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
                ]),
              ),
            ),
            if (_open) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(
                    maxHeight: kLayerListVisibleRows * kLayerRowHeight),
                child: Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    key: const Key('layers-list'),
                    controller: _scroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final r in rows)
                          LayerRow(
                            key: ValueKey<Handle>(r.handle),
                            controller: widget.controller,
                            record: r,
                            current: r.handle == current,
                            selected: r.handle == _selected,
                            enabled: allowed,
                            editing: r.handle == _editing,
                            foreground: foreground,
                            onSelect: () =>
                                setState(() => _selected = r.handle),
                            onMakeCurrent: r.handle == current &&
                                    _doc.header.currentLayer == r.handle
                                ? null
                                : () =>
                                    _execute(SetCurrentLayerCommand(r.handle)),
                            onToggleVisible: () => _update(r.handle,
                                (l) => l.copyWith(visible: !l.visible)),
                            onToggleLocked: () => _update(
                                r.handle, (l) => l.copyWith(locked: !l.locked)),
                            onColour: (aci) => _update(
                                r.handle,
                                (l) => l.color == IndexedColor(aci)
                                    ? null
                                    : l.copyWith(color: IndexedColor(aci))),
                            onStartRename: () => setState(() {
                              _selected = r.handle;
                              _editing = r.handle;
                            }),
                            validate: (name) => switch (
                                layerNameProblem(_doc, name, self: r.handle)) {
                              null => null,
                              final p =>
                                PlanStrings.of(context).layerNameProblem(p),
                            },
                            onRename: (name) => _update(
                                r.handle, (l) => l.copyWith(name: name)),
                            onEndRename: () {
                              if (_editing == r.handle && mounted) {
                                setState(() => _editing = null);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(children: [
                IconButton(
                  key: const Key('layers-add'),
                  icon: const Icon(Icons.add),
                  iconSize: 18,
                  tooltip: strings.newLayer,
                  visualDensity: VisualDensity.compact,
                  onPressed: allowed ? _add : null,
                ),
                Tooltip(
                  message: blocked ?? strings.deleteLayer,
                  child: IconButton(
                    key: const Key('layers-delete'),
                    icon: const Icon(Icons.delete_outline),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        blocked == null ? () => _delete(_selected!) : null,
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
