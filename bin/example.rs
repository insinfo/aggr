fn main() {
    println!("Hello, world! {}",srgb_to_rgb(982.25));
}

/// Interpolator a value between two end points pre-calculated by alpha
///
/// p + q - (p*a)
pub fn prelerp_u8(p: u8, q: u8, a: u8) -> u8 {
    p.wrapping_add(q).wrapping_sub(multiply_u8(p,a))
}

/// Multiply two u8 values using fixed point math
///
/// See agg_color_rgba.h:395
/// https://sestevenson.wordpress.com/2009/08/19/rounding-in-fixed-point-number-conversions/
/// https://stackoverflow.com/questions/10067510/fixed-point-arithmetic-in-c-programming
/// http://x86asm.net/articles/fixed-point-arithmetic-and-tricks/
/// Still not sure where the value is added and shifted multiple times
pub fn multiply_u8(a: u8, b: u8) -> u8 {
    let base_shift = 8;
    let base_msb = 1 << (base_shift - 1);
    let (a,b) = (u32::from(a), u32::from(b));
    let t : u32  = a * b + base_msb;
    let tt : u32 = ((t >> base_shift) + t) >> base_shift;
    tt as u8
}

/// Convert an f64 [0,1] component to a u8 [0,255] component
fn cu8(v: f64) -> u8 {
    (v * 255.0).round() as u8
}

/// Convert from sRGB to RGB for a single component
fn srgb_to_rgb(x: f64) -> f64 {
    if x <= 0.04045 {
        x / 12.92
    } else {
        ((x + 0.055) / 1.055).powf(2.4)
    }
}
/// Convert from RGB to sRGB for a single component
fn rgb_to_srgb(x: f64) -> f64 {
    if x <= 0.003_130_8 {
        x * 12.92
    } else {
        1.055 * x.powf(1.0/2.4) - 0.055
    }
}
