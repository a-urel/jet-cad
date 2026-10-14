// Export and import registries (spec 2a P5, A17.4): a host's exporters
// render a copy of the plan into bytes; its importers turn bytes into a
// plan's text. The controller stores them (Task 8); Task 19 runs them.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

abstract interface class PlanExporter {
  /// `plan.pdf`, `plan.png`; a host's: `acme.dxf`.
  String get id;
  String get extension;

  /// What a host's save hands on with the bytes.
  String get mimeType;

  Future<Uint8List> export(PlanExportRequest request);
}

abstract interface class PlanImporter {
  String get id;
  List<String> get extensions;

  /// A plan's text (spec decision 4); one without a manifest gets an empty
  /// one before it is loaded.
  Future<String> import(Uint8List bytes);
}

/// What an exporter renders (spec P5). Task 19 adds the choice and the
/// fonts.
@immutable
final class PlanExportRequest {
  const PlanExportRequest(
      {required this.document, required this.page, required this.omitted});

  /// A copy decoded from the plan's text when the export starts.
  final DraftDocument document;

  /// Null for a "drawing" export.
  final PageComponent? page;

  /// Objects of types with `exported: false`.
  final Set<Handle> omitted;
}
