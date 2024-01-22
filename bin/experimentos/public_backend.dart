// import 'dart:async';
// import 'dart:convert';

// import 'dart:isolate';
// import 'package:eloquent/eloquent.dart';

// //import 'package:shelf_plus/shelf_plus.dart';
// import 'package:shelf/shelf.dart';
// import 'package:shelf_router/shelf_router.dart';
// import 'package:shelf/shelf_io.dart' as io;

// import 'package:stack_trace/stack_trace.dart';
// import 'package:new_sali_backend/src/db/db_layer.dart';
// import 'package:new_sali_backend/src/modules/protocolo/repositories/processo_repository.dart';
// import 'package:new_sali_core/src/utils/core_utils.dart';
// import 'package:new_sali_core/src/models/status_message.dart';

// import 'package:prometheus_client/prometheus_client.dart';
// import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;
// import 'package:prometheus_client_shelf/shelf_metrics.dart' as shelf_metrics;
// import 'package:prometheus_client/format.dart' as format;
// import 'package:args/args.dart' show ArgParser;
// import '../lib/src/shared/dependencies/shelf_cors_headers_base/shelf_cors_headers_base.dart';
// import '../lib/src/shared/dependencies/stream_isolate/stream_isolate.dart';
// // to compile
// // dart compile exe -o public_backend.exe .\bin\public_backend.dart
// // to test
// // xargs -I % -P 8 curl "http:/192.168.66.123:3161/api/v1/protocolo/processos/public/site/2023/10" < <(printf '%s\n' {1..400})

// const defaultHeaders = {'Content-Type': 'application/json;charset=utf-8'};

// Response responseError(String message,
//     {dynamic exception, dynamic stackTrace, int statusCode = 400}) {
//   final v = jsonEncode({
//     'is_error': true,
//     'status_code': statusCode,
//     'message': message,
//     'exception': exception?.toString(),
//     'stackTrace': stackTrace?.toString()
//   });
//   return Response(statusCode, body: v, headers: defaultHeaders);
// }

// final basePath = '/api/v1';
// final streamIsolates = <Map<int, BidirectionalStreamIsolate>>[];
// void main(List<String> args) async {
//   final parser = new ArgParser()
//     ..addOption('address', abbr: 'a', defaultsTo: '0.0.0.0')
//     ..addOption('port', abbr: 'p', defaultsTo: '3161')
//     ..addOption('isolates', abbr: 'i', defaultsTo: '3');

//   final argsParsed = parser.parse(args);

//   final arguments = [argsParsed['address'], int.parse(argsParsed['port'])];

//   final numberOfIsolates = int.parse(argsParsed['isolates']);
//   for (var i = 0; i < numberOfIsolates - 1; i++) {
//     final streamIsolate = await StreamIsolate.spawnBidirectional(isolateMain,
//         debugName: i.toString(), argument: [i, ...arguments]);
//     streamIsolates.add({i: streamIsolate});
//     streamIsolate.stream.listen((event) => receiveAndPass(event, i));
//   }
// }

// /// receive msg from isolate and send to all isolates
// void receiveAndPass(event, int idx) {
//   streamIsolates.forEach((item) {
//     item.values.first.send(event);
//   });
// }

// Stream isolateMain(Stream inc, dynamic args) {
//   final arguments = args as List;
//   int id = arguments[0];
//   String address = arguments[1];
//   int port = arguments[2];

//   final streamController = StreamController.broadcast();

//   final reg = CollectorRegistry(); //CollectorRegistry.defaultRegistry;
//   // Register default runtime metrics
//   runtime_metrics.register(reg);
//   // Register http requests total
//   final http_requests_total = Counter(
//       name: 'http_requests_total', help: 'Total number of http api requests');
//   http_requests_total.register(reg);
//   // listen msg from main
//   inc.listen((msg) {
//     http_requests_total.inc();
//   });

//   _startServer([id, streamController, reg, address, port]);
//   return streamController.stream;
// }

// void _startServer(List args) async {
//   //final id = args[0] as int;
//   final streamController = args[1] as StreamController;
//   final reg = args[2] as CollectorRegistry;
//   String address = args[3];
//   int port = args[4];

//   final app = Router();
//   routes(app, reg);

