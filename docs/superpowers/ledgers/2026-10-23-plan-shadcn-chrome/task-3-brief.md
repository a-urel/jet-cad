### Task 3: The chrome parts

**Files:**
- Create under `packages/jet_cad_2d_plan/lib/src/chrome/`:
  `words_carrier.dart`, `icon_button.dart`, `text_field.dart`,
  `select.dart`, `segmented.dart`, `menu_button.dart`, `rows.dart`
- Test: `test/chrome/parts_test.dart`, `test/l10n/shadcn_words_test.dart`

**Interfaces:**
- Consumes: `PlanShadScope` (Task 2).
- Produces (all internal, none exported):
  - `abstract interface class PlanWordsCarrier { Iterable<String> get visibleWords; }`
    — implemented by every part below; returns every string the part can
    put on screen (label, tooltip, placeholder, error, suffix, every menu
    or option label), open or closed.
  - `PlanIconButton({Key? key, required IconData icon, required String label, VoidCallback? onPressed, bool? selected, String? tooltip})`
    — `ShadIconButton.ghost` in a `ShadTooltip` showing `tooltip ?? label`;
    `Semantics(button: true, label: label, selected: selected, enabled: onPressed != null)`;
    `selected == true` draws the secondary variant. `key` on the part.
  - `PlanTextField({Key? key, required TextEditingController controller, FocusNode? focusNode, String? label, String? suffix, String? errorText, String? placeholder, bool readOnly = false, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, VoidCallback? onEditingComplete, TapRegionCallback? onTapOutside})`
    — label above, `ShadInput` (`groupId: EditableText`,
    `contextMenuBuilder:` the library's adaptive toolbar,
    `keyboardToolbarBuilder` null, `onPressedOutside: onTapOutside`),
    suffix as trailing, error below in `destructive`. **Read-only keeps
    today's `TextField(readOnly: true)` behaviour** (focusable, text
    selectable and copyable, not editable): builder's technique, pinned by
    CP3.
  - `PlanReadOnlyField({Key? key, required String label, required Widget child})` — the `InputDecorator` replacement.
  - `PlanSelect<T>({Key? key, required T? value, required List<PlanOption<T>> options, required ValueChanged<T> onChanged, bool enabled = true, String? label, String? placeholder})`
    and `PlanOption<T>(T value, String label)` — `ShadSelect<T>` driven by
    a private `ShadSelectController<T>`; after `onChanged` returns, and on
    every `didUpdateWidget`, the controller is set back to `value` (the
    model is the authority).
  - `PlanSegmented<T>({Key? key, required T value, required List<PlanSegment<T>> segments, required ValueChanged<T> onChanged, bool enabled = true})`
    and `PlanSegment<T>(T value, String label, {IconData? icon, Key? key})` —
    toggled `ShadButton`s (secondary when selected), each with
    `Semantics(selected:)`; same authority rule. Segment keys go on the
    segment buttons.
  - `PlanMenuButton<T>({Key? key, required IconData icon, required String label, required List<PlanMenuEntry<T>> Function() entries, required ValueChanged<T> onSelected, T? selected})`
    and `PlanMenuEntry<T>(T value, String label, {bool enabled = true, Key? key})` —
    a `PlanIconButton` trigger opening a `ShadContextMenu` through a
    `ShadContextMenuController` on primary click, tap, Enter or Space, on
    every platform; `entries()` is re-read on every build while open (live
    permissions); Escape and outside tap close it and return the focus to
    the trigger; the `selected` entry is marked.
  - `PlanCheckRow({Key? key, required String label, required bool value, ValueChanged<bool>? onChanged})`,
    `PlanSwitchRow(...)` same shape, `PlanListRow({Key? key, required Widget title, Widget? leading, bool selected = false, VoidCallback? onTap})`
    — focusable, `Semantics(button:, selected:)`, Enter/Space activate.
  - `Widget planTextContextMenu(BuildContext context, EditableTextState state)`
    — `AdaptiveTextSelectionToolbar.editableText(editableTextState: state)`.

- [ ] **Step 1: Write failing tests** (`parts_test.dart`, each part mounted under a bare `MaterialApp` in a `PlanShadScope`):
  `CP1 two PlanTextFields: tapping the second does not call the first's onTapOutside`;
  `CP2 tapping outside both calls it once`;
  `CP3 a readOnly field: focusable, its text selectable and copyable
  (Clipboard holds the selection), typing changes nothing; set readOnly
  while focused → stays focused; back to editable → typing edits`;
  `CP4 a PlanSelect whose onChanged refuses (does not change value) shows
  the old option's label after the pick`;
  `CP5 a PlanSelect rebuilt with a new value shows it` (undo/replace case);
  `CP6 PlanMenuButton opens on a primary mouse click on desktop
  (debugDefaultTargetPlatformOverride = macOS) and on a tap on Android;
  Enter on the focused trigger opens it; Escape closes it and the trigger
  has focus`;
  `CP7 Tab moves focus across a row of three PlanIconButtons; Space
  activates the focused one`;
  `CP8 an entry disabled by entries() while the menu is open becomes
  disabled without reopening`;
  `CP9 flipping the ancestor ShadTheme to dark with the select open: no
  exception, the open popover's background is the dark one`;
  `CP10 PlanIconButton(selected: true) exposes a selected semantics node
  labelled label; selected: false does not`;
  `CP11 every part's visibleWords lists its label, tooltip, placeholder,
  error and every entry/option label`.
  (`shadcn_words_test.dart`): `SW1 every ShadInput( in lib/ is inside
  lib/src/chrome/text_field.dart`; `SW2 text_field.dart passes
  contextMenuBuilder and no keyboardToolbarBuilder`; `SW3 no
  withSearch, ShadDatePicker, ShadTimePicker, ShadCalendar in lib/`;
  `SW4 every shadcn identifier used in lib/ is in kAllowedShad` (a const
  list in the test; an unused entry is red too, as `theme_colours_test`
  does).
- [ ] **Step 2: Run** `flutter test test/chrome/parts_test.dart test/l10n/shadcn_words_test.dart` → FAIL.
- [ ] **Step 3: Implement** the parts.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Mutations** M-CP1 drop `groupId` (CP1 red); M-CP4 no
  controller reset (CP4 red); M-CP6 use `ShadContextMenuRegion` (CP6 red on
  macOS); M-CP10 drop `selected:` from semantics (CP10 red); M-SW drop
  `contextMenuBuilder` (SW2 red). Revert each.
- [ ] **Step 6: Gates; commit** `feat(plan): the shadcn chrome parts`.

