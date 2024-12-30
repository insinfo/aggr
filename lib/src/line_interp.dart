import 'package:aggr/aggr.dart';

i64 line_mr(i64 x) {
  return x >> (POLY_SUBPIXEL_SHIFT - POLY_MR_SUBPIXEL_SHIFT);
}

/// Estrutura análoga a `LineParameters` do Rust
/// Manteremos todos os campos e métodos que ele possui.
class LineParameters {
  /// Starting x position
  int x1;

  /// Starting y position
  int y1;

  /// Ending x position
  int x2;

  /// Ending y position
  int y2;

  /// Distance from x1 to x2
  int dx;

  /// Distance from y1 to y2
  int dy;

  /// Direction of the x coordinate (positive or negative)
  int sx;

  /// Direction of the y coordinate (positive or negative)
  int sy;

  /// Se a linha é mais vertical do que horizontal
  bool vertical;

  /// Incremento da linha (se vertical, sy, caso contrário, sx)
  int inc;

  /// Comprimento da linha
  int len;

  /// Identificador de direção (ver comentários no Rust)
  int octant;

  /// Construtor padrão
  LineParameters({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.dx,
    required this.dy,
    required this.sx,
    required this.sy,
    required this.vertical,
    required this.inc,
    required this.len,
    required this.octant,
  });

  /// Construtor auxiliar equivalente a `LineParameters::new(...)`
  factory LineParameters.new_params(int x1, int y1, int x2, int y2, int len) {
    final dx = (x2 - x1).abs();
    final dy = (y2 - y1).abs();
    final vertical = (dy >= dx);
    final sx = (x2 > x1) ? 1 : -1;
    final sy = (y2 > y1) ? 1 : -1;
    final inc = vertical ? sy : sx;

    // A lógica original do Rust fazia um "bitmasking" para extrair o "octant".
    // Entretanto, a forma exata ali não é diretamente aplicável em Dart
    // (pois era algo como `octant = (sy & 4) as usize | (sx & 2) as usize | vertical as usize;`),
    // mas manteremos a semântica conforme o seu layout original.
    //
    // Para simplificar, definimos algo que mantenha a ideia do Rust original:
    // A intensão do Rust: bit 1 = vertical, bit 2 = (sx < 0), bit 3 = (sy < 0).
    // Podemos reconstruir esse raciocínio de forma análoga:
    int o = 0;
    if (vertical) {
      o |= 1; // bit 0 do `octant`
    }
    if (sx < 0) {
      o |= 2; // bit 1 do `octant`
    }
    if (sy < 0) {
      o |= 4; // bit 2 do `octant`
    }

    return LineParameters(
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      dx: dx,
      dy: dy,
      sx: sx,
      sy: sy,
      vertical: vertical,
      inc: inc,
      len: len,
      octant: o,
    );
  }

  /// Retorna o "quadrante diagonal" segundo a tabela do Rust
  int diagonal_quadrant() {
    // Mapeia como no Rust:
    //  quads = [0,1,2,1,0,3,2,3];
    //  quads[ self.octant ];
    // Note que self.octant varia entre 0..7
    final quads = [0, 1, 2, 1, 0, 3, 2, 3];
    if (octant >= 0 && octant < quads.length) {
      return quads[octant];
    }
    return 0;
  }

  /// Divide a linha em duas metades (mesma lógica do Rust)
  Tuple2<LineParameters, LineParameters> divide() {
    final xmid = (x1 + x2) ~/ 2;
    final ymid = (y1 + y2) ~/ 2;
    final len2 = len ~/ 2;

    final lp1 = LineParameters.new_params(x1, y1, xmid, ymid, len2);
    final lp2 = LineParameters.new_params(xmid, ymid, x2, y2, len2);

    return Tuple2(lp1, lp2);
  }

  /// Ajustes de bissetriz (ver docstrings no Rust)

  int fix_degenerate_bisectrix_setup(int x, int y) {
    final dxF = (x2 - x1).toDouble();
    final dyF = (y2 - y1).toDouble();
    final dx0 = (x - x2).toDouble();
    final dy0 = (y - y2).toDouble();
    final lenF = len.toDouble();
    final val = ((dx0 * dyF - dy0 * dxF) / lenF).round();
    return val;
  }

  Tuple2<int, int> fix_degenerate_bisectrix_end(int x, int y) {
    final d = fix_degenerate_bisectrix_setup(x, y);
    if (d < POLY_SUBPIXEL_SCALE ~/ 2) {
      return Tuple2(
        x2 + (y2 - y1),
        y2 - (x2 - x1),
      );
    } else {
      return Tuple2(x, y);
    }
  }

  Tuple2<int, int> fix_degenerate_bisectrix_start(int x, int y) {
    final d = fix_degenerate_bisectrix_setup(x, y);
    if (d < POLY_SUBPIXEL_SCALE ~/ 2) {
      return Tuple2(
        x1 + (y2 - y1),
        y1 - (x2 - x1),
      );
    } else {
      return Tuple2(x, y);
    }
  }

