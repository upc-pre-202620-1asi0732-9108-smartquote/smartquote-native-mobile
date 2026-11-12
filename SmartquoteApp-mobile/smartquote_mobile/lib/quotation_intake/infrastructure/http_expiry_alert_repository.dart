import '../../shared/domain/api_contract.dart';
import '../domain/expiry_alerts.dart';

class HttpExpiryAlertRepository implements ExpiryAlertRepository {
  HttpExpiryAlertRepository(this.api);
  final ApiGateway api;
  @override
  Future<List<JsonObject>> list({
    bool unreadOnly = false,
    int page = 1,
  }) async => objectsOf(
    await api.request(
      '/quotation-expiry-alerts',
      query: {'unreadOnly': unreadOnly, 'page': page, 'pageSize': 20},
    ),
  );
  @override
  Future<void> read(String id) async {
    await api.request('/quotation-expiry-alerts/$id/read', method: 'PUT');
  }
}
