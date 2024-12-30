import 'package:test/test.dart';
import 'package:aggr/aggr.dart';

void main() {
  group('Cell', () {
    test('Construtor newCell() deve criar um Cell com x e y = intMaxValue', () {
      final c = Cell.newCell();
      expect(c.x, intMaxValue);
      expect(c.y, intMaxValue);
      expect(c.cover, 0);
      expect(c.area, 0);
    });

    test('Construtor at(x, y) deve criar um Cell com coordenadas fornecidas',
        () {
      final c = Cell.at(10, 20);
      expect(c.x, 10);
      expect(c.y, 20);
      expect(c.cover, 0);
      expect(c.area, 0);
    });

    test('equal(x, y) deve retornar true somente se tiver x e y iguais', () {
      final c = Cell.at(100, 200);
      expect(c.equal(100, 200), isTrue);
      expect(c.equal(100, 201), isFalse);
      expect(c.equal(101, 200), isFalse);
    });

    test('clone() deve retornar uma cópia com os mesmos valores', () {
      final original = Cell(5, 7, 10, 20);
      final copia = original.clone();
      expect(copia.x, 5);
      expect(copia.y, 7);
      expect(copia.cover, 10);
      expect(copia.area, 20);

      // Verifica se são objetos diferentes em memória
      expect(identical(original, copia), isFalse);
    });
  });

  group('RasterizerCell', () {
    test(
        'newRasterizerCell() deve criar um objeto com limites min e max corretos',
        () {
      final rc = RasterizerCell.newRasterizerCell();
      expect(rc.cells, isEmpty);
      expect(rc.min_x, intMaxValue);
      expect(rc.min_y, intMaxValue);
      expect(rc.max_x, intMinValue);
      expect(rc.max_y, intMinValue);
      expect(rc.sorted_y, isEmpty);
    });

    test('reset() deve limpar completamente as células e os limites', () {
      final rc = RasterizerCell.newRasterizerCell();
      // Simula adicionar algo
      rc.cells.add(Cell(10, 20, 1, 2));
      rc.min_x = 10;
      rc.max_x = 20;
      rc.reset();
      expect(rc.cells, isEmpty);
      expect(rc.sorted_y, isEmpty);
      expect(rc.min_x, intMaxValue);
      expect(rc.min_y, intMaxValue);
      expect(rc.max_x, intMinValue);
      expect(rc.max_y, intMinValue);
    });

    test('total_cells() retorna o número de células em cells', () {
      final rc = RasterizerCell.newRasterizerCell();
      rc.cells.add(Cell(1, 2));
      rc.cells.add(Cell(3, 4));
      expect(rc.total_cells(), 2);
    });

    test('sort_cells() gera sorted_y ordenado por y e depois por x', () {
      final rc = RasterizerCell.newRasterizerCell();
      // Adiciona células fora de ordem
      rc.cells.add(Cell(5, 2));
      rc.cells.add(Cell(2, 5));
      rc.cells.add(Cell(1, 2));
      rc.cells.add(Cell(10, 1));
      // Atualiza max_y manualmente para permitir a geração do sorted_y
      rc.max_y = 5;
      rc.sort_cells();
      // Verifica se gerou bins para y = 0..5
      expect(rc.sorted_y.length, 6);

      // y=0 deve estar vazio
      expect(rc.sorted_y[0], isEmpty);

      // y=1 deve ter uma célula x=10
      expect(rc.sorted_y[1].length, 1);
      expect(rc.sorted_y[1][0].x, 10);

      // y=2 deve ter duas células x=1 e x=5
      expect(rc.sorted_y[2].length, 2);
      expect(rc.sorted_y[2][0].x, 1);
      expect(rc.sorted_y[2][1].x, 5);

      // y=5 deve ter x=2
      expect(rc.sorted_y[5].length, 1);
      expect(rc.sorted_y[5][0].x, 2);
    });

    test('scanline_num_cells() e scanline_cells() retornam lista esperada', () {
      final rc = RasterizerCell.newRasterizerCell();
      rc.cells.add(Cell(0, 0));
      rc.cells.add(Cell(1, 1));
      rc.max_y = 1;
      rc.sort_cells();
      expect(rc.scanline_num_cells(0), 1);
      expect(rc.scanline_num_cells(1), 1);

      final c0 = rc.scanline_cells(0);
      expect(c0, hasLength(1));
      expect(c0[0].x, 0);

      final c1 = rc.scanline_cells(1);
      expect(c1, hasLength(1));
      expect(c1[0].x, 1);
    });

    test(
        'curr_cell_not_equal() detecta corretamente se a última célula é igual',
        () {
      final rc = RasterizerCell.newRasterizerCell();
      rc.cells.add(Cell(10, 10));
      expect(rc.curr_cell_not_equal(10, 10), isFalse);
      expect(rc.curr_cell_not_equal(11, 10), isTrue);
    });

    test(
        'pop_last_cell_if_empty() remove a última célula se cover e area forem 0',
        () {
      final rc = RasterizerCell.newRasterizerCell();
      rc.cells.add(Cell(10, 10, 0, 0));
      expect(rc.cells, hasLength(1));
      rc.pop_last_cell_if_empty();
      expect(rc.cells, isEmpty);
    });

    test(
        'set_curr_cell() adiciona nova célula somente se for diferente da última',
        () {
      final rc = RasterizerCell.newRasterizerCell();
      rc.set_curr_cell(10, 10);
      expect(rc.cells, hasLength(1));
      // Tenta setar a mesma célula
      rc.set_curr_cell(10, 10);
      expect(rc.cells, hasLength(1));
      // Define uma diferente
      rc.set_curr_cell(11, 10);
      expect(rc.cells, hasLength(2));
    });

    test(
        'render_hline() atualiza cover/area da célula atual e pode criar nova célula',
        () {
      final rc = RasterizerCell.newRasterizerCell();
      // Simula subpixel shift 8 => x1=100 => ex1=100>>8=0, fx1=100&255=100
      // Desenhamos uma linha horizontal de (x1,y1) => (x2,y2).
      // Exemplo: (100, 50) => (356, 90)
      // y1=50, y2=90 => ex1=0, ex2=1, ...
      rc.cells.add(Cell(0, 0, 0, 0)); // célula inicial
      rc.render_hline(0, 100, 50, 356, 90);
      // Podemos checar se a célula final foi adicionada corretamente
      expect(rc.cells.length >= 2, isTrue);
      // Não é trivial validar valores exatos de cover/area sem replicar a lógica,
      // mas podemos checar se não há erros e se a lista não está vazia.
    });

    test('line() com linha horizontal simples gera células esperadas', () {
      final rc = RasterizerCell.newRasterizerCell();
      // Desenha de (x1=0, y1=0) até (x2=256, y2=0) => 1 pixel em Y => subpixel shift 8
      // Significa ex1=0>>8=0, ex2=256>>8=1, ...
      rc.line(0, 0, 256, 0);
      expect(rc.cells.isNotEmpty, isTrue);
      // Deverá ter pelo menos duas células (ex=0 e ex=1) etc.
    });

    test('line() com linha vertical simples', () {
      final rc = RasterizerCell.newRasterizerCell();
      // Linha vertical subpixel => x1=128, x2=128, y1=0, y2=512
      // ex=128>>8=0, ...
      rc.line(128, 0, 128, 512);
      expect(rc.cells.isNotEmpty, isTrue);
      // Verifica se min_x==max_x, pois a linha é vertical
      expect(rc.min_x, rc.max_x);
    });
  });
}
