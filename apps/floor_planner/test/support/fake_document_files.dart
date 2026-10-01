import 'dart:async';
import 'dart:typed_data';

import 'package:floor_planner/document_files.dart';

/// One call to [FakeDocumentFiles.write], as it was made.
typedef FakeWrite = ({
  Object location,
  String name,
  Uint8List bytes,
  FileKind kind
});

/// A scripted [DocumentFiles] for the host's tests (plan 12a P-5, spec 12a
/// D9): no panel, no disk, no download.
///
/// [open] and [saveLocation] answer from queues the test fills, in order:
/// a file, a cancel (null) or a throw. A call with nothing scripted throws
/// a [StateError] and is counted in [unscriptedCalls], so a test that did
/// not expect the call can say so even when the host catches the throw.
///
/// [write] records every call in [writes], in order, whatever its outcome.
/// It then fails when [failNextWrite] queued an error, is held when
/// [holdWrites] is set (the future is a [Completer]'s in [heldWrites], which
/// the test completes, or completes with an error), and otherwise
/// succeeds.
class FakeDocumentFiles implements DocumentFiles {
  FakeDocumentFiles({this.writesInPlace = true});

  @override
  final bool writesInPlace;

  final _opens = <FutureOr<({String name, Uint8List bytes, Object? location})?>
      Function()>[];
  final _saveLocations =
      <FutureOr<({String name, Object location})?> Function()>[];
  final _writeErrors = <Object>[];

  /// How many times [open] was called.
  int openCalls = 0;

  /// The `suggestedName` of every [saveLocation] call, in order.
  final saveLocationCalls = <String>[];

  /// The `kind` of every [saveLocation] call, in order (one per entry of
  /// [saveLocationCalls]).
  final saveLocationKinds = <FileKind>[];

  /// Every [write] call, in order, including those that then failed or are
  /// still held.
  final writes = <FakeWrite>[];

  /// When set, each [write] returns the future of a new [Completer] added
  /// to [heldWrites] instead of completing by itself.
  bool holdWrites = false;

  /// The completers of the held writes, in order.
  final heldWrites = <Completer<void>>[];

  /// Calls that found nothing scripted.
  int unscriptedCalls = 0;

  /// The next [open] returns this file.
  void scriptOpen(
      {required String name, required List<int> bytes, Object? location}) {
    final copy = Uint8List.fromList(bytes);
    _opens.add(() => (name: name, bytes: copy, location: location));
  }

  /// The next [open] is cancelled (returns null).
  void scriptOpenCancel() => _opens.add(() => null);

  /// The next [open] throws [error].
  void scriptOpenThrow(Object error) => _opens.add(() => throw error);

  /// The next [saveLocation] returns this place.
  void scriptSaveLocation({required String name, required Object location}) =>
      _saveLocations.add(() => (name: name, location: location));

  /// The next [saveLocation] is cancelled (returns null).
  void scriptSaveCancel() => _saveLocations.add(() => null);

  /// The next [saveLocation] throws [error].
  void scriptSaveLocationThrow(Object error) =>
      _saveLocations.add(() => throw error);

  /// The next [write] throws [error] (after it is recorded).
  void failNextWrite(Object error) => _writeErrors.add(error);

  @override
  Future<({String name, Uint8List bytes, Object? location})?> open() async {
    openCalls++;
    if (_opens.isEmpty) {
      unscriptedCalls++;
      throw StateError('FakeDocumentFiles.open: nothing scripted');
    }
    return _opens.removeAt(0)();
  }

  @override
  Future<({String name, Object location})?> saveLocation(String suggestedName,
      {FileKind kind = FileKind.jetplan}) async {
    saveLocationCalls.add(suggestedName);
    saveLocationKinds.add(kind);
    if (_saveLocations.isEmpty) {
      unscriptedCalls++;
      throw StateError('FakeDocumentFiles.saveLocation: nothing scripted');
    }
    return _saveLocations.removeAt(0)();
  }

  @override
  Future<void> write(Object location, String name, Uint8List bytes,
      {FileKind kind = FileKind.jetplan}) {
    writes.add((
      location: location,
      name: name,
      bytes: Uint8List.fromList(bytes),
      kind: kind
    ));
    if (_writeErrors.isNotEmpty) return Future.error(_writeErrors.removeAt(0));
    if (holdWrites) {
      final held = Completer<void>();
      heldWrites.add(held);
      return held.future;
    }
    return Future.value();
  }
}
