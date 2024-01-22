// ignore_for_file: omit_local_variable_types

import 'dart:math';

double recursiveSine(double x, int n) {
  if (n == 0) {
    return x;
  } else {
    return x - recursiveSine(x, n - 1) * pow(x, 2) / ((2 * n) * (2 * n + 1));
  }
}

double taylorSin(double x, int n) {
  double result = 0;
  int sign = 1;
  int factorial = 1;

  for (int i = 1; i <= n; i += 2) {
    result += sign * (pow(x, i) / factorial);
    sign = -sign; // Toggle the sign for the next term
    factorial *= (i + 1) * (i + 2); // Update the factorial
  }

  return result;
}

double bhaskaraSine(double x) {
  // Ensure x is within the range of -π to π for accurate results
  x = x % (2 * pi);

  double x2 = x * x;
  double x3 = x2 * x;
  double x5 = x2 * x3;
  double x7 = x2 * x5;

  double sine = x - (x3 / 6) + (x5 / 120) - (x7 / 5040);

  return sine;
}

double bhaskaraSin(double radians) {
  // Calculate the first term of the approximation.
  double term1 = radians;

  // Calculate the second term of the approximation.
  double term2 = (radians * radians * radians) / 6.0;

  // Calculate the third term of the approximation.
  double term3 = (radians * radians * radians * radians * radians) / 120.0;

  // Calculate the sine of the angle using the approximation.
  double sine = term1 - term2 + term3;

  // Return the sine of the angle.
  return sine;
}

double padeSine(double x) {
  final double xSquared = x * x;
  final double xCubed = xSquared * x;
  final double xQuart = xCubed * x;

  final double numerator = x * (3.0 + xSquared * (-4.0 + xSquared));
  final double denominator = 3.0 + xSquared * (-2.0 + xSquared);

  return numerator / denominator;
}

double padeSineBard(double x) {
  // Coefficients of the Padé approximation to sin(x).
  const double a0 = -1.0;
  const double a1 = 1.0;
  const double a2 = -1.0 / 6.0;
  const double b0 = 1.0;
  const double b1 = 1.0 / 2.0;
  const double b2 = 1.0 / 12.0;

  // Calculate the Padé approximation.
  double numerator = a0 + a1 * x + a2 * x * x;
  double denominator = b0 + b1 * x + b2 * x * x;
  return numerator / denominator;
}
//Slope Iteration Method
double sineSlopeIteration(double theta, double resolution) {
  // Calculate the stepDelta for our angle.
  // resolution is the number of samples we calculate from 0 to 2pi radians
  final double twoPi = 6.28318530718;
  final double stepDelta = twoPi / resolution;

  // Initialize our starting values
  double angle = 0.0;
  double vcos = 1.0;
  double vsin = 0.0;

  // While we are less than our desired angle
  while (angle < theta) {
    // Calculate our step size on the y-axis for our step size on the x-axis.
    final double vcosscaled = vcos * stepDelta;
    final double vsinscaled = vsin * stepDelta;

    // Take a step on the x-axis
    angle += stepDelta;

    // Take a step on the y-axis
    vsin += vcosscaled;
    vcos -= vsinscaled;
  }

  // Return the value we calculated
  return vsin;
}



double calcPiMonteCarlo() {
  final int totalPoints = 1000000;
  int insideCircle = 0;

  final random = Random();

  for (int i = 0; i < totalPoints; i++) {
    final double x = random.nextDouble();
    final double y = random.nextDouble();
    final double distance = x * x + y * y;

    if (distance <= 1) {
      insideCircle++;
    }
  }

  final double estimatedPi = 4 * insideCircle / totalPoints;

  return estimatedPi;
}

