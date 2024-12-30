import 'dart:math' as math;

import 'package:aggr/aggr.dart';

/// Exemplo mínimo de uso:
///
/// void main() {
///   final path = Path();
///   path.move_to(0, 0);
///   path.line_to(100, 100);
///   path.line_to(200, 50);
///   // path.close_path(); // se quiser fechar
///
///   final stroke = Stroke<Path>(path);
///   stroke.width_(2.5);
///   stroke.line_cap_(LineCap.square);
///   stroke.line_join_(LineJoin.miter);
///   stroke.miter_limit_(5.0);
///
///   final strokedVertices = stroke.xconvert();
///   print(strokedVertices);
/// }

// use crate::paths::PathCommand;
// use crate::paths::Vertex;
// use crate::paths::len;
// use crate::paths::cross;
// use crate::paths::split;
// use crate::VertexSource;
// use std::f64::consts::PI;

/// Enum para definir o tipo de linha no final (cap)
enum LineCap {
  butt,
  square,
  round,
}

/// Enum para definir o tipo de junção (join) na parte externa
enum LineJoin {
  miter,
  miterRevert,
  round,
  bevel,
  miterRound,
  miterAccurate,
  none,
}

/// Enum para definir o tipo de junção (join) na parte interna
enum InnerJoin {
  bevel,
  miter,
  jag,
  round,
}

/// Função para calcular a distância entre dois vértices (double).
double len(Vertex<double> v0, Vertex<double> v1) {
  final dx = v1.x - v0.x;
  final dy = v1.y - v0.y;
  return math.sqrt(dx * dx + dy * dy);
}

/// Função para calcular o produto vetorial (cross) 2D
double cross(Vertex<double> p0, Vertex<double> p1, Vertex<double> p2) {
  return (p1.x - p0.x) * (p2.y - p0.y) - (p1.y - p0.y) * (p2.x - p0.x);
}

/// Divide a lista de vértices em subcaminhos sempre que encontrar um 'MoveTo'
/// (similar ao split(&v0) no Rust)
List<List<int>> split(List<Vertex<double>> verts) {
  final List<List<int>> pairs = [];
  if (verts.isEmpty) {
    return pairs;
  }
  int start = 0;
  for (int i = 1; i < verts.length; i++) {
    if (verts[i].cmd == PathCommand.moveTo) {
      pairs.add([start, i - 1]);
      start = i;
    }
  }
  // Último subcaminho
  pairs.add([start, verts.length - 1]);
  return pairs;
}

/// Verifica se o caminho está fechado (possui pelo menos um ClosePolygon)
bool is_path_closed(List<Vertex<double>> verts) {
  for (final v in verts) {
    if (v.cmd == PathCommand.close) {
      return true;
    }
  }
  return false;
}

/// Remove vértices repetidos ou muito próximos, também ajusta se o path é fechado.
List<Vertex<double>> clean_path(List<Vertex<double>> verts) {
  if (verts.isEmpty) {
    return <Vertex<double>>[];
  }
  final List<int> mark = [0]; // guarda índices a manter

  for (int i = 1; i < verts.length; i++) {
    if (verts[i].cmd == PathCommand.lineTo) {
      if (len(verts[i - 1], verts[i]) >= 1e-6) {
        mark.add(i);
      }
    } else {
      mark.add(i);
    }
  }
  if (mark.isEmpty) {
    return <Vertex<double>>[];
  }

  // Coletar somente os vértices "ok"
  final out = <Vertex<double>>[];
  for (final i in mark) {
    out.add(verts[i]);
  }

  // Se não é fechado, podemos retornar
  if (!is_path_closed(out)) {
    return out;
  }

  // Se é fechado, remover vértices duplicados do final
  final first = out[0];
  while (true) {
    final i = last_line_to(out);
    if (i == null) {
      // Sem lineTo
      break;
    }
    final lastV = out[i];
    if (len(first, lastV) >= 1e-6) {
      break;
    }
    out.removeAt(i);
    if (i == 0 || out.isEmpty) {
      break;
    }
  }
  return out;
}

/// Acha o índice do último lineTo no array
int? last_line_to(List<Vertex<double>> verts) {
  for (int i = verts.length - 1; i >= 0; i--) {
    if (verts[i].cmd == PathCommand.lineTo) {
      return i;
    }
  }
  return null;
}

