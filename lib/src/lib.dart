import 'package:aggr/aggr.dart';

const i64 POLY_SUBPIXEL_SHIFT = 8;
const i64 POLY_SUBPIXEL_SCALE = 1 << POLY_SUBPIXEL_SHIFT;
const i64 POLY_SUBPIXEL_MASK = POLY_SUBPIXEL_SCALE - 1;
const i64 POLY_MR_SUBPIXEL_SHIFT = 4;
const MAX_HALF_WIDTH = 64;

abstract class VertexSource {
    /// Rewind the vertex source (unused)
   void  rewind() { }
    /// Get values from the source
    ///
    /// This could be turned into an iterator
   List<Vertex<f64>>  xconvert();
}

/// Access Color properties and compoents
abstract class Color {
  /// Get red value [0,1] as f64
  f64 red();

  /// Get green value [0,1] as f64
  f64 green();

  /// Get blue value [0,1] as f64
  f64 blue();

  /// Get alpha value [0,1] as f64
  f64 alpha();

  /// Get red value [0,255] as u8
  u8 red8();

  /// Get green value [0,255] as u8
  u8 green8();

  /// Get blue value [0,255] as u8
  u8 blue8();

  /// Get alpha value [0,255] as u8
  u8 alpha8();

  /// Return if the color is completely transparent, alpha = 0.0
  bool is_transparent() => alpha() == 0.0;

  /// Return if the color is completely opaque, alpha = 1.0
  bool is_opaque() => alpha() >= 1.0;

  /// Return if the color has been premultiplied
  bool is_premultiplied();
}
