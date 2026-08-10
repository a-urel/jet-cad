import 'dart:ui';

/// Records what reaches `dart:ui`.
///
/// `CanvasDrawSink` reuses one `Paint` across ops, so the paint is snapshotted
/// at call time; holding the reference would show every call the last colour.
class SpyCanvas implements Canvas {
  final List<RecordedCall> calls = <RecordedCall>[];

  Iterable<RecordedCall> named(String name) =>
      calls.where((c) => c.name == name);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    Paint? paint;
    for (final a in args) {
      if (a is Paint) paint = a;
    }
    calls.add(RecordedCall(
      _nameOf(invocation.memberName),
      args,
      color: paint?.color,
      strokeWidth: paint?.strokeWidth,
      paintingStyle: paint?.style,
    ));
    return null;
  }
}

class RecordedCall {
  RecordedCall(this.name, this.args,
      {this.color, this.strokeWidth, this.paintingStyle});

  final String name;
  final List<Object?> args;
  final Color? color;
  final double? strokeWidth;
  final PaintingStyle? paintingStyle;
}

String _nameOf(Symbol s) {
  final text = s.toString(); // Symbol("drawPath")
  return text.substring(text.indexOf('"') + 1, text.lastIndexOf('"'));
}
