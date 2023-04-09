import 'dart:convert';
import 'dart:math' as math;
import 'precision_native.dart' if (dart.library.html) 'precision_js.dart'
    as platform_precision;

typedef u8 = int;
typedef i64 = int;
typedef f64 = double;
typedef f32 = double;
typedef Vec<T> = List<T>;
typedef usize = int;

const double PI = math.pi;

/// [Machine epsilon] value for `f32`.
///
/// This is the difference between `1.0` and the next larger representable number.
///
/// [Machine epsilon]: https://en.wikipedia.org/wiki/Machine_epsilon
const f32 f32_EPSILON = 1.19209290e-07;

/// The smallest positive [double] value that is greater than zero.
const double epsilon = 4.94065645841247E-324;

/// Actual double precision machine epsilon, the smallest number that can be
/// subtracted from 1, yielding a results different than 1.
///
/// This is also known as unit roundoff error. According to the definition of Prof. Demmel.
/// On a standard machine this is equivalent to [doublePrecision].
final double machineEpsilon = _measureMachineEpsilon();

/// Actual double precision machine epsilon, the smallest number that can be
/// added to 1, yielding a results different than 1.
///
/// This is also known as unit roundoff error. According to the definition of Prof. Higham.
/// On a standard machine this is equivalent to [positiveDoublePrecision].
final double positiveMachineEpsilon = _measurePositiveMachineEpsilon();

/// Calculates the actual (negative) double precision machine epsilon -
/// the smallest number that can be subtracted from 1, yielding a results different than 1.
///
/// This is also known as unit roundoff error. According to the definition of Prof. Demmel.
double _measureMachineEpsilon() {
  var eps = 1.0;
  while ((1.0 - (eps / 2.0)) < 1.0) {
    eps /= 2.0;
  }
  return eps;
}

/// Calculates the actual positive double precision machine epsilon -
/// the smallest number that can be added to 1, yielding a results different than 1.
///
/// This is also known as unit roundoff error. According to the definition of Prof. Higham.
double _measurePositiveMachineEpsilon() {
  var eps = 1.0;
  while ((1.0 + (eps / 2.0)) > 1.0) {
    eps /= 2.0;
  }
  return eps;
}

/// The smallest possible value of an int within 64 bits.
const int intMinValue = platform_precision.intMinValue;

/// The biggest possible value of an int within 64 bits.
const int intMaxValue = platform_precision.intMaxValue;

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

  int get MAX => intMaxValue;
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

  double acos() {
    return math.acos(this);
  }

  double cos() {
    return math.cos(this);
  }

  double sin() {
    return math.sin(this);
  }
}

extension ListExtension<T> on List<T> {
  void reverse() {
    var reversed = this.reversed.toList();
    clear();
    addAll(reversed);
  }

  List<T> copy() => List<T>.from(this);

  List clone() => json.decode(json.encode(this));

  void push(value) {
    add(value);
  }

  void extend(Iterable<T> iterable) {
    addAll(iterable);
  }

  int len() => length;

  /// O método pop() remove o último elemento de um array e retorna aquele elemento.
  /// Removes and returns the last object in this list.
  T pop() => removeLast();
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
