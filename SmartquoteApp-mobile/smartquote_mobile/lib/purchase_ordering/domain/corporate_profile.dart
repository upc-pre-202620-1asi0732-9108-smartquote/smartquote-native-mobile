import '../../shared/domain/api_contract.dart';
import 'purchase_order.dart';

class CorporateProfile {
  const CorporateProfile({
    required this.name,
    required this.taxId,
    required this.address,
  });
  final String name, taxId, address;
  void validate() {
    if (name.trim().isEmpty ||
        address.trim().isEmpty ||
        !RegExp(r'^\d{11}$').hasMatch(taxId.trim())) {
      throw const ApiFailure(
        'Configura razón social, dirección y RUC corporativo de 11 dígitos.',
      );
    }
  }
}

abstract interface class OrderExporter {
  Future<void> export(PurchaseOrder order, CorporateProfile profile);
}

void assertExportable(PurchaseOrder order) {
  final data = order.data;
  if (!['Issued', 'Delivered'].contains(order.status) ||
      textOf(data, 'approvedBy').isEmpty ||
      DateTime.tryParse(textOf(data, 'approvedAt')) == null) {
    throw const ApiFailure('Solo se exportan órdenes aprobadas y emitidas.');
  }
  for (final key in [
    'orderNumber',
    'supplierBusinessName',
    'supplierTaxIdentifier',
    'currency',
    'deliveryConditions',
    'deliveryDestination',
    'purchaseRequestId',
    'simulationRunId',
    'inputFingerprint',
  ]) {
    if (textOf(data, key).trim().isEmpty) {
      throw ApiFailure('Falta información obligatoria de la orden: $key.');
    }
  }
  if (order.lines.isEmpty ||
      data['total'] is! num ||
      order.lines.any(
        (l) =>
            textOf(l, 'description').isEmpty ||
            l['quantity'] is! num ||
            l['unitPrice'] is! num ||
            textOf(l, 'unitOfMeasure').isEmpty,
      )) {
    throw const ApiFailure(
      'La orden no contiene partidas e importes completos.',
    );
  }
}
