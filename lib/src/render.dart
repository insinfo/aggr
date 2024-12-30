// ignore_for_file: omit_local_variable_types
import 'dart:math' as math;
import 'package:aggr/aggr.dart';
import 'package:aggr/src/base.dart';
import 'package:aggr/src/outline.dart';

/// constantes
const int LINE_MAX_LENGTH = 1 << (POLY_SUBPIXEL_SHIFT + 10);

/// Função len_i64_xy do Rust (em crate::raster::len_i64_xy).
int len_i64_xy(int x1, int y1, int x2, int y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return (math.sqrt((dx * dx + dy * dy).toDouble())).round();
}

/// Função (free function) do Rust: render_scanline_bin_solid.
void render_scanline_bin_solid<T extends Pixel, C extends Color>(
    ScanlineU8 sl, RenderingBase<T> ren, C color) {
  final cover_full = 255;
  final rgba =
      Rgba8(color.red8(), color.green8(), color.blue8(), color.alpha8());
  for (var span in sl.spans) {
    ren.blend_hline(
        span.x, sl.y, span.x - 1 + span.len.abs(), rgba, cover_full);
  }
}

/// Função (free function) do Rust: render_scanline_aa_solid.
void render_scanline_aa_solid<T extends Pixel, C extends Color>(
    ScanlineU8 sl, RenderingBase<T> ren, C color) {
  final rgba =
      Rgba8(color.red8(), color.green8(), color.blue8(), color.alpha8());
  final y = sl.y;
  for (var span in sl.spans) {
    final x = span.x;
    var length = span.len;
    if (length > 0) {
      ren.blend_solid_hspan(x, y, length, rgba, span.covers);
    } else {
      ren.blend_hline(x, y, x - length - 1, rgba, span.covers[0]);
    }
  }
}

/// Classe em Dart que espelha a SpanGradient do Rust.
class SpanGradient {
  int d1;
  int d2;
  GradientX gradient;
  List<Rgb8> color;
  Transform trans;

  SpanGradient(this.d1, this.d2, this.gradient, this.color, this.trans);

  /// Em Rust, subpixel_shift() -> i64.
  int subpixel_shift() => 4;

  /// Em Rust, subpixel_scale() -> i64.
  int subpixel_scale() => 1 << subpixel_shift();

  factory SpanGradient.new_span(Transform trans, GradientX gradient,
      List<Rgb8> color, double d1, double d2) {
    final s = SpanGradient(0, 1, gradient, [...color], trans);
    s.set_d1(d1);
    s.set_d2(d2);
    return s;
  }

  void set_d1(double val) {
    d1 = (val * subpixel_scale()).round();
  }

  void set_d2(double val) {
    d2 = (val * subpixel_scale()).round();
  }

  void prepare() {
    // no-op
  }

  List<Rgb8> generate(int x, int y, int len) {
    final interp = Interpolator.new_interpolator(trans);
    final downscale_shift = interp.subpixel_shift() - subpixel_shift();

    var dd = d2 - d1;
    if (dd < 1) {
      dd = 1;
    }
    final ncolors = color.length;
    final span = List<Rgb8>.filled(len, Rgb8.white());

    interp.begin(x.toDouble() + 0.5, y.toDouble() + 0.5, len);

    for (int i = 0; i < len; i++) {
      final coords = interp.coordinates();
      final xx = coords.item1 >> downscale_shift;
      final yy = coords.item2 >> downscale_shift;
      int d = gradient.calculate(xx, yy, d2);
      d = ((d - d1) * ncolors) ~/ dd;
      if (d < 0) {
        d = 0;
      }
      if (d >= ncolors) {
        d = ncolors - 1;
      }
      span[i] = color[d];
      interp.inc();
    }
    return span;
  }
}

/// Classe que espelha a GradientX do Rust.
class GradientX {
  int calculate(int x, int _, int __) {
    return x;
  }
}

/// Classe Interpolator (Rust).
class Interpolator {
  LineInterpolator? li_x;
  LineInterpolator? li_y;
  Transform trans;

  Interpolator(this.trans, this.li_x, this.li_y);

  static Interpolator new_interpolator(Transform t) {
    return Interpolator(t, null, null);
  }

  int subpixel_shift() => 8;
  int subpixel_scale() => 1 << subpixel_shift();

  void begin(double x, double y, int len) {
    final tx1 = x;
    final ty1 = y;
    final pair1 = trans.transform(tx1, ty1);
    final x1 = (pair1.item1 * subpixel_scale()).round();
    final y1 = (pair1.item2 * subpixel_scale()).round();

    final tx2 = x + len;
    final ty2 = y;
    final pair2 = trans.transform(tx2, ty2);
    final x2 = (pair2.item1 * subpixel_scale()).round();
    final y2 = (pair2.item2 * subpixel_scale()).round();

    li_x = LineInterpolator.new_line_interpolator(x1, x2, len);
    li_y = LineInterpolator.new_line_interpolator(y1, y2, len);
  }

  void inc() {
    if (li_x != null) {
      li_x!.inc();
    }
    if (li_y != null) {
      li_y!.inc();
    }
  }

