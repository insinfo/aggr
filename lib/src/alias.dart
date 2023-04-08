import 'dart:math' as math;

typedef u8 = int;
typedef i64 = int;
typedef f64 = double;
typedef f32 = double;

/// [Machine epsilon] value for `f32`.
///
/// This is the difference between `1.0` and the next larger representable number.
///
/// [Machine epsilon]: https://en.wikipedia.org/wiki/Machine_epsilon
const f32 f32_EPSILON = 1.19209290e-07;

void println(String val, [dynamic a, dynamic b, dynamic c, dynamic d]) {
  var buffer = StringBuffer();
  if (a != null) {
    buffer.write(a);
  }
  if (b != null) {
    buffer.write(b);
  }
  if (c != null) {
    buffer.write(c);
  }
  if (d != null) {
    buffer.write(d);
  }
  print(buffer.toString());
}

extension IntExtensions on int {
  /// Performs addition that wraps around on overflow.
  /// Wrapping (modular) addition. Computes `self + other`, wrapping around at the boundary of  the type.
  int wrapping_add(int other) {
    return this + other;
  }

  int wrapping_sub(int other) {
    return this - other;
  }
}

extension DoubleExtensions on double {
  /// Raises a number to a floating point power.
  double powf(double other) {
    return math.pow(this, other) as double;
    //return this - other;
  }

  double powi(double other) {
    return math.pow(this, other) as double;
  }

  double sqrt() {
    return math.sqrt(this);
  }
}

extension ListExtension on List {
  void reverse() {
    var reversed = this.reversed.toList();
    clear();
    addAll(reversed);
  }
}

class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;

  /// Creates a new tuple value with the specified items.
  const Tuple2(this.item1, this.item2);

  /// Create a new tuple value with the specified list [items].
  factory Tuple2.fromList(List items) {
    if (items.length != 2) {
      throw ArgumentError('items must have length 2');
    }

    return Tuple2<T1, T2>(items[0] as T1, items[1] as T2);
  }

  /// Returns a tuple with the first item set to the specified value.
  Tuple2<T1, T2> withItem1(T1 v) => Tuple2<T1, T2>(v, item2);

  /// Returns a tuple with the second item set to the specified value.
  Tuple2<T1, T2> withItem2(T2 v) => Tuple2<T1, T2>(item1, v);

  /// Creates a [List] containing the items of this [Tuple2].
  ///
  /// The elements are in item order. The list is variable-length
  /// if [growable] is true.
  List toList({bool growable = false}) =>
      List.from([item1, item2], growable: growable);

  @override
  String toString() => '[$item1, $item2]';

  @override
  bool operator ==(Object other) =>
      other is Tuple2 && other.item1 == item1 && other.item2 == item2;

  @override
  int get hashCode => Object.hash(item1.hashCode, item2.hashCode);
}
