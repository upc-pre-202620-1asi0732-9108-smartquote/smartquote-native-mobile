import '../entities/purchase_request.dart';
import '../entities/notification.dart';

abstract class SmartQuoteRepository {
  Future<List<PurchaseRequest>> getPurchaseRequests();
  Future<List<AppNotification>> getNotifications();
  // Agregaremos el POST createRequest luego
}