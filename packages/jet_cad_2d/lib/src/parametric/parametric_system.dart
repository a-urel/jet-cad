import 'package:meta/meta.dart';

import '../core/diagnostic.dart';
import '../core/handle.dart';
import '../core/tolerance.dart';
import '../document/command.dart';
import '../document/commands.dart';
import '../document/component.dart';
import '../document/draft_document.dart';
import '../document/drafting.dart';
import '../document/node.dart';
import '../document/style.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';

part 'regeneration.dart';

/// What one parametric type contributes (spec 06 D3). Behaviour lives here,
/// outside the document, which stays data only.
abstract class ParametricType<T extends Component> {
  const ParametricType();

  /// The capability a change of `T`'s value needs (spec D7).
  Capability get editCapability;

  /// The world region this object's generation depends on and affects,
  /// from parameters and the group's accumulated transform only.
  Aabb2 reach(T params, Transform2 toWorld);

  /// This object's entities, in the group's local space, from its own
  /// parameters and its neighbours' — never from generated geometry.
  List<Generated> generate(ParametricView view, Handle self);

  /// This client's report about one live object, [self] (spec 07 D12): a
  /// joint it could not build cleanly, a fallback it took. Called only by
  /// [ParametricSystem.diagnostics], with a view over a full survey, and
  /// must not mutate: an `execute` from here throws `StateError`, like one
  /// from [generate]. Default: nothing to report.
  List<Diagnostic> diagnose(ParametricView view, Handle self) => const [];

  /// The objects [params] reference (an opening: its host). An edit of a
  /// referent regenerates its referrers, and an edit of a referrer
  /// regenerates its referents (spec 08 D3). Default: none.
  ///
  /// Called once per live object per survey, twice per edit (spec 08 D2),
  /// including for an edit that touches no object: keep it a field read.
  /// A handle named here that is not a live parametric object is left out
  /// of the survey's maps; it relates nothing. For a [ReferencePolicy.cascade]
  /// type, an edit that leaves such a handle on one of its seeds is refused
  /// with [DanglingReferenceError]; a loaded one is reported by
  /// [ParametricSystem.diagnostics] (spec 08 D5).
  Iterable<Handle> references(T params) => const [];

  /// What happens to a live object of this type when an object it
  /// references stops being a live object (spec 08 D4). Default: cascade.
  ReferencePolicy get referencePolicy => ReferencePolicy.cascade;
}

/// A referrer's fate when its referent stops being a live object (spec 08
/// D4): its node removed, its component detached, or its group no longer
/// root-level.
enum ReferencePolicy {
  /// Deleted in the same edit, leaves then node, as the select tool deletes
  /// a group; transitively (an opening).
  cascade,

  /// Kept, and regenerated in the same edit: its `generate` sees
  /// `paramsOf(referent) == null` and decides what to draw. Reported by
  /// `diagnostics()` as `parametric.orphan`.
  orphan,
}

/// One generated entity (spec D3), one generated region (spec 07 D8), or
/// one generated TEXT (spec 10 D12).
///
/// The plain form is never a fill: a fill's payload is a reference to its
/// boundary, not geometry, and `SetEntityGeometryCommand` refuses it. A
/// filled area is generated with [Generated.region] instead. Nor is it a
/// TEXT or an ATTRIB: a TEXT is generated with [Generated.text], which
/// carries its string.
///
/// [color], [text], [textAttrs] and [flags] are written into the record
/// when the child is **added**, and only then: a regeneration rewrites a
/// matched child's payload in place, and a matched TEXT's string (spec 10
/// D12), and never the rest of its record (06 D11), so a client must keep
/// its colours, its text attributes and its flags fixed for an object's
/// life. ByLayer by default.
final class Generated {
  /// Throws `ArgumentError` for [EntityKind.fill] (see the class comment),
  /// and for [EntityKind.text] and [EntityKind.attrib] (spec 10 D12, R-15):
  /// a TEXT without its string is exactly the defect 10's research found,
  /// a label the planner would add empty; an ATTRIB needs a tag nobody
  /// generates.
  Generated(this.kind, this.payload, {this.color = const ByLayerColor()})
      : filled = false,
        text = '',
        textAttrs = 0,
        flags = 0 {
    if (kind == EntityKind.fill) {
      throw ArgumentError.value(
          kind, 'kind', 'a fill cannot be generated (spec 06 D3)');
    }
    if (kind == EntityKind.text || kind == EntityKind.attrib) {
      throw ArgumentError.value(
          kind,
          'kind',
          'a TEXT is generated with Generated.text, and an ATTRIB '
              'cannot be generated (spec 10 D12)');
    }
  }

