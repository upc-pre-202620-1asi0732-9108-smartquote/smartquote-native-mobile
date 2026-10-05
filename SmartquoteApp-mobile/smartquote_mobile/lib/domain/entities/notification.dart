class AppNotification {
  final String notificationId;
  final String purchaseRequestId;
  final String? newStatus;
  final String? message;
  final DateTime createdAt;

  AppNotification({
    required this.notificationId,
    required this.purchaseRequestId,
    this.newStatus,
    this.message,
    required this.createdAt,
  });
}