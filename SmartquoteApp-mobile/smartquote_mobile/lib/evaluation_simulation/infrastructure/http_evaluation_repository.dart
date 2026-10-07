import '../../shared/domain/api_contract.dart';
import '../domain/evaluation.dart';

class HttpEvaluationRepository implements EvaluationRepository {
  HttpEvaluationRepository(this.api);
  final ApiGateway api;
  @override
  Future<EvaluationScenario?> current(String requestId) async {
    try {
      return EvaluationScenario(
        objectOf(
          await api.request(
            '/purchase-requests/$requestId/evaluation-scenario',
          ),
        ),
      );
    } on ApiFailure catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<EvaluationScenario> get(String id) async => EvaluationScenario(
    objectOf(await api.request('/evaluation-scenarios/$id')),
  );
  @override
  Future<EvaluationScenario> save(
    String requestId,
    List<JsonObject> criteria,
    EvaluationScenario? current,
  ) async => EvaluationScenario(
    objectOf(
      await api.request(
        current == null
            ? '/evaluation-scenarios'
            : '/evaluation-scenarios/${current.id}/versions',
        method: 'POST',
        body: {
          if (current == null) 'requestId': requestId,
          'criteria': criteria,
        },
      ),
    ),
  );
  @override
  Future<Simulation> simulate(String scenarioId) async => Simulation(
    objectOf(
      await api.request(
        '/evaluation-scenarios/$scenarioId/simulations',
        method: 'POST',
        timeout: const Duration(minutes: 3),
      ),
    ),
  );
  @override
  Future<Simulation> getSimulation(String id) async =>
      Simulation(objectOf(await api.request('/simulations/$id')));
  @override
  Future<List<Simulation>> history(String requestId) async =>
      objectsOf(await api.request('/purchase-requests/$requestId/simulations'))
          .map(Simulation.new)
          .toList();
}
