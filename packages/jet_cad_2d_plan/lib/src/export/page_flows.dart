// Spec P2 (the export rules) and P5 (the registries): the controller's
// export, print and import, one export or print at a time. Ported from
// jet_cad_floor_plan/lib/src/host/page_flows.dart (exportOnce, printOnce,
// :73-120) and floor_plan_controller.dart (_pageFlow, :1376-1388).
import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show registerKitComponents;

import '../file/plan_file.dart' show ensureManifest;
import '../units/unit_components.dart' show registerUnitComponents;
import 'builtin_exporters.dart';
import 'export_font.dart';
import 'page_printer.dart';
import 'registries.dart';

bool _never() => false;

/// The export, print and import flows of one controller: the registries,
/// the one-flow guard its views share, the remembered dialog answer and
/// the font.
final class PlanPageFlows {
  /// [exporters] and [importers] are the host's; [unexported] the ids of
  /// the types with `exported: false`; [document], [catalog], [settle] and
  /// [load] read and act on the controller at each call.
  PlanPageFlows({
    required List<PlanExporter> exporters,
    required List<PlanImporter> importers,
    required Set<String> unexported,
    required DraftDocument Function() document,
    required ParametricCatalog Function() catalog,
    required void Function() settle,
    required void Function(String json) load,
    PlanExportFonts? fonts,
  })  : exporters = List.unmodifiable(<PlanExporter>[
          const PlanPdfExporter(),
          const PlanPngExporter(),
          ...exporters,
        ]),
        importers = List.unmodifiable(importers),
        fonts = fonts ?? ExportFontCache(),
        _unexported = Set.unmodifiable(unexported),
        _document = document,
        _catalog = catalog,
        _settle = settle,
        _load = load {
    checkRegistry(exporters: exporters, importers: importers);
  }

  /// Throws an [ArgumentError] naming `exporters` (or `importers`) when two
  /// of them, the built-ins included, share an id. The controller's factory
  /// calls it before it builds anything.
  static void checkRegistry(
      {required List<PlanExporter> exporters,
      required List<PlanImporter> importers}) {
    _unique([
      PlanPdfExporter.exporterId,
      PlanPngExporter.exporterId,
      for (final e in exporters) e.id,
    ], 'exporters');
    _unique([for (final i in importers) i.id], 'importers');
  }

