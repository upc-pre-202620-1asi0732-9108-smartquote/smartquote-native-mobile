import 'package:dio/dio.dart';
import 'auth_interceptor.dart';

class DioClient {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://smartquote-api-h8czffe5b4dtg6d7.chilecentral-01.azurewebsites.net/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(AuthInterceptor());

  static Dio get instance => _dio;
}