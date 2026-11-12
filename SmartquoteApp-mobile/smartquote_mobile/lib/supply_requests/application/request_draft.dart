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
  RequestDraft();
  factory RequestDraft.fromJson(JsonObject data) {
    final draft = RequestDraft();
    draft.requiredDate = DateTime.parse(textOf(data, 'requiredDate'));
    draft.priority = textOf(data, 'priority');
    draft.items.clear();
    for (final value in objectsOf(data['items'])) {
      final item = ItemDraft()
        ..description = textOf(value, 'description')
        ..quantity = '${value['quantity']}'
        ..unit = textOf(value, 'unitOfMeasure');
      item.requirements.clear();
      for (final r in objectsOf(value['requirements'])) {
        item.requirements.add(
          RequirementDraft()
            ..name = textOf(r, 'name')
            ..operator = textOf(r, 'operator')
            ..expectedValue = textOf(r, 'expectedValue')
            ..unit = textOf(r, 'unitOfMeasure')
            ..mandatory = r['isMandatory'] == true,
        );
      }
      draft.items.add(item);
    }
    return draft;
  }
  DateTime requiredDate = DateTime.now().add(const Duration(days: 7));
  String priority = 'Normal';
  final items = <ItemDraft>[ItemDraft()];
  String? validate() {
    if (items.isEmpty) return 'Agrega al menos un ítem.';
    for (final item in items) {
      final quantity = double.tryParse(item.quantity.replaceAll(',', '.'));
      if (item.description.trim().isEmpty ||
          item.unit.trim().isEmpty ||
          quantity == null ||
          !quantity.isFinite ||
          quantity <= 0) {
        return 'Completa la descripción, unidad y cantidad positiva de cada ítem.';
      }
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
        if (r.name.trim().isEmpty || r.expectedValue.trim().isEmpty) {
          return 'Completa el nombre y valor de cada requisito.';
        }
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
