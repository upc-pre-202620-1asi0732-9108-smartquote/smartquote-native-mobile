import '../identity_access/application/session_controller.dart';
import '../supply_requests/domain/purchase_request.dart';
import '../quotation_intake/domain/quotation.dart';
import '../evaluation_simulation/domain/evaluation.dart';
import '../purchase_ordering/domain/purchase_order.dart';
import '../purchase_ordering/domain/corporate_profile.dart';
import '../purchase_ordering/application/ordering_workflow.dart';

class Services {
  const Services({
    required this.auth,
    required this.requests,
    required this.quotations,
    required this.evaluations,
    required this.orders,
    required this.orderExporter,
  });
  final SessionController auth;
  final RequestRepository requests;
  final QuotationRepository quotations;
  final EvaluationRepository evaluations;
  final OrderRepository orders;
  final OrderExporter orderExporter;
  OrderingWorkflow get ordering =>
      OrderingWorkflow(orders, evaluations, orderExporter);
}
