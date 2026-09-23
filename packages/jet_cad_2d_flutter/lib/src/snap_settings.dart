import 'package:flutter/foundation.dart';

/// F3's object-snap toggle (spec D10). The shell owns it; a drag reads it
/// per event through `ToolContext.snap`.
class SnapSettings extends ChangeNotifier {
  SnapSettings({bool objectSnap = true}) : _objectSnap = objectSnap;

  bool _objectSnap;
  bool get objectSnap => _objectSnap;

  void toggleObjectSnap() {
    _objectSnap = !_objectSnap;
    notifyListeners();
  }
}
