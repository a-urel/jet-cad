// The document host (spec 12a D2, D5, D8, D10, D11, D13; plan 12a P-3):
// the session that owns the current document and its file state, and the
// widget that runs the flows over it -- New, Open sample, Open, Save and
// Save As, asking first when unsaved work would be lost, and the app's
// exit request -- and builds the shell, keyed by the document, so a new
// document is a new shell.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'document_files.dart';
import 'exit_guard.dart';
import 'export/export_dialog.dart';
import 'export/export_flow.dart';
import 'export/export_font.dart';
import 'export/page_printer.dart';
import 'main.dart';
import 'new_document.dart';
import 'parametric/catalog.dart';
import 'shell_commands.dart';
import 'startup_plan.dart';
import 'symbols/symbol_library_loader.dart';

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

  /// Whether the document differs from its save point, read from the
  /// dispatcher now. [dirty] follows the change stream, which delivers a
  /// microtask after the change: a flow that has just settled pending input
  /// (spec 12a D2), whose commit is not on [dirty] yet, reads this.
  bool get differsFromSave => _document.commands.stateId != _savedState;

  void _listen() {
    _changes = _document.commands.changes.listen((_) => _recompute());
  }

  void _recompute() => dirty.value = differsFromSave;

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
///
/// New, Open and Open sample ask Save / Don't Save / Cancel first when the
/// document is dirty (D10); the app's exit request asks the same (D11,
/// through an `AppLifecycleListener` the host owns); and [exitGuard] is
/// armed exactly while the document is dirty (D11, the web's tab close).
class DocumentHost extends StatefulWidget {
  const DocumentHost(
      {super.key,
      required this.session,
      required this.files,
      this.exitGuard,
      this.symbols,
      this.thumbnails,
      this.exportFont,
      this.printer = const PrintingPagePrinter()});

  final DocumentSession session;
  final DocumentFiles files;

  /// The platform's guard when null (a test passes a fake). The host owns
  /// it: it disposes it with itself.
  final ExitGuard? exitGuard;

  /// The app's symbol library loader (spec 09b D2, R-4), handed to every
  /// shell this host builds; the app owns it, so a document swap keeps it.
  final SymbolLibraryLoader? symbols;

  /// The app's symbol thumbnail cache (spec 09b D5), handed to every shell
  /// with [symbols]; the app owns it.
  final SymbolThumbnails? thumbnails;

  /// The app's export font (spec 13 D7), read once per app; the app owns
  /// it, so a document swap keeps it. The export and print flows read
  /// [ExportFontCache.bytes] (plan 13 Tasks 9-10). A host given none makes
  /// its own over the bundled asset, which reads nothing until an export
  /// asks.
  final ExportFontCache? exportFont;

  /// Where Print hands the page's PDF (spec 13 D9): the platform's print
  /// dialog unless a test gives a fake.
  final PagePrinter printer;

  @override
  State<DocumentHost> createState() => DocumentHostState();
}

/// The answer to the Save / Don't Save / Cancel dialog (spec 12a D10).
enum SaveChoice { save, discard, cancel }

class DocumentHostState extends State<DocumentHost> {
  /// Object snap (F3): the host's, so it survives a swap (spec 12a D2).
  final SnapSettings snap = SnapSettings();

  VoidCallback? _settle;

  /// The app's exit request (spec 12a D11): Cmd+Q, the app menu's Quit, and
  /// on macOS the window's close button, which `MainFlutterWindow` routes
  /// through it. Made in [initState], disposed with the host.
  late final AppLifecycleListener _exitListener;

  /// Armed exactly while dirty (spec 12a D11).
  late final ExitGuard _exitGuard;

  DocumentSession get _session => widget.session;

  /// The file commands are enabled while no flow runs (spec 12a D6, R-7);
  /// the shell adds its own half of idle, a shape part-way (T-2).
  late final DerivedFlag _notBusy =
      DerivedFlag([_session.busy], () => !_session.busy.value);

  /// The export font: the app's, or the host's own when none was given.
  late final ExportFontCache _exportFont =
      widget.exportFont ?? ExportFontCache();

