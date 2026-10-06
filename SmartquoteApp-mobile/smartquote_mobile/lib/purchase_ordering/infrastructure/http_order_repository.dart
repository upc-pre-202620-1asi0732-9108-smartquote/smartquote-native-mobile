import '../../shared/domain/api_contract.dart';
import '../domain/purchase_order.dart';

class HttpOrderRepository implements OrderRepository {
  HttpOrderRepository(this.api);
  final ApiGateway api;
  Future<PurchaseOrder?> _optional(String path) async {
    try {
      return PurchaseOrder(objectOf(await api.request(path)));
    } on ApiFailure catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<PurchaseOrder?> byRequest(String id) =>
      _optional('/purchase-requests/$id/purchase-order');
  @override
  Future<PurchaseOrder?> bySimulation(String id) =>
      _optional('/simulations/$id/purchase-order');
  @override
  Future<PurchaseOrder> get(String id) async =>
      PurchaseOrder(objectOf(await api.request('/purchase-orders/$id')));
  @override
  Future<PurchaseOrder> approve(
    String runId,
    String quoteId,
    String conditions,
    String destination,
  ) async => PurchaseOrder(
    objectOf(
      await api.request(
        '/simulations/$runId/quotations/$quoteId/purchase-orders',
        method: 'POST',
        body: {
          'deliveryConditions': conditions,
          'deliveryDestination': destination,
        },
      ),
    ),
  );
  @override
  Future<PurchaseOrder> delivered(String id) async => PurchaseOrder(
    objectOf(
      await api.request('/purchase-orders/$id/delivery', method: 'POST'),
    ),
  );
  @override
  Future<JsonObject> evaluate(
    String id,
    int onTime,
    int quality,
    String observations,
  ) async {
    PurchaseOrder.validateEvaluation(onTime, quality, observations);
    return objectOf(
      await api.request(
        '/purchase-orders/$id/delivery-evaluation',
        method: 'POST',
        body: {
          'onTimeScore': onTime,
          'qualityScore': quality,
          'observations': observations.trim().isEmpty
              ? null
              : observations.trim(),
        },
      ),
    );
  }

  @override
  Future<JsonObject> performance(String taxId) async => objectOf(
    await api.request('/suppliers/${Uri.encodeComponent(taxId)}/performance'),
  );
  @override
  Future<List<JsonObject>> audit(String entityType, String id) async =>
      objectsOf(await api.request('/audit/$entityType/$id'));
  @override
  Future<JsonObject> metrics(String from, String to) async => objectOf(
    await api.request('/purchasing-metrics', query: {'from': from, 'to': to}),
  );
}
