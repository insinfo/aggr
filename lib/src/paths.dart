// ignore_for_file: unnecessary_cast, unnecessary_this

import 'package:aggr/aggr.dart';

enum PathCommand {
  Stop,
  MoveTo,
  LineTo,
  Close,
  //Curve3,
  //Curve4,
  //CurveN,
  //Catrom,
  //UBSpline,
  //EndPoly,
}

extension PathCommandExtension on PathCommand {
  PathCommand defaultValue() {
    return PathCommand.MoveTo;
  }
}

class Vertex<T> {
  T x;
  T y;
  PathCommand cmd;

  Vertex(
    this.x,
    this.y,
    this.cmd,
  );

  factory Vertex.xy(T x, T y) {
    return Vertex(x, y, PathCommand.Stop);
  }
  factory Vertex.move_to(T x, T y) {
    return Vertex(x, y, PathCommand.MoveTo);
  }
  factory Vertex.line_to(T x, T y) {
    return Vertex(x, y, PathCommand.LineTo);
  }
  factory Vertex.close_polygon(T x, T y) {
    return Vertex(x, y, PathCommand.Close);
  }
}

/// Compute length between two points
f64 len(Vertex<f64> a, Vertex<f64> b) {
  return ((a.x - b.x).powi(2) + (a.y - b.y).powi(2)).sqrt();
}

/// Compute cross product of three points
///
/// Returns the z-value of the 2D points, positive is counter-clockwise
///   negative is clockwise (or the ordering of the basis)
///
/// Because the input are 2D, this assumes the z-value is 0
/// the value is the length and direction of the cross product in the
/// z direction, or k-hat
f64 cross(Vertex<f64> p1, Vertex<f64> p2, Vertex<f64> p) {
  return (p.x - p2.x) * (p2.y - p1.y) - (p.y - p2.y) * (p2.x - p1.x);
}

class Path {
  late List<Vertex<f64>> vertices;

  Path() {
    vertices = [];
  }
  void remove_all() {
    vertices.clear();
  }

  void move_to(f64 x, f64 y) {
    //self.vertices.push( Vertex::new(x,y, PathCommand::MoveTo) );
    vertices.add(Vertex.move_to(x, y));
  }

  void line_to(f64 x, f64 y) {
    //self.vertices.push( Vertex::new(x,y, PathCommand::LineTo) );
    vertices.add(Vertex.line_to(x, y));
  }

  void close_polygon() {
    if (vertices.isEmpty) {
      return;
    }
    var n = vertices.length;
    var last = vertices[n - 1];
    if (last.cmd == PathCommand.LineTo) {
      vertices.add(Vertex.close_polygon(last.x, last.y));
    }
  }

  void arrange_orientations(PathOrientation dir) {
    arrange_orientations2(this, dir);
  }
}

// impl VertexSource for Path {
//     fn xconvert(&self) -> Vec<Vertex<f64>> {
//         self.vertices.clone()
//     }
// }

enum PathOrientation { Clockwise, CounterClockwise }

/// Split Path into Individual Segments at MoveTo Boundaries
List<Tuple2> split(List<Vertex<f64>> path) {
  var start, end;

  var pairs = <Tuple2>[];
  for (var i = 0; i < path.length; i++) {
    var v = path[i];

    if (start == null && end == null) {
      if (v.cmd == PathCommand.MoveTo) {
        start = i;
      } else if (v.cmd == PathCommand.LineTo) {
      } else if (v.cmd == PathCommand.Close) {
      } else if (v.cmd == PathCommand.Stop) {}
    } else if (start != null && end == null) {
      if (v.cmd == PathCommand.MoveTo) {
        start = i;
      } else if (v.cmd == PathCommand.LineTo) {
        end = i;
      } else if (v.cmd == PathCommand.Close || v.cmd == PathCommand.Stop) {
        end = i;
      }
    } else if (start != null && end != null) {
      if (v.cmd == PathCommand.MoveTo) {
        pairs.add(Tuple2(start, end));
        start = i;
        end = null;
      } else if (v.cmd == PathCommand.LineTo ||
          v.cmd == PathCommand.Close ||
          v.cmd == PathCommand.Stop) {
        end = i;
      } else if (start == null && end != null) {
        throw Exception('unreachable!("oh on bad state!")');
      }
    }
  }

  // if let (Some(s), Some(e)) = (start, end) {
  //     pairs.push((s,e));
  // }
  return pairs;
}

