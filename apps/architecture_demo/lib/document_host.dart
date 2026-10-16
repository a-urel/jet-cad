// The document host (spec B2, decision 5): the widget that runs the
// document flows -- New, Open sample, Open, Save and Save As, asking first
// when unsaved work would be lost -- over the app's one PlanController, and
// builds the editor. Ported from apps/floor_planner/lib/document_host.dart
// (DocumentHostState and the dialogs); the document, its codec, the save
// point and the settle registry are the controller's now.
//
// Two questions about the controller, answered from its source:
//
// * Does `newPlan` settle pending input? Yes: `newPlan`, `load`, `save` and
//   `markSaved` each call `settlePendingInput` first (plan_controller.dart
//   :678, :687, :696, :726). That method is `@internal`, so the host cannot
//   call it; `PlanEditor` settles before it calls `onNew`/`onOpen`/`onSave`/
//   `onSaveAs`, which is the path of every toolbar button and chord. A flow
//   called directly (the tests) therefore reads `dirty` before the settle
//   that `newPlan` or `load` would do; Task 5's exit request will settle
//   with a discarded `controller.save()`.
// * Does `dirty` update synchronously after a command? No. `_refreshFlags`
//   (plan_controller.dart :1935) sets `_dirty` from `commands.stateId !=
//   _savedState`, but the commit path reaches it through the document's
//   change stream (:1685, `_onDesignChange`), which delivers a microtask
//   after the command. A settle's own commit -- a typed panel value -- is
//   therefore not on `dirty` yet when the editor calls the host back.
//   `_mayDiscard` yields one microtask before it reads (see there); the
//   old app read the dispatcher's `differsFromSave` instead, and the save
//   point is private to the controller.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show buildSampleFlat;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'app_strings.dart';
import 'busy_wrappers.dart';
import 'document_files.dart';
import 'document_session.dart';
import 'exit_guard.dart';

/// What a save encoded: the plan's document (to tell a swap during the
/// write) and its bytes.
typedef _Encoded = ({Object plan, Uint8List bytes});

/// The answer to the Save / Don't Save / Cancel dialog.
enum SaveChoice { save, discard, cancel }

/// Runs the document flows over [controller] and [session] and builds the
/// editor. The flows are public for the tests; the editor reaches them
/// through its file callbacks, which do nothing while a flow runs.
///
/// Each flow sets [DocumentSession.busy] for its whole span when it is the
/// outermost flow, and clears it in a `finally`; a flow called inside
/// another leaves busy to the outer one.
class DocumentHost extends StatefulWidget {
  const DocumentHost(
      {super.key,
      required this.controller,
      required this.session,
      required this.files,
      this.exitGuard,
      this.printer = const PrintingPagePrinter()});

  final PlanController controller;
  final DocumentSession session;
  final DocumentFiles files;

  /// The exit guard the host arms exactly while the plan is dirty; the
  /// platform's when null.
  final ExitGuard? exitGuard;

  /// Where Print hands the page's PDF.
  final PagePrinter printer;

  @override
  State<DocumentHost> createState() => DocumentHostState();
}

class DocumentHostState extends State<DocumentHost> {
  PlanController get _controller => widget.controller;
  DocumentSession get _session => widget.session;

  late final AppLifecycleListener _exitListener;
  late final ExitGuard _exitGuard;

  /// The printer the editor gets: busy around the platform's print job.
  /// Made once, not per build.
  late final PagePrinter _printer = BusyPagePrinter(
      _session.busy, widget.printer,
      isDisposed: () => _session.isDisposed);

  /// The export dialog the editor gets: busy while it is up. Made once.
  late final PlanExportDialog _exportDialog =
      busyExportDialog(_session.busy, isDisposed: () => _session.isDisposed);

  /// Runs [body] as a flow: busy for its whole span when no flow is running
  /// yet, cleared however it ends; inside another flow, busy is the outer
  /// one's.
  Future<T> _flow<T>(Future<T> Function() body) async {
    final busy = _session.busy;
    if (busy.value) return body();
    busy.value = true;
    try {
      return await body();
    } finally {
      // The app may be torn down with a flow in flight.
      if (!_session.isDisposed) busy.value = false;
    }
  }

