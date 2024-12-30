// ignore_for_file: omit_local_variable_types

import 'package:aggr/aggr.dart';
import 'package:aggr/src/base.dart';

/// Representa um valor de subpixel.
class Subpixel {
  final int val;

  const Subpixel(this.val);

  /// Retorna o valor interno como inteiro.
  int value() {
    return val;
  }

  /// Construtor "from" a partir de int.
  static Subpixel from_int(int v) {
    return Subpixel(v);
  }

  /// Converte Subpixel para inteiro considerando o POLY_SUBPIXEL_SHIFT.
  static int to_int(Subpixel s) {
    // Em Rust: v.0 >> POLY_SUBPIXEL_SHIFT
    return s.val >> POLY_SUBPIXEL_SHIFT;
  }
}

/// Rasterizer para formas com contornos (outline).
///
/// O desenho é feito diretamente assim que o rasterizador recebe
/// os comandos (imediato).
class RasterizerOutline<T extends Pixel> {
  /// Renderer de primitivas associado.
  RendererPrimatives<T> ren;

  /// Ponto inicial em subpixel.
  Subpixel start_x;
  Subpixel start_y;

  /// Contador de vértices para auxiliar no fechamento do path.
  int vertices;

  /// Cria um novo RasterizerOutline com um RendererPrimatives.
  RasterizerOutline.with_primative(this.ren)
      : start_x = Subpixel.from_int(0),
        start_y = Subpixel.from_int(0),
        vertices = 0;

  /// Adiciona um caminho (path) e o renderiza imediatamente.
  void add_path(VertexSource path) {
    for (var v in path.xconvert()) {
      final cmd = v.cmd;
      final double vx = v.x;
      final double vy = v.y;

      if (cmd == PathCommand.moveTo) {
        move_to_d(vx, vy);
      } else if (cmd == PathCommand.lineTo) {
        line_to_d(vx, vy);
      } else if (cmd == PathCommand.close) {
        close();
      } else if (cmd == PathCommand.stop) {
        throw UnimplementedError('stop encountered');
      }
    }
  }

  /// Fecha o caminho atual, traçando uma linha de volta ao início, caso haja mais que dois vértices.
  void close() {
    if (vertices > 2) {
      final x = start_x;
      final y = start_y;
      line_to(x, y);
    }
    vertices = 0;
  }

  /// Move para a posição (x,y) em coordenadas double, fazendo a conversão para subpixel.
  void move_to_d(double x, double y) {
    final sx = ren.coord(x);
    final sy = ren.coord(y);
    move_to(sx, sy);
  }

  /// Desenha uma linha da posição atual até (x,y) em coordenadas double,
  /// convertendo para subpixel.
  void line_to_d(double x, double y) {
    final sx = ren.coord(x);
    final sy = ren.coord(y);
    line_to(sx, sy);
  }

  /// Move a posição atual para (x,y) em subpixels.
  void move_to(Subpixel x, Subpixel y) {
    vertices = 1;
    start_x = x;
    start_y = y;
    ren.move_to(x, y);
  }

  /// Desenha uma linha da posição atual até (x,y) em subpixels.
  void line_to(Subpixel x, Subpixel y) {
    vertices += 1;
    ren.line_to(x, y);
  }
}

/// Renderer de primitivas.
class RendererPrimatives<T extends Pixel> {
  /// Base de renderização.
  RenderingBase<T> base;

  /// Cor de preenchimento.
  Rgba8 fill_color;

  /// Cor de linha.
  Rgba8 line_color;

  /// Coordenadas atuais em subpixel.
  Subpixel x;
  Subpixel y;

  /// Cria uma instância de RendererPrimatives com uma RenderingBase.
  RendererPrimatives.with_base(this.base)
      : fill_color = Rgba8(0, 0, 0, 255),
        line_color = Rgba8(0, 0, 0, 255),
        x = Subpixel.from_int(0),
        y = Subpixel.from_int(0);

  /// Define a cor da linha.
  void line_color_func(Color line_color) {
    this.line_color = Rgba8.from_color(line_color);
  }

  /// Define a cor de preenchimento.
  void fill_color_func(Color fill_color) {
    this.fill_color = Rgba8.from_color(fill_color);
  }

  /// Converte uma coordenada double para subpixel.
  Subpixel coord(double c) {
    // Em Rust:
    // Subpixel::from( (c * POLY_SUBPIXEL_SCALE as f64).round() as i64 )
    final v = (c * POLY_SUBPIXEL_SCALE).round();
    return Subpixel.from_int(v);
  }

  /// Move a posição de desenho para (x,y).
  void move_to(Subpixel x, Subpixel y) {
    this.x = x;
    this.y = y;
  }

  /// Desenha uma linha da posição atual até (x,y).
  void line_to(Subpixel x, Subpixel y) {
    final x0 = this.x;
    final y0 = this.y;
    line(x0, y0, x, y);
    this.x = x;
    this.y = y;
  }

  /// Desenha a linha em si, usando um interpolador de Bresenham.
  void line(Subpixel x1, Subpixel y1, Subpixel x2, Subpixel y2) {
    final mask = (base.pixf as Pixel).cover_mask();
    final color = line_color;

    final li = BresehamInterpolator.new_breseham(x1, y1, x2, y2);
    if (li.len == 0) {
      return;
    }

    if (li.ver) {
      for (int i = 0; i < li.len; i++) {
        base.blend_hline(
          li.x2,
          li.y1,
          li.x2,
          color,
          mask,
        );
        li.vstep();
      }
    } else {
      for (int i = 0; i < li.len; i++) {
        base.blend_hline(
          li.x1,
          li.y2,
          li.x1,
          color,
          mask,
        );
        li.hstep();
      }
    }
  }
}
