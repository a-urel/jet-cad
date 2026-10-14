// Spec P2 "Permissions": what the plan's widgets let their user do. The
// select gates, the palette and selectTool, the panels and the controller's
// widget-facing commands read it; a host's own calls are not gated. 2b adds
// the service flags and a units-only profile.
import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftPermissions;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanGate;

/// The editor's permissions (spec P2).
///
/// - [tools]: the tool ids offered (the palette, the letters,
///   `PlanController.selectTool`); null offers every tool. `plan.select` is
///   always offered, whatever the set says. [copyWith] copies the set it
///   is given, unmodifiable; the `const` constructor keeps the set as
///   given.
/// - [move], [rotate], [mirror], [reshape], [delete]: the select tool's
///   gates and the panel's matching fields; [changeLayer], [recolor]: the
///   panel's layer field and colour row; [editLayers], [editPage]: the
///   Layer and Page panels; [undo]: the Undo and Redo buttons and chords;
///   [export], [print]: theirs. A property spec's `gate` names one of the
///   first nine ([allows]).
/// - [draft]: what the document's own `DraftPermissions` become.
@immutable
final class PlanPermissions {
  const PlanPermissions({
    this.tools,
    this.move = true,
    this.rotate = true,
    this.mirror = true,
    this.reshape = true,
    this.delete = true,
    this.changeLayer = true,
    this.recolor = true,
    this.editLayers = true,
    this.editPage = true,
    this.undo = true,
    this.export = true,
    this.print = true,
  });

  /// Every tool, every flag on: today's editor.
  static const PlanPermissions full = PlanPermissions();

  /// Select, pan and zoom; no edit, no undo. Export and print stay: neither
  /// is an edit.
  static const PlanPermissions readOnly = PlanPermissions(
    tools: {_select},
    move: false,
    rotate: false,
    mirror: false,
    reshape: false,
    delete: false,
    changeLayer: false,
    recolor: false,
    editLayers: false,
    editPage: false,
    undo: false,
  );

  static const String _select = 'plan.select';

  final Set<String>? tools;
  final bool move, rotate, mirror, reshape, delete;
  final bool changeLayer, recolor, editLayers, editPage;
  final bool undo, export, print;

  /// Whether the tool [id] is offered: `plan.select` always, else by
  /// [tools] (null: every id).
  bool allowsTool(String id) => id == _select || (tools?.contains(id) ?? true);

  /// Whether [gate]'s flag is on.
  bool allows(PlanGate gate) => switch (gate) {
        PlanGate.move => move,
        PlanGate.rotate => rotate,
        PlanGate.mirror => mirror,
        PlanGate.reshape => reshape,
        PlanGate.delete => delete,
        PlanGate.changeLayer => changeLayer,
        PlanGate.recolor => recolor,
        PlanGate.editLayers => editLayers,
        PlanGate.editPage => editPage,
      };

  /// Whether anything may be edited: an edit flag, or a tool other than
  /// `plan.select` (a drawing tool or a kit's).
  bool get edits =>
      move ||
      rotate ||
      mirror ||
      reshape ||
      delete ||
      changeLayer ||
      recolor ||
      editLayers ||
      editPage ||
      (tools?.any((id) => id != _select) ?? true);

  /// The document's engine permissions: [DraftPermissions.readOnly] when
  /// nothing may be edited ([edits] false), else [DraftPermissions.all].
  /// An engine group maps onto several flags, so it closes only when every
  /// one of them is off.
  DraftPermissions get draft =>
      edits ? DraftPermissions.all : DraftPermissions.readOnly;

  /// A copy with the given fields replaced; a null argument keeps the
  /// field (so `copyWith(tools: null)` keeps the set: start from [full] for
  /// every tool). A given [tools] is copied, unmodifiable.
  PlanPermissions copyWith({
    Set<String>? tools,
    bool? move,
    bool? rotate,
    bool? mirror,
    bool? reshape,
    bool? delete,
    bool? changeLayer,
    bool? recolor,
    bool? editLayers,
    bool? editPage,
    bool? undo,
    bool? export,
    bool? print,
  }) =>
      PlanPermissions(
        tools: tools == null ? this.tools : Set.unmodifiable(tools),
        move: move ?? this.move,
        rotate: rotate ?? this.rotate,
        mirror: mirror ?? this.mirror,
        reshape: reshape ?? this.reshape,
        delete: delete ?? this.delete,
        changeLayer: changeLayer ?? this.changeLayer,
        recolor: recolor ?? this.recolor,
        editLayers: editLayers ?? this.editLayers,
        editPage: editPage ?? this.editPage,
        undo: undo ?? this.undo,
        export: export ?? this.export,
        print: print ?? this.print,
      );

  /// The flags, in declaration order, by name.
  List<(String, bool)> get _flags => [
        ('move', move),
        ('rotate', rotate),
        ('mirror', mirror),
        ('reshape', reshape),
        ('delete', delete),
        ('changeLayer', changeLayer),
        ('recolor', recolor),
        ('editLayers', editLayers),
        ('editPage', editPage),
        ('undo', undo),
        ('export', export),
        ('print', print),
      ];

  @override
  bool operator ==(Object other) {
    if (other is! PlanPermissions || !setEquals(other.tools, tools)) {
      return false;
    }
    final a = other._flags, b = _flags;
    for (var i = 0; i < a.length; i++) {
      if (a[i].$2 != b[i].$2) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      tools == null ? null : Object.hashAllUnordered(tools!),
      Object.hashAll([for (final (_, v) in _flags) v]));

  /// The fields that differ from [full], as `name: value`; the tools
  /// sorted.
  @override
  String toString() => 'PlanPermissions(${[
        if (tools case final t?) 'tools: {${(t.toList()..sort()).join(', ')}}',
        for (final (n, v) in _flags)
          if (!v) '$n: $v',
      ].join(', ')})';
}
