// The Symbols tab (spec 09b D7): the search field over the gallery of the
// bundled library, with the library's loading and failure states.
//
// The shell (Task 9) owns everything passed in: the loader and the thumbnail
// cache (both the app's, R-4), the tool controller, the placement tool, the
// armed symbol, the search field's focus node and, since 09c (D13), its
// text controller. A cell tap only reports
// the entry ([SymbolPanel.onSelect]); arming and activating are the shell's.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'symbol_names.dart';
import '../l10n/strings.dart';
import '../new_document.dart';
import '../panel_focus.dart';
import '../shortcut_guard.dart';
import 'symbol_library.dart';
import 'symbol_library_loader.dart';
import 'symbol_library_state.dart';
import 'symbol_place_tool.dart';
import 'symbol_placer.dart';
import 'symbol_search.dart';

/// The capabilities a placement needs (spec D6); the gallery is enabled only
/// when the document allows all of them (D7).
const List<Capability> kSymbolPlacementNeeds = [
  Capability.structure,
  Capability.geometry,
  Capability.components,
];

/// The gallery's id of [entry]: `"$key@$version"` (spec D4), unambiguous when
/// the library holds one key at two versions.
String symbolIdOf(SymbolEntry entry) => '${entry.key}@${entry.version}';

/// A thumbnail's document (spec D5): the placer's own output, so a thumbnail
/// is what a placement makes. [prepareDocument] registers the app's
/// components (so the `SymbolComponent` is accepted), then [placeSymbol]
/// runs at the definition's base point, no turn, not mirrored: an identity
/// transform.
DraftDocument symbolThumbnailDocument(
    SymbolEntry entry, TextMeasurer measurer) {
  final doc = prepareDocument(measurer);
  // Spec 14a T13 (F-15): a thumbnail shows the symbol, not a table number.
  doc.commands.execute(
      placeSymbol(doc, entry, at: entry.definition.basePoint, numbered: false));
  return doc;
}

/// Spec 09b D7: the Symbols tab.
///
/// - **Loading:** a progress indicator and "Loading symbols…".
/// - **Failed:** the error's message and a Retry button (key
///   `symbol-retry`) calling [SymbolLibraryLoader.retry].
/// - **Ready:** the search field (key `symbol-search`, hint "Search
///   symbols", a clear button keyed `symbol-search-clear` while it is not
///   empty), then the [SymbolGallery] over [searchSymbols]. An empty result
///   shows `No symbols match "<query>"` (key `symbol-search-empty`) and a
///   Clear button (key `symbol-search-clear-empty`).
///
/// **The field's focus follows the page panel's pattern** (F-4, F-13):
/// `ShellShortcutGuard › CallbackShortcuts(Escape → handBack) › TextField(
/// focusNode: searchFocus, onEditingComplete: handBack, onTapOutside:
/// handBack)`. The guard keeps the shell's letters out of the field; the
/// nearer Escape binding hands the focus back to the canvas, which the
/// guard alone would not.
///
/// **The highlight** (the gallery's `selectedId`) is the armed entry's id
/// while [tool] is the active tool of [tools], null otherwise: the panel
/// listens to [tools] and to [armed].
///
/// **Enabled** only when [permissions] allow every capability of
/// [kSymbolPlacementNeeds].
///
/// **The search text** is [query]'s (spec 09c D13): the caller's, which
/// outlives the panel -- the shell removes the panel on its Tools tab -- so
/// the text survives a tab switch. The panel listens to it while mounted and
/// never disposes it.
class SymbolPanel extends StatefulWidget {
  const SymbolPanel({
    super.key,
    required this.loader,
    required this.thumbnails,
    required this.tools,
    required this.tool,
    required this.armed,
    required this.permissions,
    required this.searchFocus,
    required this.query,
    required this.onSelect,
    this.measurer = const InsertionPointMeasurer(),
  });

  final SymbolLibraryLoader loader;
  final SymbolThumbnails thumbnails;
  final ToolController tools;
  final SymbolPlaceTool tool;
  final ValueNotifier<SymbolEntry?> armed;
  final DraftPermissions permissions;
  final PanelFieldFocusNode searchFocus;

  /// The search field's text (spec 09c D13): the caller's, never disposed
  /// here.
  final TextEditingController query;

  /// A cell tap, with its entry. The shell arms the tool and activates it.
  final void Function(SymbolEntry entry) onSelect;

  /// The thumbnail documents' measurer. A symbol holds no text, so the
  /// default (no font stack) paints the same thumbnail as any other.
  final TextMeasurer measurer;

  @override
  State<SymbolPanel> createState() => _SymbolPanelState();
}

class _SymbolPanelState extends State<SymbolPanel> {
  TextEditingController get _query => widget.query;

  /// One [GallerySymbol] per entry of the loaded library, by identity, so a
  /// rebuild hands the gallery the same values.
  final Map<SymbolEntry, GallerySymbol> _gallerySymbols =
      Map<SymbolEntry, GallerySymbol>.identity();

  /// The entries by gallery id, for [SymbolPanel.onSelect].
  final Map<String, SymbolEntry> _byId = <String, SymbolEntry>{};

