// The document session: what the app knows about the plan's file, beside the
// controller (spec B2). Ported from apps/floor_planner/lib/document_host.dart
// (DocumentSession), without the document, the measurer or the save point:
// those are the PlanController's.
import 'package:flutter/foundation.dart';

import 'document_files.dart' show kJetplanExtension;

/// The name of a plan that has no file yet.
const String kUntitledName = 'Untitled';

/// The web tab's title: `name — jet-cad`, with `• ` in front while [dirty].
String documentTitle(String name, {required bool dirty}) =>
    '${dirty ? '• ' : ''}$name — jet-cad';

/// The name a file shows as: its base name without `.jetplan`. Another
/// extension is kept.
String documentNameOf(String fileName) {
  const suffix = '.$kJetplanExtension';
  return fileName.endsWith(suffix) && fileName.length > suffix.length
      ? fileName.substring(0, fileName.length - suffix.length)
      : fileName;
}

/// What the app knows about the plan's file, beside the controller: its
/// name and location, the untitled name in the app's language, and whether
/// a flow runs. Dirty is the controller's (`PlanController.dirty`).
///
/// Notifies when the name or the location changes; [busy] notifies for
/// itself.
class DocumentSession extends ChangeNotifier {
  String? _fileName;
  Object? _location;
  String _untitledName = kUntitledName;

  /// Whether a flow is running. Set by the outermost flow only.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// The file's name, with its extension; null while untitled.
  String? get fileName => _fileName;

  /// Where a Save writes, as the files object returned it; opaque here.
  Object? get location => _location;

  /// [untitledName], or [fileName] without `.jetplan`.
  String get name =>
      _fileName == null ? _untitledName : documentNameOf(_fileName!);

  String get untitledName => _untitledName;

  /// Sets [untitledName] without notifying (the host sets it during a
  /// build); true when the shown [name] changed, and the host then calls
  /// [nameChanged] after the frame.
  bool setUntitledName(String next) {
    if (next == _untitledName) return false;
    _untitledName = next;
    return _fileName == null;
  }

  /// Tells the listeners that [name] changed with the language.
  void nameChanged() => notifyListeners();

  /// The plan is now the file [fileName] at [location] (untitled when
  /// null). One notification.
  void named(String? fileName, Object? location) {
    _fileName = fileName;
    _location = location;
    notifyListeners();
  }

  bool _disposed = false;

  /// True once [dispose] ran: a flow still in flight must not touch [busy].
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    busy.dispose();
    super.dispose();
  }
}
