import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'symbol_thumbnails.dart';

/// One symbol as the gallery shows it.
///
/// The gallery knows no symbol type of its own: [id] is the caller's
/// identity (the app's is `"$key@$version"`), [thumbnailKey] the value the
/// thumbnail cache compares with `==`, and [thumbnailDocument] builds the
/// small document a thumbnail paints, called only on a cache miss.
@immutable
final class GallerySymbol {
  const GallerySymbol({
    required this.id,
    required this.label,
    required this.thumbnailKey,
    required this.thumbnailDocument,
  });

  final String id;
  final String label;
  final Object thumbnailKey;
  final DraftDocument Function() thumbnailDocument;
}

/// One collapsible group of the gallery, in the caller's order.
@immutable
final class GalleryCategory {
  const GalleryCategory({required this.name, required this.symbols});

  final String name;
  final List<GallerySymbol> symbols;
}

/// The logical width-to-height ratio of a cell's thumbnail.
const double kGalleryThumbnailAspect = 4 / 3;

/// Spec 09b D4: the symbols, grouped by category, as a scrollable column of
/// collapsible headers over two-column grids of thumbnail cells.
///
/// It holds **no text field and no search state** (R-1): the caller filters
/// and passes the result. The collapsed set is widget state, not persisted.
///
/// **It never takes focus** (`ExcludeFocus`, Ruling 05-6): the canvas keeps
/// it, so the shell's shortcuts keep working after a click here.
///
/// Keys: a header is `symbol-group-<name>`, a cell `symbol-cell-<id>`.
///
/// **The highlight** of the cell whose id is [selectedId] is observable
/// without a golden: the cell's semantics carry `selected: true` (its
/// `SemanticsFlag.isSelected`), and its `Material` takes the colour scheme's
/// `primaryContainer` instead of [cellColor], with a `primary` border. Both
/// come from the one `selected` value per cell.
///
/// **A displayed image is a clone**: a cell takes `image.clone()` in the
/// completion callback of [SymbolThumbnails.imageFor] and disposes its own
/// clone when it is disposed or its image changes, so the cache may dispose
/// an evicted image under a live cell.
class SymbolGallery extends StatefulWidget {
  const SymbolGallery({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.enabled,
    required this.onSelect,
    required this.thumbnails,
    required this.foreground,
    required this.cellColor,
  });

  final List<GalleryCategory> categories;

  /// The highlighted cell's id, or null for none.
  final String? selectedId;

  /// False greys every cell and ignores its taps. Headers still collapse.
  final bool enabled;

  final void Function(String id) onSelect;
  final SymbolThumbnails thumbnails;

  /// The thumbnails' ACI 7 colour (`0xRRGGBB`), e.g.
  /// `foregroundFor(cellColor.toARGB32())` (spec F-8).
  final int foreground;

  /// A cell's background when it is not selected.
  final Color cellColor;

  @override
  State<SymbolGallery> createState() => _SymbolGalleryState();
}

class _SymbolGalleryState extends State<SymbolGallery> {
  final Set<String> _collapsed = <String>{};

