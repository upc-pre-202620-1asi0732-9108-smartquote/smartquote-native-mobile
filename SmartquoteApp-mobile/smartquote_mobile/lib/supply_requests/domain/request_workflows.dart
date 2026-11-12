import '../../shared/domain/api_contract.dart';

/// US15/US16: versioned server operations; no client-side generation of occurrences.
abstract interface class RequestWorkflowRepository {
  Future<List<JsonObject>> clarifications({String? requestId, int page = 1});
  Future<JsonObject> ask(String requestId, JsonObject payload);
  Future<void> read(String id);
  Future<JsonObject> respond(String id, String answer, int version);
  Future<void> revise(String id, JsonObject payload);
  Future<List<JsonObject>> revisions(String requestId);
  Future<List<JsonObject>> schedules({int page = 1});
  Future<JsonObject> schedule(String id);
  Future<JsonObject> createSchedule(JsonObject payload);
  Future<JsonObject> pause(String id, int version);
  Future<void> saveDraft(String requestId, JsonObject payload);
  Future<void> submitDraft(String requestId, int version);
}
