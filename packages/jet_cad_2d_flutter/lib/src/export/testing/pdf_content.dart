import 'dart:convert' show latin1;
import 'dart:math' as math;
import 'dart:typed_data';

/// Inflates a `/FlateDecode` stream (tests pass `zlib.decode` from
/// `dart:io`). It is a callback so this library needs no `dart:io`.
typedef PdfInflate = List<int> Function(List<int> data);

/// A test instrument: it reads the one page of a PDF back into page-space
/// geometry (plan 13, P-2).
///
/// It does the following:
/// - finds the page;
/// - concatenates and decodes its content streams;
/// - tokenises them;
/// - runs the graphics state (`q`/`Q`, `cm`, colours, widths, `gs`, the text
///   state);
/// - records every path, with its points carried to page space by the CTM in
///   force when the path was built, and every text run.
///
/// **It is not a renderer**, and it stays strict. An operator that moves
/// geometry and that it does not model throws [UnsupportedError] rather
/// than being passed over silently: `Tc Tw Ts TL T* TD ' " d Do BI sh W W*`.
///
/// Matrices follow the PDF convention (ISO 32000-1, 8.3.4). A point is a row
/// vector and `[a b c d e f]` maps `(x, y)` to `(a·x + c·y + e,
/// b·x + d·y + f)`. `M cm` sets `CTM' = M × CTM`.
final class PdfContent {
  PdfContent._(this.mediaBox, this.operators, this.paths, this.textRuns);

  /// Reads [bytes], a whole PDF file with exactly one page.
  ///
  /// Objects are found by a sequential scan for `N G obj … endobj`. The
  /// scan never looks inside a stream's data, so the xref table is not
  /// needed.
  factory PdfContent.parse(Uint8List bytes, {required PdfInflate inflate}) {
    final file = _PdfFile(latin1.decode(bytes), inflate);
    final pages = [
      for (final o in file.objects.values)
        if (o.value case final Map<String, Object?> d
            when d['/Type'] == const PdfRawName('/Page'))
          d,
    ];
    if (pages.length != 1) {
      throw FormatException('expected one /Page, found ${pages.length}');
    }
    final page = pages.single;
    final mediaBox = [
      for (final v in file.resolve(page['/MediaBox']) as List<Object?>)
        (file.resolve(v) as num).toDouble(),
    ];
    // A page with nothing painted has no /Contents at all: the pdf package
    // drops a content stream that painted nothing.
    final contents = file.resolve(page['/Contents']);
    final parts = <String>[];
    for (final c in contents == null
        ? const <Object?>[]
        : contents is List<Object?>
            ? contents
            : [contents]) {
      parts.add(latin1.decode(file.streamData(file.resolve(c))));
    }
    final resources =
        file.resolve(page['/Resources']) as Map<String, Object?>? ?? const {};
    final interpreter = _Interpreter(file, resources);
    // Content streams of one page are one stream for parsing (ISO 32000-1,
    // 7.8.2), separated by whitespace.
    interpreter.run(parts.join('\n'));
    return PdfContent._(
      mediaBox,
      interpreter.operators,
      interpreter.paths,
      interpreter.texts,
    );
  }

  /// The page's `/MediaBox`: `[x0, y0, x1, y1]`.
  final List<double> mediaBox;

  /// Every operator in the content stream, in order, with its operands.
  final List<PdfContentOp> operators;

  /// Every painted path, in order (`n`, which paints nothing, included).
  final List<PdfContentPath> paths;

  /// Every `TJ` and `Tj`, in order.
  final List<PdfContentText> textRuns;

  /// The operator names alone, in order.
  List<String> get operatorNames => [for (final o in operators) o.name];
}