/// Função auxiliar para obter o índice anterior
int _prev(int i, int n) => (i + n - 1) % n;

/// Função auxiliar para obter o índice atual
int _curr(int i, int n) => i;

/// Função auxiliar para obter o índice seguinte
int _next(int i, int n) => (i + 1) % n;

/// Implementação da estrutura Stroke em Dart
class Stroke<VS extends VertexSource> implements VertexSource {
  VS source;
  double width;
  double width_abs;
  double width_eps;
  double width_sign;
  double miter_limit;
  double inner_miter_limit;
  double approx_scale;
  LineCap line_cap;
  LineJoin line_join;
  InnerJoin inner_join;

  Stroke(this.source)
      : width = 0.5,
        width_abs = 0.5,
        width_eps = 0.5 / 1024.0,
        width_sign = 1.0,
        miter_limit = 4.0,
        inner_miter_limit = 1.01,
        approx_scale = 1.0,
        inner_join = InnerJoin.miter,
        line_cap = LineCap.butt,
        line_join = LineJoin.miter;

  /// Cria um novo Stroke a partir de uma fonte de vértices
  factory Stroke.new_stroke(VS source) {
    return Stroke<VS>(source);
  }

  /// Define a largura do traço (Stroke Width)
  void width_(double w) {
    // half-stroke logic
    width = w / 2.0;
    width_abs = width.abs();
    width_sign = (width < 0.0) ? -1.0 : 1.0;
  }

  /// Define o estilo de line cap
  void line_cap_(LineCap cap) {
    line_cap = cap;
  }

  /// Define o estilo de line join
  void line_join_(LineJoin join) {
    line_join = join;
    if (line_join == LineJoin.miterAccurate) {
      line_join = LineJoin.miter;
    }
    if (line_join == LineJoin.none) {
      line_join = LineJoin.miter;
    }
  }

  /// Define o estilo de junção interna
  void inner_join_(InnerJoin ij) {
    inner_join = ij;
  }

  /// Define o limite de miter
  void miter_limit_(double ml) {
    miter_limit = ml;
  }

  /// Define o limite de miter interno
  void inner_miter_limit_(double iml) {
    inner_miter_limit = iml;
  }

  /// Define a escala de aproximação
  void approximation_scale_(double scale) {
    approx_scale = scale;
  }

  @override
  void rewind() {
    // sem uso no momento
  }

  /// Retorna os vértices processados
  @override
  List<Vertex<double>> xconvert() {
    return stroke();
  }

  /// Calcula o "cap" (final da linha)
  List<Vertex<double>> calc_cap(
    Vertex<double> v0,
    Vertex<double> v1,
  ) {
    final out = <Vertex<double>>[];
    final dx = v1.x - v0.x;
    final dy = v1.y - v0.y;
    final len_ = math.sqrt(dx * dx + dy * dy);
    final dx1 = width * dy / len_;
    final dy1 = width * dx / len_;

    switch (line_cap) {
      case LineCap.square:
        {
          final dx2 = dy1 * width_sign;
          final dy2 = dx1 * width_sign;
          out.add(Vertex.line_to(v0.x - dx1 - dx2, v0.y + dy1 - dy2));
          out.add(Vertex.line_to(v0.x + dx1 - dx2, v0.y - dy1 - dy2));
        }
        break;
      case LineCap.butt:
        {
          out.add(Vertex.line_to(v0.x - dx1, v0.y + dy1));
          out.add(Vertex.line_to(v0.x + dx1, v0.y - dy1));
        }
        break;
      case LineCap.round:
        {
          final da =
              2.0 * math.acos(width_abs / (width_abs + 0.125 / approx_scale));
          final n = (math.pi / da).toInt();
          final da2 = math.pi / (n + 1);
          out.add(Vertex.line_to(v0.x - dx1, v0.y + dy1));

          if (width_sign > 0.0) {
            double a1 = math.atan2(dy1, -dx1);
            a1 += da2;
            for (int i = 0; i < n; i++) {
              out.add(Vertex.line_to(
                  v0.x + math.cos(a1) * width, v0.y + math.sin(a1) * width));
              a1 += da2;
            }
          } else {
            double a1 = math.atan2(-dy1, dx1);
            a1 -= da2;
            for (int i = 0; i < n; i++) {
              out.add(Vertex.line_to(
                  v0.x + math.cos(a1) * width, v0.y + math.sin(a1) * width));
              a1 -= da2;
            }
          }
          out.add(Vertex.line_to(v0.x + dx1, v0.y - dy1));
        }
        break;
    }
    return out;
  }

