import '../../shared/domain/api_contract.dart';

/// US19: research evidence only. It never issues orders nor replaces the
/// current criteria.
class SensitivityAnalysis {
  SensitivityAnalysis(JsonObject view)
    : data = objectOf(view['analysis']),
      current = view['isCurrent'] == true,
      stable = view['isStable'] == true;
  final JsonObject data;
  final bool current;
  final bool stable;

  String get id => textOf(data, 'id');
  int get criteriaVersion => integerOf(data, 'criteriaVersion');
  List<JsonObject> get configurations => objectsOf(data['configurations']);

  /// The baseline is identified by the API; row order is not a contract.
  JsonObject? get baseline {
    final inputs = data['inputs'] is Map ? objectOf(data['inputs']) : null;
    final id = inputs == null ? '' : textOf(inputs, 'baselineConfigurationId');
    return configurations.where((c) => c['id'] == id).firstOrNull ??
        configurations.firstOrNull;
  }

  /// Baseline first, then the variations in the API order.
  List<JsonObject> get ordered => [
    ?baseline,
    ...configurations.where((c) => c['id'] != baseline?['id']),
  ];

  bool isBaseline(JsonObject configuration) =>
      configuration['id'] == baseline?['id'];

  /// Whether this configuration recommends another supplier than the baseline.
  bool changesRecommendation(JsonObject configuration) =>
      configuration['recommendedQuotationId'] !=
      baseline?['recommendedQuotationId'];

  int get changedCount => configurations.where(changesRecommendation).length;

  void assertPromotable(String configurationId) {
    if (!current) {
      throw const ApiFailure(
        'Los datos cambiaron después de este análisis. Repítelo antes de usar una configuración.',
        status: 409,
      );
    }
    if (!configurations.any((c) => c['id'] == configurationId)) {
      throw const ApiFailure('La configuración no pertenece a este análisis.');
    }
  }
}

const maximumSensitivityVariants = 20;

JsonObject? _weighted(List<JsonObject> criteria, String category) => criteria
    .where((c) => c['mode'] == 'Weighted' && c['category'] == category)
    .firstOrNull;

/// Sum of the commercial weights (price and delivery time) that may vary.
double commercialWeight(List<JsonObject> criteria) {
  final price = _weighted(criteria, 'Price');
  final delivery = _weighted(criteria, 'DeliveryTime');
  return price == null || delivery == null
      ? 0
      : numberOf(price, 'weight') + numberOf(delivery, 'weight');
}

/// Builds the variations: only price and delivery time move against each
/// other; mandatory rules and other weighted criteria keep their value.
List<JsonObject> sensitivityVariants(
  List<JsonObject> criteria,
  List<double> priceWeights,
) {
  final weighted = criteria.where((c) => c['mode'] == 'Weighted').toList();
  final price = _weighted(criteria, 'Price');
  final delivery = _weighted(criteria, 'DeliveryTime');
  if (price == null ||
      delivery == null ||
      weighted.any((c) => textOf(c, 'criterionId').isEmpty)) {
    throw const ApiFailure(
      'Primero guarda criterios con pesos de precio y plazo de entrega.',
    );
  }
  final commercial = commercialWeight(criteria);
  final current = numberOf(price, 'weight');
  if (priceWeights.isEmpty ||
      priceWeights.length > maximumSensitivityVariants ||
      priceWeights.toSet().length != priceWeights.length ||
      priceWeights.any(
        (w) => !w.isFinite || w < 0 || w > commercial || w == current,
      )) {
    throw ApiFailure(
      'Agrega entre 1 y $maximumSensitivityVariants pesos de precio distintos, diferentes del vigente y entre 0 y ${commercial.toStringAsFixed(0)} %.',
    );
  }
  return [
    for (final value in priceWeights)
      {
        'weights': [
          for (final c in weighted)
            {
              'criterionId': c['criterionId'],
              'weight': identical(c, price)
                  ? value
                  : identical(c, delivery)
                  ? commercial - value
                  : numberOf(c, 'weight'),
            },
        ],
      },
  ];
}

abstract interface class SensitivityRepository {
  Future<SensitivityAnalysis> analyze(
    String scenarioId,
    List<JsonObject> configurations,
  );
  Future<List<SensitivityAnalysis>> history(String requestId);

  /// Returns the identifiers of the official scenario and simulation created.
  Future<JsonObject> promote(
    SensitivityAnalysis analysis,
    String configurationId,
  );
}