  Tuple2 coordinates() {
    if (li_x != null && li_y != null) {
      return Tuple2(li_x!.y, li_y!.y);
    }
    throw StateError('Interpolator not initialized');
  }
}

/// Classe que emula a Transform do Rust (x' = x, y' = y, simplificada).
class Transform {
  const Transform();

  Tuple2 transform(double x, double y) {
    // Transformação de exemplo: identidade
    return Tuple2(x, y);
  }
}

/// Função Rust: render_scanline_aa (que usa spans gerados).
void render_scanline_aa<T extends Pixel>(
    ScanlineU8 sl, RenderingBase<T> ren, SpanGradient span_gen) {
  final y = sl.y;
  for (var span in sl.spans) {
    final x = span.x;
    var length = span.len;
    final covers = span.covers;
    if (length < 0) {
      length = -length;
    }
    final colors = span_gen.generate(x, y, length);
    ren.blend_color_hspan(
      x,
      y,
      length,
      colors.map((e) => Rgba8(e.r, e.g, e.b, 255)).toList(),
      span.len < 0 ? [] : covers,
      covers.isNotEmpty ? covers[0] : 255,
    );
  }
}

/// Classes de renderização do Rust, adaptadas para Dart:

/// Aliased Renderer
class RenderingScanlineBinSolid<T extends Pixel> implements Render {
  RenderingBase<T> base;
  Rgba8 _color;

  RenderingScanlineBinSolid(this.base, this._color);

  /// Em Rust: with_base
  factory RenderingScanlineBinSolid.with_base(RenderingBase<T> base) {
    return RenderingScanlineBinSolid(base, Rgba8.black());
  }

  @override
  void render(RenderData data) {
    render_scanline_bin_solid(data.sl, base, _color);
  }

  @override
  void color(Color c) {
    _color = Rgba8(c.red8(), c.green8(), c.blue8(), c.alpha8());
  }

  @override
  void prepare() {
    // no-op
  }

  List<int> as_bytes() => base.as_bytes();
  void to_file(String filename) => base.to_file(filename);
}

class RenderData {
  ScanlineU8 sl;

  /// Cria um novo RenderData com uma instância de ScanlineU8
  RenderData() : sl = ScanlineU8();
}

/// Anti-Aliased Renderer
class RenderingScanlineAASolid<T extends Pixel> implements Render {
  RenderingBase<T> base;
  Rgba8 _color;

  RenderingScanlineAASolid(this.base, this._color);

  factory RenderingScanlineAASolid.with_base(RenderingBase<T> base) {
    return RenderingScanlineAASolid(base, Rgba8.black());
  }

  @override
  void render(RenderData data) {
    render_scanline_aa_solid(data.sl, base, _color);
  }

  @override
  void color(Color c) {
    _color = Rgba8(c.red8(), c.green8(), c.blue8(), c.alpha8());
  }

  @override
  void prepare() {
    // no-op
  }

  List<int> as_bytes() => base.as_bytes();
  void to_file(String filename) => base.to_file(filename);
}

/// Anti-Aliased Renderer com SpanGradient
class RenderingScanlineAA<T extends Pixel> implements Render {
  RenderingBase<T> base;
  SpanGradient span;

  RenderingScanlineAA(this.base, this.span);

  @override
  void render(RenderData data) {
    render_scanline_aa(data.sl, base, span);
  }

  @override
  void color(Color c) {
    throw UnimplementedError("oops");
  }

  @override
  void prepare() {
    // no-op
  }
}

/// Funções livres de renderização (equivalentes às do Rust):
void render_scanlines_bin_solid<C extends Color, T extends Pixel>(
    RasterizerScanline ras, RenderingBase<T> ren, C color) {
  final sl = ScanlineU8();
  if (ras.rewind_scanlines()) {
    sl.reset(ras.min_x(), ras.max_x());
    while (ras.sweep_scanline(sl)) {
      render_scanline_bin_solid(sl, ren, color);
    }
  }
}

void render_scanlines_aa_solid<C extends Color, T extends Pixel>(
    RasterizerScanline ras, RenderingBase<T> ren, C color) {
  final sl = ScanlineU8();
  if (ras.rewind_scanlines()) {
    sl.reset(ras.min_x(), ras.max_x());
    while (ras.sweep_scanline(sl)) {
      render_scanline_aa_solid(sl, ren, color);
    }
  }
}

void render_scanlines<REN extends Render>(RasterizerScanline ras, REN ren) {
  final data = RenderData();
  if (ras.rewind_scanlines()) {
    data.sl.reset(ras.min_x(), ras.max_x());
    ren.prepare();
    while (ras.sweep_scanline(data.sl)) {
      ren.render(data);
    }
  }
}

void render_all_paths<REN extends Render, VS extends VertexSource,
        C extends Color>(
    RasterizerScanline ras, REN ren, List<VS> paths, List<C> colors) {
  assert(paths.length == colors.length);
  for (var i = 0; i < paths.length; i++) {
    final path = paths[i];
    final c = colors[i];
    ras.reset();
    ras.add_path(path);
    ren.color(c);
    render_scanlines(ras, ren);
  }
}

