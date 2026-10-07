import '../../shared/domain/api_contract.dart';
import '../domain/purchase_request.dart';

class HttpRequestRepository implements RequestRepository {
  HttpRequestRepository(this.api);
  final ApiGateway api;
  @override
  Future<RequestPage> list({String status = '', int page = 1}) async =>
      RequestPage(
        objectOf(
          await api.request(
            '/purchase-requests',
            query: {
              'page': page,
              'pageSize': 12,
              if (status.isNotEmpty) 'status': status,
            },
          ),
        ),
      );
  @override
  Future<PurchaseRequest> get(String id) async =>
      PurchaseRequest(objectOf(await api.request('/purchase-requests/$id')));
  @override
  Future<PurchaseRequest> create(JsonObject payload) async => PurchaseRequest(
    objectOf(
      await api.request('/purchase-requests', method: 'POST', body: payload),
    ),
  );
  @override
  Future<List<JsonObject>> history(String id) async => objectsOf(
    objectOf(await api.request('/purchase-requests/$id/history'))['entries'],
  );
  @override
  Future<void> changeStatus(
    PurchaseRequest request,
    String nextStatus,
    String reason,
  ) async {
    await api.request(
      '/purchase-requests/${request.id}/status',
      method: 'PUT',
      body: {
        'nextStatus': nextStatus,
        'reason': reason.trim(),
        'expectedVersion': request.version,
      },
    );
  }

  @override
  Future<void> attach(PurchaseRequest request, UploadFile file) async {
    await api.request(
      '/purchase-requests/${request.id}/attachments',
      method: 'POST',
      body: MultipartPayload(
        {'expectedVersion': request.version},
        {
          'file': [file],
        },
      ),
    );
  }

  @override
  Future<List<JsonObject>> notifications({bool unreadOnly = false}) async =>
      objectsOf(
        await api.request('/notifications', query: {'unreadOnly': unreadOnly}),
      );
  @override
  Future<void> readNotification(String id) async {
    await api.request('/notifications/$id/read', method: 'PUT');
  }
}
