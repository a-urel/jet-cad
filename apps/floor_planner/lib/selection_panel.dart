import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'parametric/box.dart';
import 'parametric/wall.dart';
import 'parametric/wall_tool.dart';

/// Spec 06 D13 and 07 D11: the right panel's parametric sections.
///
/// - **Box:** one selected box's width and height.
/// - **Wall:** one selected wall's thickness and justification, or -- while
///   the Wall tool is active -- the tool's [WallSettings] for the next wall.
///
/// Each commit to an object is one `SetComponentCommand`, which the
/// parametric system turns into one undo step with its regeneration. 12
/// builds the real inspector.
///
/// Every numeric field follows 06 D13's amendment (F1/F2): it owns a
/// `FocusNode` and commits on its own focus loss, whatever took the focus;
/// Enter commits too; an invalid value reverts the field instead; a reload
/// never writes into a focused field.
///
/// **The commit target is pinned at focus gain (07 D11).** A field records
/// its section's target when it gains focus, and its commit goes to that
/// target -- if it is still a live object of the same type; otherwise the
/// typed text is discarded. A selection change while a field has focus
/// therefore never redirects the typed value onto another object.
class SelectionPanel extends StatefulWidget {
  const SelectionPanel(
      {super.key,
      required this.document,
      required this.selection,
      this.tools,
      this.wallTool,
      this.wallSettings});

  final DraftDocument document;
  final SelectionController selection;

  /// The shell's tool controller and its Wall tool: while [wallTool] is
  /// active, the Wall section edits [wallSettings]. All three or none.
  final ToolController? tools;
  final Tool? wallTool;

  /// Owned by the shell and shared with the Wall tool, which reads it at
  /// each commit (07 D11).
  final ValueNotifier<WallSettings>? wallSettings;

  @override
  State<SelectionPanel> createState() => _SelectionPanelState();
}

/// Which quantity a numeric field edits.
enum _Kind { width, height, thickness }

/// One numeric field's state.
///
/// A target is a `Handle`: a box or a wall, or [_toolSettings] for the Wall
/// tool's settings. [pinned] is the target recorded at focus gain (07 D11);
/// [loadedTarget] and [loadedValue] are what the field last showed, so a
/// reload can tell a real model change from a notification that carries
/// none (06 D13's F1: hover and unrelated edits both notify).
final class _Field {
  _Field(this.kind);

  final _Kind kind;
  final TextEditingController text = TextEditingController();
  final FocusNode focus = FocusNode();
  Handle? pinned;
  Handle? loadedTarget;
  double? loadedValue;

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

/// The Wall section's target while the Wall tool is active: its settings.
/// Handle 0 is never an object's handle.
const Handle _toolSettings = Handle.none;

class _SelectionPanelState extends State<SelectionPanel> {
  final _Field _width = _Field(_Kind.width);
  final _Field _height = _Field(_Kind.height);
  final _Field _thickness = _Field(_Kind.thickness);
  late final List<_Field> _fields = [_width, _height, _thickness];
  late final StreamSubscription<DocChange> _changes;

