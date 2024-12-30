// ignore_for_file: omit_local_variable_types
import 'dart:math' as math;
import 'package:aggr/aggr.dart';

// Exemplo de classe utilitária, convertendo double para int escalado.
// Em Rust: RasConvInt
class RasConvInt {
  // upscale() => multiplica por POLY_SUBPIXEL_SCALE e arredonda para int
  static int upscale(double v) {
    return (v * POLY_SUBPIXEL_SCALE).round();
  }

  // Se quiser downscale, defina aqui.
  // static int downscale(int v) => v;
}

/// Winding / Filling Rule
/// (Similar ao enum FillingRule do Rust)
enum FillingRule {
  nonZero,
  evenOdd,
}

/// PathStatus (similar ao enum PathStatus em Rust)
enum PathStatus {
  initial,
  closed,
  moveTo,
  lineTo,
}

/// Implementa valor default (equivalente a impl Default for PathStatus)
extension PathStatusDefault on PathStatus {
  static PathStatus get defaultValue => PathStatus.initial;
}

/// Rasterizer Anti-Alias usando Scanline
/// (similar a RasterizerScanline do Rust)
class RasterizerScanline {
  /// Clipping Region
  final Clip clipper;

  /// Coleção de Rasterizing Cells
  final RasterizerCell outline;

  /// Status do Path
  PathStatus status;

  /// Posição (x0, y0) atual
  int x0;
  int y0;

  /// Linha (row) atual em processamento
  int scanY;

  /// Regras de preenchimento (winding)
  FillingRule fillingRule;

  /// Valores de correção de gamma
  List<int> gammaTable;

  RasterizerScanline._internal({
    required this.clipper,
    required this.outline,
    required this.status,
    required this.x0,
    required this.y0,
    required this.scanY,
    required this.fillingRule,
    required this.gammaTable,
  });

  /// Construtor "padrão" (equivalente a `new()` em Rust)
  factory RasterizerScanline() {
    return RasterizerScanline._internal(
      clipper: Clip.newClip(),
      outline: RasterizerCell.newRasterizerCell(),
      status: PathStatus.initial,
      x0: 0,
      y0: 0,
      scanY: 0,
      fillingRule: FillingRule.nonZero,
      // Em Rust: gamma = (0..256).collect(). Em Dart: List<int>.generate(...)
      gammaTable: List<int>.generate(256, (i) => i), // só um "dummy" inicial
    );
  }

  /// Reset Rasterizer
  /// - Zera RasterizerCell e PathStatus => Initial
  void reset() {
    outline.reset();
    status = PathStatus.initial;
  }

  /// Adiciona um Path
  /// - Lê vértices do VertexSource e rasteriza
  void addPath(VertexSource path) {
    // Em Rust: path.rewind(). Se precisar, chame aqui path.rewind();
    // Se outline já possui dados, faz reset
    if (outline.sorted_y.isNotEmpty) {
      reset();
    }

    // xconvert() retorna uma lista de vértices, cada qual com cmd, x, y
    final segments = path.xconvert();
    for (final seg in segments) {
      switch (seg.cmd) {
        case PathCommand.lineTo:
          lineTo(seg.x, seg.y);
          break;
        case PathCommand.moveTo:
          moveTo(seg.x, seg.y);
          break;
        case PathCommand.close:
          closePolygon();
          break;
        case PathCommand.stop:
          throw UnimplementedError('PathCommand.stop encountered');
      }
    }
  }

  /// Rewind the Scanline
  /// - Fecha o polígono, ordena as células, define scanY p/ valor minY
  /// - Retorna true se existirem células
  bool rewindScanlines() {
    closePolygon();
    outline.sort_cells();
    if (outline.total_cells() == 0) {
      return false;
    } else {
      scanY = outline.min_y;
      return true;
    }
  }

