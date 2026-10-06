import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/smartquote_repository.dart';

// Clases auxiliares para manejar el estado del formulario anidado
class RequirementForm {
  String name = '';
  String operator = 'Igual a';
  String expectedValue = '';
  String unitOfMeasure = '';
  bool isMandatory = true;
}

class ItemForm {
  String description = '';
  int quantity = 1;
  String unitOfMeasure = '';
  List<RequirementForm> requirements = [RequirementForm()];
}

class NewRequestViewModel extends ChangeNotifier {
  final SmartQuoteRepository repository;
  NewRequestViewModel({required this.repository});

  DateTime requiredDate = DateTime.now().add(const Duration(days: 7));
  String priority = 'Normal';
  List<ItemForm> items = [ItemForm()];
  
  bool isSubmitting = false;
  String? errorMessage;

  void setDate(DateTime date) { requiredDate = date; notifyListeners(); }
  void setPriority(String prio) { priority = prio; notifyListeners(); }

  void addItem() { items.add(ItemForm()); notifyListeners(); }
  void addRequirement(int itemIndex) { items[itemIndex].requirements.add(RequirementForm()); notifyListeners(); }

  Future<bool> submitRequest() async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    // Mapeamos nuestras clases auxiliares al JSON que espera el Backend
    final requestData = {
      "requiredDate": DateFormat('yyyy-MM-dd').format(requiredDate),
      "priority": priority,
      "items": items.map((item) => {
        "description": item.description,
        "quantity": item.quantity,
        "unitOfMeasure": item.unitOfMeasure,
        "requirements": item.requirements.map((req) => {
          "name": req.name,
          "operator": req.operator,
          "expectedValue": req.expectedValue,
          "unitOfMeasure": req.unitOfMeasure,
          "isMandatory": req.isMandatory
        }).toList()
      }).toList()
    };

    try {
      final success = await repository.createPurchaseRequest(requestData);
      isSubmitting = false;
      notifyListeners();
      return success;
    } catch (e) {
      errorMessage = e.toString();
      isSubmitting = false;
      notifyListeners();
      return false;
    }
  }
}