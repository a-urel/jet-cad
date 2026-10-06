// Dark theme spec D9b, D9c, D9d, R-3 (plan Task 6): the planner's widgets
// follow the theme. A symbol cell's thumbnail takes the ink of its own
// background (M-DT-15, M-DT-16); a live switch reaches the symbol cells and
// the page swatches (M-DT-17); the layer swatch keeps its outline on a dark
// panel (M-DT-18); and every panel paints under the dark theme (the sweep).
//
// The real shell, the real bundled library and the real thumbnail cache,
// under the floor planner's seed (support/palette_fixture.dart), read back
// in pixels at device pixel ratio 1. M-DT-15 alone overrides the dark
// scheme's `primaryContainer` with a light colour: under the real seed both
// cell backgrounds take white ink and that mutant is invisible (F-18).
//
// Thumbnails are images painted through engine callbacks the fake-async
// zone never delivers: every wait for one runs under `tester.runAsync`,
// then a pump delivers the cells' callbacks (the gallery tests' pattern).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/document_toolbar.dart';
import 'package:jet_cad_floor_plan/src/export/export_dialog.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_loader.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_state.dart';
import 'package:jet_cad_floor_plan/src/text_entry_overlay.dart'
    show kTextEntrySize;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'host/status_caption_test.dart' show pumpService, statusController;
import 'support/palette_fixture.dart';

final Uint8List assetBytes =
    File('assets/library/furniture.jetlib').readAsBytesSync();

/// The thumbnail cache, recording every future it hands out.
class RecordingThumbnails extends SymbolThumbnails {
  final List<Future<ui.Image>> requests = [];

  @override
  Future<ui.Image> imageFor({
    required Object key,
    required DraftDocument Function() document,
    required ui.Size logicalSize,
    required double devicePixelRatio,
    required int foreground,
  }) {
    final f = super.imageFor(
        key: key,
        document: document,
        logicalSize: logicalSize,
        devicePixelRatio: devicePixelRatio,
        foreground: foreground);
    requests.add(f);
    return f;
  }

  /// Waits, in real time, for every request so far, errors included.
  Future<void> settle() => Future.wait([
        for (final r in requests) r.then((_) {}, onError: (Object _) {}),
      ]);
}

/// The planner under test: its document, its symbol loader and its
/// thumbnail cache, all torn down after the test.
final class Planner {
  Planner(this.tester, {int? paper = white}) {
    f = paletteDoc(measurer, paper: paper);
    addTearDown(() {
      f.doc.dispose();
      measurer.clear();
      loader.dispose();
      thumbnails.dispose();
    });
  }

  final WidgetTester tester;
  final FlutterTextMeasurer measurer = FlutterTextMeasurer();
  final SymbolLibraryLoader loader =
      SymbolLibraryLoader(read: () async => assetBytes);
  final RecordingThumbnails thumbnails = RecordingThumbnails();
  late final ({DraftDocument doc, Handle selected, Handle ink}) f;

  /// Pumps the shell under [light] and [dark] in [mode], at zero theme
  /// animation, the whole navigator inside the capture boundary. Pumping again with another
  /// [mode] keeps every state below: the tree has the same shape.
  Future<void> pump(ThemeMode mode, {ThemeData? light, ThemeData? dark}) async {
    if (loader.state is! SymbolLibraryReady) {
      await tester.runAsync(loader.load);
    }
    await tester.pumpWidget(MaterialApp(
      theme: light ?? lightTheme,
      darkTheme: dark ?? darkTheme,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      // Around the navigator, so a shot holds the menus and dialogs too.
      builder: (_, child) => RepaintBoundary(key: shotKey, child: child),
      home: PlannerShell(
          document: f.doc, symbols: loader, thumbnails: thumbnails),
    ));
    await tester.pump();
  }

  /// Lets every pending thumbnail complete and delivers the cells'
  /// callbacks, until no new request appears.
  Future<void> settleImages() async {
    var seen = -1;
    while (seen != thumbnails.requests.length) {
      seen = thumbnails.requests.length;
      await tester.runAsync(thumbnails.settle);
      await tester.pump();
    }
  }

  Future<void> openSymbols() async {
    await tester.tap(find.byKey(const Key('tab-symbols')));
    await tester.pump();
    await settleImages();
  }

  SymbolGallery get gallery =>
      tester.widget<SymbolGallery>(find.byType(SymbolGallery));

  /// The first category's first [n] cell ids, in gallery order.
  List<String> firstIds(int n) =>
      gallery.categories.first.symbols.take(n).map((s) => s.id).toList();
}

Finder cell(String id) => find.byKey(Key('symbol-cell-$id'));

/// The cell's background, as its `Material` paints it.
Color cellColour(WidgetTester tester, String id) => tester
    .widget<Material>(
        find.descendant(of: cell(id), matching: find.byType(Material)).first)
    .color!;