/// RasterizerScanline do Rust. Aqui, definimos uma classe de exemplo.
class RasterizerScanline {
  int _minX = 0;
  int _maxX = 0;
  bool _rewound = false;

  bool rewind_scanlines() {
    // Exemplo
    _rewound = true;
    return true;
  }

  bool sweep_scanline(ScanlineU8 sl) {
    // Exemplo fictício
    if (!_rewound) return false;
    _rewound = false;
    sl.y = 10;
    sl.spans = [
      Span.withValues(10, 5, [255, 255, 255, 255, 255]), // Exemplo
    ];
    return true;
  }

  int min_x() => _minX;
  int max_x() => _maxX;

  void reset() {
    // no-op
  }

  void add_path(VertexSource path) {
    // no-op
  }
}

/// BresehamInterpolator
class BresehamInterpolator {
  int x1;
  int y1;
  int x2;
  int y2;
  bool ver;
  int len;
  int inc;
  LineInterpolator func;

  BresehamInterpolator(this.x1, this.y1, this.x2, this.y2, this.ver, this.len,
      this.inc, this.func);

  factory BresehamInterpolator.new_breseham(
      Subpixel x1_hr, Subpixel y1_hr, Subpixel x2_hr, Subpixel y2_hr) {
    final x1 = x1_hr.value();
    final x2 = x2_hr.value();
    final y1 = y1_hr.value();
    final y2 = y2_hr.value();

    final dy = (y2 - y1).abs();
    final dx = (x2 - x1).abs();
    final ver = dy > dx;
    final length = ver ? dy : dx;
    final inc = ver ? (y2 > y1 ? 1 : -1) : (x2 > x1 ? 1 : -1);

    final z1 = ver ? x1_hr.value() : y1_hr.value();
    final z2 = ver ? x2_hr.value() : y2_hr.value();

    final func = LineInterpolator.new_line_interpolator(z1, z2, length);
    return BresehamInterpolator(x1, y1, x2, y2, ver, length, inc, func);
  }

  void vstep() {
    func.inc();
    y1 += inc;
    x2 = func.y >> POLY_SUBPIXEL_SHIFT;
  }

  void hstep() {
    func.inc();
    x1 += inc;
    y2 = func.y >> POLY_SUBPIXEL_SHIFT;
  }
}

/// Digital differential analyzer (LineInterpolator).
class LineInterpolator {
  int count;
  int left;
  int rem;
  int xmod;
  int y;

  LineInterpolator(this.count, this.left, this.rem, this.xmod, this.y);

  factory LineInterpolator.new_line_interpolator(int y1, int y2, int count) {
    final cnt = math.max(1, count);
    int left = (y2 - y1) ~/ cnt;
    int rem = (y2 - y1) % cnt;
    int xmod = rem;
    int y = y1;
    if (xmod <= 0) {
      xmod += cnt;
      rem += cnt;
      left -= 1;
    }
    xmod -= cnt;
    return LineInterpolator(cnt, left, rem, xmod, y);
  }

  void inc() {
    xmod += rem;
    y += left;
    if (xmod > 0) {
      xmod -= count;
      y += 1;
    }
  }

  void dec() {
    if (xmod <= rem) {
      xmod += count;
      y -= 1;
    }
    xmod -= rem;
    y -= left;
  }
}

/// Função de recorte de linha (clip_line_segment) do Rust.
Tuple5<int, int, int, int, int> clip_line_segment(
    int x1, int y1, int x2, int y2, Rectangle<i64> clip_box) {
  final f1 = clip_box.clip_flags(x1, y1);
  final f2 = clip_box.clip_flags(x2, y2);
  var ret = 0;
  if (f1 == INSIDE && f2 == INSIDE) {
    return Tuple5(x1, y1, x2, y2, 0);
  }
  final x_side = LEFT | RIGHT;
  final y_side = TOP | BOTTOM;
  if ((f1 & x_side) != 0 && ((f1 & x_side) == (f2 & x_side))) {
    return Tuple5(x1, y1, x2, y2, 4); // Outside
  }
  if ((f1 & y_side) != 0 && ((f1 & y_side) == (f2 & y_side))) {
    return Tuple5(x1, y1, x2, y2, 4); // Outside
  }

  int nx1 = x1, ny1 = y1;
  int nx2 = x2, ny2 = y2;
  if (f1 != 0) {
    final moved = clip_move_point(x1, y1, x2, y2, clip_box, x1, y1, f1);
    if (moved == null) {
      return Tuple5(nx1, ny1, nx2, ny2, 4);
    }
    nx1 = moved.item1;
    ny1 = moved.item2;
    if (nx1 == nx2 && ny1 == ny2) {
      return Tuple5(nx1, ny1, nx2, ny2, 4);
    }
    ret |= 1;
  }
  if (f2 != 0) {
    final moved = clip_move_point(nx1, ny1, x2, y2, clip_box, x2, y2, f2);
    if (moved == null) {
      return Tuple5(nx1, ny1, nx2, ny2, 4);
    }
    nx2 = moved.item1;
    ny2 = moved.item2;
    if (nx1 == nx2 && ny1 == ny2) {
      return Tuple5(nx1, ny1, nx2, ny2, 4);
    }
    ret |= 2;
  }
  return Tuple5(nx1, ny1, nx2, ny2, ret);
}

