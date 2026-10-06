import 'package:flutter/material.dart';
import '../../domain/entities/notification.dart';
import '../../domain/repositories/smartquote_repository.dart';

class NotificationViewModel extends ChangeNotifier {
  final SmartQuoteRepository repository;
  NotificationViewModel({required this.repository});

  List<AppNotification> notifications = [];
  bool isLoading = true;

  Future<void> fetchNotifications() async {
    isLoading = true;
    notifyListeners();
    try {
      notifications = await repository.getNotifications();
    } catch (e) {
      print("Error: $e");
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    bool success = await repository.markNotificationAsRead(id);
    if (success) {
      // Recarga la lista para que desaparezca o se actualice
      fetchNotifications(); 
    }
  }
}