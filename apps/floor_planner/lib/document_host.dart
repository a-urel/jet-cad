// The document host (spec 12a D2, D5, D8, D13; plan 12a P-3): the session
// that owns the current document and its file state, and the widget that
// runs the flows over it -- New, Open sample, Open, Save and Save As -- and
// builds the shell, keyed by the document, so a new document is a new
// shell.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'document_files.dart';
import 'main.dart';
import 'new_document.dart';
import 'parametric/catalog.dart';
import 'shell_commands.dart';
import 'startup_plan.dart';

/// The name of a document that has no file yet (spec 12a D4).
const String kUntitledName = 'Untitled';

/// The web tab's title (spec 12a D5): `name — jet-cad`, with `• ` in front
/// while [dirty].
String documentTitle(String name, {required bool dirty}) =>
    '${dirty ? '• ' : ''}$name — jet-cad';

/// The name a file shows as: its base name without `.jetplan` (spec 12a
/// D8). Another extension is kept.
String documentNameOf(String fileName) {
  const suffix = '.$kJetplanExtension';
  return fileName.endsWith(suffix) && fileName.length > suffix.length
      ? fileName.substring(0, fileName.length - suffix.length)
      : fileName;
}

/// The current document and what the app knows about its file (spec 12a
/// D2, D5; plan 12a P-3): the document and the measurer it was built with,
/// its file name and location, its save point, and the dirty and busy
/// notifiers.
///
/// **Clean** iff the document's `commands.stateId` is [savedState]. The
/// session listens to the current document's `commands.changes` and
/// recomputes [dirty] on each change; the subscription is the current
/// document's only, made again with every [replace] (S-23).
///
/// Notifies when the document, the name or the location changes; [dirty]
/// and [busy] notify for themselves.
class DocumentSession extends ChangeNotifier {
  DocumentSession(DraftDocument document, FlutterTextMeasurer measurer)
      : _document = document,
        _measurer = measurer,
        _savedState = document.commands.stateId {
    _listen();
  }

  /// The launch document: [newDocument], untitled and clean (spec 12a D4).
  factory DocumentSession.untitled() {
    final measurer = FlutterTextMeasurer();
    return DocumentSession(newDocument(measurer), measurer);
  }

  DraftDocument _document;
  FlutterTextMeasurer _measurer;
  String? _fileName;
  Object? _location;
  int _savedState;
  StreamSubscription<DocChange>? _changes;

  /// Whether the document differs from its save point.
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);

  /// Whether a flow is running (spec 12a D6). Set by the outermost flow
  /// only (T-8).
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  DraftDocument get document => _document;

  /// The measurer [document] was built or decoded with: one per document,
  /// cleared once, after the document is replaced (spec 12a D2).
  FlutterTextMeasurer get measurer => _measurer;

  /// The file's name, with its extension; null while untitled.
  String? get fileName => _fileName;

  /// The document's name: [kUntitledName], or [fileName] without
  /// `.jetplan`.
  String get name =>
      _fileName == null ? kUntitledName : documentNameOf(_fileName!);

  /// Where a Save writes, as the files object returned it; opaque here.
  Object? get location => _location;

  /// The state id the last save encoded, or the document's id when it
  /// came in (spec 12a D5).
  int get savedState => _savedState;

  void _listen() {
    _changes = _document.commands.changes.listen((_) => _recompute());
  }

  void _recompute() => dirty.value = _document.commands.stateId != _savedState;

  /// Makes [document] (built or decoded with [measurer]) the current one,
  /// named after [fileName] (untitled when null) at [location], clean: the
  /// save point is its state id now. One notification (spec 12a D2, S-28).
  ///
  /// The old document is disposed, and its measurer cleared, after the
  /// next frame, once the old shell's `dispose` has let go of it (S-11,
  /// S-24): disposing closes its change stream, which ends any
  /// subscription still on it, and makes a stale use throw.
  void replace(DraftDocument document, FlutterTextMeasurer measurer,
      {String? fileName, Object? location}) {
    final oldDocument = _document;
    final oldMeasurer = _measurer;
    _changes?.cancel();
    _document = document;
    _measurer = measurer;
    _fileName = fileName;
    _location = location;
    _savedState = document.commands.stateId;
    _listen();
    _recompute();
    notifyListeners();
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        oldDocument.dispose();
        oldMeasurer.clear();
      })
      ..ensureVisualUpdate();
  }

  /// A save encoded the document at [stateId] and its bytes reached the
  /// file (spec 12a D5, S-2): that is the save point now, and [dirty] is
  /// recomputed at once (a save emits no document change, T-13). With
  /// [fileName], the document takes that file's name and [location].
  void markSaved(int stateId, {String? fileName, Object? location}) {
    _savedState = stateId;
    _recompute();
    if (fileName != null && (fileName != _fileName || location != _location)) {
      _fileName = fileName;
      _location = location;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    dirty.dispose();
    busy.dispose();
    _document.dispose();
    _measurer.clear();
    super.dispose();
  }
}