Tuple2<int, int>? clip_move_point(int x1, int y1, int x2, int y2,
    Rectangle<i64> clip_box, int x, int y, int flags) {
  int nx = x, ny = y;
  if ((flags & (LEFT | RIGHT)) != 0) {
    if (x1 == x2) {
      return null;
    } else {
      nx = (flags & LEFT) != 0 ? clip_box.x1 : clip_box.x2;
      ny = ((nx - x1) * (y2 - y1) / (x2 - x1) + y1).toInt();
    }
  }
  final f = clip_box.clip_flags(nx, ny);
  if ((f & (TOP | BOTTOM)) != 0) {
    if (y1 == y2) {
      return null;
    } else {
      ny = (f & BOTTOM) != 0 ? clip_box.y1 : clip_box.y2;
      nx = ((ny - y1) * (x2 - x1) / (y2 - y1) + x1).toInt();
    }
  }
  return Tuple2(nx, ny);
}

/// Exemplo de RendererOutlineImg do Rust, adaptado.
class RendererOutlineImg<T extends Pixel> implements DrawOutline {
  RenderingBase<T> ren;
  LineImagePatternPow2 pattern;
  int start;
  double scale_x;
  Rectangle<i64>? clip_box;

  RendererOutlineImg(
      this.ren, this.pattern, this.start, this.scale_x, this.clip_box);

  factory RendererOutlineImg.with_base_and_pattern(
      RenderingBase<T> ren, LineImagePatternPow2 pattern) {
    return RendererOutlineImg(ren, pattern, 0, 1.0, null);
  }

  @override
  bool accurate_join_only() => true;

  @override
  void color(Color color) {
    throw UnimplementedError('no color for outline img');
  }

  @override
  void line0(LineParameters lp) {
    // no-op
  }

  @override
  void line1(LineParameters lp, int sx, int sy) {
    // no-op
  }

  @override
  void line2(LineParameters lp, int ex, int ey) {
    // no-op
  }

  @override
  void line3(LineParameters lp, int sx, int sy, int ex, int ey) {
    if (clip_box != null) {
      final boxx = clip_box!;
      final c = clip_line_segment(lp.x1, lp.y1, lp.x2, lp.y2, boxx);
      final clip_flag = c.item5;
      var (x1, y1, x2, y2) = (c.item1, c.item2, c.item3, c.item4);
      final saved_start = start;

      var nsx = sx, nsy = sy, nex = ex, ney = ey;

      if ((clip_flag & 4) == 0) {
        if (clip_flag != 0) {
          final lp2 = LineParameters.new_params(
              x1, y1, x2, y2, len_i64_xy(x1, y1, x2, y2));
          if ((clip_flag & 1) != 0) {
            start += (len_i64_xy(lp.x1, lp.y1, x1, y1) / scale_x).round();
            nsx = x1 + (y2 - y1);
            nsy = y1 - (x2 - x1);
          } else {
            while ((nsx - lp.x1).abs() + (nsy - lp.y1).abs() > lp2.len) {
              nsx = (lp.x1 + nsx) >> 1;
              nsy = (lp.y1 + nsy) >> 1;
            }
          }
          if ((clip_flag & 2) != 0) {
            nex = x2 + (y2 - y1);
            ney = y2 - (x2 - x1);
          } else {
            while ((nex - lp.x2).abs() + (ney - lp.y2).abs() > lp2.len) {
              nex = (lp.x2 + nex) >> 1;
              ney = (lp.y2 + ney) >> 1;
            }
          }
          line3_no_clip(lp2, nsx, nsy, nex, ney);
        } else {
          line3_no_clip(lp, nsx, nsy, nex, ney);
        }
      }
      start = saved_start + (lp.len / scale_x).round();
    } else {
      line3_no_clip(lp, sx, sy, ex, ey);
    }
  }

  void line3_no_clip(LineParameters lp, int sx, int sy, int ex, int ey) {
    if (lp.len > LINE_MAX_LENGTH) {
      // Divisão recursiva
      final divided = lp.divide(); // unimplemented
      throw UnimplementedError('line3_no_clip subdivisão não implementada');
    }
    final fixedStart = lp.fix_degenerate_bisectrix_start(sx, sy);
    final fixedEnd = lp.fix_degenerate_bisectrix_end(ex, ey);
    final li = lp.interp_image(
        fixedStart.item1,
        fixedStart.item2,
        fixedEnd.item1,
        fixedEnd.item2,
        subpixel_width(),
        start,
        pattern_width(),
        scale_x);
    if (lp.vertical) {
      while (li.step_ver(this)) {}
    } else {
      while (li.step_hor(this)) {}
    }
    start += (lp.len / scale_x).round();
  }

