// The library's own symbol gallery body (spec "The gallery (decision 9)"):
// collapsible category headers over two-column grids of thumbnail cells, in
// the shadcn chrome. It keeps the behaviour of the renderer's
// `SymbolGallery` (which stays for its own users): collapse state per group
// id, lazily built cells, thumbnails from the given `SymbolThumbnails`
// (never a cache of its own), the selected cell marked in semantics, cells
// sized by the device pixel ratio, and the thumbnail's ink the foreground
// of its own cell colour.
//
// **It never takes focus** (`ExcludeFocus`, Ruling 05-6): the canvas keeps
// it, so the shell's shortcuts keep working after a click here.
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument, foregroundFor;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SymbolThumbnails, kGalleryThumbnailAspect;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chrome/icon_button.dart' show PlanTooltip;
import '../chrome/shad_scope.dart';

/// One symbol as the grid shows it: [id] is the caller's identity,
/// [thumbnailKey] the value the thumbnail cache compares with `==`, and
/// [thumbnailDocument] builds the small document a thumbnail paints, called
/// only on a cache miss.
@immutable
final class PlanGalleryCell {
  const PlanGalleryCell(
      this.id, this.label, this.thumbnailKey, this.thumbnailDocument);

  final String id;
  final String label;
  final Object thumbnailKey;
  final DraftDocument Function() thumbnailDocument;
}

/// One collapsible group, in the caller's order. [id] keys the header and
/// its collapsed state, so a group shown in another language keeps both.
@immutable
final class PlanGalleryGroup {
  const PlanGalleryGroup(this.id, this.name, this.cells);

  final String id;

  /// The header's text.
  final String name;
  final List<PlanGalleryCell> cells;
}

/// The groups as a scrollable column of collapsible headers over two-column
/// grids. Keys: a header is `symbol-group-<id>`, a cell `symbol-cell-<id>`.
///
/// The cell whose id is [selectedId] reports selected semantics and takes
/// the theme's secondary fill with a primary border. A displayed image is a
/// clone: a cell clones in the completion callback of
/// [SymbolThumbnails.imageFor] and disposes its own clone, so the cache may
/// dispose an evicted image under a live cell.
class PlanGalleryGrid extends StatefulWidget {
  const PlanGalleryGrid({
    super.key,
    required this.groups,
    required this.selectedId,
    required this.enabled,
    required this.onSelect,
    required this.thumbnails,
  });

  final List<PlanGalleryGroup> groups;
  final String? selectedId;

  /// False greys every cell and ignores its taps. Headers still collapse.
  final bool enabled;
  final ValueChanged<String> onSelect;
  final SymbolThumbnails thumbnails;

  @override
  State<PlanGalleryGrid> createState() => _PlanGalleryGridState();
}

class _PlanGalleryGridState extends State<PlanGalleryGrid> {
  final Set<String> _collapsed = <String>{};

  void _toggle(String id) => setState(() {
        if (!_collapsed.remove(id)) _collapsed.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final colours = planShadThemeOf(context).colorScheme;
    return ExcludeFocus(
      child: CustomScrollView(
        slivers: [
          for (final group in widget.groups) ...[
            SliverToBoxAdapter(
              child: _Header(
                key: Key('symbol-group-${group.id}'),
                name: group.name,
                count: group.cells.length,
                collapsed: _collapsed.contains(group.id),
                onTap: () => _toggle(group.id),
              ),
            ),
            if (!_collapsed.contains(group.id))
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final cell = group.cells[i];
                      return _Cell(
                        key: Key('symbol-cell-${cell.id}'),
                        cell: cell,
                        selected: widget.selectedId == cell.id,
                        enabled: widget.enabled,
                        onSelect: widget.onSelect,
                        thumbnails: widget.thumbnails,
                        cellColor: colours.card,
                        selectedColor: colours.secondary,
                        borderColor: colours.primary,
                        labelColor: colours.cardForeground,
                        selectedLabelColor: colours.secondaryForeground,
                        devicePixelRatio: dpr,
                      );
                    },
                    childCount: group.cells.length,
                  ),
                ),
              ),
          ],
        ],
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
    final theme = planShadThemeOf(context);
    return Semantics(
      button: true,
      expanded: !collapsed,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Row(
              children: [
                Icon(
                    collapsed
                        ? LucideIcons.chevronRight
                        : LucideIcons.chevronDown,
                    size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small),
                ),
                Text('$count',
                    style: theme.textTheme.muted.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.cell,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.thumbnails,
    required this.cellColor,
    required this.selectedColor,
    required this.borderColor,
    required this.labelColor,
    required this.selectedLabelColor,
    required this.devicePixelRatio,
  });

  final PlanGalleryCell cell;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final SymbolThumbnails thumbnails;
  final Color cellColor;
  final Color selectedColor;
  final Color borderColor;
  final Color labelColor;
  final Color selectedLabelColor;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    final theme = planShadThemeOf(context);
    final fill = selected ? selectedColor : cellColor;
    // The ink of this cell's own background (dark theme spec D9b).
    final ink = foregroundFor(fill.toARGB32() & 0xFFFFFF);
    void tap() => onSelect(cell.id);
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      label: cell.label,
      onTap: enabled ? tap : null,
      excludeSemantics: true,
      child: PlanTooltip(
        message: cell.label,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? tap : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(6),
                  border: selected
                      ? Border.all(color: borderColor, width: 2)
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                          final size = _fit(constraints.biggest);
                          return Center(
                            child: _Thumbnail(
                              cell: cell,
                              logicalSize: size,
                              devicePixelRatio: devicePixelRatio,
                              foreground: ink,
                              thumbnails: thumbnails,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cell.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.muted.copyWith(
                            fontSize: 11,
                            color: selected ? selectedLabelColor : labelColor),
                      ),
                    ],
                  ),
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
    required this.cell,
    required this.logicalSize,
    required this.devicePixelRatio,
    required this.foreground,
    required this.thumbnails,
  });

  final PlanGalleryCell cell;
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
        old.cell.thumbnailKey != widget.cell.thumbnailKey ||
        old.logicalSize != widget.logicalSize ||
        old.devicePixelRatio != widget.devicePixelRatio ||
        old.foreground != widget.foreground) {
      _requestImage();
    }
  }

  void _requestImage() {
    final request = widget.thumbnails.imageFor(
      key: widget.cell.thumbnailKey,
      document: widget.cell.thumbnailDocument,
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
        // Already disposed by the cache: show the empty cell.
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
