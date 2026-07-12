import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/viewport/texture_binding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('jet_cad/texture');
  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? handler;

  setUp(() {
    calls.clear();
    handler = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler?.call(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('registerTexture sends surfaceId and returns textureId', () async {
    handler = (_) => 42;
    const binding = TextureBinding();
    expect(await binding.registerTexture(7), 42);
    expect(calls.single.method, 'registerTexture');
    expect(calls.single.arguments, {'surfaceId': 7});
  });

  test('registerTexture throws StateError on null result', () async {
    const binding = TextureBinding();
    await expectLater(binding.registerTexture(7), throwsStateError);
  });

  test('updateSurface, frameReady, unregisterTexture send exact payloads',
      () async {
    const binding = TextureBinding();
    await binding.updateSurface(42, 9);
    await binding.frameReady(42);
    await binding.unregisterTexture(42);
    expect(calls.map((c) => c.method).toList(),
        ['updateSurface', 'frameReady', 'unregisterTexture']);
    expect(calls[0].arguments, {'textureId': 42, 'surfaceId': 9});
    expect(calls[1].arguments, {'textureId': 42});
    expect(calls[2].arguments, {'textureId': 42});
  });

  test('PlatformException propagates untouched', () async {
    handler = (_) => throw PlatformException(code: 'surfaceNotFound');
    const binding = TextureBinding();
    await expectLater(
      binding.registerTexture(999),
      throwsA(isA<PlatformException>()
          .having((e) => e.code, 'code', 'surfaceNotFound')),
    );
  });
}
