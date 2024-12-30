// ignore_for_file: unnecessary_cast, annotate_overrides, prefer_final_fields

import 'package:aggr/aggr.dart';

/// Convert an f64 [0,1] component to a u8 [0,255] component
u8 cu8(f64 v) {
  return (v * 255.0).round() as u8;
}

/// Convert from sRGB to RGB for a single component
f64 srgb_to_rgb(f64 x) {
  if (x <= 0.04045) {
    return x / 12.92;
  } else {
    return ((x + 0.055) / 1.055).powf(2.4);
  }
}

/// Convert from RGB to sRGB for a single component
f64 rgb_to_srgb(f64 x) {
  if (x <= 0.0031308) {
    return x * 12.92;
  } else {
    return 1.055 * x.powf(1.0 / 2.4) - 0.055;
  }
}

/// Color as Red, Green, Blue, and Alpha
class Rgba8 implements Color {
  /// Red
  u8 r;

  /// Green
  u8 g;

  /// Blue
  u8 b;

  /// Alpha
  u8 a;

  Rgba8(
    this.r,
    this.g,
    this.b,
    this.a,
  );

  static Rgba8 from_color(Color c) {
    return Rgba8(c.red8(), c.green8(), c.blue8(), c.alpha8());
  }

  /// White Color (255,255,255,255)
  static Rgba8 white() {
    return Rgba8(255, 255, 255, 255);
  }

  /// Black Color (0,0,0,255)
  static Rgba8 black() {
    return Rgba8(0, 0, 0, 255);
  }

  List<u8> into_slice() {
    return [r, g, b, a];
  }

  /// Crate new color from a wavelength and gamma
  static Rgba8 from_wavelength_gamma(f64 w, f64 gamma) {
    var c = Rgb8.from_wavelength_gamma(w, gamma);
    return from_color(c);
  }

  void clear() {
    r = 0;
    g = 0;
    b = 0;
    a = 0;
  }

  Rgba8pre premultiply() {
    switch (a) {
      case 255:
        return Rgba8pre(r, g, b, a);
      case 0:
        return Rgba8pre(0, 0, 0, a);
      default:
        r = multiply_u8(r, a);
        g = multiply_u8(g, a);
        b = multiply_u8(b, a);
        return Rgba8pre(r, g, b, a);
    }
  }

  f64 red() => color_u8_to_f64(r);
  f64 green() => color_u8_to_f64(g);
  f64 blue() => color_u8_to_f64(b);
  f64 alpha() => color_u8_to_f64(a);
  u8 alpha8() => a;
  u8 red8() => r;
  u8 green8() => g;
  u8 blue8() => b;
  bool is_premultiplied() => false;

  /// Return if the color is completely transparent, alpha = 0.0
  bool is_transparent() => alpha() == 0.0;

  /// Return if the color is completely opaque, alpha = 1.0
  bool is_opaque() => alpha() >= 1.0;

  // Sobrescrita de igualdade
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rgba8 &&
        runtimeType == other.runtimeType &&
        r == other.r &&
        g == other.g &&
        b == other.b &&
        a == other.a;
  }

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'Rgba8($r, $g, $b, $a)';
}

class Gray8 implements Color {
  u8 value;
  u8 _alpha;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Gray8 &&
        runtimeType == other.runtimeType &&
        value == other.value &&
        _alpha == other._alpha;
  }

  @override
  int get hashCode => Object.hash(value, _alpha);

  @override
  String toString() => 'Gray8($value, $_alpha)';

  static Gray8 from_color(Color c) {
    var lum = luminance_u8(c.red8(), c.green8(), c.blue8());
    return Gray8.new_with_alpha(lum, c.alpha8());
  }

  /// Create a new gray scale value
  Gray8(this.value, [this._alpha = 255]);
  static Gray8 new_with_alpha(u8 value, u8 alpha) {
    return Gray8(value, alpha);
  }

  static Gray8 from_slice(List<u8> v) {
    return Gray8.new_with_alpha(v[0], v[1]);
  }

  List<u8> into_slice() {
    return [value, _alpha];
  }

  f64 red() => color_u8_to_f64(value);
  f64 green() => color_u8_to_f64(value);
  f64 blue() => color_u8_to_f64(value);
  f64 alpha() => color_u8_to_f64(_alpha);
  u8 alpha8() => _alpha;
  u8 red8() => value;
  u8 green8() => value;
  u8 blue8() => value;
  bool is_premultiplied() => false;

  /// Return if the color is completely transparent, alpha = 0.0
  bool is_transparent() => alpha() == 0.0;

  /// Return if the color is completely opaque, alpha = 1.0
  bool is_opaque() => alpha() >= 1.0;
}

