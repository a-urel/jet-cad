// PlanServices (spec 2a P1): a live view, one per kit per controller, of
// the current document, its index, the camera, the effective object snap,
// the attachment registry, the kit's words at the controller's locale, the
// kit's own tools' settings and the per-document shared cache.
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'session.dart';
import 'tool_settings_store.dart';

/// What the services read of their controller.
abstract interface class ServicesHost {
  DocumentSession get session;
  CameraController get camera;
  SnapSettings get snap;
  ToolSettingsStore get toolSettings;
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