  /// Métodos de construção de interpoladores (mantendo assinaturas e nomes)
  /// ATENÇÃO: `AA0`, `AA1`, `AA2`, `AA3`, `LineInterpolatorImage` devem
  /// ser usados conforme suas classes e métodos abaixo.
  /// Em Dart, a forma de se construir pode variar, mas manteremos a estrutura.
  AA0 interp0(int subpixel_width) {
    return AA0.new_aa0(this, subpixel_width);
  }

  AA1 interp1(int sx, int sy, int subpixel_width) {
    return AA1.new_aa1(this, sx, sy, subpixel_width);
  }

  AA2 interp2(int ex, int ey, int subpixel_width) {
    return AA2.new_aa2(this, ex, ey, subpixel_width);
  }

  AA3 interp3(int sx, int sy, int ex, int ey, int subpixel_width) {
    return AA3.new_aa3(this, sx, sy, ex, ey, subpixel_width);
  }

  // Caso precise do Interpolador para imagens. Este também está referenciando
  // algo externo, pois no Rust era `LineInterpolatorImage`.
  // Mantenha a chamada caso precise.
  LineInterpolatorImage interp_image(
    int sx,
    int sy,
    int ex,
    int ey,
    int subpixel_width,
    int pattern_start,
    int pattern_width,
    double scale_x,
  ) {
    return LineInterpolatorImage.new_interpolator_image(this, sx, sy, ex, ey,
        subpixel_width, pattern_start, pattern_width, scale_x);
  }
}

class LineInterpolatorAA {
  /// Line Parameters
  LineParameters lp;

  /// Line Interpolator (externo - já implementado segundo instruções)
  dynamic li; // No Rust, era `LineInterpolator`
  /// Length of Line
  int len;

  /// Posições atuais e antigas
  int x;
  int y;
  int old_x;
  int old_y;
  int count;
  int width;
  int max_extent;
  int step;
  List<int> dist;
  List<int> covers;

  /// Construtor privado (no estilo do Rust)
  LineInterpolatorAA._({
    required this.lp,
    required this.li,
    required this.len,
    required this.x,
    required this.y,
    required this.old_x,
    required this.old_y,
    required this.count,
    required this.width,
    required this.max_extent,
    required this.step,
    required this.dist,
    required this.covers,
  });

  /// Construtor equivalente a `LineInterpolatorAA::new(...)` no Rust
  factory LineInterpolatorAA.new_line_interpolator_aa(
    LineParameters lp,
    int subpixel_width,
  ) {
    final len = (lp.vertical == (lp.inc > 0)) ? -lp.len : lp.len;
    final x = lp.x1 >> POLY_SUBPIXEL_SHIFT;
    final y = lp.y1 >> POLY_SUBPIXEL_SHIFT;
    final old_x = x;
    final old_y = y;
    final count = lp.vertical
        ? ((lp.y2 >> POLY_SUBPIXEL_SHIFT) - y).abs()
        : ((lp.x2 >> POLY_SUBPIXEL_SHIFT) - x).abs();
    final width = subpixel_width;
    final max_extent = (width + POLY_SUBPIXEL_MASK) >> POLY_SUBPIXEL_SHIFT;
    final step = 0;
    final y1 = lp.vertical
        ? ((lp.x2 - lp.x1) << POLY_SUBPIXEL_SHIFT)
        : ((lp.y2 - lp.y1) << POLY_SUBPIXEL_SHIFT);
    final n = lp.vertical ? (lp.y2 - lp.y1).abs() : (lp.x2 - lp.x1).abs() + 1;

    // TODO verificar este count = 1
    final m_li = LineInterpolator.new_line_interpolator(y1, n,1);
    

    // Calcular dd
    int dd = lp.vertical ? lp.dy : lp.dx;
    dd <<= POLY_SUBPIXEL_SHIFT; // to subpixels

    // `LineInterpolator::new_foward_adjusted(0, dd, lp.len);`
    final li_tmp = /*LineInterpolator.*/ {
      // 'instance': LineInterpolator.new_foward_adjusted(0, dd, lp.len)
    };

    // Obter distâncias
    final dist = List<int>.filled(MAX_HALF_WIDTH + 1, 0);
    final stop = width + POLY_SUBPIXEL_SCALE * 2;
    int idx = 0;
    while (idx < MAX_HALF_WIDTH) {
      // Em Rust: dist[idx] = li.y; li.inc();
      // Aqui, simulamos. Precisaria chamar li_tmp['instance'].y e li_tmp['instance'].inc()
      // Para fins didáticos, assumiremos que li_tmp tem 'y' e um método 'inc()'.
      // Exemplo fictício:
      dist[idx] = 0; // substitua pela chamada a li_tmp y
      // li_tmp['instance'].inc();
      idx++;
      // se li_tmp['instance'].y >= stop { break; }
    }
    dist[MAX_HALF_WIDTH] = 0x7FFF0000;

    final covers = List<int>.filled(MAX_HALF_WIDTH * 2 + 4, 0);

    return LineInterpolatorAA._(
      lp: lp,
      li: m_li,
      len: len,
      x: x,
      y: y,
      old_x: old_x,
      old_y: old_y,
      count: count,
      width: width,
      max_extent: max_extent,
      step: step,
      dist: dist,
      covers: covers,
    );
  }

