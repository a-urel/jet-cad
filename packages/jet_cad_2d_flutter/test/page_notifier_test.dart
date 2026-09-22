import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/page_fixture.dart';

/// A command that names nothing it touched.
///
/// `DocChange.touched` is documented as empty when the *whole document*
/// changed (`doc_change.dart:11-12`), and the index and the tile cache both
/// read it that way. Nothing shipped in the engine emits an empty set today,
/// and the notifier listens to the stream, which only the dispatcher feeds —
/// so the only way to put one on the stream is a command whose `apply`
/// returns one.
class WholeDocumentCommand extends DraftCommand {
  @override
  Capability get capability => Capability.structure;

  @override
  String get label => 'whole document';

  @override
  CommandResult apply(CommandTarget target) {
    target.invalidateDerived();
    return CommandResult(inverse: WholeDocumentCommand(), touched: const {});
  }
}

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

  test('an empty touched set means the whole document changed', () async {
    // A7. The index (`spatial_index.dart`, `_reconcile`'s empty branch) and
    // the tile cache (`tile_cache.dart`, `applyChange`) both read an empty
    // set as "everything changed"; the notifier must not be the one consumer
    // that reads it as "nothing I care about".
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    expect(n.value!.pageBreaks, isFalse);

    // Out of band, so only the empty-set event can make the notifier see it.
    doc.components.attach<PageComponent>(
        doc.rootHandle, standardPage().copyWith(pageBreaks: true));
    expect(n.value!.pageBreaks, isFalse);

    doc.commands.execute(WholeDocumentCommand());
    await Future<void>.delayed(Duration.zero);

    expect(n.value!.pageBreaks, isTrue);
  });

  test('a load re-reads, and dispose stops listening', () async {
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage().copyWith(gridVisible: false)));
    await Future<void>.delayed(Duration.zero);
    expect(n.value!.gridVisible, isFalse);

    // Out of band: the registry is written directly, so no command runs and
    // no `DocChange` is emitted — exactly what a decode does before
    // `notifyLoaded`. The notifier cannot have seen it yet.
    doc.components.attach<PageComponent>(
        doc.rootHandle, standardPage().copyWith(pageBreaks: true));
    expect(n.value!.pageBreaks, isFalse,
        reason: 'nothing on the stream, so nothing re-read');
    expect(n.value!.gridVisible, isFalse);

    doc.commands.notifyLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(n.value!.pageBreaks, isTrue,
        reason: 'the load arm re-reads the registry rather than trusting the '
            'value it already holds');
    expect(n.value!.gridVisible, isTrue,
        reason: 'the re-read is of the whole component, not one field');

    // The observable for dispose is the notifier's own field: the
    // subscription is cancelled, so `_onChange` never runs and `value` is
    // never written. (A notifier that kept listening would write a disposed
    // `ValueNotifier`, which throws out of the stream callback.)
    final atDispose = n.value;
    n.dispose();
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage().copyWith(scaleDenominator: 20)));
    await Future<void>.delayed(Duration.zero);
    expect(n.value, atDispose, reason: 'a disposed notifier follows nothing');
    expect(
        doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator, 20,
        reason: 'fixture guard: the edit really landed, so an unchanged '
            'notifier means it stopped listening rather than that nothing '
            'happened');
  });
}
