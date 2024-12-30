import 'package:aggr/aggr.dart';

/// blend_pix conforme no Rust
Rgba8 blend_pix(Color p, Color c, int cover) {
  // Asserts
  assert(c.alpha() >= 0.0, 'alpha < 0');
  assert(c.alpha() <= 1.0, 'alpha > 1');

  // alpha = multiply_u8(c.alpha8(), cover as u8)
  final alphaVal = multiply_u8(c.alpha8(), cover);

  final red = lerp_u8(p.red8(), c.red8(), alphaVal);
  final green = lerp_u8(p.green8(), c.green8(), alphaVal);
  final blue = lerp_u8(p.blue8(), c.blue8(), alphaVal);
  final alpha = lerp_u8(p.alpha8(), c.alpha8(), alphaVal);

  return Rgba8(red, green, blue, alpha);
}

/// Classe principal "AlphaMaskAdaptor<T>" em Dart.
class AlphaMaskAdaptor<T> {
  final Pixfmt<T> rgb;
  final Pixfmt<Gray8> alpha;

  AlphaMaskAdaptor(this.rgb, this.alpha);

  /// Construtor de conveniência (estilo `pub fn new(...)` em Rust).
  factory AlphaMaskAdaptor.newAdaptor(Pixfmt<T> rgb, Pixfmt<Gray8> alpha) {
    return AlphaMaskAdaptor(rgb, alpha);
  }

  /// blend_color_hspan: mescla uma lista de cores Rgb8 com a imagem `rgb`,
  /// usando o canal alpha armazenado em `alpha`.
  ///
  /// Em Rust:
  /// ```
  /// pub fn blend_color_hspan(&mut self, x: usize, y: usize, n: usize,
  ///                          colors: &[Rgb8], _cover: usize) { ... }
  /// ```
  void blend_color_hspan(int x, int y, int n, List<Rgb8> colors, int cover) {
    assert(n == colors.length, 'Tamanho de colors difere do n=$n');

    for (var i = 0; i < n; i++) {
      // 1) lê o pixel existente (em rgb) como Color
      final p = rgb.get_pixel(x + i, y);

      // 2) lê o pixel do canal alpha como Rgba8
      //    (Em PixfmtGray8, get_pixel retorna Rgba8(p[0], p[0], p[0], p[1]),
      //     então p[0] == canal de cinza e p[1] == alpha)
      final grayPix = alpha.get_pixel(x + i, y) as Rgba8;

      // 3) se quiser tratar o canal de cinza como "alpha" em [0..255],
      //    basta usar grayPix.r (ou .g ou .b, pois são iguais).
      final alphaVal = grayPix.r;

      // 4) mistura 'colors[i]' (Rgb8) com o background 'p', usando alphaVal.
      //    (cover poderia ser multiplicado junto, se desejado)
      final newPix = blend_pix(p, colors[i], alphaVal);

      // 5) grava de volta no pixfmt principal
      rgb.set_pixel(x + i, y, newPix);
    }
  }
}
