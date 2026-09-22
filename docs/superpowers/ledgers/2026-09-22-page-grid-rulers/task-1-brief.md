### Task 1: The branch point, and `PageComponent`

**Files:**
- Create: `lib/src/document/page_component.dart`
- Modify: `lib/jet_cad_2d.dart` (export)
- Test: `test/document/page_component_test.dart`

**Interfaces:**
- Produces: `PageComponent`, `PageOrientation`, `DisplayUnit` (+
  `mmPerUnit`, `symbol`, `isImperial`), `SheetSize` (+ `presets`),
  `PageComponent.register`, `effectiveWidthMm/HeightMm`, `preset`,
  `copyWith`, `fromJson`, `componentTypeId`.

- [ ] **Step 1: Branch point.** In the worktree: `git log --oneline -1`
  (≥ `52dd8ae`), `flutter pub get`, then the four gate lines once, pasting
  the four summary lines into the ledger: engine 830, render layer 771 +
  1 skip + the five goldens, harness 82, app 13. `git checkout --` the three
  `analysis_options.yaml` files.

- [ ] **Step 2: Write the failing tests.**

```dart
// test/document/page_component_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  // Never a square sheet (M-04e), never the defaults where a default would
  // hide the assertion.
  final letterPortrait = PageComponent(
    widthMm: 215.9, heightMm: 279.4, orientation: PageOrientation.portrait,
    scaleDenominator: 48, originX: 7350, originY: -1230,
    displayUnit: DisplayUnit.feetInches, background: 0xFFFAF6EC,
    gridVisible: false, gridStepMm: 152.4, snapToGrid: false, pageBreaks: true);

  test('effective size follows orientation on a non-square sheet', () {
    // M-04e.
    expect(letterPortrait.effectiveWidthMm, 215.9);
    expect(letterPortrait.effectiveHeightMm, 279.4);
    final landscape = letterPortrait.copyWith(orientation: PageOrientation.landscape);
    expect(landscape.effectiveWidthMm, 279.4);
    expect(landscape.effectiveHeightMm, 215.9);
  });

  test('presets are recognised by exact dimensions, anything else is custom', () {
    expect(letterPortrait.preset, SheetSize.letter);
    expect(PageComponent().preset, SheetSize.a4);
    expect(letterPortrait.copyWith(widthMm: 215.9, heightMm: 279.5).preset, isNull);
  });

  test('toJson keys are alphabetical and fromJson round-trips by value', () {
    final json = letterPortrait.toJson();
    expect(json.keys.toList(), [
      'background', 'displayUnit', 'gridStepMm', 'gridVisible', 'heightMm',
      'orientation', 'originX', 'originY', 'pageBreaks', 'scaleDenominator',
      'snapToGrid', 'widthMm',
    ]);
    final back = PageComponent.fromJson(json);
    expect(back, letterPortrait);
    expect(back.hashCode, letterPortrait.hashCode);
    expect(back.gridStepMm, 152.4);
  });

  test('optional keys take their defaults, required keys throw', () {
    final json = letterPortrait.toJson()
      ..remove('gridStepMm')
      ..remove('gridVisible')
      ..remove('snapToGrid')
      ..remove('pageBreaks')
      ..remove('background');
    final back = PageComponent.fromJson(json);
    expect(back.gridStepMm, isNull);
    expect(back.gridVisible, isTrue);
    expect(back.snapToGrid, isTrue);
    expect(back.pageBreaks, isFalse);
    expect(back.background, 0xFFFFFFFF);
    expect(() => PageComponent.fromJson(json..remove('originX')),
        throwsA(isA<FormatException>()));
  });

  test('copyWith can clear gridStepMm and leaves the rest alone', () {
    final cleared = letterPortrait.copyWith(gridStepMm: null);
    expect(cleared.gridStepMm, isNull);
    expect(cleared.copyWith(displayUnit: DisplayUnit.meters).scaleDenominator, 48);
    expect(letterPortrait.copyWith(), letterPortrait);
  });

  test('validation refuses non-finite and non-positive values', () {
    expect(() => PageComponent(widthMm: 0), throwsArgumentError);
    expect(() => PageComponent(heightMm: double.nan), throwsArgumentError);
    expect(() => PageComponent(scaleDenominator: -50), throwsArgumentError);
    expect(() => PageComponent(gridStepMm: 0), throwsArgumentError);
    expect(() => PageComponent(originX: double.infinity), throwsArgumentError);
  });

  test('register makes the type known to a registry, once', () {
    final registry = ComponentRegistry()..registerBuiltIns();
    PageComponent.register(registry);
    registry.attach(const Handle(16), letterPortrait);
    expect(registry.get<PageComponent>(const Handle(16)), letterPortrait);
    expect(registry.isInternal(PageComponent.componentTypeId), isFalse);
  });

  test('DisplayUnit conversions are exact', () {
    expect(DisplayUnit.millimeters.mmPerUnit, 1);
    expect(DisplayUnit.centimeters.mmPerUnit, 10);
    expect(DisplayUnit.meters.mmPerUnit, 1000);
    expect(DisplayUnit.inches.mmPerUnit, 25.4);
    expect(DisplayUnit.feetInches.mmPerUnit, 304.8);
    expect(DisplayUnit.feetInches.isImperial, isTrue);
    expect(DisplayUnit.centimeters.isImperial, isFalse);
    expect(DisplayUnit.meters.symbol, 'm');
    expect(DisplayUnit.feetInches.symbol, 'ft');
  });
}
```

