import 'dart:typed_data';

import 'package:aggr/aggr.dart';
import 'package:aggr/src/ppm.dart';
import 'dart:math' as math;

class RenderingBuffer {
  final int width;
  final int height;
  final int bpp; // bytes por pixel

  Uint8List data;

  RenderingBuffer(this.width, this.height, this.bpp)
      : data = Uint8List(width * height * bpp);

  int len() => data.length;

  void clear() {
    data.fillRange(0, data.length, 255);
  }

  // Usando sublistView para retornar uma *view* do buffer,
  // em vez de criar uma cópia.
  List<int> operator [](List<int> xy) {
    final x = xy[0];
    final y = xy[1];
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return <int>[];
    }
    final index = (x + y * width) * bpp;
    return Uint8List.sublistView(data, index, index + bpp);
  }

  RenderingBuffer.fromBuf(Uint8List buf, int w, int h, int bpp)
      : width = w,
        height = h,
        bpp = bpp,
        data = buf;
}

class Pixfmt<T> extends Pixel {
  final RenderingBuffer rbuf;

  Pixfmt(this.rbuf);

  factory Pixfmt.newPixfmt(int width, int height, int bpp) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Cannot create Pixfmt with zero dimension');
    }
    final rbuf = RenderingBuffer(width, height, bpp);
    return Pixfmt<T>(rbuf);
  }

  static Future<Pixfmt<T>> from_file<T>(String filename) async {
    final image = await read_file(filename);
    final w = image.item2;
    final h = image.item3;
    final rbuf = RenderingBuffer.fromBuf(image.item1, w, h, 3);
    return Pixfmt<T>(rbuf);
  }

  void copy_pixel(int x, int y, Color c) {
    if (x >= rbuf.width || y >= rbuf.height) {
      return;
    }
    set_pixel(x, y, c);
  }

  void copy_hline(int x, int y, int n, Color c) {
    if (y < 0 || y >= rbuf.height || x >= rbuf.width || n == 0) return;
    final maxN = math.min(rbuf.width - x, n);
    for (var i = 0; i < maxN; i++) {
      set_pixel(x + i, y, c);
    }
  }

  void copy_vline(int x, int y, int n, Color c) {
    if (x < 0 || x >= rbuf.width || y >= rbuf.height || n == 0) return;
    final maxN = math.min(rbuf.height - y, n);
    for (var i = 0; i < maxN; i++) {
      set_pixel(x, y + i, c);
    }
  }

  @override
  String toString() {
    return 'Pixfmt<$T>(RenderingBuffer ${rbuf.data})';
  }

  @override
  int cover_mask() => 255;

  @override
  int bpp() => rbuf.bpp;

  @override
  List<int> as_bytes() => rbuf.data;

  @override
  Future<void> to_file(String filename) async {
    throw UnimplementedError('Please override to_file in subclasses');
  }

  @override
  int width() => rbuf.width;

  @override
  int height() => rbuf.height;

  @override
  void set_pixel(int x, int y, Color c) {
    // Genérico: cada subclass deverá realmente sobrescrever e implementar
    // a escrita na memória, pois aqui não sabemos como converter Color -> T
    throw UnimplementedError('Override set_pixel in subclasses');
  }

  @override
  void setn_pixel(int x, int y, int n, Color c) {
    // Genérico: cada subclass deverá sobrescrever (se quiser otimizar)
    // ou usar a implementação "ingênua" aqui
    for (var i = 0; i < n; i++) {
      set_pixel(x + i, y, c);
    }
  }

  @override
  void blend_pix(int x, int y, Color c, int cover) {
    // Genérico: cada subclass deverá sobrescrever
    throw UnimplementedError('Override blend_pix in subclasses');
  }

  @override
  void fill(Color color) {
    // Genérico: cada subclass deverá sobrescrever para otimizar (ou usar loop)
    for (var yy = 0; yy < height(); yy++) {
      for (var xx = 0; xx < width(); xx++) {
        set_pixel(xx, yy, color);
      }
    }
  }

  // -- Métodos extras (não pertencem a Pixel mas podem ser úteis) --
  int size() => rbuf.len();

  void clear() => rbuf.clear();

  /// Lê o pixel da posição [x, y].
  @override
  Color get_pixel(int x, int y) {
    // Cada subclasse deverá sobrescrever, se quiser
    throw UnimplementedError('Override get_pixel in subclasses');
  }

  /// Apenas um atalho do Source<T>.
  Color get_pixel_source(int x, int y) {
    return get_pixel(x, y);
  }
}

