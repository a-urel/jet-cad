// Attachment (spec 2a P3, umbrella A5): a kit's provider offers where a
// symbol may attach (a wall's face, a room's corner); the plan library asks
// every provider of the kinds a symbol's `attachTo` names and keeps the
// answer whose marker is nearest the pointer.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A kit's attachment provider: one target [kind], made once per document
/// from the kit's `attachments` factories.
abstract interface class AttachmentProvider {
  /// A target kind (K2's kind pattern): `wall-face`.
  String get kind;

  /// Where the symbol in [query] attaches, or null for nowhere near. Must
  /// not mutate the document.
  Attachment? attach(AttachmentQuery query);
}

/// What a provider is asked: the symbol, where it is, where the pointer is.
///
/// The query never changes after it is made: [pointer] is copied when it
/// is made and again at each read (a provider that changes the vector it
/// read changes nothing the next provider sees), and [exclude] is an
/// unmodifiable copy.
@immutable
final class AttachmentQuery {
  /// Throws [ArgumentError] for a capture or an edge capture that is
  /// negative or not finite, and for a pointer that is not finite.
  AttachmentQuery({
    required this.footprint,
    required this.current,
    required Vector2 pointer,
    required this.capture,
    required this.edgeCapture,
    required this.mirrored,
    required this.mayRotate,
    Set<Handle> exclude = const {},
    this.keep,
  })  : _pointer = Vector2.copy(pointer),
        exclude = Set.unmodifiable(exclude) {
    _checkDistance(capture, 'capture');
    _checkDistance(edgeCapture, 'edgeCapture');
    if (!pointer.x.isFinite || !pointer.y.isFinite) {
      throw ArgumentError.value(pointer, 'pointer', 'is not finite');
    }
  }

  /// The symbol's box in its own frame.
  final Aabb2 footprint;

  /// The symbol's transform now (while placing: the ghost's).
  final Transform2 current;

  /// The raw world point under the pointer: a fresh copy at each read.
  Vector2 get pointer => Vector2.copy(_pointer);
  final Vector2 _pointer;

  /// World distances: how far from a target the pointer may be, and how
  /// near an end of a target the symbol may slide.
  final double capture;
  final double edgeCapture;

  /// Whether the symbol is mirrored now.
  final bool mirrored;

  /// False (the `rotate` permission is off): offer only targets the
  /// symbol's current turn already fits.
  final bool mayRotate;

  /// Objects not to attach to: the one being moved.
  final Set<Handle> exclude;

  /// The previous answer, for hysteresis; null at first.
  final Attachment? keep;
}

/// Where a symbol attaches: its new [transform], the world point the plan
/// library draws its marker at, and the provider's own [token] (a face run),
/// which it reads back from [AttachmentQuery.keep].
///
/// [marker] is copied.
@immutable
final class Attachment {
  /// Throws [ArgumentError] for a transform or a marker that is not finite.
  Attachment({
    required this.transform,
    required Vector2 marker,
    required this.token,
  }) : marker = Vector2.copy(marker) {
    final t = transform;
    if (![t.a, t.b, t.c, t.d, t.e, t.f].every((v) => v.isFinite)) {
      throw ArgumentError.value(transform, 'transform', 'is not finite');
    }
    if (!marker.x.isFinite || !marker.y.isFinite) {
      throw ArgumentError.value(marker, 'marker', 'is not finite');
    }
  }

  final Transform2 transform;
  final Vector2 marker;
  final Object token;
}

/// The plan library's registry over every loaded kit's providers.
abstract interface class AttachmentRegistry {
  /// The answer of the providers of [kinds] nearest the pointer, or null.
  Attachment? attach(List<String> kinds, AttachmentQuery query);

  /// The kinds some provider offers.
  Set<String> get kinds;
}

void _checkDistance(double v, String name) {
  if (!v.isFinite || v < 0) {
    throw ArgumentError.value(v, name, 'must be finite and not negative');
  }
}
