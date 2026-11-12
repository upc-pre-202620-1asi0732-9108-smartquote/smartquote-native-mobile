import '../../shared/domain/api_contract.dart';

/// US18: internal enablement of a supplier for new purchases. It is neither an
/// external certification nor a decision issued by AI.
class SupplierAccount {
  SupplierAccount(this.data);
  final JsonObject data;

  static const statuses = ['Pending', 'Enabled', 'Suspended'];
  static const _transitions = {
    'Pending': 'enable',
    'Enabled': 'suspend',
    'Suspended': 'reactivate',
  };
  static const actionLabels = {
    'enable': 'Habilitar proveedor',
    'suspend': 'Suspender proveedor',
    'reactivate': 'Reactivar proveedor',
  };

  String get id => textOf(data, 'id');
  String get name => textOf(data, 'businessName');
  String get taxId => textOf(data, 'taxIdentifier');
  String get status => textOf(data, 'status');
  int get version => integerOf(data, 'version');
  bool get enabled => status == 'Enabled';
  List<JsonObject> get history => objectsOf(data['history']);

  /// The only decision allowed from the current status, if any.
  String? get nextAction => _transitions[status];

  void validateDecision(String action, String reason) {
    if (nextAction != action) {
      throw const ApiFailure(
        'Esta decisión no está permitida desde el estado actual del proveedor.',
      );
    }
    validateReason(reason);
  }
}

void validateReason(String reason) {
  final text = reason.trim();
  if (text.isEmpty || text.length > 2000) {
    throw const ApiFailure('Registra un motivo de 1 a 2000 caracteres.');
  }
}

/// US20: versioned maximum budget in PEN. An absent budget is "not configured",
/// never a budget of zero.
class PurchaseBudget {
  PurchaseBudget(this.data);
  final JsonObject data;
  bool get configured =>
      data['status'] == 'Configured' && data['amountPen'] is num;
  double? get amountPen => (data['amountPen'] as num?)?.toDouble();

  /// The first authorization is sent with expected version 0.
  int get version => integerOf(data, 'version');
  List<JsonObject> get revisions => objectsOf(data['revisions']);

  /// Parses a positive amount with up to four decimals; comma or dot accepted.
  static double parseAmount(String value) {
    final text = value.trim().replaceAll(',', '.');
    final amount = RegExp(r'^\d{1,14}(\.\d{1,4})?$').hasMatch(text)
        ? double.tryParse(text)
        : null;
    if (amount == null || amount <= 0) {
      throw const ApiFailure(
        'Ingresa un importe positivo en PEN con hasta cuatro decimales.',
      );
    }
    return amount;
  }
}

/// Contrast of the complete amount to be issued against the current budget.
class BudgetCheck {
  BudgetCheck(this.data) : assessment = objectOf(data['assessment'] ?? {});
  final JsonObject data;
  final JsonObject assessment;
  String get status => textOf(assessment, 'status');
  bool get configured => status != 'NotConfigured';
  bool get exceeded => status == 'Exceeded';
  bool get canApprove => assessment['canApprove'] == true;

  /// Version to send with the approval; 0 states "checked without a budget".
  int get budgetVersion => integerOf(assessment, 'budgetVersion');
  JsonObject? get exchangeRate =>
      data['exchangeRate'] == null ? null : objectOf(data['exchangeRate']);

  void assertApprovable() {
    if (!canApprove) {
      throw const ApiFailure(
        'El importe total supera el presupuesto autorizado. No se emitió ninguna orden.',
      );
    }
  }
}

abstract interface class OrderingPolicyRepository {
  Future<List<SupplierAccount>> suppliers({String? status});
  Future<SupplierAccount> supplier(String id);
  Future<SupplierAccount> decide(
    SupplierAccount supplier,
    String action,
    String reason,
  );
  Future<PurchaseBudget> budget(String requestId);
  Future<PurchaseBudget> authorizeBudget(
    String requestId,
    double amount,
    String reason,
    int expectedVersion,
  );
  Future<BudgetCheck> budgetCheck(String runId, String quotationId);
}
