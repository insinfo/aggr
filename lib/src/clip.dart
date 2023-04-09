// ignore_for_file: unnecessary_this

import 'package:aggr/aggr.dart';

class Rectangle<T extends num> {
  /// Minimum x value
  T x1;

  /// Minimum y value
  T y1;

  /// Maximum x value
  T x2;

  /// Maximum y value
  T y2;

  Rectangle(this.x1, this.y1, this.x2, this.y2);

  /// Create a new Rectangle
  ///
  /// Values are sorted before storing
  factory Rectangle.newRectangle(T x1, T y1, T x2, T y2) {
    if (x1 > x2) {
      x1 = x2;
      x2 = x1;
    } else {
      x1 = x1;
      x2 = x2;
    }
    ;
    //let (y1, y2) =
    if (y1 > x2) {
      y1 = y2;
      y2 = y1;
    } else {
      y1 = y1;
      y2 = y2;
    }
    ;
    return Rectangle(x1, y1, x2, y2);
  }

  /// Get location of point relative to rectangle
  ///
  /// Returned is an a u8 made up of the following bits:
  /// - [INSIDE](constant.INSIDE.html)
  /// - [LEFT](constant.LEFT.html)
  /// - [RIGHT](constant.RIGHT.html)
  /// - [BOTTOM](constant.BOTTOM.html)
  /// - [TOP](constant.TOP.html)
  ///
  u8 clip_flags(T x, T y) {
    return clip_flags2(x, y, this.x1, this.y1, this.x2, this.y2);
  }

  /// Expand if the point (x,y) is outside
  void expand(T x, T y) {
    if (x < this.x1) {
      this.x1 = x;
    }
    if (x > this.x2) {
      this.x2 = x;
    }
    if (y < this.y1) {
      this.y1 = y;
    }
    if (y > this.y2) {
      this.y2 = y;
    }
  }

  /// Expand if the rectangle is outside
  void expand_rect(Rectangle<T> r) {
    expand(r.x1, r.y1);
    expand(r.x2, r.y2);
  }
  //  T x1() =>  { this.x1 }
  //  T x2() -> T { this.x2 }
  //  T y1() -> T { this.y1 }
  //  T y2() -> T { this.y2 }
}

/// Inside Region
///
/// See https://en.wikipedia.org/wiki/Liang-Barsky_algorithm
/// See https://en.wikipedia.org/wiki/Cyrus-Beck_algorithm
const INSIDE = 0;

/// Left of Region
///
/// See [Liang Barsky](https://en.wikipedia.org/wiki/Liang-Barsky_algorithm)
///
/// See [Cyrus Beck](https://en.wikipedia.org/wiki/Cyrus-Beck_algorithm)
const LEFT = 1;

/// Right of Region
///
/// See [Liang Barsky](https://en.wikipedia.org/wiki/Liang-Barsky_algorithm)
///
/// See [Cyrus Beck](https://en.wikipedia.org/wiki/Cyrus-Beck_algorithm)
const RIGHT = 2;

/// Below Region
///
/// See [Liang Barsky](https://en.wikipedia.org/wiki/Liang-Barsky_algorithm)
///
/// See [Cyrus Beck](https://en.wikipedia.org/wiki/Cyrus-Beck_algorithm)
const BOTTOM = 4;

/// Above Region
///
/// See [Liang Barsky](https://en.wikipedia.org/wiki/Liang-Barsky_algorithm)
///
/// See [Cyrus Beck](https://en.wikipedia.org/wiki/Cyrus-Beck_algorithm)
const TOP = 8;

/// Determine the loaiton of a point to a broken-down rectangle or range
///
/// Returned is an a u8 made up of the following bits:
/// - [INSIDE](constant.INSIDE.html)
/// - [LEFT](constant.LEFT.html)
/// - [RIGHT](constant.RIGHT.html)
/// - [BOTTOM](constant.BOTTOM.html)
/// - [TOP](constant.TOP.html)
///
u8 clip_flags2<T extends num>(T x, T y, T x1, T y1, T x2, T y2) {
  var code = INSIDE;
  if (x < x1) {
    code |= LEFT;
  }
  if (x > x2) {
    code |= RIGHT;
  }
  if (y < y1) {
    code |= BOTTOM;
  }
  if (y > y2) {
    code |= TOP;
  }
  return code;
}