double calcPiMonteCarloBard(int numDarts) {
  // Create a square with a side length of 1.0.
  double squareSideLength = 1.0;

  // Inscribe a circle in the square.
  double circleRadius = squareSideLength / 2.0;

  // Randomly throw darts at the square.
  int numDartsInsideCircle = 0;
  for (int i = 0; i < numDarts; i++) {
    // Generate random x and y coordinates for the dart.
    double dartX = Random().nextDouble() * squareSideLength;
    double dartY = Random().nextDouble() * squareSideLength;

    // Calculate the distance from the dart to the center of the circle.
    double distanceToCenter = sqrt(
        (dartX - circleRadius) * (dartX - circleRadius) +
            (dartY - circleRadius) * (dartY - circleRadius));

    // If the distance to the center is less than or equal to the circle radius, then the dart landed inside the circle.
    if (distanceToCenter <= circleRadius) {
      numDartsInsideCircle++;
    }
  }

  // Divide the number of darts that landed inside the circle by the total number of darts thrown.
  double piEstimate = numDartsInsideCircle / numDarts;

  // Multiply the result by 4 to estimate the value of Pi.
  piEstimate *= 4.0;

  return piEstimate;
}

double cordicSine(double angle, int iterations) {
  // Define constants for CORDIC
  final k = 0.6072529350088812561694; // 1 / ln(2)
  final cordicConstants = [
    0.7853981633974483, 0.4636476090008061, 0.24497866312686414,
    0.12435499454676144, 0.06241880999595735, 0.031239833430268277,
    0.01562372862047683, 0.007812341060101111
  ];

  // Ensure the angle is in the range [-pi/2, pi/2]
  angle %= (2 * 3.141592653589793);
  if (angle < -1.5707963267948966) angle += 3.141592653589793;
  if (angle > 1.5707963267948966) angle -= 3.141592653589793;

  double x = 1.0;
  double y = 0.0;
  double z = angle;

  for (int i = 0; i < iterations; i++) {
    double d = z >= 0 ? -1.0 : 1.0;
    double x_next = x - d * y * k * cordicConstants[i];
    double y_next = y + d * x * k * cordicConstants[i];
    double z_next = z - d * cordicConstants[i];
    x = x_next;
    y = y_next;
    z = z_next;
  }

  return y; // The sine value
}

class Cordic {
  static const int iterations = 15;
  static List<double> atanTable = List.filled(iterations, 0);

  static void initialize() {
    for (int i = 0; i < iterations; i++) {
      atanTable[i] = atan(pow(2, -i));
    }
  }

  static double sin(double angle) {
    double x = 1.2075, y = 0, z = angle;
    double xnew, ynew, znew;
    for (int j = 0; j < iterations; j++) {
      int d = (z < 0) ? -1 : 1;
      xnew = x - d * y * pow(2, -j);
      ynew = y + d * x * pow(2, -j);
      znew = z - d * atanTable[j];
      x = xnew;
      y = ynew;
      z = znew;
    }
    return y;
  }
}

void main() {
  double angleInDegrees = 30;
  double angleInRadians = angleInDegrees * (pi / 180);

  print('Seno nativo de 30 graus: ${sin(angleInRadians)}');

  print('Seno recursive: ${recursiveSine(angleInRadians, 200)}');
  print('Seno taylor: ${taylorSin(angleInRadians, 10)}');
  print('Seno bhaskara: ${bhaskaraSine(angleInRadians)}');
  print('Seno bhaskara bard: ${bhaskaraSin(angleInRadians)}');
  print('Seno pade: ${padeSine(angleInRadians)}');
  print('Seno pade bard: ${padeSineBard(angleInRadians)}');
 print('Seno Slope Iteration: ${sineSlopeIteration(angleInRadians,1024.0)}');
   print('Seno cordic: ${cordicSine(angleInRadians,8)}');
  Cordic.initialize();
  print('Seno cordic: ${Cordic.sin(angleInRadians)}');

  // print('Estimated Pi: ${calcPiMonteCarlo()}');
  // print('Estimated Pi bard: ${calcPiMonteCarloBard(1000000)}');
}
