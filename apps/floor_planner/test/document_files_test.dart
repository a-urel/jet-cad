import 'dart:typed_data';

import 'package:floor_planner/document_files.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_document_files.dart';

void main() {
  group('the shared part of DocumentFiles (spec 12a D9)', () {
    test(
        'DF1 a typed save name: blank is a cancel, white space is trimmed, '
        'and .jetplan is appended only when the name does not end in it', () {
      expect(jetplanFileName(null), isNull);
      expect(jetplanFileName(''), isNull);
      expect(jetplanFileName(' \t '), isNull);

      expect(jetplanFileName('Kitchen'), 'Kitchen.jetplan');
      expect(jetplanFileName('  Kitchen 2 '), 'Kitchen 2.jetplan');
      expect(jetplanFileName('Kitchen.jetplan'), 'Kitchen.jetplan');
      expect(jetplanFileName(' Kitchen.jetplan '), 'Kitchen.jetplan');
      // Another extension is kept and the suffix added after it.
      expect(jetplanFileName('plan.v2'), 'plan.v2.jetplan');
      // Ending in the extension's letters is not ending in `.jetplan`.
      expect(jetplanFileName('myjetplan'), 'myjetplan.jetplan');
      expect(jetplanFileName('jetplan'), 'jetplan.jetplan');
    });

    test('DF2 the panels offer one type: .jetplan files, nothing else', () {
      expect(kJetplanExtension, 'jetplan');
      // `XTypeGroup` strips a leading dot itself, so the list reads the same
      // written with or without one.
      expect(kJetplanTypeGroup.extensions, <String>['jetplan']);
      expect(kJetplanTypeGroup.allowsAny, isFalse);
      expect(kJetplanTypeGroup.label, 'Jet plan');
    });
  });

  group('FakeDocumentFiles (plan 12a P-5)', () {
    test(
        'DF3 open answers in the order scripted: a file, a cancel, a throw; '
        'unscripted throws and is counted', () async {
      final files = FakeDocumentFiles();
      final source = <int>[0x7b, 0x7d, 0x0a];
      files
        ..scriptOpen(name: 'a.jetplan', bytes: source, location: '/p/a.jetplan')
        ..scriptOpenCancel()
        ..scriptOpenThrow(const FormatException('bad'))
        ..scriptOpen(name: 'b.jetplan', bytes: <int>[0x31]);
      // The script holds its own copy of the bytes.
      source[0] = 0;

      final first = await files.open();
      expect(first!.name, 'a.jetplan');
      expect(first.bytes, <int>[0x7b, 0x7d, 0x0a]);
      expect(first.location, '/p/a.jetplan');
      expect(await files.open(), isNull);
      await expectLater(files.open(), throwsA(isA<FormatException>()));
      final fourth = await files.open();
      expect(fourth!.name, 'b.jetplan');
      expect(fourth.bytes, <int>[0x31]);
      expect(fourth.location, isNull);
      expect(files.unscriptedCalls, 0);

      await expectLater(files.open(), throwsA(isA<StateError>()));
      expect(files.unscriptedCalls, 1);
      expect(files.openCalls, 5);
    });

    test(
        'DF4 saveLocation records each suggested name and answers in the '
        'order scripted', () async {
      final files = FakeDocumentFiles();
      files
        ..scriptSaveCancel()
        ..scriptSaveLocation(name: 'b.jetplan', location: '/p/b.jetplan')
        ..scriptSaveLocationThrow(StateError('panel'));

      expect(await files.saveLocation('Untitled.jetplan'), isNull);
      final second = await files.saveLocation('A.jetplan');
      expect(second!.name, 'b.jetplan');
      expect(second.location, '/p/b.jetplan');
      await expectLater(
          files.saveLocation('C.jetplan'),
          throwsA(
              isA<StateError>().having((e) => e.message, 'message', 'panel')));
      expect(files.unscriptedCalls, 0);
      await expectLater(files.saveLocation('D.jetplan'), throwsStateError);
      expect(files.unscriptedCalls, 1);
      expect(files.saveLocationCalls, <String>[
        'Untitled.jetplan',
        'A.jetplan',
        'C.jetplan',
        'D.jetplan',
      ]);
    });

    test(
        'DF5 write records every call, a failed one too; failNextWrite fails '
        'the next write only; the recorded bytes are a copy', () async {
      final files = FakeDocumentFiles();
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);

      await files.write('/p/a.jetplan', 'a.jetplan', bytes);
      bytes[0] = 9;
      files.failNextWrite(const FileSystemLikeError());
      await expectLater(files.write('/p/b.jetplan', 'b.jetplan', bytes),
          throwsA(isA<FileSystemLikeError>()));
      await files.write('/p/c.jetplan', 'c.jetplan', bytes);

      expect(files.writes, hasLength(3));
      expect(files.writes[0].location, '/p/a.jetplan');
      expect(files.writes[0].name, 'a.jetplan');
      expect(files.writes[0].bytes, <int>[1, 2, 3]);
      expect(files.writes[1].location, '/p/b.jetplan');
      expect(files.writes[1].bytes, <int>[9, 2, 3]);
      expect(files.writes[2].name, 'c.jetplan');
      expect(files.heldWrites, isEmpty);
    });

    test(
        'DF6 holdWrites: a write completes only when the test completes it, '
        'with a value or an error; writesInPlace is what was asked', () async {
      final files = FakeDocumentFiles(writesInPlace: false);
      expect(files.writesInPlace, isFalse);
      expect(FakeDocumentFiles().writesInPlace, isTrue);

      files.holdWrites = true;
      var done = false;
      final first = files
          .write('a.jetplan', 'a.jetplan', Uint8List.fromList(<int>[5]))
          .then((_) => done = true);
      final second =
          files.write('b.jetplan', 'b.jetplan', Uint8List.fromList(<int>[6]));
      expect(files.writes, hasLength(2));
      expect(files.heldWrites, hasLength(2));
      await pumpEventQueue();
      expect(done, isFalse);

      files.heldWrites[0].complete();
      await first;
      expect(done, isTrue);
      files.heldWrites[1].completeError(const FileSystemLikeError());
      await expectLater(second, throwsA(isA<FileSystemLikeError>()));

      files.holdWrites = false;
      await files.write('c.jetplan', 'c.jetplan', Uint8List(0));
      expect(files.heldWrites, hasLength(2));
      expect(files.writes, hasLength(3));
    });
  });
}

/// A thrown object that is not an [Exception] and not the [StateError] the
/// fake throws itself: the host catches any thrown object (spec 12a S-12).
class FileSystemLikeError {
  const FileSystemLikeError();
}
