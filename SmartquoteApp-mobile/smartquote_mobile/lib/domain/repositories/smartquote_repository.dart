import '../entities/purchase_request.dart';
import '../entities/notification.dart';

abstract class SmartQuoteRepository {
  Future<List<PurchaseRequest>> getPurchaseRequests();
  Future<List<AppNotification>> getNotifications();
  Future<bool> markNotificationAsRead(String notificationId);
  Future<bool> createPurchaseRequest(Map<String, dynamic> requestData);
}