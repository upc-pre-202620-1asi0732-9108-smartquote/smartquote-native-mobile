import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

Future<void> Function() configurePlatform(Dio dio) {
  // Session cookies stay in memory: no plaintext refresh token on disk.
  final jar = CookieJar();
  dio.interceptors.add(CookieManager(jar));
  return jar.deleteAll;
}
