import 'package:jet_cad/src/viewport/texture_binding.dart';

/// Records channel traffic instead of touching a real platform channel.
class FakeBinding extends TextureBinding {
  FakeBinding();
  final List<String> log = [];
  int nextTextureId = 7;

  @override
  Future<int> registerTexture(int surfaceId) async {
    log.add('register $surfaceId');
    return nextTextureId;
  }

  @override
  Future<void> updateSurface(int textureId, int surfaceId) async {
    log.add('update $textureId $surfaceId');
  }

  @override
  Future<void> frameReady(int textureId) async {
    log.add('frame $textureId');
  }

  @override
  Future<void> unregisterTexture(int textureId) async {
    log.add('unregister $textureId');
  }
}
