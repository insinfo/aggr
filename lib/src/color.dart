// ignore_for_file: unnecessary_cast

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
