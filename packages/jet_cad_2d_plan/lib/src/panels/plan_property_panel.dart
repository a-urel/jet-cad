// Spec 2a P2 ("The widgets"), P3 (properties, colour), P4 (locks): the
// active tool's settings while a tool with settings is active; the one
// selected object's section (its type's fields titled by its title word,
// then its escape hatch) or the generic symbol section (name, size,
// rotation, mirror, the family's Size menu); the colour row over the
// selection. A locked object shows no section.
//
// The field rules are today's (jet_cad_floor_plan/lib/src/selection_panel.dart,
// spec 06 D13 F1/F2, 07 D11, 10 D21, fix/post-07, post-11): a field owns a
// PanelFieldFocusNode, pins its target at focus gain, commits on its focus
// loss and on Enter, hands the focus back to the canvas, reverts what it
// cannot parse or what is refused, and is never reloaded while focused.
// What changes is where a field comes from: a PropertyField that the type
// (PlanType.fieldsOf) or the tool's settings (PlanToolSettings.fieldsOf)
// bind, in place of the closed list of _Kind values.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:meta/meta.dart' show internal;
import 'package:shadcn_ui/shadcn_ui.dart' show ShadButton;

import '../chrome/rows.dart';
import '../chrome/select.dart';
import '../chrome/shad_scope.dart';
import '../chrome/text_field.dart';
import '../controller/plan_controller.dart';
import '../kits/section_boundary.dart' show KitSectionBoundary;
import '../l10n/locale_scope.dart';
import '../l10n/number_text.dart';
import '../l10n/strings.dart';
import '../l10n/strings_en.dart';
import '../shortcuts/plan_shortcut_guard.dart';
import '../units/unit_problems.dart' show DuplicateLabel;
import '../units/unit_rotate.dart' show rotateUnitCommand;
import '../units/unit_words.dart';
import '../units/unit_writes.dart' show unitLabelCommand;
import 'colour_row.dart';
import 'frame_safe_relay.dart';
import 'kit_lookup.dart';
import 'layer_picker.dart';
import 'panel_focus.dart';
import 'symbol_section.dart';
import 'unit_section.dart';

/// The selected object's and the active tool's properties, over
/// [controller].
class PlanPropertyPanel extends StatefulWidget {
  const PlanPropertyPanel({super.key, required this.controller});

  final PlanController controller;

  @override
  State<PlanPropertyPanel> createState() => _PlanPropertyPanelState();
}

/// The layer field's slot (spec P2, "The layer field"): the layer picker
/// (Task 18). Null shows none.
@internal
Widget? Function(BuildContext context, PlanController controller)?
    propertyPanelLayerField =
    (context, controller) => LayerPicker(controller: controller);

/// What a field edits: one object of a type, one tool's settings, or one
/// placed symbol's rotation.
sealed class _Target {
  const _Target();
}

final class _ObjectTarget extends _Target {
  const _ObjectTarget(this.handle, this.typeId);

  final Handle handle;
  final String typeId;

  @override
  bool operator ==(Object other) =>
      other is _ObjectTarget &&
      other.handle == handle &&
      other.typeId == typeId;

  @override
  int get hashCode => Object.hash(handle, typeId);
}

final class _ToolTarget extends _Target {
  const _ToolTarget(this.toolId);

  final String toolId;

  @override
  bool operator ==(Object other) =>
      other is _ToolTarget && other.toolId == toolId;

  @override
  int get hashCode => toolId.hashCode;
}

final class _SymbolTarget extends _Target {
  const _SymbolTarget(this.handle);

  final Handle handle;

  @override
  bool operator ==(Object other) =>
      other is _SymbolTarget && other.handle == handle;

  @override
  int get hashCode => handle.hashCode;
}

final class _UnitTarget extends _Target {
  const _UnitTarget(this.handle);

  final Handle handle;

  @override
  bool operator ==(Object other) =>
      other is _UnitTarget && other.handle == handle;

  @override
  int get hashCode => Object.hash(_UnitTarget, handle);
}

enum _Scope { object, tool, symbol, unit }

/// One text field's state (today's `_Field`, `selection_panel.dart:160-186`):
/// [pinned] is the target recorded at focus gain; [loadedTarget] and
/// [loadedText] are what the field last showed, so a reload can tell a real
/// change from a notification that carries none.
final class _Field {
  _Field(this.scope, this.id);

  final _Scope scope;

  /// The spec id; `rotation` for the symbol's row.
  final String id;
  final TextEditingController text = TextEditingController();
  final PanelFieldFocusNode focus = PanelFieldFocusNode();
  _Target? pinned;
  _Target? loadedTarget;
  String? loadedText;

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

class _PlanPropertyPanelState extends State<PlanPropertyPanel> {
  PlanController get _c => widget.controller;

