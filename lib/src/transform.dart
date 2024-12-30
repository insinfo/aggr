import 'dart:math' as math;

import 'package:aggr/aggr.dart';

/// Estrutura de transformação, equivalente a `Transform` no Rust.
/// Usa 6 parâmetros (sx, sy, shx, shy, tx, ty).
class Transform {
  double sx;
  double sy;
  double shx;
  double shy;
  double tx;
  double ty;

  /// Construtor padrão
  Transform({
    this.sx = 1.0,
    this.sy = 1.0,
    this.shx = 0.0,
    this.shy = 0.0,
    this.tx = 0.0,
    this.ty = 0.0,
  });

  /// Construtor equivalente a `Transform::new()`
  factory Transform.new_transform() {
    return Transform();
  }

  /// Similar a `transform.translate(dx, dy)`
  void translate(double dx, double dy) {
    tx += dx;
    ty += dy;
  }

  /// Similar a `transform.scale(sx, sy)`
  void scale(double sxx, double syy) {
    sx *= sxx;
    shx *= sxx;
    tx *= sxx;
    sy *= syy;
    shy *= syy;
    ty *= syy;
  }

  /// Similar a `transform.rotate(angle)`, em radianos
  void rotate(double angle) {
    final ca = math.cos(angle);
    final sa = math.sin(angle);

    final t0 = sx * ca - shy * sa;
    final t2 = shx * ca - sy * sa;
    final t4 = tx * ca - ty * sa;

    shy = sx * sa + shy * ca;
    sy = shx * sa + sy * ca;
    ty = tx * sa + ty * ca;
    sx = t0;
    shx = t2;
    tx = t4;
  }

  /// Aplica a transformação a um ponto (x, y), retornando (x', y')
  /// Equivalente a `transform.transform(x, y) -> (x', y')`
  List<double> transform_xy(double x, double y) {
    final xPrime = x * sx + y * shx + tx;
    final yPrime = x * shy + y * sy + ty;
    return [xPrime, yPrime];
  }

  /// Determinante (para cálculo de inversão)
  double determinant() {
    return sx * sy - shy * shx;
  }

  /// Inverte a transformação atual (similar a `transform.invert()` no Rust)
  void invert_() {
    final d = 1.0 / determinant();
    final t0 = sy * d;
    sy = sx * d;
    shy = -shy * d;
    shx = -shx * d;
    final t4 = -tx * t0 - ty * shx;
    ty = -tx * shy - ty * sy;

    sx = t0;
    tx = t4;
  }

  /// Multiplica (compõe) duas transformações: self * m
  /// (equivalente a `transform.mul_transform(&m)`)
  Transform mul_transform(Transform m) {
    final t0 = sx * m.sx + shy * m.shx;
    final t2 = shx * m.sx + sy * m.shx;
    final t4 = tx * m.sx + ty * m.shx + m.tx;

    final shy2 = sx * m.shy + shy * m.sy;
    final sy2 = shx * m.shy + sy * m.sy;
    final ty2 = tx * m.shy + ty * m.sy + m.ty;

    return Transform(
      sx: t0,
      sy: sy2,
      tx: t4,
      ty: ty2,
      shx: t2,
      shy: shy2,
    );
  }

  /// Fábrica de Transform somente com scale (similar a `Transform::new_scale(...)`)
  factory Transform.new_scale(double sx, double sy) {
    final t = Transform.new_transform();
    t.scale(sx, sy);
    return t;
  }

  /// Fábrica de Transform com translate (similar a `Transform::new_translate(...)`)
  factory Transform.new_translate(double tx, double ty) {
    final t = Transform.new_transform();
    t.translate(tx, ty);
    return t;
  }

  /// Fábrica de Transform com rotate (similar a `Transform::new_rotate(...)`)
  factory Transform.new_rotate(double ang) {
    final t = Transform.new_transform();
    t.rotate(ang);
    return t;
  }
}

/// Em Rust, `impl Mul<Transform> for Transform` define a * sobrecarga do operador.
/// Em Dart, podemos criar um método estático ou de instância. Exemplo:
Transform operatorMul(Transform a, Transform b) => a.mul_transform(b);

/// Estrutura "ConvTransform", que "envolve" um Path e aplica a Transform nele.
/// Equivale ao `ConvTransform` no Rust, também implementa `VertexSource`.
class ConvTransform implements VertexSource {
  /// Fonte de vértices (Path)
  final Path source;

  /// Transform a aplicar
  final Transform trans;

  /// Construtor
  ConvTransform({
    required this.source,
    required this.trans,
  });

  /// Implementa xconvert() => gera vertices transformados
  @override
  List<Vertex<double>> xconvert() {
    return transform_();
  }

  /// Aplica de fato a transformação
  List<Vertex<double>> transform_() {
    final out = <Vertex<double>>[];
    final srcVerts = source.xconvert();
    for (final v in srcVerts) {
      final xy = trans.transform_xy(v.x, v.y);
      out.add(Vertex<double>(xy[0], xy[1], v.cmd));
    }
    return out;
  }

  @override
  void rewind() {}
}
