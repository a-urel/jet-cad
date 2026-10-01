// Spec 13 D8, plan 13 Task 8 (review finding 1): the platform files cannot
// run here (the io side needs the macOS panel, the web side a browser), so
// their use of the file kind is pinned by their source, as the render
// package's T-11 pins page_export.dart. Named mutants: M-8iocall (the io
// panel offers a fixed type group), M-8webname (spec M-13ac at the web call
// site: the name takes a fixed kind's extension), M-8webmime (the web blob
// has a fixed MIME type).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final io = File('lib/document_files_io.dart').readAsStringSync();
  final web = File('lib/document_files_web.dart').readAsStringSync();

  test('DS1 the io save panel offers the kind\'s type groups', () {
    expect(io, contains('acceptedTypeGroups: saveTypeGroupsFor(kind)'));
    expect('kJetplanTypeGroup'.allMatches(io), hasLength(1),
        reason: 'the open panel only');
  });

  test('DS2 the web save names the file and types the blob by the kind', () {
    expect(web, contains('fileNameFor(await askName(suggestedName), kind)'));
    expect(web, contains('BlobPropertyBag(type: kind.mimeType)'));
    expect(web, isNot(contains('application/')),
        reason: 'no MIME type literal: the kind carries it');
    expect(web, isNot(contains('jetplanFileName')),
        reason: 'no jetplan-only naming');
  });
}
