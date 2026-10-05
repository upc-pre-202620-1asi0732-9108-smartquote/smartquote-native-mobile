class PurchaseRequest {
  final String requestId;
  final DateTime requiredDate;
  final String? priority;
  final String? status;
  // Simplificado para el ejemplo de la tabla
  
  PurchaseRequest({
    required this.requestId,
    required this.requiredDate,
    this.priority,
    this.status,
  });
}