import '../../shared/domain/api_contract.dart';
import '../../supply_requests/domain/purchase_request.dart';

List<JsonObject> defaultCriteria(PurchaseRequest request) => [
  for (final item in request.items)
    for (final r in objectsOf(
      item['requirements'],
    ).where((r) => r['isMandatory'] == true))
      {
        'name': '${textOf(item, 'description')}: ${textOf(r, 'name')}',
        'targetField': r['requirementId'],
        'category': 'TechnicalCompliance',
        'mode': 'Mandatory',
        'operator': r['operator'],
        'expectedValue': r['expectedValue'],
        'unitOfMeasure': r['unitOfMeasure'],
        'weight': 0,
      },
  {
    'name': 'Precio total',
    'targetField': 'totalPrice',
    'category': 'Price',
    'mode': 'Weighted',
    'operator': 'LessThanOrEqual',
    'expectedValue': '999999999',
    'unitOfMeasure': '',
    'weight': 60,
  },
  {
    'name': 'Plazo de entrega',
    'targetField': 'deliveryLeadTimeDays',
    'category': 'DeliveryTime',
    'mode': 'Weighted',
    'operator': 'LessThanOrEqual',
    'expectedValue': '365',
    'unitOfMeasure': 'days',
    'weight': 40,
  },
].indexed.map((e) => {...e.$2, 'displayOrder': e.$1 + 1}).toList();
List<JsonObject> criteriaPayload(List<JsonObject> criteria) => criteria.indexed
    .map(
      (e) => {
        for (final key in [
          'name',
          'targetField',
          'category',
          'mode',
          'operator',
          'expectedValue',
          'unitOfMeasure',
          'weight',
        ])
          key: e.$2[key],
        'displayOrder': e.$1 + 1,
      },
    )
    .toList();
String? criteriaError(List<JsonObject> criteria, PurchaseRequest request) {
  final weighted = criteria.where((c) => c['mode'] == 'Weighted').toList();
  if (weighted.isEmpty || !criteria.any((c) => c['mode'] == 'Mandatory')) {
    return 'Incluye criterios obligatorios y ponderados.';
  }
  if (weighted.any(
    (c) =>
        !numberOf(c, 'weight').isFinite ||
        numberOf(c, 'weight') < 0 ||
        numberOf(c, 'weight') > 100,
  )) {
    return 'Cada peso debe estar entre 0 y 100 %.';
  }
  if ((weighted.fold<double>(0, (sum, c) => sum + numberOf(c, 'weight')) - 100)
          .abs() >
      .001) {
    return 'Los pesos deben sumar exactamente 100 %.';
  }
  for (final r in request.requirements.where((r) => r['isMandatory'] == true)) {
    if (!criteria.any(
      (c) =>
          c['mode'] == 'Mandatory' &&
          c['targetField'] == r['requirementId'] &&
          c['operator'] == r['operator'] &&
          c['expectedValue'] == r['expectedValue'],
    )) {
      return 'No se pueden omitir ni cambiar los requisitos obligatorios de producción.';
    }
  }
  return null;
}
