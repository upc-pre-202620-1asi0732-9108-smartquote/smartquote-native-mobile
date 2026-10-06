import '../../shared/domain/api_contract.dart';

const roles = {
  'ProductionSpecialist': 'Producción',
  'PurchaseAnalyst': 'Analista de compras',
  'PurchaseManager': 'Jefe de compras',
};

class Session {
  Session.fromJson(JsonObject data)
    : token = textOf(data, 'accessToken'),
      expiresIn = integerOf(data, 'expiresIn'),
      user = objectOf(data['user']);
  final String token;
  final int expiresIn;
  final JsonObject user;
  List<String> get assignedRoles =>
      List<String>.from(user['roles'] as List? ?? []);
  bool has(String role) => assignedRoles.contains(role);
  bool get production => has('ProductionSpecialist');
  bool get manager => has('PurchaseManager');
  bool get purchasing => manager || has('PurchaseAnalyst');
  String get name => textOf(user, 'displayName');
}

String? passwordError(String value, String email) {
  if (value.length < 12 || value.length > 128) {
    return 'Usa entre 12 y 128 caracteres.';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value) ||
      !RegExp(r'[a-z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value) ||
      !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value)) {
    return 'Incluye mayúscula, minúscula, número y símbolo.';
  }
  final local = email.split('@').first;
  if (local.length >= 3 && value.toLowerCase().contains(local.toLowerCase())) {
    return 'No incluyas tu correo en la contraseña.';
  }
  if (RegExp(r'[\x00-\x1f]').hasMatch(value)) {
    return 'No uses caracteres de control.';
  }
  return null;
}

abstract interface class IdentityRepository {
  Future<Session> login(String email, String password);
  Future<Session> refresh();
  Future<void> logout();
  Future<JsonObject> register(JsonObject data);
  Future<bool> initialSetup();
  Future<JsonObject> me();
  Future<List<JsonObject>> pending();
  Future<void> approve(String userId, String role);
}
