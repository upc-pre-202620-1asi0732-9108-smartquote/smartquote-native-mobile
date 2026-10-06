import '../../shared/domain/api_contract.dart';

class RequirementDraft {
  String name = '', operator = 'Equals', expectedValue = '', unit = '';
  bool mandatory = true;
  JsonObject toJson() => {
    'name': name.trim(),
    'operator': operator,
    'expectedValue': expectedValue.trim(),
    'unitOfMeasure': unit.trim(),
    'isMandatory': mandatory,
  };
}

class ItemDraft {
  String description = '', quantity = '', unit = '';
  final requirements = <RequirementDraft>[RequirementDraft()];
  JsonObject toJson() => {
    'description': description.trim(),
    'quantity': double.parse(quantity.replaceAll(',', '.')),
    'unitOfMeasure': unit.trim(),
    'requirements': requirements.map((r) => r.toJson()).toList(),
  };
}

class RequestDraft {
  DateTime requiredDate = DateTime.now().add(const Duration(days: 7));
  String priority = 'Normal';
  final items = <ItemDraft>[ItemDraft()];
  String? validate() {
    if (items.isEmpty) return 'Agrega al menos un ítem.';
    for (final item in items) {
      if (!item.requirements.any((r) => r.mandatory)) {
        return 'Cada ítem debe tener al menos un requisito obligatorio.';
      }
      if (item.requirements
              .map((r) => r.name.trim().toLowerCase())
              .toSet()
              .length !=
          item.requirements.length) {
        return 'No repitas nombres de requisitos en un ítem.';
      }
      for (final r in item.requirements) {
        if (r.operator != 'Contains' &&
            r.operator != 'Equals' &&
            double.tryParse(r.expectedValue.replaceAll(',', '.')) == null) {
          return 'Los requisitos de comparación numérica necesitan un valor numérico.';
        }
      }
    }
    return null;
  }

  JsonObject toJson() => {
    'requiredDate': requiredDate.toIso8601String().substring(0, 10),
    'priority': priority,
    'items': items.map((i) => i.toJson()).toList(),
  };
}
