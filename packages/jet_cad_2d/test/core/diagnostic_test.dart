import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('carries severity, a machine-matchable code, and affected handles', () {
    const d = Diagnostic(
      severity: DiagnosticSeverity.loss,
      code: 'fill.image_degraded',
      message: 'Raster fill unavailable; wrote a solid fill.',
      handles: [Handle(0x2A)],
    );
    expect(d.severity, DiagnosticSeverity.loss);
    expect(d.code, 'fill.image_degraded');
    expect(d.handles.single, const Handle(0x2A));
    expect(d.sourceLocation, isNull);
  });

  test('handles defaults to empty, not null', () {
    const d = Diagnostic(
      severity: DiagnosticSeverity.info,
      code: 'x',
      message: 'y',
    );
    expect(d.handles, isEmpty);
  });

  test('is value-equal so tests can assert on expected diagnostic sets', () {
    const a = Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'tree.cycle_dropped',
      message: 'm',
      handles: [Handle(1), Handle(2)],
    );
    const b = Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'tree.cycle_dropped',
      message: 'm',
      handles: [Handle(1), Handle(2)],
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('toJson emits keys in a stable order and omits absent fields', () {
    const d = Diagnostic(
      severity: DiagnosticSeverity.error,
      code: 'c',
      message: 'm',
      handles: [Handle(3)],
    );
    expect(
        d.toJson().keys.toList(), ['severity', 'code', 'message', 'handles']);
    expect(d.toJson()['handles'], [3]);
  });
}