  static void _unique(List<String> ids, String name) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        throw ArgumentError.value(ids, name, 'lists the id "$id" twice');
      }
    }
  }

  /// `plan.pdf`, `plan.png`, then the host's, in its order.
  final List<PlanExporter> exporters;
  final List<PlanImporter> importers;
  final PlanExportFonts fonts;
  final Set<String> _unexported;
  final DraftDocument Function() _document;
  final ParametricCatalog Function() _catalog;
  final void Function() _settle;
  final void Function(String json) _load;

  final ValueNotifier<bool> _ready = ValueNotifier(true);
  bool _disposed = false;

  /// False while an export or a print runs, for this controller and every
  /// view of it.
  ValueListenable<bool> get ready => _ready;

  /// The export dialog's last answer: the next dialog's initial.
  PlanExportAnswer dialogAnswer = PlanExportAnswer.initial;

  bool get isDisposed => _disposed;

  /// Takes the guard: false when a flow runs or the flows are disposed.
  bool acquire() {
    if (_disposed || !_ready.value) return false;
    _ready.value = false;
    return true;
  }

  /// Gives the guard back, unless the flows are disposed.
  void release() {
    if (!_disposed) _ready.value = true;
  }

  PlanExporter exporterOf(String id) {
    for (final e in exporters) {
      if (e.id == id) return e;
    }
    throw ArgumentError.value(id, 'exporterId', 'names no exporter');
  }

  PlanImporter importerOf(String id) {
    for (final i in importers) {
      if (i.id == id) return i;
    }
    throw ArgumentError.value(id, 'importerId', 'names no importer');
  }

  /// The live objects of [document] whose type has `exported: false`.
  Set<Handle> omittedOf(DraftDocument document) {
    if (_unexported.isEmpty) return const {};
    final catalog = _catalog();
    return {
      for (final node in document.tree.nodes)
        if (node is GroupNode)
          if (catalog.typeIdOf(document, node.handle) case final id?
              when _unexported.contains(id))
            node.handle,
    };
  }

  /// A copy of [live]: its codec JSON decoded with a measurer of its own
  /// and the controller's registrations. A component the plan keeps raw
  /// (E4) stays raw in the copy, as `decodePlan` reads it.
  ({DraftDocument document, FlutterTextMeasurer measurer}) _copyOf(
      DraftDocument live) {
    final measurer = FlutterTextMeasurer();
    final catalog = _catalog();
    final DraftDocument copy;
    try {
      copy = DraftDocumentCodec.decodeString(
          DraftDocumentCodec.encodeToString(live),
          measurer: measurer, registerComponents: (r) {
        PageComponent.register(r);
        registerKitComponents(r);
        registerUnitComponents(r);
        catalog.registerComponents(r);
      }, diagnostics: <Diagnostic>[], keepUnreadableComponents: true);
    } catch (_) {
      measurer.clear();
      rethrow;
    }
    return (document: copy, measurer: measurer);
  }

  /// [flow] under the guard, after the settle; [busy] when another flow
  /// runs or the flows are disposed, before or after it.
  Future<T> guarded<T>(T busy, Future<T> Function() flow) async {
    if (!acquire()) return busy;
    try {
      _settle();
      final result = await flow();
      return _disposed ? busy : result;
    } finally {
      release();
    }
  }

  /// Export's one body (page_flows.dart:73-97): [document] (the
  /// controller's plan when null) by [exporterId] as [choice] says, named
  /// `<name>.<extension>`. Null when the plan shown is no longer
  /// [document], before or after the bytes; when the exporter plots the
  /// page and the plan has none; or when [cancelled] says so after the
  /// bytes. The exporter gets a copy, disposed when its bytes are back.
  Future<PlanExport?> exportOnce(
      String exporterId, PlanExportChoice choice, String name,
      {DraftDocument? document, bool Function() cancelled = _never}) async {
    final exporter = exporterOf(exporterId);
    final live = document ?? _document();
    if (!identical(live, _document())) return null;
    if (exportPageOf(live) == null && exporter is PlanPageExporter) {
      return null;
    }
    final copy = _copyOf(live);
    final Uint8List bytes;
    try {
      bytes = await exporter.export(PlanExportRequest(
          document: copy.document,
          page: exportPageOf(copy.document),
          choice: choice,
          omitted: omittedOf(copy.document),
          fonts: fonts));
    } finally {
      _disposeCopy(copy);
    }
    if (cancelled() || !identical(live, _document())) return null;
    return PlanExport(
        bytes: bytes,
        name: '$name.${exporter.extension}',
        mimeType: exporter.mimeType);
  }

  /// Print's one body (page_flows.dart:99-120): the plan's page as
  /// `plan.pdf`'s bytes to [printer], named [name]. False when it has no
  /// page, when the plan shown changed while the bytes were made, or when
  /// [cancelled] says so after them; true once the printer is done.
  Future<bool> printOnce(PagePrinter printer, String name,
      {PlanExportChoice choice = PlanExportChoice.initial,
      bool Function() cancelled = _never}) async {
    final live = _document();
    final page = exportPageOf(live);
    if (page == null) return false;
    final copy = _copyOf(live);
    final Uint8List bytes;
    try {
      bytes = await const PlanPdfExporter().export(PlanExportRequest(
          document: copy.document,
          page: exportPageOf(copy.document),
          choice: choice,
          omitted: omittedOf(copy.document),
          fonts: fonts));
    } finally {
      _disposeCopy(copy);
    }
    if (cancelled() || !identical(live, _document())) return false;
    await printer.print(bytes, name, printPageFormat(page));
    return true;
  }

  static void _disposeCopy(
      ({DraftDocument document, FlutterTextMeasurer measurer}) copy) {
    unawaited(copy.document.dispose());
    copy.measurer.clear();
  }

  /// `PlanController.export`: an unknown id throws at once.
  Future<PlanExport?> export(String exporterId, PlanExportChoice choice,
      {required String name}) {
    exporterOf(exporterId);
    return guarded<PlanExport?>(null,
        () => exportOnce(exporterId, choice, name, cancelled: () => _disposed));
  }

  /// `PlanController.print`.
  Future<bool> print(PlanExportChoice choice,
          {required PagePrinter printer, required String name}) =>
      guarded<bool>(
          false,
          () => printOnce(printer, name,
              choice: choice, cancelled: () => _disposed));

  /// `PlanController.import`: an unknown id throws at once; the importer's
  /// text, with an empty manifest added when it has none, is loaded.
  Future<void> import(String importerId, Uint8List bytes) {
    final importer = importerOf(importerId);
    return _import(importer, bytes);
  }

  Future<void> _import(PlanImporter importer, Uint8List bytes) async {
    final text = await importer.import(bytes);
    if (_disposed) return;
    _load(ensureManifest(text));
  }

  void dispose() {
    _disposed = true;
    _ready.dispose();
  }
}
