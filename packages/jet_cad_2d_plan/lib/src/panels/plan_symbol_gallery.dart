// Spec P2 "PlanSymbolGallery" (Task 13): the loaded kits' symbols with a
// search over names and tags, categories, retired symbols hidden (R2), an
// optional filter (today's symbolFilter); choosing a symbol arms
// plan.symbol. Ported from jet_cad_floor_plan's symbol_panel.dart (spec
// 09b D7, F-4, F-13; 09c D13).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:jet_cad_2d/jet_cad_2d.dart' show foregroundFor;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';
import '../symbols/gallery_model.dart';
import '../symbols/plan_symbol.dart';
import '../symbols/plan_symbols_state.dart';
import '../symbols/thumbnail_document.dart';
import '../tools/generic_tools.dart' show PlanToolIds;
import 'panel_focus.dart';

/// The gallery of [controller]'s symbols.
///
/// - **Loading:** a progress indicator and the "loading" words (key
///   `symbol-loading`).
/// - **Failed:** the words and a Retry button (key `symbol-retry`) calling
///   `PlanController.retrySymbols`.
/// - **Ready:** the search field (key `symbol-search`; a clear button
///   keyed `symbol-search-clear` while it is not empty), then the
///   [SymbolGallery] over [searchPlanSymbols]. An empty result shows the
///   no-match words (key `symbol-search-empty`) and a Clear button (key
///   `symbol-search-clear-empty`); with no query (a [filter] offering
///   nothing), an empty area.
///
/// **The highlight** is the armed symbol's id while plan.symbol is the
/// active tool. **Enabled** while the permissions offer plan.symbol and
/// the document's engine permissions allow a placement's needs. A tap arms
/// the symbol through `PlanController.armSymbol`.
///
/// **The search text** is [query]'s when given (the caller's, which may
/// outlive this widget, so the text survives a tab switch; never disposed
/// here); else the gallery's own.
class PlanSymbolGallery extends StatefulWidget {
  const PlanSymbolGallery({
    super.key,
    required this.controller,
    this.filter,
    this.query,
  });

  final PlanController controller;

  /// The symbols offered: applied before the search and to a tapped cell;
  /// null offers every (not retired) symbol. Read at each build.
  final bool Function(PlanSymbol symbol)? filter;

  final TextEditingController? query;

  @override
  State<PlanSymbolGallery> createState() => _PlanSymbolGalleryState();
}

class _PlanSymbolGalleryState extends State<PlanSymbolGallery> {
  TextEditingController? _ownQuery;
  TextEditingController? _listening;
  final PanelFieldFocusNode _searchFocus =
      PanelFieldFocusNode(debugLabel: 'symbol-search');

  /// One cell per symbol, by identity, so a rebuild hands the gallery the
  /// same values; cleared when the symbols or the language change.
  final Map<PlanSymbol, GallerySymbol> _cells =
      Map<PlanSymbol, GallerySymbol>.identity();
  final Map<String, PlanSymbol> _byId = <String, PlanSymbol>{};
  List<PlanSymbol>? _indexed;
  PlanSymbolWords _words = PlanSymbolWords.english;

  TextEditingController get _query =>
      widget.query ?? (_ownQuery ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanSymbolGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen();
    if (!identical(oldWidget.controller, widget.controller)) {
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  void _listen() {
    final q = _query;
    if (identical(q, _listening)) return;
    _listening?.removeListener(_onQuery);
    _listening = q;
    q.addListener(_onQuery);
  }

  void _onQuery() => setState(() {});

  @override
  void dispose() {
    _listening?.removeListener(_onQuery);
    _ownQuery?.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handBack() => _searchFocus.handBack();

  void _clear() => _query.clear();

  void _index(List<PlanSymbol> symbols) {
    if (identical(symbols, _indexed)) return;
    _indexed = symbols;
    _cells.clear();
    _byId
      ..clear()
      ..addAll({for (final s in symbols) s.id: s});
  }

  GallerySymbol _cell(PlanSymbol s) => _cells.putIfAbsent(
      s,
      () => GallerySymbol(
            id: s.id,
            label: _words.name(s),
            thumbnailKey: s.id,
            thumbnailDocument: () => symbolThumbnailDocument(s),
          ));

  String? get _selectedId {
    final c = widget.controller;
    final armed = c.armedSymbol.value;
    if (armed == null || c.activeTool.value != PlanToolIds.symbol) {
      return null;
    }
    return armed.id;
  }

  bool get _enabled {
    final c = widget.controller;
    if (!c.permissions.allowsTool(PlanToolIds.symbol)) return false;
    final engine = c.document.commands.permissions;
    return PlanToolIds.symbolNeeds.every(engine.allows);
  }

  void _onSelect(String id) {
    final s = _byId[id];
    if (s == null) return;
    if (widget.filter case final f? when !f(s)) return;
    widget.controller.armSymbol(s);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable:
          Listenable.merge([c, c.symbolsState, c.activeTool, c.armedSymbol]),
      builder: (context, _) => switch (c.symbolsState.value) {
        PlanSymbolsState.loading => const _Loading(),
        PlanSymbolsState.failed =>
          _Failed(onRetry: () => unawaited(c.retrySymbols())),
        PlanSymbolsState.ready => _ready(context),
      },
    );
  }

  Widget _ready(BuildContext context) {
    final c = widget.controller;
    _index(c.symbols);
    final words = PlanSymbolWords(PlanStrings.of(context).languageCode);
    if (words.language != _words.language) {
      _words = words;
      _cells.clear();
    }
    final scheme = Theme.of(context).colorScheme;
    final cellColor = scheme.surfaceContainerLowest;
    final groups =
        searchPlanSymbols(c.symbols, _query.text, words, filter: widget.filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: _searchField(context),
        ),
        Expanded(
          child: groups.isEmpty
              ? (_query.text.trim().isEmpty
                  ? const SizedBox.shrink()
                  : _NoMatch(query: _query.text, onClear: _clear))
              : SymbolGallery(
                  categories: [
                    for (final g in groups)
                      GalleryCategory(
                        id: groupIdOf(g),
                        name: words.category(g.symbols.first),
                        symbols: [for (final s in g.symbols) _cell(s)],
                      ),
                  ],
                  selectedId: _selectedId,
                  enabled: _enabled,
                  onSelect: _onSelect,
                  thumbnails: c.thumbnails,
                  foreground: foregroundFor(cellColor.toARGB32() & 0xFFFFFF),
                  selectedForeground: foregroundFor(
                      scheme.primaryContainer.toARGB32() & 0xFFFFFF),
                  cellColor: cellColor,
                ),
        ),
      ],
    );
  }