/// Runs the document flows over [session] and builds the shell (spec 12a
/// D2, D8, D9, D13): `PlannerShell(key: ObjectKey(document), …)`, so a
/// replaced document gets a fresh shell and the old one's `dispose`
/// releases everything it held. Owns the object-snap setting, which
/// survives a swap (D2).
///
/// The flows are public for the tests; the command table (spec 12a D6)
/// reaches them through [DocumentHostState.fileCommands].
/// Each sets [DocumentSession.busy] for its whole span when it is the
/// outermost flow, and clears it in a `finally` (S-21, T-8); a flow called
/// inside another leaves busy to the outer one.
class DocumentHost extends StatefulWidget {
  const DocumentHost({super.key, required this.session, required this.files});

  final DocumentSession session;
  final DocumentFiles files;

  @override
  State<DocumentHost> createState() => DocumentHostState();
}

class DocumentHostState extends State<DocumentHost> {
  /// Object snap (F3): the host's, so it survives a swap (spec 12a D2).
  final SnapSettings snap = SnapSettings();

  VoidCallback? _settle;

  DocumentSession get _session => widget.session;

  /// The file commands are enabled while no flow runs (spec 12a D6, R-7);
  /// the shell adds its own half of idle, a shape part-way (T-2).
  late final DerivedFlag _notBusy =
      DerivedFlag([_session.busy], () => !_session.busy.value);

  /// The file half of the command table (spec 12a D6), in the toolbar's
  /// order: New, Open, Open sample, Save, Save As. Each runs one flow,
  /// which sets busy for its span (T-8).
  late final List<ShellCommand> fileCommands = [
    ShellCommand(
        id: 'new',
        label: 'New',
        icon: Icons.note_add_outlined,
        shortcuts: kNewChords,
        enabled: _notBusy,
        run: newFlow),
    ShellCommand(
        id: 'open',
        label: 'Open…',
        icon: Icons.folder_open_outlined,
        shortcuts: kOpenChords,
        enabled: _notBusy,
        run: openFlow),
    ShellCommand(
        id: 'open-sample',
        label: 'Open sample',
        icon: Icons.home_work_outlined,
        enabled: _notBusy,
        run: openSampleFlow),
    ShellCommand(
        id: 'save',
        label: 'Save',
        icon: Icons.save_outlined,
        shortcuts: kSaveChords,
        enabled: _notBusy,
        run: saveStep),
    ShellCommand(
        id: 'save-as',
        label: 'Save As…',
        icon: Icons.save_as_outlined,
        shortcuts: kSaveAsChords,
        enabled: _notBusy,
        run: saveAsStep),
  ];

  VoidCallback _registerSettle(VoidCallback settle) {
    _settle = settle;
    return () {
      if (identical(_settle, settle)) _settle = null;
    };
  }

  /// Spec 12a D2: pending input is committed before a flow reads or
  /// replaces the document, synchronously.
  void _settlePendingInput() => _settle?.call();

  /// Runs [body] as a flow: busy for its whole span when no flow is
  /// running yet, cleared however it ends (spec 12a D6, S-21); inside
  /// another flow, busy is the outer one's (T-8).
  Future<T> _flow<T>(Future<T> Function() body) async {
    final busy = _session.busy;
    if (busy.value) return body();
    busy.value = true;
    try {
      return await body();
    } finally {
      busy.value = false;
    }
  }

  /// New (spec 12a D4): the empty document, untitled and clean. Replaces
  /// the current one unconditionally (the dirty dialog, D10, goes in front
  /// of it later).
  Future<void> newFlow() => _flow(() async {
        _settlePendingInput();
        final measurer = FlutterTextMeasurer();
        _session.replace(newDocument(measurer), measurer);
      });

  /// Open sample (spec 12a D4): the startup flat, untitled and clean.
  Future<void> openSampleFlow() => _flow(() async {
        _settlePendingInput();
        final measurer = FlutterTextMeasurer();
        _session.replace(startupPlan(measurer), measurer);
      });

  /// Open (spec 12a D8): pick, decode with the app's registrations and a
  /// fresh measurer, then swap. The replacement is built before anything
  /// is torn down: any object thrown while reading or decoding (S-12: the
  /// loaders throw `TypeError`s and null-check errors, not only
  /// exceptions) shows an error dialog naming the file, clears the fresh
  /// measurer, and changes nothing else. A cancel does nothing. Open adds
  /// no DASHED record (R-3): the bytes stay the file's.
  Future<void> openFlow() => _flow(() async {
        _settlePendingInput();
        final ({String name, Uint8List bytes, Object? location})? file;
        try {
          file = await widget.files.open();
        } catch (e) {
          await _showError('Could not open the file', e);
          return;
        }
        if (file == null) return;
        final measurer = FlutterTextMeasurer();
        final DraftDocument document;
        try {
          document = DraftDocumentCodec.decodeString(utf8.decode(file.bytes),
              measurer: measurer,
              registerComponents: registerAppComponents,
              // Not shown in 12a (the diagnostics slice).
              diagnostics: <Diagnostic>[]);
        } catch (e) {
          measurer.clear();
          await _showError('Could not open ${file.name}', e);
          return;
        }
        _session.replace(document, measurer,
            fileName: file.name, location: file.location);
      });