  /// The Export dialog's last answer in this app session (spec 13 D8): the
  /// host's, so a document swap keeps it; PDF, 150 dpi at first.
  ExportChoice _lastExport = ExportChoice.initial;

  /// The file half of the command table (spec 12a D6), in the toolbar's
  /// order: New, Open, Open sample, Save, Save As, Export, Print (spec 13
  /// D8, D9). Each
  /// runs one flow, which sets busy for its span (T-8).
  ///
  /// Their `enabled` is only "no flow is running": it does **not** know
  /// about a shape part-way, which only the shell sees (T-2, R-8), nor --
  /// for Export and Print -- whether the document has a page
  /// ([kPageCommandIds]).
  /// Bind them through the shell, which re-wraps each with its own idle
  /// and, for those, its page; a consumer that binds this list directly
  /// would act mid-shape.
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
    ShellCommand(
        id: 'export',
        label: 'Export…',
        icon: Icons.ios_share_outlined,
        shortcuts: kExportChords,
        enabled: _notBusy,
        run: exportFlow),
    ShellCommand(
        id: 'print',
        label: 'Print…',
        icon: Icons.print_outlined,
        shortcuts: kPrintChords,
        enabled: _notBusy,
        run: printFlow),
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

  /// Whether the current document may go (spec 12a D10, D11), asked inside
  /// the caller's flow, after its settle. Clean: yes, without a dialog.
  /// Dirty: the Save / Don't Save / Cancel dialog. Save runs [saveStep]
  /// inside the caller's busy span (T-8); a cancelled or failed save is a
  /// no, and a save that succeeded while an edit landed during the write
  /// (the document is dirty again, D5) asks again rather than lose that
  /// edit. Don't Save: yes. Cancel: no. Dirty is read from the dispatcher,
  /// not from [DocumentSession.dirty]: the settle's commit has not reached
  /// the notifier yet.
  Future<bool> _mayDiscard() async {
    while (_session.differsFromSave) {
      switch (await _askToSave()) {
        case SaveChoice.save:
          if (!await saveStep()) return false;
        case SaveChoice.discard:
          return true;
        case SaveChoice.cancel:
          return false;
      }
    }
    return true;
  }

