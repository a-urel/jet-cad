import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {
      markTestSkipped('native library not built');
    });
    return;
  }

  late FfiKernelBridge bridge;
  late SessionHandle session;

  setUp(() async {
    bridge = FfiKernelBridge(libPath);
    session = await bridge.createSession(const TextureTarget());
    await bridge.resizeViewport(session, 128, 128, 1.0);
  });

  tearDown(() async {
    await bridge.disposeSession(session);
    await bridge.shutdown();
  });

  Future<List<int>> centerPixel() async {
    final result = await bridge.debugExecute(session, {
      'cmd': 'debugReadPixels',
      'x': 64,
      'y': 64,
      'width': 1,
      'height': 1,
    });
    return base64Decode(result['rgbaBase64'] as String);
  }

  // Selection highlighting in this native configuration recolors only the
  // selected shape's silhouette/edges (confirmed empirically: selecting a
  // fitted box changes ~500 of 16384 pixels, all along edge scanlines, never
  // the face fill) — not the whole face, so the view CENTER pixel of a
  // fitted box's front face never changes on selection. Read the whole frame
  // instead of one pixel so the assertion holds regardless of exactly where
  // the highlight is drawn.
  Future<List<int>> fullFrame() async {
    final result = await bridge.debugExecute(session, {
      'cmd': 'debugReadPixels',
      'x': 0,
      'y': 0,
      'width': 128,
      'height': 128,
    });
    return base64Decode(result['rgbaBase64'] as String);
  }

  test('fitted box covers the view center', () async {
    await bridge.renderFrame(session);
    final background = await centerPixel();
    await bridge.makeBox(session, const Vec3(50, 50, 50));
    await bridge.fitAll(session);
    await bridge.renderFrame(session);
    expect(await centerPixel(), isNot(background));
  });

  test('pick at center hits the box body and one of its faces', () async {
    final box = await bridge.makeBox(session, const Vec3(50, 50, 50));
    await bridge.fitAll(session);
    await bridge.renderFrame(session);
    final bodyHit = await bridge.pick(session, 64, 64, PickFilter.body);
    expect(bodyHit?.body, box.body);
    expect(bodyHit?.entity, box.body);
    final faceHit = await bridge.pick(session, 64, 64, PickFilter.face);
    expect(faceHit?.body, box.body);
    expect(box.faces, contains(faceHit?.entity));
  });

  test('selection highlight changes rendered pixels', () async {
    final box = await bridge.makeBox(session, const Vec3(50, 50, 50));
    await bridge.fitAll(session);
    await bridge.renderFrame(session);
    final before = await fullFrame();
    await bridge.setSelection(session, [box.body]);
    await bridge.renderFrame(session);
    expect(await fullFrame(), isNot(before),
        reason: 'highlight must be visible somewhere in the rendered frame');
  });
}