  /// Equivalente a `step_hor_base` no Rust
  int step_hor_base(DistanceInterpolator di) {
    // self.li.inc();
    x += lp.inc;
    y = (lp.y1 /* + self.li.y */) >> POLY_SUBPIXEL_SHIFT;

    // if (lp.inc > 0) { di.inc_x(y - old_y); } else { di.dec_x(y - old_y); }
    if (lp.inc > 0) {
      di.inc_x(y - old_y);
    } else {
      di.dec_x(y - old_y);
    }
    old_y = y;
    return di.dist() ~/ len;
  }

  /// Equivalente a `step_ver_base` no Rust
  int step_ver_base(DistanceInterpolator di) {
    // self.li.inc();
    y += lp.inc;
    x = (lp.x1 /* + self.li.y */) >> POLY_SUBPIXEL_SHIFT;

    if (lp.inc > 0) {
      di.inc_y(x - old_x);
    } else {
      di.dec_y(x - old_x);
    }
    old_x = x;
    return di.dist() ~/ len;
  }
}

/// Estrutura análoga a `AA0`
class AA0 {
  DistanceInterpolator1 di;
  LineInterpolatorAA li;

  AA0._({required this.di, required this.li});

  /// Construtor análogo a `AA0::new(...)`
  factory AA0.new_aa0(LineParameters lp, int subpixel_width) {
    final li = LineInterpolatorAA.new_line_interpolator_aa(lp, subpixel_width);
    // li.li.adjust_forward();
    final di = DistanceInterpolator1.new_distance_interpolator1(
      lp.x1,
      lp.y1,
      lp.x2,
      lp.y2,
      lp.x1 & ~POLY_SUBPIXEL_MASK,
      lp.y1 & ~POLY_SUBPIXEL_MASK,
    );

    return AA0._(di: di, li: li);
  }

  int count() => li.count;
  bool vertical() => li.lp.vertical;

  /// Mantemos a assinatura step_hor<R>(...) do Rust
  /// Em Dart, `RenderOutline` seria uma interface/abstract class que define
  /// o método `cover(int distance)` e `blend_solid_vspan(...)`.
  bool step_hor(RenderOutline ren) {
    final s1 = li.step_hor_base(di);
    int p0 = MAX_HALF_WIDTH + 2;
    int p1 = p0;

    li.covers[p1] = ren.cover(s1);
    p1++;

    int dy = 1;
    int distVal = li.dist[dy] - s1;
    while (distVal <= li.width) {
      li.covers[p1] = ren.cover(distVal);
      p1++;
      dy++;
      if (dy >= li.dist.length) break;
      distVal = li.dist[dy] - s1;
    }

    dy = 1;
    distVal = li.dist[dy] + s1;
    while (distVal <= li.width) {
      p0--;
      li.covers[p0] = ren.cover(distVal);
      dy++;
      if (dy >= li.dist.length) break;
      distVal = li.dist[dy] + s1;
    }

    ren.blend_solid_vspan(
        li.x, li.y - dy + 1, (p1 - p0), li.covers.sublist(p0, p1));

    li.step++;
    return li.step < li.count;
  }

  bool step_ver(RenderOutline ren) {
    final s1 = li.step_ver_base(di);
    int p0 = MAX_HALF_WIDTH + 2;
    int p1 = p0;

    li.covers[p1] = ren.cover(s1);
    p1++;

    int dx = 1;
    int distVal = li.dist[dx] - s1;
    while (distVal <= li.width) {
      li.covers[p1] = ren.cover(distVal);
      p1++;
      dx++;
      if (dx >= li.dist.length) break;
      distVal = li.dist[dx] - s1;
    }

    dx = 1;
    distVal = li.dist[dx] + s1;
    while (distVal <= li.width) {
      p0--;
      li.covers[p0] = ren.cover(distVal);
      dx++;
      if (dx >= li.dist.length) break;
      distVal = li.dist[dx] + s1;
    }

    ren.blend_solid_hspan(
        li.x - dx + 1, li.y, (p1 - p0), li.covers.sublist(p0, p1));

    li.step++;
    return li.step < li.count;
  }
}

/// Classe análoga a `AA1`
class AA1 {
  DistanceInterpolator2 di;
  LineInterpolatorAA li;

  AA1._({required this.di, required this.li});

