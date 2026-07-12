import 'package:flutter/material.dart';
import 'package:jet_cad/jet_cad.dart';

/// Dev harness: manual verification of the jet_cad viewport.
/// Public package API only — if something here needs an import from
/// package:jet_cad/src/..., the package surface is wrong.
void main() {
  runApp(const MaterialApp(home: HarnessPage()));
}

class HarnessPage extends StatefulWidget {
  const HarnessPage({super.key});

  @override
  State<HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<HarnessPage> {
  CadDocument? _doc;
  ViewportController? _controller;
  String _status = 'starting…';
  Set<EntityId> _selection = const {};

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
            'native lib not found — run packages/jet_cad/tool/run_harness.sh');
        return;
      }
      final bridge = FfiKernelBridge(libPath);
      final doc =
          await CadDocument.create(bridge, target: const TextureTarget());
      final controller = ViewportController(document: doc);
      controller.selectionChanges
          .listen((event) => setState(() => _selection = event.selection));
      setState(() {
        _doc = doc;
        _controller = controller;
        _status = 'ready';
      });
    } catch (e) {
      setState(() => _status = 'FAILED: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      setState(() => _status = 'ready');
    } catch (e) {
      setState(() => _status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final controller = _controller;
    final selection = _selection.map((e) => e.value).join(', ');
    return Scaffold(
      appBar: AppBar(title: Text('jet_cad harness — $_status')),
      body: doc == null || controller == null
          ? Center(child: Text(_status))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _guard(() async {
                          await doc.makeBox(const Vec3(40, 30, 20));
                          await controller.fitAll();
                        }),
                        child: const Text('Add box'),
                      ),
                      FilledButton(
                        onPressed: () => _guard(doc.undo),
                        child: const Text('Undo'),
                      ),
                      FilledButton(
                        onPressed: () => _guard(doc.redo),
                        child: const Text('Redo'),
                      ),
                      FilledButton(
                        onPressed: () => _guard(controller.fitAll),
                        child: const Text('Fit'),
                      ),
                      Text('selection: ${selection.isEmpty ? '—' : selection}'),
                    ],
                  ),
                ),
                Expanded(child: JetCadViewport(controller: controller)),
              ],
            ),
    );
  }
}