/// ---------------------------------------------------------------------------
/// PixfmtRgba8
/// ---------------------------------------------------------------------------
class PixfmtRgba8 extends Pixfmt<Rgba8> {
  PixfmtRgba8(RenderingBuffer rbuf) : super(rbuf);

  factory PixfmtRgba8.newPixfmt(int width, int height) {
    return PixfmtRgba8(RenderingBuffer(width, height, 4));
  }

  @override
  Rgba8 get_pixel(int x, int y) {
    final p = rbuf[[x, y]];
    if (p.isEmpty) return Rgba8.white(); // fora do range
    return Rgba8(p[0], p[1], p[2], p[3]);
  }

  @override
  void set_pixel(int x, int y, Color c) {
    final dataSlice = rbuf[[x, y]];
    if (dataSlice.isEmpty) return; // fora do range

    final px = Rgba8.from_color(c);
    dataSlice[0] = px.r;
    dataSlice[1] = px.g;
    dataSlice[2] = px.b;
    dataSlice[3] = px.a;
  }

  @override
  void setn_pixel(int x, int y, int n, Color c) {
    final px = Rgba8.from_color(c);
    for (var i = 0; i < n; i++) {
      set_pixel(x + i, y, px);
    }
  }

  @override
  void blend_pix(int x, int y, Color c, int cover) {
    if (cover == 0) return; // nada a fazer
    final existing = get_pixel(x, y);
    final overlay = Rgba8.from_color(c);

    // alpha total = overlay.a * cover/255
    final alpha = multiply_u8(overlay.a, cover);

    final newR = lerp_u8(existing.r, overlay.r, alpha);
    final newG = lerp_u8(existing.g, overlay.g, alpha);
    final newB = lerp_u8(existing.b, overlay.b, alpha);
    final newA = lerp_u8(existing.a, overlay.a, alpha);

    set_pixel(x, y, Rgba8(newR, newG, newB, newA));
  }

  @override
  Future<void> to_file(String filename) async {
    await write_file(rbuf.data, width(), height(), filename);
  }

  @override
  void fill(Color color) {
    final px = Rgba8.from_color(color);
    for (var yy = 0; yy < height(); yy++) {
      for (var xx = 0; xx < width(); xx++) {
        set_pixel(xx, yy, px);
      }
    }
  }
}

/// ---------------------------------------------------------------------------
/// PixfmtRgb8
/// ---------------------------------------------------------------------------
class PixfmtRgb8 extends Pixfmt<Rgb8> {
  PixfmtRgb8(RenderingBuffer rbuf) : super(rbuf);

  factory PixfmtRgb8.newPixfmt(int width, int height) {
    return PixfmtRgb8(RenderingBuffer(width, height, 3));
  }

  @override
  Rgba8 get_pixel(int x, int y) {
    final p = rbuf[[x, y]];
    if (p.isEmpty) return Rgba8.white();
    return Rgba8(p[0], p[1], p[2], 255);
  }

  @override
  void set_pixel(int x, int y, Color c) {
    final dataSlice = rbuf[[x, y]];
    if (dataSlice.isEmpty) return;

    final px = Rgba8.from_color(c);
    dataSlice[0] = px.r;
    dataSlice[1] = px.g;
    dataSlice[2] = px.b;
  }

  @override
  void setn_pixel(int x, int y, int n, Color c) {
    // Uma forma otimizada
    final px = Rgba8.from_color(c);
    for (var i = 0; i < n; i++) {
      set_pixel(x + i, y, px);
    }
  }

  @override
  void blend_pix(int x, int y, Color c, int cover) {
    if (cover == 0) return;
    final existing = get_pixel(x, y);
    final overlay = Rgba8.from_color(c);

    final alpha = cover / 255.0;
    final newR = (overlay.r * alpha + existing.r * (1 - alpha)).round();
    final newG = (overlay.g * alpha + existing.g * (1 - alpha)).round();
    final newB = (overlay.b * alpha + existing.b * (1 - alpha)).round();

    set_pixel(x, y, Rgb8(newR, newG, newB));
  }

