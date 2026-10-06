import '../../shared/domain/api_contract.dart';

class PurchaseOrder {
  static const maximumObservationsLength = 500;

  static void validateEvaluation(int onTime, int quality, String observations) {
    if (onTime < 1 || onTime > 5 || quality < 1 || quality > 5) {
      throw const ApiFailure('Las calificaciones deben estar entre 1 y 5.');
    }
    if (observations.trim().length > maximumObservationsLength) {
      throw const ApiFailure(
        'Las observaciones no pueden superar 500 caracteres.',
      );
    }
  }

  PurchaseOrder(this.data);
  final JsonObject data;
  String get id => textOf(data, 'purchaseOrderId');
  String get status => textOf(data, 'status');
  List<JsonObject> get lines => objectsOf(data['lines']);
}

abstract interface class OrderRepository {
  Future<PurchaseOrder?> byRequest(String requestId);
  Future<PurchaseOrder?> bySimulation(String runId);
  Future<PurchaseOrder> get(String id);
  Future<PurchaseOrder> approve(
    String runId,
    String quoteId,
    String conditions,
    String destination,
  );
  Future<PurchaseOrder> delivered(String id);
  Future<JsonObject> evaluate(
    String id,
    int onTime,
    int quality,
    String observations,
  );
  Future<JsonObject> performance(String taxId);
  Future<List<JsonObject>> audit(String entityType, String id);
  Future<JsonObject> metrics(String from, String to);
}
