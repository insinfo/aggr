import 'package:aggr/aggr.dart';

const i64 POLY_SUBPIXEL_SHIFT = 8;
const i64 POLY_SUBPIXEL_SCALE = 1 << POLY_SUBPIXEL_SHIFT;
const i64 POLY_SUBPIXEL_MASK = POLY_SUBPIXEL_SCALE - 1;
const i64 POLY_MR_SUBPIXEL_SHIFT = 4;
const MAX_HALF_WIDTH = 64;

/// Interface que representa uma fonte de vértices (equivalente a `VertexSource` em Rust).
abstract class VertexSource {
  /// Rewind the vertex source (unused)
  void rewind() {}

  /// Get values from the source
  ///
  /// This could be turned into an iterator
  ///  Retorna a lista de vértices convertidos (xconvert)
  List<Vertex<f64>> xconvert();
}

/// A interface `Color` traduz as propriedades e métodos do trait Rust.
abstract class Color {
  /// Get red value [0,1]
  double red();

  /// Get green value [0,1]
  double green();

  /// Get blue value [0,1]
  double blue();

  /// Get alpha value [0,1]
  double alpha();

  /// Get red value [0,255]
  int red8();

  /// Get green value [0,255]
  int green8();

  /// Get blue value [0,255]
  int blue8();

  /// Get alpha value [0,255]
  int alpha8();

  /// Return if the color is completely transparent (alpha = 0.0)
  bool is_transparent() => alpha() == 0.0;

  /// Return if the color is completely opaque (alpha = 1.0)
  bool is_opaque() => alpha() >= 1.0;

  /// Return if the color has been premultiplied
  bool is_premultiplied();
}

/// Interface `Render` (equivalente ao trait Rust).
/// Renderiza *scanlines* em algum alvo, ajusta cor, etc.
abstract class Render {
  /// Render a single scanline ou similar para a imagem
  void render(RenderData data);

  /// Seta a cor do renderer
  void color(Color c);

  /// Preparação para o Render, caso seja necessário
  void prepare() {}
}

// abstract class Source<C> {
//   C get_pixel(int x,int y);
// }

/// Interface para operação de *pixel buffer* (equivalente ao `Pixel` em Rust),
/// fornecendo métodos de manipulação e *blending* de pixels.
/// implements Source<Color>
abstract class Pixel {
  /// Retorna a *mask* de cobertura.
  int cover_mask();

  Color get_pixel(int x,int y);

  /// Bytes por pixel (bits per pixel).
  int bpp();

  /// Retorna a lista de bytes brutos (só leitura) desse buffer.
  List<int> as_bytes();

  /// Salva o conteúdo em arquivo (p. ex. PNG, BMP etc).
  Future<void> to_file(String filename);

  /// Largura do buffer em pixels.
  int width();

  /// Altura do buffer em pixels.
  int height();

  /// Ajusta cor `c` diretamente no pixel (x, y).
  void set_pixel(int x, int y, Color c);

  /// Ajusta `n` pixels, a partir de (x, y), usando a cor `c`.
  void setn_pixel(int x, int y, int n, Color c);

  /// Faz blending do pixel (x, y) com a cor `c`, usando cobertura `cover`.
  void blend_pix(int x, int y, Color c, int cover);

  /// Preenche todo o buffer com a cor `color`.
  void fill(Color color);

  /// Copia ou faz blend de um único pixel.
  /// - Se `color.is_transparent()`, nada é feito.
  /// - Se `color.is_opaque()`, copia diretamente (set_pixel).
  /// - Caso contrário, faz blend com cover = 255.
  void copy_or_blend_pix(int x, int y, Color color) {
    if (!color.is_transparent()) {
      if (color.is_opaque()) {
        set_pixel(x, y, color);
      } else {
        // 255 é o máximo de cobertura (cover)
        blend_pix(x, y, color, 255);
      }
    }
  }

  /// Copia ou faz blend com *cover* específico.
  /// - Se `color.is_opaque()` e `cover == cover_mask()`, copia direto.
  /// - Caso contrário, faz blend com a cobertura indicada.
  void copy_or_blend_pix_with_cover(int x, int y, Color color, int cover) {
    if (!color.is_transparent()) {
      if (color.is_opaque() && cover == cover_mask()) {
        set_pixel(x, y, color);
      } else {
        blend_pix(x, y, color, cover);
      }
    }
  }

  /// Copia ou faz blend de uma linha horizontal de tamanho `len`.
  void blend_hline(int x, int y, int len, Color color, int cover) {
    if (color.is_transparent()) {
      return;
    }
    if (color.is_opaque() && cover == cover_mask()) {
      setn_pixel(x, y, len, color);
    } else {
      for (int i = 0; i < len; i++) {
        blend_pix(x + i, y, color, cover);
      }
    }
  }

  /// Mescla cor sólida (única) numa faixa horizontal, usando uma lista de coberturas.
  void blend_solid_hspan(int x, int y, int len, Color color, List<int> covers) {
    assert(len == covers.length);
    for (int i = 0; i < len; i++) {
      blend_hline(x + i, y, 1, color, covers[i]);
    }
  }

