import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

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

class ArchitectureDemoApp extends StatefulWidget {
  const ArchitectureDemoApp(
      {super.key, this.printer = const PrintingPagePrinter()});

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

  /// Marks a file chord handled, and does nothing.
  static void _consume() {}

  @override
  void dispose() {
    _controller.dispose();
    _symbols.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: _navigator,
        title: 'jet-cad',
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
        home: Scaffold(
            body: PlanEditor(controller: _controller, printer: widget.printer)),
      );
}
