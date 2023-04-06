// ignore_for_file: unnecessary_cast

import 'package:aggr/aggr.dart';

/// Interpolate a value between two end points using fixed point math
///
/// See agg_color_rgba.h:454 of agg version 2.4
///
u8 lerp_u8(u8 p, u8 q, u8 a) {
  var base_shift = 8;
  var base_msb = 1 << (base_shift - 1);
  var v = p > q ? 1 : 0;
// q = i32::from(q);
// p = i32::from(p);
// a = i32::from(a);
  var t0 = (q - p) * a + base_msb - v; // Signed multiplication
  var t1 = ((t0 >> base_shift) + t0) >> base_shift;
  return (p + t1) as u8;
}

/// Interpolator a value between two end points pre-calculated by alpha
///
/// p + q - (p*a)
u8 prelerp_u8(u8 p, u8 q, u8 a) {
  return p.wrapping_add(q).wrapping_sub(multiply_u8(p, a));
}

/// Multiply two u8 values using fixed point math
///
/// See agg_color_rgba.h:395
/// https://sestevenson.wordpress.com/2009/08/19/rounding-in-fixed-point-number-conversions/
/// https://stackoverflow.com/questions/10067510/fixed-point-arithmetic-in-c-programming
/// http://x86asm.net/articles/fixed-point-arithmetic-and-tricks/
/// Still not sure where the value is added and shifted multiple times
u8 multiply_u8(u8 a, u8 b) {
  var base_shift = 8;
  var base_msb = 1 << (base_shift - 1);
  //var (a,b) = (u32::from(a), u32::from(b));
  var t = a * b + base_msb;
  var tt = ((t >> base_shift) + t) >> base_shift;
  return tt as u8;
}
