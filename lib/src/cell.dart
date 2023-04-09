// ignore_for_file: unnecessary_this

import 'package:aggr/aggr.dart';
import 'dart:math' as math;

class Cell {
  // Cell x position
  int x;
  // Cell y position
  int y;
  // Cell coverage
  int cover;
  // Cell area
  int area;

  Cell(this.x, this.y, [this.cover = 0, this.area = 0]);

  //  static Cell newCell2()  {
  //     return  Cell ( i64.max, i64.max,  0,  0 );
  //   }

  // Create a new Cell
  // Cover and Area are both 0
  factory Cell.newCell() {
    return Cell(intMaxValue, intMaxValue);
  }

  // Create new cell at position (x,y)
  factory Cell.at(int x, int y) {
    return Cell(x, y);
  }

  // Compare two cell positions
  bool equal(int x, int y) {
    return this.x - x == 0 && this.y - y == 0;
  }

  // Test if cover and area are equal to 0
  // bool is_empty() {
  //   return cover == 0 && area == 0;
  // }

  Cell clone() => Cell(x, y, cover, area);
}

class RasterizerCell {
  /// Cells
  Vec<Cell> cells;

  /// Minimum x value of current cells
  i64 min_x;

  /// Maximum x value of current cells
  i64 max_x;

  /// Minimum y value of current cells
  i64 min_y;

  /// Maximum y value of current cells
  i64 max_y;

  /// Cells sorted by y position, then x position
  Vec<Vec<Cell>> sorted_y;

  RasterizerCell(this.cells, this.min_x, this.max_x, this.min_y, this.max_y,
      this.sorted_y);

  // RasterizerCell()
  //     : cells = [],
  //       min_x = 9223372036854775807,
  //       min_y = 9223372036854775807,
  //       max_x = -9223372036854775808,
  //       max_y = -9223372036854775808,
  //       sorted_y = [];

  factory RasterizerCell.newRasterizerCell() {
    return RasterizerCell(
      [],
      intMaxValue,
      intMinValue,
      intMaxValue,
      intMinValue,
      [],
    );
  }

  void reset() {
    max_x = intMinValue;
    max_y = intMinValue;
    min_x = intMaxValue;
    min_y = intMaxValue;
    sorted_y.clear();
    cells.clear();
  }

  int total_cells() => cells.length;

  void sort_cells() {
    if (sorted_y.isNotEmpty || max_y < 0) {
      return;
    }
    sorted_y = List.generate(max_y + 1, (_) => []);
    for (final c in cells) {
      if (c.y >= 0) {
        final y = c.y;
        sorted_y[y].add(c.clone());
      }
    }
    for (var i = 0; i < sorted_y.length; i++) {
      sorted_y[i].sort((a, b) => a.x.compareTo(b.x));
    }
  }

  int scanline_num_cells(int y) => sorted_y[y].length;

  List<Cell> scanline_cells(int y) => sorted_y[y];

  bool curr_cell_not_equal(int x, int y) {
    Cell? cur = cells.last;
    return cur == null || !cur.equal(x, y);
  }

  void pop_last_cell_if_empty() {
    final n = cells.length;
    if (n == 0) {
      return;
    }
    if (cells[n - 1].area == 0 && cells[n - 1].cover == 0) {
      cells.removeLast();
    }
  }

  void set_curr_cell(int x, int y) {
    if (curr_cell_not_equal(x, y)) {
      pop_last_cell_if_empty();
      cells.add(Cell.at(x, y));
    }
  }

  void render_hline(int ey, int x1, int y1, int x2, int y2) {
    var ex1 = x1 >> POLY_SUBPIXEL_SHIFT;
    var ex2 = x2 >> POLY_SUBPIXEL_SHIFT;
    var fx1 = x1 & POLY_SUBPIXEL_MASK;
    var fx2 = x2 & POLY_SUBPIXEL_MASK;

    if (y1 == y2) {
      set_curr_cell(ex2, ey);
      return;
    }

    if (ex1 == ex2) {
      var mCurrCell = cells.last;
      mCurrCell.cover += y2 - y1;
      mCurrCell.area += (fx1 + fx2) * (y2 - y1);
      return;
    }

    var p, first, incr, dx;
    if (x2 - x1 < 0) {
      p = fx1 * (y2 - y1);
      first = 0;
      incr = -1;
      dx = x1 - x2;
    } else {
      p = (POLY_SUBPIXEL_SCALE - fx1) * (y2 - y1);
      first = POLY_SUBPIXEL_SCALE;
      incr = 1;
      dx = x2 - x1;
    }

    var delta = p ~/ dx;
    var xmod = p % dx;

    if (xmod < 0) {
      delta--;
      xmod += dx;
    }

    var mCurrCell = cells.last;
    mCurrCell.cover += delta as int;
    mCurrCell.area += ((fx1 + first) * delta) as int;

    ex1 = (ex1 + incr) as int;
    set_curr_cell(ex1, ey);
    y1 = y1 + delta;

    if (ex1 != ex2) {
      p = POLY_SUBPIXEL_SCALE * (y2 - y1 + delta);
      var lift = p ~/ dx;
      var rem = p % dx;
      if (rem < 0) {
        lift--;
        rem += dx;
      }
      xmod -= dx;

      while (ex1 != ex2) {
        delta = lift;
        xmod += rem;
        if (xmod >= 0) {
          xmod -= dx;
          delta++;
        }
        mCurrCell = cells.last;
        mCurrCell.cover += delta as int;
        mCurrCell.area += POLY_SUBPIXEL_SCALE * delta;
        y1 += delta;
        ex1 += incr as int;
        set_curr_cell(ex1, ey);
      }
    }

    delta = y2 - y1;
    mCurrCell = cells.last;
    mCurrCell.cover += delta;
    mCurrCell.area += ((fx2 + POLY_SUBPIXEL_SCALE - first) * delta) as int;
  }

