import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

Future<void> Function() configurePlatform(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
  return () async {};
}