List<Tuple2<int, int>> split2(List<Vertex<f64>> path) {
  var start, end;
  var pairs = <Tuple2<int, int>>[];
  for (var i = 0; i < path.length; i++) {
    var v = path[i];
    if (start == null && end == null) {
      switch (v.cmd) {
        case PathCommand.MoveTo:
          start = i;
          break;
        case PathCommand.LineTo:
        case PathCommand.Close:
        case PathCommand.Stop:
          break;
      }
    } else if (start != null && end == null) {
      switch (v.cmd) {
        case PathCommand.MoveTo:
          start = i;
          break;
        case PathCommand.LineTo:
          end = i;
          break;
        case PathCommand.Close:
        case PathCommand.Stop:
          end = i;
          break;
      }
    } else if (start != null && end != null) {
      switch (v.cmd) {
        case PathCommand.MoveTo:
          pairs.add(Tuple2(start, end));
          start = i;
          end = null;
          break;
        case PathCommand.LineTo:
        case PathCommand.Close:
        case PathCommand.Stop:
          end = i;
          break;
      }
    } else if (start == null && end != null) {
      throw StateError('oh on bad state!');
    }
  }
  if (start != null && end != null) {
    pairs.add(Tuple2(start, end));
  }
  return pairs;
}

void arrange_orientations2(Path path, PathOrientation dir) {
  var pairs = split(path.vertices);
  for (var pair in pairs) {
    var subvertices = path.vertices.sublist(pair.item1, pair.item2 + 1);
    var pdir = preceive_polygon_orientation(subvertices);
    if (pdir != dir) {
      invert_polygon(subvertices);
    }
  }
}

void invert_polygon(List<Vertex<f64>> v) {
  var n = v.length;
  v.reverse();
  var tmp = v[0].cmd;
  v[0].cmd = v[n - 1].cmd;
  v[n - 1].cmd = tmp;
}

PathOrientation preceive_polygon_orientation(List<Vertex<f64>> vertices) {
  var n = vertices.length;
  var p0 = vertices[0];
  var area = 0.0;
  for (var i = 0; i < vertices.length; i++) {
    var p1 = vertices[i];
    var p2 = vertices[(i + 1) % n];
    var x1, y1;
    if (p1.cmd == PathCommand.Close) {
      x1 = p0.x;
      y1 = p0.y;
    } else {
      x1 = p1.x;
      y1 = p1.y;
    }
    var x2, y2;
    if (p2.cmd == PathCommand.Close) {
      x2 = p0.x;
      y2 = p0.y;
    } else {
      x2 = p2.x;
      y2 = p2.y;
    }

    area += x1 * y2 - y1 * x2;
  }
  if (area < 0.0) {
    return PathOrientation.Clockwise;
  } else {
    return PathOrientation.CounterClockwise;
  }
}

Rectangle<f64>? bounding_rect(VertexSource path) {
  var pts = path.xconvert();
  if (pts.isEmpty) {
    return null;
  } else {
    var r = Rectangle(pts[0].x, pts[0].y, pts[0].x, pts[0].y);
    for (var p in pts) {
      r.expand(p.x, p.y);
    }
    return r;
  }
}

class Ellipse implements VertexSource {
  f64 x;
  f64 y;
  f64 rx;
  f64 ry;
  f64 scale;
  int num;
  //step: usize,
  bool cw;
  late Vec<Vertex<f64>> vertices;

  @override
  Vec<Vertex<f64>> xconvert() {
    return vertices.copy();
    //TODO verificar isso
    //  vertices.clone();
  }

  @override
  void rewind() {
    throw UnimplementedError();
  }

  /// Create a new Ellipse
  Ellipse([
    this.x = 0.0,
    this.y = 0.0,
    this.rx = 1.0,
    this.ry = 1.0,
    this.scale = 1.0,
    this.num = 4,
    this.cw = false,
  ]) {
    vertices = [];
    if (num == 0) {
      calc_num_steps();
    }
    calc();
  }
  void calc_num_steps() {
    var ra = (rx.abs() + ry.abs()) / 2.0;
    var da = (ra / (ra + 0.125 / scale)).acos() * 2.0;
    num = (2.0 * PI / da).round() as usize;
  }

  void calc() {
    vertices = [];
    for (var i = 0; i < num; i++) {
      var angle = (i as f64) / (num as f64) * 2.0 * PI;
      angle = cw ? 2.0 * PI - angle : angle;

      var x = this.x + angle.cos() * rx;
      var y = this.y + angle.sin() * ry;
      var v = i == 0 ? Vertex.move_to(x, y) : Vertex.line_to(x, y);

      vertices.push(v);
    }
    var v = vertices[0];
    vertices.push(Vertex.close_polygon(v.x, v.y));
  }
}

class RoundedRect implements VertexSource {
  late List<f64> x;
  late List<f64> y;
  late List<f64> rx;
  late List<f64> ry;
  late Vec<Vertex<f64>> vertices;

