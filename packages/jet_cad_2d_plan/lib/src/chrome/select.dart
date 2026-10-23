// The choice of one value among a few (spec "Choices"): a shadcn select
// that shows what the model holds, whatever the user picked.
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'shad_scope.dart';
import 'words_carrier.dart';

/// One option of a [PlanSelect]: a [value] and the [label] it shows. [key],
/// if given, is the key of the option's text.
class PlanOption<T> {
  const PlanOption(this.value, this.label, {this.key});

  final T value;
  final String label;
  final Key? key;
}

/// A select. [value] is the authority: after [onChanged] returns, and on
/// every update of the widget, the select shows [value] again, so a pick the
/// model refused (or one that landed on another value) does not stay on
/// screen, and an undo that changes [value] shows at once.
class PlanSelect<T> extends StatefulWidget implements PlanWordsCarrier {
  const PlanSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.expanded = false,
    this.focusNode,
    this.label,
    this.placeholder,
  });

  final T? value;
  final List<PlanOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  /// Whether the select takes the width it is given (a row of a panel),
  /// else the width of what it shows.
  final bool expanded;

  /// The focus node of the select's trigger, if the owner keeps it.
  final FocusNode? focusNode;
  final String? label;
  final String? placeholder;

  @override
  Iterable<String> get visibleWords => [
        if (label != null) label!,
        if (placeholder != null) placeholder!,
        for (final option in options) option.label,
      ];

  @override
  State<PlanSelect<T>> createState() => _PlanSelectState<T>();
}

class _PlanSelectState<T> extends State<PlanSelect<T>> {
  late final ShadSelectController<T> _controller = ShadSelectController<T>(
      initialValue: widget.value == null ? null : {widget.value as T});
  final ShadPopoverController _popover = ShadPopoverController();
  bool _wasOpen = false;

  @override
  void initState() {
    super.initState();
    _popover.addListener(_onPopover);
  }

  /// A closing popover gives the focus back to the trigger when it is
  /// still inside the popover (Escape closed it): the trigger stays where
  /// the keyboard is. A click elsewhere that already moved the focus is
  /// left alone.
  void _onPopover() {
    final open = _popover.isOpen;
    final closed = _wasOpen && !open;
    _wasOpen = open;
    final node = widget.focusNode;
    if (!closed || node == null || node.hasFocus) return;
    final held = FocusManager.instance.primaryFocus;
    if (held == null ||
        held.context?.findAncestorWidgetOfExactType<ShadSelect<T>>() != null) {
      node.requestFocus();
    }
  }

  /// Sets the controller back to the model's value; a no-op when it holds it.
  void _syncToModel() {
    final value = widget.value;
    final held = _controller.value;
    final want = value == null ? <T>{} : <T>{value};
    if (held.length == want.length && held.containsAll(want)) return;
    _controller.value = want;
  }

  @override
  void didUpdateWidget(PlanSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncToModel();
  }

  @override
  void dispose() {
    _popover.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _labelOf(T value) {
    for (final option in widget.options) {
      if (option.value == value) return option.label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = planShadThemeOf(context);
    final label = widget.label, placeholder = widget.placeholder;
    return Column(
      crossAxisAlignment: widget.expanded
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: theme.textTheme.small),
          ),
        ShadSelect<T>(
          controller: _controller,
          focusNode: widget.focusNode,
          popoverController: _popover,
          enabled: widget.enabled,
          minWidth: 0,
          placeholder: placeholder == null ? null : Text(placeholder),
          options: [
            for (final option in widget.options)
              ShadOption<T>(
                  value: option.value,
                  child: Text(option.label, key: option.key)),
          ],
          selectedOptionBuilder: (context, value) => Text(_labelOf(value)),
          onChanged: (picked) {
            if (picked != null) widget.onChanged(picked);
            // The model is the authority, not the pick.
            _syncToModel();
          },
        ),
      ],
    );
  }
}