/// Clip Region
///
/// Clipping for Rasterizers
/*
#[derive(Debug)]
 struct Clip {
    /// Current x Point
    x1: i64,
    /// Current y Point
    y1: i64,
    /// Rectangle to clip on
    clip_box: Option<Rectangle<i64>>,
    /// Current clip flag for point (x1,y1)
    clip_flag: u8,
}

fn mul_div(a: i64, b: i64, c: i64) -> i64 {
    let (a,b,c) = (a as f64, b as f64, c as f64);
    (a * b / c).round() as i64
}
impl Clip {
    /// Create new Clipping region
    new() -> Self {
        Self {x1: 0, y1: 0,
              clip_box: None,
              clip_flag: INSIDE }
    }
    /// Clip a line along the top and bottom of the regon
    fn line_clip_y(&self, ras: &mut RasterizerCell,
                   x1: i64, y1: i64,
                   x2: i64, y2: i64,
                   f1: u8, f2: u8) {
        let b = match this.clip_box {
            None => return,
            Some(ref b) => b,
        };
        let f1 = f1 & (TOP|BOTTOM);
        let f2 = f2 & (TOP|BOTTOM);
        // Fully Visible in y
        if f1 == INSIDE && f2 == INSIDE {
            ras.line(x1,y1,x2,y2);
        } else {
            // Both points above or below clip box
            if f1 == f2 {
                return;
            }
            let (mut tx1, mut ty1, mut tx2, mut ty2) = (x1,y1,x2,y2);
            if f1 == BOTTOM {
                tx1 = x1 + mul_div(b.y1-y1, x2-x1, y2-y1);
                ty1 = b.y1;
            }
            if f1 == TOP {
                tx1 = x1 + mul_div(b.y2-y1, x2-x1, y2-y1);
                ty1 = b.y2;
            }
            if f2 == BOTTOM {
                tx2 = x1 + mul_div(b.y1-y1, x2-x1, y2-y1);
                ty2 = b.y1;
            }
            if f2 == TOP {
                tx2 = x1 + mul_div(b.y2-y1, x2-x1, y2-y1);
                ty2 = b.y2;
            }
            ras.line(tx1,tx2,ty1,ty2);
        }
    }

    /// Draw a line from (x1,y1) to (x2,y2) into a RasterizerCell
    ///
    /// Final point (x2,y2) is saved internally as (x1,y1))
    (crate) fn line_to(&mut self, ras: &mut RasterizerCell, x2: i64, y2: i64) {
        if let Some(ref b) = this.clip_box {
            let f2 = b.clip_flags(x2,y2);
            // Both points above or below clip box
            let fy1 = (TOP | BOTTOM) & this.clip_flag;
            let fy2 = (TOP | BOTTOM) & f2;
            if fy1 != INSIDE && fy1 == fy2 {
                this.x1 = x2;
                this.y1 = y2;
                this.clip_flag = f2;
                return;
            }
            let (x1,y1,f1) = (this.x1, this.y1, this.clip_flag);
            match (f1 & (LEFT|RIGHT), f2 & (LEFT|RIGHT)) {
                (INSIDE,INSIDE) => this.line_clip_y(ras, x1,y1,x2,y2,f1,f2),
                (INSIDE,RIGHT) => {
                    let y3 = y1 + mul_div(b.x2-x1, y2-y1, x2-x1);
                    let f3 = b.clip_flags(b.x2, y3);
                    this.line_clip_y(ras, x1,   y1, b.x2, y3, f1, f3);
                    this.line_clip_y(ras, b.x2, y3, b.x2, y2, f3, f2);
                },
                (RIGHT,INSIDE) => {
                    let y3 = y1 + mul_div(b.x2-x1, y2-y1, x2-x1);
                    let f3 = b.clip_flags(b.x2, y3);
                    this.line_clip_y(ras, b.x2, y1, b.x2, y3, f1, f3);
                    this.line_clip_y(ras, b.x2, y3,   x2, y2, f3, f2);
                },
                (INSIDE,LEFT) => {
                    let y3 = y1 + mul_div(b.x1-x1, y2-y1, x2-x1);
                    let f3 = b.clip_flags(b.x1, y3);
                    this.line_clip_y(ras, x1,   y1, b.x1, y3, f1, f3);
                    this.line_clip_y(ras, b.x1, y3, b.x1, y2, f3, f2);
                },
                (RIGHT,LEFT) => {
                    let y3 = y1 + mul_div(b.x2-x1, y2-y1, x2-x1);
                    let y4 = y1 + mul_div(b.x1-x1, y2-y1, x2-x1);
                    let f3 = b.clip_flags(b.x2, y3);
                    let f4 = b.clip_flags(b.x1, y4);
                    this.line_clip_y(ras, b.x2, y1, b.x2, y3, f1, f3);
                    this.line_clip_y(ras, b.x2, y3, b.x1, y4, f3, f4);
                    this.line_clip_y(ras, b.x1, y4, b.x1, y2, f4, f2);
                },
                (LEFT,INSIDE) => {
                    let y3 = y1 + mul_div(b.x1-x1, y2-y1, x2-x1);
                    let f3 = b.clip_flags(b.x1, y3);
                    this.line_clip_y(ras, b.x1, y1, b.x1, y3, f1, f3);
                    this.line_clip_y(ras, b.x1, y3,   x2, y2, f3, f2);
                },
                (LEFT,RIGHT) => {
                    let y3 = y1 + mul_div(b.x1-x1, y2-y1, x2-x1);
                    let y4 = y1 + mul_div(b.x2-x1, y2-y1, x2-x1);
                    let f3 = b.clip_flags(b.x1, y3);
                    let f4 = b.clip_flags(b.x2, y4);
                    this.line_clip_y(ras, b.x1, y1, b.x1, y3, f1, f3);
                    this.line_clip_y(ras, b.x1, y3, b.x2, y4, f3, f4);
                    this.line_clip_y(ras, b.x2, y4, b.x2, y2, f4, f2);
                },
                (LEFT,LEFT)   => this.line_clip_y(ras, b.x1,y1,b.x1,y2,f1,f2),
                (RIGHT,RIGHT) => this.line_clip_y(ras, b.x2,y1,b.x2,y2,f1,f2),

                (_,_) => unreachable!("f1,f2 {:?} {:?}", f1,f2),
            }
            this.clip_flag = f2;
        } else {
            ras.line(this.x1, this.y1, x2, y2);
        }
        this.x1 = x2;
        this.y1 = y2;
    }
    /// Move to point (x2,y2)
    ///
    /// Point is saved internally as (x1,y1)
    (crate) fn move_to(&mut self, x2: i64, y2: i64) {
        this.x1 = x2;
        this.y1 = y2;
        if let Some(ref b) = this.clip_box {
            this.clip_flag = clip_flags(&x2,&y2,
                                        &b.x1,&b.y1,
                                        &b.x2,&b.y2);
        }
    }
    /// Define the clipping region
    clip_box(&mut self, x1: i64, y1: i64, x2: i64, y2: i64) {
        this.clip_box = Some( Rectangle::new(x1, y1, x2, y2) );
    }
}*/