  /// A region (spec 07 D8): a closed POLYLINE [payload] and the FILL that
  /// names it. The planner matches it through the object's fill children
  /// and rewrites only the boundary, in place; the fill record, whose
  /// payload is the boundary's handle, is never rewritten. [payload] must
  /// be a closed polyline with a non-empty triangulation, or the edit that
  /// generates it throws `ArgumentError` and is rolled back.
  ///
  /// [color] is the fill's and the boundary's both.
  Generated.region(this.payload, {this.color = const ByLayerColor()})
      : kind = EntityKind.polyline,
        filled = true,
        text = '',
        textAttrs = 0,
        flags = 0;

  /// A TEXT whose string the planner owns (spec 10 D12): [payload] is a
  /// `textPayload`, [text] is written into the record on add and rewritten
  /// on a match (`SetEntityTextCommand`) whenever it differs. [textAttrs]
  /// (`packTextAttrs`) is fixed at creation, like [color]: a type that must
  /// change a label's justification needs a new child.
  Generated.text(this.payload, this.text,
      {this.color = const ByLayerColor(), this.textAttrs = 0, this.flags = 0})
      : kind = EntityKind.text,
        filled = false;

  /// [EntityKind.polyline] for a region: the kind of its boundary.
  final EntityKind kind;
  final GeometryPayload payload;

  /// True for a region: [payload] is the boundary of a generated fill.
  final bool filled;

  /// The colour an added child's record gets (both records of a region).
  final DraftColor color;

  /// A TEXT's string (spec 10 D12); `''` for every other form.
  final String text;

  /// A TEXT's packed justification and override bits, written on add only;
  /// 0 for every other form.
  final int textAttrs;

  /// The record's `flags`, written on add only.
  final int flags;
}

/// A direct edit of a generated entity (spec D6). Propagates like
/// `PermissionDeniedError`; the UI never offers the edit.
class GeneratedGeometryError implements Exception {
  const GeneratedGeometryError(this.handle);

  final Handle handle;

  @override
  String toString() => 'GeneratedGeometryError: ${handle.toHex()} is '
      'generated by a parametric object and cannot be edited directly';
}

/// An edit that would leave a `cascade`-policy seed naming a handle that is
/// not a live parametric object (spec 08 D5). The edit is rolled back, the
/// cascade included, and nothing enters the history. Propagates like
/// [GeneratedGeometryError]; the UI never builds such an edit.
class DanglingReferenceError implements Exception {
  const DanglingReferenceError(this.object, this.referent);

  /// The referring object.
  final Handle object;

  /// The handle it names, which is not a live parametric object.
  final Handle referent;

  @override
  String toString() => 'DanglingReferenceError: ${object.toHex()} references '
      '${referent.toHex()}, which is not a live parametric object';
}

/// Read-only access for [ParametricType.generate] and
/// [ParametricType.diagnose].
final class ParametricView {
  ParametricView._(this._target, this._survey);

  final CommandTarget _target;
  final _Survey _survey;

  /// [h]'s component of type [U], or null, and null for any handle that is
  /// not a live object of the survey this view was built over (inside an
  /// edit, `drift()` and `diagnostics()` alike). An object an edit lost
  /// keeps its component until 06 D8's cleanup, after the plan, and a
  /// re-parented one keeps it for good; either way an orphan must see its
  /// host gone (spec 08 D4), not a host whose transform has fallen back to
  /// the identity or that no longer regenerates.
  U? paramsOf<U extends Component>(Handle h) =>
      _survey.objects.containsKey(h) ? _target.components.get<U>(h) : null;

  /// The accumulated transform: group-local to world.
  Transform2 toWorld(Handle h) => _worldOf(_target, h);

  /// Ascending handles of the objects whose reach overlaps [h]'s, computed
  /// on the first call for [h] and memoised (spec 07 D10). Unmodifiable.
  List<Handle> neighbours(Handle h) => _survey.neighboursOf(h);

  /// Ascending handles of the live objects whose
  /// [ParametricType.references] name [h] (spec 08 D2): a wall lists its
  /// openings through it. Read from the survey this view was built over:
  /// the after-survey in an edit, a full survey in `drift()` and
  /// `diagnostics()`. Unmodifiable, and empty when [h] has none.
  List<Handle> referrers(Handle h) => _survey.referrers[h] ?? const [];
}

/// The parametric types an application knows, independent of any document
/// (Ruling 06-1): `DraftDocumentCodec.decode` needs the factories before
/// the document exists.
class ParametricCatalog {
  final List<_Registration<Component>> _types = [];