  int subpixel_width() => pattern.line_width();
  int pattern_width() => pattern.pattern_width();

  Rgba8 pixel(int x, int y) => pattern.pixel(x, y);

  void blend_color_hspan(int x, int y, int len, List<Rgba8> colors) {
    ren.blend_color_hspan(x, y, len, colors, const [], 255);
  }

  void blend_color_vspan(int x, int y, int len, List<Rgba8> colors) {
    ren.blend_color_vspan(x, y, len, colors, [], 255);
  }

  @override
  void semidot(dynamic cmp, int xc1, int yc1, int xc2, int yc2) {
    // no-op
  }

  @override
  void pie(int xc, int y, int x1, int y1, int x2, int y2) {
    // no-op
  }
}

/// Linha de padrões de imagem (LineImagePattern do Rust) adaptada.
class LineImagePattern {
  late PixfmtRgba8 pix;
  PatternFilterBilinear filter;
  int dilation;
  int dilation_hr;
  int width;
  int height;
  int width_hr;
  int half_height_hr;
  int offset_y_hr;

  LineImagePattern(this.filter)
      : dilation = filter.dilation() + 1,
        dilation_hr = ((filter.dilation() + 1) << POLY_SUBPIXEL_SHIFT),
        width = 0,
        height = 0,
        width_hr = 0,
        half_height_hr = 0,
        offset_y_hr = 0 {
    pix = PixfmtRgba8.newPixfmt(1, 1);
  }

  void create(Pixel src) {
    // bug aqui
    height = src.height();
    width = src.width();
    width_hr = width * POLY_SUBPIXEL_SCALE;
    half_height_hr = (height * POLY_SUBPIXEL_SCALE) ~/ 2;
    offset_y_hr = dilation_hr + half_height_hr - (POLY_SUBPIXEL_SCALE ~/ 2);
    half_height_hr += (POLY_SUBPIXEL_SCALE ~/ 2);

    pix = PixfmtRgba8.newPixfmt((width + dilation * 2), (height + dilation * 2));

    // Copiar pixels
    for (int y = 0; y < height; y++) {
      final x1 = dilation;
      final y1 = y + dilation;
      for (int x = 0; x < width; x++) {
        pix.set_pixel(x1 + x, y1, src.get_pixel(x, y));
      }
    }
    // Zerar faixas de "dilatação"
    final none = Rgba8(0, 0, 0, 0);
    for (int y = 0; y < dilation; y++) {
      // parte inferior e superior
      final x1 = dilation;
      final y1 = y + height + dilation;
      final x2 = dilation;
      final y2 = dilation - y - 1;
      for (int x = 0; x < width; x++) {
        pix.set_pixel(x1 + x, y1, none);
        pix.set_pixel(x2 + x, y2, none);
      }
    }
    final h = height + dilation * 2;
    for (int y = 0; y < h; y++) {
      final sx1 = dilation;
      final sx2 = dilation + width;
      for (int xx = 0; xx < dilation; xx++) {
        final dx1 = sx2 + xx;
        final dx2 = sx1 - xx - 1;
        // Copiamos ou deixamos none?
        pix.set_pixel(dx1, y, pix.get_pixel(sx1 + xx, y));
        pix.set_pixel(dx2, y, pix.get_pixel(sx2 - xx - 1, y));
      }
    }
  }

  int pattern_width() => width_hr;
  int line_width() => half_height_hr;
  int getWidth() => height; // ???
}

/// Versão pow2 do LineImagePattern.
class LineImagePatternPow2 {
  LineImagePattern base;
  int mask;

  LineImagePatternPow2(this.base, this.mask);

  factory LineImagePatternPow2.new_pow2(PatternFilterBilinear filter) {
    final b = LineImagePattern(filter);
    return LineImagePatternPow2(b, POLY_SUBPIXEL_MASK);
  }

  void create(Pixel src) {
    base.create(src);
    int m = 1;
    while (m < base.width) {
      m <<= 1;
      m |= 1;
    }
    m <<= (POLY_SUBPIXEL_SHIFT - 1);
    m |= POLY_SUBPIXEL_MASK;
    base.width_hr = m + 1;
    mask = m;
  }

  int pattern_width() => base.width_hr;
  int line_width() => base.half_height_hr;
  int getWidth() => base.height;

  Rgba8 pixel(int x, int y) {
    return base.filter.pixel_high_res(
      base.pix,
      (x & mask) + base.dilation_hr,
      y + base.offset_y_hr,
    );
  }
}

/// Filter bilinear do Rust.
class PatternFilterBilinear {
  int dilation() => 1;

  Rgba8 pixel_low_res(PixfmtRgba8 pix, int x, int y) {
    return pix.get_pixel(x, y);
  }

