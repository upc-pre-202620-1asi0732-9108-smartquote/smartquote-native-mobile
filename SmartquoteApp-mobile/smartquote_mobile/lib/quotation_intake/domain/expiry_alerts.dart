import '../../shared/domain/api_contract.dart';

abstract interface class ExpiryAlertRepository {
  Future<List<JsonObject>> list({bool unreadOnly = false, int page = 1});
  Future<void> read(String id);
}
