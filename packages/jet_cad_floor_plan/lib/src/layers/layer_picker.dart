import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings.dart';
import '../parametric/box.dart';
import '../parametric/dimension.dart';
import '../parametric/live_objects.dart';
import '../parametric/opening.dart';
import '../parametric/room.dart';
import '../parametric/separator.dart';
import '../parametric/wall.dart';
import 'layer_panel.dart' show layersInPanelOrder;

/// Whether [h] is a live parametric object of one of the floor planner's
/// registered types (`parametricCatalog`), by the engine's own rule
/// ([isLiveObject]): a root-level group carrying a registered component.
///
/// **This list must name every type `parametricCatalog` registers**: the
/// engine has no "any registered type" query yet. A type left out is
/// treated as a plain group, so the picker is disabled for it.
bool isParametricObject(DraftDocument doc, Handle h) =>
    isLiveObject<BoxParams>(doc, h) ||
    isLiveObject<WallParams>(doc, h) ||
    isLiveObject<OpeningParams>(doc, h) ||
    isLiveObject<SeparatorParams>(doc, h) ||
    isLiveObject<RoomParams>(doc, h) ||
    isLiveObject<DimensionParams>(doc, h);

/// The instance that owns entity [slot] (an ATTRIB, spec 12b S-14), or null.
InstanceNode? _owningInstance(DraftDocument doc, int slot) {
  final owner = doc.tree[doc.entities.ownerAt(slot)];
  return owner is InstanceNode ? owner : null;
}

/// The boundary a fill at [slot] names, when that boundary exists, or null.
Handle? _boundaryOfFill(DraftDocument doc, int slot) {
  final entities = doc.entities;
  if (entities.kindAt(slot) != EntityKind.fill) return null;
  final b = boundaryHandleOf(doc.geometry.peek(entities.geomIndexAt(slot)));
  return entities.slotOf(b) == null ? null : b;
}

/// Key [key]'s layer as the picker shows it (spec 12b D12), or null for a
/// plain group or a key that no longer resolves:
///
/// - an instance's own layer;
/// - an ATTRIB's: its owning instance's;
/// - a parametric object's: its `objectLayer`;
/// - a drafted region's: its boundary's, whichever record was picked;
/// - any other root entity's: its own.
Handle? layerOfKey(DraftDocument doc, SelectionKey key) {
  final h = key.target;
  final node = doc.tree[h];
  if (node is InstanceNode) return node.layer;
  if (node is GroupNode) {
    return isParametricObject(doc, h) ? objectLayer(doc, h) : null;
  }
  if (node != null) return null;
  final entities = doc.entities;
  final slot = entities.slotOf(h);
  if (slot == null) return null;
  if (_owningInstance(doc, slot) case final owner?) return owner.layer;
  final boundary = _boundaryOfFill(doc, slot);
  return entities.layerAt(boundary == null ? slot : entities.slotOf(boundary)!);
}

/// Why the picker is disabled for [keys] in [doc], or null when it is
/// enabled: a permission set without `Capability.components` (D11), or a
/// plain group among the keys (D12).
/// In [strings]' language (spec 14d); English by default, the constants
/// above.
String? layerPickerBlocked(DraftDocument doc, Iterable<SelectionKey> keys,
    [FloorPlanStrings strings = const FloorPlanStringsEn()]) {
  if (!doc.commands.permissions.allows(Capability.components)) {
    return strings.readOnlyDocument;
  }
  for (final k in keys) {
    final node = doc.tree[k.target];
    if (node is GroupNode && !isParametricObject(doc, k.target)) {
      return strings.plainGroupNoLayer;
    }
  }
  return null;
}

