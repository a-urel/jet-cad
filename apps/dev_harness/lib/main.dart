import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jet_cad/jet_cad.dart';

/// Dev harness: proves the real OCCT V3d/AIS viewer renders a shaded box
/// into the shim's IOSurface framebuffer and composites in Flutter.
void main() {
  runApp(const MaterialApp(home: SpikePage()));
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  static const _channel = MethodChannel('jet_cad/texture');

  FfiKernelBridge? _bridge;
  SessionHandle? _session;
  int? _textureId;
  String _status = 'starting…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final libPath = FfiKernelBridge.locateLibrary();
      if (libPath == null) {
        setState(() => _status =
            'native lib not found — run tool/run_harness.sh from repo root');
        return;
      }
      final bridge = FfiKernelBridge(libPath);
      final session = await bridge.createSession(const HeadlessTarget());
      final init = await bridge.debugExecute(session, {
        'cmd': 'initViewer',
        'width': 512,
        'height': 512,
        'pixelRatio': 1.0,
      });
      final surfaceId = init['surfaceId'] as int;
      final textureId = await _channel
          .invokeMethod<int>('registerTexture', {'surfaceId': surfaceId});
      await bridge.debugExecute(session, {
        'cmd': 'makeBox',
        'size': [50.0, 50.0, 50.0]
      });
      await bridge.debugExecute(session, {'cmd': 'cameraFit'});
      await bridge.debugExecute(session, {'cmd': 'renderFrame'});
      await _channel.invokeMethod<void>('frameReady', {'textureId': textureId});
      setState(() {
        _bridge = bridge;
        _session = session;
        _textureId = textureId;
        _status = 'texture $textureId on IOSurface $surfaceId';
      });
    } catch (e) {
      setState(() => _status = 'FAILED: $e');
    }
  }

  @override
  void dispose() {
    final session = _session;
    if (session != null) {
      _bridge?.disposeSession(session);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('jet_cad viewer — $_status')),
      body: Center(
        child: _textureId == null
            ? const CircularProgressIndicator()
            : SizedBox(
                width: 512,
                height: 512,
                // GL rows are bottom-up; flip so GL "top" renders at the top.
                child: Transform.flip(
                  flipY: true,
                  child: Texture(textureId: _textureId!),
                ),
              ),
      ),
    );
  }
}
