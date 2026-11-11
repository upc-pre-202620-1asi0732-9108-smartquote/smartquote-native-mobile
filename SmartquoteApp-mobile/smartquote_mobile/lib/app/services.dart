import '../identity_access/application/session_controller.dart';
import '../supply_requests/domain/request_workflows.dart';
import '../quotation_intake/domain/expiry_alerts.dart';
import '../supply_requests/domain/purchase_request.dart';
import '../quotation_intake/domain/quotation.dart';
import '../evaluation_simulation/domain/evaluation.dart';
import '../purchase_ordering/domain/purchase_order.dart';
import '../purchase_ordering/domain/corporate_profile.dart';
import '../purchase_ordering/application/ordering_workflow.dart';
import '../purchase_ordering/domain/ordering_policies.dart';
import '../evaluation_simulation/domain/sensitivity.dart';

class Services {
  const Services({
    required this.auth,
    required this.requests,
    required this.quotations,
    required this.evaluations,
    required this.orders,
    required this.orderExporter,
    this.workflows,
    this.expiryAlerts,
    this.policies,
    this.sensitivity,
  });
  final SessionController auth;
  final RequestWorkflowRepository? workflows;
  final ExpiryAlertRepository? expiryAlerts;

  /// US18 and US20: supplier enablement and acquisition budgets.
  final OrderingPolicyRepository? policies;

  /// US19: sensitivity analysis of the purchase recommendation.
  final SensitivityRepository? sensitivity;
  final RequestRepository requests;
  final QuotationRepository quotations;
  final EvaluationRepository evaluations;
  final OrderRepository orders;
  final OrderExporter orderExporter;
  OrderingWorkflow get ordering =>
      OrderingWorkflow(orders, evaluations, orderExporter);
}
