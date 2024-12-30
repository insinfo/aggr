/// Contiguous area of data
class Span {
  /// Starting x position
  int x;

  /// Length of span
  int len;

  /// Cover values with len values
  List<int> covers;

  /// Construtor padrão equivalente ao `#[derive(Default)]` do Rust
  Span()
      : x = 0,
        len = 0,
        covers = <int>[];

  /// Construtor que recebe x, len e covers
  Span.withValues(this.x, this.len, this.covers);
}

/// Unpacked ScanlineU8
///
/// Represents a single row of an image
class ScanlineU8 {
  /// Last x value used
  ///
  /// Usado como variável de estado
  int last_x;

  /// Minimum x position
  ///
  /// Este valor pode ser removido se não for necessário
  int min_x;

  /// Collection of spans
  List<Span> spans;

  /// Current y value
  ///
  /// Variável de estado
  int y;

  /// Constante que em Rust era `const LAST_X: i64 = 0x7FFF_FFF0;`
  static const int LAST_X = 0x7FFFFFF0;

  /// Construtor equivalente a `ScanlineU8::new()`
  /// Define valores iniciais:
  ///   - `last_x = LAST_X`
  ///   - `min_x = 0`
  ///   - `y = 0`
  ///   - `spans` com capacidade (em Dart, apenas lista vazia)
  ScanlineU8()
      : last_x = LAST_X,
        min_x = 0,
        spans = <Span>[],
        y = 0;

  /// Reset values and clear spans
  /// (equivalente a `reset_spans(&mut self)`)
  void reset_spans() {
    last_x = LAST_X;
    spans.clear();
  }

  /// Reset values and clear spans, setting min value
  /// (equivalente a `reset(&mut self, min_x: i64, _max_x: i64)`)
  void reset(int min_x, int max_x) {
    last_x = LAST_X;
    this.min_x = min_x;
    spans.clear();
  }

  /// Set the current row (y) that is to be worked on
  /// (equivalente a `finalize(&mut self, y: i64)`)
  void finalize(int y) {
    this.y = y;
  }

  /// Total number of spans
  /// (equivalente a `num_spans(&self) -> usize`)
  int num_spans() {
    return spans.length;
  }

  /// Add a span starting at x, with a length and cover value
  ///
  /// Se `x == last_x + 1`, estende o span atual;
  /// caso contrário, cria um novo `Span`.
  /// (equivalente a `add_span(&mut self, x: i64, len: i64, cover: u64)`)
  void add_span(int x, int len, int cover) {
    // Ajusta x com base em `min_x`
    x = x - min_x;

    // Se x for contíguo ao último x, expandimos o span atual
    if (x == last_x + 1) {
      var cur = spans.last;
      cur.len += len;
      // adiciona 'cover' repetido 'len' vezes
      cur.covers.addAll(List<int>.filled(len, cover));
    } else {
      // cria novo span
      spans.add(
        Span.withValues(
          x + min_x,
          len,
          List<int>.filled(len, cover),
        ),
      );
    }
    last_x = x + len - 1;
  }

  /// Add a single-length span (cell) with a cover value
  ///
  /// Se `x == last_x + 1`, estende o span atual;
  /// caso contrário, cria um novo span de tamanho 1.
  /// (equivalente a `add_cell(&mut self, x: i64, cover: u64)`)
  void add_cell(int x, int cover) {
    x = x - min_x;

    if (x == last_x + 1) {
      var cur = spans.last;
      cur.len += 1;
      cur.covers.add(cover);
    } else {
      spans.add(
        Span.withValues(
          x + min_x,
          1,
          [cover],
        ),
      );
    }
    last_x = x;
  }
}
