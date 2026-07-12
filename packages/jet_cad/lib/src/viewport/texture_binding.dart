import 'package:flutter/services.dart';

/// Bridges IOSurface ids from the kernel to Flutter external texture ids via
/// the macOS plugin's `jet_cad/texture` MethodChannel.
///
/// Internal plumbing for [ViewportController]; not exported by the package.
/// Instance-based (const) so tests substitute a subclass fake.
class TextureBinding {
  const TextureBinding();

  static const MethodChannel _channel = MethodChannel('jet_cad/texture');

  /// Wraps the IOSurface [surfaceId] in a CVPixelBuffer and registers it as
  /// a Flutter external texture. Returns the texture id for [Texture].
  Future<int> registerTexture(int surfaceId) async {
    final textureId = await _channel
        .invokeMethod<int>('registerTexture', {'surfaceId': surfaceId});
    if (textureId == null) {
      throw StateError('registerTexture returned null texture id');
    }
    return textureId;
  }

  /// Re-wraps [textureId] onto a new IOSurface after a resize reallocation.
  Future<void> updateSurface(int textureId, int surfaceId) =>
      _channel.invokeMethod<void>(
          'updateSurface', {'textureId': textureId, 'surfaceId': surfaceId});

  /// Tells the compositor a new frame is in the surface (damage signal).
  Future<void> frameReady(int textureId) =>
      _channel.invokeMethod<void>('frameReady', {'textureId': textureId});

  /// Unregisters the texture. Safe to call once during dispose; the platform
  /// side treats unknown ids as a no-op.
  Future<void> unregisterTexture(int textureId) => _channel
      .invokeMethod<void>('unregisterTexture', {'textureId': textureId});
}
