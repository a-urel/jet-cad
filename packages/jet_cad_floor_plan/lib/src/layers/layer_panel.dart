// Spec 12b D9, D10, D11: the Layers section of the right panel.
import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../l10n/strings.dart';
import 'layer_row.dart';

/// How many rows the list shows before it scrolls (spec 12b D9: "about
/// six"), so the page panel below keeps its room.
const int kLayerListVisibleRows = 6;

/// The disabled delete button's tooltip when the permissions forbid
/// `Capability.structure` (spec 12b D11). Neutral, not "read-only": under
/// the `runtime` preset the Selection section's layer picker still moves
/// things (Task 10 review info 6).
const String kLayersLocked = 'Layers cannot be changed in this document';

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

/// The name the panel's + gives a new layer (spec 12b D4): `Layer N`, the
/// smallest `N ≥ 1` that [layerNameError] accepts in [target].
String nextLayerName(CommandTarget target) {
  for (var n = 1;; n++) {
    final name = 'Layer $n';
    if (layerNameError(target, name) == null) return name;
  }
}

/// The Layers section (spec 12b D9): a collapsible list of every layer of
/// [document], one [LayerRow] each, with + and delete below.
///
/// **No copy of the layers.** Every build reads `document.tables.layers`
/// and `drawingLayer(document)`; the panel rebuilds on
/// `document.commands.changes` (every edit is a command) and on
/// `document.tables.changes` (a direct table write, which the engine
/// allows). Both subscriptions are removed on dispose, and moved when the
/// widget is handed another document.
///
/// **Each user action is exactly one command** through
/// `document.commands.execute`; a rename is one [SetLayerCommand] at
/// commit, never per keystroke. No widget here writes a table or the
/// header.
///
/// **Permissions** are read from `document.commands.permissions` (R-17):
/// without [Capability.structure] every control is disabled and nothing is
/// dispatched (D11, M-12a); the list is still shown, and the header still
/// collapses it.
///
/// **Delete** is enabled only when the selected row's layer is empty
/// ([layerIsEmpty], D5) — computed for that one row only — with a tooltip
/// giving the reason otherwise.
///
/// [foreground] is the paper's foreground, `0xRRGGBB`: ACI 7's swatch is
/// drawn in it, as the style resolver draws the layer.
class LayerPanel extends StatefulWidget {
  const LayerPanel(
      {super.key, required this.document, this.foreground = 0x000000});

  final DraftDocument document;
  final int foreground;

  @override
  State<LayerPanel> createState() => LayerPanelState();
}

class LayerPanelState extends State<LayerPanel> {
  StreamSubscription<DocChange>? _changes;

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
    _subscribe(widget.document);
  }

  @override
  void didUpdateWidget(LayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.document, widget.document)) {
      _unsubscribe(oldWidget.document);
      _subscribe(widget.document);
      _selected = null;
      _editing = null;
    }
  }

  @override
  void dispose() {
    _unsubscribe(widget.document);
    _scroll.dispose();
    super.dispose();
  }

  void _subscribe(DraftDocument document) {
    _changes = document.commands.changes.listen((_) => _refresh());
    document.tables.changes.addListener(_refresh);
  }

  void _unsubscribe(DraftDocument document) {
    _changes?.cancel();
    _changes = null;
    document.tables.changes.removeListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  DraftDocument get _doc => widget.document;

  bool get _allowed => _doc.commands.permissions.allows(Capability.structure);

  /// Executes [command]. A refusal is caught as the Selection section's
  /// commits and `LayerPicker` catch one: the dispatcher has rolled it back,
  /// so nothing changed, and no gesture surfaces an exception (a control
  /// enabled from a state the panel has not rebuilt for yet, final review
  /// finding 1).
  void _execute(DraftCommand command) {
    try {
      _doc.commands.execute(command);
    } on ArgumentError {
      // Refused: nothing changed.
    } on StateError {
      // Refused: nothing changed.
    }
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
      name: nextLayerName(_doc),
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
  String? _deleteBlocked(Handle? layer, FloorPlanStrings strings) {
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
    final rows = layersInPanelOrder(layers.records);
    final title = Theme.of(context).textTheme.titleSmall;
    final strings = FloorPlanStrings.of(context);
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
                            record: r,
                            current: r.handle == current,
                            selected: r.handle == _selected,
                            enabled: allowed,
                            editing: r.handle == _editing,
                            foreground: widget.foreground,
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
                              final p => FloorPlanStrings.of(context)
                                  .layerNameProblem(p),
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
