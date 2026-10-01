import 'dart:typed_data';

import 'package:floor_planner/document_files.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_document_files.dart';

void main() {
  group('FileKind (spec 13 D8)', () {
    test(
        'FK1 fileNameFor appends the kind\'s own extension, and only when '
        'the name does not already end in it (M-13ac)', () {
      expect(fileNameFor('plan', FileKind.pdf), 'plan.pdf');
      expect(fileNameFor('plan', FileKind.png), 'plan.png');
      expect(fileNameFor('plan', FileKind.jetplan), 'plan.jetplan');

      // A name already carrying the kind's extension is kept as it is.
      expect(fileNameFor('plan.png', FileKind.png), 'plan.png');
      expect(fileNameFor('plan.pdf', FileKind.pdf), 'plan.pdf');
      expect(fileNameFor(' plan.pdf ', FileKind.pdf), 'plan.pdf');
      expect(fileNameFor('plan.jetplan', FileKind.jetplan), 'plan.jetplan');

      // Another kind's extension is not this kind's: the suffix follows it.
      expect(fileNameFor('plan.png', FileKind.pdf), 'plan.png.pdf');
      expect(fileNameFor('plan.pdf', FileKind.png), 'plan.pdf.png');
      expect(fileNameFor('plan.jetplan', FileKind.pdf), 'plan.jetplan.pdf');
      expect(fileNameFor('plan.pdf', FileKind.jetplan), 'plan.pdf.jetplan');

      // Case-sensitive, as jetplanFileName always was (DF1).
      expect(fileNameFor('plan.PDF', FileKind.pdf), 'plan.PDF.pdf');
      expect(fileNameFor('plan.Png', FileKind.png), 'plan.Png.png');
      expect(jetplanFileName('plan.JETPLAN'), 'plan.JETPLAN.jetplan');

      // Ending in the extension's letters is not ending in `.pdf`.
      expect(fileNameFor('mypdf', FileKind.pdf), 'mypdf.pdf');
    });

    test('FK2 a blank or null typed name is a cancel for every kind', () {
      for (final kind in FileKind.values) {
        expect(fileNameFor(null, kind), isNull, reason: kind.name);
        expect(fileNameFor('', kind), isNull, reason: kind.name);
        expect(fileNameFor(' \t ', kind), isNull, reason: kind.name);
      }
    });

    test('FK3 jetplanFileName is fileNameFor\'s jetplan case', () {
      for (final typed in <String?>[
        null,
        '',
        'Kitchen',
        ' Kitchen 2 ',
        'Kitchen.jetplan',
        'plan.pdf',
      ]) {
        expect(jetplanFileName(typed), fileNameFor(typed, FileKind.jetplan),
            reason: '$typed');
      }
    });

    test('FK4 each kind\'s extension, type group and MIME type', () {
      expect(FileKind.values,
          <FileKind>[FileKind.jetplan, FileKind.pdf, FileKind.png]);

      expect(FileKind.jetplan.extension, 'jetplan');
      expect(FileKind.pdf.extension, 'pdf');
      expect(FileKind.png.extension, 'png');

      // The web write used application/json for a document before kinds
      // existed; the jetplan kind keeps it.
      expect(FileKind.jetplan.mimeType, 'application/json');
      expect(FileKind.pdf.mimeType, 'application/pdf');
      expect(FileKind.png.mimeType, 'image/png');

      // The jetplan kind's group is the one the open panel offers.
      expect(FileKind.jetplan.typeGroup.label, kJetplanTypeGroup.label);
      expect(
          FileKind.jetplan.typeGroup.extensions, kJetplanTypeGroup.extensions);
      expect(FileKind.pdf.typeGroup.label, 'PDF document');
      expect(FileKind.pdf.typeGroup.extensions, <String>['pdf']);
      expect(FileKind.png.typeGroup.label, 'PNG image');
      expect(FileKind.png.typeGroup.extensions, <String>['png']);
      for (final kind in FileKind.values) {
        expect(kind.typeGroup.allowsAny, isFalse, reason: kind.name);
      }
    });

    test(
        'FK5 the native save panel offers the kind\'s type group alone '
        '(the io rule)', () {
      for (final kind in FileKind.values) {
        final groups = saveTypeGroupsFor(kind);
        expect(groups, hasLength(1), reason: kind.name);
        expect(groups.single.label, kind.typeGroup.label, reason: kind.name);
        expect(groups.single.extensions, <String>[kind.extension],
            reason: kind.name);
      }
    });
  });

  group('FakeDocumentFiles records the kind (spec 13 D8)', () {
    test(
        'FK6 saveLocation and write record the kind of each call; a call '
        'without one is a jetplan', () async {
      final files = FakeDocumentFiles();
      files
        ..scriptSaveLocation(name: 'a.pdf', location: '/p/a.pdf')
        ..scriptSaveLocation(name: 'b.jetplan', location: '/p/b.jetplan')
        ..scriptSaveCancel();

      await files.saveLocation('A.pdf', kind: FileKind.pdf);
      await files.saveLocation('B.jetplan');
      expect(await files.saveLocation('C.png', kind: FileKind.png), isNull);
      expect(files.saveLocationCalls, <String>['A.pdf', 'B.jetplan', 'C.png']);
      expect(files.saveLocationKinds,
          <FileKind>[FileKind.pdf, FileKind.jetplan, FileKind.png]);

      await files.write('/p/a.png', 'a.png', Uint8List.fromList(<int>[1]),
          kind: FileKind.png);
      await files.write('/p/b.jetplan', 'b.jetplan', Uint8List(0));
      await files.write('/p/c.pdf', 'c.pdf', Uint8List.fromList(<int>[2]),
          kind: FileKind.pdf);
      expect(files.writes.map((w) => w.kind),
          <FileKind>[FileKind.png, FileKind.jetplan, FileKind.pdf]);
      expect(files.writes.map((w) => w.name),
          <String>['a.png', 'b.jetplan', 'c.pdf']);
    });
  });
}