int _maxChannel(int rgb) =>
    math.max((rgb >> 16) & 0xFF, math.max((rgb >> 8) & 0xFF, rgb & 0xFF));
int _minChannel(int rgb) =>
    math.min((rgb >> 16) & 0xFF, math.min((rgb >> 8) & 0xFF, rgb & 0xFF));

/// WCAG 2 relative luminance of `0xRRGGBB`, written out here so the oracle
/// shares nothing with production code.
double luminance(int rgb) {
  double channel(int shift) {
    final c = ((rgb >> shift) & 0xFF) / 255.0;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/// WCAG 2 contrast ratio, lighter over darker.
double contrast(int a, int b) {
  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The ink of a cell's thumbnail as the screen shows it: the darkest and
/// the brightest pixel of the thumbnail's centre (its middle half each
/// way), where the symbol's leaves lie. The thumbnail is a transparent
/// image, so every pixel there is the cell's background or a leaf.
({int darkest, int brightest}) centreLeaf(
    WidgetTester tester, Shot shot, String id) {
  final r = tester
      .getRect(find.descendant(of: cell(id), matching: find.byType(RawImage)));
  final c = Rect.fromCenter(
      center: r.center, width: r.width / 2, height: r.height / 2);
  var darkest = 0xFFFFFF, brightest = 0x000000;
  for (var y = c.top.ceil(); y < c.bottom.floor(); y++) {
    for (var x = c.left.ceil(); x < c.right.floor(); x++) {
      final p = shot.rgbAt(x, y);
      if (_maxChannel(p) < _maxChannel(darkest)) darkest = p;
      if (_minChannel(p) > _minChannel(brightest)) brightest = p;
    }
  }
  return (darkest: darkest, brightest: brightest);
}

/// The border of the page panel's swatch [i].
Border swatchBorder(WidgetTester tester, int i) {
  final box = tester.widget<Container>(find
      .descendant(
          of: find.byKey(Key('page-swatch-$i')),
          matching: find.byType(Container))
      .first);
  return (box.decoration! as BoxDecoration).border! as Border;
}

/// The page swatches' borders are [scheme]'s: primary on the selected one
/// (White, swatch 0, the fixture's paper), outline on the others.
void expectSwatches(WidgetTester tester, ColorScheme scheme, String reason) {
  for (var i = 0; i < 4; i++) {
    expect(swatchBorder(tester, i).top.color,
        i == 0 ? scheme.primary : scheme.outline,
        reason: '$reason: page swatch $i');
  }
}

/// The 16 px swatch box (`_Swatch`) under [of], found by its rounded
/// corners and not by its border, so a swatch without one is still found.
Finder swatchUnder(Finder of) => find.descendant(
    of: of,
    matching: find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).borderRadius ==
            BorderRadius.circular(3)));

void main() {
  test(
      'premise: the overridden primaryContainer takes black ink, the dark '
      "seed's cell colour white; under the real dark seed both take white "
      '(F-18), under the light seed both black', () {
    final scheme = mdt15Scheme();
    expect(foregroundFor(0xD8E2FF), 0x000000);
    expect(rgbOf(scheme.primaryContainer), 0xD8E2FF);
    expect(foregroundFor(rgbOf(scheme.surfaceContainerLowest)), 0xFFFFFF);
    final dark = darkTheme.colorScheme, light = lightTheme.colorScheme;
    expect(foregroundFor(rgbOf(dark.surfaceContainerLowest)), 0xFFFFFF);
    expect(foregroundFor(rgbOf(dark.primaryContainer)), 0xFFFFFF);
    expect(foregroundFor(rgbOf(light.surfaceContainerLowest)), 0x000000);
    expect(foregroundFor(rgbOf(light.primaryContainer)), 0x000000);
  });

  testWidgets(
      'M-DT-15: a dark scheme whose primaryContainer is light: the selected '
      "cell's centre leaf is dark (at least 3:1 on 0xD8E2FF), an unselected "
      "cell's leaf light (D9b)", (tester) async {
    windowAt(tester, const Size(1440, 900));
    final p = Planner(tester);
    await p.pump(ThemeMode.dark, dark: ThemeData(colorScheme: mdt15Scheme()));
    await p.openSymbols();
    final [chosen, other] = p.firstIds(2);
    await tester.tap(cell(chosen));
    await tester.pump();
    await p.settleImages();
    expect(cellColour(tester, chosen), const Color(0xFFD8E2FF),
        reason: 'premise: the tapped cell is the selected one');
    expect(cellColour(tester, other), mdt15Scheme().surfaceContainerLowest);

    final shot = await shoot(tester);
    final selected = centreLeaf(tester, shot, chosen);
    expect(contrast(selected.darkest, 0xD8E2FF), greaterThanOrEqualTo(3),
        reason: 'selected leaf darkest ${hex(selected.darkest)}');
    final unselected = centreLeaf(tester, shot, other);
    expect(_minChannel(unselected.brightest), greaterThan(200),
        reason: 'unselected leaf brightest ${hex(unselected.brightest)}');
    // What the panel handed the gallery, after the pixels.
    expect(p.gallery.selectedForeground, 0x000000);
    expect(p.gallery.foreground, 0xFFFFFF);
  });

  for (final (mode, name) in [
    (ThemeMode.dark, 'dark theme'),
    (ThemeMode.light, 'light theme (the control)'),
  ]) {
    testWidgets(
        "M-DT-16, $name: an unselected cell's centre leaf is "
        "${mode == ThemeMode.dark ? 'light' : 'dark'}, and so is the "
        "selected cell's (D9b)", (tester) async {
      windowAt(tester, const Size(1440, 900));
      final p = Planner(tester);
      await p.pump(mode);
      await p.openSymbols();
      final [chosen, other] = p.firstIds(2);
      await tester.tap(cell(chosen));
      await tester.pump();
      await p.settleImages();
      final scheme =
          (mode == ThemeMode.dark ? darkTheme : lightTheme).colorScheme;
      expect(cellColour(tester, chosen), scheme.primaryContainer,
          reason: 'premise: the tapped cell is the selected one');
      final shot = await shoot(tester);
      for (final id in [other, chosen]) {
        final leaf = centreLeaf(tester, shot, id);
        if (mode == ThemeMode.dark) {
          expect(_minChannel(leaf.brightest), greaterThan(200),
              reason: '$id: leaf brightest ${hex(leaf.brightest)}');
        } else {
          expect(_maxChannel(leaf.darkest), lessThan(60),
              reason: '$id: leaf darkest ${hex(leaf.darkest)}');
        }
      }
    });
  }

  testWidgets(
      'M-DT-17: a live switch from light to dark (zero animation): the '
      "symbol cells' colour, their leaves and the page swatches' borders "
      'follow the dark scheme, and back (D9d)', (tester) async {
    windowAt(tester, const Size(1440, 900));
    final p = Planner(tester);
    await p.pump(ThemeMode.light);
    await p.openSymbols();
    final [id] = p.firstIds(1);
    final light = lightTheme.colorScheme, dark = darkTheme.colorScheme;
    expect(light.surfaceContainerLowest, isNot(dark.surfaceContainerLowest));
    expect(cellColour(tester, id), light.surfaceContainerLowest);
    expectSwatches(tester, light, 'light');
    var leaf = centreLeaf(tester, await shoot(tester), id);
    expect(_maxChannel(leaf.darkest), lessThan(60),
        reason: 'light: leaf darkest ${hex(leaf.darkest)}');

    await p.pump(ThemeMode.dark);
    await p.settleImages();
    expect(cellColour(tester, id), dark.surfaceContainerLowest,
        reason: 'after the switch to dark: the cell colour');
    expectSwatches(tester, dark, 'after the switch to dark');
    leaf = centreLeaf(tester, await shoot(tester), id);
    expect(_minChannel(leaf.brightest), greaterThan(200),
        reason: 'after the switch to dark: leaf brightest '
            '${hex(leaf.brightest)}');

    await p.pump(ThemeMode.light);
    await p.settleImages();
    expect(cellColour(tester, id), light.surfaceContainerLowest);
    expectSwatches(tester, light, 'back to light');
  });

  for (final (mode, theme) in [
    (ThemeMode.dark, darkTheme),
    (ThemeMode.light, lightTheme),
  ]) {
    testWidgets(
        'M-DT-18, ${mode.name} theme on White paper: the layer row\'s '
        '"Foreground" swatch and the colour menu\'s show the canvas\'s ink '
        '(black in the light theme; white in the dark one, which shows White '
        'dark, dark canvas K1) inside a scheme.outline border (D9c)',
        (tester) async {
      windowAt(tester, const Size(1440, 900));
      final p = Planner(tester);
      await p.pump(mode);
      final outline = rgbOf(theme.colorScheme.outline);
      final ink = mode == ThemeMode.dark ? 0xFFFFFF : 0x000000;
      expect(channelDistance(outline, ink), greaterThan(60),
          reason: 'premise: the outline is not the ink');

      Future<void> expectSwatch(Finder box, String reason) async {
        final r = tester.getRect(box);
        expect(r.size, const Size(16, 16), reason: reason);
        expect(r.left, r.left.roundToDouble(), reason: '$reason: whole px');
        final shot = await shoot(tester);
        final y = r.center.dy.floor();
        final left = r.left.round(), right = r.right.round() - 1;
        expect(hex(shot.rgbAt(left, y)), hex(outline),
            reason: '$reason: left border');
        expect(hex(shot.rgbAt(right, y)), hex(outline),
            reason: '$reason: right border');
        expect(hex(shot.rgbAt(r.center.dx.floor(), y)), hex(ink),
            reason: '$reason: the swatch shows the canvas\'s ink');
      }

      // Layer 0 (handle 1) is ACI 7, drawn in the paper's foreground.
      final button = find.byKey(const Key('layer-colour-1'));
      await expectSwatch(swatchUnder(button), 'layer 0 row');
      await tester.tap(button);
      await tester.pumpAndSettle();
      final item = find.byKey(const Key('layer-colour-item-7'));
      expect(find.descendant(of: item, matching: find.text('Foreground')),
          findsOneWidget);
      await expectSwatch(swatchUnder(item), 'the menu\'s Foreground item');
    });
  }

  group(
      'the panel sweep (smoke): under the dark theme every panel paints '
      'without an exception', () {
    testWidgets(
        'the shell: tool palette, toolbar, status line, layer panel and its '
        'menu, selection panel and its layer picker, page panel, symbol '
        'panel and its search, text entry and the export dialog',
        (tester) async {
      windowAt(tester, const Size(1440, 900));
      final p = Planner(tester);
      await p.pump(ThemeMode.dark);
      final scheme = darkTheme.colorScheme;
      Future<void> painted(String step) async {
        await shoot(tester);
        expect(tester.takeException(), isNull, reason: step);
      }

      expect(find.byKey(const Key('tool-fill')), findsOneWidget);
      expect(find.byType(DocumentToolbar), findsOneWidget);
      expect(find.byKey(const Key('status-text')), findsOneWidget);
      expect(find.byKey(const Key('layers-panel')), findsOneWidget);
      expect(find.byKey(const Key('page-swatch-0')), findsOneWidget);
      expect(
          tester.widget<Container>(find.byKey(const Key('chrome-left'))).color,
          scheme.surfaceContainerLow,
          reason: 'the panels sit on the dark scheme');
      await painted('the shell');

      // The layer colour menu.
      await tester.tap(find.byKey(const Key('layer-colour-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('layer-colour-item-3')), findsOneWidget);
      await painted('the layer colour menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // The selection panel and its layer picker.
      final view = tester.widget<PlannerView>(find.byType(PlannerView));
      view.camera.value = paletteCamera;
      view.selection.replace([SelectionKey.root(p.f.selected)]);
      await tester.pump();
      expect(find.byKey(const Key('layer-picker')), findsOneWidget);
      await painted('the selection panel');
      await tester.tap(find.byKey(const Key('layer-picker')));
      await tester.pumpAndSettle();
      await painted('the layer picker');
      await tester.tap(find.byKey(const Key('layer-picker-item-1')).last);
      await tester.pumpAndSettle();
      view.selection.clear();
      await tester.pump();

      // The text entry.
      await tester.tap(find.byKey(const Key('tool-text')));
      await tester.pump();
      final at = paletteCamera.worldToScreen(Vector2(10500, 6400));
      final area = tester.getTopLeft(find.byType(InteractionLayer));
      await tester.tapAt(area + Offset(at.x, at.y));
      await tester.pump();
      expect(find.byKey(const Key('text-entry')), findsOneWidget);
      expect(kTextEntrySize.height, greaterThan(0));
      await painted('the text entry');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // The export dialog (the print flow has no dialog of its own: it
      // hands the PDF to the platform's).
      final context = tester.element(find.byType(PlannerView));
      final choice = showExportDialog(context, ExportChoice.initial);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('export-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('export-format-png')));
      await tester.pumpAndSettle();
      await painted('the export dialog');
      await tester.tap(find.byKey(const Key('export-cancel')));
      await tester.pumpAndSettle();
      expect(await choice, isNull);

      // The symbol panel and its search, matching and not.
      await p.openSymbols();
      await painted('the symbol panel');
      await tester.enterText(find.byKey(const Key('symbol-search')), 'bed');
      await tester.pump();
      await p.settleImages();
      expect(find.byKey(const Key('symbol-search-clear')), findsOneWidget);
      await painted('the symbol search');
      await tester.enterText(
          find.byKey(const Key('symbol-search')), 'no such symbol');
      await tester.pump();
      expect(find.byKey(const Key('symbol-search-empty')), findsOneWidget);
      await painted('the symbol search, no match');
    });

    testWidgets('ServiceView with a status', (tester) async {
      final c = statusController(white);
      await pumpService(tester, c, ThemeMode.dark);
      await shoot(tester);
      expect(tester.takeException(), isNull);
    });
  });
}

/// M-DT-15's scheme: the real dark seed with a light `primaryContainer`.
ColorScheme mdt15Scheme() =>
    ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark)
        .copyWith(primaryContainer: const Color(0xFFD8E2FF));
