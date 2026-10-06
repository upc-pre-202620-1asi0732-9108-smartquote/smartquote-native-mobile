import '../../domain/entities/notification.dart';

class NotificationModel extends AppNotification {
  NotificationModel({
    required super.notificationId,
    required super.purchaseRequestId,
    super.newStatus,
    super.message,
    required super.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notificationId'],
      purchaseRequestId: json['purchaseRequestId'],
      newStatus: json['newStatus'],
      message: json['message'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}