  @override
  Future<void> to_file(String filename) async {
    await write_file(rbuf.data, width(), height(), filename);
  }

  @override
  void fill(Color color) {
    final px = Rgb8.from_color(color);
    for (var yy = 0; yy < height(); yy++) {
      for (var xx = 0; xx < width(); xx++) {
        set_pixel(xx, yy, px);
      }
    }
  }
}

/// ---------------------------------------------------------------------------
/// PixfmtRgba8pre
/// ---------------------------------------------------------------------------
class PixfmtRgba8pre extends Pixfmt<Rgba8pre> {
  PixfmtRgba8pre(RenderingBuffer rbuf) : super(rbuf);

  factory PixfmtRgba8pre.newPixfmt(int width, int height) {
    return PixfmtRgba8pre(RenderingBuffer(width, height, 4));
  }

  @override
  Rgba8 get_pixel(int x, int y) {
    final p = rbuf[[x, y]];
    if (p.isEmpty) return Rgba8.white();
    // Aqui retornamos Rgba8 sem "despremultiplicar",
    // mas se quisesse converter de premult, precisaria normalizar.
    return Rgba8(p[0], p[1], p[2], p[3]);
  }

  @override
  void set_pixel(int x, int y, Color c) {
    final dataSlice = rbuf[[x, y]];
    if (dataSlice.isEmpty) return;
    final pxPre = Rgba8pre.from_color(c); // premultiplicado
    dataSlice[0] = pxPre.r;
    dataSlice[1] = pxPre.g;
    dataSlice[2] = pxPre.b;
    dataSlice[3] = pxPre.a;
  }

  @override
  void setn_pixel(int x, int y, int n, Color c) {
    final pxPre = Rgba8pre.from_color(c);
    for (var i = 0; i < n; i++) {
      set_pixel(x + i, y, pxPre);
    }
  }

  @override
  void blend_pix(int x, int y, Color c, int cover) {
    if (cover == 0) return;
    final existing = get_pixel(x, y); // Rgba8 (não premultiplicado)
    final overlay = Rgba8.from_color(c);
    final alpha = multiply_u8(overlay.a, cover);

    final rr = lerp_u8(existing.r, overlay.r, alpha);
    final gg = lerp_u8(existing.g, overlay.g, alpha);
    final bb = lerp_u8(existing.b, overlay.b, alpha);
    final aa = lerp_u8(existing.a, overlay.a, alpha);

    // Armazena como premultiplicado
    final newPre = Rgba8pre.from_color(Rgba8(rr, gg, bb, aa));
    set_pixel(x, y, newPre);
  }

  @override
  Future<void> to_file(String filename) async {
    await write_file(rbuf.data, width(), height(), filename);
  }

  @override
  void fill(Color color) {
    final pxPre = Rgba8pre.from_color(color);
    for (var yy = 0; yy < height(); yy++) {
      for (var xx = 0; xx < width(); xx++) {
        set_pixel(xx, yy, pxPre);
      }
    }
  }
}

/// ---------------------------------------------------------------------------
/// PixfmtGray8
/// ---------------------------------------------------------------------------
class PixfmtGray8 extends Pixfmt<Gray8> {
  PixfmtGray8(RenderingBuffer rbuf) : super(rbuf);

  factory PixfmtGray8.newPixfmt(int width, int height) {
    return PixfmtGray8(RenderingBuffer(width, height, 2));
  }

  @override
  Rgba8 get_pixel(int x, int y) {
    final p = rbuf[[x, y]];
    if (p.isEmpty) return Rgba8.white();
    return Rgba8(p[0], p[0], p[0], p[1]);
  }

  @override
  void set_pixel(int x, int y, Color c) {
    final dataSlice = rbuf[[x, y]];
    if (dataSlice.isEmpty) return;
    final px = Gray8.from_color(c);
    dataSlice[0] = px.value;
    dataSlice[1] = px.alpha8();
  }

