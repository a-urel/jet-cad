import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// The document's page as a listenable (spec D10): seeded in the
/// constructor, re-read on any change that touches the root, on a load and
/// on a purge. `ValueNotifier` skips the notification when the value is
/// `==`, so an unrelated root edit costs its listeners nothing.
class PageNotifier extends ValueNotifier<PageComponent?> {
  PageNotifier(this.document)
      : super(document.components.get<PageComponent>(document.rootHandle)) {
    _subscription = document.changes.listen(_onChange);
  }

  final DraftDocument document;
  late final StreamSubscription<DocChange> _subscription;

  void _onChange(DocChange change) {
    final root = document.rootHandle;
    final refresh = switch (change) {
      // An empty set means the whole document changed
      // (`doc_change.dart:11-12`), which is how `SpatialIndex` and
      // `TileCache` read it too; the page is part of "everything".
      CommandApplied(:final touched) ||
      CommandUndone(:final touched) ||
      CommandRedone(:final touched) =>
        touched.isEmpty || touched.contains(root),
      DocumentLoaded() || DocumentPurged() => true,
    };
    if (refresh) value = document.components.get<PageComponent>(root);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
