// Spec D12 (the page panel) and 2a spec P2: the page's controls over a
// PlanController. Ported from jet_cad_floor_plan/lib/src/page_panel.dart.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show PageNotifier;

import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/number_text.dart';
import '../l10n/strings.dart';
import '../l10n/strings_en.dart';
import '../shortcuts/plan_shortcut_guard.dart';
import 'panel_focus.dart';

/// The page panel (spec D12) of [controller]'s plan. Every control
/// executes one `SetComponentCommand<PageComponent>` through
/// `controller.execute`; the panel rebuilds from the page notifier, so
/// undo moves the controls back. With `permissions.editPage` false every
/// control is disabled and the values are still shown. It follows a
/// swapped document, and its scale field's re-sync is registered with the
/// controller's pending-input settle.
class PlanPagePanel extends StatefulWidget {
  const PlanPagePanel({super.key, required this.controller});

  final PlanController controller;

  @override
  State<PlanPagePanel> createState() => PlanPagePanelState();
}

class PlanPagePanelState extends State<PlanPagePanel> {
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
  PlanStrings _strings = const PlanStringsEn();

  /// The page notifier [_syncScale] listens to: the controller's, rebound
  /// on a swap.
  PageNotifier? _page;

  /// Withdraws [resyncScale]'s registration with the controller.
  VoidCallback? _releaseSettle;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _bindPage();
    _releaseSettle = widget.controller.registerSettle(resyncScale);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
    final next = PlanStrings.of(context);
    if (identical(next, _strings)) return;
    _strings = next;
    if (!_scaleFocus.hasFocus) _syncScale();
  }

  @override
  void didUpdateWidget(PlanPagePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onController);
      _releaseSettle?.call();
      widget.controller.addListener(_onController);
      _releaseSettle = widget.controller.registerSettle(resyncScale);
      _bindPage();
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _releaseSettle?.call();
    _page?.removeListener(_syncScale);
    _scale.dispose();
    _scaleFocus.dispose();
    super.dispose();
  }

  /// A swapped document has a new page notifier: listen to it and show its
  /// scale. New permissions rebuild.
  void _onController() {
    if (!identical(_page, widget.controller.page)) _bindPage();
    if (mounted) setState(() {});
  }

  void _bindPage() {
    _page?.removeListener(_syncScale);
    _page = widget.controller.page..addListener(_syncScale);
    _syncScale();
  }

  /// Shows the page's scale, read from the document, not from the notifier
  /// (page_panel.dart:74-77: a command updates the document at once, the
  /// notifier only after the change stream delivers).
  void _syncScale() {
    final document = widget.controller.document;
    final page = document.components.get<PageComponent>(document.rootHandle);
    if (page == null) return;
    final text = formatPanelNumber(page.scaleDenominator, _strings);
    if (_scale.text != text) _scale.text = text;
  }

  /// Shows the stored scale in the scale field, dropping any text typed and
  /// not submitted, and commits nothing: the controller's settle calls it
  /// before a flow reads the document (D14: unsubmitted text is not saved).
  /// A scale field that has the focus hands it back to the canvas, as the
  /// old shell's settle did.
  void resyncScale() {
    _scaleFocus.handBack();
    _syncScale();
  }

  bool get _editable => widget.controller.permissions.editPage;

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

  void _set(PageComponent next) {
    if (!_editable) return;
    final document = widget.controller.document;
    try {
      // False: refused (a lock, which raises the hint, a dangling
      // reference, an ArgumentError, a kit's failure); nothing changed.
      widget.controller.execute(
          SetComponentCommand<PageComponent>(document.rootHandle, next));
    } on StateError {
      // Refused by the dispatcher: nothing changed.
    }
  }

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

  /// The panel sits in a [PlanShortcutGuard], as the property panel and
  /// a layer's rename field do: the scale field keeps its keys (spec P2,
  /// "Text fields keep their keys") wherever a host puts the panel.
  /// A segment label that stays on one line: the segment is narrower than
  /// "Landscape" or "Querformat" beside the selected-check icon, so the
  /// text shrinks to its segment instead of breaking mid-word (spec R2 O2).
  Widget _oneLine(String text, Key key) => FittedBox(
      fit: BoxFit.scaleDown, child: Text(text, key: key, maxLines: 1));

  @override
  Widget build(BuildContext context) => PlanShortcutGuard(
      controller: widget.controller,
      child: ValueListenableBuilder<PageComponent?>(
        valueListenable: widget.controller.page,
        builder: (context, page, _) {
          if (page == null) return const SizedBox.shrink();
          // Spec C-5: with `editPage` false, every control is disabled.
          final editable = _editable;
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
                        label: _oneLine(_strings.portrait,
                            const Key('page-orientation-portrait'))),
                    ButtonSegment(
                        value: PageOrientation.landscape,
                        label: _oneLine(_strings.landscape,
                            const Key('page-orientation-landscape'))),
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
      ));
}