  /// Copia ou faz blend de uma linha vertical de tamanho `len`.
  void blend_vline(int x, int y, int len, Color color, int cover) {
    if (color.is_transparent()) {
      return;
    }
    if (color.is_opaque() && cover == cover_mask()) {
      for (int i = 0; i < len; i++) {
        set_pixel(x, y + i, color);
      }
    } else {
      for (int i = 0; i < len; i++) {
        blend_pix(x, y + i, color, cover);
      }
    }
  }

  /// Mescla cor sólida (única) numa faixa vertical, usando uma lista de coberturas.
  void blend_solid_vspan(int x, int y, int len, Color color, List<int> covers) {
    assert(len == covers.length);
    for (int i = 0; i < len; i++) {
      blend_vline(x, y + i, 1, color, covers[i]);
    }
  }

  /// Mescla várias cores (array `colors`) numa faixa horizontal, com
  ///   *covers* específicos ou cobertura única `cover`.
  /// Se `covers` não estiver vazio, ele tem precedência sobre `cover`.
  void blend_color_hspan(
    int x,
    int y,
    int len,
    List<Color> colors,
    List<int> covers,
    int cover,
  ) {
    assert(len == colors.length);
    if (covers.isNotEmpty) {
      assert(colors.length == covers.length);
      for (int i = 0; i < len; i++) {
        copy_or_blend_pix_with_cover(x + i, y, colors[i], covers[i]);
      }
    } else if (cover == 255) {
      // cover == 255 => mescla normal sem covers
      for (int i = 0; i < len; i++) {
        copy_or_blend_pix(x + i, y, colors[i]);
      }
    } else {
      for (int i = 0; i < len; i++) {
        copy_or_blend_pix_with_cover(x + i, y, colors[i], cover);
      }
    }
  }

  /// Mescla várias cores (array `colors`) numa faixa vertical, com
  ///   *covers* específicos ou cobertura única `cover`.
  void blend_color_vspan(
    int x,
    int y,
    int len,
    List<Color> colors,
    List<int> covers,
    int cover,
  ) {
    assert(len == colors.length);
    if (covers.isNotEmpty) {
      assert(colors.length == covers.length);
      for (int i = 0; i < len; i++) {
        copy_or_blend_pix_with_cover(x, y + i, colors[i], covers[i]);
      }
    } else if (cover == 255) {
      for (int i = 0; i < len; i++) {
        copy_or_blend_pix(x, y + i, colors[i]);
      }
    } else {
      for (int i = 0; i < len; i++) {
        copy_or_blend_pix_with_cover(x, y + i, colors[i], cover);
      }
    }
  }
}

/// `LineInterp` (equivalente ao trait Rust).
/// Fornece métodos de interpolação para desenhar linhas (Bresenham-like).
abstract class LineInterp {
  /// Inicializa a interpolação
  void init();

  /// Faz um passo horizontal
  void step_hor();

  /// Faz um passo vertical
  void step_ver();
}

/// `RenderOutline` (equivalente ao trait Rust).
/// É responsável por cobrir (cover) e desenhar spans horizontais/verticais sólidos.
abstract class RenderOutline {
  /// Retorna a cobertura baseada em `d`.
  int cover(int d);

  /// Desenha (blenda) uma faixa horizontal sólida.
  void blend_solid_hspan(int x, int y, int len, List<int> covers);

  /// Desenha (blenda) uma faixa vertical sólida.
  void blend_solid_vspan(int x, int y, int len, List<int> covers);
}

/// `DrawOutline` (equivalente ao trait Rust).
/// Fornece operações de desenho de *outline* (linhas, joins etc).
abstract class DrawOutline {
  /// Seta a cor atual
  void color(Color c);

  /// Verifica se somente *joins* "acurados" (accurate) devem ser usados
  bool accurate_join_only();

  /// Desenha linha 0
  void line0(LineParameters lp);

  /// Desenha linha 1
  void line1(LineParameters lp, int sx, int sy);

  /// Desenha linha 2
  void line2(LineParameters lp, int ex, int ey);

  /// Desenha linha 3
  void line3(LineParameters lp, int sx, int sy, int ex, int ey);

  /// Semicírculo (semidot), usado internamente
  void semidot(
    bool Function(int) cmp,
    int xc1,
    int yc1,
    int xc2,
    int yc2,
  );

  /// Desenho de fatia de círculo (pie)
  void pie(int xc, int y, int x1, int y1, int x2, int y2);
}

/// `DistanceInterpolator` (equivalente ao trait Rust).
/// Fornece métodos para cálculo de distância incremental (usado para espessura de linha, antialias etc).
abstract class DistanceInterpolator {
  /// Retorna a distância atual
  int dist();

  /// Incrementa X, com base em dy
  void inc_x(int dy);

  /// Incrementa Y, com base em dx
  void inc_y(int dx);

  /// Decrementa X, com base em dy
  void dec_x(int dy);

  /// Decrementa Y, com base em dx
  void dec_y(int dx);
}
