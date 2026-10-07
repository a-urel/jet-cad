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

  // Spec Q0's fixture rule: centimetres, 1:20 (not the default 1:50), the
  // origin off zero, and `comma` against the default `point`.
  final centimetreComma = PageComponent(
      scaleDenominator: 20,
      originX: -4180.5,
      originY: 2645.25,
      displayUnit: DisplayUnit.centimeters,
      decimalSeparator: DecimalSeparator.comma);

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
      'decimalSeparator',
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

  test('copyWith takes any num for gridStepMm and refuses anything else', () {
    // M-page-num: `gridStepMm as double?` throws a TypeError on an int.
    // `gridStepMm` is `Object?` (the sentinel), so an int literal is not
    // promoted to double at compile time.
    final stepped = letterPortrait.copyWith(gridStepMm: 250);
    expect(stepped.gridStepMm, 250.0);
    expect(stepped.gridStepMm, isA<double>());
    expect(stepped.copyWith(gridStepMm: null).gridStepMm, isNull);
    final fromCleared =
        letterPortrait.copyWith(gridStepMm: null).copyWith(gridStepMm: 300);
    expect(fromCleared.gridStepMm, 300.0);
    expect(letterPortrait.copyWith(gridStepMm: 76.2).gridStepMm, 76.2);
    expect(
        () => letterPortrait.copyWith(gridStepMm: '250'),
        throwsA(
            isA<ArgumentError>().having((e) => e.name, 'name', 'gridStepMm')));
    // The num path still validates: an int zero is refused like 0.0.
    expect(
        () => letterPortrait.copyWith(gridStepMm: 0),
        throwsA(
            isA<ArgumentError>().having((e) => e.name, 'name', 'gridStepMm')));
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

  test(
      'Q0-P1 decimalSeparator is written by name in its alphabetical place '
      'and read back', () {
    // M-Q0-c: the key not written; the key not read.
    final json = centimetreComma.toJson();
    expect(json['decimalSeparator'], 'comma');
    final keys = json.keys.toList();
    expect(keys.indexOf('decimalSeparator'), keys.indexOf('background') + 1);
    final back = PageComponent.fromJson(json);
    expect(back.decimalSeparator, DecimalSeparator.comma);
    expect(back, centimetreComma);
    expect(back.hashCode, centimetreComma.hashCode);
  });

  test('Q0-P2 a v7 page (no decimalSeparator key) reads as point', () {
    final json = centimetreComma.toJson()..remove('decimalSeparator');
    final back = PageComponent.fromJson(json);
    expect(back.decimalSeparator, DecimalSeparator.point);
    // Nothing else moves: the rest is the fixture's.
    expect(back,
        centimetreComma.copyWith(decimalSeparator: DecimalSeparator.point));
  });

  test('Q0-P3 an unknown separator name is refused with an ArgumentError', () {
    // As the sibling enums are, through `values.byName` (spec Q0 V-6).
    final json = centimetreComma.toJson()..['decimalSeparator'] = 'semicolon';
    expect(() => PageComponent.fromJson(json), throwsArgumentError);
  });

  test('Q0-P4 == and hashCode distinguish the separator', () {
    // M-Q0-a / F-3: without the field in `==`, a change of separator is
    // invisible to regeneration and to PageNotifier.
    final point =
        centimetreComma.copyWith(decimalSeparator: DecimalSeparator.point);
    expect(point == centimetreComma, isFalse);
    expect(point.hashCode == centimetreComma.hashCode, isFalse);
    expect(point.copyWith(decimalSeparator: DecimalSeparator.comma),
        centimetreComma);
  });

  test('Q0-P5 copyWith sets the separator and otherwise keeps it', () {
    expect(centimetreComma.copyWith().decimalSeparator, DecimalSeparator.comma);
    final rescaled = centimetreComma.copyWith(
        scaleDenominator: 25, displayUnit: DisplayUnit.millimeters);
    expect(rescaled.decimalSeparator, DecimalSeparator.comma);
    final point =
        centimetreComma.copyWith(decimalSeparator: DecimalSeparator.point);
    expect(point.decimalSeparator, DecimalSeparator.point);
    expect(point.scaleDenominator, 20);
    expect(point.displayUnit, DisplayUnit.centimeters);
    expect(point.originX, -4180.5);
    expect(PageComponent().decimalSeparator, DecimalSeparator.point);
  });

  test('Q0-P6 DecimalSeparator prints its character', () {
    expect(DecimalSeparator.point.char, '.');
    expect(DecimalSeparator.comma.char, ',');
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
