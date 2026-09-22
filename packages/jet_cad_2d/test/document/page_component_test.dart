import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  // Never a square sheet (M-04e), never the defaults where a default would
  // hide the assertion.
  final letterPortrait = PageComponent(
      widthMm: 215.9,
      heightMm: 279.4,
      orientation: PageOrientation.portrait,
      scaleDenominator: 48,
      originX: 7350,
      originY: -1230,
      displayUnit: DisplayUnit.feetInches,
      background: 0xFFFAF6EC,
      gridVisible: false,
      gridStepMm: 152.4,
      snapToGrid: false,
      pageBreaks: true);

  test('effective size follows orientation on a non-square sheet', () {
    // M-04e.
    expect(letterPortrait.effectiveWidthMm, 215.9);
    expect(letterPortrait.effectiveHeightMm, 279.4);
    final landscape =
        letterPortrait.copyWith(orientation: PageOrientation.landscape);
    expect(landscape.effectiveWidthMm, 279.4);
    expect(landscape.effectiveHeightMm, 215.9);
  });

  test('presets are recognised by exact dimensions, anything else is custom',
      () {
    expect(letterPortrait.preset, SheetSize.letter);
    expect(PageComponent().preset, SheetSize.a4);
    expect(letterPortrait.copyWith(widthMm: 215.9, heightMm: 279.5).preset,
        isNull);
  });

  test('toJson keys are alphabetical and fromJson round-trips by value', () {
    final json = letterPortrait.toJson();
    expect(json.keys.toList(), [
      'background',
      'displayUnit',
      'gridStepMm',
      'gridVisible',
      'heightMm',
      'orientation',
      'originX',
      'originY',
      'pageBreaks',
      'scaleDenominator',
      'snapToGrid',
      'widthMm',
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
    expect(
        cleared.copyWith(displayUnit: DisplayUnit.meters).scaleDenominator, 48);
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