  SymbolLibrary? _indexed;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQuery);
  }

  void _onQuery() => setState(() {});

  @override
  void didUpdateWidget(SymbolPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.query, widget.query)) return;
    oldWidget.query.removeListener(_onQuery);
    widget.query.addListener(_onQuery);
  }

  @override
  void dispose() {
    // The caller's: only the panel's own listener goes (D13).
    _query.removeListener(_onQuery);
    super.dispose();
  }

  void _handBack() => widget.searchFocus.handBack();

  void _clear() => _query.clear();

  /// The palette's names (spec 14d L9): the cells are rebuilt when the
  /// language changes.
  SymbolWords _words = SymbolWords.english;

  GallerySymbol _gallerySymbol(SymbolEntry entry) =>
      _gallerySymbols.putIfAbsent(entry, () {
        final id = symbolIdOf(entry);
        return GallerySymbol(
          id: id,
          label: _words.name(entry),
          thumbnailKey: id,
          thumbnailDocument: () =>
              symbolThumbnailDocument(entry, widget.measurer),
        );
      });

  void _index(SymbolLibrary library) {
    if (identical(library, _indexed)) return;
    _indexed = library;
    _gallerySymbols.clear();
    _byId
      ..clear()
      ..addAll({for (final e in library.entries) symbolIdOf(e): e});
  }

  String? get _selectedId {
    final entry = widget.armed.value;
    if (entry == null || !identical(widget.tools.active, widget.tool)) {
      return null;
    }
    return symbolIdOf(entry);
  }

  bool get _enabled => kSymbolPlacementNeeds.every(widget.permissions.allows);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable:
            Listenable.merge([widget.loader, widget.tools, widget.armed]),
        builder: (context, _) => switch (widget.loader.state) {
          SymbolLibraryLoading() => const _Loading(),
          SymbolLibraryFailed(:final error) =>
            _Failed(error: error, onRetry: widget.loader.retry),
          SymbolLibraryReady(:final library) => _ready(context, library),
        },
      );

  Widget _ready(BuildContext context, SymbolLibrary library) {
    _index(library);
    final words = SymbolWords(
        widget.loader.names, FloorPlanStrings.of(context).languageCode);
    if (words.language != _words.language ||
        !identical(words.names, _words.names)) {
      _words = words;
      _gallerySymbols.clear();
    }
    final scheme = Theme.of(context).colorScheme;
    final cellColor = scheme.surfaceContainerLowest;
    final groups = searchSymbols(library.entries, _query.text, words);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: _searchField(),
        ),
        Expanded(
          child: groups.isEmpty
              ? _NoMatch(query: _query.text, onClear: _clear)
              : SymbolGallery(
                  categories: [
                    for (final g in groups)
                      GalleryCategory(
                        id: g.category,
                        name: words.category(g.category),
                        symbols: [for (final e in g.symbols) _gallerySymbol(e)],
                      ),
                  ],
                  selectedId: _selectedId,
                  enabled: _enabled,
                  onSelect: (id) {
                    final entry = _byId[id];
                    if (entry != null) widget.onSelect(entry);
                  },
                  thumbnails: widget.thumbnails,
                  foreground: foregroundFor(cellColor.toARGB32() & 0xFFFFFF),
                  cellColor: cellColor,
                ),
        ),
      ],
    );
  }

  Widget _searchField() => ShellShortcutGuard(
        // Nearer than the guard's own Escape (F-13, the text entry's
        // pattern): Escape in the field hands the focus back.
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): _handBack,
          },
          child: TextField(
            key: const Key('symbol-search'),
            controller: _query,
            focusNode: widget.searchFocus,
            maxLines: 1,
            textInputAction: TextInputAction.search,
            // Enter and a tap outside hand the focus back to the canvas
            // (F-4): a plain unfocus would leave it on the route's scope,
            // where no key reaches the shell.
            onEditingComplete: _handBack,
            onTapOutside: (_) => _handBack(),
            decoration: InputDecoration(
              isDense: true,
              hintText: FloorPlanStrings.of(context).searchSymbols,
              prefixIcon: const Icon(Icons.search, size: 18),
              border: const OutlineInputBorder(),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : ExcludeFocus(
                      child: IconButton(
                        key: const Key('symbol-search-clear'),
                        tooltip: FloorPlanStrings.of(context).clear,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clear,
                      ),
                    ),
            ),
          ),
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
        key: const Key('symbol-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 8),
            Text(FloorPlanStrings.of(context).loadingSymbols),
          ],
        ),
      );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        key: const Key('symbol-failed'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The words only (spec 14d I-4, V-17): the loader logs the
              // error itself.
              Text(FloorPlanStrings.of(context).symbolsFailed,
                  key: const Key('symbol-failed-text'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              // Ruling 05-6: a panel button never takes the canvas's focus.
              ExcludeFocus(
                child: FilledButton.tonal(
                  key: const Key('symbol-retry'),
                  onPressed: onRetry,
                  child: Text(FloorPlanStrings.of(context).retry),
                ),
              ),
            ],
          ),
        ),
      );
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              FloorPlanStrings.of(context).noSymbolsMatch(query),
              key: const Key('symbol-search-empty'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ExcludeFocus(
              child: TextButton(
                key: const Key('symbol-search-clear-empty'),
                onPressed: onClear,
                child: Text(FloorPlanStrings.of(context).clear),
              ),
            ),
          ],
        ),
      );
}
