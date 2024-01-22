import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:native_synchronization/primitives.dart';
import 'package:native_synchronization/sendable.dart';

//hey -n 4 -c 1 http://localhost:8080
//bombardier -c 200 -d 10s http://localhost:8080
void main(List<String> args) async {
  final concurrency = 4;

  final intPointer = calloc<Int64>();
  final mutex = Mutex();
  intPointer.value = 0;

  for (var i = 0; i < concurrency; i++) {
    await Isolate.spawn<List>(
        initServer, ['0.0.0.0', 8080, intPointer.address, mutex.asSendable],
        debugName: i.toString());
    print('isolate $i');
  }

  while (true) {
    if (stdin.readLineSync() == '1') {
      print('intPointer.value ${intPointer.value}');
      exit(0);
    }
  }
}

void initServer(List args) async {
  final intPointer = Pointer<Int64>.fromAddress(args[2]);

  final mutex = (args[3] as Sendable<Mutex>).materialize();

  final server = await HttpServer.bind(args[0], args[1], shared: true);
  server.listen((r) => handle(r, r.response, intPointer, mutex));
}

void handle(HttpRequest rec, HttpResponse resp, Pointer<Int64> intPointer,
    Mutex mutex) {
  //if (rec.requestedUri.path != '/favicon.ico') {
  //final id = Isolate.current.debugName;
  //final path =rec.requestedUri.path;
  //print('path: $path | server: $id | count: ${intPointer.value} ');
  //resp.writeln( 'server: $id | count: ${intPointer.value} ');
  //resp.close();
  mutex.runLocked(() {
    intPointer.value = intPointer.value + 1;
  });
  //}

  resp.write(intPointer.value);
  resp.close();
}
