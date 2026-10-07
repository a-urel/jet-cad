import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart'
    show floorPlanLocalizationsDelegates, floorPlanSupportedLocales;
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

import 'app_strings.dart';
import 'document_files.dart';
import 'document_host.dart';
import 'exit_guard.dart';

/// The app's symbol libraries, in palette order (spec 14 V-5): the
/// planner's furniture, then the restaurant symbols.
const List<SymbolLibrarySource> kAppSymbolSources = [
  furnitureSymbolSource,
  restaurantSymbolSource,
];

/// The thumbnail cache's size (spec 14 14s risks): every symbol of both
/// libraries (27 + 69) fits at one size and pixel ratio, with room to
/// spare, so scrolling the palette never repaints a thumbnail it showed.
const int kAppThumbnailCapacity = 128;

/// The app's theme seed, for the light and the dark theme alike.
const Color _seed = Color(0xFF2266CC);

Future<void> main() async {
  // The planner's font is registered from the package's bytes before the
  // first document is measured (spec 14 V-11). The pubspec declares the
  // family too; a failed registration is reported, not fatal: the app still
  // starts (review F-4).
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensureFloorPlanFonts();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'floor_planner',
        context: ErrorDescription('while registering the planner font')));
  }
  registerFontLicences();
  runApp(const FloorPlannerApp());
}

/// The app (spec 12a D5, U-4, plan 12a P-3): it owns the [DocumentSession]
/// and the [DocumentFiles], and rebuilds [MaterialApp] from the session, so
/// `onGenerateTitle` -- which runs above `home` and re-runs only when the
/// app rebuilds -- follows the document's name and dirty state (the web
/// tab's title). The [DocumentHost] in `home` runs the flows and builds the
/// shell.
///
/// [files] and [exitGuard] are test seams: the platform's implementations
/// when null.
///
/// Since 09b (spec D2, D5, R-4) the app also owns the symbol library's
/// loader and the thumbnail cache: above the host, because the shell is
/// rebuilt per document and must neither read the asset again nor repaint
/// every thumbnail.
class FloorPlannerApp extends StatefulWidget {
  const FloorPlannerApp(
      {super.key,
      this.files,
      this.createFiles = createDocumentFiles,
      this.exitGuard,
      this.symbols,
      this.thumbnails,
      this.exportFont,
      this.printer = const PrintingPagePrinter()});

  final DocumentFiles? files;

  /// Makes the files when [files] is null: the platform's, a test seam
  /// that sees the prompt and the type names the app hands over.
  final DocumentFiles Function(
      {required DocumentNamePrompt askName,
      required FileTypeLabel typeLabel}) createFiles;

  /// Handed to the [DocumentHost], which owns it (spec 12a D11).
  final ExitGuard? exitGuard;

  /// The symbol library's loader (spec 09b D2), a test seam: when null the
  /// app makes one over the bundled asset and disposes it; a given one is
  /// the caller's to dispose. Either way the app calls `load()` once.
  final SymbolLibraryLoader? symbols;

  /// The symbol thumbnail cache (spec 09b D5), a test seam: when null the
  /// app makes one and disposes it; a given one is the caller's to dispose.
  final SymbolThumbnails? thumbnails;

  /// The export font's bytes, read once per app (spec 13 D7), a test seam:
  /// when null the app makes a cache over the bundled asset.
  final ExportFontCache? exportFont;

  /// Where Print hands the page's PDF (spec 13 D9), a test seam: the
  /// platform's print dialog by default.
  final PagePrinter printer;

  @override
  State<FloorPlannerApp> createState() => _FloorPlannerAppState();
}

class _FloorPlannerAppState extends State<FloorPlannerApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  final DocumentSession _session =
      DocumentSession.untitled(decimalSeparator: launchDecimalSeparator());
  late final DocumentFiles _files = widget.files ??
      widget.createFiles(askName: _askName, typeLabel: _typeLabel);

  /// The loader this app made itself, disposed with it; null when the
  /// caller gave one.
  SymbolLibraryLoader? _ownSymbols;
  late final SymbolLibraryLoader _symbols = widget.symbols ??
      (_ownSymbols = SymbolLibraryLoader(sources: kAppSymbolSources));

  /// The thumbnail cache this app made itself, disposed with it; null when
  /// the caller gave one.
  SymbolThumbnails? _ownThumbnails;
  late final SymbolThumbnails _thumbnails = widget.thumbnails ??
      (_ownThumbnails = SymbolThumbnails(maxEntries: kAppThumbnailCapacity));

  /// The export font (spec 13 D7): above the host, so a document swap never
  /// reads the asset again. Nothing is read until an export asks.
  late final ExportFontCache _exportFont =
      widget.exportFont ?? ExportFontCache();

  /// The web's save-name prompt (spec 12a D9, T-12), shown over the
  /// navigator: the files object is made above the `MaterialApp`, so it
  /// has no `BuildContext` of its own.
  Future<String?> _askName(String suggested) async {
    final context = _navigator.currentContext;
    if (context == null) return null;
    return showDocumentNamePrompt(context, suggested);
  }

  /// A file type's name in the panels, in the app's language (spec 14d
  /// L16), read at each panel: English before the navigator exists.
  String _typeLabel(FileKind kind) {
    final context = _navigator.currentContext;
    return context == null
        ? englishFileTypeLabel(kind)
        : AppStrings.of(context).fileTypeLabel(kind);
  }

  /// Marks a file chord handled, and does nothing.
  static void _consume() {}

  @override
  void initState() {
    super.initState();
    _symbols.load();
  }

  @override
  void dispose() {
    _ownSymbols?.dispose();
    _ownThumbnails?.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_session, _session.dirty]),
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigator,
          onGenerateTitle: (_) =>
              documentTitle(_session.name, dirty: _session.dirty.value),
          debugShowCheckedModeBanner: false,
          // Spec 14d L16: English, German and Turkish, by the system's
          // language; the planner's delegate with Flutter's three.
          supportedLocales: floorPlanSupportedLocales,
          localizationsDelegates: floorPlanLocalizationsDelegates,
          // Dark theme spec D1: the planner follows the host's theme, and
          // the OS picks light or dark.
          theme: ThemeData(colorSchemeSeed: _seed),
          darkTheme:
              ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
          themeMode: ThemeMode.system,
          // Spec 12a D6 (T-3, U-3, R-10): the file chords once more above
          // the Navigator, consume-only. A dialog or a dropdown's route is
          // outside the shell's focus chain, and on web a key nobody
          // handles is not `preventDefault`ed: Cmd/Ctrl+S would open the
          // browser's Save Page. Here the key is marked handled and nothing
          // runs; the shell's own bindings run the commands whenever the
          // home route has the focus, so no flow starts over another route.
          builder: (context, child) => CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              for (final chord in kFileChords) chord: _consume,
            },
            child: child!,
          ),
          home: DocumentHost(
              session: _session,
              files: _files,
              exitGuard: widget.exitGuard,
              symbols: _symbols,
              thumbnails: _thumbnails,
              exportFont: _exportFont,
              printer: widget.printer),
        ),
      );
}