  void register<T extends Component>(
      String typeId, ComponentFactory<T> factory, ParametricType<T> type) {
    _types.add(_Registration<T>(typeId, factory, type));
  }

  /// Pass as `DraftDocumentCodec.decode(…, registerComponents: …)`.
  void registerComponents(ComponentRegistry registry) {
    for (final t in _types) {
      t.registerInto(registry);
    }
  }
}

/// Regenerates parametric objects inside the edit that changes them (spec
/// 06 D1, D2, D4). One per document; takes the dispatcher's expander slot.
class ParametricSystem {
  ParametricSystem(this.document, this.catalog) {
    catalog.registerComponents(document.components);
  }

  final DraftDocument document;
  final ParametricCatalog catalog;

  /// True while this system runs client code: an edit's regeneration, a
  /// dry run, a diagnostics pass. Nested-safe: each entry restores the
  /// value it found, so an inner pass ending (a client `diagnose` calling
  /// [diagnostics], a `generate` calling [drift]) never clears an outer
  /// pass's guard.
  bool _applying = false;

  List<_Registration<Component>> get _types => catalog._types;

  void install() {
    if (document.commands.expander != null) {
      throw StateError('the dispatcher already has an expander (spec 06 D2)');
    }
    document.commands.expander = _expand;
  }

  /// Releases the slot only if it is still this system's own tear-off.
  void dispose() {
    if (document.commands.expander == _expand) {
      document.commands.expander = null;
    }
  }

  /// Handles whose regeneration would change anything (spec D10). A dry
  /// run: reserves no handle, mutates nothing.
  ///
  /// Guarded the same way [apply] is (F5): a client `generate` must not
  /// mutate, and a dry run is exactly where a client could try to call
  /// `execute` and have it actually land, since nothing else here applies
  /// anything. Re-entry through the dispatcher throws instead.
  ///
  /// Throws what the plan throws (spec 07 D8): `ArgumentError` when a
  /// client generates a region that is not a closed, triangulable
  /// polyline, and `StateError` when an object's fill names a boundary that
  /// is missing or not a child of the same object (a malformed load). Like
  /// an edit, a dry run cannot plan around either.
  List<Handle> drift() {
    final was = _applying;
    _applying = true;
    try {
      final s = _survey(document, _types);
      final view = ParametricView._(document, s);
      return [
        for (final h in s.objects.keys)
          if (_plan(document, [h], s, view).isNotEmpty) h,
      ];
    } finally {
      _applying = was;
    }
  }

  /// One diagnostic per parametric component on a holder that is not a
  /// root-level group: it is not regenerated (spec D5). Then, for every live
  /// object in ascending handle order and every handle its `references`
  /// declared that is not a live object, in declared order and once each,
  /// `parametric.dangling` (severity error) for a `cascade` type or
  /// `parametric.orphan` (warning) for an `orphan` one, naming the object
  /// then the handle (spec 08 D5, D17): read from the survey's one
  /// `references` call per object. Then every live
  /// object's [ParametricType.diagnose], in ascending handle order whatever
  /// the types' registration order (spec 07 D12), over one full survey;
  /// neighbours are computed only for the objects a client asks about.
  ///
  /// Guarded like [drift], survey included: a client `reach` or `diagnose`
  /// that calls `execute` throws `StateError` out of this call, and nothing
  /// lands. Any other exception a client's `reach` or `diagnose` throws
  /// propagates too; there is no partial report.
  List<Diagnostic> diagnostics() {
    final misplaced = [
      for (final t in _types)
        for (final h in t.handles(document))
          if (!_isObject(document, _types, h))
            Diagnostic(
              severity: DiagnosticSeverity.warning,
              code: 'parametric.misplaced',
              message: '${t.typeId} on ${h.toHex()}, which is not a '
                  'root-level group, is not regenerated',
              handles: [h],
            ),
    ];
    final was = _applying;
    _applying = true;
    try {
      final s = _survey(document, _types);
      final view = ParametricView._(document, s);
      return [
        ...misplaced,
        for (final h in s.objects.keys) ..._unresolved(s, h),
        for (final h in s.objects.keys) ...s.objects[h]!.diagnose(view, h),
      ];
    } finally {
      _applying = was;
    }
  }

  /// [h]'s declared handles that are not live objects of [s], each once,
  /// in declared order (spec 08 D17).
  static List<Diagnostic> _unresolved(_Survey s, Handle h) {
    final declared = s.declared[h];
    if (declared == null) return const [];
    final cascade =
        s.objects[h]!.type.referencePolicy == ReferencePolicy.cascade;
    return [
      for (final x in {...declared})
        if (!s.objects.containsKey(x))
          Diagnostic(
            severity:
                cascade ? DiagnosticSeverity.error : DiagnosticSeverity.warning,
            code: cascade ? 'parametric.dangling' : 'parametric.orphan',
            message: '${h.toHex()} references ${x.toHex()}, which is not a '
                'live parametric object',
            handles: [h, x],
          ),
    ];
  }

