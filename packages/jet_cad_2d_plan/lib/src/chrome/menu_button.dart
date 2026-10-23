// A button that opens a menu (spec "Menus"): an icon button and a shadcn
// context menu. Opened by a normal click, tap, Enter or Space on every
// platform: `ShadContextMenuRegion` opens on a tap only on mobile and on a
// secondary click elsewhere, which a toolbar button is not.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'icon_button.dart';
import 'words_carrier.dart';

/// One entry of a [PlanMenuButton]: a [value], its [label], whether it can
/// be picked now. [key] is put on the rendered entry.
class PlanMenuEntry<T> {
  const PlanMenuEntry(this.value, this.label, {this.enabled = true, this.key});

  final T value;
  final String label;
  final bool enabled;
  final Key? key;
}

/// An icon button with a menu.
///
/// [entries] is called on every build, so an entry whose permission changes
/// while the menu is open is enabled or disabled at once. The entry equal to
/// [selected] is marked. Escape closes the menu and returns the focus to the
/// button; so does a tap outside that lands on nothing focusable.
class PlanMenuButton<T> extends StatefulWidget implements PlanWordsCarrier {
  const PlanMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.entries,
    required this.onSelected,
    this.selected,
  });

  final IconData icon;
  final String label;
  final List<PlanMenuEntry<T>> Function() entries;
  final ValueChanged<T> onSelected;
  final T? selected;

  @override
  Iterable<String> get visibleWords =>
      [label, for (final entry in entries()) entry.label];

  @override
  State<PlanMenuButton<T>> createState() => _PlanMenuButtonState<T>();
}

class _PlanMenuButtonState<T> extends State<PlanMenuButton<T>> {
  final ShadContextMenuController _controller = ShadContextMenuController();

  /// Holds no focus itself: its descendant is the trigger.
  final FocusNode _trigger =
      FocusNode(canRequestFocus: false, skipTraversal: true);
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _controller.dispose();
    _trigger.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final open = _controller.isOpen;
    if (open == _open) return;
    _open = open;
    if (open) {
      HardwareKeyboard.instance.addHandler(_onKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFocus());
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    _controller.hide();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restoreFocus(force: true));
    return true;
  }

  /// Back to the trigger, unless the user's tap moved the focus elsewhere
  /// (a text field) in the meantime.
  void _restoreFocus({bool force = false}) {
    if (!mounted) return;
    final focused = FocusManager.instance.primaryFocus;
    if (!force && focused != null && focused is! FocusScopeNode) return;
    for (final node in _trigger.traversalDescendants) {
      if (node.canRequestFocus) {
        node.requestFocus();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadContextMenu(
      controller: _controller,
      items: [
        for (final entry in widget.entries())
          ShadContextMenuItem(
            key: entry.key,
            enabled: entry.enabled,
            leading: entry.value == widget.selected
                ? const Icon(LucideIcons.check)
                : const SizedBox.square(dimension: 16),
            onPressed: () => widget.onSelected(entry.value),
            child: Semantics(
              selected: entry.value == widget.selected,
              child: Text(entry.label),
            ),
          ),
      ],
      child: Focus(
        focusNode: _trigger,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => PlanTooltipSuppressor(
            suppressed: _controller.isOpen,
            child: PlanIconButton(
              icon: widget.icon,
              label: widget.label,
              onPressed: _controller.toggle,
            ),
          ),
        ),
      ),
    );
  }
}
