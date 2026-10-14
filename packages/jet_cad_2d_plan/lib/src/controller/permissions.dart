// Spec P2 "Permissions" (2a) and 2b S4 "Permissions": what the plan's
// widgets let their user do. The select gates, the palette and selectTool,
// the panels and the controller's widget-facing commands read it; a host's
// own calls are not gated. 2b adds relabel (today's renumber),
// selectUnitsOnly (today's selectTablesOnly), the two service flags
// (serviceMove, today's view parameter serviceMoves; serviceMerge, Merge and
// Split), the unitsOnly profile and the gallery filter isUnitSymbol.
import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftPermissions;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanGate;

import '../symbols/plan_symbol.dart';

/// The editor's permissions (spec P2, 2b S4).
///
/// - [tools]: the tool ids offered (the palette, the letters,
///   `PlanController.selectTool`); null offers every tool. `plan.select` is
///   always offered, whatever the set says. [copyWith] copies the set it
///   is given, unmodifiable; the `const` constructor keeps the set as
///   given.
/// - [move], [rotate], [mirror], [reshape], [delete]: the select tool's
///   gates and the panel's matching fields; [changeLayer], [recolor]: the
///   panel's layer field and colour row; [editLayers], [editPage]: the
///   Layer and Page panels; [relabel]: the unit section's label field;
///   [undo]: the Undo and Redo buttons and chords; [export], [print]:
///   theirs. A property spec's `gate` names one of the first ten
///   ([allows]).
/// - [selectUnitsOnly]: the design's click and band pick placed units only
///   (a restriction: off in [full]).
/// - [serviceMove]: the service view's drags move units; [serviceMerge]:
///   the service bar offers Merge and Split (still only with their
///   callbacks). The design flags do not gate service (spec S4).
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
    this.relabel = true,
    this.undo = true,
    this.export = true,
    this.print = true,
    this.selectUnitsOnly = false,
    this.serviceMove = true,
    this.serviceMerge = true,
  });

  /// Every tool, every flag on, no restriction: today's editor.
  static const PlanPermissions full = PlanPermissions();

  /// Select, pan and zoom; no edit, no undo. Export and print stay: neither
  /// is an edit. The service flags stay: the profile governs the editor.
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
    relabel: false,
    undo: false,
  );

  /// Today's `tablesOnly` (editor_capabilities.dart:175-190): select and
  /// place symbols; no mirror, reshape or layer change; no layer or page
  /// editing; the click and the band pick placed units only. Hiding the
  /// Layer and Page panels is `PlanEditor`'s options (2a P7); the gallery's
  /// filter is [isUnitSymbol].
  static const PlanPermissions unitsOnly = PlanPermissions(
    tools: {_select, _symbol},
    mirror: false,
    reshape: false,
    changeLayer: false,
    editLayers: false,
    editPage: false,
    selectUnitsOnly: true,
  );

  static const String _select = 'plan.select';
  static const String _symbol = 'plan.symbol';

  final Set<String>? tools;
  final bool move, rotate, mirror, reshape, delete;
  final bool changeLayer, recolor, editLayers, editPage, relabel;
  final bool undo, export, print;
  final bool selectUnitsOnly, serviceMove, serviceMerge;

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
        PlanGate.relabel => relabel,
      };

  /// Whether anything may be edited: an edit flag, or a tool other than
  /// `plan.select` (a drawing tool or a kit's). [selectUnitsOnly],
  /// [serviceMove] and [serviceMerge] are not edits of the design.
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
      relabel ||
      (tools?.any((id) => id != _select) ?? true);

  /// The document's engine permissions: [DraftPermissions.readOnly] when
  /// nothing may be edited ([edits] false), else [DraftPermissions.all].
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
    bool? relabel,
    bool? undo,
    bool? export,
    bool? print,
    bool? selectUnitsOnly,
    bool? serviceMove,
    bool? serviceMerge,
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
        relabel: relabel ?? this.relabel,
        undo: undo ?? this.undo,
        export: export ?? this.export,
        print: print ?? this.print,
        selectUnitsOnly: selectUnitsOnly ?? this.selectUnitsOnly,
        serviceMove: serviceMove ?? this.serviceMove,
        serviceMerge: serviceMerge ?? this.serviceMerge,
      );

  /// The flags, in declaration order: name, value and [full]'s value.
  List<(String, bool, bool)> get _flags => [
        ('move', move, true),
        ('rotate', rotate, true),
        ('mirror', mirror, true),
        ('reshape', reshape, true),
        ('delete', delete, true),
        ('changeLayer', changeLayer, true),
        ('recolor', recolor, true),
        ('editLayers', editLayers, true),
        ('editPage', editPage, true),
        ('relabel', relabel, true),
        ('undo', undo, true),
        ('export', export, true),
        ('print', print, true),
        ('selectUnitsOnly', selectUnitsOnly, false),
        ('serviceMove', serviceMove, true),
        ('serviceMerge', serviceMerge, true),
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
      Object.hashAll([for (final (_, v, _) in _flags) v]));

  /// The fields that differ from [full], as `name: value`; the tools
  /// sorted.
  @override
  String toString() => 'PlanPermissions(${[
        if (tools case final t?) 'tools: {${(t.toList()..sort()).join(', ')}}',
        for (final (n, v, d) in _flags)
          if (v != d) '$n: $v',
      ].join(', ')})';
}

/// The gallery's filter for [PlanPermissions.unitsOnly] (today's
/// `tablesOnly` filter, editor_capabilities.dart:209-211, widened by spec
/// S5): any symbol whose definition carries `jetcad.unit`, a seat
/// included. Pass it to `PlanSymbolGallery(filter:)` or
/// `PlanEditor(symbolFilter:)`.
bool isUnitSymbol(PlanSymbol symbol) => symbol.entry.unit != null;
