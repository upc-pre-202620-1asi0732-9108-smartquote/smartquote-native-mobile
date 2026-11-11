import '../../shared/domain/api_contract.dart';
import '../domain/ordering_policies.dart';

class HttpOrderingPolicyRepository implements OrderingPolicyRepository {
  HttpOrderingPolicyRepository(this.api);
  final ApiGateway api;

  @override
  Future<List<SupplierAccount>> suppliers({String? status}) async {
    if (status != null && !SupplierAccount.statuses.contains(status)) {
      throw const ApiFailure('Selecciona un estado de proveedor válido.');
    }
    return objectsOf(
      await api.request(
        '/suppliers',
        query: {'status': ?status, 'page': 1, 'pageSize': 100},
      ),
    ).map(SupplierAccount.new).toList();
  }

  @override
  Future<SupplierAccount> supplier(String id) async =>
      SupplierAccount(objectOf(await api.request('/suppliers/$id')));

  @override
  Future<SupplierAccount> decide(
    SupplierAccount supplier,
    String action,
    String reason,
  ) async {
    supplier.validateDecision(action, reason);
    return SupplierAccount(
      objectOf(
        await api.request(
          '/suppliers/${supplier.id}/$action',
          method: 'POST',
          body: {'reason': reason.trim(), 'expectedVersion': supplier.version},
        ),
      ),
    );
  }

  @override
  Future<PurchaseBudget> budget(String requestId) async => PurchaseBudget(
    objectOf(await api.request('/purchase-requests/$requestId/budget')),
  );

  @override
  Future<PurchaseBudget> authorizeBudget(
    String requestId,
    double amount,
    String reason,
    int expectedVersion,
  ) async {
    if (!amount.isFinite || amount <= 0) {
      throw const ApiFailure(
        'Ingresa un importe positivo en PEN con hasta cuatro decimales.',
      );
    }
    validateReason(reason);
    return PurchaseBudget(
      objectOf(
        await api.request(
          '/purchase-requests/$requestId/budget',
          method: 'PUT',
          body: {
            'amount': amount,
            'currency': 'PEN',
            'reason': reason.trim(),
            'expectedVersion': expectedVersion,
          },
        ),
      ),
    );
  }

  @override
  Future<BudgetCheck> budgetCheck(String runId, String quotationId) async =>
      BudgetCheck(
        objectOf(
          await api.request(
            '/simulations/$runId/budget-check',
            query: {'quotationId': quotationId},
          ),
        ),
      );
}