  Rgba8 pixel_high_res(PixfmtRgba8 pix, int x, int y) {
    int red = 0, green = 0, blue = 0, alpha = 0;

    final x_lr = x >> POLY_SUBPIXEL_SHIFT;
    final y_lr = y >> POLY_SUBPIXEL_SHIFT;

    final fx = x & POLY_SUBPIXEL_MASK;
    final fy = y & POLY_SUBPIXEL_MASK;

    final ptr1 = pix.get_pixel(x_lr, y_lr);
    int weight = (POLY_SUBPIXEL_SCALE - fx) * (POLY_SUBPIXEL_SCALE - fy);

    red += (weight * ptr1.r);
    green += (weight * ptr1.g);
    blue += (weight * ptr1.b);
    alpha += (weight * ptr1.a);

    final ptr2 = pix.get_pixel(x_lr + 1, y_lr);
    weight = fx * (POLY_SUBPIXEL_SCALE - fy);

    red += weight * ptr2.r;
    green += weight * ptr2.g;
    blue += weight * ptr2.b;
    alpha += weight * ptr2.a;

    final ptr3 = pix.get_pixel(x_lr, y_lr + 1);
    weight = (POLY_SUBPIXEL_SCALE - fx) * fy;

    red += weight * ptr3.r;
    green += weight * ptr3.g;
    blue += weight * ptr3.b;
    alpha += weight * ptr3.a;

    final ptr4 = pix.get_pixel(x_lr + 1, y_lr + 1);
    weight = fx * fy;

    red += weight * ptr4.r;
    green += weight * ptr4.g;
    blue += weight * ptr4.b;
    alpha += weight * ptr4.a;

    final shift2 = POLY_SUBPIXEL_SHIFT * 2;
    return Rgba8(
      (red >> shift2),
      (green >> shift2),
      (blue >> shift2),
      (alpha >> shift2),
    );
  }
}

/// LineInterpolatorImage do Rust, adaptado em Dart.
class LineInterpolatorImage {
  LineParameters lp;
  LineInterpolator li;
  DistanceInterpolator4 di;
  int x;
  int y;
  int old_x;
  int old_y;
  int count;
  int width;
  int max_extent;
  int start;
  int step;
  List<int> dist_pos;
  List<Rgba8> colors;

  LineInterpolatorImage(
      this.lp,
      this.li,
      this.di,
      this.x,
      this.y,
      this.old_x,
      this.old_y,
      this.count,
      this.width,
      this.max_extent,
      this.start,
      this.step,
      this.dist_pos,
      this.colors);

  factory LineInterpolatorImage.new_interpolator_image(
      LineParameters lp,
      int sx,
      int sy,
      int ex,
      int ey,
      int subpixel_width,
      int pattern_start,
      int pattern_width,
      double scale_x) {
    final vertical = lp.vertical;
    final n = vertical ? (lp.y2 - lp.y1).abs() : (lp.x2 - lp.x1).abs() + 1;
    final y1 = vertical
        ? ((lp.x2 - lp.x1) << POLY_SUBPIXEL_SHIFT)
        : ((lp.y2 - lp.y1) << POLY_SUBPIXEL_SHIFT);

    final m_li = LineInterpolator.new_line_interpolator(y1, 0, n);
    int x = lp.x1 >> POLY_SUBPIXEL_SHIFT;
    int y = lp.y1 >> POLY_SUBPIXEL_SHIFT;
    int old_x = x;
    int old_y = y;
    final cnt = vertical
        ? ((lp.y2 >> POLY_SUBPIXEL_SHIFT) - y).abs()
        : ((lp.x2 >> POLY_SUBPIXEL_SHIFT) - x).abs();
    final w = subpixel_width;
    final max_ext = ((w + POLY_SUBPIXEL_SCALE) >> POLY_SUBPIXEL_SHIFT);
    int stp = 0;
    final st = pattern_start + (max_ext + 2) * pattern_width;
    final distPos = List<int>.filled(MAX_HALF_WIDTH + 1, 0);
    final cols =
        List<Rgba8>.filled(MAX_HALF_WIDTH * 2 + 4, Rgba8(0, 0, 0, 255));

    final di = DistanceInterpolator4.new_di4(
      lp.x1,
      lp.y1,
      lp.x2,
      lp.y2,
      sx,
      sy,
      ex,
      ey,
      lp.len,
      scale_x,
      (lp.x1 & ~POLY_SUBPIXEL_MASK),
      (lp.y1 & ~POLY_SUBPIXEL_MASK),
    );

    final dd = vertical
        ? (lp.dy << POLY_SUBPIXEL_SHIFT)
        : (lp.dx << POLY_SUBPIXEL_SHIFT);
    final tmp_li = LineInterpolator.new_line_interpolator(0, dd, lp.len);

    final stop = w + POLY_SUBPIXEL_SCALE * 2;
    for (int i = 0; i < MAX_HALF_WIDTH; i++) {
      distPos[i] = tmp_li.y;
      if (distPos[i] >= stop) {
        break;
      }
      tmp_li.inc();
    }
    distPos[MAX_HALF_WIDTH] = 0x7FFF0000;

    return LineInterpolatorImage(lp, m_li, di, x, y, old_x, old_y, cnt, w,
        max_ext, st, stp, distPos, cols);
  }

  bool vertical() => lp.vertical;

