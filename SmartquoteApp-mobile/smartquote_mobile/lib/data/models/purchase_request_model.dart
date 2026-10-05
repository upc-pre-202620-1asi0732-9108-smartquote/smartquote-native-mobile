import '../../domain/entities/purchase_request.dart';

class PurchaseRequestModel extends PurchaseRequest {
  PurchaseRequestModel({
    required super.requestId,
    required super.requiredDate,
    super.priority,
    super.status,
  });

  factory PurchaseRequestModel.fromJson(Map<String, dynamic> json) {
    return PurchaseRequestModel(
      requestId: json['requestId'],
      requiredDate: DateTime.parse(json['requiredDate']),
      priority: json['priority'],
      status: json['status'],
    );
  }
}