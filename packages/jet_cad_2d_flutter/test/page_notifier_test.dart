import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/page_fixture.dart';

void main() {
  test('seeds from the document before any event', () {
    // M-04u.
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    expect(n.value, standardPage());
  });

  test('follows apply, undo and redo through the stream', () async {
    // M-04l (undo ignored).
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    final seen = <PageComponent?>[];
    n.addListener(() => seen.add(n.value));
    final edited = standardPage().copyWith(pageBreaks: true);

    doc.commands
        .execute(SetComponentCommand<PageComponent>(doc.rootHandle, edited));
    await Future<void>.delayed(Duration.zero);
    doc.commands.undo();
    await Future<void>.delayed(Duration.zero);
    doc.commands.redo();
    await Future<void>.delayed(Duration.zero);

    expect(seen, [edited, standardPage(), edited]);
  });

  test('an unrelated edit and an equal value do not notify', () async {
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    var notified = 0;
    n.addListener(() => notified++);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage())); // equal value
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: doc.handleSeed.next(),
        parent: doc.rootHandle,
        transform: Transform2.translation(5, 5),
        children: const [])));
    await Future<void>.delayed(Duration.zero);
    expect(notified, 0);
  });

  test('a load re-reads, and dispose stops listening', () async {
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage().copyWith(gridVisible: false)));
    await Future<void>.delayed(Duration.zero);
    doc.commands.notifyLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(n.value!.gridVisible, isFalse);
    n.dispose();
    expect(
        () => doc.commands.execute(
            SetComponentCommand<PageComponent>(doc.rootHandle, standardPage())),
        returnsNormally);
  });
}