  bool step_ver(RendererOutlineImg ren) {
    li.inc();
    y += lp.inc;
    x = (lp.x1 + li.y) >> POLY_SUBPIXEL_SHIFT;

    if (lp.inc > 0) {
      di.inc_y_by(x - old_x);
    } else {
      di.dec_y_by(x - old_x);
    }
    old_x = x;

    var s1 = di.dist / lp.len;
    var s2 = -s1;
    if (lp.inc > 0) {
      s1 = -s1;
    }
    var dist_start = di.dist_start;
    var dist_pict = di.dist_pict + start;
    var dist_end = di.dist_end;
    var p0 = MAX_HALF_WIDTH + 2;
    var p1 = p0;
    var npix = 0;
    colors[p1] = Rgba8(0, 0, 0, 0);
    if (dist_end > 0) {
      if (dist_start <= 0) {
        colors[p1] = ren.pixel(dist_pict, s2.toInt());
      }
      npix += 1;
    }
    p1++;
    var dx = 1;
    var dist = dist_pos[dx];
    while (dist - s1 <= width) {
      dist_start += di.dy_start;
      dist_pict += di.dy_pict;
      dist_end += di.dy_end;
      colors[p1] = Rgba8(0, 0, 0, 0);
      if (dist_end > 0 && dist_start <= 0) {
        int ddist = dist;
        if (lp.inc > 0) {
          ddist = -dist;
        }
        colors[p1] = ren.pixel(dist_pict, (s2 + ddist).toInt());
        npix += 1;
      }
      p1++;
      dx++;
      dist = dist_pos[dx];
    }

    dx = 1;
    dist_start = di.dist_start;
    dist_pict = di.dist_pict + start;
    dist_end = di.dist_end;
    dist = dist_pos[dx];
    while (dist + s1 <= width) {
      dist_start -= di.dy_start;
      dist_pict -= di.dy_pict;
      dist_end -= di.dy_end;
      p0--;
      colors[p0] = Rgba8(0, 0, 0, 0);
      if (dist_end > 0 && dist_start <= 0) {
        int ddist = dist;
        if (lp.inc > 0) {
          ddist = -dist;
        }
        colors[p0] = ren.pixel(dist_pict, (s2 - ddist).toInt());
        npix += 1;
      }
      dx++;
      dist = dist_pos[dx];
    }

    ren.blend_color_hspan(x - dx + 1, y, (p1 - p0), colors.sublist(p0, p1));
    step++;
    return npix != 0 && step < count;
  }

  bool step_hor(RendererOutlineImg ren) {
    li.inc();
    x += lp.inc;
    y = (lp.y1 + li.y) >> POLY_SUBPIXEL_SHIFT;

    if (lp.inc > 0) {
      di.inc_x_by(y - old_y);
    } else {
      di.dec_x_by(y - old_y);
    }
    old_y = y;

    var s1 = di.dist / lp.len;
    var s2 = -s1;
    if (lp.inc < 0) {
      s1 = -s1;
    }

    var dist_start = di.dist_start;
    var dist_pict = di.dist_pict + start;
    var dist_end = di.dist_end;
    var p0 = MAX_HALF_WIDTH + 2;
    var p1 = p0;

    var npix = 0;
    colors[p1] = Rgba8(0, 0, 0, 0);
    if (dist_end > 0) {
      if (dist_start <= 0) {
        colors[p1] = ren.pixel(dist_pict, s2.toInt());
      }
      npix += 1;
    }
    p1++;

    var dy = 1;
    var dist = dist_pos[dy];
    while (dist - s1 <= width) {
      dist_start -= di.dx_start;
      dist_pict -= di.dx_pict;
      dist_end -= di.dx_end;
      colors[p1] = Rgba8(0, 0, 0, 0);
      if (dist_end > 0 && dist_start <= 0) {
        int ddist = dist;
        if (lp.inc > 0) {
          ddist = -dist;
        }
        colors[p1] = ren.pixel(dist_pict, (s2 - ddist).toInt());
        npix += 1;
      }
      p1++;
      dy++;
      dist = dist_pos[dy];
    }

    dy = 1;
    dist_start = di.dist_start;
    dist_pict = di.dist_pict + start;
    dist_end = di.dist_end;
    dist = dist_pos[dy];
    while (dist + s1 <= width) {
      dist_start += di.dx_start;
      dist_pict += di.dx_pict;
      dist_end += di.dx_end;
      p0--;
      colors[p0] = Rgba8(0, 0, 0, 0);
      if (dist_end > 0 && dist_start <= 0) {
        int ddist = dist;
        if (lp.inc > 0) {
          ddist = -dist;
        }
        colors[p0] = ren.pixel(dist_pict, (s2 + ddist).toInt());
        npix += 1;
      }
      dy++;
      dist = dist_pos[dy];
    }

    ren.blend_color_vspan(x, y - dy + 1, (p1 - p0), colors.sublist(p0, p1));
    step++;
    return npix != 0 && step < count;
  }
}