  final Map<(_Scope, String), _Field> _fields = {};

  /// Each choice row's focus node, by its key's name. The menu takes the
  /// focus when it opens (`DropdownButton` asks for it); a choice hands it
  /// back to the node that had it before -- the canvas -- as Enter does
  /// for a text field, so the canvas's keys work at once (2a: the focus
  /// rules are today's, whose segmented buttons never took it). The row
  /// stays reachable from the keyboard.
  final Map<String, PanelFieldFocusNode> _choiceFocus = {};

  /// The document the subscriptions below belong to.
  DraftDocument? _document;
  StreamSubscription<DocChange>? _changes;
  FrameSafeRelay? _selection;
  VoidCallback? _releaseSettle;

  /// The label field's last refusal and the unit it was for (today's
  /// `_numberError`, selection_panel.dart:244-249).
  String Function(PlanStrings)? _labelError;
  Handle? _labelErrorFor;

  /// The panel's words: set before the first build and on a change of
  /// language, when the fields are shown again in it (spec 14d L12).
  PlanStrings _strings = const PlanStringsEn();

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, _c);
    final next = PlanStrings.of(context);
    if (identical(next, _strings)) return;
    _strings = next;
    for (final f in _fields.values) {
      if (!f.focus.hasFocus && f.loadedTarget != null) _show(f);
    }
  }

  @override
  void didUpdateWidget(PlanPropertyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, _c)) return;
    _detach(oldWidget.controller);
    _forgetTargets();
    _attach();
    PlanLocaleScope.push(context, _c);
  }

  @override
  void dispose() {
    _detach(_c);
    for (final f in _fields.values) {
      f.dispose();
    }
    for (final focus in _choiceFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  static List<Listenable> _listened(PlanController c) =>
      [c.activeTool, c.toolSettings, c.symbolsState, c.locked, c.locale];

  void _attach() {
    final c = _c;
    c.addListener(_onController);
    for (final l in _listened(c)) {
      l.addListener(_sync);
    }
    _releaseSettle = c.registerSettle(_settle);
    _bindDocument();
  }

  void _detach(PlanController c) {
    c.removeListener(_onController);
    for (final l in _listened(c)) {
      l.removeListener(_sync);
    }
    _releaseSettle?.call();
    _releaseSettle = null;
    _unbindDocument();
  }

  void _bindDocument() {
    _document = _c.document;
    _changes = _document!.commands.changes.listen((_) => _sync());
    _selection = FrameSafeRelay(_c.selection)..addListener(_sync);
  }

  void _unbindDocument() {
    _changes?.cancel();
    _changes = null;
    _selection
      ?..removeListener(_sync)
      ..dispose();
    _selection = null;
  }

  /// After a swap no field may write into the new plan what it pinned in
  /// the old one.
  void _forgetTargets() {
    for (final f in _fields.values) {
      f
        ..pinned = null
        ..loadedTarget = null
        ..loadedText = null;
    }
  }

  void _onController() {
    if (!identical(_c.document, _document)) {
      _unbindDocument();
      _forgetTargets();
      _bindDocument();
    }
    _sync();
  }

  /// Review Focus 4: before the controller swaps the document, a focused
  /// field hands its focus back, and its focus-loss commit lands in the plan
  /// it was typed for (today's `_settlePendingInput`,
  /// `planner_shell.dart:855-865`).
  void _settle() {
    var any = false;
    for (final f in _fields.values) {
      if (f.focus.hasFocus) {
        f.focus.handBack();
        any = true;
      }
    }
    if (any) FocusManager.instance.applyFocusChangesIfNeeded();
  }

  // ---- targets ----

  /// The one selected key's target when it is a root-level key.
  Handle? get _single {
    final keys = _c.selection.keys;
    if (keys.length != 1) return null;
    final key = keys.single;
    return key.chain.isEmpty ? key.target : null;
  }

  _ObjectTarget? get _objectTarget {
    final h = _single;
    if (h == null || _c.isLocked(h)) return null;
    final typeId = _c.catalog.typeIdOf(_c.document, h);
    if (typeId == null || planTypeOf(_c, typeId) == null) return null;
    return _ObjectTarget(h, typeId);
  }

  _SymbolTarget? get _symbolTarget {
    final h = _single;
    if (h == null || _c.isLocked(h) || !isSymbolInstance(_c.document, h)) {
      return null;
    }
    return _SymbolTarget(h);
  }

  _UnitTarget? get _unitTarget {
    final h = _single;
    if (h == null || _c.isLocked(h)) return null;
    return placedUnitOf(_c.unitIndex, h) == null ? null : _UnitTarget(h);
  }

  _ToolTarget? get _toolTarget {
    final id = _c.activeTool.value;
    return planToolOf(_c, id)?.settings == null ? null : _ToolTarget(id);
  }

  _Target? _targetOf(_Field f) => switch (f.scope) {
        _Scope.object => _objectTarget,
        _Scope.tool => _toolTarget,
        _Scope.symbol => _symbolTarget,
        _Scope.unit => _unitTarget,
      };

  /// [t]'s fields, bound now; none when [t] is no longer a live object of
  /// its type, or when a kit hook threw binding them ([_fieldsOrNull]).
  List<PropertyField> _bound(_Target t) => _fieldsOrNull(t) ?? const [];

  /// [t]'s fields, bound now, or null when a kit's hook threw binding them
  /// (a spec's `read` or `enabled`): spec P4, every kit hook at the
  /// contract's boundary. The failure is one diagnostic ([_hookFailed]);
  /// the panel's builds, listeners and focus changes go on.
  List<PropertyField>? _fieldsOrNull(_Target t) {
    final c = _c;
    switch (t) {
      case _ObjectTarget(:final handle, :final typeId):
        if (c.catalog.typeIdOf(c.document, handle) != typeId) return const [];
        try {
          return planTypeOf(c, typeId)!.fieldsOf(
              c.document, handle, c.servicesOf(kitOfKey(typeId)).words);
        } catch (error) {
          _hookFailed(typeId, 'properties', error);
          return null;
        }
      case _ToolTarget(:final toolId):
        final settings = planToolOf(c, toolId)?.settings;
        if (settings == null) return const [];
        try {
          return settings.fieldsOf(c.toolSettings.valueOf(toolId),
              (v) => c.toolSettings.store(toolId, v),
              toolId: toolId);
        } catch (error) {
          _hookFailed(toolId, 'settings', error);
          return null;
        }
      case _SymbolTarget():
        return const [];
      case _UnitTarget():
        return const [];
    }
  }

  PropertyField? _fieldOf(_Target t, String id) {
    for (final f in _bound(t)) {
      if (f.spec.id == id) return f;
    }
    return null;
  }

  // ---- reading and parsing ----

  /// What [f] shows for [t] now, or null when [t] is no longer live.
  String? _shown(_Target t, _Field f) {
    if (t case _SymbolTarget(:final handle)) {
      return isSymbolInstance(_c.document, handle)
          ? formatPanelNumber(shownRotation(_c.document, handle), _strings)
          : null;
    }
    if (t case _UnitTarget(:final handle)) {
      final u = placedUnitOf(_c.unitIndex, handle);
      return u == null ? null : (u.text ?? '');
    }
    final field = _fieldOf(t, f.id);
    return field == null ? null : _textOf(field);
  }

  String? _textOf(PropertyField field) {
    final value = field.value;
    switch (field.spec) {
      case TextProperty():
        return value is String ? value : null;
      case AngleProperty():
        return value is double
            ? formatPanelNumber(degreesShown(value), _strings)
            : null;
      case NumberProperty(:final decimals):
        return value is double
            ? formatPanelNumber(
                double.parse(value.toStringAsFixed(decimals)), _strings)
            : null;
      case LengthProperty():
        return value is double ? formatPanelNumber(value, _strings) : null;
      case ChoiceProperty() ||
            ToggleProperty() ||
            ValueDisplay() ||
            TextDisplay() ||
            ActionProperty():
        return null;
    }
  }

  double? _number(String text) {
    final v = parsePanelNumber(text, _strings);
    return v != null && v.isFinite ? v : null;
  }

  /// [f]'s text as the input to commit to [t], or null when the field
  /// reverts instead.
  Object? _parse(_Target t, _Field f) {
    final text = f.text.text.trim();
    if (t is _SymbolTarget) return _number(text);
    if (t case _UnitTarget(:final handle)) {
      final u = placedUnitOf(_c.unitIndex, handle);
      if (u == null) return null;
      final refusal = labelRefusal(_c.unitIndex, u, text);
      if (refusal == null) return text;
      // The line is not cleared here: Enter's focus-loss commit re-reads
      // the reverted text, which must not end it (today's T14).
      _labelError = refusal;
      _labelErrorFor = handle;
      return null;
    }
    final field = _fieldOf(t, f.id);
    if (field == null) return null;
    switch (field.spec) {
      case TextProperty(:final maxLength):
        return maxLength != null && text.runes.length > maxLength ? null : text;
      case AngleProperty():
        final degrees = _number(text);
        return degrees == null ? null : degrees * math.pi / 180;
      case LengthProperty() || NumberProperty():
        return _number(text);
      case ChoiceProperty() ||
            ToggleProperty() ||
            ValueDisplay() ||
            TextDisplay() ||
            ActionProperty():
        return null;
    }
  }

  /// Whether [t]'s field [id] edits (today's `_editable` and `_capable`,
  /// `selection_panel.dart:356-391`).
  bool _editable(_Target t, String id) {
    final c = _c;
    final engine = c.document.commands.permissions;
    switch (t) {
      case _SymbolTarget(:final handle):
        // A rotation is a TransformNodeCommand (09c D7); a placed unit's
        // also re-stamps its label (V-1).
        return c.permissions.rotate && _turnableAt(handle);
      case _UnitTarget():
        // A label is entity text (today's _editable, :362-366).
        return c.permissions.relabel && engine.allows(Capability.geometry);
      case _ToolTarget():
        // A tool's settings are no edit of the document (:73).
        final field = _fieldOf(t, id);
        return field != null && field.enabled && field.commit != null;
      case _ObjectTarget(:final typeId):
        final field = _fieldOf(t, id);
        if (field == null || !field.enabled || field.commit == null) {
          return false;
        }
        final gate = field.spec.gate;
        if (gate != null && !c.permissions.allows(gate)) return false;
        return engine.allows(Capability.components) &&
            engine.allows(planTypeOf(c, typeId)!.parametric.editCapability);
    }
  }

  /// Whether [symbol] can be turned or mirrored now (today's `_turnableAt`,
  /// selection_panel.dart:486-491): `transform`, and for a placed unit, whose
  /// label is re-stamped by the same step, `geometry` too -- a unit turns in
  /// the design mode only (V-1, 14a Q-4). Asked of the pinned target at a
  /// commit, which the selection may no longer be.
  bool _turnableAt(Handle symbol) {
    final engine = _c.document.commands.permissions;
    if (!engine.allows(Capability.transform)) return false;
    return placedUnitOf(_c.unitIndex, symbol) == null ||
        engine.allows(Capability.geometry);
  }

  // ---- writing ----

  String _kitOf(_Target t) => switch (t) {
        _ObjectTarget(:final typeId) => kitOfKey(typeId),
        _ToolTarget(:final toolId) => kitOfKey(toolId),
        _SymbolTarget() => 'plan',
        _UnitTarget() => 'plan',
      };

  /// Runs [edit]. A commit goes through `controller.execute`, which catches
  /// every refusal itself (the lock hint, the diagnostics) and answers
  /// false. What can throw here is what runs before it: the spec's refusals
  /// (`ArgumentError` out of range, `StateError` disabled: Task 3) change
  /// nothing and the field shows the stored value; anything else a kit's
  /// `write` or `apply` threw is one diagnostic (spec P4).
  void _guarded(_Target t, String what, void Function() edit) {
    final c = _c;
    try {
      edit();
    } on ArgumentError {
      // Refused by the spec: nothing changed.
    } on StateError {
      // Refused: a disabled field. Nothing changed.
    } on Object catch (error) {
      c.diagnosticsLog.report(KitDiagnostic(
          kitId: _kitOf(t),
          subject: switch (t) {
            _ObjectTarget(:final typeId) => typeId,
            _ToolTarget(:final toolId) => toolId,
            _SymbolTarget() => 'plan.symbol',
            _UnitTarget() => 'plan.unit',
          },
          code: KitDiagnosticCode.hookFailed,
          message: '$what threw',
          error: error));
    }
  }

  /// Stores [input] as [t]'s field [id]: one command for an object or a
  /// symbol, the settings for a tool, nothing when the value is unchanged.
  void _write(_Target t, String id, Object? input) {
    final c = _c;
    _guarded(t, 'the property "$id"', () {
      switch (t) {
        case _SymbolTarget(:final handle):
          final command =
              rotateSymbolCommand(c.document, handle, input! as double);
          if (command != null) c.execute(command);
        case _UnitTarget(:final handle):
          final u = placedUnitOf(c.unitIndex, handle);
          if (u == null) return;
          final command = unitLabelCommand(c.document, u, input! as String);
          if (command != null) c.execute(command);
        case _ObjectTarget(:final handle, :final typeId):
          final field = _fieldOf(t, id);
          if (field == null || (input != null && input == field.value)) {
            return;
          }
          final command = planTypeOf(c, typeId)!.commitField(c.document, handle,
              field, input, c.servicesOf(kitOfKey(typeId)).words);
          // A value the spec rounds back to the stored one (2.31 at one
          // decimal over 2.3) writes nothing: no empty undo step (final
          // review).
          if (command is SetComponentCommand &&
              command.value == _componentOf(handle, typeId)) {
            return;
          }
          c.execute(command);
        case _ToolTarget():
          final field = _fieldOf(t, id);
          if (field == null || (input != null && input == field.value)) {
            return;
          }
          field.commit!(input);
      }
    });
  }

  /// [handle]'s component of [typeId], read without its `T`.
  Component? _componentOf(Handle handle, String typeId) {
    for (final (id, component)
        in _c.document.components.snapshotOf(handle).components) {
      if (id == typeId) return component;
    }
    return null;
  }

  /// A click (a toggle, a choice, an action) acts on the target shown now.
  void _act(_Target t, String id, Object? input) {
    _write(t, id, input);
    if (mounted) setState(() {});
  }

  // ---- the field cycle (selection_panel.dart:760-1008) ----

  _Field _fieldFor(_Scope scope, String id) =>
      _fields.putIfAbsent((scope, id), () {
        final f = _Field(scope, id);
        f.focus.addListener(() => _onFocusChange(f));
        _show(f);
        return f;
      });

  /// Records the target on focus gain; commits on focus loss. `??=`: a
  /// focused node that notifies again keeps its pin.
  void _onFocusChange(_Field f) {
    if (f.focus.hasFocus) {
      f.pinned ??= _targetOf(f);
      return;
    }
    _commit(f);
  }

  /// Commits [f]'s text to its pinned target, then shows the current
  /// target's value. Text equal to what the field shows for the stored
  /// value commits nothing.
  void _commit(_Field f) {
    final t = f.pinned;
    if (t != null) {
      final shown = _shown(t, f);
      if (shown != null && f.text.text.trim() != shown && _editable(t, f.id)) {
        final input = _parse(t, f);
        if (input != null) _write(t, f.id, input);
      }
    }
    _show(f);
    f.pinned = f.focus.hasFocus ? _targetOf(f) : null;
    if (mounted) setState(() {});
  }

  /// Writes the current target's value into [f], unconditionally.
  void _show(_Field f) {
    final t = _targetOf(f);
    final shown = t == null ? null : _shown(t, f);
    f.loadedTarget = shown == null ? null : t;
    f.loadedText = shown;
    if (shown != null && f.text.text != shown) f.text.text = shown;
  }

  /// Copies the model into the fields, never into a focused one, and only
  /// where the target or its shown value changed (06 D13 F1).
  void _load() {
    for (final f in _fields.values) {
      final t = _targetOf(f);
      final shown = t == null ? null : _shown(t, f);
      if (shown == null) {
        f.loadedTarget = null;
        f.loadedText = null;
        continue;
      }
      if (f.focus.hasFocus) continue;
      if (t == f.loadedTarget && shown == f.loadedText) continue;
      _show(f);
    }
  }

  void _sync() {
    // A selection change ends the label field's refusal line.
    if (_labelError != null && _labelErrorFor != _unitTarget?.handle) {
      _labelError = null;
    }
    _load();
    if (mounted) setState(() {});
  }

  /// 07 D11, 08 D16: while a tool's settings show, every valid keystroke
  /// reaches them at once (a canvas click accepts its point before the
  /// field's focus-loss commit runs).
  void _onChanged(_Field f) {
    if (f.scope == _Scope.unit && _labelError != null) {
      setState(() => _labelError = null);
    }
    final t = f.pinned;
    if (t is! _ToolTarget) return;
    final input = _parse(t, f);
    if (input != null) _write(t, f.id, input);
  }

  // ---- widgets ----

  Widget _textField(Key key, String label, _Field f, bool editable,
          {String? suffix, bool signed = false, bool isText = false}) =>
      PlanTextField(
        key: key,
        controller: f.text,
        focusNode: f.focus,
        readOnly: !editable,
        // No maxLength formatter: a text over the spec's maxLength is
        // refused at the commit and the field reverts (Task 3's refusal).
        label: label,
        suffix: suffix,
        keyboardType: isText
            ? TextInputType.text
            : TextInputType.numberWithOptions(decimal: true, signed: signed),
        onChanged: (_) => _onChanged(f),
        onSubmitted: (_) => _commit(f),
        // Enter hands the focus back to the canvas, past any other panel
        // field (fix/post-07 F3); onSubmitted still runs after it.
        onEditingComplete: f.focus.handBack,
        // Only unfocuses (06 D13 F2): the commit is _onFocusChange's.
        onTapOutside: (_) => f.focus.handBack(),
      );

  String _valueText(Object? value, ValueUnit unit) {
    if (value is! double) return '—';
    return switch (unit) {
      ValueUnit.length => '${formatPanelNumber(value, _strings)} mm',
      ValueUnit.area => '${formatPanelNumber(value / 1e6, _strings)} m²',
      ValueUnit.angle => '${formatPanelNumber(degreesShown(value), _strings)}°',
      ValueUnit.none => formatPanelNumber(value, _strings),
    };
  }

  Widget _row(_Target t, _Scope scope, PropertyField field, String kitId) {
    final id = field.spec.id;
    final name = '${scope == _Scope.tool ? 'setting' : 'property'}-$id';
    final key = Key(name);
    final label = planWordOf(_c, kitId, field.wordId) ?? id;
    final editable = _editable(t, id);
    switch (field.spec) {
      case LengthProperty():
        return _textField(key, label, _fieldFor(scope, id), editable,
            suffix: 'mm');
      case AngleProperty():
        return _textField(key, label, _fieldFor(scope, id), editable,
            suffix: '°', signed: true);
      case NumberProperty(:final min):
        return _textField(key, label, _fieldFor(scope, id), editable,
            signed: min == null || min < 0);
      case TextProperty():
        return _textField(key, label, _fieldFor(scope, id), editable,
            isText: true);
      case ToggleProperty():
        // Its own width: the row is the tap target, not the panel's width.
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: PlanSwitchRow(
            key: key,
            label: label,
            value: field.value == true,
            onChanged: editable ? (v) => _act(t, id, v) : null,
          ),
        );
      case ChoiceProperty(:final values):
        final focus = _choiceFocus.putIfAbsent(
            name, () => PanelFieldFocusNode(debugLabel: name));
        return PlanSelect<Object?>(
          key: key,
          expanded: true,
          focusNode: focus,
          label: label,
          value: field.value,
          enabled: editable,
          options: [
            for (final v in values)
              PlanOption<Object?>(
                  v,
                  planWordOf(_c, kitId,
                          '${field.wordId}.${ChoiceProperty.segmentOf(v)}') ??
                      ChoiceProperty.segmentOf(v),
                  key: Key('$name-${ChoiceProperty.segmentOf(v)}')),
          ],
          onChanged: (v) {
            _act(t, id, v);
            _handBackAfterChoice(focus);
          },
        );
      case ValueDisplay(:final unit):
        return PlanReadOnlyField(
          label: label,
          child: Text(_valueText(field.value, unit), key: key),
        );
      case TextDisplay():
        // Spec 3a C1.1: a read-only line, the text as the kit read it.
        return PlanReadOnlyField(
          label: label,
          child: Text(field.value as String? ?? '', key: key),
        );
      case ActionProperty():
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ShadButton.outline(
              key: key,
              width: double.infinity,
              onPressed: editable ? () => _act(t, id, null) : null,
              child: Text(label)),
        );
    }
  }

  /// Hands the focus from choice row [focus] back to the canvas once a
  /// choice is made. `DropdownButton` took the focus for the row when its
  /// menu opened, and the menu's route gives it back to the row as it
  /// closes -- after `onChanged` runs, so the row does not have it yet
  /// here. So the hand-back waits for the row to gain it, within the
  /// frame; a row that already has it hands it back at once.
  void _handBackAfterChoice(PanelFieldFocusNode focus) {
    if (focus.hasFocus) {
      focus.handBack();
      return;
    }
    void restored() {
      focus.removeListener(restored);
      if (focus.hasFocus) focus.handBack();
    }

    focus.addListener(restored);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => focus.removeListener(restored));
  }

  /// Whether [field] of [t] takes a row (spec 3a C1.7): not when its
  /// `visible` says no (a text display that read nothing included), nor an
  /// object's action whose gate the permissions refuse (today's S-11: a
  /// button the capabilities refuse is not shown). A hidden field takes no
  /// room.
  bool _shows(_Target t, PropertyField field) {
    if (!field.visible) return false;
    final gate = field.spec.gate;
    return !(t is _ObjectTarget &&
        field.spec is ActionProperty &&
        gate != null &&
        !_c.permissions.allows(gate));
  }

  /// One `hookFailed` diagnostic for [subject] (a type or a tool id) of its
  /// kit: published after the frame, since a build may call it; the log
  /// keeps one per kit, subject and code.
  void _hookFailed(String subject, String hook, Object error) =>
      _c.diagnosticsLog.addAfterFrame(KitDiagnostic(
          kitId: kitOfKey(subject),
          subject: subject,
          code: KitDiagnosticCode.hookFailed,
          message: '$hook: $error',
          error: error));

  /// What replaces a section whose kit hook threw while it was being built
  /// (spec P4): Task 11's "section failed" box (`KitSectionBoundary`).
  Widget _sectionFailed() {
    final theme = planShadThemeOf(context);
    final error = theme.colorScheme.destructive;
    return Container(
      key: const Key('kit-section-failed'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: error),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(_strings.sectionFailed,
          style: theme.textTheme.small.copyWith(color: error)),
    );
  }

  List<Widget> _settingsSection(_ToolTarget t, TextStyle? title) {
    final kit = kitOfKey(t.toolId);
    final fields = _fieldsOrNull(t);
    if (fields == null) return [_sectionFailed()];
    return [
      Text(planWordOf(_c, kit, 'tool:${t.toolId}') ?? t.toolId,
          key: Key('settings-${t.toolId}'), style: title),
      for (final field in fields)
        if (_shows(t, field)) _row(t, _Scope.tool, field, kit),
    ];
  }

  /// The type's title word for [t], or null when its `title` hook threw
  /// (one diagnostic).
  String? _titleWordOf(PlanType<Component> type, _ObjectTarget t) {
    try {
      return type.titleWordOf(_c.document, t.handle);
    } catch (error) {
      _hookFailed(t.typeId, 'title', error);
      return null;
    }
  }

  List<Widget> _objectSection(_ObjectTarget t, TextStyle? title) {
    final c = _c;
    final doc = c.document;
    final type = planTypeOf(c, t.typeId)!;
    final kit = kitOfKey(t.typeId);
    // Spec P4: a hook that throws while the section builds (a title, a
    // spec's read or enabled) replaces the whole section by the box.
    final titleWord = _titleWordOf(type, t);
    final fields = _fieldsOrNull(t);
    if (titleWord == null || fields == null) return [_sectionFailed()];
    return [
      Text(planWordOf(c, kit, titleWord) ?? t.typeId,
          key: Key('section-${t.typeId}'), style: title),
      for (final field in fields)
        if (_shows(t, field)) _row(t, _Scope.object, field, kit),
      if (type.hasSection)
        // Spec P4: a section builder that throws shows a small box in its
        // place (Task 11's boundary).
        KitSectionBoundary(
          kitId: kit,
          typeId: t.typeId,
          log: c.diagnosticsLog,
          builder: (context) => type.sectionFor(
              context,
              doc,
              t.handle,
              (command) => _guarded(
                  t, 'the section\'s commit', () => c.execute(command)),
              c.servicesOf(kit).words,
              c.servicesOf(kit)),
        ),
    ];
  }

  /// The Symbol section (09c D7; `selection_panel.dart:1122-1191`).
  List<Widget> _symbolSection(_SymbolTarget t, TextStyle? title) {
    final c = _c;
    final doc = c.document;
    final h = t.handle;
    final node = doc.tree[h]! as InstanceNode;
    final component = doc.components.get<SymbolComponent>(node.definition)!;
    final box = boxOfDefinition(doc, node.definition);
    final members = sizeMenuMembers(symbolEntriesOf(c.symbols), doc, h);
    String size(SymbolBox b) => '${formatPanelNumber(b.width, _strings)} × '
        '${formatPanelNumber(b.depth, _strings)}';
    final p = c.permissions;
    final engine = doc.commands.permissions;
    final turnable = _turnableAt(h);
    final resizable = engine.allows(Capability.structure) &&
        engine.allows(Capability.geometry) &&
        engine.allows(Capability.components) &&
        turnable;
    final name = c
            .namesOf(kitOfKey(component.key))
            ?.symbolName(_strings.languageCode, component) ??
        component.name;
    return [
      Text(_strings.toolSymbol, key: const Key('symbol-section'), style: title),
      PlanReadOnlyField(
        label: _strings.name,
        child: Text(name, key: const Key('symbol-name')),
      ),
      PlanReadOnlyField(
        label: _strings.size,
        child:
            Text(box == null ? '—' : size(box), key: const Key('symbol-size')),
      ),
      _textField(const Key('symbol-rotation'), _strings.rotation,
          _fieldFor(_Scope.symbol, 'rotation'), _editable(t, 'rotation'),
          suffix: '°', signed: true),
      // A button the permissions refuse is not shown (S-11).
      if (p.mirror)
        ShadButton.outline(
          key: const Key('symbol-mirror'),
          width: double.infinity,
          onPressed: turnable
              ? () => _guarded(t, 'Mirror', () {
                    final command = mirrorSymbolCommand(doc, h);
                    if (command != null) c.execute(command);
                  })
              : null,
          leading: const Icon(LucideIcons.flipHorizontal),
          child: Flexible(
              child: Text(_strings.mirror, overflow: TextOverflow.ellipsis)),
        ),
      if (members.isNotEmpty && p.reshape)
        PlanSelect<SymbolEntry>(
          key: const Key('symbol-size-menu'),
          expanded: true,
          value:
              members.where((m) => m.symbol.key == component.key).firstOrNull,
          enabled: resizable,
          options: [
            for (final m in members)
              PlanOption<SymbolEntry>(m, size(boxOfEntry(m)!),
                  key: Key('symbol-size-${m.symbol.key}')),
          ],
          onChanged: (m) {
            _guarded(t, 'Change size', () {
              final command = changeSizeCommand(doc, h, m);
              if (command != null) c.execute(command);
            });
            if (mounted) setState(() {});
          },
        ),
    ];
  }

  /// The unit section (spec S4; today's Table section,
  /// selection_panel.dart:1193-1248).
  List<Widget> _unitSection(_UnitTarget t, TextStyle? title) {
    final c = _c;
    final u = placedUnitOf(c.unitIndex, t.handle)!;
    final error =
        _labelErrorFor == t.handle ? _labelError?.call(_strings) : null;
    final shared = u.text == null ? 0 : c.unitIndex.withLabel(u.text!).length;
    final theme = planShadThemeOf(context);
    final engine = c.document.commands.permissions;
    final turnable = engine.allows(Capability.transform) &&
        engine.allows(Capability.geometry);
    return [
      Text(unitKindWord(c, u), key: const Key('unit-section'), style: title),
      _textField(
          const Key('unit-label'),
          u.labelling == UnitLabelling.assigned
              ? _strings.label
              : _strings.number,
          _fieldFor(_Scope.unit, 'label'),
          _editable(t, 'label'),
          isText: true),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(error,
              key: const Key('unit-label-error'),
              style: theme.textTheme.small
                  .copyWith(color: theme.colorScheme.destructive)),
        ),
      if (shared > 1)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
              _strings
                  .labelWarning(DuplicateLabel(label: u.text!, count: shared)),
              key: const Key('unit-label-duplicate'),
              style: theme.textTheme.small
                  .copyWith(color: theme.colorScheme.mutedForeground)),
        ),
      PlanReadOnlyField(
        label: _strings.capacity,
        child: Text('${u.capacity}', key: const Key('unit-capacity')),
      ),
      // A button the permissions refuse is not shown (S-11).
      // One above the other, each the column's width: side by side, a
      // docked column or a phone's drawer cut their words.
      if (turnable && c.permissions.rotate) ...[
        ShadButton.outline(
          key: const Key('unit-rotate-left'),
          width: double.infinity,
          onPressed: () => _rotateUnit(t, 1),
          leading: const Icon(LucideIcons.rotateCcw),
          child: Flexible(
              child:
                  Text(_strings.rotateLeft, overflow: TextOverflow.ellipsis)),
        ),
        ShadButton.outline(
          key: const Key('unit-rotate-right'),
          width: double.infinity,
          onPressed: () => _rotateUnit(t, -1),
          leading: const Icon(LucideIcons.rotateCw),
          child: Flexible(
              child:
                  Text(_strings.rotateRight, overflow: TextOverflow.ellipsis)),
        ),
      ],
    ];
  }

  /// Today's `_rotateTable` (:685-701): one Rotate step about the base
  /// point; a refusal is caught inside `execute`.
  void _rotateUnit(_UnitTarget t, int quarterTurns) =>
      _guarded(t, 'Rotate', () {
        final command = rotateUnitCommand(_c.document, t.handle, quarterTurns);
        if (command != null) _c.execute(command);
      });

  @override
  Widget build(BuildContext context) => PlanShadScope(child: _body(context));

  Widget _body(BuildContext context) {
    final c = _c;
    // A parent rebuild may arrive before the controller's notification.
    if (!identical(c.document, _document)) {
      _unbindDocument();
      _forgetTargets();
      _bindDocument();
    }
    // A section's title stands above its fields' labels (`small`).
    final title = planShadThemeOf(context).textTheme.large;
    final tool = _toolTarget;
    final object = _objectTarget;
    final symbol = object == null ? _symbolTarget : null;
    final unit = tool == null && object == null ? _unitTarget : null;
    // CP1, CP11 (M-PC9-tool): no colour row while a tool's settings show.
    final colours = tool == null &&
        (colourTargets(c, c.selection.keys).isNotEmpty ||
            unitColourTargets(c, c.selection.keys).isNotEmpty);
    final sections = <List<Widget>>[
      if (tool != null) _settingsSection(tool, title),
      if (object != null) _objectSection(object, title),
      if (symbol != null) _symbolSection(symbol, title),
      if (unit != null) _unitSection(unit, title),
      if (colours)
        [
          ColourRow(
              controller: c,
              darkCanvasPaper: darkCanvasFor(
                      page: c.page.value?.background,
                      brightness: Theme.of(context).brightness)
                  ? kDarkCanvasPaper
                  : null),
        ],
      // The layer field (Task 18 fills the slot): a non-empty selection,
      // no tool's settings, changeLayer on (selection_panel.dart:1256-1263).
      if (propertyPanelLayerField case final layer?
          when tool == null &&
              c.selection.keys.isNotEmpty &&
              c.permissions.changeLayer)
        if (layer(context, c) case final field?) [field],
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return PlanShortcutGuard(
      controller: c,
      child: Material(
        key: const Key('property-panel'),
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Room between a section's rows, and more between sections.
              for (final (i, section) in sections.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                for (final (j, row) in section.indexed) ...[
                  if (j > 0) const SizedBox(height: 8),
                  row,
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