  /// A file callback that does nothing while a flow runs (decision 5): the
  /// editor has no hook to grey its buttons out.
  PlanFileCallback _idle(Future<Object?> Function() flow) => () async {
        if (_session.busy.value) return;
        await flow();
      };

  /// Whether the current plan may go, asked inside the caller's flow. Clean:
  /// yes, without a dialog. Dirty: the Save / Don't Save / Cancel dialog.
  /// Save runs [saveStep] inside the caller's busy span; a cancelled or
  /// failed save is a no, and a save that succeeded while an edit landed
  /// during the write (dirty again) asks again rather than lose that edit.
  /// Don't Save: yes. Cancel: no. Dirty is the controller's.
  Future<bool> _mayDiscard() async {
    // `dirty` lags a command by one microtask (the change stream): the
    // editor has just settled pending input, and a typed value's commit is
    // not on it yet. Without this turn a clean-looking plan with a typed,
    // uncommitted value is replaced without asking.
    await Future<void>.value();
    while (_controller.dirty.value) {
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

  /// The app's exit request, in this order: a flow in progress -- a
  /// dialog, a panel, a write in flight -- cancels, with no second dialog;
  /// else pending input is settled, so a typed value makes the plan dirty
  /// rather than being lost; then a clean plan exits and a dirty one asks
  /// as [_mayDiscard] does. A shape part-way does not block the exit and is
  /// dropped.
  ///
  /// The settle is a discarded `controller.save()` (`settlePendingInput` is
  /// `@internal`); `_mayDiscard` then yields one microtask before it reads
  /// `dirty`. A save that throws is not an exit blocker here: the plan is
  /// then asked about as it stands, and Save shows the error.
  Future<AppExitResponse> _onExitRequested() async {
    if (_session.busy.value) return AppExitResponse.cancel;
    final mayExit = await _flow(() async {
      try {
        _controller.save();
      } catch (_) {
        // Settled as far as it could; the dialog's Save reports the error.
      }
      return _mayDiscard();
    });
    return mayExit ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  /// The editor's export hand-over (`PlanEditor.onExport`), as a flow: asks
  /// where, then writes the bytes under the file kind of `export.name`'s
  /// extension (`pdf` or `png`, the only ones the library's built-in
  /// exporters make; any other is an [ArgumentError] shown as the export
  /// failing). A cancelled panel writes nothing. A throw shows the error.
  ///
  /// The sequence, from the library's `EditorPageFlows.export`: the library
  /// takes its own one-flow guard (Export and Print refuse a second press);
  /// the dialog runs inside [busyExportDialog]'s busy span, which ends when
  /// it answers; the library then makes the bytes -- the app is NOT busy
  /// for that stretch, there is no hook; then it calls this with the guard
  /// still held, and the busy span of this flow covers the panel and the
  /// write. A New, Open or Save started during the byte-making is not held:
  /// New and Open replace the plan, which the library sees (the document
  /// is no longer the one it exported) and drops the export; Save writes
  /// its own file. The document is never moved off its save point by an
  /// export.
  Future<void> exportFlow(PlanExport export) => _flow(() async {
        try {
          final dot = export.name.lastIndexOf('.');
          final kind = switch (dot < 0 ? '' : export.name.substring(dot + 1)) {
            'pdf' => FileKind.pdf,
            'png' => FileKind.png,
            final other => throw ArgumentError.value(
                export.name, 'name', 'has no exportable extension: "$other"'),
          };
          final place =
              await widget.files.saveLocation(export.name, kind: kind);
          if (place == null || !mounted) return;
          await widget.files
              .write(place.location, place.name, export.bytes, kind: kind);
        } catch (e) {
          await _showError((w) => w.exportFailed, e);
        }
      });

  void _armExitGuard() => _exitGuard.armed = _controller.dirty.value;

  Future<SaveChoice> _askToSave() async {
    if (!mounted) return SaveChoice.cancel;
    final choice = await showDialog<SaveChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SaveChangesDialog(name: _session.name),
    );
    return choice ?? SaveChoice.cancel;
  }

  /// New: the empty plan, untitled and clean, once the current one may go.
  Future<void> newFlow() => _flow(() async {
        if (!await _mayDiscard()) return;
        _controller.newPlan();
        _session.named(null, null);
      });

  /// Open sample: the sample flat, untitled and clean with nothing to
  /// undo, once the current plan may go.
  Future<void> openSampleFlow() => _flow(() async {
        if (!await _mayDiscard()) return;
        _controller.newPlan(build: buildSampleFlat);
        _session.named(null, null);
      });

  /// Open: once the current plan may go -- asked before the picker -- pick,
  /// decode and load. Any object thrown while reading or loading (a
  /// `PlanFormatException`, a `FormatException` from the bytes, anything)
  /// shows an error dialog naming the file and changes nothing: `load`
  /// throws before it replaces the plan, and the session is named only
  /// after it returned. A cancel does nothing.
  Future<void> openFlow() => _flow(() async {
        if (!await _mayDiscard()) return;
        final file = await _pick();
        if (file == null || !mounted) return;
        try {
          _controller.load(utf8.decode(file.bytes));
        } catch (e) {
          await _showError((w) => w.couldNotOpen(file.name), e);
          return;
        }
        _session.named(file.name, file.location);
      });

  Future<({String name, Uint8List bytes, Object? location})?> _pick() async {
    try {
      return await widget.files.open();
    } catch (e) {
      await _showError((w) => w.couldNotOpenFile, e);
      return null;
    }
  }

  /// Save: true when the bytes were written. An untitled plan, or one whose
  /// location the files object cannot write in place to, is saved as
  /// ([saveAsStep]'s path); on the web a titled plan downloads under its
  /// name without asking.
  Future<bool> saveStep() => _flow(() async {
        final encoded = await _encode();
        if (encoded == null) return false;
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

  /// Save As: asks where, then writes; false when cancelled or failed.
  Future<bool> saveAsStep() => _flow(() async {
        final encoded = await _encode();
        if (encoded == null) return false;
        return _saveAs(encoded);
      });

  /// The plan's bytes, read in one synchronous block (`save` settles
  /// pending input first and remembers the state it encoded): the save
  /// point is that state, whatever happens while the write is pending. A
  /// throw shows the save error and answers null.
  Future<_Encoded?> _encode() async {
    final String text;
    try {
      text = _controller.save();
    } catch (e) {
      await _showError((w) => w.couldNotSave(_session.name), e);
      return null;
    }
    return (
      plan: _controller.document,
      bytes: Uint8List.fromList(utf8.encode(text))
    );
  }

  Future<bool> _saveAs(_Encoded encoded) async {
    final ({String name, Object location})? place;
    try {
      place = await widget.files.saveLocation('${_session.name}.jetplan');
    } catch (e) {
      await _showError((w) => w.couldNotSave(_session.name), e);
      return false;
    }
    if (place == null) return false;
    return _write(encoded, place.location, place.name);
  }

  /// Writes, then moves the save point to the encoded state and names the
  /// plan after the file; on a failure shows the error and leaves the save
  /// point where it was.
  ///
  /// `markSaved` marks the state `save` encoded -- not the current one -- so
  /// an edit made during the write stays dirty. The app's own entry points
  /// cannot start New, Open sample or Open during the write (decision 5:
  /// the file callbacks do nothing while busy), but a flow called inside
  /// this one can (the exit request, the tests): if it replaced the plan, a
  /// save point and a file name mean nothing for the new one, so neither is
  /// given (the old `identical(document, ...)` guard, kept).
  Future<bool> _write(
      _Encoded encoded, Object location, String fileName) async {
    try {
      await widget.files.write(location, fileName, encoded.bytes);
    } catch (e) {
      await _showError((w) => w.couldNotSave(fileName), e);
      return false;
    }
    // The app may be torn down during the write: the file is written, and
    // the controller and the session are gone.
    if (!mounted) return true;
    if (identical(_controller.document, encoded.plan)) {
      _controller.markSaved();
      _session.named(fileName, location);
    }
    return true;
  }

  /// The error dialog of a failed Open or Save: what failed and the thrown
  /// object's text. The flow waits for it, so it stays busy while the
  /// dialog is up.
  Future<void> _showError(
      String Function(AppStrings words) title, Object error) async {
    if (!mounted) return;
    final words = AppStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('document-error'),
        title: Text(title(words), key: const Key('document-error-title')),
        content: Text(error.toString(), key: const Key('document-error-text')),
        actions: [
          TextButton(
            key: const Key('document-error-ok'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.of(context).ok),
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
    _controller.dirty.addListener(_armExitGuard);
  }

  @override
  void dispose() {
    _controller.dirty.removeListener(_armExitGuard);
    _exitGuard.dispose();
    _exitListener.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session.setUntitledName(AppStrings.of(context).untitled)) {
      // Not during this build: the app's title listens to the session.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _session.nameChanged();
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _session,
        builder: (context, _) => Scaffold(
          body: PlanEditor(
            controller: _controller,
            onNew: _idle(newFlow),
            onOpen: _idle(openFlow),
            onSave: _idle(saveStep),
            onSaveAs: _idle(saveAsStep),
            onExport: (export) => unawaited(exportFlow(export)),
            onExportDialog: _exportDialog,
            printer: _printer,
            onPageFlowError: (e) =>
                unawaited(_showError((w) => w.pageFlowFailed, e)),
            exportName: _session.name,
            bar: PlanEditorBar(leading: [
              _DocumentTitle(session: _session, controller: _controller),
              _OpenSampleButton(onPressed: _idle(openSampleFlow)),
            ]),
          ),
        ),
      );
}

/// The plan's name, with `• ` in front and an `Edited` tooltip while it is
/// dirty, cut with an ellipsis at 144 px: with the Open sample button and
/// the library's bar, Export's button included (it was 160 px before the app
/// gave `onExport`), that leaves the top bar fitting 800 px.
class _DocumentTitle extends StatelessWidget {
  const _DocumentTitle({required this.session, required this.controller});

  final DocumentSession session;
  final PlanController controller;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 144),
        child: ListenableBuilder(
          listenable: Listenable.merge([session, controller.dirty]),
          builder: (context, _) {
            final dirty = controller.dirty.value;
            final text = Text(dirty ? '• ${session.name}' : session.name,
                key: const Key('document-name'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis);
            return dirty
                ? Tooltip(message: PlanStrings.of(context).edited, child: text)
                : text;
          },
        ),
      );
}

/// The bar's Open sample button (decision 8): not a `PlanEditorAction`, so
/// the app's own widget in `PlanEditorBar.leading`.
class _OpenSampleButton extends StatelessWidget {
  const _OpenSampleButton({required this.onPressed});

  final PlanFileCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        key: const Key('toolbar-open-sample'),
        icon: const Icon(Icons.home_work_outlined),
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        tooltip: AppStrings.of(context).openSample,
        onPressed: () => unawaited(onPressed()),
      );
}

/// Save / Don't Save / Cancel for the plan [name]. Pops its [SaveChoice];
/// Escape pops [SaveChoice.cancel]; Save has the focus.
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
        title: Text(AppStrings.of(context).saveChangesTo(name),
            key: const Key('replace-title')),
        content: Text(AppStrings.of(context).changesLost),
        actions: [
          TextButton(
            key: const Key('replace-discard'),
            onPressed: () => choose(SaveChoice.discard),
            child: Text(AppStrings.of(context).dontSave),
          ),
          TextButton(
            key: const Key('replace-cancel'),
            onPressed: () => choose(SaveChoice.cancel),
            child: Text(PlanStrings.of(context).cancel),
          ),
          FilledButton(
            key: const Key('replace-save'),
            autofocus: true,
            onPressed: () => choose(SaveChoice.save),
            child: Text(AppStrings.of(context).save),
          ),
        ],
      ),
    );
  }
}

/// Asks for a file name, starting from [suggested]: the web's save prompt.
/// Null when cancelled; the files object treats a blank name as a cancel
/// and appends `.jetplan`.
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
        title: Text(AppStrings.of(context).saveAsTitle),
        content: TextField(
          key: const Key('name-prompt-field'),
          controller: _name,
          autofocus: true,
          decoration:
              InputDecoration(labelText: AppStrings.of(context).fileName),
          onSubmitted: (_) => _save(),
        ),
        actions: [
          TextButton(
            key: const Key('name-prompt-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(PlanStrings.of(context).cancel),
          ),
          TextButton(
            key: const Key('name-prompt-save'),
            onPressed: _save,
            child: Text(AppStrings.of(context).save),
          ),
        ],
      );
}
