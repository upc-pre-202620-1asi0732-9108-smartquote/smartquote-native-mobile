import '../../shared/domain/api_contract.dart';
import '../domain/request_workflows.dart';

class HttpRequestWorkflowRepository implements RequestWorkflowRepository {
  HttpRequestWorkflowRepository(this.api);
  final ApiGateway api;
  @override
  Future<List<JsonObject>> clarifications({
    String? requestId,
    int page = 1,
  }) async => objectsOf(
    await api.request(
      requestId == null
          ? '/technical-clarifications'
          : '/purchase-requests/$requestId/clarifications',
      query: {
        'page': page,
        'pageSize': 20,
        if (requestId == null) 'assignedToMe': true,
      },
    ),
  );
  @override
  Future<JsonObject> ask(String requestId, JsonObject payload) async =>
      objectOf(
        await api.request(
          '/purchase-requests/$requestId/clarifications',
          method: 'POST',
          body: payload,
        ),
      );
  @override
  Future<void> read(String id) async {
    await api.request('/technical-clarifications/$id/read', method: 'PUT');
  }

  @override
  Future<JsonObject> respond(String id, String answer, int version) async =>
      objectOf(
        await api.request(
          '/technical-clarifications/$id/response',
          method: 'POST',
          body: {'answer': answer.trim(), 'expectedVersion': version},
        ),
      );
  @override
  Future<void> revise(String id, JsonObject payload) async {
    await api.request(
      '/technical-clarifications/$id/requirement-revisions',
      method: 'POST',
      body: payload,
    );
  }

  @override
  Future<List<JsonObject>> revisions(String requestId) async => objectsOf(
    await api.request('/purchase-requests/$requestId/requirement-revisions'),
  );
  @override
  Future<List<JsonObject>> schedules({int page = 1}) async => objectsOf(
    await api.request(
      '/recurring-request-schedules',
      query: {'page': page, 'pageSize': 20},
    ),
  );
  @override
  Future<JsonObject> schedule(String id) async =>
      objectOf(await api.request('/recurring-request-schedules/$id'));
  @override
  Future<JsonObject> createSchedule(JsonObject payload) async => objectOf(
    await api.request(
      '/recurring-request-schedules',
      method: 'POST',
      body: payload,
    ),
  );
  @override
  Future<JsonObject> pause(String id, int version) async => objectOf(
    await api.request(
      '/recurring-request-schedules/$id/pause',
      method: 'POST',
      body: {'expectedVersion': version},
    ),
  );
  @override
  Future<void> saveDraft(String requestId, JsonObject payload) async {
    await api.request(
      '/purchase-requests/$requestId/draft',
      method: 'PUT',
      body: payload,
    );
  }

  @override
  Future<void> submitDraft(String requestId, int version) async {
    await api.request(
      '/purchase-requests/$requestId/submit',
      method: 'POST',
      body: {'expectedVersion': version},
    );
  }
}