  /// Calcula um arco (arc)
  List<Vertex<double>> calc_arc(
    double x,
    double y,
    double dx1,
    double dy1,
    double dx2,
    double dy2,
  ) {
    final out = <Vertex<double>>[];
    double a1 = math.atan2(dy1 * width_sign, dx1 * width_sign);
    double a2 = math.atan2(dy2 * width_sign, dx2 * width_sign);

    double da = 2.0 * math.acos(width_abs / (width_abs + 0.125 / approx_scale));
    out.add(Vertex.line_to(x + dx1, y + dy1));

    if (width_sign > 0.0) {
      if (a1 > a2) {
        a2 += 2.0 * math.pi;
      }
      final n = ((a2 - a1) / da).floor();
      final da2 = (a2 - a1) / (n + 1);
      a1 += da2;
      for (int i = 0; i < n; i++) {
        out.add(
            Vertex.line_to(x + math.cos(a1) * width, y + math.sin(a1) * width));
        a1 += da2;
      }
    } else {
      if (a1 < a2) {
        a2 -= 2.0 * math.pi;
      }
      final n = ((a1 - a2) / da).floor();
      final da2 = (a1 - a2) / (n + 1);
      a1 -= da2;
      for (int i = 0; i < n; i++) {
        out.add(
            Vertex.line_to(x + math.cos(a1) * width, y + math.sin(a1) * width));
        a1 -= da2;
      }
    }
    out.add(Vertex.line_to(x + dx2, y + dy2));
    return out;
  }