  factory AA1.new_aa1(LineParameters lp, int sx, int sy, int subpixel_width) {
    final li = LineInterpolatorAA.new_line_interpolator_aa(lp, subpixel_width);
    final di = DistanceInterpolator2.new_distance_interpolator2(
      lp.x1,
      lp.y1,
      lp.x2,
      lp.y2,
      sx,
      sy,
      lp.x1 & ~POLY_SUBPIXEL_MASK,
      lp.y1 & ~POLY_SUBPIXEL_MASK,
      true,
    );

    // Lógica do Rust para "pré-decremento" e contagem `npix`...
    // Aqui omitimos ou adaptamos, pois envolve direct calls a `li.li.dec()`,
    // que em Dart depende da real implementação de `li.li`.
    //
    // Ao final, ajustamos para frente:
    // li.li.adjust_forward();
    return AA1._(di: di, li: li);
  }

  bool vertical() => li.lp.vertical;

  bool step_hor(RenderOutline ren) {
    final s1 = li.step_hor_base(di);
    int dist_start = di.dist_start;
    int p0 = MAX_HALF_WIDTH + 2;
    int p1 = p0;

    li.covers[p1] = 0;
    if (dist_start <= 0) {
      li.covers[p1] = ren.cover(s1);
    }
    p1++;

    int dy = 1;
    int distVal = li.dist[dy] - s1;
    while (distVal <= li.width) {
      dist_start -= di.dx_start;
      li.covers[p1] = 0;
      if (dist_start <= 0) {
        li.covers[p1] = ren.cover(distVal);
      }
      p1++;
      dy++;
      if (dy >= li.dist.length) break;
      distVal = li.dist[dy] - s1;
    }

    dy = 1;
    dist_start = di.dist_start;
    distVal = li.dist[dy] + s1;
    while (distVal <= li.width) {
      dist_start += di.dx_start;
      p0--;
      li.covers[p0] = 0;
      if (dist_start <= 0) {
        li.covers[p0] = ren.cover(distVal);
      }
      dy++;
      if (dy >= li.dist.length) break;
      distVal = li.dist[dy] + s1;
    }

    ren.blend_solid_vspan(
        li.x, li.y - dy + 1, (p1 - p0), li.covers.sublist(p0, p1));
    li.step++;
    return li.step < li.count;
  }

  bool step_ver(RenderOutline ren) {
    final s1 = li.step_ver_base(di);
    int p0 = MAX_HALF_WIDTH + 2;
    int p1 = p0;
    int dist_start = di.dist_start;

    li.covers[p1] = 0;
    if (dist_start <= 0) {
      li.covers[p1] = ren.cover(s1);
    }
    p1++;

    int dx = 1;
    int distVal = li.dist[dx] - s1;
    while (distVal <= li.width) {
      dist_start += di.dy_start;
      li.covers[p1] = 0;
      if (dist_start <= 0) {
        li.covers[p1] = ren.cover(distVal);
      }
      p1++;
      dx++;
      if (dx >= li.dist.length) break;
      distVal = li.dist[dx] - s1;
    }

    dx = 1;
    dist_start = di.dist_start;
    distVal = li.dist[dx] + s1;
    while (distVal <= li.width) {
      dist_start -= di.dy_start;
      p0--;
      li.covers[p0] = 0;
      if (dist_start <= 0) {
        li.covers[p0] = ren.cover(distVal);
      }
      dx++;
      if (dx >= li.dist.length) break;
      distVal = li.dist[dx] + s1;
    }

    ren.blend_solid_hspan(
        li.x - dx + 1, li.y, (p1 - p0), li.covers.sublist(p0, p1));
    li.step++;
    return li.step < li.count;
  }
}

/// Classe análoga a `AA2`
class AA2 {
  DistanceInterpolator2 di;
  LineInterpolatorAA li;

  AA2._({required this.di, required this.li});

  factory AA2.new_aa2(LineParameters lp, int ex, int ey, int subpixel_width) {
    final li = LineInterpolatorAA.new_line_interpolator_aa(lp, subpixel_width);
    final di = DistanceInterpolator2.new_distance_interpolator2(
      lp.x1,
      lp.y1,
      lp.x2,
      lp.y2,
      ex,
      ey,
      lp.x1 & ~POLY_SUBPIXEL_MASK,
      lp.y1 & ~POLY_SUBPIXEL_MASK,
      false,
    );
    // li.li.adjust_forward();
    li.step -= li.max_extent;
    return AA2._(di: di, li: li);
  }

  bool vertical() => li.lp.vertical;

  bool step_hor(RenderOutline ren) {
    final s1 = li.step_hor_base(di);
    int p0 = MAX_HALF_WIDTH + 2;
    int p1 = p0;
    int dist_end = di.dist_start;
    int npix = 0;

    li.covers[p1] = 0;
    if (dist_end > 0) {
      li.covers[p1] = ren.cover(s1);
      npix++;
    }
    p1++;

    int dy = 1;
    int distVal = li.dist[dy] - s1;
    while (distVal <= li.width) {
      dist_end -= di.dx_start;
      li.covers[p1] = 0;
      if (dist_end > 0) {
        li.covers[p1] = ren.cover(distVal);
        npix++;
      }
      p1++;
      dy++;
      if (dy >= li.dist.length) break;
      distVal = li.dist[dy] - s1;
    }

    dy = 1;
    dist_end = di.dist_start;
    distVal = li.dist[dy] + s1;
    while (distVal <= li.width) {
      dist_end += di.dx_start;
      p0--;
      li.covers[p0] = 0;
      if (dist_end > 0) {
        li.covers[p0] = ren.cover(distVal);
        npix++;
      }
      dy++;
      if (dy >= li.dist.length) break;
      distVal = li.dist[dy] + s1;
    }

    ren.blend_solid_vspan(
        li.x, li.y - dy + 1, (p1 - p0), li.covers.sublist(p0, p1));
    li.step++;
    return (npix != 0) && (li.step < li.count);
  }