  /// Save (spec 12a D5, D9, D13): true when the bytes were written. An
  /// untitled document, or one whose location the files object cannot
  /// write in place to, is saved as ([saveAsStep]'s path); on the web a
  /// titled document downloads under its name without asking.
  Future<bool> saveStep() => _flow(() async {
        _settlePendingInput();
        final encoded = _encode();
        final fileName = _session.fileName;
        final location = _session.location;
        if (fileName != null) {
          if (!widget.files.writesInPlace) {
            return _write(encoded, location ?? fileName, fileName);
          }
          if (location != null) return _write(encoded, location, fileName);
        }
        return _saveAs(encoded);
      });

  /// Save As (spec 12a D9): asks where, then writes; false when cancelled
  /// or failed.
  Future<bool> saveAsStep() => _flow(() async {
        _settlePendingInput();
        return _saveAs(_encode());
      });

  /// The document, its state id and its bytes, read in one synchronous
  /// block after the settle (spec 12a D5, S-2): the save point is the id
  /// the bytes were encoded at, whatever happens while the write is
  /// pending. The bytes are the codec's and nothing else (D13).
  ({DraftDocument document, int stateId, Uint8List bytes}) _encode() {
    final document = _session.document;
    return (
      document: document,
      stateId: document.commands.stateId,
      bytes: utf8.encode(DraftDocumentCodec.encodeToString(document)),
    );
  }

  Future<bool> _saveAs(
      ({DraftDocument document, int stateId, Uint8List bytes}) encoded) async {
    final ({String name, Object location})? place;
    try {
      place = await widget.files.saveLocation('${_session.name}.jetplan');
    } catch (e) {
      await _showError('Could not save ${_session.name}', e);
      return false;
    }
    if (place == null) return false;
    return _write(encoded, place.location, place.name);
  }

  /// Writes, then moves the save point to the encoded id and names the
  /// document after the file; on a failure shows the error and leaves the
  /// save point where it was.
  Future<bool> _write(
      ({DraftDocument document, int stateId, Uint8List bytes}) encoded,
      Object location,
      String fileName) async {
    try {
      await widget.files.write(location, fileName, encoded.bytes);
    } catch (e) {
      await _showError('Could not save $fileName', e);
      return false;
    }
    // A save point is an id of one dispatcher's (spec 12a D3): it means
    // nothing for another document.
    if (identical(_session.document, encoded.document)) {
      _session.markSaved(encoded.stateId,
          fileName: fileName, location: location);
    }
    return true;
  }

  /// The error dialog of a failed Open or Save (spec 12a D8): what failed
  /// and the thrown object's text. The flow waits for it, so it stays busy
  /// while the dialog is up.
  Future<void> _showError(String title, Object error) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('document-error'),
        title: Text(title, key: const Key('document-error-title')),
        content: Text(error.toString(), key: const Key('document-error-text')),
        actions: [
          TextButton(
            key: const Key('document-error-ok'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notBusy.dispose();
    snap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _session,
        builder: (context, _) => PlannerShell(
          key: ObjectKey(_session.document),
          document: _session.document,
          snap: snap,
          fileCommands: fileCommands,
          documentName: _session.name,
          dirty: _session.dirty,
          busy: _session.busy,
          onSettle: _registerSettle,
        ),
      );
}

/// Asks for a file name, starting from [suggested] (spec 12a D9 web,
/// T-12): the web's save prompt. Null when cancelled; the files object
/// treats a blank name as a cancel and appends `.jetplan`.
Future<String?> showDocumentNamePrompt(
        BuildContext context, String suggested) =>
    showDialog<String>(
      context: context,
      builder: (_) => _NamePrompt(suggested: suggested),
    );

class _NamePrompt extends StatefulWidget {
  const _NamePrompt({required this.suggested});

  final String suggested;

  @override
  State<_NamePrompt> createState() => _NamePromptState();
}

class _NamePromptState extends State<_NamePrompt> {
  late final TextEditingController _name =
      TextEditingController(text: widget.suggested);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_name.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('name-prompt'),
        title: const Text('Save as'),
        content: TextField(
          key: const Key('name-prompt-field'),
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
          onSubmitted: (_) => _save(),
        ),
        actions: [
          TextButton(
            key: const Key('name-prompt-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('name-prompt-save'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      );
}
