// Spec P5: the export and import registries' types. A host adds its own
// exporters and importers through PlanController(exporters:, importers:);
// the plan library builds in `plan.pdf` and `plan.png`.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import '../theme/plan_theme.dart' show kUnitColourOpacity;
import 'unit_colour_underlay.dart' show checkedUnitColourOpacity;

/// What makes an export's bytes. Its [id] names the format in the dialog's
/// answer and in `PlanController.export`: the built-ins are `plan.pdf` and
/// `plan.png`, a host's its own (`acme.dxf`).
abstract interface class PlanExporter {
  String get id;

  /// The file name's extension, without the dot.
  String get extension;

  /// The bytes' MIME type.
  String get mimeType;

  /// The bytes of [request]'s document. An error completes the export's
  /// `Future` with it.
  Future<Uint8List> export(PlanExportRequest request);
}

/// An exporter that plots the plan's page (the built-ins do): for a plan
/// without a page the controller answers null and never calls it, and its
/// request's page is never null (spec P2: "a plan with no page where the
/// choice needs one").
abstract interface class PlanPageExporter implements PlanExporter {}

/// What turns a file into a plan's text (spec P5, decision 4). A text
/// without a manifest gets an empty one before it is loaded, so an imported
/// drawing opens as plain geometry.
abstract interface class PlanImporter {
  String get id;

  /// The file extensions it reads, without the dot.
  List<String> get extensions;

  Future<String> import(Uint8List bytes);
}

/// The resolutions an image export offers.
enum PlanExportDpi {
  d96,
  d150,
  d300;

  /// Dots per inch.
  int get value => switch (this) {
        PlanExportDpi.d96 => 96,
        PlanExportDpi.d150 => 150,
        PlanExportDpi.d300 => 300,
      };
}

/// An export's settings: today's export choice without the format, which
/// the exporter's id now names (spec P2). A PDF ignores the resolution.
@immutable
final class PlanExportChoice {
  const PlanExportChoice({this.dpi = PlanExportDpi.d150});

  /// The first choice of a controller's life: 150 dpi.
  static const PlanExportChoice initial = PlanExportChoice();

  final PlanExportDpi dpi;

  PlanExportChoice copyWith({PlanExportDpi? dpi}) =>
      PlanExportChoice(dpi: dpi ?? this.dpi);

  @override
  bool operator ==(Object other) =>
      other is PlanExportChoice && other.dpi == dpi;

  @override
  int get hashCode => dpi.hashCode;

  @override
  String toString() => 'PlanExportChoice(${dpi.value} dpi)';
}

/// The export dialog's answer, the host's dialog's too: the exporter's id
/// and the choice. Remembered per controller as the next dialog's initial.
@immutable
final class PlanExportAnswer {
  const PlanExportAnswer({required this.exporter, required this.choice});

  /// The first answer of a controller's life: PDF, 150 dpi, as today's
  /// dialog's.
  static const PlanExportAnswer initial =
      PlanExportAnswer(exporter: 'plan.pdf', choice: PlanExportChoice.initial);

  final String exporter;
  final PlanExportChoice choice;

  PlanExportAnswer copyWith({String? exporter, PlanExportChoice? choice}) =>
      PlanExportAnswer(
          exporter: exporter ?? this.exporter, choice: choice ?? this.choice);

  @override
  bool operator ==(Object other) =>
      other is PlanExportAnswer &&
      other.exporter == exporter &&
      other.choice == choice;

  @override
  int get hashCode => Object.hash(exporter, choice);

  @override
  String toString() => 'PlanExportAnswer($exporter, ${choice.dpi.value} dpi)';
}

/// The plan's fonts, for an exporter that embeds text.
abstract interface class PlanExportFonts {
  /// The bundled Roboto's bytes: the face the screen lays text out in.
  Future<Uint8List> get bytes;
}

/// What an exporter is handed (spec P5).
final class PlanExportRequest {
  PlanExportRequest({
    required this.document,
    required this.page,
    required this.choice,
    required Set<Handle> omitted,
    required this.fonts,
    double unitColourOpacity = kUnitColourOpacity,
  })  : omitted = Set.unmodifiable(omitted),
        unitColourOpacity = checkedUnitColourOpacity(unitColourOpacity);

  /// A copy of the plan made when the export started, so edits made while
  /// the export runs cannot race with it. Disposed once the bytes are back:
  /// keep nothing of it.
  final DraftDocument document;

  /// The plan's page, or null for a plan without one (never null for a
  /// [PlanPageExporter]).
  final PageComponent? page;

  final PlanExportChoice choice;

  /// The objects of types with `exported: false`: their leaves are not
  /// drawn.
  final Set<Handle> omitted;

  final PlanExportFonts fonts;

  /// The alpha the units' colours are filled at under the drawing (2b spec
  /// S4): the exporting editor's theme, or the host's argument, or 0.35. An
  /// [ArgumentError] for one that is not finite or outside [0, 1].
  final double unitColourOpacity;
}

/// An export's bytes, its file name and its MIME type.
@immutable
final class PlanExport {
  const PlanExport(
      {required this.bytes, required this.name, required this.mimeType});

  final Uint8List bytes;

  /// `<name>.<extension>`.
  final String name;

  final String mimeType;
}