  /// Calcula a interseção de duas linhas
  /// Retorna `[px, py]` se houver, ou `null` se forem paralelas
  List<double>? calc_intersection(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    double dx,
    double dy,
  ) {
    const intersection_epsilon = 1.0e-30;
    final num_ = (ay - cy) * (dx - cx) - (ax - cx) * (dy - cy);
    final den = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx);
    if (den.abs() < intersection_epsilon) {
      return null;
    }
    final r = num_ / den;
    final px = ax + r * (bx - ax);
    final py = ay + r * (by - ay);
    return [px, py];
  }

  /// Calcula um 'miter' join
  List<Vertex<double>> calc_miter(
    Vertex<double> p0,
    Vertex<double> p1,
    Vertex<double> p2,
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    LineJoin join,
    double mlimit,
    double dbevel,
  ) {
    final out = <Vertex<double>>[];
    double xi = p1.x;
    double yi = p1.y;
    double di = 1.0;
    final lim = width_abs * mlimit;
    bool miter_limit_exceeded = true;
    bool intersection_failed = true;

    // Tenta achar a interseção
    final inter = calc_intersection(
      p0.x + dx1,
      p0.y - dy1,
      p1.x + dx1,
      p1.y - dy1,
      p1.x + dx2,
      p1.y - dy2,
      p2.x + dx2,
      p2.y - dy2,
    );
    if (inter != null) {
      xi = inter[0];
      yi = inter[1];
      final pz = Vertex.line_to(xi, yi);
      di = len(p1, pz);
      if (di <= lim) {
        out.add(Vertex.line_to(xi, yi));
        miter_limit_exceeded = false;
      }
      intersection_failed = false;
    } else {
      // Se deu falha (linhas paralelas), checa se o segmento continua em linha reta
      final x2 = p1.x + dx1;
      final y2 = p1.y - dy1;
      final pz = Vertex.line_to(x2, y2);
      if ((cross(p0, p1, pz) < 0.0) == (cross(p1, p2, pz) < 0.0)) {
        out.add(Vertex.line_to(p1.x + dx1, p1.y - dy1));
        miter_limit_exceeded = false;
      }
    }

    if (miter_limit_exceeded) {
      switch (join) {
        case LineJoin.miterRevert:
          out.add(Vertex.line_to(p1.x + dx1, p1.y - dy1));
          out.add(Vertex.line_to(p1.x + dx2, p1.y - dy2));
          break;
        case LineJoin.round:
          out.addAll(calc_arc(p1.x, p1.y, dx1, -dy1, dx2, -dy2));
          break;
        default:
          {
            if (intersection_failed) {
              final ml = mlimit * width_sign;
              out.add(
                  Vertex.line_to(p1.x + dx1 + dy1 * ml, p1.y - dy1 + dx1 * ml));
              out.add(
                  Vertex.line_to(p1.x + dx2 - dy2 * ml, p1.y - dy2 - dx2 * ml));
            } else {
              final x1 = p1.x + dx1;
              final y1 = p1.y - dy1;
              final x2 = p1.x + dx2;
              final y2 = p1.y - dy2;
              final scale = (lim - dbevel) / (di - dbevel);
              out.add(Vertex.line_to(
                  x1 + (xi - x1) * scale, y1 + (yi - y1) * scale));
              out.add(Vertex.line_to(
                  x2 + (xi - x2) * scale, y2 + (yi - y2) * scale));
            }
          }
          break;
      }
    }
    return out;
  }

  /// Calcula a junção de duas linhas
  List<Vertex<double>> calc_join(
    Vertex<double> p0,
    Vertex<double> p1,
    Vertex<double> p2,
  ) {
    final out = <Vertex<double>>[];
    final len1 = len(p1, p0);
    final len2 = len(p2, p1);

    if (len1 == 0.0) {
      throw StateError('Same point between p0,p1 $p0, $p1');
    }
    if (len2 == 0.0) {
      throw StateError('Same point between p1,p2 $p1, $p2');
    }

    final dx1 = width * (p1.y - p0.y) / len1;
    final dy1 = width * (p1.x - p0.x) / len1;
    final dx2 = width * (p2.y - p1.y) / len2;
    final dy2 = width * (p2.x - p1.x) / len2;

    final cp = cross(p0, p1, p2);
    final bool cpNeg = (cp < 0.0);
    final bool wNeg = (width < 0.0);

    if (cp != 0.0 && cpNeg == wNeg) {
      // Inner join
      double limit = (len1 < len2) ? (len1 / width_abs) : (len2 / width_abs);
      if (limit < inner_miter_limit) {
        limit = inner_miter_limit;
      }
      switch (inner_join) {
        case InnerJoin.bevel:
          out.add(Vertex.line_to(p1.x + dx1, p1.y - dy1));
          out.add(Vertex.line_to(p1.x + dx2, p1.y - dy2));
          break;
        case InnerJoin.miter:
          out.addAll(calc_miter(p0, p1, p2, dx1, dy1, dx2, dy2,
              LineJoin.miterRevert, limit, 0.0));
          break;
        case InnerJoin.jag:
        case InnerJoin.round:
          final cp2 = math.pow(dx1 - dx2, 2) + math.pow(dy1 - dy2, 2);
          if (cp2 < math.pow(len1, 2) && cp2 < math.pow(len2, 2)) {
            out.addAll(calc_miter(p0, p1, p2, dx1, dy1, dx2, dy2,
                LineJoin.miterRevert, limit, 0.0));
          } else {
            if (inner_join == InnerJoin.jag) {
              out.add(Vertex.line_to(p1.x + dx1, p1.y - dy1));
              out.add(Vertex.line_to(p1.x, p1.y));
              out.add(Vertex.line_to(p1.x + dx2, p1.y - dy2));
            }
            if (inner_join == InnerJoin.round) {
              out.add(Vertex.line_to(p1.x + dx1, p1.y - dy1));
              out.add(Vertex.line_to(p1.x, p1.y));
              out.addAll(calc_arc(p1.x, p1.y, dx2, -dy2, dx1, -dy1));
              out.add(Vertex.line_to(p1.x, p1.y));
              out.add(Vertex.line_to(p1.x + dx2, p1.y - dy2));
            }
          }
          break;
      }
    } else {
      // Outer join
      final dx = (dx1 + dx2) / 2.0;
      final dy = (dy1 + dy2) / 2.0;
      final dbevel = math.sqrt(dx * dx + dy * dy);

      // Otimização de colinearidades
      if ((line_join == LineJoin.round || line_join == LineJoin.bevel) &&
          approx_scale * (width_abs - dbevel) < width_eps) {
        final inter = calc_intersection(
          p0.x + dx1,
          p0.y - dy1,
          p1.x + dx1,
          p1.y - dy1,
          p1.x + dx2,
          p1.y - dy2,
          p2.x + dx2,
          p2.y - dy2,
        );
        if (inter != null) {
          out.add(Vertex.line_to(inter[0], inter[1]));
        } else {
          out.add(Vertex.line_to(p1.x + dx1, p1.y - dy1));
        }
        return out;
      }

      switch (line_join) {
        case LineJoin.miter:
        case LineJoin.miterRevert:
        case LineJoin.miterRound:
          out.addAll(calc_miter(
              p0, p1, p2, dx1, dy1, dx2, dy2, line_join, miter_limit, dbevel));
          break;
        case LineJoin.round:
          out.addAll(calc_arc(p1.x, p1.y, dx1, -dy1, dx2, -dy2));
          break;
        case LineJoin.bevel:
          out.add(Vertex.line_to(p1.x + dx1, p1.y - dy1));
          out.add(Vertex.line_to(p1.x + dx2, p1.y - dy2));
          break;
        case LineJoin.none:
        case LineJoin.miterAccurate:
          // Não faz nada
          break;
      }
    }
    return out;
  }

  /// Lógica principal de "stroke" do path
  List<Vertex<double>> stroke() {
    final all_out = <Vertex<double>>[];
    final v0 = source.xconvert();
    final pairs = split(v0);

    for (final pair in pairs) {
      final m1 = pair[0];
      final m2 = pair[1];

      final sub = v0.sublist(m1, m2 + 1);
      final v = clean_path(sub);
      if (v.length <= 1) {
        continue;
      }
      final closed = is_path_closed(v);
      final n = closed ? (v.length - 1) : v.length;
      final n1 = closed ? 0 : 1;
      final n2 = closed ? (n - 1) : (n - 1);

      // Forward path
      final outf = <Vertex<double>>[];
      if (!closed) {
        // Cap inicial
        outf.addAll(calc_cap(v[0], v[1]));
      }
      for (int i = n1; i < n2; i++) {
        outf.addAll(calc_join(
          v[_prev(i, n)],
          v[_curr(i, n)],
          v[_next(i, n)],
        ));
      }
      if (closed && outf.isNotEmpty) {
        final last = outf[outf.length - 1];
        outf.add(Vertex.close_polygon(last.x, last.y));
      }

      // Backward path
      final outb = <Vertex<double>>[];
      if (!closed) {
        outb.addAll(calc_cap(v[n - 1], v[n - 2]));
      }
      // Loop inverso
      for (int i = n2 - 1; i >= n1; i--) {
        outb.addAll(calc_join(
          v[_next(i, n)],
          v[_curr(i, n)],
          v[_prev(i, n)],
        ));
      }

      if (closed && outb.isNotEmpty) {
        outb[0] = Vertex(
          outb[0].x,
          outb[0].y,
          PathCommand.moveTo,
        );
        final last = outb[outb.length - 1];
        outb.add(Vertex.close_polygon(last.x, last.y));
      } else if (outb.isNotEmpty) {
        final last = outb[outb.length - 1];
        outb.add(Vertex.close_polygon(last.x, last.y));
      }

      if (outf.isNotEmpty) {
        // Força o primeiro ponto do "outf" a ser MoveTo
        outf[0] = Vertex(
          outf[0].x,
          outf[0].y,
          PathCommand.moveTo,
        );
      }

      // Junta forward e backward
      outf.addAll(outb);
      all_out.addAll(outf);
    }
    return all_out;
  }
}

/// Exemplo mínimo de uma VertexSource "Path" em Dart
/// (apenas para demonstrar a interface)
class Path implements VertexSource {
  final List<Vertex<double>> _commands = [];

  void move_to(double x, double y) {
    _commands.add(Vertex.move_to(x, y));
  }

  void line_to(double x, double y) {
    _commands.add(Vertex.line_to(x, y));
  }

  void close_path() {
    // Equivalente a "ClosePolygon"
    if (_commands.isNotEmpty) {
      final last = _commands[_commands.length - 1];
      _commands.add(Vertex.close_polygon(last.x, last.y));
    }
  }

  @override
  List<Vertex<double>> xconvert() {
    return _commands;
  }

  @override
  void rewind() {
    throw UnimplementedError();
  }
}
