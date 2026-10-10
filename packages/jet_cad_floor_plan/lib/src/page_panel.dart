import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'l10n/strings_en.dart';
import 'l10n/strings.dart';
import 'l10n/number_text.dart';
import 'panel_focus.dart';

/// The smallest panel that lets a human change the page (spec D12). Every
/// control executes one `SetComponentCommand`; the panel rebuilds from the
/// notifier, so undo moves the controls back. 12 replaces this.
///
/// [editable] false (host embedding API spec C-5's `editPage`, S-9 e)
/// disables every control; the values are still shown.
class PagePanel extends StatefulWidget {
  const PagePanel(
      {super.key,
      required this.document,
      required this.page,
      this.editable = true});

  final DraftDocument document;
  final PageNotifier page;

  /// Whether the host lets the user edit the page (spec C-5); true is
  /// today's panel.
  final bool editable;

  @override
  State<PagePanel> createState() => PagePanelState();
}

/// Public for the shell's settle (spec 12a D2): [resyncScale].
class PagePanelState extends State<PagePanel> {
  final TextEditingController _scale = TextEditingController();
  final PanelFieldFocusNode _scaleFocus = PanelFieldFocusNode();

  static const List<(String, int)> _swatches = [
    ('White', 0xFFFFFFFF),
    ('Ivory', 0xFFFAF6EC),
    ('Grey', 0xFFEDEDED),
    ('Blueprint', 0xFF1F3A5F),
  ];

  /// The panel's words (spec 14d L12): set before the first build; a
  /// change of language shows the scale again in it.
  FloorPlanStrings _strings = const FloorPlanStringsEn();

  @override
  void initState() {
    super.initState();
    _syncScale();
    widget.page.addListener(_syncScale);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = FloorPlanStrings.of(context);
    if (identical(next, _strings)) return;
    _strings = next;
    if (!_scaleFocus.hasFocus) _syncScale();
  }

  @override
  void dispose() {
    widget.page.removeListener(_syncScale);
    _scale.dispose();
    _scaleFocus.dispose();
    super.dispose();
  }

  /// Shows the page's scale. It reads the page from the document, not from
  /// [PagePanel.page]: a command updates the document at once, while the
  /// notifier hears of it only from `document.changes`, an asynchronous
  /// stream, a microtask or more later.
  void _syncScale() {
    final document = widget.document;
    final page = document.components.get<PageComponent>(document.rootHandle);
    if (page == null) return;
    final text = formatPanelNumber(page.scaleDenominator, _strings);
    if (_scale.text != text) _scale.text = text;
  }

  /// Shows the stored scale in the scale field, dropping any text typed and
  /// not submitted, and commits nothing: the shell's settle (spec 12a D2)
  /// calls it before a flow reads the document, so the panel never shows a
  /// scale the saved file does not have (D14: unsubmitted text is not
  /// saved).
  void resyncScale() => _syncScale();

  /// The scale is committed on submit (spec 04), so a field left without
  /// Enter would go on showing a scale the page does not have. A tap outside
  /// the field -- the user clicking elsewhere in the app -- hands the focus
  /// back to the canvas and then re-syncs the field to the page's scale
  /// (fix/post-07 F2F3d). Nothing is committed.
  ///
  /// Only a pointer down outside the field's tap region calls this, and the
  /// field arms it from its focus at its last build. A window blur never
  /// does. On web (Chromium; on Safari desktop the engine listens for no
  /// input blur, and only the window's blur arrives) the focused `<input>`
  /// blurs first, with no element to take the focus, so the engine closes
  /// the text input connection;
  /// `EditableText.connectionClosed` then unfocuses the field while the app
  /// is still `resumed`, and the window's own blur, which makes the app
  /// `inactive`, comes after that (the F2F3c review saw this order in
  /// Chromium). A focus-loss listener cannot tell that from the user moving
  /// on, even behind a lifecycle guard, and dropped the typed text (f5920de).
  /// Here the field keeps it. Once it has rebuilt without the focus, the
  /// field is no longer armed, so a later click elsewhere in the app does
  /// not re-sync it either.
  ///
  /// On Enter, `onEditingComplete` hands the focus back and `onSubmitted`
  /// commits; the page listener then shows the committed value.
  ///
  /// Accepted: every text field has `EditableText`'s default tap group, so a
  /// click on another text field -- a Selection panel field, say -- is not
  /// outside this one, and Tab is no tap at all. Leaving the scale either
  /// way keeps the unsubmitted text visible until the page changes, or the
  /// field, focused again, is submitted or left by a tap outside.
  void _onScaleTapOutside(PointerDownEvent _) {
    _scaleFocus.handBack();
    _syncScale();
  }

  void _set(PageComponent next) => widget.document.commands.execute(
      SetComponentCommand<PageComponent>(widget.document.rootHandle, next));