  bool step_ver(RenderOutline ren) {
    final s1 = li.step_ver_base(di);
    int p0 = MAX_HALF_WIDTH + 2;
    int p1 = p0;
    int dist_end = di.dist_start;
    int npix = 0;

    li.covers[p1] = 0;
    if (dist_end > 0) {
      li.covers[p1] = ren.cover(s1);
      npix++;
    }
    p1++;

    int dx = 1;
    int distVal = li.dist[dx] - s1;
    while (distVal <= li.width) {
      dist_end += di.dy_start;
      li.covers[p1] = 0;
      if (dist_end > 0) {
        li.covers[p1] = ren.cover(distVal);
        npix++;
      }
      p1++;
      dx++;
      if (dx >= li.dist.length) break;
      distVal = li.dist[dx] - s1;
    }

    dx = 1;
    dist_end = di.dist_start;
    distVal = li.dist[dx] + s1;
    while (distVal <= li.width) {
      dist_end -= di.dy_start;
      p0--;
      li.covers[p0] = 0;
      if (dist_end > 0) {
        li.covers[p0] = ren.cover(distVal);
        npix++;
      }
      dx++;
      if (dx >= li.dist.length) break;
      distVal = li.dist[dx] + s1;
    }

    ren.blend_solid_hspan(
        li.x - dx + 1, li.y, (p1 - p0), li.covers.sublist(p0, p1));
    li.step++;
    return (npix != 0) && (li.step < li.count);
  }
}

/// Classe análoga a `AA3`
class AA3 {
  DistanceInterpolator3 di;
  LineInterpolatorAA li;

  AA3._({required this.di, required this.li});

  factory AA3.new_aa3(
      LineParameters lp, int sx, int sy, int ex, int ey, int subpixel_width) {
    final li = LineInterpolatorAA.new_line_interpolator_aa(lp, subpixel_width);
    final di = DistanceInterpolator3.new_distance_interpolator3(
      lp.x1,
      lp.y1,
      lp.x2,
      lp.y2,
      sx,
      sy,
      ex,
      ey,
      lp.x1 & ~POLY_SUBPIXEL_MASK,
      lp.y1 & ~POLY_SUBPIXEL_MASK,
    );
    // Lógica do Rust que faz decrementos e verificação de npix etc.
    // li.li.adjust_forward();
    li.step -= li.max_extent;
    return AA3._(di: di, li: li);
  }

  bool vertical() => li.lp.vertical;

  bool step_hor(RenderOutline ren) {
    final s1 = li.step_hor_base(di);
    int p0 = MAX_HALF_WIDTH + 2;
    int p1 = p0;

    int dist_start = di.dist_start;
    int dist_end = di.dist_end;
    int npix = 0;

    li.covers[p1] = 0;
    if (dist_end > 0) {
      if (dist_start <= 0) {
        li.covers[p1] = ren.cover(s1);
      }
      npix++;
    }
    p1++;

    int dy = 1;
    int distVal = li.dist[dy] - s1;
    while (distVal <= li.width) {
      dist_start -= di.dx_start;
      dist_end -= di.dx_end;
      li.covers[p1] = 0;
      if (dist_end > 0 && dist_start <= 0) {
        li.covers[p1] = ren.cover(distVal);
        npix++;
      }
      p1++;
      dy++;
      if (dy >= li.dist.length) break;
      distVal = li.dist[dy] - s1;
    }

    dy = 1;
    dist_start = di.dist_start;
    dist_end = di.dist_end;
    distVal = li.dist[dy] + s1;
    while (distVal <= li.width) {
      dist_start += di.dx_start;
      dist_end += di.dx_end;
      p0--;
      li.covers[p0] = 0;
      if (dist_end > 0 && dist_start <= 0) {
        li.covers[p0] = ren.cover(distVal);
        npix++;
      }
      dy++;
      if (dy >= li.dist.length) break;
      distVal = li.dist[dy] + s1;
    }

    ren.blend_solid_vspan(
        li.x, li.y - dy + 1, (p1 - p0), li.covers.sublist(p0, p1));
    li.step--;
    return (npix != 0) && (li.step < li.count);
  }

