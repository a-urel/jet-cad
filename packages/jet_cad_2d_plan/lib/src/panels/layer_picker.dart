// Spec 12b D11, D12 and 2a spec P2, P4: the selection's layer menu.
// Ported from jet_cad_floor_plan/lib/src/layers/layer_picker.dart: "is a
// live object" is the catalog's (E1) in place of the floor planner's
// closed list (`isParametricObject`, :16-29), and a locked object refuses
// its layer change.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;

import '../chrome/menu_button.dart';
import '../chrome/shad_scope.dart';
import '../controller/plan_controller.dart';
import '../l10n/strings.dart';
import '../l10n/strings_en.dart';
import 'plan_layer_panel.dart' show layersInPanelOrder;

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
/// - a live parametric object's ([isObject]): its `objectLayer`;
/// - a drafted region's: its boundary's, whichever record was picked;
/// - any other root entity's: its own.
Handle? layerOfKey(DraftDocument doc, SelectionKey key,
    {required bool Function(Handle h) isObject}) {
  final h = key.target;
  final node = doc.tree[h];
  if (node is InstanceNode) return node.layer;
  if (node is GroupNode) return isObject(h) ? objectLayer(doc, h) : null;
  if (node != null) return null;
  final entities = doc.entities;
  final slot = entities.slotOf(h);
  if (slot == null) return null;
  if (_owningInstance(doc, slot) case final owner?) return owner.layer;
  final boundary = _boundaryOfFill(doc, slot);
  return entities.layerAt(boundary == null ? slot : entities.slotOf(boundary)!);
}

/// Whether [h], or a group or instance above it (its entity owner, then
/// the tree's parents up to the root), is locked.
bool _lockedOrUnderLock(
    DraftDocument doc, Handle h, bool Function(Handle h) isLocked) {
  if (isLocked(h)) return true;
  final slot = doc.entities.slotOf(h);
  Handle? up = slot != null ? doc.entities.ownerAt(slot) : doc.tree[h]?.parent;
  final root = doc.rootHandle;
  while (up != null && up != root) {
    if (isLocked(up)) return true;
    up = doc.tree[up]?.parent;
  }
  return false;
}

/// Why the picker is disabled for [keys] in [doc], or null when it is
/// enabled: a permission set without `Capability.components` (D11); a
/// locked object, or a key under one, among the keys (2a spec P4); a plain
/// group among the keys (D12). In [strings]' language.
String? layerPickerBlocked(DraftDocument doc, Iterable<SelectionKey> keys,
    {required bool Function(Handle h) isObject,
    required bool Function(Handle h) isLocked,
    PlanStrings strings = const PlanStringsEn()}) {
  if (!doc.commands.permissions.allows(Capability.components)) {
    return strings.readOnlyDocument;
  }
  for (final k in keys) {
    if (_lockedOrUnderLock(doc, k.target, isLocked)) {
      return strings.lockedNoLayer;
    }
  }
  for (final k in keys) {
    final node = doc.tree[k.target];
    if (node is GroupNode && !isObject(k.target)) {
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
/// - a live parametric object ([isObject]):
///   `SetComponentCommand<ObjectLayer>`.
///
/// Each member is moved once — the entity records first, then the
/// instances, then the objects, each in key order; a member already on [layer]
/// (exact `==` on the stored value; an object without an `ObjectLayer` is
/// on layer 0) is skipped. One member left is its command alone; more are
/// one `CompoundCommand`: one undo step either way. A plain group is not a
/// member (the picker is disabled for it, [layerPickerBlocked]).
DraftCommand? layerMoveCommand(
    DraftDocument doc, Iterable<SelectionKey> keys, Handle layer,
    {required bool Function(Handle h) isObject}) {
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
      if (isObject(h)) objects.add(h);
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

bool _never(Handle _) => false;

/// Spec 12b D12: the property panel's layer menu over [controller]'s
/// selection. It shows the selection's common layer ([layerOfKey]), or the
/// strings' `mixed`; choosing a layer dispatches [layerMoveCommand]'s one
/// command through `controller.execute`, built from the document and the
/// selection as they are at the choice. Disabled, with the reason as its
/// tooltip, when [layerPickerBlocked] says so. It keeps no state: its
/// parent rebuilds it on every selection and document change.
class LayerPicker extends StatelessWidget {
  const LayerPicker({super.key, required this.controller});

  final PlanController controller;

  bool _isObject(Handle h) =>
      controller.catalog.typeIdOf(controller.document, h) != null;

  void _choose(Handle layer) {
    final document = controller.document;
    final keys = controller.selection.keys;
    // A menu opened before the host turned `changeLayer` off picks nothing.
    if (!controller.permissions.changeLayer) return;
    // Today's re-check (permissions, a plain group). A lock made after the
    // menu opened is refused at commit by the lock expander (spec P4).
    if (keys.isEmpty ||
        layerPickerBlocked(document, keys,
                isObject: _isObject, isLocked: _never) !=
            null) {
      return;
    }
    if (document.tables.layers[layer] == null) return;
    final command =
        layerMoveCommand(document, keys, layer, isObject: _isObject);
    if (command == null) return;
    try {
      // False: refused (a lock, which raises the hint, a dangling
      // reference, an ArgumentError, a kit's failure); nothing changed.
      controller.execute(command);
    } on StateError {
      // Refused by the dispatcher: nothing changed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = controller.document;
    final keys = controller.selection.keys;
    final strings = PlanStrings.of(context);
    final blocked = layerPickerBlocked(document, keys,
        isObject: _isObject, isLocked: controller.isLocked, strings: strings);
    Handle? common;
    var mixed = false;
    for (final k in keys) {
      final l = layerOfKey(document, k, isObject: _isObject);
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
    return PlanShadScope(
      child: Row(
        children: [
          Text(strings.layer),
          const SizedBox(width: 12),
          Expanded(
            child: PlanMenuButton<Handle>(
              key: const Key('layer-picker'),
              expanded: true,
              enabled: blocked == null,
              // The tooltip and the accessible name: why it is disabled,
              // else what it does.
              label: blocked ?? strings.moveSelectionToLayer,
              selected: mixed ? null : common,
              onSelected: _choose,
              entries: () => [
                for (final r in layersInPanelOrder(layers.records))
                  PlanMenuEntry<Handle>(r.handle, r.name,
                      key: Key('layer-picker-item-${r.handle.toHex()}')),
              ],
              child: Text(label,
                  key: const Key('layer-picker-value'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}
