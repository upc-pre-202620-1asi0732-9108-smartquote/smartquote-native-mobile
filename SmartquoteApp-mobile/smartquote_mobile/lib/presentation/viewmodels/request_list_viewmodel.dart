import 'package:flutter/material.dart';
import '../../domain/entities/purchase_request.dart';
import '../../domain/repositories/smartquote_repository.dart';

class RequestListViewModel extends ChangeNotifier {
  final SmartQuoteRepository repository;

  RequestListViewModel({required this.repository});

  List<PurchaseRequest> requests = [];
  bool isLoading = true;
  String? errorMessage;

  Future<void> fetchRequests() async {
    isLoading = true;
    notifyListeners(); // Avisa a la UI que muestre un loader
    try {
      requests = await repository.getPurchaseRequests();
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Error al cargar las solicitudes';
    }
    isLoading = false;
    notifyListeners(); // Avisa a la UI que los datos llegaron
  }
}