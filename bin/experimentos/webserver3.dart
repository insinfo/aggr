import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:shared_map/shared_map.dart';
//run with: xargs -I % -P 8 curl "http://192.168.66.123:3161/" < <(printf '%s\n' {1..4000})

void main(List<String> args) async {
  final store1 = SharedStore('t1');
  final counter = await store1.getSharedMap<int, int>('m1');
  final counterReference = counter!.sharedReference();
  counter.put(0, 0);

  final args = ['0.0.0.0', 3161];
  final concurrency = 8;

  for (var i = 0; i < concurrency - 1; i++) {
    await Isolate.spawn(startIsolate, [i, ...args, counterReference]);
  }

  startIsolate([concurrency - 1, ...args, counterReference]);
}

void startIsolate(List args) async {
  final id = args[0] as int;
  final address = args[1] as String;
  final port = args[2] as int;
  final counterReference = args[3] as SharedMapReference;
  final server = await HttpServer.bind(address, port, shared: true);

  final counter = SharedMap<int, int>.fromSharedReference(counterReference);

  server.listen((req) {
    //log(req, id);
    handler(req, req.response, counter);
  });

  print('server $id ${server.address.address}:${server.port}');
}

void handler(
    HttpRequest req, HttpResponse res, SharedMap<int, int> counter) async {
  final path = req.uri.path;

  var count = await counter.get(0);

  switch (path) {
    case '/':
      // Un-synchronized computation:
      //var count2 = await counter.put(0, count! + 1);

      // Synchronized computation:
     await counter.update(0, _increment);
       //var count2 =
      //(count: $count -> $count2)
      res.withString('ok ');
      break;
    case '/metrics':
      res.withString('count $count');
      break;
    default:
      res.notFound();
  }
}

int _increment(int k, int? v) => (v ?? 0) + 1;

void log(HttpRequest req, int id) {
  print('$id ${req.method} ${req.uri.path}');
}

extension HttpResponseExtension on HttpResponse {
  void withJson(Object? object) {
    statusCode = 200;
    writeln(jsonEncode(object));
    close();
  }

  void withString(String str) {
    statusCode = 200;
    writeln(str);
    close();
  }

  void ok() {
    statusCode = 200;
    close();
  }

  void notFound() {
    statusCode = 404;
    close();
  }
}