/// A PDF matrix `[a b c d e f]`, row-vector convention (see [PdfContent]).
final class PdfContentMatrix {
  const PdfContentMatrix(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = PdfContentMatrix(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, e, f;

  /// `this × other`: [this] applies first, then [other]. `M cm` sets the CTM
  /// to `M.times(ctm)`.
  PdfContentMatrix times(PdfContentMatrix o) => PdfContentMatrix(
        a * o.a + b * o.c,
        a * o.b + b * o.d,
        c * o.a + d * o.c,
        c * o.b + d * o.d,
        e * o.a + f * o.c + o.e,
        e * o.b + f * o.d + o.f,
      );

  PdfXY apply(double x, double y) =>
      (x: a * x + c * y + e, y: b * x + d * y + f);

  /// The image of a direction (no translation).
  PdfXY applyToVector(double x, double y) =>
      (x: a * x + c * y, y: b * x + d * y);

  double get determinant => a * d - b * c;

  /// `sqrt(|det|)`: the representative scale of the linear part.
  double get scale => math.sqrt(determinant.abs());

  @override
  String toString() => '[$a $b $c $d $e $f]';
}

/// A point in page space (PDF user space at the page level, y up).
typedef PdfXY = ({double x, double y});

/// One operator and its operands, as written.
///
/// An operand is a [num], a [PdfRawName], a [PdfRawString], a `bool`,
/// `null`, a `List<Object?>` or a `Map<String, Object?>`.
final class PdfContentOp {
  const PdfContentOp(this.name, this.operands);

  final String name;
  final List<Object?> operands;

  @override
  String toString() => '${operands.join(' ')} $name';
}

/// How a path was painted.
enum PdfPaint { stroke, fill, fillAndStroke, none }

/// One path, with the graphics state in force when it was painted.
final class PdfContentPath {
  PdfContentPath({
    required this.subpaths,
    required this.paint,
    required this.evenOdd,
    required this.state,
    required this.operatorIndex,
  });

  final List<PdfContentSubpath> subpaths;
  final PdfPaint paint;
  final bool evenOdd;
  final PdfContentState state;

  /// The index in [PdfContent.operators] of the operator that painted it.
  final int operatorIndex;

  bool get strokes =>
      paint == PdfPaint.stroke || paint == PdfPaint.fillAndStroke;
  bool get fills => paint == PdfPaint.fill || paint == PdfPaint.fillAndStroke;

  /// The stroke width in page units: `w` times the CTM's scale (`sqrt|det|`).
  double get deviceLineWidth => state.lineWidth * state.ctm.scale;
}

/// One subpath: a start point and the segments after it, in page space.
final class PdfContentSubpath {
  PdfContentSubpath(this.start);

  final PdfXY start;
  final List<PdfContentSegment> segments = [];

  /// Closed by `h`, `re`, `s`, `b` or `b*`.
  bool closed = false;

  /// The on-curve points: [start] and every segment's end point.
  List<PdfXY> get vertices => [start, for (final s in segments) s.to];
}

/// A `l` segment (no controls) or a `c`/`v`/`y` cubic (two controls).
final class PdfContentSegment {
  PdfContentSegment.line(this.to) : controls = const [];
  PdfContentSegment.cubic(PdfXY c1, PdfXY c2, this.to) : controls = [c1, c2];

  final PdfXY to;
  final List<PdfXY> controls;

  bool get isCubic => controls.isNotEmpty;
}

/// The part of the graphics state the reader models.
final class PdfContentState {
  PdfContentState();

  PdfContentMatrix ctm = PdfContentMatrix.identity;
  double lineWidth = 1.0; // PDF's initial value
  int lineCap = 0;
  int lineJoin = 0;
  double miterLimit = 10.0;
  List<double> strokeRgb = const [0, 0, 0];
  List<double> fillRgb = const [0, 0, 0];

  /// `CA` (stroking) and `ca` (non-stroking) alpha from the last `gs`.
  double strokeAlpha = 1.0;
  double fillAlpha = 1.0;

  /// The `gs` resource names applied, in order, since the state was saved.
  /// Copied by `q`, so a name set inside `q … Q` is gone after it.
  List<String> extGStates = const [];

  /// The text state `Tf` and `Tz` set. It is part of the graphics state
  /// (ISO 32000-1, 8.4.1 and 9.3.1), so `q` saves it and `Q` restores it.
  String? fontResource;
  double fontSize = 0;

  /// `Tz`, in percent (100 initially).
  double horizontalScale = 100;

  PdfContentState copy() => PdfContentState()
    ..ctm = ctm
    ..lineWidth = lineWidth
    ..lineCap = lineCap
    ..lineJoin = lineJoin
    ..miterLimit = miterLimit
    ..strokeRgb = strokeRgb
    ..fillRgb = fillRgb
    ..strokeAlpha = strokeAlpha
    ..fillAlpha = fillAlpha
    ..extGStates = extGStates
    ..fontResource = fontResource
    ..fontSize = fontSize
    ..horizontalScale = horizontalScale;
}

/// One `TJ` or `Tj`.
final class PdfContentText {
  PdfContentText({
    required this.fontResource,
    required this.font,
    required this.fontInfo,
    required this.size,
    required this.horizontalScale,
    required this.textMatrix,
    required this.ctm,
    required this.codes,
    required this.string,
    required this.advance,
    required this.state,
    required this.operatorIndex,
  });

  /// The resource name `Tf` selected, e.g. `/F1`.
  final String fontResource;

  /// The font dictionary (indirect values resolved one level).
  final Map<String, Object?> font;

  /// What [font] declares, followed through the file's references.
  final PdfContentFontInfo fontInfo;

  /// `Tf`'s size.
  final double size;

  /// `Tz`, in percent (100 when not set).
  final double horizontalScale;

  /// The text matrix at the start of the run, in text space.
  final PdfContentMatrix textMatrix;

  /// The CTM in force.
  final PdfContentMatrix ctm;

  /// The run's character codes: CIDs (two bytes each) for a `/Type0` font,
  /// single bytes otherwise.
  final List<int> codes;

  /// The codes mapped through the font's `/ToUnicode`, or `null` when the
  /// font has none.
  final String? string;

  /// The run's advance in unscaled text space (before the text matrix):
  /// `sum(w / 1000) · size · Tz / 100`, minus each `TJ` number
  /// `/ 1000 · size · Tz / 100`. The widths `w` are read from the font's
  /// `/W` (CID fonts, default `/DW`) or `/Widths`.
  final double advance;

  final PdfContentState state;
  final int operatorIndex;

  /// The text matrix in page space: `Tm × CTM`.
  PdfContentMatrix get pageMatrix => textMatrix.times(ctm);

  /// The run's origin in page space.
  PdfXY get origin => pageMatrix.apply(0, 0);
}

/// What a font dictionary declares about its kind and its program, with every
/// reference followed (ISO 32000-1, 9.6 to 9.9).
final class PdfContentFontInfo {
  const PdfContentFontInfo({
    required this.subtype,
    required this.encoding,
    required this.descendantSubtype,
    required this.fontFile,
  });

  /// The font's `/Subtype`, e.g. `/Type0` or `/TrueType`.
  final String? subtype;

  /// The font's `/Encoding` when it is a name, e.g. `/Identity-H`.
  final String? encoding;

  /// For a `/Type0` font, its descendant's `/Subtype` (`/CIDFontType2` for
  /// TrueType outlines); `null` otherwise.
  final String? descendantSubtype;

  /// The key under which the font descriptor embeds the font program as a
  /// stream: `/FontFile`, `/FontFile2` or `/FontFile3`; `null` when nothing
  /// is embedded. For a `/Type0` font the descriptor is the descendant's.
  final String? fontFile;
}

/// A name, slash included: `/Type`.
final class PdfRawName {
  const PdfRawName(this.name);

  final String name;

  @override
  bool operator ==(Object other) => other is PdfRawName && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// A string's bytes, from either the literal or the hex form.
final class PdfRawString {
  const PdfRawString(this.bytes, {required this.hex});

  final List<int> bytes;
  final bool hex;

  @override
  String toString() => hex
      ? '<${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}>'
      : '(${latin1.decode(bytes)})';
}

/// An indirect reference `N G R`.
final class PdfRawRef {
  const PdfRawRef(this.id, this.generation);

  final int id;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is PdfRawRef && other.id == id && other.generation == generation;

  @override
  int get hashCode => Object.hash(id, generation);

  @override
  String toString() => '$id $generation R';
}

/// A stream object: its dictionary and its raw (still encoded) data.
final class PdfRawStream {
  const PdfRawStream(this.dict, this.data);

  final Map<String, Object?> dict;
  final List<int> data;
}

// ---------------------------------------------------------------------------
// The file

final class _PdfObject {
  _PdfObject(this.value, [this.stream]);

  final Object? value;
  final PdfRawStream? stream;
}

final class _PdfFile {
  _PdfFile(this.text, this.inflate) {
    _scan();
  }

  final String text;
  final PdfInflate inflate;
  final Map<int, _PdfObject> objects = {};

  static final _objHeader = RegExp(r'(\d+)\s+(\d+)\s+obj\b');

  void _scan() {
    var pos = 0;
    while (true) {
      final m = _objHeader.allMatches(text, pos).firstOrNull;
      if (m == null) break;
      final lexer = _Lexer(text, m.end);
      final parser = _Parser(lexer);
      final value = parser.object();
      PdfRawStream? stream;
      // Through the parser: a value that was a lone integer has already read
      // the token after it, and that token is waiting there.
      final t = parser.nextToken();
      if (t is _Keyword && t.word == 'stream') {
        var start = lexer.pos;
        if (text.startsWith('\r\n', start)) {
          start += 2;
        } else if (text.startsWith('\n', start) ||
            text.startsWith('\r', start)) {
          start += 1;
        }
        final dict = value as Map<String, Object?>;
        final length = dict['/Length'];
        int end;
        if (length is num) {
          end = start + length.toInt();
        } else {
          end = text.indexOf('endstream', start);
          while (end > start && ' \r\n'.contains(text[end - 1])) {
            end--;
          }
        }
        stream = PdfRawStream(
          dict,
          Uint8List.fromList(latin1.encode(text.substring(start, end))),
        );
        final endstream = text.indexOf('endstream', end);
        if (endstream < 0) throw const FormatException('no endstream');
        pos = text.indexOf('endobj', endstream);
      } else if (t is _Keyword && t.word == 'endobj') {
        pos = lexer.pos - 'endobj'.length;
      } else {
        throw FormatException('object ${m.group(1)}: expected endobj, got $t');
      }
      if (pos < 0) throw FormatException('object ${m.group(1)}: no endobj');
      objects[int.parse(m.group(1)!)] = _PdfObject(value, stream);
      pos += 'endobj'.length;
    }
  }

  /// [v] with an indirect reference replaced by the object it names. A stream
  /// object resolves to its [PdfRawStream].
  Object? resolve(Object? v) {
    if (v is! PdfRawRef) return v;
    final o = objects[v.id];
    if (o == null) throw FormatException('no object ${v.id}');
    return o.stream ?? o.value;
  }

  /// The decoded data of [stream]: `/FlateDecode` through the callback.
  /// Any other filter throws (the reader never decodes a font file, the one
  /// stream the package writes in `/ASCII85Decode`).
  List<int> streamData(Object? stream) {
    if (stream is! PdfRawStream) {
      throw FormatException('expected a stream, got $stream');
    }
    var data = stream.data;
    final filter = resolve(stream.dict['/Filter']);
    final filters = filter == null
        ? const <Object?>[]
        : filter is List<Object?>
            ? filter
            : [filter];
    for (final f in filters) {
      data = switch ((resolve(f) as PdfRawName).name) {
        '/FlateDecode' => inflate(data),
        final other => throw UnsupportedError('filter $other'),
      };
    }
    return data;
  }
}

// ---------------------------------------------------------------------------
// Lexing and parsing

sealed class _Token {}

final class _Value extends _Token {
  _Value(this.value);
  final Object? value;
}

final class _Keyword extends _Token {
  _Keyword(this.word);
  final String word;
}

final class _Open extends _Token {
  _Open(this.kind);
  final String kind; // '[' or '<<'
}

final class _Close extends _Token {
  _Close(this.kind);
  final String kind; // ']' or '>>'
}

final class _End extends _Token {}

final class _Lexer {
  _Lexer(this.s, this.pos);

  final String s;
  int pos;

  static bool _isWhite(int c) =>
      c == 0x00 ||
      c == 0x09 ||
      c == 0x0A ||
      c == 0x0C ||
      c == 0x0D ||
      c == 0x20;

  static bool _isDelimiter(int c) => '()<>[]{}/%'.codeUnits.contains(c);

  static final _number = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$');

  void _skip() {
    while (pos < s.length) {
      final c = s.codeUnitAt(pos);
      if (_isWhite(c)) {
        pos++;
      } else if (c == 0x25) {
        // '%' comment to the end of the line.
        while (pos < s.length && s[pos] != '\n' && s[pos] != '\r') {
          pos++;
        }
      } else {
        return;
      }
    }
  }

  _Token next() {
    _skip();
    if (pos >= s.length) return _End();
    final c = s[pos];
    if (c == '[') {
      pos++;
      return _Open('[');
    }
    if (c == ']') {
      pos++;
      return _Close(']');
    }
    if (s.startsWith('<<', pos)) {
      pos += 2;
      return _Open('<<');
    }
    if (s.startsWith('>>', pos)) {
      pos += 2;
      return _Close('>>');
    }
    if (c == '<') return _Value(_hexString());
    if (c == '(') return _Value(_literalString());
    if (c == '/') return _Value(_name());
    if (c == '{' || c == '}' || c == ')' || c == '>') {
      throw FormatException('unexpected "$c" at $pos');
    }
    final start = pos;
    while (pos < s.length &&
        !_isWhite(s.codeUnitAt(pos)) &&
        !_isDelimiter(s.codeUnitAt(pos))) {
      pos++;
    }
    final word = s.substring(start, pos);
    if (_number.hasMatch(word)) {
      return _Value(
          word.contains('.') ? double.parse(_dotted(word)) : int.parse(word));
    }
    return switch (word) {
      'true' => _Value(true),
      'false' => _Value(false),
      'null' => _Value(null),
      _ => _Keyword(word),
    };
  }

  /// `.5` and `-.5` as Dart parses them: `0.5`, `-0.5`; `3.` as `3.0`.
  static String _dotted(String w) {
    var t = w;
    if (t.endsWith('.')) t = '${t}0';
    if (t.startsWith('.')) return '0$t';
    if (t.startsWith('-.')) return '-0${t.substring(1)}';
    if (t.startsWith('+.')) return '0${t.substring(1)}';
    return t;
  }

  PdfRawName _name() {
    final start = pos;
    pos++;
    while (pos < s.length &&
        !_isWhite(s.codeUnitAt(pos)) &&
        !_isDelimiter(s.codeUnitAt(pos))) {
      pos++;
    }
    final raw = s.substring(start, pos);
    return PdfRawName(raw.replaceAllMapped(RegExp('#([0-9A-Fa-f]{2})'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16))));
  }

  PdfRawString _hexString() {
    pos++; // '<'
    final end = s.indexOf('>', pos);
    if (end < 0) throw FormatException('unterminated hex string at $pos');
    var hex = s.substring(pos, end).replaceAll(RegExp(r'\s'), '');
    pos = end + 1;
    if (hex.length.isOdd) hex = '${hex}0';
    return PdfRawString([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ], hex: true);
  }

  PdfRawString _literalString() {
    pos++; // '('
    final out = <int>[];
    var depth = 1;
    while (pos < s.length) {
      final c = s[pos++];
      if (c == '\\') {
        final e = s[pos++];
        switch (e) {
          case 'n':
            out.add(0x0A);
          case 'r':
            out.add(0x0D);
          case 't':
            out.add(0x09);
          case 'b':
            out.add(0x08);
          case 'f':
            out.add(0x0C);
          case '\r':
            if (pos < s.length && s[pos] == '\n') pos++;
          case '\n':
            break;
          default:
            if (RegExp('[0-7]').hasMatch(e)) {
              var octal = e;
              while (octal.length < 3 &&
                  pos < s.length &&
                  RegExp('[0-7]').hasMatch(s[pos])) {
                octal += s[pos++];
              }
              out.add(int.parse(octal, radix: 8) & 0xFF);
            } else {
              out.add(e.codeUnitAt(0)); // \( \) \\ and any other
            }
        }
      } else if (c == '(') {
        depth++;
        out.add(0x28);
      } else if (c == ')') {
        depth--;
        if (depth == 0) return PdfRawString(out, hex: false);
        out.add(0x29);
      } else {
        out.add(c.codeUnitAt(0));
      }
    }
    throw const FormatException('unterminated literal string');
  }
}

final class _Parser {
  _Parser(this.lexer);

  final _Lexer lexer;
  final List<_Token> _pending = [];

  _Token _next() => _pending.isNotEmpty ? _pending.removeLast() : lexer.next();

  /// The next token, a pushed-back one first.
  _Token nextToken() => _next();
  void _push(_Token t) => _pending.add(t);

  /// One complete object at the lexer's position.
  Object? object() {
    final t = _next();
    return _value(t);
  }

  Object? _value(_Token t) {
    switch (t) {
      case _Value(:final value):
        if (value is int) return _maybeRef(value);
        return value;
      case _Open(kind: '['):
        final list = <Object?>[];
        while (true) {
          final n = _next();
          if (n is _Close && n.kind == ']') return list;
          if (n is _End) throw const FormatException('unterminated array');
          list.add(_value(n));
        }
      case _Open(kind: '<<'):
        final dict = <String, Object?>{};
        while (true) {
          final k = _next();
          if (k is _Close && k.kind == '>>') return dict;
          if (k is! _Value || k.value is! PdfRawName) {
            throw FormatException('dictionary key expected, got $k');
          }
          dict[(k.value as PdfRawName).name] = _value(_next());
        }
      case _Keyword(:final word):
        throw FormatException('unexpected keyword $word');
      default:
        throw FormatException('unexpected token $t');
    }
  }

  /// `N G R` is a reference; a lone integer is itself.
  Object? _maybeRef(int first) {
    final second = _next();
    if (second is _Value && second.value is int) {
      final third = _next();
      if (third is _Keyword && third.word == 'R') {
        return PdfRawRef(first, second.value as int);
      }
      _push(third);
    }
    _push(second);
    return first;
  }
}

// ---------------------------------------------------------------------------
// The content stream

final class _Interpreter {
  _Interpreter(this.file, this.resources);

  final _PdfFile file;
  final Map<String, Object?> resources;

  final operators = <PdfContentOp>[];
  final paths = <PdfContentPath>[];
  final texts = <PdfContentText>[];

  var _state = PdfContentState();
  final _saved = <PdfContentState>[];

  List<PdfContentSubpath> _path = [];
  PdfXY? _current; // in user space, before the CTM
  PdfXY? _subpathStart;

  // Text state.
  var _tm = PdfContentMatrix.identity;
  var _tlm = PdfContentMatrix.identity;
  var _inText = false;

  static const _unsupported = {
    'Tc', 'Tw', 'Ts', 'TL', 'T*', 'TD', "'", '"', 'd', 'Do', 'BI', 'sh', //
    'W', 'W*',
  };

  void run(String content) {
    final lexer = _Lexer(content, 0);
    final parser = _Parser(lexer);
    final operands = <Object?>[];
    while (true) {
      final t = lexer.next();
      if (t is _End) break;
      if (t is _Keyword) {
        _op(t.word, List.of(operands));
        operands.clear();
      } else if (t is _Value) {
        // No references in a content stream: an integer is an integer.
        operands.add(t.value);
      } else {
        operands.add(parser._value(t));
      }
    }
    if (operands.isNotEmpty) {
      throw FormatException('operands with no operator: $operands');
    }
  }

  double _n(List<Object?> o, int i) => (o[i] as num).toDouble();

  PdfXY _toPage(double x, double y) => _state.ctm.apply(x, y);

  void _op(String name, List<Object?> o) {
    operators.add(PdfContentOp(name, o));
    if (_unsupported.contains(name)) {
      throw UnsupportedError('the reader does not model "$name"');
    }
    switch (name) {
      case 'q':
        _saved.add(_state.copy());
      case 'Q':
        if (_saved.isEmpty) throw const FormatException('Q without q');
        _state = _saved.removeLast();
      case 'cm':
        _state.ctm = PdfContentMatrix(
          _n(o, 0), _n(o, 1), _n(o, 2), _n(o, 3), _n(o, 4), _n(o, 5), //
        ).times(_state.ctm);
      case 'w':
        _state.lineWidth = _n(o, 0);
      case 'J':
        _state.lineCap = (o[0] as num).toInt();
      case 'j':
        _state.lineJoin = (o[0] as num).toInt();
      case 'M':
        _state.miterLimit = _n(o, 0);
      case 'RG':
        _state.strokeRgb = [_n(o, 0), _n(o, 1), _n(o, 2)];
      case 'rg':
        _state.fillRgb = [_n(o, 0), _n(o, 1), _n(o, 2)];
      case 'G':
        _state.strokeRgb = [_n(o, 0), _n(o, 0), _n(o, 0)];
      case 'g':
        _state.fillRgb = [_n(o, 0), _n(o, 0), _n(o, 0)];
      case 'gs':
        _gs((o[0] as PdfRawName).name);
      case 'm':
        _moveTo(_n(o, 0), _n(o, 1));
      case 'l':
        _lineTo(_n(o, 0), _n(o, 1));
      case 'c':
        _curveTo(_n(o, 0), _n(o, 1), _n(o, 2), _n(o, 3), _n(o, 4), _n(o, 5));
      case 'v':
        final p = _current!;
        _curveTo(p.x, p.y, _n(o, 0), _n(o, 1), _n(o, 2), _n(o, 3));
      case 'y':
        _curveTo(_n(o, 0), _n(o, 1), _n(o, 2), _n(o, 3), _n(o, 2), _n(o, 3));
      case 'h':
        _close();
      case 're':
        final x = _n(o, 0), y = _n(o, 1), w = _n(o, 2), h = _n(o, 3);
        _moveTo(x, y);
        _lineTo(x + w, y);
        _lineTo(x + w, y + h);
        _lineTo(x, y + h);
        _close();
      case 'S':
        _paint(PdfPaint.stroke);
      case 's':
        _close();
        _paint(PdfPaint.stroke);
      case 'f' || 'F':
        _paint(PdfPaint.fill);
      case 'f*':
        _paint(PdfPaint.fill, evenOdd: true);
      case 'B':
        _paint(PdfPaint.fillAndStroke);
      case 'B*':
        _paint(PdfPaint.fillAndStroke, evenOdd: true);
      case 'b':
        _close();
        _paint(PdfPaint.fillAndStroke);
      case 'b*':
        _close();
        _paint(PdfPaint.fillAndStroke, evenOdd: true);
      case 'n':
        _paint(PdfPaint.none);
      case 'BT':
        if (_inText) throw const FormatException('BT inside BT');
        _inText = true;
        _tm = PdfContentMatrix.identity;
        _tlm = PdfContentMatrix.identity;
      case 'ET':
        if (!_inText) throw const FormatException('ET without BT');
        _inText = false;
      case 'Tf':
        _state.fontResource = (o[0] as PdfRawName).name;
        _state.fontSize = _n(o, 1);
      case 'Tz':
        _state.horizontalScale = _n(o, 0);
      case 'Td':
        _tlm = PdfContentMatrix(1, 0, 0, 1, _n(o, 0), _n(o, 1)).times(_tlm);
        _tm = _tlm;
      case 'Tm':
        _tlm = PdfContentMatrix(
          _n(o, 0), _n(o, 1), _n(o, 2), _n(o, 3), _n(o, 4), _n(o, 5), //
        );
        _tm = _tlm;
      case 'Tj':
        _show([o[0]]);
      case 'TJ':
        _show(o[0] as List<Object?>);
      default:
        // Recorded in [operators] and otherwise ignored: `ri`, `i`, `BDC`,
        // `EMC`, `Tr` and the like move no geometry.
        break;
    }
  }

  PdfContentFontInfo _fontInfo(Map<String, Object?> font) {
    String? name(Object? v) => (file.resolve(v) as PdfRawName?)?.name;
    final subtype = name(font['/Subtype']);
    final encoding = file.resolve(font['/Encoding']);
    var holder = font;
    String? descendantSubtype;
    if (subtype == '/Type0') {
      final descendants =
          file.resolve(font['/DescendantFonts']) as List<Object?>;
      holder = file.resolve(descendants.first) as Map<String, Object?>;
      descendantSubtype = name(holder['/Subtype']);
    }
    final descriptor =
        file.resolve(holder['/FontDescriptor']) as Map<String, Object?>?;
    String? fontFile;
    for (final key in const ['/FontFile', '/FontFile2', '/FontFile3']) {
      if (file.resolve(descriptor?[key]) is PdfRawStream) fontFile = key;
    }
    return PdfContentFontInfo(
      subtype: subtype,
      encoding: encoding is PdfRawName ? encoding.name : null,
      descendantSubtype: descendantSubtype,
      fontFile: fontFile,
    );
  }

  void _gs(String name) {
    final table =
        file.resolve(resources['/ExtGState']) as Map<String, Object?>?;
    final entry = file.resolve(table?[name]);
    if (entry is! Map<String, Object?>) {
      throw FormatException('no ExtGState $name');
    }
    final ca = file.resolve(entry['/CA']);
    final caFill = file.resolve(entry['/ca']);
    if (ca is num) _state.strokeAlpha = ca.toDouble();
    if (caFill is num) _state.fillAlpha = caFill.toDouble();
    _state.extGStates = [..._state.extGStates, name];
  }

  void _moveTo(double x, double y) {
    _path.add(PdfContentSubpath(_toPage(x, y)));
    _current = (x: x, y: y);
    _subpathStart = _current;
  }

  void _lineTo(double x, double y) {
    _requireSubpath('l');
    _path.last.segments.add(PdfContentSegment.line(_toPage(x, y)));
    _current = (x: x, y: y);
  }

  void _curveTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    _requireSubpath('c');
    _path.last.segments.add(PdfContentSegment.cubic(
        _toPage(x1, y1), _toPage(x2, y2), _toPage(x3, y3)));
    _current = (x: x3, y: y3);
  }

  void _close() {
    if (_path.isEmpty) return;
    _path.last.closed = true;
    _current = _subpathStart;
  }

  void _requireSubpath(String op) {
    if (_path.isEmpty) throw FormatException('"$op" with no current point');
  }

  void _paint(PdfPaint paint, {bool evenOdd = false}) {
    paths.add(PdfContentPath(
      subpaths: _path,
      paint: paint,
      evenOdd: evenOdd,
      state: _state.copy(),
      operatorIndex: operators.length - 1,
    ));
    _path = [];
    _current = null;
    _subpathStart = null;
  }

  void _show(List<Object?> items) {
    if (!_inText) throw const FormatException('text shown outside BT/ET');
    final resource = _state.fontResource;
    if (resource == null) throw const FormatException('no font selected');
    final fonts = file.resolve(resources['/Font']) as Map<String, Object?>?;
    final font = file.resolve(fonts?[resource]);
    if (font is! Map<String, Object?>) {
      throw FormatException('no font $resource');
    }
    final metrics = _FontMetrics.of(file, font);
    final codes = <int>[];
    var advance = 0.0;
    final size = _state.fontSize, tz = _state.horizontalScale;
    final k = size * tz / 100;
    for (final item in items) {
      if (item is PdfRawString) {
        final b = item.bytes;
        if (metrics.twoByte) {
          for (var i = 0; i + 1 < b.length; i += 2) {
            codes.add((b[i] << 8) | b[i + 1]);
          }
        } else {
          codes.addAll(b);
        }
      } else if (item is num) {
        advance -= item / 1000 * k;
      } else {
        throw FormatException('unexpected TJ element $item');
      }
    }
    for (final code in codes) {
      advance += metrics.width(code) / 1000 * k;
    }
    texts.add(PdfContentText(
      fontResource: resource,
      font: font,
      fontInfo: _fontInfo(font),
      size: size,
      horizontalScale: tz,
      textMatrix: _tm,
      ctm: _state.ctm,
      codes: codes,
      string: metrics.unicode(codes),
      advance: advance,
      state: _state.copy(),
      operatorIndex: operators.length - 1,
    ));
    // The next run starts where this one ended (ISO 32000-1, 9.4.4).
    _tm = PdfContentMatrix(1, 0, 0, 1, advance, 0).times(_tm);
  }
}

/// Widths and the Unicode map of one font dictionary.
final class _FontMetrics {
  _FontMetrics._(
      this.twoByte, this._widths, this._defaultWidth, this._toUnicode);

