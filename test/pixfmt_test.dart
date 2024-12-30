import 'package:aggr/aggr.dart';
import 'package:test/test.dart';

void main() {
  group('PixfmtRGB8(10x10)', () {
    // Vamos criar um PixfmtRGB8(10,10) a cada teste
    // usando setUp() para ficar DRY (Don't Repeat Yourself).

    late PixfmtRgb8 p;

    setUp(() {
      p = PixfmtRgb8.newPixfmt(10, 10);
    });

    test('Buffer length deve ser 300', () {
      expect(p.rbuf.data.length, equals(300), reason: '10 * 10 * 3 = 300');
    });

    test('copy_pixel(0,0, Rgb8.black()) => deve ser Rgba8.black()', () {
      // (0,0) era default = white() pois o buffer inicia fillRange=255?
      // Vamos ver a cor inicial só pra debug:
      // final oldPix = p.get_pixel([0,0]);
      // print('Antes: $oldPix');

      p.copy_pixel(0, 0, Rgb8.black());
      expect(p.get_pixel(0, 0), equals(Rgba8.black()));
    });

    test('copy_pixel(1,0, Rgb8.white()) => (1,0)=white()', () {
      final p = PixfmtRgb8.newPixfmt(10, 10);
      // estado inicial deve ser fillRange(0..300, 255) => (255,255,255)
      // mas vamos checar pixel(1,0) => supostamente white():
      // expect(p.get_pixel([1,0]), equals(Rgba8.white()), reason: 'inicial');
      // se já estiver white, o teste de "diferente" vai falhar.

      // sobrescreve (1,0) com black, só pra ver que muda:
      p.copy_pixel(1, 0, Rgb8.black());
      expect(p.get_pixel(1, 0), equals(Rgba8.black()),
          reason: '(1,0) deve ser black agora');

      // agora sobrescreve (1,0) com white
      p.copy_pixel(1, 0, Rgb8.white());
      expect(p.get_pixel(1, 0), equals(Rgba8.white()),
          reason: '(1,0) => white()');
    });
    test(
        'copy_hline(0,1,10, Rgba8(255,0,0,128)) => deve ignorar alpha => (255,0,0,255)',
        () {
      // Em PixfmtRgb8, a alpha do overlay é ignorada => vira (255,0,0,255).
      final red = Rgba8(255, 0, 0, 128);
      p.copy_hline(0, 1, 10, red);

      for (var x = 0; x < 10; x++) {
        expect(p.get_pixel(x, 1), equals(Rgba8(255, 0, 0, 255)),
            reason: 'col=$x, row=1 => Rgb8 => alpha=255');
      }
    });

    test(
        'copy_hline(0,2,10, Srgba8(128,255,0,128)) => deve gerar (55,255,0,255)',
        () {
      // Em PixfmtRgb8, ignoramos alpha ou fazemos blend simplificado => result fixo?
      final yellow = Srgba8(128, 255, 0, 128);
      p.copy_hline(0, 2, 10, yellow);

      for (var x = 0; x < 10; x++) {
        expect(p.get_pixel(x, 2), equals(Rgba8(55, 255, 0, 255)),
            reason:
                'x=$x, y=2 => (55,255,0,255) se combinou igual ao Rust test');
      }
    });

    test('clear() => tudo fica (255,255,255,255)', () {
      // Primeiro, alteramos um pixel pra não ser white()
      p.copy_pixel(0, 3, Rgb8.black());
      expect(p.get_pixel(0, 3), equals(Rgba8.black()),
          reason: 'Antes do clear, (0,3)= black');

      // Agora chamamos clear
      p.clear();
      // Checamos vários pixels
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 10; x++) {
          expect(p.get_pixel(x, y), equals(Rgba8.white()),
              reason: '(x=$x,y=$y) após clear() deve ser white()');
        }
      }
    });

    test(
        'copy_vline(1,0,10, Rgba8(255,0,0,128)) => col=1 => deve virar (255,0,0,255)',
        () {
      // Observando que em Rgb8, alpha=128 é ignorado e vira 255.
      final red2 = Rgba8(255, 0, 0, 128);

      // Antes, limpamos (opcional)
      p.clear();
      p.copy_vline(1, 0, 10, red2);
      for (var y = 0; y < 10; y++) {
        expect(p.get_pixel(1, y), equals(Rgba8(255, 0, 0, 255)),
            reason: 'col=1, row=$y => (255,0,0,255)');
      }
    });

    // E assim por diante...
  });

  group('PixfmtRgb8(1,1) smaller tests', () {
    // Este grupo testa cenários com 1x1.
    // Cada teste reinicia com "late pix" no setUp.
    late PixfmtRgb8 pix;

    setUp(() {
      pix = PixfmtRgb8.newPixfmt(1, 1);
    });

    test('Buf length = 3', () {
      expect(pix.rbuf.data.length, equals(3));
    });

    test('Copia black => confere black', () {
      pix.copy_pixel(0, 0, Rgb8.black());
      expect(pix.get_pixel(0, 0), equals(Rgba8.black()));
    });

    test('copy_or_blend_pix_with_cover => cover=255 => set => vira white', () {
      // Primeiro, (0,0)= black
      pix.copy_pixel(0, 0, Rgba8(0, 0, 0, 255));
      // Agora cover=255 => set => vira white
      pix.copy_or_blend_pix_with_cover(0, 0, Rgba8(255, 255, 255, 255), 255);
      expect(pix.get_pixel(0, 0), equals(Rgba8.white()));
    });

    // E continue com as combinações alpha,beta,cover etc.
  });
}
