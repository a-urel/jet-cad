// A table's context menu (a right click, or a long press under "Long press:
// menu"): the table's title, "Select only this" and the statuses.
import 'package:flutter/material.dart';

import 'demo_strings.dart';
import 'statuses.dart';

/// The menu's choice for [number] at the global point [at]: `select`, or
/// `status:<name>`; null when dismissed. [locked] disables "Select only
/// this": a locked table cannot be selected.
Future<String?> showTableMenu(BuildContext context, Offset at,
    {required String number, required bool locked}) {
  final words = DemoStrings.of(context);
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    items: [
      PopupMenuItem(enabled: false, child: Text(words.tableTitle(number))),
      PopupMenuItem(
          key: const Key('menu-select'),
          value: 'select',
          enabled: !locked,
          child: Text(words.selectOnlyThis)),
      const PopupMenuDivider(),
      for (final name in kStatuses.keys)
        PopupMenuItem(
            key: Key('menu-status-${name.toLowerCase()}'),
            value: 'status:$name',
            child: Text(words.statusName(name))),
    ],
  );
}
