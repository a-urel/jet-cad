// Spec P2 and P5: the export choice without the format, the dialog's
// answer naming the exporter, and the resolutions.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';

void main() {
  test(
      'X-1 the choice and the answer: ==, hashCode, copyWith, toString; the '
      'resolutions in order', () {
    const initial = PlanExportChoice.initial;
    expect(initial.dpi, PlanExportDpi.d150);
    expect(initial.toString(), 'PlanExportChoice(150 dpi)');
    expect(PlanExportDpi.values.map((d) => d.value), [96, 150, 300]);
    final d96 = initial.copyWith(dpi: PlanExportDpi.d96);
    // M-X-1a: PlanExportChoice.== ignores dpi.
    expect(d96 == initial, isFalse);
    expect(initial.copyWith(), initial);
    expect(const PlanExportChoice(dpi: PlanExportDpi.d150), initial);
    expect(initial.hashCode == d96.hashCode, isFalse);

    const answer = PlanExportAnswer.initial;
    expect(answer.exporter, 'plan.pdf');
    expect(answer.choice, initial);
    expect(answer.toString(), 'PlanExportAnswer(plan.pdf, 150 dpi)');
    final png = answer.copyWith(exporter: 'plan.png');
    final fine = answer.copyWith(
        choice: const PlanExportChoice(dpi: PlanExportDpi.d300));
    expect(png.choice, initial, reason: 'choice kept');
    expect(fine.exporter, 'plan.pdf', reason: 'exporter kept');
    // M-X-1b: PlanExportAnswer.== ignores the exporter.
    expect(png == answer, isFalse);
    expect(fine == answer, isFalse);
    expect(png == fine, isFalse);
    expect(answer.copyWith(), answer);
    expect(
        const PlanExportAnswer(
            exporter: 'plan.png', choice: PlanExportChoice.initial),
        png);
    expect(png.hashCode == answer.hashCode, isFalse);
  });
}
