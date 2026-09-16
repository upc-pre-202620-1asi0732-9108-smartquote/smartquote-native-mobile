import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartquote_api/smartquote_api.dart';
import '../storage/secure_storage_provider.dart';

// Proveedor del cliente API principal
final apiProvider = Provider<SmartquoteApi>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  
  // Ajuste de IP dependiendo del emulador
  final String baseUrl = Platform.isAndroid 
      ? 'http://10.0.2.2:8080' 
      : 'http://127.0.0.1:8080';

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Interceptor para inyectar el JWT
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await tokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (DioException error, handler) async {
      // Aquí puedes manejar expiración de token (401) globalmente después
      return handler.next(error);
    },
  ));

  return SmartquoteApi(dio: dio);
});