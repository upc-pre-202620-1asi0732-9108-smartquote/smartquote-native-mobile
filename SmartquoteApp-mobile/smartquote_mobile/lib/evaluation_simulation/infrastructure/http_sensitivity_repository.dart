import '../../shared/domain/api_contract.dart';
import '../domain/sensitivity.dart';

class HttpSensitivityRepository implements SensitivityRepository {
  HttpSensitivityRepository(this.api);
  final ApiGateway api;

  @override
  Future<SensitivityAnalysis> analyze(
    String scenarioId,
    List<JsonObject> configurations,
  ) async => SensitivityAnalysis(
    objectOf(
      await api.request(
        '/evaluation-scenarios/$scenarioId/sensitivity-analyses',
        method: 'POST',
        body: {'configurations': configurations},
        timeout: const Duration(minutes: 3),
      ),
    ),
  );

  @override
  Future<List<SensitivityAnalysis>> history(String requestId) async =>
      objectsOf(
        await api.request('/purchase-requests/$requestId/sensitivity-analyses'),
      ).map(SensitivityAnalysis.new).toList();

  @override
  Future<JsonObject> promote(
    SensitivityAnalysis analysis,
    String configurationId,
  ) async {
    analysis.assertPromotable(configurationId);
    return objectOf(
      await api.request(
        '/sensitivity-analyses/${analysis.id}/configurations/$configurationId/official-simulation',
        method: 'POST',
        body: {'expectedCriteriaVersion': analysis.criteriaVersion},
        timeout: const Duration(minutes: 3),
      ),
    );
  }
}
