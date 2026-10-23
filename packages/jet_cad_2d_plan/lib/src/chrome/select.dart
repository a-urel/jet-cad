// The choice of one value among a few (spec "Choices"): a shadcn select
// that shows what the model holds, whatever the user picked.
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'shad_scope.dart';
import 'words_carrier.dart';

/// One option of a [PlanSelect]: a [value] and the [label] it shows.
class PlanOption<T> {
  const PlanOption(this.value, this.label);

  final T value;
  final String label;
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
    this.label,
    this.placeholder,
  });

  final T? value;
  final List<PlanOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: theme.textTheme.small),
          ),
        ShadSelect<T>(
          controller: _controller,
          enabled: widget.enabled,
          minWidth: 0,
          placeholder: placeholder == null ? null : Text(placeholder),
          options: [
            for (final option in widget.options)
              ShadOption<T>(value: option.value, child: Text(option.label)),
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
