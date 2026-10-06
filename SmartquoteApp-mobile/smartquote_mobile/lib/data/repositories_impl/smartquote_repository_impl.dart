import '../../core/network/dio_client.dart';
import '../../domain/entities/purchase_request.dart';
import '../../domain/entities/notification.dart';
import '../../domain/repositories/smartquote_repository.dart';
import '../models/purchase_request_model.dart';
import '../models/notification_model.dart';

class SmartQuoteRepositoryImpl implements SmartQuoteRepository {
  @override
  Future<List<PurchaseRequest>> getPurchaseRequests() async {
    try {
      final response = await DioClient.instance.get('/purchase-requests', queryParameters: {
        'page': 1,
        'pageSize': 20,
      });
      
      final List<dynamic> items = response.data['items'];
      return items.map((json) => PurchaseRequestModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al cargar solicitudes: $e');
    }
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    try {
      // El Swagger indica que devuelve directamente un arreglo (List)
      final response = await DioClient.instance.get('/notifications');
      final List<dynamic> data = response.data;
      return data.map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al cargar notificaciones: $e');
    }
  }

  @override
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final response = await DioClient.instance.put('/notifications/$notificationId/read');
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> createPurchaseRequest(Map<String, dynamic> requestData) async {
    try {
      final response = await DioClient.instance.post(
        '/purchase-requests',
        data: requestData,
      );
      return response.statusCode == 201;
    } catch (e) {
      throw Exception('Error al crear la solicitud: $e');
    }
  }
}