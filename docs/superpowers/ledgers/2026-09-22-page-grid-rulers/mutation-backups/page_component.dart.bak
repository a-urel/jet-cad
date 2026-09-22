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

  // Ruling 04-8: constant patterns in a switch (`a4 => ...`) are rejected by
  // the analyzer on a class that overrides `==`, so this is an if-chain over
  // [presets] instead. Behaviour is identical to the pattern-match form.
  String get name {
    if (this == a4) return 'A4';
    if (this == a3) return 'A3';
    if (this == letter) return 'Letter';
    if (this == tabloid) return 'Tabloid';
    return 'Custom';
  }

  @override
  bool operator ==(Object other) =>
      other is SheetSize &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm;

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
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'must be finite');
    }
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
  int get hashCode => Object.hash(
      widthMm,
      heightMm,
      orientation,
      scaleDenominator,
      originX,
      originY,
      displayUnit,
      background,
      gridVisible,
      gridStepMm,
      snapToGrid,
      pageBreaks);

  @override
  String toString() =>
      'PageComponent(${preset?.name ?? 'custom'} ${orientation.name} '
      '1:$scaleDenominator at ($originX, $originY), ${displayUnit.name})';
}