  void _submitScale(PageComponent page, String text) {
    final value = parsePanelNumber(text, _strings);
    if (value == null || !value.isFinite || value <= 0) {
      _syncScale();
      return;
    }
    if (value != page.scaleDenominator) {
      _set(page.copyWith(scaleDenominator: value));
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PageComponent?>(
        valueListenable: widget.page,
        builder: (context, page, _) {
          if (page == null) return const SizedBox.shrink();
          // Spec C-5: with `editPage` false, every control is disabled.
          final editable = widget.editable;
          // Dark theme spec D6a: the swatch border is the scheme's, read at
          // build so a theme switch follows.
          final scheme = Theme.of(context).colorScheme;
          // The shell's `chrome-right` slot is a `Container` with its own
          // background color (a `ColoredBox`); without a `Material` of its
          // own in between, the checkboxes' `ListTile` ink surface has no
          // Material to paint on and Flutter raises "background color or
          // ink splashes may be invisible" on every frame.
          return Material(
            color: Colors.transparent,
            // Laid out whole: the shell's right column scrolls (review
            // 14d-1 F-2).
            child: ListView(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                Text(_strings.pageTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButton<SheetSize?>(
                  key: const Key('page-preset'),
                  isExpanded: true,
                  value: page.preset,
                  // `DropdownButton` shows `hint` (never an item lookup) when
                  // `value` is null, so a custom size needs this to read
                  // "Custom" while closed; the disabled entry below is what
                  // makes it read "Custom" in the opened list too.
                  hint: Text(_strings.customSize),
                  items: [
                    for (final s in SheetSize.presets)
                      DropdownMenuItem(value: s, child: Text(s.name)),
                    if (page.preset == null)
                      DropdownMenuItem<SheetSize?>(
                          value: null,
                          enabled: false,
                          child: Text(_strings.customSize)),
                  ],
                  onChanged: !editable
                      ? null
                      : (s) {
                          if (s != null) {
                            _set(page.copyWith(
                                widthMm: s.widthMm, heightMm: s.heightMm));
                          }
                        },
                ),
                const SizedBox(height: 8),
                SegmentedButton<PageOrientation>(
                  segments: [
                    ButtonSegment(
                        value: PageOrientation.portrait,
                        label: Text(_strings.portrait,
                            key: const Key('page-orientation-portrait'))),
                    ButtonSegment(
                        value: PageOrientation.landscape,
                        label: Text(_strings.landscape,
                            key: const Key('page-orientation-landscape'))),
                  ],
                  selected: {page.orientation},
                  onSelectionChanged: !editable
                      ? null
                      : (s) => _set(page.copyWith(orientation: s.single)),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('page-scale'),
                  controller: _scale,
                  focusNode: _scaleFocus,
                  enabled: editable,
                  decoration: InputDecoration(
                      prefixText: '1:', labelText: _strings.scale),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (text) => _submitScale(page, text),
                  // Enter and a tap outside hand focus back to the canvas
                  // (fix/post-07 F2), so the shell's letters and Escape work
                  // again at once. `onSubmitted` still runs after Enter's.
                  // Without these, Enter and a mouse click outside take the
                  // focus to the route's scope, where no key reaches the
                  // shell -- even from a canvas click. A tap outside also
                  // re-syncs the field (`_onScaleTapOutside`).
                  onEditingComplete: _scaleFocus.handBack,
                  onTapOutside: _onScaleTapOutside,
                ),
                const SizedBox(height: 8),
                DropdownButton<DisplayUnit>(
                  key: const Key('page-unit'),
                  isExpanded: true,
                  value: page.displayUnit,
                  items: const [
                    DropdownMenuItem(
                        value: DisplayUnit.millimeters, child: Text('mm')),
                    DropdownMenuItem(
                        value: DisplayUnit.centimeters, child: Text('cm')),
                    DropdownMenuItem(
                        value: DisplayUnit.meters, child: Text('m')),
                    DropdownMenuItem(
                        value: DisplayUnit.inches, child: Text('in')),
                    DropdownMenuItem(
                        value: DisplayUnit.feetInches, child: Text('ft-in')),
                  ],
                  onChanged: !editable
                      ? null
                      : (u) {
                          if (u != null) _set(page.copyWith(displayUnit: u));
                        },
                ),
                // Spec Q0 P1: the page's own separator, the one its text
                // prints with. It shows the page's value, never the UI's
                // (`_strings.decimalSeparator`); the segments are digits,
                // the same in every language.
                const SizedBox(height: 8),
                Text(_strings.pageDecimalSeparator),
                const SizedBox(height: 4),
                SegmentedButton<DecimalSeparator>(
                  key: const Key('page-decimal-separator'),
                  segments: const [
                    ButtonSegment(
                        value: DecimalSeparator.point,
                        label: Text('1.5',
                            key: Key('page-decimal-separator-point'))),
                    ButtonSegment(
                        value: DecimalSeparator.comma,
                        label: Text('1,5',
                            key: Key('page-decimal-separator-comma'))),
                  ],
                  selected: {page.decimalSeparator},
                  onSelectionChanged: !editable
                      ? null
                      : (s) => _set(page.copyWith(decimalSeparator: s.single)),
                ),
                CheckboxListTile(
                  key: const Key('page-grid'),
                  title: Text(_strings.grid),
                  value: page.gridVisible,
                  onChanged: !editable
                      ? null
                      : (v) => _set(page.copyWith(gridVisible: v)),
                ),
                CheckboxListTile(
                  key: const Key('page-snap'),
                  title: Text(_strings.snapToGrid),
                  value: page.snapToGrid,
                  onChanged: !editable
                      ? null
                      : (v) => _set(page.copyWith(snapToGrid: v)),
                ),
                CheckboxListTile(
                  key: const Key('page-breaks'),
                  title: Text(_strings.pageBreaks),
                  value: page.pageBreaks,
                  onChanged: !editable
                      ? null
                      : (v) => _set(page.copyWith(pageBreaks: v)),
                ),
                const SizedBox(height: 8),
                Text(_strings.paper),
                Row(
                  children: [
                    for (var i = 0; i < _swatches.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          key: Key('page-swatch-$i'),
                          onTap: !editable
                              ? null
                              : () => _set(
                                  page.copyWith(background: _swatches[i].$2)),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(_swatches[i].$2),
                              border: Border.all(
                                  color: page.background == _swatches[i].$2
                                      ? scheme.primary
                                      : scheme.outline,
                                  width: page.background == _swatches[i].$2
                                      ? 2
                                      : 1),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      );
}