- [ ] **Step 3: Run it to fail.** `CI=true dart test
  test/document/page_component_test.dart` → compile error, `PageComponent`
  undefined.

- [ ] **Step 4: Implement.**

```dart
// lib/src/document/page_component.dart
import 'component.dart';

/// Which way the sheet is turned; [PageComponent.widthMm] and [heightMm]
/// are always the portrait dimensions.
enum PageOrientation { portrait, landscape }

/// The unit a person reads (spec D1). The model is millimetres regardless.
enum DisplayUnit { millimeters, centimeters, meters, inches, feetInches }

extension DisplayUnitConversion on DisplayUnit {
  /// Exact, spec D1's table.
  double get mmPerUnit => switch (this) {
        DisplayUnit.millimeters => 1.0,
        DisplayUnit.centimeters => 10.0,
        DisplayUnit.meters => 1000.0,
        DisplayUnit.inches => 25.4,
        DisplayUnit.feetInches => 304.8,
      };

  String get symbol => switch (this) {
        DisplayUnit.millimeters => 'mm',
        DisplayUnit.centimeters => 'cm',
        DisplayUnit.meters => 'm',
        DisplayUnit.inches => 'in',
        DisplayUnit.feetInches => 'ft',
      };

  bool get isImperial =>
      this == DisplayUnit.inches || this == DisplayUnit.feetInches;
}

/// A sheet's portrait dimensions in paper millimetres.
class SheetSize {
  const SheetSize(this.widthMm, this.heightMm);

  static const SheetSize a4 = SheetSize(210, 297);
  static const SheetSize a3 = SheetSize(297, 420);
  static const SheetSize letter = SheetSize(215.9, 279.4);
  static const SheetSize tabloid = SheetSize(279.4, 431.8);
  static const List<SheetSize> presets = [a4, a3, letter, tabloid];

  final double widthMm;
  final double heightMm;

  String get name => switch (this) {
        a4 => 'A4',
        a3 => 'A3',
        letter => 'Letter',
        tabloid => 'Tabloid',
        _ => 'Custom',
      };

  @override
  bool operator ==(Object other) =>
      other is SheetSize && other.widthMm == widthMm && other.heightMm == heightMm;

  @override
  int get hashCode => Object.hash(widthMm, heightMm);
}

/// Sentinel for [PageComponent.copyWith]'s nullable field.
const Object _keep = Object();

/// The page (spec D3): sheet, orientation, drawing scale, the sheet's world
/// origin, display unit, paper colour, grid and snap settings. Attached to
/// the root handle by the application; not an engine built-in.
///
/// Immutable and value-equal, like every [Component]; `toJson` keys are
/// alphabetical, so the order is fixed by construction.
class PageComponent implements Component {
  static const String componentTypeId = 'jetcad.page';

  /// Registers the type. **Once per registry**: `register` replaces the
  /// store for the type, so a second call drops a live page.
  static void register(ComponentRegistry registry) =>
      registry.register<PageComponent>(componentTypeId, fromJson);

  final double widthMm;
  final double heightMm;
  final PageOrientation orientation;
  final double scaleDenominator;
  final double originX;
  final double originY;
  final DisplayUnit displayUnit;
  final int background;
  final bool gridVisible;
  final double? gridStepMm;
  final bool snapToGrid;
  final bool pageBreaks;

  PageComponent({
    this.widthMm = 210,
    this.heightMm = 297,
    this.orientation = PageOrientation.landscape,
    this.scaleDenominator = 50,
    this.originX = 0,
    this.originY = 0,
    this.displayUnit = DisplayUnit.meters,
    this.background = 0xFFFFFFFF,
    this.gridVisible = true,
    this.gridStepMm,
    this.snapToGrid = true,
    this.pageBreaks = false,
  }) {
    _requirePositive(widthMm, 'widthMm');
    _requirePositive(heightMm, 'heightMm');
    _requirePositive(scaleDenominator, 'scaleDenominator');
    final step = gridStepMm;
    if (step != null) _requirePositive(step, 'gridStepMm');
    _requireFinite(originX, 'originX');
    _requireFinite(originY, 'originY');
  }

  static void _requirePositive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'must be finite and positive');
    }
  }

  static void _requireFinite(double value, String name) {
    if (!value.isFinite) throw ArgumentError.value(value, name, 'must be finite');
  }

  double get effectiveWidthMm =>
      orientation == PageOrientation.portrait ? widthMm : heightMm;
  double get effectiveHeightMm =>
      orientation == PageOrientation.portrait ? heightMm : widthMm;

  /// The preset whose dimensions match exactly, or null for a custom sheet.
  SheetSize? get preset {
    for (final p in SheetSize.presets) {
      if (p.widthMm == widthMm && p.heightMm == heightMm) return p;
    }
    return null;
  }

  PageComponent copyWith({
    double? widthMm,
    double? heightMm,
    PageOrientation? orientation,
    double? scaleDenominator,
    double? originX,
    double? originY,
    DisplayUnit? displayUnit,
    int? background,
    bool? gridVisible,
    Object? gridStepMm = _keep,
    bool? snapToGrid,
    bool? pageBreaks,
  }) =>
      PageComponent(
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        orientation: orientation ?? this.orientation,
        scaleDenominator: scaleDenominator ?? this.scaleDenominator,
        originX: originX ?? this.originX,
        originY: originY ?? this.originY,
        displayUnit: displayUnit ?? this.displayUnit,
        background: background ?? this.background,
        gridVisible: gridVisible ?? this.gridVisible,
        gridStepMm: identical(gridStepMm, _keep)
            ? this.gridStepMm
            : gridStepMm as double?,
        snapToGrid: snapToGrid ?? this.snapToGrid,
        pageBreaks: pageBreaks ?? this.pageBreaks,
      );

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'background': background,
        'displayUnit': displayUnit.name,
        'gridStepMm': gridStepMm,
        'gridVisible': gridVisible,
        'heightMm': heightMm,
        'orientation': orientation.name,
        'originX': originX,
        'originY': originY,
        'pageBreaks': pageBreaks,
        'scaleDenominator': scaleDenominator,
        'snapToGrid': snapToGrid,
        'widthMm': widthMm,
      };

  static PageComponent fromJson(Map<String, Object?> json) => PageComponent(
        widthMm: _requiredDouble(json, 'widthMm'),
        heightMm: _requiredDouble(json, 'heightMm'),
        orientation: PageOrientation.values
            .byName(_required(json, 'orientation') as String),
        scaleDenominator: _requiredDouble(json, 'scaleDenominator'),
        originX: _requiredDouble(json, 'originX'),
        originY: _requiredDouble(json, 'originY'),
        displayUnit:
            DisplayUnit.values.byName(_required(json, 'displayUnit') as String),
        background: (json['background'] as int?) ?? 0xFFFFFFFF,
        gridVisible: (json['gridVisible'] as bool?) ?? true,
        gridStepMm: (json['gridStepMm'] as num?)?.toDouble(),
        snapToGrid: (json['snapToGrid'] as bool?) ?? true,
        pageBreaks: (json['pageBreaks'] as bool?) ?? false,
      );

  static Object _required(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) throw FormatException('PageComponent: missing "$key"');
    return value;
  }

  static double _requiredDouble(Map<String, Object?> json, String key) =>
      (_required(json, key) as num).toDouble();

  @override
  bool operator ==(Object other) =>
      other is PageComponent &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm &&
      other.orientation == orientation &&
      other.scaleDenominator == scaleDenominator &&
      other.originX == originX &&
      other.originY == originY &&
      other.displayUnit == displayUnit &&
      other.background == background &&
      other.gridVisible == gridVisible &&
      other.gridStepMm == gridStepMm &&
      other.snapToGrid == snapToGrid &&
      other.pageBreaks == pageBreaks;

  @override
  int get hashCode => Object.hash(widthMm, heightMm, orientation,
      scaleDenominator, originX, originY, displayUnit, background,
      gridVisible, gridStepMm, snapToGrid, pageBreaks);

  @override
  String toString() =>
      'PageComponent(${preset?.name ?? 'custom'} ${orientation.name} '
      '1:$scaleDenominator at ($originX, $originY), ${displayUnit.name})';
}
```

Add `export 'src/document/page_component.dart';` to `lib/jet_cad_2d.dart`
in alphabetical position (after `origin_component.dart`).

- [ ] **Step 5: Run to pass**, then the `jet_cad_2d` gate line.
- [ ] **Step 6: Commit** — `feat(engine): PageComponent`.

---

