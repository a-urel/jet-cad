// Spec 2a P4: a kit diagnostic is equal by kit, subject, code and message.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

const KitDiagnostic failed = KitDiagnostic(
  kitId: 'test',
  subject: 'test.slab',
  code: KitDiagnosticCode.hookFailed,
  message: 'reach threw',
  error: 'boom',
);

void main() {
  test('PT23 equality sees kit, subject, code and message, not the error', () {
    expect(
        failed,
        const KitDiagnostic(
            kitId: 'test',
            subject: 'test.slab',
            code: KitDiagnosticCode.hookFailed,
            message: 'reach threw',
            error: 'another'));
    expect(
        failed.hashCode,
        const KitDiagnostic(
                kitId: 'test',
                subject: 'test.slab',
                code: KitDiagnosticCode.hookFailed,
                message: 'reach threw')
            .hashCode);
    expect(
        failed,
        isNot(const KitDiagnostic(
            kitId: 'other',
            subject: 'test.slab',
            code: KitDiagnosticCode.hookFailed,
            message: 'reach threw')));
    // M-PT23: drop the subject from ==.
    expect(
        failed,
        isNot(const KitDiagnostic(
            kitId: 'test',
            subject: 'test.post',
            code: KitDiagnosticCode.hookFailed,
            message: 'reach threw')));
    expect(
        failed,
        isNot(const KitDiagnostic(
            kitId: 'test',
            subject: 'test.slab',
            code: KitDiagnosticCode.componentUnreadable,
            message: 'reach threw')));
    expect(
        failed,
        isNot(const KitDiagnostic(
            kitId: 'test',
            subject: 'test.slab',
            code: KitDiagnosticCode.hookFailed,
            message: 'generate threw')));
    expect('$failed', 'hookFailed [test test.slab]: reach threw');
    expect(
        '${const KitDiagnostic(kitId: 'cafe', code: KitDiagnosticCode.kitMissing, message: 'not loaded')}',
        'kitMissing [cafe]: not loaded');
  });
}
