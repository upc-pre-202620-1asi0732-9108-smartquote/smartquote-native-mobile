import 'dart:typed_data';

typedef JsonObject = Map<String, dynamic>;

JsonObject objectOf(dynamic value) => Map<String, dynamic>.from(value as Map);
List<JsonObject> objectsOf(dynamic value) =>
    (value as List? ?? []).map(objectOf).toList(growable: false);
String textOf(JsonObject data, String key) => data[key]?.toString() ?? '';
double numberOf(JsonObject data, String key) =>
    (data[key] as num?)?.toDouble() ?? 0;
int integerOf(JsonObject data, String key) => (data[key] as num?)?.toInt() ?? 0;

class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.status = 0,
    this.code = '',
    this.traceId = '',
  });
  final String message;
  final int status;
  final String code;
  final String traceId;
  @override
  String toString() => message;
}

class UploadFile {
  const UploadFile(
    this.name,
    this.bytes,
    this.contentType, {
    this.validationError,
  });
  final String? validationError;
  final String name;
  final Uint8List bytes;
  final String contentType;
}

class MultipartPayload {
  const MultipartPayload(this.fields, this.files);
  final JsonObject fields;
  final Map<String, List<UploadFile>> files;
}

abstract interface class ApiGateway {
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
    JsonObject? query,
    bool authenticated = true,
    Duration? timeout,
    void Function(int sent, int total)? onSendProgress,
  });
}

abstract interface class SessionTransport {
  String get baseUrl;
  set accessToken(String? value);
  set renewSession(Future<bool> Function()? value);
  Future<void> clearSession();
}
