import '../../core/network/dio_client.dart';
import '../../domain/entities/purchase_request.dart';
import '../../domain/entities/notification.dart';
import '../../domain/repositories/smartquote_repository.dart';
import '../models/purchase_request_model.dart';
// import '../models/notification_model.dart'; // Crearemos esto similar al anterior

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
    // Implementación similar llamando a /notifications
    throw UnimplementedError();
  }
}