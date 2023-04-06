import 'dart:math' as math;

typedef u8 = int;
typedef f64 = double;

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