  void _toggle(String name) => setState(() {
        if (!_collapsed.remove(name)) _collapsed.add(name);
      });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ExcludeFocus(
      // Like the tool palette: the panel paints its own background, so the
      // headers need a `Material` of their own to paint their ink on.
      child: Material(
        color: Colors.transparent,
        child: CustomScrollView(
          slivers: [
            for (final category in widget.categories) ...[
              SliverToBoxAdapter(
                child: _Header(
                  key: Key('symbol-group-${category.name}'),
                  name: category.name,
                  count: category.symbols.length,
                  collapsed: _collapsed.contains(category.name),
                  onTap: () => _toggle(category.name),
                ),
              ),
              if (!_collapsed.contains(category.name))
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.95,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final symbol = category.symbols[i];
                        return _Cell(
                          key: Key('symbol-cell-${symbol.id}'),
                          symbol: symbol,
                          selected: widget.selectedId == symbol.id,
                          enabled: widget.enabled,
                          onSelect: widget.onSelect,
                          thumbnails: widget.thumbnails,
                          foreground: widget.foreground,
                          cellColor: widget.cellColor,
                          devicePixelRatio: dpr,
                        );
                      },
                      childCount: category.symbols.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    super.key,
    required this.name,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Row(
          children: [
            Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall),
            ),
            Text('$count', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.symbol,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.thumbnails,
    required this.foreground,
    required this.cellColor,
    required this.devicePixelRatio,
  });

  final GallerySymbol symbol;
  final bool selected;
  final bool enabled;
  final void Function(String id) onSelect;
  final SymbolThumbnails thumbnails;
  final int foreground;
  final Color cellColor;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Tooltip(
        message: symbol.label,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Material(
            color: selected ? scheme.primaryContainer : cellColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: selected
                  ? BorderSide(color: scheme.primary, width: 2)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? () => onSelect(symbol.id) : null,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        final size = _fit(constraints.biggest);
                        return Center(
                          child: _Thumbnail(
                            symbol: symbol,
                            logicalSize: size,
                            devicePixelRatio: devicePixelRatio,
                            foreground: foreground,
                            thumbnails: thumbnails,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      symbol.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The largest [kGalleryThumbnailAspect] box inside [space], in whole
  /// logical pixels so a cache key stays stable across sub-pixel layouts.
  static Size _fit(Size space) {
    var w = space.width;
    var h = w / kGalleryThumbnailAspect;
    if (h > space.height) {
      h = space.height;
      w = h * kGalleryThumbnailAspect;
    }
    return Size(w.floorToDouble().clamp(1, double.infinity),
        h.floorToDouble().clamp(1, double.infinity));
  }
}

/// A cell's thumbnail: requests the image, shows its own clone of it.
class _Thumbnail extends StatefulWidget {
  const _Thumbnail({
    required this.symbol,
    required this.logicalSize,
    required this.devicePixelRatio,
    required this.foreground,
    required this.thumbnails,
  });

  final GallerySymbol symbol;
  final Size logicalSize;
  final double devicePixelRatio;
  final int foreground;
  final SymbolThumbnails thumbnails;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  /// This cell's own clone; the cache's image is never held.
  ui.Image? _image;

  /// The pending request; a completion for any other is dropped.
  Future<ui.Image>? _request;

  @override
  void initState() {
    super.initState();
    _requestImage();
  }

  @override
  void didUpdateWidget(_Thumbnail old) {
    super.didUpdateWidget(old);
    if (!identical(old.thumbnails, widget.thumbnails) ||
        old.symbol.thumbnailKey != widget.symbol.thumbnailKey ||
        old.logicalSize != widget.logicalSize ||
        old.devicePixelRatio != widget.devicePixelRatio ||
        old.foreground != widget.foreground) {
      _requestImage();
    }
  }

  void _requestImage() {
    final request = widget.thumbnails.imageFor(
      key: widget.symbol.thumbnailKey,
      document: widget.symbol.thumbnailDocument,
      logicalSize: widget.logicalSize,
      devicePixelRatio: widget.devicePixelRatio,
      foreground: widget.foreground,
    );
    _request = request;
    request.then((image) {
      if (!mounted || !identical(_request, request)) return;
      // Cloned in the completion callback, as the cache requires: an entry
      // evicted while pending disposes its image one microtask later.
      ui.Image? clone;
      try {
        clone = image.clone();
      } on StateError {
        // Already disposed by the cache (evicted between completion and this
        // callback): show the empty cell rather than throw into the tree.
        clone = null;
      }
      setState(() => _replace(clone));
    }, onError: (Object _, StackTrace __) {
      // A failed paint shows an empty cell with the label (spec D5).
      if (!mounted || !identical(_request, request)) return;
      setState(() => _replace(null));
    });
  }

  void _replace(ui.Image? image) {
    _image?.dispose();
    _image = image;
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        size: widget.logicalSize,
        child: RawImage(
          image: _image,
          width: widget.logicalSize.width,
          height: widget.logicalSize.height,
          scale: widget.devicePixelRatio,
        ),
      );
}