u8 luminance_u8(u8 red, u8 green, u8 blue) {
  return (luminance(color_u8_to_f64(red), color_u8_to_f64(green),
              color_u8_to_f64(blue)) *
          255.0)
      .round() as u8;
}

f64 luminance(f64 red, f64 green, f64 blue) {
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

/// Lightness (max(R, G, B) + min(R, G, B)) / 2
f64 lightness(f64 red, f64 green, f64 blue) {
  var cmax = red;
  var cmin = red;
  if (green > cmax) {
    cmax = green;
  }
  if (blue > cmax) {
    cmax = blue;
  }
  if (green < cmin) {
    cmin = green;
  }
  if (blue < cmin) {
    cmin = blue;
  }

  return (cmax + cmin) / 2.0;
}

/// Average
f64 average(f64 red, f64 green, f64 blue) {
  return (red + green + blue) / 3.0;
}

/// Color as Red, Green, Blue

class Rgb8 implements Color {
  u8 r;
  u8 g;
  u8 b;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rgb8 &&
        runtimeType == other.runtimeType &&
        r == other.r &&
        g == other.g &&
        b == other.b;
  }

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'Rgb8($r, $g, $b)';

  static Rgb8 from_color(Color c) {
    return Rgb8(c.red8(), c.green8(), c.blue8());
  }

  static Rgb8 white() {
    return Rgb8(255, 255, 255);
  }

  static Rgb8 black() {
    return Rgb8(0, 0, 0);
  }

  Rgb8(this.r, this.g, this.b);

  static Rgb8 gray(u8 g) {
    return Rgb8(g, g, g);
  }

  static Rgb8 from_slice(List<u8> v) {
    return Rgb8(v[0], v[1], v[2]);
  }

  List<u8> into_slice() {
    return [r, g, b];
  }

  static Rgb8 from_wavelength_gamma(f64 w, f64 gamma) {
    f64 r, g, b;

    if (w >= 380.0 && w <= 440.0) {
      r = -1.0 * (w - 440.0) / (440.0 - 380.0);
      g = 0.0;
      b = 1.0;
    } else if (w >= 440.0 && w <= 490.0) {
      r = 0.0;
      g = (w - 440.0) / (490.0 - 440.0);
      b = 1.0;
    } else if (w >= 490.0 && w <= 510.0) {
      r = 0.0;
      g = 1.0;
      b = -1.0 * (w - 510.0) / (510.0 - 490.0);
    } else if (w >= 510.0 && w <= 580.0) {
      r = (w - 510.0) / (580.0 - 510.0);
      g = 1.0;
      b = 0.0;
    } else if (w >= 580.0 && w <= 645.0) {
      r = 1.0;
      g = -1.0 * (w - 645.0) / (645.0 - 580.0);
      b = 0.0;
    } else if (w >= 645.0 && w <= 780.0) {
      r = 1.0;
      g = 0.0;
      b = 0.0;
    } else {
      r = 0.0;
      g = 0.0;
      b = 0.0;
    }
    f64 scale;
    if (w > 700.0) {
      scale = 0.3 + 0.7 * (780.0 - w) / (780.0 - 700.0);
    } else if (w < 420.0) {
      scale = 0.3 + 0.7 * (w - 380.0) / (420.0 - 380.0);
    } else {
      scale = 1.0;
    }
    var r2 = (r * scale).powf(gamma) * 255.0;
    var g2 = (g * scale).powf(gamma) * 255.0;
    var b2 = (b * scale).powf(gamma) * 255.0;

    // Arredondar e/ou clamp
    final rr = r2.clamp(0, 255).round();
    final gg = g2.clamp(0, 255).round();
    final bb = b2.clamp(0, 255).round();
    return Rgb8(rr, gg, bb);
    //return Rgb8(r2 as u8, g2 as u8, b2 as u8);
  }

  f64 red() => color_u8_to_f64(r);
  f64 green() => color_u8_to_f64(g);
  f64 blue() => color_u8_to_f64(b);
  f64 alpha() => 1.0;
  u8 alpha8() => 255;
  u8 red8() => r;
  u8 green8() => g;
  u8 blue8() => b;
  bool is_premultiplied() => false;

  /// Return if the color is completely transparent, alpha = 0.0
  bool is_transparent() => alpha() == 0.0;

  /// Return if the color is completely opaque, alpha = 1.0
  bool is_opaque() => alpha() >= 1.0;
}

