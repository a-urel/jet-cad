// PlanServices (spec 2a P1): a live view, one per kit per controller, of
// the current document, its index, the camera, the effective object snap,
// the attachment registry, the kit's words at the controller's locale, the
// kit's own tools' settings and the per-document shared cache.
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../symbols/plan_symbol.dart';
import '../symbols/symbol_placer.dart' show definitionForEntry;
import 'session.dart';
import 'tool_settings_store.dart';

/// What the services read of their controller.
abstract interface class ServicesHost {
  DocumentSession get session;
  CameraController get camera;
  SnapSettings get snap;

  /// The controller's catalog: every loaded kit's types (spec 3a C1.5).
  ParametricCatalog get catalog;

  ToolSettingsStore get toolSettings;

  /// The loaded symbol `key@version`, or null.
  PlanSymbol? symbolById(String id);

  /// The controller's symbol libraries' state.
  ValueListenable<SymbolsState> get symbolsState;

  /// The refs whose `add` has not executed yet, by key: one map per
  /// controller, shared by every kit's services (spec 2b S2).
  Map<String, SymbolDefinitionRef> get pendingDefinitions;
}

final class KitServices implements PlanServices {
  KitServices(this.kit, this._host, this.words);

  final PlanKit kit;
  final ServicesHost _host;

  @override
  final KitWords words;

  @override
  DraftDocument get document => _host.session.document;

  @override
  SpatialIndex get index => _host.session.index;

  @override
  CameraController get camera => _host.camera;

  @override
  bool get objectSnap => _host.snap.objectSnap;

  @override
  AttachmentRegistry get attachments => _host.session.attachments;

  /// The kit's own tool [toolId]'s settings: another kit's tool, a tool
  /// without settings and settings that are not an [S] are each an
  /// [ArgumentError].
  @override
  S settingsOf<S extends Object>(String toolId) {
    if (kitOfKey(toolId) != kit.id) {
      throw ArgumentError.value(
          toolId, 'toolId', 'is not a tool of the kit "${kit.id}"');
    }
    final value = _host.toolSettings.valueOf(toolId);
    if (value is! S) {
      throw ArgumentError.value(
          toolId, 'toolId', 'has settings of ${value.runtimeType}, not $S');
    }
    return value;
  }

  @override
  T shared<T extends Object>(T Function(PlanServices) create) =>
      _host.session.shared.get<T>(kit.id, this, create);

  /// Spec 2b S2. A pending ref is handed out again until the document holds
  /// its definition (its `add` executed, by whatever path), the controller
  /// executes a command, or the document is replaced; a ref whose
  /// definition the document holds is made afresh, with no `add`.
  @override
  SymbolDefinitionRef? symbolDefinition(String key) {
    final pending = _host.pendingDefinitions;
    final document = this.document;
    final kept = pending[key];
    if (kept != null) {
      if (document.tree.definition(kept.handle) == null) return kept;
      pending.remove(key);
    }
    final entry = _host.symbolById(key)?.entry;
    if (entry == null) return null;
    final made = definitionForEntry(document, entry);
    final ref = SymbolDefinitionRef(
      handle: made.definition,
      add: made.commands.isEmpty
          ? null
          : CompoundCommand(made.commands, label: 'Add ${entry.symbol.name}'),
      basePoint: entry.definition.basePoint.clone(),
      top: servedTopOfEntry(entry),
    );
    if (ref.add != null) pending[key] = ref;
    return ref;
  }

  @override
  ValueListenable<SymbolsState> get symbolsState => _host.symbolsState;

  /// Spec 3a C1.5: null for E2's frozen objects (the set the system's
  /// `isFrozen` reads), else the catalog's type id over the current
  /// document, which is null for a missing kit's object (kept raw) and for
  /// anything that is no object.
  @override
  String? liveTypeIdOf(Handle handle) {
    final session = _host.session;
    if (session.frozen.contains(handle)) return null;
    return _host.catalog.typeIdOf(session.document, handle);
  }
}

/// The attachment registry until Task 14: no kind, no attachment.
final class NoAttachments implements AttachmentRegistry {
  const NoAttachments();

  @override
  Attachment? attach(List<String> kinds, AttachmentQuery query) => null;

  @override
  Set<String> get kinds => const {};
}

/// Object snap as the tools, the drags and the kits read it: the user's F3
/// while the canvas allows snapping. Ported from planner_shell.dart:
/// 1759-1776 (`_CapabilitySnap`).
final class EffectiveSnap extends SnapSettings {
  EffectiveSnap(this._user, this._allowed);

  final SnapSettings _user;
  final bool Function() _allowed;

  @override
  bool get objectSnap => _allowed() && _user.objectSnap;

  @override
  void toggleObjectSnap() => _user.toggleObjectSnap();

  @override
  void addListener(VoidCallback listener) => _user.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _user.removeListener(listener);
}
