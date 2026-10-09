import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'shell_commands.dart';

/// The toolbar at the left of the top bar (spec 12a D7): one icon button
/// per command of the table (D6), keyed `toolbar-<id>`, with the command's
/// tooltip, disabled while the command is. The file commands come first,
/// then a gap, then Undo and Redo. A bare shell has no file commands and
/// shows Undo and Redo only. [DocumentToolbar.groups] lays out any run of
/// groups the same way (host embedding API spec C-2): a gap between two
/// groups that both show a button.
///
/// **It never takes focus** (`ExcludeFocus`, as the tool palette), so the
/// canvas keeps it and the shortcuts keep working after a click here.
///
/// **It sits inside a [TextFieldTapRegion]** (spec 12a D2, T-1): a press on
/// it is not a tap outside an open text entry, which would otherwise lose
/// its focus -- and cancel -- on pointer down, before the button's
/// `onPressed`. The command's settle then commits the entry for the button
/// exactly as for the key.
class DocumentToolbar extends StatelessWidget {
  const DocumentToolbar({
    super.key,
    required this.fileCommands,
    required this.editCommands,
  }) : _groups = null;

  /// The buttons of [groups], in order, with a [groupGap] between two
  /// non-empty groups (spec C-2): today's toolbar is the two groups
  /// `[fileCommands, editCommands]`.
  const DocumentToolbar.groups({
    super.key,
    required List<List<ShellCommand>> groups,
  })  : _groups = groups,
        fileCommands = const <ShellCommand>[],
        editCommands = const <ShellCommand>[];

  final List<ShellCommand> fileCommands;
  final List<ShellCommand> editCommands;
  final List<List<ShellCommand>>? _groups;

  /// The gap between the file group and Undo/Redo.
  static const double groupGap = 12;

  /// The buttons, a [groupGap] between two non-empty groups.
  List<Widget> _children() {
    final groups = _groups ?? [fileCommands, editCommands];
    final children = <Widget>[];
    for (final group in groups) {
      if (group.isEmpty) continue;
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: groupGap));
      }
      for (final c in group) {
        children.add(_CommandButton(c));
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
        child: ExcludeFocus(
          // The top bar paints its own background, so the buttons need a
          // `Material` of their own in between to paint their ink on.
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _children(),
            ),
          ),
        ),
      );
}

class _CommandButton extends StatelessWidget {
  const _CommandButton(this.command);

  final ShellCommand command;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: command.enabled,
        builder: (context, enabled, _) => IconButton(
          key: Key('toolbar-${command.id}'),
          tooltip: command.tooltipFor(defaultTargetPlatform,
              control: FloorPlanStrings.of(context).controlKey,
              shift: FloorPlanStrings.of(context).shiftKey),
          icon: Icon(command.icon),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          onPressed: enabled ? command.invoke : null,
        ),
      );
}
