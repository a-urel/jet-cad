import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'panel_focus.dart';
import 'parametric/box.dart';
import 'parametric/opening.dart';
import 'parametric/opening_tool.dart';
import 'parametric/wall.dart';
import 'parametric/wall_tool.dart';

/// Spec 06 D13, 07 D11 and 08 D16: the right panel's parametric sections.
///
/// - **Box:** one selected box's width and height.
/// - **Wall:** one selected wall's thickness and justification, or -- while
///   the Wall tool is active -- the tool's [WallSettings] for the next wall.
/// - **Opening:** one selected opening's width and position, and a door's
///   Flip hinge and Flip swing; or -- while the Door, Window or Gap tool is
///   active, even with an opening selected -- that tool's [OpeningSettings]
///   (its width only) for the next opening.
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
      this.wallSettings,
      this.openingTools,
      this.openingSettings});

  final DraftDocument document;
  final SelectionController selection;

  /// The shell's tool controller and its Wall tool: while [wallTool] is
  /// active, the Wall section edits [wallSettings]. All three or none.
  final ToolController? tools;
  final Tool? wallTool;

  /// Owned by the shell and shared with the Wall tool, which reads it at
  /// each commit (07 D11).
  final ValueNotifier<WallSettings>? wallSettings;

  /// The shell's Door, Window and Gap tools, and their settings (spec 08
  /// D16, Ruling 08-17): while the tool of a kind is active, the Opening
  /// section edits that kind's settings, which the tool reads at each hover
  /// and click. Both, with [tools], or neither.
  final Map<OpeningKind, Tool>? openingTools;
  final Map<OpeningKind, ValueNotifier<OpeningSettings>>? openingSettings;

  @override
  State<SelectionPanel> createState() => _SelectionPanelState();
}

/// Which quantity a numeric field edits.
enum _Kind { width, height, thickness, openingWidth, position }

/// One numeric field's state.
///
/// A target is a `Handle`: a box, a wall or an opening, [_toolSettings] for
/// the Wall tool's settings, or [_openingToolSettings] for an opening tool's.
/// [pinned] is the target recorded at focus gain (07 D11);
/// [loadedTarget] and [loadedValue] are what the field last showed, so a
/// reload can tell a real model change from a notification that carries
/// none (06 D13's F1: hover and unrelated edits both notify).
final class _Field {
  _Field(this.kind);

  final _Kind kind;
  final TextEditingController text = TextEditingController();
  final PanelFieldFocusNode focus = PanelFieldFocusNode();
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

/// The Opening section's target while the tool of [kind] is active: its
/// settings (Ruling 08-17). A negative value is never an object's handle,
/// and each kind has its own, so a field pinned to the Door tool's settings
/// never writes the Window tool's.
Handle _openingToolSettings(OpeningKind kind) => Handle(-1 - kind.index);

/// The kind whose tool settings [h] is ([_openingToolSettings]), or null.
OpeningKind? _openingToolKind(Handle h) =>
    h.value < 0 && h.value >= -OpeningKind.values.length
        ? OpeningKind.values[-1 - h.value]
        : null;

class _SelectionPanelState extends State<SelectionPanel> {
  final _Field _width = _Field(_Kind.width);
  final _Field _height = _Field(_Kind.height);
  final _Field _thickness = _Field(_Kind.thickness);
  final _Field _openingWidth = _Field(_Kind.openingWidth);
  final _Field _position = _Field(_Kind.position);
  late final List<_Field> _fields = [
    _width,
    _height,
    _thickness,
    _openingWidth,
    _position,
  ];
  late final StreamSubscription<DocChange> _changes;

  /// Whether the Wall tool was active at the last check: the tool
  /// controller forwards every hover of the active tool, and only a switch
  /// in or out of the Wall tool concerns the panel.
  bool _toolMode = false;

