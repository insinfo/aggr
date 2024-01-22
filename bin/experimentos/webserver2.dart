import 'dart:io';
import 'dart:isolate';

//hey -n 4 -c 1 http://localhost:8080
//bombardier -c 200 -d 10s http://localhost:8080
void main(List<String> args) async {
  final concurrency = 4;

  final receivePort = ReceivePort();
  //
  SendPort? sendPort;
  receivePort.listen((message) {
    if (message is SendPort) {
      sendPort = message;
    } else if (message is int) {
      sendPort!.send(message);
    }
    //print('main receive $contador');
  });

  for (var i = 0; i < concurrency; i++) {
    await Isolate.spawn<List>(
        initServer, ['0.0.0.0', 8080, receivePort.sendPort],
        debugName: i.toString());
    print('isolate $i');
  }
}

class Contador {
  int val = 0;

  Contador();
  void inc() {
    val += 1;
  }

  @override
  String toString() {
    return val.toString();
  }
}

void initServer(List args) async {
  final id = Isolate.current.debugName;
  final mainPort = args[2] as SendPort;
  final isolatePort = ReceivePort();
  var contador = Contador();
  mainPort.send(isolatePort.sendPort);
  final server = await HttpServer.bind(args[0], args[1], shared: true);
  isolatePort.listen((message) {
    contador.inc();
    print('isolate $id receive from main | $contador');
  });
  await for (final rec in server) {
    final resp = rec.response;
    if (rec.requestedUri.path != '/favicon.ico') {
      mainPort.send(1);
    }

    resp.write(contador.val + 1);
    await resp.flush();
    await resp.close();
  }
}
