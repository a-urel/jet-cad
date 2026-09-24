// SPIKE 07 — throwaway SVG dump.
import 'dart:io';
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';

List<Vector2> ringOf(WorldWall w, List<WorldWall> all) =>
    outline(w, [for (final o in all) if (o.handle != w.handle) o]);

bool insideRing(Vector2 p, List<Vector2> r) {
  var c = false;
  for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
    final a = r[i], b = r[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      c = !c;
    }
  }
  return c;
}

const _colours = ['#333', '#666', '#999', '#555', '#888'];

void dump(String name, List<WorldWall> walls, Vector2 hub, double r) {
  final rings = [for (final w in walls) ringOf(w, walls)];
  final b = StringBuffer()
    ..writeln('<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="${-r} ${-r} ${2 * r} ${2 * r}" width="600" height="600">')
    ..writeln('<rect x="${-r}" y="${-r}" width="${2 * r}" height="${2 * r}" '
        'fill="white"/>')
    ..writeln('<g transform="scale(1,-1)">');
  String pts(List<Vector2> ps) =>
      ps.map((p) => '${p.x - hub.x},${p.y - hub.y}').join(' ');
  for (final (i, rg) in rings.indexed) {
    b.writeln('<polygon points="${pts(rg)}" fill="${_colours[i % 5]}" '
        'fill-opacity="0.55" stroke="black" stroke-width="${r / 300}"/>');
  }
  for (final w in walls) {
    final (l, rr) = w.offsets;
    final n = Vector2(-w.d.y, w.d.x);
    b.writeln('<polygon points="${pts([
          w.s + n * rr,
          w.e + n * rr,
          w.e + n * l,
          w.s + n * l
        ])}" fill="none" stroke="green" stroke-dasharray="${r / 60}" '
        'stroke-width="${r / 400}"/>');
    b.writeln('<line x1="${w.s.x - hub.x}" y1="${w.s.y - hub.y}" '
        'x2="${w.e.x - hub.x}" y2="${w.e.y - hub.y}" stroke="orange" '
        'stroke-width="${r / 400}"/>');
  }
  final rnd = math.Random(7);
  for (var i = 0; i < 6000; i++) {
    final a = rnd.nextDouble() * 2 * math.pi;
    final rad = r * math.sqrt(rnd.nextDouble());
    final p = hub + Vector2(math.cos(a), math.sin(a)) * rad;
    final count = rings.where((rg) => insideRing(p, rg)).length;
    bool inStrip(WorldWall w) {
      final (l, rr) = w.offsets;
      final d = w.d, nn = Vector2(-d.y, d.x);
      final u = (p - w.s).dot(d), v = (p - w.s).dot(nn);
      return u > 0 && u < (w.e - w.s).length && v < l && v > rr;
    }

    final colour = count > 1
        ? 'blue'
        : (count == 0 && walls.any(inStrip))
            ? 'red'
            : null;
    if (colour != null) {
      b.writeln('<circle cx="${p.x - hub.x}" cy="${p.y - hub.y}" '
          'r="${r / 150}" fill="$colour"/>');
    }
  }
  b.writeln('<circle cx="0" cy="0" r="${r / 80}" fill="magenta"/>');
  b
    ..writeln('</g>')
    ..writeln('<text x="${-r * 0.95}" y="${-r * 0.88}" '
        'font-size="${r / 14}">$name</text>')
    ..writeln('</svg>');
  Directory('build/spike_walls').createSync(recursive: true);
  File('build/spike_walls/$name.svg').writeAsStringSync(b.toString());
}