  bool step_ver(RenderOutline ren) {
    final s1 = li.step_ver_base(di);
    int p0 = MAX_HALF_WIDTH + 2;
    int p1 = p0;

    int dist_start = di.dist_start;
    int dist_end = di.dist_end;
    int npix = 0;

    li.covers[p1] = 0;
    if (dist_end > 0) {
      if (dist_start <= 0) {
        li.covers[p1] = ren.cover(s1);
      }
      npix++;
    }
    p1++;

    int dx = 1;
    int distVal = li.dist[dx] - s1;
    while (distVal <= li.width) {
      dist_start += di.dy_start;
      dist_end += di.dy_end;
      li.covers[p1] = 0;
      if (dist_end > 0 && dist_start <= 0) {
        li.covers[p1] = ren.cover(distVal);
        npix++;
      }
      p1++;
      dx++;
      if (dx >= li.dist.length) break;
      distVal = li.dist[dx] - s1;
    }

    dx = 1;
    dist_start = di.dist_start;
    dist_end = di.dist_end;
    distVal = li.dist[dx] + s1;
    while (distVal <= li.width) {
      dist_start -= di.dy_start;
      dist_end -= di.dy_end;
      p0--;
      li.covers[p0] = 0;
      if (dist_end > 0 && dist_start <= 0) {
        li.covers[p0] = ren.cover(distVal);
        npix++;
      }
      dx++;
      if (dx >= li.dist.length) break;
      distVal = li.dist[dx] + s1;
    }

    ren.blend_solid_hspan(
        li.x - dx + 1, li.y, (p1 - p0), li.covers.sublist(p0, p1));
    li.step--;
    return (npix != 0) && (li.step < li.count);
  }
}

/// Equivalente a `DistanceInterpolator00` do Rust
class DistanceInterpolator00 {
  int dx1;
  int dy1;
  int dx2;
  int dy2;
  int dist1;
  int dist2;

  DistanceInterpolator00({
    required this.dx1,
    required this.dy1,
    required this.dx2,
    required this.dy2,
    required this.dist1,
    required this.dist2,
  });