/// Classe DistanceInterpolator4 do Rust.
class DistanceInterpolator4 {
  int dx;
  int dy;
  int dx_start;
  int dy_start;
  int dx_pict;
  int dy_pict;
  int dx_end;
  int dy_end;
  int dist;
  int dist_start;
  int dist_pict;
  int dist_end;
  int len;

  DistanceInterpolator4(
      this.dx,
      this.dy,
      this.dx_start,
      this.dy_start,
      this.dx_pict,
      this.dy_pict,
      this.dx_end,
      this.dy_end,
      this.dist,
      this.dist_pict,
      this.dist_start,
      this.dist_end,
      this.len);

  factory DistanceInterpolator4.new_di4(int x1, int y1, int x2, int y2, int sx,
      int sy, int ex, int ey, int length, double scale, int xx, int yy) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dx_start = line_mr(sx) - line_mr(x1);
    final dy_start = line_mr(sy) - line_mr(y1);
    final dx_end = line_mr(ex) - line_mr(x2);
    final dy_end = line_mr(ey) - line_mr(y2);

    final dist = (((xx + (POLY_SUBPIXEL_SCALE >> 1) - x2) * (dy)) -
            ((yy + (POLY_SUBPIXEL_SCALE >> 1) - y2) * (dx)))
        .round();

    final dist_start =
        ((line_mr(xx + (POLY_SUBPIXEL_SCALE >> 1)) - line_mr(sx)) * dy_start) -
            ((line_mr(yy + (POLY_SUBPIXEL_SCALE >> 1)) - line_mr(sy)) *
                dx_start);
    final dist_end =
        ((line_mr(xx + (POLY_SUBPIXEL_SCALE >> 1)) - line_mr(ex)) * dy_end) -
            ((line_mr(yy + (POLY_SUBPIXEL_SCALE >> 1)) - line_mr(ey)) * dx_end);
    final len = (length / scale).round();

    final d = len * scale;
    final tdx = (((x2 - x1) << POLY_SUBPIXEL_SHIFT) / d).round();
    final tdy = (((y2 - y1) << POLY_SUBPIXEL_SHIFT) / d).round();

    final dx_pict = -tdy;
    final dy_pict = tdx;
    final dist_pict =
        (((xx + (POLY_SUBPIXEL_SCALE >> 1) - (x1 - tdy)) * dy_pict) -
                ((yy + (POLY_SUBPIXEL_SCALE >> 1) - (y1 + tdx)) * dx_pict)) >>
            POLY_SUBPIXEL_SHIFT;

    final dx_ = dx << POLY_SUBPIXEL_SHIFT;
    final dy_ = dy << POLY_SUBPIXEL_SHIFT;
    final dx_start_ = dx_start << POLY_MR_SUBPIXEL_SHIFT;
    final dy_start_ = dy_start << POLY_MR_SUBPIXEL_SHIFT;
    final dx_end_ = dx_end << POLY_MR_SUBPIXEL_SHIFT;
    final dy_end_ = dy_end << POLY_MR_SUBPIXEL_SHIFT;

    return DistanceInterpolator4(dx_, dy_, dx_start_, dy_start_, dx_pict,
        dy_pict, dx_end_, dy_end_, dist, dist_pict, dist_start, dist_end, len);
  }

  void inc_x_by(int dy) {
    dist += this.dy;
    dist_start += dy_start;
    dist_pict += dy_pict;
    dist_end += dy_end;
    if (dy > 0) {
      dist -= dx;
      dist_start -= dx_start;
      dist_pict -= dx_pict;
      dist_end -= dx_end;
    }
    if (dy < 0) {
      dist += dx;
      dist_start += dx_start;
      dist_pict += dx_pict;
      dist_end += dx_end;
    }
  }

  void dec_x_by(int dy) {
    dist -= this.dy;
    dist_start -= dy_start;
    dist_pict -= dy_pict;
    dist_end -= dy_end;
    if (dy > 0) {
      dist -= dx;
      dist_start -= dx_start;
      dist_pict -= dx_pict;
      dist_end -= dx_end;
    }
    if (dy < 0) {
      dist += dx;
      dist_start += dx_start;
      dist_pict += dx_pict;
      dist_end += dx_end;
    }
  }

  void inc_y_by(int dx) {
    dist -= this.dx;
    dist_start -= dx_start;
    dist_pict -= dx_pict;
    dist_end -= dx_end;
    if (dx > 0) {
      dist += this.dy;
      dist_start += dy_start;
      dist_pict += dy_pict;
      dist_end += dy_end;
    }
    if (dx < 0) {
      dist -= this.dy;
      dist_start -= dy_start;
      dist_pict -= dy_pict;
      dist_end -= dy_end;
    }
  }

  void dec_y_by(int dx) {
    dist += this.dx;
    dist_start += dx_start;
    dist_pict += dx_pict;
    dist_end += dx_end;
    if (dx > 0) {
      dist += this.dy;
      dist_start += dy_start;
      dist_pict += dy_pict;
      dist_end += dy_end;
    }
    if (dx < 0) {
      dist -= this.dy;
      dist_start -= dy_start;
      dist_pict -= dy_pict;
      dist_end -= dy_end;
    }
  }
}