  /// The dialog of spec 12a D10: Save is the default (it has the focus, so
  /// Enter saves), Escape is Cancel.
  Future<SaveChoice> _askToSave() async {
    if (!mounted) return SaveChoice.cancel;
    final choice = await showDialog<SaveChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SaveChangesDialog(name: _session.name),
    );
    return choice ?? SaveChoice.cancel;
  }

  /// The app's exit request (spec 12a D11), in this order (T-7): a flow in
  /// progress -- a dialog, a panel, a write in flight -- cancels, with no
  /// second dialog (S-17); else pending input is settled, so a typed value
  /// makes the document dirty rather than being lost; then a clean
  /// document exits, and a dirty one asks as [_mayDiscard] does. A shape
  /// part-way does not block the exit and is dropped (U-7): busy, not
  /// idle.
  Future<AppExitResponse> _onExitRequested() async {
    if (_session.busy.value) return AppExitResponse.cancel;
    final mayExit = await _flow(() async {
      _settlePendingInput();
      return _mayDiscard();
    });
    return mayExit ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  void _armExitGuard() => _exitGuard.armed = _session.dirty.value;

  /// New (spec 12a D4): the empty document, untitled and clean, once the
  /// current one may go (D10).
  Future<void> newFlow() => _flow(() async {
        _settlePendingInput();
        if (!await _mayDiscard()) return;
        final measurer = FlutterTextMeasurer();
        _session.replace(newDocument(measurer), measurer);
      });

  /// Open sample (spec 12a D4): the sample flat, untitled and clean, once
  /// the current document may go (D10).
  Future<void> openSampleFlow() => _flow(() async {
        _settlePendingInput();
        if (!await _mayDiscard()) return;
        final measurer = FlutterTextMeasurer();
        _session.replace(startupPlan(measurer), measurer);
      });

  /// Open (spec 12a D8): once the current document may go -- asked before
  /// the picker, as macOS apps do (D10) -- pick, decode with the app's
  /// registrations and a fresh measurer, then swap. The replacement is
  /// built before anything is torn down: any object thrown while reading or
  /// decoding (S-12: the loaders throw `TypeError`s and null-check errors,
  /// not only exceptions) shows an error dialog naming the file, clears the
  /// fresh measurer, and changes nothing else. A cancel does nothing. Open
  /// adds no DASHED record (R-3): the bytes stay the file's.
  Future<void> openFlow() => _flow(() async {
        _settlePendingInput();
        if (!await _mayDiscard()) return;
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

  /// Export (spec 13 D8): after the settle, the document's page -- none,
  /// and nothing happens; then the Export dialog, opened on the last
  /// choice; then where to save `<name>.pdf` or `<name>.png`; then the
  /// page, exported without the separators, written there. A cancel at
  /// either step writes nothing; any object thrown on the way shows
  /// `Export failed`. The document is read, never written.
  Future<void> exportFlow() => _flow(() async {
        _settlePendingInput();
        final document = _session.document;
        final page = exportPageOf(document);
        if (page == null || !mounted) return;
        final choice = await showExportDialog(context, _lastExport);
        if (choice == null) return;
        _lastExport = choice;
        final kind = exportFileKind(choice);
        try {
          final place = await widget.files
              .saveLocation(exportFileName(_session.name, choice), kind: kind);
          if (place == null) return;
          final bytes = await exportBytes(document, page, choice,
              fontBytes: () => _exportFont.bytes);
          await widget.files
              .write(place.location, place.name, bytes, kind: kind);
        } catch (e) {
          await _showError('Export failed', e);
        }
      });

  /// Print (spec 13 D9): after the settle, the document's page -- none, and
  /// nothing happens; then the page exported once as Export → PDF makes it
  /// (the separators omitted, the export font), and those bytes handed to
  /// the printer with the document's name and the page's size in pt. Any
  /// object thrown on the way shows `Print failed`. The document is read,
  /// never written.
  Future<void> printFlow() => _flow(() async {
        _settlePendingInput();
        final document = _session.document;
        final page = exportPageOf(document);
        if (page == null || !mounted) return;
        try {
          final bytes = await exportPdfBytes(document, page,
              fontBytes: await _exportFont.bytes);
          await widget.printer
              .print(bytes, _session.name, printPageFormat(page));
        } catch (e) {
          await _showError('Print failed', e);
        }
      });

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
  void initState() {
    super.initState();
    _exitListener = AppLifecycleListener(onExitRequested: _onExitRequested);
    _exitGuard = widget.exitGuard ?? createExitGuard();
    _armExitGuard();
    _session.dirty.addListener(_armExitGuard);
  }

  @override
  void dispose() {
    _session.dirty.removeListener(_armExitGuard);
    _exitGuard.dispose();
    _exitListener.dispose();
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
          symbols: widget.symbols,
          thumbnails: widget.thumbnails,
        ),
      );
}

/// Save / Don't Save / Cancel for the document [name] (spec 12a D10). Pops
/// its [SaveChoice]; Escape pops [SaveChoice.cancel]; Save has the focus.
class _SaveChangesDialog extends StatelessWidget {
  const _SaveChangesDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    void choose(SaveChoice choice) => Navigator.of(context).pop(choice);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            choose(SaveChoice.cancel),
      },
      child: AlertDialog(
        key: const Key('replace-dialog'),
        title:
            Text('Save the changes to $name?', key: const Key('replace-title')),
        content: const Text('Your changes are lost if you do not save them.'),
        actions: [
          TextButton(
            key: const Key('replace-discard'),
            onPressed: () => choose(SaveChoice.discard),
            child: const Text("Don't Save"),
          ),
          TextButton(
            key: const Key('replace-cancel'),
            onPressed: () => choose(SaveChoice.cancel),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('replace-save'),
            autofocus: true,
            onPressed: () => choose(SaveChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
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