  @override
  void setn_pixel(int x, int y, int n, Color c) {
    final px = Gray8.from_color(c);
    for (var i = 0; i < n; i++) {
      set_pixel(x + i, y, px);
    }
  }

  @override
  void blend_pix(int x, int y, Color c, int cover) {
    if (cover == 0) return;
    final existing = get_pixel(x, y); // Rgba8
    final overlay = Rgba8.from_color(c);

    final alpha = multiply_u8(overlay.a, cover);
    final oldGray = existing.r;
    final newGray = overlay.r;

    final gg = lerp_u8(oldGray, newGray, alpha);
    final aa = lerp_u8(existing.a, overlay.a, alpha);

    final dataSlice = rbuf[[x, y]];
    if (dataSlice.isEmpty) return;
    dataSlice[0] = gg;
    dataSlice[1] = aa;
  }

  @override
  Future<void> to_file(String filename) async {
    await write_file(rbuf.data, width(), height(), filename);
  }

  @override
  void fill(Color color) {
    final px = Gray8.from_color(color);
    for (var yy = 0; yy < height(); yy++) {
      for (var xx = 0; xx < width(); xx++) {
        set_pixel(xx, yy, px);
      }
    }
  }
}

/// ---------------------------------------------------------------------------
/// PixfmtRgba32
/// ---------------------------------------------------------------------------
class PixfmtRgba32 extends Pixfmt<Rgba32> {
  PixfmtRgba32(RenderingBuffer rbuf) : super(rbuf);

  factory PixfmtRgba32.newPixfmt(int width, int height) {
    // 16 bytes/pixel = 4 floats de 4 bytes cada
    return PixfmtRgba32(RenderingBuffer(width, height, 16));
  }

  @override
  Rgba8 get_pixel(int x, int y) {
    final dataSlice = rbuf[[x, y]];
    if (dataSlice.isEmpty) return Rgba8.white();

    // Monta um ByteData para ler os floats (little-endian)
    final bd = ByteData.sublistView(Uint8List.fromList(dataSlice));
    final red = bd.getFloat32(0, Endian.little);
    final green = bd.getFloat32(4, Endian.little);
    final blue = bd.getFloat32(8, Endian.little);
    final alpha = bd.getFloat32(12, Endian.little);

    // Converte Rgba32 -> Rgba8
    return Rgba8(
      (red * 255).clamp(0, 255).toInt(),
      (green * 255).clamp(0, 255).toInt(),
      (blue * 255).clamp(0, 255).toInt(),
      (alpha * 255).clamp(0, 255).toInt(),
    );
  }

  @override
  void set_pixel(int x, int y, Color c) {
    final dataSlice = rbuf[[x, y]];
    if (dataSlice.isEmpty) return;

    final px = Rgba32.from_color(c); // (r, g, b, a) em floats 0..1
    // Precisamos escrever 4 floats (16 bytes)
    final bd = ByteData(16);
    bd.setFloat32(0, px.r, Endian.little);
    bd.setFloat32(4, px.g, Endian.little);
    bd.setFloat32(8, px.b, Endian.little);
    bd.setFloat32(12, px.a, Endian.little);

    final newBytes = bd.buffer.asUint8List();
    for (var i = 0; i < 16; i++) {
      dataSlice[i] = newBytes[i];
    }
  }

  @override
  void setn_pixel(int x, int y, int n, Color c) {
    for (var i = 0; i < n; i++) {
      set_pixel(x + i, y, c);
    }
  }

  @override
  void blend_pix(int x, int y, Color c, int cover) {
    // Exemplo simplificado: apenas faz set() (sem blending real).
    // Para blending de verdade, precisaria implementar com floats.
    if (cover == 0) return;
    set_pixel(x, y, c);
  }

  @override
  Future<void> to_file(String filename) async {
    // Você pode salvar como EXR, PFM etc., mas aqui só exemplo:
    await write_file(rbuf.data, width(), height(), filename);
  }

  @override
  void fill(Color color) {
    for (var yy = 0; yy < height(); yy++) {
      for (var xx = 0; xx < width(); xx++) {
        set_pixel(xx, yy, color);
      }
    }
  }
}
