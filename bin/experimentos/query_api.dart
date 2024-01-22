import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

class FluentAPI {
  FluentAPI from(String table) {
    return this;
  }

  FluentAPI select([List<String> cols = const ['*']]) {
    return this;
  }

  FluentAPI where(String col, String operator, dynamic val) {
    return this;
  }

  FluentAPI orderBy(String col, String dir) {
    return this;
  }

  FluentAPI limit(int limit) {
    return this;
  }

  FluentAPI offset(int offset) {
    return this;
  }

  Future<List<Map<String, dynamic>>> getAll() {
    return Future.value([
      {'name': 'a'}
    ]);
  }
}

extension ListMapExtension on List<Map> {
  Future<String> toJsonAsync() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateListMapToJson, [receivePort.sendPort, this]);
    final completer = Completer<String>();
    receivePort.listen((message) {
      completer.complete(message);
      receivePort.close();
    });
    return await completer.future;
  }

  static void _isolateListMapToJson(List args) {
    SendPort sendPort = args.first;
    List<Map<String, dynamic>> map = args[1];
    final json = jsonEncode(map);
    sendPort.send(json);
  }
}

// today
void main() async {
  final json = await (await FluentAPI.new()
          .select()
          .from('table')
          .where('name', 'like', 'a')
          .limit(10)
          .getAll())
      .toJsonAsync();
  print('json $json');
}
// proposal
// void main() async {
//   final json = await FluentAPI.new()
//           .select()
//           .from('table')
//           .where('name', 'like', 'a')
//           .limit(10)
//           .getAll()
//           .await // <- allow this
//           .toJsonAsync();
//   print('json $json');
// }

