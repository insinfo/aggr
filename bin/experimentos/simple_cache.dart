// import 'dart:convert';
// import 'dart:io';
// import 'package:crypto/crypto.dart';

// class JsonFileCache {
//   final String cacheKey;
//   final String cacheDirPath;
//   final Duration cacheDuration;

//   DateTime get _now => DateTime.now();
//   File get _cacheFile => File(cacheDirPath + '/'+_generateMd5(cacheKey)+'.json');

//   String _generateMd5(String input) {
//     final bytes = utf8.encode(input); 
//     final md5Result = md5.convert(bytes); 
//     return md5Result.toString();
//   }

//   JsonFileCache(this.cacheKey,
//       {this.cacheDuration = const Duration(minutes: 30),this.cacheDirPath ='/tmp'});

//   Future<bool> isValid() async {
//     if (await _cacheFile.exists()) {
//       final lastModified = await _cacheFile.lastModified();
//       return _now.difference(lastModified) < cacheDuration;
//     }
//     return false;
//   }

//   Future<Map<String, dynamic>> read() async {
//     if (await _cacheFile.exists()) {
//       final contents = await _cacheFile.readAsString();
//       return json.decode(contents);
//     }
//     return {};
//   }
//   Future<String> readAsJson() async {
//     return jsonEncode(await read());
//   }


//   Future<void> write(Map<String, dynamic> data) async {
//     await _cacheFile.writeAsString(json.encode(data));
//   }
// }

// // Example usage:
// class ProductsController {
//  static Future<dynamic> getAll(request,response) async {
//     final cache = JsonFileCache(request.path);
//     final db = Conection('....');
//     try{
//     if (await cache.isValid()) {
//       // Use cached data
//       final cachedData = await cache.readAsJson();
//       print('Using cached data: $cachedData');
//      return response.json(cachedData);
//     } else {
//       // Fetch data from database      
//       db.open();
//       final data = await db.query('sql...').asJson();
//       db.close();
//       // Save the data to the cache
//       await cache.write(data);
//       print('Fetched data from API: $data');
//       return  response.json(data);      
//     }
//     }catch(e,s){
//        db.close();
//        return  response.json({'error':'..'}); 
//     }
//   }
// }


// final app = Angel();
// //routes
// app.get('/products',ProductsController.getAll);