import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jet_cad/jet_cad.dart';

/// Spike harness: proves shim-rendered IOSurface pixels composite in Flutter.
///
/// Expected on screen (after the flipY wrapper): red top-left, green
/// top-right, blue bottom-left, white bottom-right. If the quadrants land
/// elsewhere, the orientation finding in the plan/ledger must be corrected.
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
      final init = await bridge.debugExecute(
          session, {'cmd': 'debugInitTexture', 'width': 512, 'height': 512});
      final surfaceId = init['surfaceId'] as int;
      final textureId = await _channel
          .invokeMethod<int>('registerTexture', {'surfaceId': surfaceId});
      await bridge.debugExecute(session, {'cmd': 'debugRenderTestPattern'});
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
      appBar: AppBar(title: Text('jet_cad spike — $_status')),
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