//   final handler = Pipeline()
//       .addMiddleware(corsHeaders())
//       //http_request_duration_seconds metrics
//       //.addMiddleware(shelf_metrics.register(reg))
//       .addMiddleware((innerHandler) {
//         return (request) async {
//           // Every time http_request is called, increase the counter by one
//           final resp = await innerHandler(request);
//           if (!request.url.path.contains('metrics')) {
//             //send msg to main
//             streamController.add('+1');
//           }
//           return resp;
//         };
//       })
//       .addMiddleware(logRequestsCustom())
//       .addHandler(app);

//   final server = await io.serve(handler, address, port, shared: true);
//   server.defaultResponseHeaders.remove('X-Frame-Options', 'SAMEORIGIN');

//   print('Serving at http://${server.address.host}:${server.port}');
// }

// void routes(Router app, CollectorRegistry reg) {
//   // Register a handler to expose the metrics in the Prometheus text format
//   app.get('/metrics', (Request request) async {
//     final buffer = StringBuffer();
//     final metrics = await reg.collectMetricFamilySamples();
//     format.write004(buffer, metrics);
//     return Response.ok(
//       buffer.toString(),
//       headers: {'Content-Type': format.contentType},
//     );
//   });

//   app.get('$basePath/protocolo/processos/public/site/<ano>/<codigo>',
//       (Request request, String ano, String codigo) async {
//     //final key = request.headers['Authorization'];
//     Connection? conn;
//     try {
//       final codProcesso = int.tryParse(codigo);
//       if (codProcesso == null) {
//         return responseError('codProcesso invalido');
//       }
//       final anoExercicio = ano;
//       conn = await DBLayer().connect();
//       final procRepo = ProcessoRepository(conn);
//       final proc =
//           await procRepo.getProcessoByCodigoPublic(codProcesso, anoExercicio);
//       await conn.disconnect();
//       return Response.ok(
//         jsonEncode(proc, toEncodable: SaliCoreUtils.customJsonEncode),
//         headers: defaultHeaders,
//       );
//     } catch (e, s) {
//       await conn?.disconnect();
//       print('public_backend@getProcessoByCodigoPublic $e $s');
//       return responseError(StatusMessage.ERROR_GENERIC);
//     }
//   });
// }

// Middleware logRequestsCustom(
//         {void Function(String message, bool isError)? logger}) =>
//     (innerHandler) {
//       final theLogger = logger ?? _defaultLogger;
//       return (request) {
//         var startTime = DateTime.now();
//         var watch = Stopwatch()..start();
//         return Future.sync(() => innerHandler(request)).then((response) {
//           var msg = _message(startTime, response.statusCode,
//               request.requestedUri, request.method, watch.elapsed);
//           theLogger(msg, false);
//           return response;
//         }, onError: (Object error, StackTrace stackTrace) {
//           if (error is HijackException) throw error;
//           var msg = _errorMessage(startTime, request.requestedUri,
//               request.method, watch.elapsed, error, stackTrace);
//           theLogger(msg, true);
//           // ignore: only_throw_errors
//           throw error;
//         });
//       };
//     };

// String _formatQuery(String query) {
//   return query == '' ? '' : '?$query';
// }

// String _message(DateTime requestTime, int statusCode, Uri requestedUri,
//     String method, Duration elapsedTime) {
//   return '${requestTime.toIso8601String()} '
//       '${elapsedTime.toString().padLeft(15)} '
//       '${method.padRight(7)} [$statusCode] ' // 7 - longest standard HTTP method
//       '${requestedUri.path}${_formatQuery(requestedUri.query)}'
//       '  isolate: ${Isolate.current.debugName}';
// }

// String _errorMessage(DateTime requestTime, Uri requestedUri, String method,
//     Duration elapsedTime, Object error, StackTrace? stack) {
//   var chain = Chain.current();
//   if (stack != null) {
//     chain = Chain.forTrace(stack)
//         .foldFrames((frame) => frame.isCore || frame.package == 'shelf')
//         .terse;
//   }

//   var msg = '$requestTime\t$elapsedTime\t$method\t${requestedUri.path}'
//       '${_formatQuery(requestedUri.query)}\n$error';

//   return '$msg\n$chain';
// }

// void _defaultLogger(String msg, bool isError) {
//   if (isError) {
//     print('[ERROR] $msg');
//   } else {
//     print(msg);
//   }
// }