  RoundedRect(f64 x1, f64 y1, f64 x2, f64 y2, f64 r) {
    //var x1, x2, y1, y2;
    if (x1 > x2) {
      x1 = x2;
      x2 = x1;
    } else {
      x1 = x1;
      x2 = x2;
    }

    if (y1 > y2) {
      y1 = y2;
      y2 = y1;
    } else {
      y1 = y1;
      y2 = y2;
    }
    x = [x1, x2];
    y = [y1, y2];
    rx = [r, r, r, r];
    ry = [r, r, r, r];
    vertices = [];
  }

  @override
  Vec<Vertex<f64>> xconvert() {
    return vertices.copy();
    // vertices.clone();
  }

  @override
  void rewind() {
    throw UnimplementedError();
  }

  void calc() {
    var vx = [1.0, -1.0, -1.0, 1.0];
    var vy = [1.0, 1.0, -1.0, -1.0];
    var x = [this.x[0], this.x[1], this.x[1], this.x[0]];
    var y = [this.y[0], this.y[0], this.y[1], this.y[1]];
    var a = [PI, PI + PI * 0.5, 0.0, 0.5 * PI];
    var b = [PI + PI * 0.5, 0.0, PI * 0.5, PI];
    for (var i = 0; i < 4; i++) {
      var arc = Arc.init(x[i] + this.rx[i] * vx[i], y[i] + this.ry[i] * vy[i],
          this.rx[i], this.ry[i], a[i], b[i]);
      var verts = arc.xconvert();
      for (var vi in verts) {
        vi.cmd = PathCommand.LineTo;
      }
      this.vertices.extend(verts);
    }
    if (this.vertices.isNotEmpty) {
      this.vertices.first.cmd = PathCommand.MoveTo;
    }
    var first = this.vertices[0];
    this.vertices.push(Vertex.close_polygon(first.x, first.y));
  }

  void normalize_radius() {
    var dx = (this.y[1] - this.y[0]).abs();
    var dy = (this.x[1] - this.x[0]).abs();

    var k = 1.0 as f64;
    var ts = [
      dx / (this.rx[0] + this.rx[1]),
      dx / (this.rx[2] + this.rx[3]),
      dy / (this.rx[0] + this.rx[1]),
      dy / (this.rx[2] + this.rx[3])
    ];

    for (var t in ts) {
      if (t < k) {
        k = t;
      }
    }

    if (k < 1.0) {
      for (var i = 0; i < this.rx.length; i++) {
        this.rx[i] *= k;
      }
      for (var i = 0; i < this.ry.length; i++) {
        this.ry[i] *= k;
      }
    }
  }
}

class Arc implements VertexSource {
  f64 x;
  f64 y;
  f64 rx;
  f64 ry;
  f64 start;
  f64 end;
  f64 scale;
  bool ccw;
  f64 da;
  Vec<Vertex<f64>> vertices;

  @override
  Vec<Vertex<f64>> xconvert() {
    return vertices.copy();
  }

  @override
  void rewind() {
    throw UnimplementedError();
  }

  Arc(
    this.x,
    this.y,
    this.rx,
    this.ry,
    this.start,
    this.end,
    this.scale,
    this.ccw,
    this.da,
    this.vertices,
  );

  // Arc(this.x, this.y, this.rx, this.ry, this.start, this.end)
  //     : scale = 1.0,
  //       ccw = true,
  //       da = 0.0,
  //       vertices = <Vertex>[] {
  //   normalize(start, end, true);
  //   calc();
  // }

  static Arc init(f64 x, f64 y, f64 rx, f64 ry, f64 a1, f64 a2) {
    var a = Arc(x, y, rx, ry, 0.0, 0.0, 1.0, true, 0.0, <Vertex<f64>>[]);
    a.normalize(a1, a2, true);
    a.calc();
    return a;
  }

  void calc() {
    var angle = <double>[];
    for (var i = 0;; i++) {
      final a = start + da * i.toDouble();
      if (da > 0.0) {
        if (a < end) {
          angle.add(a);
        } else {
          break;
        }
      } else {
        if (a > end) {
          angle.add(a);
        } else {
          break;
        }
      }
    }
    angle.add(end);

    for (final a in angle) {
      final x = this.x + a.cos() * rx;
      final y = this.y + a.sin() * ry;
      vertices.add(Vertex.line_to(x, y));
    }

    if (vertices.isNotEmpty) {
      vertices.first.cmd = PathCommand.MoveTo;
      vertices.last.cmd = PathCommand.Close;
    }
  }

  void normalize(double a1, double a2, bool ccw) {
    final ra = (rx.abs() + ry.abs()) / 2.0;
    da = (ra / (ra + 0.125 / scale)).acos() * 2.0;

    if (ccw) {
      while (a2 < a1) {
        a2 += 2.0 * PI;
      }
    } else {
      while (a1 < a2) {
        a1 += 2.0 * PI;
      }
      da = -da;
    }

    this.ccw = ccw;
    start = a1;
    end = a2;
  }
}
