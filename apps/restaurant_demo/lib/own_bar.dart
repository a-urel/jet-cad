// The service bar of the demo's own, in place of the planner's: the area's
// name, then Undo, Redo, Merge, Split, Export and Print in the planner's
// words, each enabled by the controller's own state as the planner's
// buttons are. Export and Print are off while a page flow runs
// (`pageFlowBusy`): the controller starts one at a time.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// The demo's own bar for [controller], over the area named [name].
class OwnServiceBar extends StatelessWidget {
  const OwnServiceBar({
    super.key,
    required this.name,
    required this.controller,
    required this.onMerge,
    required this.onSplit,
    required this.onExport,
    required this.onPrint,
  });

  final String name;
  final PlanController controller;

  /// Merge's request: what the planner's Merge would send.
  final void Function(Set<String> labels) onMerge;

  /// Split's request: the selected group.
  final void Function(String groupId) onSplit;
  final VoidCallback onExport;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final words = PlanStrings.of(context);
    Widget button(String key, String label, VoidCallback? onPressed) =>
        TextButton(key: Key(key), onPressed: onPressed, child: Text(label));
    return Material(
      key: const Key('own-bar-row'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: 44,
        child: Row(children: [
          const SizedBox(width: 12),
          Text(name),
          const SizedBox(width: 12),
          ValueListenableBuilder<bool>(
              valueListenable: c.canUndo,
              builder: (_, can, __) =>
                  button('own-undo', words.undo, can ? c.undo : null)),
          ValueListenableBuilder<bool>(
              valueListenable: c.canRedo,
              builder: (_, can, __) =>
                  button('own-redo', words.redo, can ? c.redo : null)),
          // What the planner's Merge would send, null when it would be
          // disabled; Split's is the selected group.
          ValueListenableBuilder<Set<String>?>(
              valueListenable: c.mergeCandidate,
              builder: (_, labels, __) => button('own-merge', words.merge,
                  labels == null ? null : () => onMerge(labels))),
          ValueListenableBuilder<String?>(
              valueListenable: c.selectedGroup,
              builder: (_, id, __) => button('own-split', words.split,
                  id == null ? null : () => onSplit(id))),
          ValueListenableBuilder<bool>(
              valueListenable: c.pageFlowBusy,
              builder: (_, busy, __) => Row(children: [
                    button('own-export', words.exportEllipsis,
                        busy ? null : onExport),
                    button('own-print', words.printEllipsis,
                        busy ? null : onPrint),
                  ])),
        ]),
      ),
    );
  }
}