  /// Whether the Wall tool was active at the last check: the tool
  /// controller forwards every hover of the active tool, and only a switch
  /// in or out of the Wall tool concerns the panel.
  bool _toolMode = false;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_sync);
    _changes = widget.document.commands.changes.listen((_) => _sync());
    widget.tools?.addListener(_onTools);
    widget.wallSettings?.addListener(_sync);
    for (final f in _fields) {
      f.focus.addListener(() => _onFocusChange(f));
    }
    _toolMode = _wallToolActive;
    _load();
  }

  @override
  void dispose() {
    widget.selection.removeListener(_sync);
    _changes.cancel();
    widget.tools?.removeListener(_onTools);
    widget.wallSettings?.removeListener(_sync);
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _wallToolActive {
    final tools = widget.tools, wall = widget.wallTool;
    return tools != null &&
        wall != null &&
        widget.wallSettings != null &&
        identical(tools.active, wall);
  }

  void _onTools() {
    final mode = _wallToolActive;
    if (mode == _toolMode) return;
    _toolMode = mode;
    _sync();
  }

  /// Under runtime permissions both sections are read-only (06 D13, 07
  /// D11): each type's `editCapability`.
  bool _editable(_Kind kind) =>
      widget.document.commands.permissions.allows(kind == _Kind.thickness
          ? const WallType().editCapability
          : const BoxType().editCapability);

  /// [h] is a live root-level group carrying a [T].
  bool _isObject<T extends Component>(Handle h) {
    final node = widget.document.tree[h];
    return node is GroupNode &&
        node.parent == widget.document.rootHandle &&
        widget.document.components.get<T>(h) != null;
  }

  /// The one selected key's root-level group carrying a [T], or null.
  Handle? _selected<T extends Component>() {
    final keys = widget.selection.keys;
    if (keys.length != 1) return null;
    final key = keys.single;
    if (key.chain.isNotEmpty) return null;
    return _isObject<T>(key.target) ? key.target : null;
  }

  /// The Box section's box, or null when it is hidden.
  Handle? get _box => _selected<BoxParams>();

  /// The Wall section's target, or null when it is hidden: the tool's
  /// settings while the Wall tool is active (a drawing tool clears the
  /// selection when it activates), else the one selected wall.
  Handle? get _wall => _toolMode ? _toolSettings : _selected<WallParams>();

  /// The target [kind]'s section shows now, or null.
  Handle? _targetOf(_Kind kind) => switch (kind) {
        _Kind.width || _Kind.height => _box,
        _Kind.thickness => _wall,
      };

  /// [kind]'s value at [target], or null when [target] is no longer a live
  /// object of the field's type.
  double? _read(_Kind kind, Handle target) {
    switch (kind) {
      case _Kind.width:
      case _Kind.height:
        if (!_isObject<BoxParams>(target)) return null;
        final p = widget.document.components.get<BoxParams>(target)!;
        return kind == _Kind.width ? p.width : p.height;
      case _Kind.thickness:
        if (target == _toolSettings) {
          return widget.wallSettings?.value.thickness;
        }
        if (!_isObject<WallParams>(target)) return null;
        return widget.document.components.get<WallParams>(target)!.thickness;
    }
  }

  /// Stores [value] as [kind] at [target], which [_read] just found live:
  /// one command for an object, nothing when the value is unchanged.
  void _write(_Kind kind, Handle target, double value) {
    final doc = widget.document;
    switch (kind) {
      case _Kind.width:
      case _Kind.height:
        final p = doc.components.get<BoxParams>(target)!;
        final next = kind == _Kind.width
            ? p.copyWith(width: value)
            : p.copyWith(height: value);
        if (next == p) return;
        doc.commands.execute(SetComponentCommand<BoxParams>(target, next));
      case _Kind.thickness:
        if (target == _toolSettings) {
          final s = widget.wallSettings!;
          s.value = s.value.copyWith(thickness: value);
          return;
        }
        final p = doc.components.get<WallParams>(target)!;
        final next = p.copyWith(thickness: value);
        if (next == p) return;
        doc.commands.execute(SetComponentCommand<WallParams>(target, next));
    }
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Records the target on focus gain; commits on focus loss (06 D13's F2,
  /// 07 D11). `??=`: a focused node that notifies again keeps its pin.
  void _onFocusChange(_Field f) {
    if (f.focus.hasFocus) {
      f.pinned ??= _targetOf(f.kind);
      return;
    }
    _commit(f);
  }

  /// Commits [f]'s text to its pinned target (07 D11), then shows the
  /// current target's value in it.
  ///
  /// The text is discarded when the pinned target is no longer a live
  /// object of the field's type, and reverted when it is not a number > 0
  /// or the edit is not allowed. Enter commits here and then, once focus
  /// has moved, focus loss commits again: the field is re-pinned to what it
  /// now shows, so that second commit is a no-op.
  ///
  /// A live pinned target's typed text is also dropped if its section
  /// hides while the field keeps focus: the field unmounts, and its commit
  /// finds it no longer shows. The UI never reaches this -- a click on the
  /// canvas, the only way to change the selection by hand, unfocuses the
  /// field first.
  void _commit(_Field f) {
    final target = f.pinned;
    if (target != null && _read(f.kind, target) != null && _editable(f.kind)) {
      final value = double.tryParse(f.text.text.trim());
      if (value != null && value.isFinite && value > 0) {
        _write(f.kind, target, value);
      }
    }
    _show(f);
    f.pinned = f.focus.hasFocus ? _targetOf(f.kind) : null;
    if (mounted) setState(() {});
  }

  /// Writes the current target's value into [f], unconditionally: the
  /// field is being left, so its own text has to go.
  void _show(_Field f) {
    final target = _targetOf(f.kind);
    final value = target == null ? null : _read(f.kind, target);
    f.loadedTarget = value == null ? null : target;
    f.loadedValue = value;
    if (value == null) return;
    final t = _number(value);
    if (f.text.text != t) f.text.text = t;
  }

  /// Copies the model into the fields; no rebuild.
  ///
  /// A field reloads only when its target, or the target's value, changed
  /// since its last load (06 D13's F1), and never while it has focus: the
  /// user may be mid-edit, and a reload must never overwrite what they
  /// typed before they commit it.
  void _load() {
    for (final f in _fields) {
      final target = _targetOf(f.kind);
      final value = target == null ? null : _read(f.kind, target);
      if (value == null) {
        f.loadedTarget = null;
        f.loadedValue = null;
        continue;
      }
      if (f.focus.hasFocus) continue;
      if (target == f.loadedTarget && value == f.loadedValue) continue;
      _show(f);
    }
  }

  /// A selection, document, tool or settings change: reload and rebuild.
  void _sync() {
    _load();
    if (mounted) setState(() {});
  }

  /// One step for a wall, the settings for the tool (07 D11). The toggle
  /// is a click, not a text entry: it acts on the target shown now.
  void _setJustification(Justification j) {
    final target = _wall;
    if (target == null || !_editable(_Kind.thickness)) return;
    if (target == _toolSettings) {
      final s = widget.wallSettings!;
      s.value = s.value.copyWith(justification: j);
      return;
    }
    final p = widget.document.components.get<WallParams>(target)!;
    final next = p.copyWith(justification: j);
    if (next == p) return;
    widget.document.commands
        .execute(SetComponentCommand<WallParams>(target, next));
  }

  Widget _field(String key, String label, _Field f, bool editable) => TextField(
        key: Key(key),
        controller: f.text,
        focusNode: f.focus,
        readOnly: !editable,
        decoration: InputDecoration(labelText: label, suffixText: 'mm'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        // While the Wall tool is active every valid keystroke reaches its
        // settings at once (07 D11, review round 1): a canvas click
        // accepts its point before the field's focus-loss commit runs, so
        // a value typed without Enter would otherwise miss that click's
        // wall. Erasing back leaves the last valid prefix in the settings
        // until the field commits.
        onChanged: (t) {
          if (f.pinned != _toolSettings) return;
          final v = double.tryParse(t.trim());
          if (v != null && v.isFinite && v > 0) {
            _write(f.kind, _toolSettings, v);
          }
        },
        onSubmitted: (_) => _commit(f),
        // Enter hands focus back to what had it before the field -- the
        // canvas -- so the shell's letters and Escape work again at once.
        // `onSubmitted` still runs after it.
        onEditingComplete: () => f.focus
            .unfocus(disposition: UnfocusDisposition.previouslyFocusedChild),
        // Only unfocuses (spec 06 D13's amendment for F2): the commit
        // itself happens in `_onFocusChange`, which fires for this too, so
        // every way of losing focus -- Enter, moving to another field, or a
        // tap outside -- commits. Like Enter, it hands focus back to the
        // previously focused node: the plain `unfocus()` clears the scope's
        // focus history and takes the focus to the scope itself, even from
        // a canvas click that has just requested it.
        onTapOutside: (_) => f.focus
            .unfocus(disposition: UnfocusDisposition.previouslyFocusedChild),
      );

  @override
  Widget build(BuildContext context) {
    final box = _box, wall = _wall;
    if (box == null && wall == null) return const SizedBox.shrink();
    final title = Theme.of(context).textTheme.titleSmall;
    final boxEditable = _editable(_Kind.width);
    final wallEditable = _editable(_Kind.thickness);
    final Justification? justification = switch (wall) {
      null => null,
      _toolSettings => widget.wallSettings!.value.justification,
      final h => widget.document.components.get<WallParams>(h)!.justification,
    };
    return Material(
      key: const Key('selection-panel'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (box != null) ...[
              Text('Box', style: title),
              _field('box-width', 'Width', _width, boxEditable),
              _field('box-height', 'Height', _height, boxEditable),
            ],
            if (wall != null) ...[
              Text('Wall', key: const Key('wall-section'), style: title),
              _field('wall-thickness', 'Thickness', _thickness, wallEditable),
              const SizedBox(height: 8),
              SegmentedButton<Justification>(
                key: const Key('wall-justification'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: Justification.left,
                      label: Text('Left', key: Key('wall-left'))),
                  ButtonSegment(
                      value: Justification.centre,
                      label: Text('Centre', key: Key('wall-centre'))),
                  ButtonSegment(
                      value: Justification.right,
                      label: Text('Right', key: Key('wall-right'))),
                ],
                selected: {justification!},
                onSelectionChanged:
                    wallEditable ? (s) => _setJustification(s.single) : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
