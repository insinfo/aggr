import 'dart:math' as math;

typedef u8 = int;
typedef f64 = double;
typedef f32 = double;

/// [Machine epsilon] value for `f32`.
///
/// This is the difference between `1.0` and the next larger representable number.
///
/// [Machine epsilon]: https://en.wikipedia.org/wiki/Machine_epsilon

const f32 f32_EPSILON = 1.19209290e-07;

void println(String val, [dynamic a, dynamic b, dynamic c, dynamic d]) {
  var buffer = StringBuffer();
  if (a != null) {
    buffer.write(a);
  }
  if (b != null) {
    buffer.write(b);
  }
  if (c != null) {
    buffer.write(c);
  }
  if (d != null) {
    buffer.write(d);
  }
  print(buffer.toString());
}

extension IntExtensions on int {
  /// Performs addition that wraps around on overflow.
  /// Wrapping (modular) addition. Computes `self + other`, wrapping around at the boundary of  the type.
  int wrapping_add(int other) {
    return this + other;
  }

  int wrapping_sub(int other) {
    return this - other;
  }
}

extension DoubleExtensions on double {
  /// Raises a number to a floating point power.
  double powf(double other) {
    return math.pow(this, other) as double;
    //return this - other;
  }
}