  factory _FontMetrics.of(_PdfFile file, Map<String, Object?> font) {
    final subtype = (file.resolve(font['/Subtype']) as PdfRawName?)?.name;
    final widths = <int, double>{};
    var defaultWidth = 0.0;
    var twoByte = false;
    if (subtype == '/Type0') {
      twoByte = true;
      final descendants =
          file.resolve(font['/DescendantFonts']) as List<Object?>;
      final cid = file.resolve(descendants.first) as Map<String, Object?>;
      defaultWidth = (file.resolve(cid['/DW']) as num? ?? 1000).toDouble();
      final w = file.resolve(cid['/W']) as List<Object?>? ?? const [];
      var i = 0;
      while (i < w.length) {
        final first = (file.resolve(w[i]) as num).toInt();
        final next = file.resolve(w[i + 1]);
        if (next is List<Object?>) {
          for (var j = 0; j < next.length; j++) {
            widths[first + j] = (file.resolve(next[j]) as num).toDouble();
          }
          i += 2;
        } else {
          final last = (next as num).toInt();
          final width = (file.resolve(w[i + 2]) as num).toDouble();
          for (var c = first; c <= last; c++) {
            widths[c] = width;
          }
          i += 3;
        }
      }
    } else {
      final first = (file.resolve(font['/FirstChar']) as num? ?? 0).toInt();
      final list = file.resolve(font['/Widths']) as List<Object?>? ?? const [];
      for (var j = 0; j < list.length; j++) {
        widths[first + j] = (file.resolve(list[j]) as num).toDouble();
      }
    }
    final toUnicodeRef = font['/ToUnicode'];
    final toUnicode = toUnicodeRef == null
        ? null
        : _parseCMap(
            latin1.decode(file.streamData(file.resolve(toUnicodeRef))));
    return _FontMetrics._(twoByte, widths, defaultWidth, toUnicode);
  }

