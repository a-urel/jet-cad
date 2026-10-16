import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'app_strings.dart';
import 'document_files.dart';
import 'document_host.dart';
import 'document_session.dart';
import 'exit_guard.dart';

/// The app's theme seed, light and dark alike (the old app's).
const Color kAppSeed = Color(0xFF2266CC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensurePlanFonts();
  } catch (error, stack) {
    // A failed registration is reported, not fatal: the app still starts.
    FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'architecture_demo',
        context: ErrorDescription('while registering the plan font')));
  }
  registerFontLicences();
  runApp(const ArchitectureDemoApp());
}

/// The app: it owns the one [PlanController], the [DocumentSession] and the
/// [DocumentFiles], and rebuilds [MaterialApp] from the session and the
/// controller's dirty flag, so `onGenerateTitle` -- which runs above `home`
/// and re-runs only when the app rebuilds -- follows the plan's name and
/// dirty state (the web tab's title). The [DocumentHost] in `home` runs the
/// flows and builds the editor.
class ArchitectureDemoApp extends StatefulWidget {
  const ArchitectureDemoApp(
      {super.key,
      this.files,
      this.createFiles = createDocumentFiles,
      this.exitGuard,
      this.printer = const PrintingPagePrinter()});

  /// The files, a test seam: when null the app makes the platform's through
  /// [createFiles].
  final DocumentFiles? files;

  /// Makes the files when [files] is null: the platform's, a test seam that
  /// sees the prompt and the type names the app hands over.
  final DocumentFiles Function(
      {required DocumentNamePrompt askName,
      required FileTypeLabel typeLabel}) createFiles;

  /// Handed to the [DocumentHost] (armed while the plan is dirty, Task 5).
  final ExitGuard? exitGuard;

  /// Where Print hands the page's PDF: the platform's dialog unless a test
  /// gives a fake.
  final PagePrinter printer;

  @override
  State<ArchitectureDemoApp> createState() => ArchitectureDemoAppState();
}

class ArchitectureDemoAppState extends State<ArchitectureDemoApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// The symbol loader is given to the controller, which never disposes a
  /// loader it was given, so this state does, after the controller.
  final PlanSymbolLoader _symbols = PlanSymbolLoader();

  /// The app's one controller: New, Open sample and Open replace the plan
  /// inside it, so the editor, its panels and its caches stay.
  late final PlanController _controller =
      PlanController(kits: [architectureKit], symbols: _symbols);

  @visibleForTesting
  PlanController get controller => _controller;

  final DocumentSession _session = DocumentSession();
  late final DocumentFiles _files = widget.files ??
      widget.createFiles(askName: _askName, typeLabel: _typeLabel);

  @visibleForTesting
  DocumentSession get session => _session;

  /// The web's save-name prompt, shown over the navigator: the files object
  /// is made above the `MaterialApp`, so it has no `BuildContext` of its
  /// own.
  Future<String?> _askName(String suggested) async {
    final context = _navigator.currentContext;
    if (context == null) return null;
    return showDocumentNamePrompt(context, suggested);
  }

  /// A file type's name in the panels, in the app's language, read at each
  /// panel: English before the navigator exists.
  String _typeLabel(FileKind kind) {
    final context = _navigator.currentContext;
    return context == null
        ? englishFileTypeLabel(kind)
        : AppStrings.of(context).fileTypeLabel(kind);
  }

  /// Marks a file chord handled, and does nothing.
  static void _consume() {}

  @override
  void dispose() {
    _controller.dispose();
    _symbols.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_session, _controller.dirty]),
        builder: (context, _) => _app(),
      );

  Widget _app() => MaterialApp(
        navigatorKey: _navigator,
        onGenerateTitle: (_) =>
            documentTitle(_session.name, dirty: _controller.dirty.value),
        debugShowCheckedModeBanner: false,
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        theme: ThemeData(colorSchemeSeed: kAppSeed),
        darkTheme:
            ThemeData(colorSchemeSeed: kAppSeed, brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        // The file chords once more above the Navigator, consume-only: a
        // dialog's route is outside the editor's focus chain, and on the
        // web an unhandled Cmd/Ctrl+S opens the browser's Save Page. The
        // editor's own bindings run the commands when the home route has
        // the focus.
        builder: (context, child) => CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            for (final chord in kFileChords) chord: _consume,
          },
          child: child!,
        ),
        home: DocumentHost(
            controller: _controller,
            session: _session,
            files: _files,
            exitGuard: widget.exitGuard,
            printer: widget.printer),
      );
}
