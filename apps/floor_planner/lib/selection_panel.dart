import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'parametric/box.dart';

/// Spec 06 D13: one selected box's width and height. Each commit is one
/// `SetComponentCommand<BoxParams>`, which the parametric system turns into
/// one undo step with its regeneration. 12 builds the real inspector.
///
/// Enter or losing focus commits (spec 06 D13) -- each field owns a
/// `FocusNode`, so moving between Width and Height, or tapping outside both,
/// always commits whichever field was left; an invalid value reverts the
/// field to the model's current value instead.
class SelectionPanel extends StatefulWidget {
  const SelectionPanel(
      {super.key, required this.document, required this.selection});

  final DraftDocument document;
  final SelectionController selection;

  @override
  State<SelectionPanel> createState() => _SelectionPanelState();
}

class _SelectionPanelState extends State<SelectionPanel> {
  final TextEditingController _width = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final FocusNode _widthFocus = FocusNode();
  final FocusNode _heightFocus = FocusNode();
  late final StreamSubscription<DocChange> _changes;

  /// The box and the values last copied into the fields, so [_load] can
  /// tell a real model change from a notification that carries none (spec
  /// 06 D13's amendment for F1): hover and unrelated edits both notify, but
  /// neither one changes the selected box or its stored parameters.
  Handle? _loadedBox;
  BoxParams? _loadedParams;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_sync);
    _changes = widget.document.commands.changes.listen((_) => _sync());
    _widthFocus.addListener(() => _onFocusChange(_widthFocus, isWidth: true));
    _heightFocus
        .addListener(() => _onFocusChange(_heightFocus, isWidth: false));
    _load();
  }

  @override
  void dispose() {
    widget.selection.removeListener(_sync);
    _changes.cancel();
    _width.dispose();
    _height.dispose();
    _widthFocus.dispose();
    _heightFocus.dispose();
    super.dispose();
  }

  /// Commits the field's current text when it just lost focus (spec 06
  /// D13's amendment for F2): each field has its own node, so moving focus
  /// from one to the other commits the one that was left, and a tap
  /// anywhere outside both -- via `onTapOutside`'s explicit unfocus below --
  /// commits whichever field had it.
  void _onFocusChange(FocusNode node, {required bool isWidth}) {
    if (node.hasFocus) return;
    final h = _box;
    if (h == null) return;
    _submit(h, isWidth ? _width.text : _height.text, isWidth: isWidth);
  }

  /// The one selected box, or null.
  Handle? get _box {
    final keys = widget.selection.keys;
    if (keys.length != 1) return null;
    final key = keys.single;
    if (key.chain.isNotEmpty) return null;
    final h = key.target;
    final node = widget.document.tree[h];
    if (node is! GroupNode || node.parent != widget.document.rootHandle) {
      return null;
    }
    return widget.document.components.get<BoxParams>(h) == null ? null : h;
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Copies the model into the fields; no rebuild.
  ///
  /// Reloads only when the selected box, or its stored values, changed
  /// since the last load -- a hover change or an unrelated document edit
  /// notifies but changes neither, so it must not touch the fields (F1).
  /// Even then, a field that currently has focus keeps its own text: the
  /// user may be mid-edit, and a reload must never overwrite what they
  /// typed before they commit it.
  void _load() {
    final h = _box;
    if (h == null) {
      _loadedBox = null;
      _loadedParams = null;
      return;
    }
    final p = widget.document.components.get<BoxParams>(h)!;
    if (h == _loadedBox && p == _loadedParams) return;
    _loadedBox = h;
    _loadedParams = p;
    final w = _number(p.width), hh = _number(p.height);
    if (!_widthFocus.hasFocus && _width.text != w) _width.text = w;
    if (!_heightFocus.hasFocus && _height.text != hh) _height.text = hh;
  }

  /// A selection or document change: reload and rebuild.
  void _sync() {
    _load();
    if (mounted) setState(() {});
  }

  void _submit(Handle h, String text, {required bool isWidth}) {
    final value = double.tryParse(text.trim());
    final p = widget.document.components.get<BoxParams>(h)!;
    if (value == null || !value.isFinite || value <= 0) {
      _revertInvalid(h, isWidth, p);
      return;
    }
    final next = isWidth ? p.copyWith(width: value) : p.copyWith(height: value);
    if (next == p) return;
    widget.document.commands.execute(SetComponentCommand<BoxParams>(h, next));
  }

  /// An invalid submit: puts the model's current value back in the one
  /// field that was rejected. Unconditional, unlike [_load]'s "changed
  /// since the last load" guard -- the model did not change, but the
  /// field's own bad text still has to go, and the field is not being
  /// typed into any more at this point (it just lost, or is losing,
  /// focus).
  void _revertInvalid(Handle h, bool isWidth, BoxParams p) {
    _loadedBox = h;
    _loadedParams = p;
    if (isWidth) {
      _width.text = _number(p.width);
    } else {
      _height.text = _number(p.height);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final h = _box;
    if (h == null) return const SizedBox.shrink();
    final editable = widget.document.commands.permissions
        .allows(const BoxType().editCapability);
    Widget field(String label, TextEditingController c, bool isWidth) =>
        TextField(
          key: Key(isWidth ? 'box-width' : 'box-height'),
          controller: c,
          focusNode: isWidth ? _widthFocus : _heightFocus,
          readOnly: !editable,
          decoration: InputDecoration(labelText: label, suffixText: 'mm'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (t) => _submit(h, t, isWidth: isWidth),
          // Only unfocuses (spec 06 D13's amendment for F2): the commit
          // itself happens in `_onFocusChange`, which fires for this too,
          // so every way of losing focus -- Enter, moving to the other
          // field, or a tap outside both -- commits exactly once.
          onTapOutside: (_) => (isWidth ? _widthFocus : _heightFocus).unfocus(),
        );
    return Material(
      key: const Key('selection-panel'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Box', style: Theme.of(context).textTheme.titleSmall),
            field('Width', _width, true),
            field('Height', _height, false),
          ],
        ),
      ),
    );
  }
}