  /// Draw a line from (x1,y1) to (x2,y2)
  ///
  /// Cells are added to the cells collection with cover and area values
  ///
  /// Input coordinates are at subpixel scale
  void line(i64 x1, i64 y1, i64 x2, i64 y2) {
    var dx_limit = 16384 << POLY_SUBPIXEL_SHIFT;
    var dx = x2 - x1;
    // Split long lines in half
    if (dx >= dx_limit || dx <= -dx_limit) {
      var cx = ((x1 + x2) / 2) as int;
      var cy = ((y1 + y2) / 2) as int;
      this.line(x1, y1, cx, cy);
      this.line(cx, cy, x2, y2);
    }
    var dy = y2 - y1;
    // Downshift
    var ex1 = x1 >> POLY_SUBPIXEL_SHIFT;
    var ex2 = x2 >> POLY_SUBPIXEL_SHIFT;
    var ey1 = y1 >> POLY_SUBPIXEL_SHIFT;
    var ey2 = y2 >> POLY_SUBPIXEL_SHIFT;
    var fy1 = y1 & POLY_SUBPIXEL_MASK;
    var fy2 = y2 & POLY_SUBPIXEL_MASK;

    this.min_x = math.min(ex2, math.min(ex1, this.min_x));
    this.min_y = math.min(ey2, math.min(ey1, this.min_y));
    this.max_x = math.max(ex2, math.max(ex1, this.max_x));
    this.max_y = math.max(ey2, math.max(ey1, this.max_y));

    set_curr_cell(ex1, ey1);
    // Horizontal Line
    if (ey1 == ey2) {
      render_hline(ey1, x1, fy1, x2, fy2);
      var n = this.cells.len();
      if (this.cells[n - 1].area == 0 && this.cells[n - 1].cover == 0) {
        this.cells.pop();
      }
      return;
    }

    if (dx == 0) {
      var ex = x1 >> POLY_SUBPIXEL_SHIFT;
      var two_fx = (x1 - (ex << POLY_SUBPIXEL_SHIFT)) << 1;
      var first, incr;
      if (dy < 0) {
        first = 0;
        incr = -1;
      } else {
        first = POLY_SUBPIXEL_SCALE;
        incr = 1;
      }
      ;
      //let x_from = x1;
      var delta = first - fy1;
      {
        var m_curr_cell = this.cells.last;
        m_curr_cell.cover += delta as int;
        m_curr_cell.area += two_fx * delta;
      }

      ey1 = (ey1 + incr) as i64;
      this.set_curr_cell(ex, ey1);
      delta = first + first - POLY_SUBPIXEL_SCALE;
      var area = two_fx * delta;
      while (ey1 != ey2) {
        {
          var m_curr_cell = this.cells.last;
          m_curr_cell.cover = delta;
          m_curr_cell.area = area as int;
        }
        ey1 += incr as int;
        this.set_curr_cell(ex, ey1);
      }
      delta = fy2 - POLY_SUBPIXEL_SCALE + first;
      {
        var m_curr_cell = this.cells.last;
        m_curr_cell.cover += delta as int;
        m_curr_cell.area += two_fx * delta;
      }
      return;
    }
    // Render Multiple Lines
    var p, first, incr;

    if (dy < 0) {
      p = fy1 * dx;
      first = 0;
      incr = -1;
      dy = -dy;
    } else {
      p = (POLY_SUBPIXEL_SCALE - fy1) * dx;
      first = POLY_SUBPIXEL_SCALE;
      incr = 1;
      dy = dy;
    }
    var delta = p / dy;
    var xmod = p % dy;
    if (xmod < 0) {
      delta -= 1;
      xmod += dy;
    }
    var x_from = (x1 + delta) as int;
    this.render_hline(ey1, x1, fy1, x_from, first);
    ey1 = (ey1 + incr) as int;
    this.set_curr_cell(x_from >> POLY_SUBPIXEL_SHIFT, ey1);
    if (ey1 != ey2) {
      var p = POLY_SUBPIXEL_SCALE * dx;
      var lift = p / dy;
      var rem = p % dy;
      if (rem < 0) {
        lift -= 1;
        rem += dy;
      }
      xmod -= dy;
      while (ey1 != ey2) {
        delta = lift;
        xmod += rem;
        if (xmod >= 0) {
          xmod -= dy;
          delta += 1;
        }
        var x_to = x_from + delta;
        this.render_hline(ey1, x_from, (POLY_SUBPIXEL_SCALE - first) as int,
            x_to as int, first);
        x_from = x_to;
        ey1 += incr as int;
        this.set_curr_cell(x_from >> POLY_SUBPIXEL_SHIFT, ey1);
      }
    }
    this.render_hline(
        ey1, x_from, (POLY_SUBPIXEL_SCALE - first) as int, x2, fy2);
    this.pop_last_cell_if_empty();
  }
}