  final bool twoByte;
  final Map<int, double> _widths;
  final double _defaultWidth;
  final Map<int, String>? _toUnicode;

  double width(int code) => _widths[code] ?? _defaultWidth;

  String? unicode(List<int> codes) {
    final map = _toUnicode;
    if (map == null) return null;
    final b = StringBuffer();
    for (final c in codes) {
      final s = map[c];
      if (s == null) throw FormatException('code $c not in /ToUnicode');
      b.write(s);
    }
    return b.toString();
  }

  /// `bfchar` and `bfrange` entries of a ToUnicode CMap.
  static Map<int, String> _parseCMap(String cmap) {
    final map = <int, String>{};
    int hexInt(String h) => int.parse(h, radix: 16);
    // A destination is UTF-16BE: whole code units of four hex digits. Any
    // other length is malformed (the pdf package writes `<1F600>` for a code
    // point above U+FFFF); the reader throws rather than drop the tail.
    List<int> utf16Units(String h) {
      if (h.isEmpty || h.length % 4 != 0) {
        throw FormatException(
            '/ToUnicode destination <$h> is not whole UTF-16BE code units');
      }
      return [
        for (var i = 0; i < h.length; i += 4) hexInt(h.substring(i, i + 4)),
      ];
    }

    String utf16(String h) => String.fromCharCodes(utf16Units(h));

    final hex = RegExp(r'<([0-9A-Fa-f\s]*)>');
    for (final block
        in RegExp(r'beginbfchar([\s\S]*?)endbfchar').allMatches(cmap)) {
      final h = [
        for (final m in hex.allMatches(block.group(1)!))
          m.group(1)!.replaceAll(RegExp(r'\s'), ''),
      ];
      for (var i = 0; i + 1 < h.length; i += 2) {
        map[hexInt(h[i])] = utf16(h[i + 1]);
      }
    }
    for (final block
        in RegExp(r'beginbfrange([\s\S]*?)endbfrange').allMatches(cmap)) {
      final line = RegExp(
          r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<[0-9A-Fa-f]+>|\[[^\]]*\])');
      for (final m in line.allMatches(block.group(1)!)) {
        final lo = hexInt(m.group(1)!), hi = hexInt(m.group(2)!);
        final dst = m.group(3)!;
        if (dst.startsWith('[')) {
          final items = [for (final x in hex.allMatches(dst)) x.group(1)!];
          for (var c = lo; c <= hi && c - lo < items.length; c++) {
            map[c] = utf16(items[c - lo]);
          }
        } else {
          final units = utf16Units(dst.substring(1, dst.length - 1));
          for (var c = lo; c <= hi; c++) {
            final u = [...units];
            u[u.length - 1] += c - lo;
            map[c] = String.fromCharCodes(u);
          }
        }
      }
    }
    return map;
  }
}
