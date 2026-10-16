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
// * Does `dirty` update synchronously after a command? Yes: the commit path
//   calls `_refreshFlags` (plan_controller.dart :1935), which sets
//   `_dirty` from `commands.stateId != _savedState`. There is no change
//   stream in between, so `_mayDiscard` reads `controller.dirty.value`
//   directly (the old `differsFromSave`).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show buildSampleFlat;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'app_strings.dart';
import 'document_files.dart';
import 'document_session.dart';
import 'exit_guard.dart';

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

  /// The exit guard the host will arm while the plan is dirty (Task 5); the
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
      busy.value = false;
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
  /// Don't Save: yes. Cancel: no. Dirty is read from the controller, which
  /// refreshes it synchronously on every command.
  Future<bool> _mayDiscard() async {
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
        if (file == null) return;
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
        final bytes = await _encode();
        if (bytes == null) return false;
        final fileName = _session.fileName;
        final location = _session.location;
        if (fileName != null) {
          if (!widget.files.writesInPlace) {
            return _write(bytes, location ?? fileName, fileName);
          }
          if (location != null) return _write(bytes, location, fileName);
        }
        return _saveAs(bytes);
      });

  /// Save As: asks where, then writes; false when cancelled or failed.
  Future<bool> saveAsStep() => _flow(() async {
        final bytes = await _encode();
        if (bytes == null) return false;
        return _saveAs(bytes);
      });

  /// The plan's bytes, read in one synchronous block (`save` settles
  /// pending input first and remembers the state it encoded): the save
  /// point is that state, whatever happens while the write is pending. A
  /// throw shows the save error and answers null.
  Future<Uint8List?> _encode() async {
    final String text;
    try {
      text = _controller.save();
    } catch (e) {
      await _showError((w) => w.couldNotSave(_session.name), e);
      return null;
    }
    return Uint8List.fromList(utf8.encode(text));
  }

  Future<bool> _saveAs(Uint8List bytes) async {
    final ({String name, Object location})? place;
    try {
      place = await widget.files.saveLocation('${_session.name}.jetplan');
    } catch (e) {
      await _showError((w) => w.couldNotSave(_session.name), e);
      return false;
    }
    if (place == null) return false;
    return _write(bytes, place.location, place.name);
  }

  /// Writes, then moves the save point to the encoded state and names the
  /// plan after the file; on a failure shows the error and leaves the save
  /// point where it was.
  ///
  /// No guard that the plan is still the one encoded (the old
  /// `identical(document, ...)`): busy keeps New, Open sample and Open from
  /// running during the write (decision 5), so the controller still holds
  /// the plan `save` encoded, and `markSaved` marks the state `save`
  /// encoded -- not the current one -- so an edit made during the write
  /// stays dirty.
  Future<bool> _write(Uint8List bytes, Object location, String fileName) async {
    try {
      await widget.files.write(location, fileName, bytes);
    } catch (e) {
      await _showError((w) => w.couldNotSave(fileName), e);
      return false;
    }
    _controller.markSaved();
    _session.named(fileName, location);
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
            printer: widget.printer,
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
/// dirty, cut with an ellipsis at 240 px.
class _DocumentTitle extends StatelessWidget {
  const _DocumentTitle({required this.session, required this.controller});

  final DocumentSession session;
  final PlanController controller;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
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