  /// Varre a Scanline
  /// - Preenche spans no scanline (ScanlineU8)
  /// - Retorna true se houver dados
  bool sweepScanline(ScanlineU8 sl) {
    while (true) {
      if (scanY < 0) {
        scanY++;
        continue;
      }
      if (scanY > outline.max_y) {
        return false;
      }

      sl.reset_spans();
      int numCells = outline.scanline_num_cells(scanY);
      final cells = outline.scanline_cells(scanY);

      int cover = 0;
      final iter = cells.iterator;

      // Consome as células
      if (iter.moveNext()) {
        var curCell = iter.current;
        while (numCells > 0) {
          int x = curCell.x;
          int area = curCell.area;
          cover += curCell.cover;
          numCells--;

          // acumula células com mesmo x
          while (numCells > 0) {
            if (!iter.moveNext()) break;
            curCell = iter.current;
            if (curCell.x != x) {
              break;
            }
            area += curCell.area;
            cover += curCell.cover;
            numCells--;
          }

          if (area != 0) {
            final alpha =
                calculateAlpha(((cover << (POLY_SUBPIXEL_SHIFT + 1)) - area));
            if (alpha > 0) {
              sl.add_cell(x, alpha);
            }
            x++;
          }

          if (numCells > 0 && curCell.x > x) {
            final alpha = calculateAlpha(cover << (POLY_SUBPIXEL_SHIFT + 1));
            if (alpha > 0) {
              sl.add_span(x, curCell.x - x, alpha);
            }
          }
        }
      }
      if (sl.num_spans() != 0) {
        // Se realmente adicionamos spans, finalize e retorne
        break;
      }
      scanY++;
    }
    sl.finalize(scanY);
    scanY++;
    return true;
  }

  /// Retorna min_x do outline
  int minX() => outline.min_x;

  /// Retorna max_x do outline
  int maxX() => outline.max_x;

  /// Cria RasterizerScanline com função gamma custom
  factory RasterizerScanline.newWithGamma(double Function(double) gfunc) {
    final ras = RasterizerScanline();
    ras.setGamma(gfunc);
    return ras;
  }

  /// Define a função de gamma
  /// Em Rust: gamma = gfunc(v/masc) * masc
  void setGamma(double Function(double) gfunc) {
    const aaShift = 8;
    final aaScale = 1 << aaShift;
    final aaMask = (aaScale - 1).toDouble();

    gammaTable = List<int>.generate(256, (i) {
      final val01 = i / aaMask; // v/aaMask => [0..1]
      final g = gfunc(val01) * aaMask;
      return g.round().clamp(0, 255);
    });
  }

  /// Define clipping box
  void clipBox(double x1, double y1, double x2, double y2) {
    clipper.clip_box(
      RasConvInt.upscale(x1),
      RasConvInt.upscale(y1),
      RasConvInt.upscale(x2),
      RasConvInt.upscale(y2),
    );
  }

  /// Move to (x,y)
  void moveTo(double x, double y) {
    x0 = RasConvInt.upscale(x);
    y0 = RasConvInt.upscale(y);
    clipper.move_to(x0, y0);
    status = PathStatus.moveTo;
  }

  /// Line to (x,y)
  void lineTo(double x, double y) {
    final xx = RasConvInt.upscale(x);
    final yy = RasConvInt.upscale(y);
    clipper.line_to(outline, xx, yy);
    status = PathStatus.lineTo;
  }

  /// Fecha polígono, ligando ao ponto inicial (x0,y0)
  void closePolygon() {
    if (status == PathStatus.lineTo) {
      clipper.line_to(outline, x0, y0);
      status = PathStatus.closed;
    }
  }

  /// Calcula alpha baseado na área (area)
  int calculateAlpha(int area) {
    const aaShift = 8;
    final aaScale = 1 << aaShift;
    final aaScale2 = aaScale * 2;
    final aaMask = aaScale - 1;
    final aaMask2 = aaScale2 - 1;

    // shift e abs
    int cover = area >> (POLY_SUBPIXEL_SHIFT * 2 + 1 - aaShift);
    cover = cover.abs();

    if (fillingRule == FillingRule.evenOdd) {
      cover *= aaMask2;
      if (cover > aaScale) {
        cover = aaScale2 - cover;
      }
    }
    cover = math.max(0, math.min(cover, aaMask));
    // Usa cover como índice na gammaTable
    return gammaTable[cover];
  }
}

/// Funções auxiliares (equivalentes a len_i64 etc.)
int lenI64(Vertex<int> a, Vertex<int> b) {
  return lenI64xy(a.x, a.y, b.x, b.y);
}

int lenI64xy(int x1, int y1, int x2, int y2) {
  final dx = x1.toDouble() - x2.toDouble();
  final dy = y1.toDouble() - y2.toDouble();
  return (dx * dx + dy * dy).sqrt().round();
}