/// The one command that moves [keys] to [layer] (spec 12b D12), or null
/// when every member is already on it. Read from [doc] as it is now.
///
/// Per key:
/// - a root entity: `SetEntityLayerCommand`; a drafted region moves every
///   record of it — from a fill, its boundary and every fill naming that
///   boundary; from a boundary, every fill in `fills.fillsOf(boundary)`;
/// - an ATTRIB: its owning instance, which then moves as below;
/// - an instance: `SetInstanceLayerCommand`;
/// - a parametric object: `SetComponentCommand<ObjectLayer>`.
///
/// Each member is moved once — the entity records first, then the
/// instances, then the objects, each in key order; a member already on [layer]
/// (exact `==` on the stored value; an object without an `ObjectLayer` is
/// on layer 0) is skipped. One member left is its command alone; more are
/// one `CompoundCommand`: one undo step either way. A plain group is not a
/// member (the picker is disabled for it, [layerPickerBlocked]).
DraftCommand? layerMoveCommand(
    DraftDocument doc, Iterable<SelectionKey> keys, Handle layer) {
  final entities = <Handle>{};
  final instances = <Handle>{};
  final objects = <Handle>{};
  final store = doc.entities;
  for (final k in keys) {
    final h = k.target;
    final node = doc.tree[h];
    if (node is InstanceNode) {
      instances.add(h);
      continue;
    }
    if (node is GroupNode) {
      if (isParametricObject(doc, h)) objects.add(h);
      continue;
    }
    if (node != null) continue;
    final slot = store.slotOf(h);
    if (slot == null) continue;
    if (_owningInstance(doc, slot) case final owner?) {
      instances.add(owner.handle);
      continue;
    }
    final boundary = _boundaryOfFill(doc, slot) ?? h;
    entities
      ..add(boundary)
      ..addAll(doc.fills.fillsOf(boundary));
    if (boundary != h) entities.add(h);
  }
  final commands = <DraftCommand>[
    for (final e in entities)
      if (store.layerAt(store.slotOf(e)!) != layer)
        SetEntityLayerCommand(e, layer),
    for (final i in instances)
      if ((doc.tree[i]! as InstanceNode).layer != layer)
        SetInstanceLayerCommand(i, layer),
    for (final o in objects)
      if ((doc.components.get<ObjectLayer>(o)?.layer ??
              ReservedHandles.layerZero) !=
          layer)
        SetComponentCommand<ObjectLayer>(o, ObjectLayer(layer)),
  ];
  return switch (commands.length) {
    0 => null,
    1 => commands.single,
    _ => CompoundCommand(commands, label: 'Move to layer'),
  };
}

/// Spec 12b D12: the Selection section's layer menu. It shows the
/// selection's common layer ([layerOfKey]), or the strings' `mixed`;
/// choosing a layer dispatches [layerMoveCommand]'s one command, built from
/// the document and the selection as they are at the choice, not at the
/// last build.
///
/// Disabled, with the reason as its tooltip, when [layerPickerBlocked]
/// says so. Moving to a hidden or locked layer is allowed: the moved keys
/// then leave the selection (the render package's D8 prune).
///
/// It keeps no state: [SelectionPanel] rebuilds it on every selection and
/// document change.
class LayerPicker extends StatelessWidget {
  const LayerPicker(
      {super.key, required this.document, required this.selection});

  final DraftDocument document;
  final SelectionController selection;

  void _choose(Handle layer) {
    final keys = selection.keys;
    if (keys.isEmpty || layerPickerBlocked(document, keys) != null) return;
    if (document.tables.layers[layer] == null) return;
    final command = layerMoveCommand(document, keys, layer);
    if (command == null) return;
    // A refused edit (a regeneration that throws on a broken file) is
    // caught as the Selection section's other commits catch one: the
    // dispatcher has rolled it back, so nothing changed.
    try {
      document.commands.execute(command);
    } on ArgumentError {
      // Refused: nothing changed.
    } on StateError {
      // Refused: nothing changed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = selection.keys;
    final strings = FloorPlanStrings.of(context);
    final blocked = layerPickerBlocked(document, keys, strings);
    Handle? common;
    var mixed = false;
    for (final k in keys) {
      final l = layerOfKey(document, k);
      if (l == null) continue;
      if (common == null) {
        common = l;
      } else if (common != l) {
        mixed = true;
        break;
      }
    }
    final layers = document.tables.layers;
    final label = mixed
        ? strings.mixed
        : switch (common) {
            null => '—',
            final h => layers[h]?.name ?? strings.missingLayer(h.toHex()),
          };
    return Row(
      children: [
        Text(strings.layer),
        const SizedBox(width: 12),
        Expanded(
          child: Tooltip(
            message: blocked ?? strings.moveSelectionToLayer,
            child: PopupMenuButton<Handle>(
              key: const Key('layer-picker'),
              enabled: blocked == null,
              tooltip: '',
              initialValue: mixed ? null : common,
              onSelected: _choose,
              itemBuilder: (context) => [
                for (final r in layersInPanelOrder(layers.records))
                  PopupMenuItem<Handle>(
                    key: Key('layer-picker-item-${r.handle.toHex()}'),
                    value: r.handle,
                    height: 32,
                    child: Text(r.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          key: const Key('layer-picker-value'),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
