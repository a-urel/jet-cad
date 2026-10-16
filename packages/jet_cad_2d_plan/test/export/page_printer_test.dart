// Spec 13 D9, F-16 (3b Task 7, the old floor planner's PR8): the production
// printer hands the platform's print dialog the document's name and the
// page's size, lays the bytes out once, and answers when the dialog is done.
// Run at the `printing` package's platform channel, as the package's own
// protocol has it (printing 5.15.1, method_channel.dart): Dart asks
// `printPdf`, the platform calls back `onLayout` for the bytes and
// `onCompleted` when the dialog closes.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

void main() {
  testWidgets(
      'PP-1 PrintingPagePrinter asks the dialog for the name, the page in pt '
      'and no dynamic layout, and lays out the given bytes whatever paper '
      'the dialog asks for (F-16)', (tester) async {
    const channel = MethodChannel('net.nfet.printing');
    final messenger = tester.binding.defaultBinaryMessenger;
    Map<Object?, Object?>? asked;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'printPdf') {
        asked = call.arguments as Map<Object?, Object?>;
        return 1;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Future<Object?> fromPlatform(String method, Map<String, Object?> args) {
      final reply = Completer<Object?>();
      messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, args)),
          (data) => reply.complete(
              data == null ? null : channel.codec.decodeEnvelope(data)));
      return reply.future;
    }

    // A page that is neither the library's default (A4 portrait, 595.28 x
    // 841.89) nor square, with a name that is not the default either.
    final pdf = Uint8List.fromList(List.generate(64, (i) => (i * 37) % 251));
    const format = PdfPageFormat(1190.5, 841.75);
    var done = false;
    final printing = const PrintingPagePrinter()
        .print(pdf, 'flat', format)
        .then((_) => done = true);
    await tester.pump();
    expect(asked, isNotNull, reason: 'the dialog was asked for');
    expect(asked!['name'], 'flat');
    expect(asked!['width'], 1190.5);
    expect(asked!['height'], 841.75);
    expect(asked!['dynamic'], isFalse);
    final job = asked!['job'];
    // The dialog asks for another paper (A4 portrait): the same bytes.
    final laid = await fromPlatform('onLayout', {
      'job': job,
      'width': 595.0,
      'height': 842.0,
      'marginLeft': 0.0,
      'marginTop': 0.0,
      'marginRight': 0.0,
      'marginBottom': 0.0,
    });
    expect(laid, pdf);
    expect(done, isFalse, reason: 'it waits for the dialog');
    await fromPlatform('onCompleted', {'job': job, 'completed': true});
    await printing;
    expect(done, isTrue);
  });
}
