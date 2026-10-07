import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/api_contract.dart';
import 'http_platform_native.dart'
    if (dart.library.js_interop) 'http_platform_web.dart'
    as platform;

class ApiClient implements ApiGateway, SessionTransport {
  ApiClient(String address, {Dio? dio}) : _dio = dio ?? Dio() {
    baseUrl = normalizeAddress(address);
    _dio.options = BaseOptions(
      baseUrl: '$baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 45),
      headers: {'Accept': 'application/json'},
      followRedirects: false,
    );
    _clearCookies = platform.configurePlatform(_dio);
  }
  static String normalizeAddress(String address) {
    var value = address.trim().replaceFirst(RegExp(r'/+$'), '');
    if (value.endsWith('/api/v1')) value = value.substring(0, value.length - 7);
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ApiFailure(
        'La dirección debe ser el origen de la API (sin rutas ni credenciales).',
      );
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw const ApiFailure(
        'La versión de distribución requiere una API HTTPS.',
      );
    }
    return value;
  }

  final Dio _dio;
  @override
  late final String baseUrl;
  late final Future<void> Function() _clearCookies;
  String? accessToken;
  Future<bool> Function()? renewSession;
  @override
  Future<void> clearSession() async {
    accessToken = null;
    await _clearCookies();
  }

  @override
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
    JsonObject? query,
    bool authenticated = true,
    Duration? timeout,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (authenticated && accessToken == null) {
      throw const ApiFailure('Inicia sesión para continuar.', status: 401);
    }
    Future<Response<dynamic>> send() => _dio.request<dynamic>(
      path,
      data: _encodeBody(body),
      queryParameters: query,
      options: Options(
        method: method,
        receiveTimeout: timeout ?? const Duration(seconds: 45),
        headers: authenticated ? {'Authorization': 'Bearer $accessToken'} : {},
      ),
      onSendProgress: onSendProgress,
    );
    try {
      try {
        return (await send()).data;
      } on DioException catch (error) {
        if (authenticated &&
            error.response?.statusCode == 401 &&
            renewSession != null &&
            await renewSession!()) {
          // Authorization rejected the first call before business processing.
          return (await send()).data;
        }
        rethrow;
      }
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Object? _encodeBody(Object? body) {
    if (body is! MultipartPayload) return body;
    final form = FormData();
    body.fields.forEach((key, value) {
      if (value != null) form.fields.add(MapEntry(key, value.toString()));
    });
    body.files.forEach((key, files) {
      for (final file in files) {
        form.files.add(
          MapEntry(
            key,
            MultipartFile.fromBytes(
              file.bytes,
              filename: file.name,
              contentType: DioMediaType.parse(file.contentType),
            ),
          ),
        );
      }
    });
    return form;
  }

  static ApiFailure failureFrom(DioException error) {
    final status = error.response?.statusCode ?? 0;
    final raw = error.response?.data;
    final problem = raw is Map ? objectOf(raw) : <String, dynamic>{};
    final fields = problem['errors'] is Map
        ? (problem['errors'] as Map).values
              .expand((v) => v is List ? v : [v])
              .join(' ')
        : '';
    final fallback = switch (status) {
      401 => 'La sesión venció o las credenciales son incorrectas.',
      403 => 'Tu rol no tiene permiso para esta operación.',
      404 => 'No se encontró el recurso.',
      409 => 'Los datos cambiaron. Actualiza antes de continuar.',
      413 => 'El archivo excede el tamaño permitido.',
      415 => 'El formato del archivo no está permitido.',
      429 => 'Se alcanzó el límite de solicitudes. Espera antes de reintentar.',
      503 =>
        'El servicio externo no está disponible. No se sustituyeron datos.',
      0 => 'No se pudo conectar o se agotó el tiempo de espera. Comprueba el resultado antes de repetir una creación.',
      _ => 'La API no pudo completar la operación (HTTP $status).',
    };
    final detail = [
      textOf(problem, 'detail'),
      fields,
    ].where((v) => v.isNotEmpty).join(' ');
    return ApiFailure(
      detail.isEmpty ? fallback : detail,
      status: status,
      code: textOf(problem, 'code'),
      traceId: textOf(problem, 'traceId'),
    );
  }
}