f64 color_u8_to_f64(u8 x) {
  return x / 255.0;
}

/// Color as Red, Green, Blue, and Alpha with pre-multiplied components
class Rgba8pre implements Color {
  u8 r;
  u8 g;
  u8 b;
  u8 a;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rgba8pre &&
        runtimeType == other.runtimeType &&
        r == other.r &&
        g == other.g &&
        b == other.b &&
        a == other.a;
  }

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'Rgba8pre($r, $g, $b, $a)';

  Rgba8pre(this.r, this.g, this.b, this.a);

  static Rgba8pre from_color(Color color) {
    return Rgba8pre(
        color.red8(), color.green8(), color.blue8(), color.alpha8());
  }

  List<u8> into_slice() => [r, g, b, a];

  f64 red() => color_u8_to_f64(r);
  f64 green() => color_u8_to_f64(g);
  f64 blue() => color_u8_to_f64(b);
  f64 alpha() => color_u8_to_f64(a);
  u8 alpha8() => a;
  u8 red8() => r;
  u8 green8() => g;
  u8 blue8() => b;
  bool is_premultiplied() => true;
  bool is_transparent() => a == 0;
  bool is_opaque() => alpha() >= 1.0;
}

class Srgba8 extends Color {
  /// Red
  u8 r;

  /// Green
  u8 g;

  /// Blue
  u8 b;

  /// Alpha
  u8 a;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Srgba8 &&
        runtimeType == other.runtimeType &&
        r == other.r &&
        g == other.g &&
        b == other.b &&
        a == other.a;
  }

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'Srgba8($r, $g, $b, $a)';

  static Srgba8 from_rgb(Color c) {
    var r = cu8(rgb_to_srgb(c.red()));
    var g = cu8(rgb_to_srgb(c.green()));
    var b = cu8(rgb_to_srgb(c.blue()));
    return Srgba8(r, g, b, cu8(c.alpha()));
  }

  /// Create a new Srgba8 color
  Srgba8(this.r, this.g, this.b, this.a);

  f64 red() => srgb_to_rgb(color_u8_to_f64(r));
  f64 green() => srgb_to_rgb(color_u8_to_f64(g));
  f64 blue() => srgb_to_rgb(color_u8_to_f64(b));
  f64 alpha() => color_u8_to_f64(a);
  u8 alpha8() => cu8(alpha());
  u8 red8() => cu8(red());
  u8 green8() => cu8(green());
  u8 blue8() => cu8(blue());
  bool is_premultiplied() => false;

  // /// Return if the color is completely transparent, alpha = 0.0
  // bool is_transparent() => alpha() == 0.0;

  // /// Return if the color is completely opaque, alpha = 1.0
  // bool is_opaque() => alpha() >= 1.0;
}

class Rgba32 extends Color {
  f32 r;
  f32 g;
  f32 b;
  f32 a;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rgba32 &&
        runtimeType == other.runtimeType &&
        r == other.r &&
        g == other.g &&
        b == other.b &&
        a == other.a;
  }

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'Rgba32($r, $g, $b, $a)';

  static Rgba32 from_color(Color c) {
    return Rgba32(
        c.red() as f32, c.green() as f32, c.blue() as f32, c.alpha() as f32);
  }

  Rgba32(this.r, this.g, this.b, this.a);

  Rgba32 premultiply() {
    if ((a - 1.0).abs() <= f32_EPSILON) {
      return Rgba32(r, g, b, a);
    } else if (a == 0.0) {
      return Rgba32(0.0, 0.0, 0.0, a);
    } else {
      var r2 = r * a;
      var g2 = g * a;
      var b2 = b * a;
      return Rgba32(r2, g2, b2, a);
    }
  }

  f64 red() => r;
  f64 green() => g;
  f64 blue() => b;
  f64 alpha() => a;
  u8 alpha8() => cu8(alpha());
  u8 red8() => cu8(red());
  u8 green8() => cu8(green());
  u8 blue8() => cu8(blue());
  bool is_premultiplied() => false;
}