  /// The field keeps every typed character, Undo, Redo and Escape from
  /// the bindings above it (`_FieldKeys`); its own nearer Escape hands the
  /// focus back to the canvas, as Enter and a tap outside do (F-4, F-13).
  Widget _searchField(BuildContext context) {
    final strings = PlanStrings.of(context);
    return _FieldKeys(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _handBack,
        },
        child: TextField(
          key: const Key('symbol-search'),
          controller: _query,
          focusNode: _searchFocus,
          maxLines: 1,
          textInputAction: TextInputAction.search,
          onEditingComplete: _handBack,
          onTapOutside: (_) => _handBack(),
          decoration: InputDecoration(
            isDense: true,
            hintText: strings.searchSymbols,
            prefixIcon: const Icon(Icons.search, size: 18),
            border: const OutlineInputBorder(),
            suffixIcon: _query.text.isEmpty
                ? null
                : ExcludeFocus(
                    child: IconButton(
                      key: const Key('symbol-search-clear'),
                      tooltip: strings.clear,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _clear,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Spec 05 D9's guard for this one field: a typed character, Undo
/// (Ctrl/Meta+Z), Redo (Ctrl/Meta+Shift+Z, Ctrl+Y) and Escape stop here as
/// `DoNothingAndStopPropagationTextIntent`, which a focused field answers
/// by taking the key as text; elsewhere no action is found and the key
/// bubbles on.
class _FieldKeys extends StatelessWidget {
  const _FieldKeys({required this.child});

  final Widget child;

  static final Map<ShortcutActivator, Intent> _stop = {
    const _TypingActivator(): const DoNothingAndStopPropagationTextIntent(),
    for (final activator in const [
      SingleActivator(LogicalKeyboardKey.keyZ, control: true),
      SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
      SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
      SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
      SingleActivator(LogicalKeyboardKey.keyY, control: true),
      SingleActivator(LogicalKeyboardKey.escape),
    ])
      activator: const DoNothingAndStopPropagationTextIntent(),
  };

  @override
  Widget build(BuildContext context) =>
      Shortcuts(shortcuts: _stop, child: child);
}

/// A key-down or repeat that types a printable character with neither
/// Control nor Meta held (ported from shortcut_guard.dart:118-138).
class _TypingActivator extends ShortcutActivator {
  const _TypingActivator();

  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is KeyUpEvent) return false;
    final character = event.character;
    if (character == null || character.isEmpty) return false;
    final unit = character.codeUnitAt(0);
    if (unit < 0x20 || unit == 0x7f) return false;
    return !state.isControlPressed && !state.isMetaPressed;
  }

  @override
  String debugDescribeKeys() => 'a key that types a character';
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
            Text(PlanStrings.of(context).loadingSymbols),
          ],
        ),
      );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        key: const Key('symbol-failed'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The words only: the errors are the controller's diagnostics.
              Text(PlanStrings.of(context).symbolsFailed,
                  key: const Key('symbol-failed-text'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ExcludeFocus(
                child: FilledButton.tonal(
                  key: const Key('symbol-retry'),
                  onPressed: onRetry,
                  child: Text(PlanStrings.of(context).retry),
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
              PlanStrings.of(context).noSymbolsMatch(query),
              key: const Key('symbol-search-empty'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ExcludeFocus(
              child: TextButton(
                key: const Key('symbol-search-clear-empty'),
                onPressed: onClear,
                child: Text(PlanStrings.of(context).clear),
              ),
            ),
          ],
        ),
      );
}
