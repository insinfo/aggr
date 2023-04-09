

//! Writing of PPM (Portable Pixmap Format) files
//!
//! See <https://en.wikipedia.org/wiki/Netpbm_format#PPM_example>
//!
//use std::path::Path;
import 'dart:io';
import 'dart:typed_data';
import 'package:aggr/aggr.dart';
import 'package:image/image.dart';

Future<Tuple3<Uint8List, int, int>> read_file(String filename) async {
  final img =  decodeImage(File(filename).readAsBytesSync());
  final w = img!.width;
  final h = img.height;
  final buf = img.getBytes();
  return Tuple3(buf, w, h);
}
/// save file to PNG
Future<void> write_file(Uint8List buf, int width, int height, String filename) async {
  final img = Image.fromBytes(width:width, height: height, bytes: buf.buffer);
  await File(filename).writeAsBytes(encodePng(img));
}

Future<bool> img_diff(String f1, String f2) async {
  final data1 = await read_file(f1);
  final data2 = await read_file(f2);

  final d1 = data1.item1;
  final w1 = data1.item2;
  final h1 = data1.item3;

  final d2 = data2.item1;
  final w2 = data2.item2;
  final h2 = data2.item3;

  if (w1 != w2 || h1 != h2) {
    return false;
  }

  if (d1.length != d2.length) {
    print('files not equal length');
    return false;
  }

  var flag = true;

  for (var i = 0; i < d1.length; i++) {
    if (d1[i] != d2[i]) {
      print(
          '$i [${(i / 3) % w1},${(i / 3) ~/ w1},${i % 3}]: ${d1[i]} ${d2[i]}');
      flag = false;
    }
  }

  return flag;
}
