import 'package:test/test.dart';
import 'package:aggr/aggr.dart';

void main() {
  group('Funções utilitárias de cores', () {
    test('cu8() converte [0..1] em [0..255]', () {
      expect(cu8(0.0), 0);
      expect(cu8(1.0), 255);

      // Verifica arredondamento
      expect(cu8(0.5), 128);
      // Verifica se passa do 1.0 (pode gerar overflow ou truncar)
      // Se seu design for clamp, você poderia checar a coerência
      // ex: expect(cu8(1.2), anything)
    });

    test('srgb_to_rgb() converte sRGB em linear (aproximado)', () {
      // 0.0 -> 0.0
      expect(srgb_to_rgb(0.0), closeTo(0.0, 1e-12));
      // 1.0 -> 1.0
      expect(srgb_to_rgb(1.0), closeTo(1.0, 1e-12));

      // Teste intermediário: sRGB 0.5 ~ 0.214
      // Valor aproximado: srgb_to_rgb(0.5) ~ 0.21404114
      final linear = srgb_to_rgb(0.5);
      expect(linear, closeTo(0.214, 1e-3));
    });

    test('rgb_to_srgb() converte linear em sRGB (aproximado)', () {
      // 0.0 -> 0.0
      expect(rgb_to_srgb(0.0), closeTo(0.0, 1e-12));
      // 1.0 -> 1.0
      expect(rgb_to_srgb(1.0), closeTo(1.0, 1e-12));

      // Teste intermediário: linear ~0.214 -> sRGB ~0.5
      final srgb = rgb_to_srgb(0.214);
      expect(srgb, closeTo(0.5, 1e-2));
    });
  });

  group('Rgb8', () {
    test('white() e black()', () {
      final w = Rgb8.white();
      expect(w.r, 255);
      expect(w.g, 255);
      expect(w.b, 255);

      final b = Rgb8.black();
      expect(b.r, 0);
      expect(b.g, 0);
      expect(b.b, 0);
    });

    test('gray()', () {
      final g = Rgb8.gray(128);
      expect(g.r, 128);
      expect(g.g, 128);
      expect(g.b, 128);
    });

    test('from_slice()', () {
      final rgb = Rgb8.from_slice([1, 2, 3]);
      expect(rgb.r, 1);
      expect(rgb.g, 2);
      expect(rgb.b, 3);
    });

    test('into_slice()', () {
      final rgb = Rgb8(10, 20, 30);
      final slice = rgb.into_slice();
      expect(slice, [10, 20, 30]);
    });

    test('from_wavelength_gamma()', () {
      // Apenas teste básico para ver se não dá erro
      // e se retorna algo entre [0..255].
      final rgb = Rgb8.from_wavelength_gamma(400.0, 1.0);
      expect(rgb.r >= 0 && rgb.r <= 255, isTrue);
      expect(rgb.g >= 0 && rgb.g <= 255, isTrue);
      expect(rgb.b >= 0 && rgb.b <= 255, isTrue);
    });

    test('Implementação Color', () {
      final rgb = Rgb8(100, 150, 200);
      expect(rgb.red(), closeTo(100 / 255.0, 1e-12));
      expect(rgb.green(), closeTo(150 / 255.0, 1e-12));
      expect(rgb.blue(), closeTo(200 / 255.0, 1e-12));
      expect(rgb.alpha(), 1.0);
      expect(rgb.alpha8(), 255);
    });
  });

  group('Rgba8', () {
    test('white() e black()', () {
      final w = Rgba8.white();
      expect(w.r, 255);
      expect(w.g, 255);
      expect(w.b, 255);
      expect(w.a, 255);

      final b = Rgba8.black();
      expect(b.r, 0);
      expect(b.g, 0);
      expect(b.b, 0);
      expect(b.a, 255);
    });

    test('from_wavelength_gamma()', () {
      final rgba = Rgba8.from_wavelength_gamma(500.0, 1.2);
      expect(rgba.r <= 255, isTrue);
      expect(rgba.g <= 255, isTrue);
      expect(rgba.b <= 255, isTrue);
      // alpha deve ser 255, pois from_trait(Rgb8)
      expect(rgba.a, 255);
    });

    test('clear()', () {
      final c = Rgba8(1, 2, 3, 4);
      c.clear();
      expect(c.r, 0);
      expect(c.g, 0);
      expect(c.b, 0);
      expect(c.a, 0);
    });

    test('premultiply()', () {
      // alpha = 255 => sem mudança
      var c = Rgba8(100, 150, 200, 255);
      var cpre = c.premultiply();
      expect(cpre.r, 100);
      expect(cpre.g, 150);
      expect(cpre.b, 200);
      expect(cpre.a, 255);

      // alpha = 0 => fica tudo 0
      c = Rgba8(100, 150, 200, 0);
      cpre = c.premultiply();
      expect(cpre.r, 0);
      expect(cpre.g, 0);
      expect(cpre.b, 0);
      expect(cpre.a, 0);

      // alpha intermediário (ex: 128)
      c = Rgba8(128, 128, 255, 128);
      cpre = c.premultiply();
      // multiply_u8(128,128) = ~64, multiply_u8(255,128) = ~128
      expect(cpre.r >= 60 && cpre.r <= 70, isTrue); // ~64
      expect(cpre.g >= 60 && cpre.g <= 70, isTrue);
      expect(cpre.b >= 120 && cpre.b <= 140, isTrue); // ~128
      expect(cpre.a, 128);
    });

    test('Implementação Color', () {
      final rgba = Rgba8(10, 20, 30, 40);
      expect(rgba.red(), 10 / 255.0);
      expect(rgba.green(), 20 / 255.0);
      expect(rgba.blue(), 30 / 255.0);
      expect(rgba.alpha(), 40 / 255.0);
      expect(rgba.is_transparent(), false);
      expect(rgba.is_opaque(), false);

      // alpha=255 => opaco
      final rgba2 = Rgba8(10, 20, 30, 255);
      expect(rgba2.is_opaque(), true);
    });
  });

  group('Gray8', () {
    test('new_with_alpha() e from_slice()', () {
      final g = Gray8.new_with_alpha(128, 100);
      expect(g.value, 128);
      expect(g.alpha8(), 100);

      final g2 = Gray8.from_slice([50, 200]);
      expect(g2.value, 50);
      expect(g2.alpha8(), 200);
    });

    test('from_trait()', () {
      final rgba = Rgba8(255, 0, 0, 128); // vermelho
      final gray = Gray8.from_color(rgba);
      // luminance_u8(255,0,0) => ~54
      expect(gray.value, closeTo(54, 2));
      expect(gray.alpha8(), 128);
    });

    test('Implementação Color', () {
      final g = Gray8(100, 128);
      expect(g.red(), closeTo(100 / 255.0, 1e-12));
      expect(g.green(), closeTo(100 / 255.0, 1e-12));
      expect(g.blue(), closeTo(100 / 255.0, 1e-12));
      expect(g.alpha8(), 128);
      expect(g.is_transparent(), false);
      expect(g.is_opaque(), false);

      // alpha=255 => opaco
      final g2 = Gray8(10, 255);
      expect(g2.is_opaque(), true);
    });
  });

  group('Rgba8pre', () {
    test('from_trait()', () {
      final c = Rgba8(100, 150, 200, 128);
      final cpre = Rgba8pre.from_color(c);
      // Como from_trait não faz a pré-multiplicação (só copia channels premultiplicados?),
      // na prática Rgba8pre pode ficar "incoerente" se não fizer o multiply,
      // mas esse é o design atual do seu código.
      expect(cpre.r, 100);
      expect(cpre.g, 150);
      expect(cpre.b, 200);
      expect(cpre.a, 128);
    });

    test('into_slice()', () {
      final cpre = Rgba8pre(10, 20, 30, 40);
      final slice = cpre.into_slice();
      expect(slice, [10, 20, 30, 40]);
    });

    test('Implementação Color', () {
      final cpre = Rgba8pre(10, 20, 30, 40);
      expect(cpre.red(), 10 / 255.0);
      expect(cpre.green(), 20 / 255.0);
      expect(cpre.blue(), 30 / 255.0);
      expect(cpre.alpha(), 40 / 255.0);
      expect(cpre.is_premultiplied(), true);
      expect(cpre.is_transparent(), false);
      expect(cpre.is_opaque(), false);

      final cpre2 = Rgba8pre(1, 2, 3, 0);
      expect(cpre2.is_transparent(), true);
    });
  });

  group('Srgba8', () {
    test('from_rgb()', () {
      // Converte Rgba8(0.5, 0.5, 0.5, 0.5) (em float) ~ (128,128,128,128) e repassa pra Srgba8
      final rgb = Rgba8(128, 128, 128, 128);
      final s = Srgba8.from_rgb(rgb);
      // Basicamente faz rgb_to_srgb em cada canal e alpha vira cu8(rgb.alpha)
      // alpha => cu8(128/255.0) ~ 128
      expect(s.a, inInclusiveRange(120, 135));
    });

    test('Implementação Color', () {
      // sRGB(50,150,250,128)
      final s = Srgba8(50, 150, 250, 128);
      // red() => srgb_to_rgb(50/255) => ~ srgb_to_rgb(0.196) ~ 0.0337
      final rLin = s.red();
      expect(rLin, inInclusiveRange(0.03, 0.04));
      // alpha() => 128/255 => ~0.5
      expect(s.alpha(), closeTo(0.5, 0.01));
      expect(s.is_premultiplied(), false);
    });
  });

  group('Rgba32', () {
    test('from_trait()', () {
      final c = Rgba8(100, 150, 200, 255);
      final c32 = Rgba32.from_color(c);
      expect(c32.r, closeTo(100 / 255.0, 1e-12));
      expect(c32.g, closeTo(150 / 255.0, 1e-12));
      expect(c32.b, closeTo(200 / 255.0, 1e-12));
      expect(c32.a, closeTo(1.0, 1e-12));
    });

    test('premultiply()', () {
      var c32 = Rgba32(0.5, 0.5, 1.0, 1.0);
      var c32p = c32.premultiply();
      // alpha = 1 => não muda
      expect(c32p.r, 0.5);
      expect(c32p.g, 0.5);
      expect(c32p.b, 1.0);

      // alpha=0 => tudo 0
      c32 = Rgba32(0.5, 0.5, 1.0, 0.0);
      c32p = c32.premultiply();
      expect(c32p.r, 0.0);
      expect(c32p.g, 0.0);
      expect(c32p.b, 0.0);

      // alpha=0.5 => multiplica
      c32 = Rgba32(0.8, 0.6, 0.4, 0.5);
      c32p = c32.premultiply();
      expect(c32p.r, closeTo(0.8 * 0.5, 1e-12));
      expect(c32p.g, closeTo(0.6 * 0.5, 1e-12));
      expect(c32p.b, closeTo(0.4 * 0.5, 1e-12));
    });
  });

  group('Funções de luminância e correlatas', () {
    test('luminance', () {
      // (1,1,1) => luminance(1,1,1) => 0.2126+0.7152+0.0722=1
      expect(luminance(1.0, 1.0, 1.0), closeTo(1.0, 1e-12));
      // (0,0,0) => luminance => 0
      expect(luminance(0.0, 0.0, 0.0), 0.0);
      // (1,0,0) => 0.2126
      expect(luminance(1.0, 0.0, 0.0), closeTo(0.2126, 1e-5));
    });

    test('luminance_u8', () {
      // (255,255,255) => ~255
      expect(luminance_u8(255, 255, 255), closeTo(255, 1));
      // (255,0,0) => ~54
      expect(luminance_u8(255, 0, 0), inInclusiveRange(50, 60));
    });

    test('lightness', () {
      // branco => max=1, min=1 => lightness=1
      expect(lightness(1.0, 1.0, 1.0), 1.0);
      // preto => 0
      expect(lightness(0.0, 0.0, 0.0), 0.0);
      // cinza => ex (0.5,0.5,0.5) => lightness=0.5
      expect(lightness(0.5, 0.5, 0.5), 0.5);
    });

    test('average', () {
      expect(average(1, 1, 1), 1.0);
      expect(average(0, 0, 0), 0.0);
      expect(average(0.5, 0.5, 0.7), closeTo(0.5666, 1e-3));
    });
  });
}
