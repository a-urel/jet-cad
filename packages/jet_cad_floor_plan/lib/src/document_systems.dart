// The expander systems of one document (spec 06 D2, 14a T12), shared by
// every shell over it: the design's `PlannerShell` and the selection mode's
// `ServiceView`. A host that replaces its `FloorPlanView` with another of
// the same controller (a new key, a new parent) mounts the new shell before
// Flutter disposes the old one, so for that frame two shells hold the same
// document; each installing its own systems would trip the dispatcher's
// one expander slot (Slice 4's results, "a second view on one controller").
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'parametric/catalog.dart' show installParametric;
import 'tables/table_label_system.dart';

/// One document's parametric and table systems, installed by the first
/// [acquire] and released by the last holder's release.
///
/// Two holders still alive at the end of the frame the second came in are
/// two views of one controller side by side, which the host guide rules out
/// ("one `FloorPlanView` at a time"): a [StateError] is thrown from that
/// frame's post-frame callback. A replacement ends the frame with one.
final class DocumentSystems {
  DocumentSystems._(DraftDocument document)
      : _parametric = installParametric(document),
        _tableLabels = TableLabelSystem(document) {
    // Last in, first out (spec 14a T12): the table system stacks on the
    // parametric system's expander.
    _tableLabels.install();
  }

  static final Expando<DocumentSystems> _of = Expando<DocumentSystems>();

  final ParametricSystem _parametric;
  final TableLabelSystem _tableLabels;
  int _holders = 0;

  /// The number of holders of [document]'s systems; 0 when none are
  /// installed.
  static int holdersOf(DraftDocument document) => _of[document]?._holders ?? 0;

  /// Installs [document]'s systems unless a holder already did, and returns
  /// this holder's release, to be called once: the last one releases the
  /// slot (the table system first, then the parametric system).
  static VoidCallback acquire(DraftDocument document) {
    final systems = _of[document] ??= DocumentSystems._(document);
    systems._holders++;
    if (systems._holders == 2) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (systems._holders > 1) {
          throw StateError('a FloorPlanController is shown in one '
              'FloorPlanView at a time: a second view of it is mounted '
              'beside the first');
        }
      });
    }
    return () {
      if (--systems._holders > 0) return;
      systems._tableLabels.dispose();
      systems._parametric.dispose();
      _of[document] = null;
      assert(document.commands.expander == null,
          'the expander slot was not released: dispose order');
    };
  }
}
