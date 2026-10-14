// A host's exporter and importer for tests: each records what it was
// handed, can fail once, and (the exporter) can hold its bytes until the
// test lets them go.
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';

class RecordingExporter implements PlanExporter {
  RecordingExporter(this.id, this.extension, this.mimeType);

  @override
  final String id;
  @override
  final String extension;
  @override
  final String mimeType;

  final List<PlanExportRequest> requests = [];

  /// Each request's document as the codec writes it, read on arrival (the
  /// copy is disposed once the bytes are back).
  final List<String> seen = [];

  /// Thrown by the next call, then cleared.
  Object? failNext;

  /// While true, each call waits on a completer added to [held].
  bool hold = false;
  final List<Completer<void>> held = [];

  @override
  Future<Uint8List> export(PlanExportRequest request) async {
    requests.add(request);
    seen.add(DraftDocumentCodec.encodeToString(request.document));
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    if (hold) {
      final open = Completer<void>();
      held.add(open);
      await open.future;
    }
    return Uint8List.fromList(utf8.encode('$id ${request.omitted.length}'));
  }
}

/// A host exporter that plots the page.
class RecordingPageExporter extends RecordingExporter
    implements PlanPageExporter {
  RecordingPageExporter(super.id, super.extension, super.mimeType);
}

class TextImporter implements PlanImporter {
  TextImporter(this.id, {this.text = ''});

  @override
  final String id;

  @override
  List<String> get extensions => const ['json'];

  /// What the next import answers.
  String text;

  /// Thrown by the next call, then cleared.
  Object? failNext;

  final List<Uint8List> asked = [];

  @override
  Future<String> import(Uint8List bytes) async {
    asked.add(bytes);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    return text;
  }
}
