// The one text field of the chrome (spec "Fields"): a label above, a shadcn
// input, a suffix inside it and an error below. The only place a `ShadInput`
// is built (test/l10n/shadcn_words_test.dart, SW1).
import 'package:flutter/material.dart' show AdaptiveTextSelectionToolbar;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'shad_scope.dart';
import 'words_carrier.dart';

/// The library's text toolbar (copy, cut, paste, select all as the platform
/// draws them): the one context menu of every [PlanTextField].
Widget planTextContextMenu(BuildContext context, EditableTextState state) =>
    AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

/// The toolbar of a read-only field: what [planTextContextMenu] offers
/// without the items that would edit.
Widget _readOnlyContextMenu(BuildContext context, EditableTextState state) =>
    AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        for (final item in state.contextMenuButtonItems)
          if (item.type == ContextMenuButtonType.copy ||
              item.type == ContextMenuButtonType.selectAll)
            item,
      ],
    );

/// Refuses every change of the text and lets the selection through.
class _KeepText extends TextInputFormatter {
  const _KeepText();

  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.text == oldValue.text ? newValue : oldValue;
}

/// A labelled text field.
///
/// [readOnly] keeps what the Material `TextField(readOnly: true)` did: the
/// field takes the focus, its text can be selected and copied, nothing edits
/// it. `ShadInput(readOnly: true)` would not do: it sets `canRequestFocus`
/// on the focus node when the flag changes, which unfocuses a focused field
/// and takes a read-only one out of the Tab order. So the input stays
/// editable for the framework and a formatter refuses every change to the
/// text (typing, delete, cut, paste), the soft keyboard is not asked for and
/// the toolbar drops cut and paste.
class PlanTextField extends StatelessWidget implements PlanWordsCarrier {
  const PlanTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.suffix,
    this.errorText,
    this.placeholder,
    this.readOnly = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTapOutside,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? suffix;
  final String? errorText;
  final String? placeholder;
  final bool readOnly;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final TapRegionCallback? onTapOutside;

  @override
  Iterable<String> get visibleWords => [
        for (final word in [label, suffix, errorText, placeholder])
          if (word != null) word,
      ];

  @override
  Widget build(BuildContext context) {
    final theme = planShadThemeOf(context);
    final label = this.label, suffix = this.suffix, error = errorText;
    final placeholder = this.placeholder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: theme.textTheme.small),
          ),
        ShadInput(
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder == null ? null : Text(placeholder),
          trailing: suffix == null
              ? null
              : Text(suffix, style: theme.textTheme.muted),
          showCursor: readOnly ? false : null,
          keyboardType: readOnly ? TextInputType.none : keyboardType,
          inputFormatters: [
            ...?inputFormatters,
            if (readOnly) const _KeepText(),
          ],
          // Every text field shares EditableText's default tap group: a tap
          // on another field is not outside this one (as with the Material
          // TextField the panels used).
          groupId: EditableText,
          contextMenuBuilder:
              readOnly ? _readOnlyContextMenu : planTextContextMenu,
          onPressedOutside: onTapOutside,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onEditingComplete: onEditingComplete,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              style: theme.textTheme.small
                  .copyWith(color: theme.colorScheme.destructive),
            ),
          ),
      ],
    );
  }
}

/// A label above a read-only value drawn by [child] (what an
/// `InputDecorator` was for: a layer's name beside its fields).
class PlanReadOnlyField extends StatelessWidget implements PlanWordsCarrier {
  const PlanReadOnlyField(
      {super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Iterable<String> get visibleWords => [label];

  @override
  Widget build(BuildContext context) {
    final theme = planShadThemeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(label, style: theme.textTheme.small),
        ),
        child,
      ],
    );
  }
}