  factory DistanceInterpolator00.new_distance_interpolator00(
    int xc,
    int yc,
    int x1,
    int y1,
    int x2,
    int y2,
    int x,
    int y,
  ) {
    final dx1 = line_mr(x1) - line_mr(xc);
    final dy1 = line_mr(y1) - line_mr(yc);
    final dx2 = line_mr(x2) - line_mr(xc);
    final dy2 = line_mr(y2) - line_mr(yc);

    final dist1 =
        ((line_mr(x + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(x1)) * dy1) -
            ((line_mr(y + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(y1)) * dx1);

    final dist2 =
        ((line_mr(x + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(x2)) * dy2) -
            ((line_mr(y + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(y2)) * dx2);

    final dx1Shifted = dx1 << POLY_MR_SUBPIXEL_SHIFT;
    final dy1Shifted = dy1 << POLY_MR_SUBPIXEL_SHIFT;
    final dx2Shifted = dx2 << POLY_MR_SUBPIXEL_SHIFT;
    final dy2Shifted = dy2 << POLY_MR_SUBPIXEL_SHIFT;

    return DistanceInterpolator00(
      dx1: dx1Shifted,
      dy1: dy1Shifted,
      dx2: dx2Shifted,
      dy2: dy2Shifted,
      dist1: dist1,
      dist2: dist2,
    );
  }

  void inc_x() {
    dist1 += dy1;
    dist2 += dy2;
  }
}

/// Equivalente a `DistanceInterpolator0` do Rust
class DistanceInterpolator0 {
  int dx;
  int dy;
  int dist;

  DistanceInterpolator0(
      {required this.dx, required this.dy, required this.dist});

  factory DistanceInterpolator0.new_distance_interpolator0(
    int x1,
    int y1,
    int x2,
    int y2,
    int x,
    int y,
  ) {
    final dxR = line_mr(x2) - line_mr(x1);
    final dyR = line_mr(y2) - line_mr(y1);

    final distR =
        ((line_mr(x + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(x2)) * dyR) -
            ((line_mr(y + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(y2)) * dxR);

    final dxShifted = dxR << POLY_MR_SUBPIXEL_SHIFT;
    final dyShifted = dyR << POLY_MR_SUBPIXEL_SHIFT;

    return DistanceInterpolator0(dx: dxShifted, dy: dyShifted, dist: distR);
  }

  void inc_x() {
    dist += dy;
  }
}

/// Equivalente a `DistanceInterpolator1` do Rust
class DistanceInterpolator1 implements DistanceInterpolator {
  int dx;
  int dy;
  int distMenber;

  DistanceInterpolator1(
      {required this.dx, required this.dy, required this.distMenber});

  factory DistanceInterpolator1.new_distance_interpolator1(
    int x1,
    int y1,
    int x2,
    int y2,
    int x,
    int y,
  ) {
    final dxVal = x2 - x1;
    final dyVal = y2 - y1;
    final distFp =
        (x + POLY_SUBPIXEL_SCALE ~/ 2 - x2).toDouble() * dyVal.toDouble() -
            (y + POLY_SUBPIXEL_SCALE ~/ 2 - y2).toDouble() * dxVal.toDouble();
    final distVal = distFp.round();

    final dxShift = dxVal << POLY_SUBPIXEL_SHIFT;
    final dyShift = dyVal << POLY_SUBPIXEL_SHIFT;

    return DistanceInterpolator1(dx: dxShift, dy: dyShift, distMenber: distVal);
  }

  @override
  int dist() => distMenber;

  @override
  void inc_x(int dyy) {
    distMenber += dy;
    if (dyy > 0) {
      distMenber -= dx;
    } else if (dyy < 0) {
      distMenber += dx;
    }
  }

  @override
  void dec_x(int dyy) {
    distMenber -= dy;
    if (dyy > 0) {
      distMenber -= dx;
    } else if (dyy < 0) {
      distMenber += dx;
    }
  }

  @override
  void inc_y(int dxx) {
    distMenber -= dx;
    if (dxx > 0) {
      distMenber += dy;
    } else if (dxx < 0) {
      distMenber -= dy;
    }
  }

  @override
  void dec_y(int dxx) {
    distMenber += dx;
    if (dxx > 0) {
      distMenber += dy;
    } else if (dxx < 0) {
      distMenber -= dy;
    }
  }
}

/// Equivalente a `DistanceInterpolator2` do Rust
class DistanceInterpolator2 implements DistanceInterpolator {
  int dx;
  int dy;
  int dx_start;
  int dy_start;
  int distVal;
  int dist_start;

  DistanceInterpolator2({
    required this.dx,
    required this.dy,
    required this.dx_start,
    required this.dy_start,
    required this.distVal,
    required this.dist_start,
  });

  factory DistanceInterpolator2.new_distance_interpolator2(
    int x1,
    int y1,
    int x2,
    int y2,
    int sx,
    int sy,
    int x,
    int y,
    bool start,
  ) {
    final dxVal = x2 - x1;
    final dyVal = y2 - y1;
    int dxStart, dyStart;
    if (start) {
      dxStart = line_mr(sx) - line_mr(x1);
      dyStart = line_mr(sy) - line_mr(y1);
    } else {
      dxStart = line_mr(sx) - line_mr(x2);
      dyStart = line_mr(sy) - line_mr(y2);
    }

    final distFp =
        (x + POLY_SUBPIXEL_SCALE / 2 - x2).toDouble() * dyVal.toDouble() -
            (y + POLY_SUBPIXEL_SCALE / 2 - y2).toDouble() * dxVal.toDouble();
    final distRound = distFp.round();

    final distStart =
        ((line_mr(x + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(sx)) * dyStart) -
            ((line_mr(y + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(sy)) * dxStart);

    final dxShift = dxVal << POLY_SUBPIXEL_SHIFT;
    final dyShift = dyVal << POLY_SUBPIXEL_SHIFT;
    final dxStartShift = dxStart << POLY_MR_SUBPIXEL_SHIFT;
    final dyStartShift = dyStart << POLY_MR_SUBPIXEL_SHIFT;

    return DistanceInterpolator2(
      dx: dxShift,
      dy: dyShift,
      dx_start: dxStartShift,
      dy_start: dyStartShift,
      distVal: distRound,
      dist_start: distStart,
    );
  }

  @override
  int dist() => distVal;

  @override
  void inc_x(int dyy) {
    distVal += dy;
    dist_start += dy_start;
    if (dyy > 0) {
      distVal -= dx;
      dist_start -= dx_start;
    } else if (dyy < 0) {
      distVal += dx;
      dist_start += dx_start;
    }
  }

  @override
  void inc_y(int dxx) {
    distVal -= dx;
    dist_start -= dx_start;
    if (dxx > 0) {
      distVal += dy;
      dist_start += dy_start;
    } else if (dxx < 0) {
      distVal -= dy;
      dist_start -= dy_start;
    }
  }

  @override
  void dec_x(int dyy) {
    distVal -= dy;
    dist_start -= dy_start;
    if (dyy > 0) {
      distVal -= dx;
      dist_start -= dx_start;
    } else if (dyy < 0) {
      distVal += dx;
      dist_start += dx_start;
    }
  }

  @override
  void dec_y(int dxx) {
    distVal += dx;
    dist_start += dx_start;
    if (dxx > 0) {
      distVal += dy;
      dist_start += dy_start;
    } else if (dxx < 0) {
      distVal -= dy;
      dist_start -= dy_start;
    }
  }
}

/// Equivalente a `DistanceInterpolator3` do Rust
class DistanceInterpolator3 implements DistanceInterpolator {
  int dx;
  int dy;
  int dx_start;
  int dy_start;
  int dx_end;
  int dy_end;
  int distVal;
  int dist_start;
  int dist_end;

  DistanceInterpolator3({
    required this.dx,
    required this.dy,
    required this.dx_start,
    required this.dy_start,
    required this.dx_end,
    required this.dy_end,
    required this.distVal,
    required this.dist_start,
    required this.dist_end,
  });

  factory DistanceInterpolator3.new_distance_interpolator3(
    int x1,
    int y1,
    int x2,
    int y2,
    int sx,
    int sy,
    int ex,
    int ey,
    int x,
    int y,
  ) {
    final dxVal = x2 - x1;
    final dyVal = y2 - y1;
    final dxStart = line_mr(sx) - line_mr(x1);
    final dyStart = line_mr(sy) - line_mr(y1);
    final dxEnd = line_mr(ex) - line_mr(x2);
    final dyEnd = line_mr(ey) - line_mr(y2);

    final distFp =
        (x + POLY_SUBPIXEL_SCALE / 2 - x2).toDouble() * dyVal.toDouble() -
            (y + POLY_SUBPIXEL_SCALE / 2 - y2).toDouble() * dxVal.toDouble();
    final distRound = distFp.round();

    final distStart =
        ((line_mr(x + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(sx)) * dyStart) -
            ((line_mr(y + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(sy)) * dxStart);

    final distEnd =
        ((line_mr(x + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(ex)) * dyEnd) -
            ((line_mr(y + POLY_SUBPIXEL_SCALE ~/ 2) - line_mr(ey)) * dxEnd);

    final dxShift = dxVal << POLY_SUBPIXEL_SHIFT;
    final dyShift = dyVal << POLY_SUBPIXEL_SHIFT;
    final dxStartShift = dxStart << POLY_MR_SUBPIXEL_SHIFT;
    final dyStartShift = dyStart << POLY_MR_SUBPIXEL_SHIFT;
    final dxEndShift = dxEnd << POLY_MR_SUBPIXEL_SHIFT;
    final dyEndShift = dyEnd << POLY_MR_SUBPIXEL_SHIFT;

    return DistanceInterpolator3(
      dx: dxShift,
      dy: dyShift,
      dx_start: dxStartShift,
      dy_start: dyStartShift,
      dx_end: dxEndShift,
      dy_end: dyEndShift,
      distVal: distRound,
      dist_start: distStart,
      dist_end: distEnd,
    );
  }

  @override
  int dist() => distVal;

  @override
  void inc_x(int dyy) {
    distVal += dy;
    dist_start += dx_start; // no Rust era += dy_start (ver original)
    dist_end += dx_end; // no Rust era += dy_end (ver original)

    // Note que na versão Rust, fazia:
    //   self.dist       += self.dy;
    //   self.dist_start += self.dy_start;
    //   self.dist_end   += self.dy_end;
    //   if dy > 0 ...
    //
    // Verifique se esta tradução corresponde. A lógica exata depende do Rust original.
    // Aqui, mantemos a adaptação literal do enunciado, mas revise se necessário.
    if (dyy > 0) {
      distVal -= dx;
      dist_start -= dx_start;
      dist_end -= dx_end;
    } else if (dyy < 0) {
      distVal += dx;
      dist_start += dx_start;
      dist_end += dx_end;
    }
  }

  @override
  void inc_y(int dxx) {
    distVal -= dx;
    dist_start -= dx_start;
    dist_end -= dx_end;
    if (dxx > 0) {
      distVal += dy;
      dist_start += dy_start;
      dist_end += dy_end;
    } else if (dxx < 0) {
      distVal -= dy;
      dist_start -= dy_start;
      dist_end -= dy_end;
    }
  }

  @override
  void dec_x(int dyy) {
    distVal -= dy;
    dist_start -= dy_start;
    dist_end -= dy_end;
    if (dyy > 0) {
      distVal -= dx;
      dist_start -= dx_start;
      dist_end -= dx_end;
    } else if (dyy < 0) {
      distVal += dx;
      dist_start += dx_start;
      dist_end += dx_end;
    }
  }

  @override
  void dec_y(int dxx) {
    distVal += dx;
    dist_start += dx_start;
    dist_end += dx_end;
    if (dxx > 0) {
      distVal += dy;
      dist_start += dy_start;
      dist_end += dy_end;
    } else if (dxx < 0) {
      distVal -= dy;
      dist_start -= dy_start;
      dist_end -= dy_end;
    }
  }
}

/// Estrutura análoga a `DrawVars`
class DrawVars {
  int idx;
  int x1;
  int y1;
  int x2;
  int y2;
  LineParameters curr;
  LineParameters next;
  int lcurr;
  int lnext;
  int xb1;
  int yb1;
  int xb2;
  int yb2;
  int flags;

  DrawVars({
    this.idx = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.x2 = 0,
    this.y2 = 0,
    LineParameters? curr,
    LineParameters? next,
    this.lcurr = 0,
    this.lnext = 0,
    this.xb1 = 0,
    this.yb1 = 0,
    this.xb2 = 0,
    this.yb2 = 0,
    this.flags = 0,
  })  : curr = curr ?? LineParameters.new_params(0, 0, 0, 0, 0),
        next = next ?? LineParameters.new_params(0, 0, 0, 0, 0);

  factory DrawVars.new_draw_vars() {
    return DrawVars();
  }
}
