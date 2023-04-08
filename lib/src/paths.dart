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
