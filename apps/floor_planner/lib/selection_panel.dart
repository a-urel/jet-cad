import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'parametric/box.dart';

/// Spec 06 D13: one selected box's width and height. Each commit is one
/// `SetComponentCommand<BoxParams>`, which the parametric system turns into
/// one undo step with its regeneration. 12 builds the real inspector.
///
/// Ruling 06-14: Enter commits; focus-out reverts to the model value. An
/// `onTapOutside` handler would also fire on the test's own tap on the field
/// (SE4/SE7), so this panel commits on `onSubmitted` only -- the spec's D13
/// gets amended in Task 11.
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
  late final StreamSubscription<DocChange> _changes;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_sync);
    _changes = widget.document.commands.changes.listen((_) => _sync());
    _load();
  }

  @override
  void dispose() {
    widget.selection.removeListener(_sync);
    _changes.cancel();
    _width.dispose();
    _height.dispose();
    super.dispose();
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
  void _load() {
    final h = _box;
    if (h == null) return;
    final p = widget.document.components.get<BoxParams>(h)!;
    final w = _number(p.width), hh = _number(p.height);
    if (_width.text != w) _width.text = w;
    if (_height.text != hh) _height.text = hh;
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
      _sync();
      return;
    }
    final next = isWidth ? p.copyWith(width: value) : p.copyWith(height: value);
    if (next == p) return;
    widget.document.commands.execute(SetComponentCommand<BoxParams>(h, next));
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
          readOnly: !editable,
          decoration: InputDecoration(labelText: label, suffixText: 'mm'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (t) => _submit(h, t, isWidth: isWidth),
          onTapOutside: (_) => _submit(h, c.text, isWidth: isWidth),
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