  /// The kind of the opening tool that was active at the last check, or
  /// null: likewise, only a switch in or out of one concerns the panel.
  OpeningKind? _openingToolMode;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_sync);
    _changes = widget.document.commands.changes.listen((_) => _sync());
    widget.tools?.addListener(_onTools);
    widget.wallSettings?.addListener(_sync);
    for (final s in _openingSettingsList) {
      s.addListener(_sync);
    }
    for (final f in _fields) {
      f.focus.addListener(() => _onFocusChange(f));
    }
    _toolMode = _wallToolActive;
    _openingToolMode = _activeOpeningTool;
    _load();
  }

  @override
  void dispose() {
    widget.selection.removeListener(_sync);
    _changes.cancel();
    widget.tools?.removeListener(_onTools);
    widget.wallSettings?.removeListener(_sync);
    for (final s in _openingSettingsList) {
      s.removeListener(_sync);
    }
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  List<ValueNotifier<OpeningSettings>> get _openingSettingsList =>
      widget.openingSettings?.values.toList() ?? const [];

  bool get _wallToolActive {
    final tools = widget.tools, wall = widget.wallTool;
    return tools != null &&
        wall != null &&
        widget.wallSettings != null &&
        identical(tools.active, wall);
  }

  /// The kind of the active opening tool, when it has settings here.
  OpeningKind? get _activeOpeningTool {
    final tools = widget.tools, openings = widget.openingTools;
    if (tools == null || openings == null) return null;
    for (final MapEntry(:key, :value) in openings.entries) {
      if (identical(tools.active, value) &&
          widget.openingSettings?[key] != null) {
        return key;
      }
    }
    return null;
  }

  void _onTools() {
    final mode = _wallToolActive, opening = _activeOpeningTool;
    if (mode == _toolMode && opening == _openingToolMode) return;
    _toolMode = mode;
    _openingToolMode = opening;
    _sync();
  }

  /// Under runtime permissions every section is read-only (06 D13, 07
  /// D11, 08 D16): a commit is a `SetComponentCommand`, which needs
  /// `Capability.components`, and its regeneration needs the type's
  /// `editCapability` (final review m4).
  bool _editable(_Kind kind) {
    final permissions = widget.document.commands.permissions;
    return permissions.allows(Capability.components) &&
        permissions.allows(switch (kind) {
          _Kind.thickness => const WallType().editCapability,
          _Kind.openingWidth ||
          _Kind.position =>
            const OpeningType().editCapability,
          _Kind.width || _Kind.height => const BoxType().editCapability,
        });
  }

  /// Whether [value] may be committed as [kind] at [target], which [_read]
  /// just found live: a thickness is `isWallThickness` (final review m1), a
  /// box side is finite and > 0, an opening's width is `isOpeningWidth` for
  /// its kind (spec 08 D6: a gap's must exceed `4 × wallJoin.linear`), and
  /// its position is finite and within `[0, L]`, `L` its host's centreline
  /// length (none when the host is not a wall).
  bool _valid(_Kind kind, Handle target, double value) {
    switch (kind) {
      case _Kind.thickness:
        return isWallThickness(value);
      case _Kind.width:
      case _Kind.height:
        return value.isFinite && value > 0;
      case _Kind.openingWidth:
        final k = _openingToolKind(target) ??
            widget.document.components.get<OpeningParams>(target)!.kind;
        return isOpeningWidth(k, value);
      case _Kind.position:
        final o = widget.document.components.get<OpeningParams>(target)!;
        final host = widget.document.components.get<WallParams>(o.host);
        if (host == null) return false;
        final l = (host.end - host.start).length;
        return value.isFinite && value >= 0 && value <= l;
    }
  }

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

  /// The Opening section's target, or null when it is hidden: the active
  /// opening tool's settings (spec 08 D16: even with an opening selected),
  /// else the one selected opening.
  Handle? get _opening => switch (_openingToolMode) {
        final k? => _openingToolSettings(k),
        null => _selected<OpeningParams>(),
      };

  /// The target [kind]'s section shows now, or null. The position has none
  /// in tool mode: the tools place at the click.
  Handle? _targetOf(_Kind kind) => switch (kind) {
        _Kind.width || _Kind.height => _box,
        _Kind.thickness => _wall,
        _Kind.openingWidth => _opening,
        _Kind.position =>
          _openingToolMode == null ? _selected<OpeningParams>() : null,
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
      case _Kind.openingWidth:
      case _Kind.position:
        if (_openingToolKind(target) case final k?) {
          final settings = widget.openingSettings?[k];
          return kind == _Kind.openingWidth ? settings?.value.width : null;
        }
        if (!_isObject<OpeningParams>(target)) return null;
        final o = widget.document.components.get<OpeningParams>(target)!;
        return kind == _Kind.openingWidth ? o.width : o.position;
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
      case _Kind.openingWidth:
      case _Kind.position:
        if (_openingToolKind(target) case final k?) {
          final s = widget.openingSettings![k]!;
          s.value = s.value.copyWith(width: value);
          return;
        }
        final p = doc.components.get<OpeningParams>(target)!;
        final next = kind == _Kind.openingWidth
            ? p.copyWith(width: value)
            : p.copyWith(position: value);
        if (next == p) return;
        doc.commands.execute(SetComponentCommand<OpeningParams>(target, next));
    }
  }

  /// Whether [target] is a tool's settings rather than an object.
  static bool _isToolTarget(Handle? target) =>
      target == _toolSettings ||
      (target != null && _openingToolKind(target) != null);

  static String _titleOf(OpeningKind k) => switch (k) {
        OpeningKind.door => 'Door',
        OpeningKind.window => 'Window',
        OpeningKind.gap => 'Gap',
      };

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
  /// object of the field's type, and reverted when it is not a valid value
  /// ([_valid]), the edit is not allowed, or the document refuses the edit
  /// (an `ArgumentError` or `StateError` from `execute` -- a loaded file
  /// the regeneration cannot honour, say -- or, spec 08 D5, a
  /// `DanglingReferenceError` for a loaded opening whose host is gone;
  /// the edit was rolled back, and must not escape a focus listener or
  /// `onSubmitted`; final review m1).
  /// Enter commits here and then, once focus has moved, focus loss commits
  /// again: the field is re-pinned to what it now shows, so that second
  /// commit is a no-op.
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
      if (value != null && _valid(f.kind, target, value)) {
        try {
          _write(f.kind, target, value);
        } on ArgumentError {
          // Refused: nothing changed; the field reverts below.
        } on StateError {
          // Refused: nothing changed; the field reverts below.
        } on DanglingReferenceError {
          // Refused (spec 08 D5): nothing changed; the field reverts below.
        }
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
  /// is a click, not a text entry: it acts on the target shown now. An
  /// edit the document refuses is caught as `_commit` catches one (final
  /// review): nothing changed, so the toggle keeps showing the model.
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
    try {
      widget.document.commands
          .execute(SetComponentCommand<WallParams>(target, next));
    } on ArgumentError {
      // Refused: nothing changed.
    } on StateError {
      // Refused: nothing changed.
    }
  }

  /// Spec 08 D16: Flip hinge or Flip swing, one step for the one selected
  /// door. Like the justification toggle, a click that acts on the target
  /// shown now, and a refused edit is caught: nothing changed.
  void _flip({required bool hinge}) {
    final target = _openingToolMode == null ? _selected<OpeningParams>() : null;
    if (target == null || !_editable(_Kind.openingWidth)) return;
    final p = widget.document.components.get<OpeningParams>(target)!;
    if (p.kind != OpeningKind.door) return;
    final next = hinge
        ? p.copyWith(
            hinge: p.hinge == HingeEnd.start ? HingeEnd.end : HingeEnd.start)
        : p.copyWith(
            swing:
                p.swing == SwingSide.left ? SwingSide.right : SwingSide.left);
    try {
      widget.document.commands
          .execute(SetComponentCommand<OpeningParams>(target, next));
    } on ArgumentError {
      // Refused: nothing changed.
    } on StateError {
      // Refused: nothing changed.
    } on DanglingReferenceError {
      // Refused: nothing changed.
    }
  }

  /// Whether [v] is a valid keystroke for the tool settings [target]:
  /// written at once in tool mode (07 D11, 08 D16).
  bool _validSetting(_Kind kind, Handle target, double v) =>
      switch (_openingToolKind(target)) {
        final k? => kind == _Kind.openingWidth && isOpeningWidth(k, v),
        null => kind == _Kind.thickness && isWallThickness(v),
      };

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
        //
        // The same for an opening tool's width (08 D16): a width typed
        // with D active and no Enter places the next door at that width.
        onChanged: (t) {
          final target = f.pinned;
          if (target == null || !_isToolTarget(target)) return;
          final v = double.tryParse(t.trim());
          if (v != null && _validSetting(f.kind, target, v)) {
            _write(f.kind, target, v);
          }
        },
        onSubmitted: (_) => _commit(f),
        // Enter hands focus back to what had it before the panel fields --
        // the canvas -- so the shell's letters and Escape work again at
        // once; past any other panel field still in the focus history
        // (fix/post-07 F3; `PanelFieldFocusNode.handBack`). `onSubmitted`
        // still runs after it.
        onEditingComplete: f.focus.handBack,
        // Only unfocuses (spec 06 D13's amendment for F2): the commit
        // itself happens in `_onFocusChange`, which fires for this too, so
        // every way of losing focus -- Enter, moving to another field, or a
        // tap outside -- commits. Like Enter, it hands focus back to the
        // canvas, and leaves a canvas click's own focus request alone.
        onTapOutside: (_) => f.focus.handBack(),
      );

  @override
  Widget build(BuildContext context) {
    final box = _box, wall = _wall, opening = _opening;
    if (box == null && wall == null && opening == null) {
      return const SizedBox.shrink();
    }
    final title = Theme.of(context).textTheme.titleSmall;
    final boxEditable = _editable(_Kind.width);
    final wallEditable = _editable(_Kind.thickness);
    final openingEditable = _editable(_Kind.openingWidth);
    final OpeningParams? openingParams = opening == null
        ? null
        : widget.document.components.get<OpeningParams>(opening);
    final openingKind = switch (opening) {
      null => null,
      final h => _openingToolKind(h) ?? openingParams!.kind,
    };
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
            if (opening != null) ...[
              if (box != null || wall != null) const SizedBox(height: 12),
              Text(_titleOf(openingKind!),
                  key: const Key('opening-section'), style: title),
              _field('opening-width', 'Width', _openingWidth, openingEditable),
              // The position, from the host's start to the centre, is the
              // stored one; a tool places at the click, so it has none.
              if (openingParams != null)
                _field(
                    'opening-position', 'Position', _position, openingEditable),
              if (openingParams?.kind == OpeningKind.door) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('opening-flip-hinge'),
                        onPressed:
                            openingEditable ? () => _flip(hinge: true) : null,
                        child: const Text('Flip hinge'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('opening-flip-swing'),
                        onPressed:
                            openingEditable ? () => _flip(hinge: false) : null,
                        child: const Text('Flip swing'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
