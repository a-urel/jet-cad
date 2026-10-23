// A table's context menu (a right click, or a long press under "Long press:
// menu"): the table's title, "Select only this" and the statuses.
import 'dart:async' show Completer;

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'demo_strings.dart';
import 'statuses.dart';

/// The menu's choice for [number] at the global point [at]: `select`, or
/// `status:<name>`; null when dismissed. [locked] disables "Select only
/// this": a locked table cannot be selected.
///
/// A `ShadContextMenu` open at [at] in an entry of the root overlay, under
/// a barrier that swallows the tap which dismisses it (as a popup route's
/// does); the entry is gone when the future completes.
Future<String?> showTableMenu(BuildContext context, Offset at,
    {required String number, required bool locked}) {
  final words = DemoStrings.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<String?>();
  final controller = ShadContextMenuController(isOpen: true);
  late final OverlayEntry entry;
  late final VoidCallback onToggle;
  void finish(String? choice) {
    if (done.isCompleted) return;
    done.complete(choice);
    controller.removeListener(onToggle);
    entry.remove();
    entry.dispose();
  }

  onToggle = () {
    if (!controller.isOpen) finish(null);
  };
  controller.addListener(onToggle);
  Widget item(String value, String label, {Key? key, bool enabled = true}) =>
      ShadContextMenuItem(
          key: key,
          enabled: enabled,
          onPressed: () => finish(value),
          child: Text(label));
  entry = OverlayEntry(
    builder: (_) => Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => finish(null),
          onSecondaryTapDown: (_) => finish(null),
        ),
      ),
      ShadContextMenu(
        controller: controller,
        anchor: ShadGlobalAnchor(at),
        items: [
          ShadContextMenuItem(
              enabled: false, child: Text(words.tableTitle(number))),
          item('select', words.selectOnlyThis,
              key: const Key('menu-select'), enabled: !locked),
          const ShadSeparator.horizontal(
              margin: EdgeInsets.symmetric(vertical: 4)),
          for (final name in kStatuses.keys)
            item('status:$name', words.statusName(name),
                key: Key('menu-status-${name.toLowerCase()}')),
        ],
        child: const SizedBox.shrink(),
      ),
    ]),
  );
  overlay.insert(entry);
  return done.future;
}