  DraftCommand _expand(DraftCommand command) {
    if (_applying) {
      throw StateError('execute() inside a parametric regeneration '
          '(spec 06 D2): generate() must not mutate');
    }
    if (!_types.any((t) => t.handles(document).isNotEmpty) &&
        !_setsParametric(command)) {
      return command;
    }
    return ParametricEdit._(this, command);
  }

  bool _setsParametric(DraftCommand c) => c is CompoundCommand
      ? c.children.any(_setsParametric)
      : _types.any((t) => t.owns(c));

  Set<Capability> _editCapabilitiesOf(DraftCommand c) => c is CompoundCommand
      ? {for (final child in c.children) ..._editCapabilitiesOf(child)}
      : {
          for (final t in _types)
            if (t.owns(c)) t.type.editCapability,
        };
}

/// An edit and its regeneration, as one command (spec D4). Created only by
/// the expander, once per `execute`, and applied once (spec D9).
final class ParametricEdit extends DraftCommand {
  ParametricEdit._(this._system, this.inner);

  final ParametricSystem _system;
  final DraftCommand inner;
  bool _applied = false;
  bool _geometryChanged = false;

  @override
  String get label => inner.label;

  /// The triggering edit's authority plus each parametric type's
  /// `editCapability`; the regeneration adds none of its own (spec D7).
  @override
  Set<Capability> get capabilities =>
      {...inner.capabilities, ..._system._editCapabilitiesOf(inner)};

  /// Read by the dispatcher after [apply]: `geometry` whenever the plan
  /// changed geometry, so the index does not skip it (spec D9).
  @override
  Capability get capability =>
      _geometryChanged && inner.capability.index < Capability.geometry.index
          ? Capability.geometry
          : inner.capability;

  @override
  CommandResult apply(CommandTarget target) {
    if (_applied) {
      throw StateError('a ParametricEdit applies once (spec 06 D9)');
    }
    _applied = true;
    final was = _system._applying;
    _system._applying = true;
    try {
      return _run(this, target);
    } finally {
      _system._applying = was;
    }
  }
}

/// The concrete inverse of a [ParametricEdit]: undo and redo replay it and
/// never regenerate. Its own inverse is again a `ParametricReplay` with the
/// same [capabilities], so redo is authorised exactly as undo (spec D7).
final class ParametricReplay extends DraftCommand {
  ParametricReplay(this.replay, Set<Capability> capabilities)
      : capabilities = Set.unmodifiable(capabilities);

  final CompoundCommand replay;

  @override
  final Set<Capability> capabilities;

  @override
  Capability get capability => replay.capability;

  @override
  String get label => replay.label;

  @override
  CommandResult apply(CommandTarget target) {
    final r = replay.apply(target);
    return CommandResult(
      inverse: ParametricReplay(r.inverse as CompoundCommand, capabilities),
      touched: r.touched,
    );
  }
}

/// One registered type, with `T` captured so the untyped system can call it.
final class _Registration<T extends Component> {
  _Registration(this.typeId, this.factory, this.type);

  final String typeId;
  final ComponentFactory<T> factory;
  final ParametricType<T> type;

  /// Ruling 06-13: `register` replaces the store, wiping every component
  /// of `T`, so a type already registered is left alone.
  void registerInto(ComponentRegistry r) {
    if (!r.isRegistered<T>()) r.register<T>(typeId, factory);
  }

  bool has(CommandTarget t, Handle h) => t.components.get<T>(h) != null;
  Iterable<Handle> handles(CommandTarget t) => t.components.withComponent<T>();
  bool owns(DraftCommand c) => c is SetComponentCommand<T>;
  DraftCommand detach(Handle h) => SetComponentCommand<T>(h, null);
  Aabb2 reachOf(CommandTarget t, Handle h) =>
      type.reach(t.components.get<T>(h) as T, _worldOf(t, h));
  List<Generated> generate(ParametricView v, Handle h) => type.generate(v, h);
  List<Diagnostic> diagnose(ParametricView v, Handle h) => type.diagnose(v, h);

  /// [h]'s declared referents. Every call counts in [debugReferenceCalls]
  /// (Ruling 08-3): the survey is its only caller, once per object.
  Iterable<Handle> referencesOf(CommandTarget t, Handle h) {
    debugReferenceCalls++;
    return type.references(t.components.get<T>(h) as T);
  }
}
