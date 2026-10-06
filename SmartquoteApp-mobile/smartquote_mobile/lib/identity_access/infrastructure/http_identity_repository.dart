import '../../shared/domain/api_contract.dart';
import '../domain/session.dart';

class HttpIdentityRepository implements IdentityRepository {
  HttpIdentityRepository(this.api);
  final ApiGateway api;
  Future<dynamic> _public(
    String path, {
    String method = 'POST',
    Object? body,
  }) => api.request(
    '/iam/auth/$path',
    method: method,
    body: body,
    authenticated: false,
  );
  @override
  Future<Session> login(String email, String password) async =>
      Session.fromJson(
        objectOf(
          await _public(
            'login',
            body: {'email': email.trim(), 'password': password},
          ),
        ),
      );
  @override
  Future<Session> refresh() async =>
      Session.fromJson(objectOf(await _public('refresh')));
  @override
  Future<void> logout() async {
    await _public('logout');
  }

  @override
  Future<JsonObject> register(JsonObject data) async =>
      objectOf(await _public('register', body: data));
  @override
  Future<bool> initialSetup() async =>
      objectOf(
        await _public('registration-status', method: 'GET'),
      )['initialSetupRequired'] ==
      true;
  @override
  Future<JsonObject> me() async => objectOf(await api.request('/iam/auth/me'));
  @override
  Future<List<JsonObject>> pending() async =>
      objectsOf(await api.request('/iam/registration-requests'));
  @override
  Future<void> approve(String userId, String role) async {
    await api.request(
      '/iam/registration-requests/$userId/approve',
      method: 'POST',
      body: {'role': role},
    );
  }
}
