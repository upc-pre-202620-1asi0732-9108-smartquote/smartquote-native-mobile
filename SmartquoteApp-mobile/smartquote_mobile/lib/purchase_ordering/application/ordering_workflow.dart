import '../../evaluation_simulation/domain/evaluation.dart';
import '../../shared/domain/api_contract.dart';
import '../domain/purchase_order.dart';
import '../domain/corporate_profile.dart';

class OrderingWorkflow {
  const OrderingWorkflow(this.orders, this.evaluations, this.exporter);
  final OrderRepository orders;
  final EvaluationRepository evaluations;
  final OrderExporter exporter;
  Future<PurchaseOrder> approve(
    String runId,
    String quotationId,
    String conditions,
    String destination,
  ) async {
    final run = await evaluations.getSimulation(runId);
    if (!run.current ||
        !run.evaluations.any(
          (e) => e['quotationId'] == quotationId && e['isEligible'] == true,
        )) {
      throw const ApiFailure(
        'La simulación ya no está vigente o la oferta no es elegible. Actualiza y simula nuevamente.',
        status: 409,
      );
    }
    return orders.approve(run.id, quotationId, conditions, destination);
  }

  Future<void> export(String orderId, CorporateProfile profile) async {
    profile.validate();
    final snapshot = await orders.get(orderId);
    assertExportable(snapshot);
    await exporter.export(snapshot, profile);
  }
}
