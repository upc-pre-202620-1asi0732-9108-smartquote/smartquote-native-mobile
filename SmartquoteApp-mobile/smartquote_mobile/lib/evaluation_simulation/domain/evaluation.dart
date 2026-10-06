import '../../shared/domain/api_contract.dart';

class EvaluationScenario {
  EvaluationScenario(this.data);
  final JsonObject data;
  String get id => textOf(data, 'scenarioId');
  List<JsonObject> get criteria => objectsOf(data['criteria']);
}

class Simulation {
  Simulation(this.data);
  final JsonObject data;
  String get id => textOf(data, 'simulationRunId');
  bool get current => data['isCurrent'] == true;
  List<JsonObject> get evaluations => objectsOf(data['evaluations']);
  JsonObject? get recommendation =>
      data['recommendation'] == null ? null : objectOf(data['recommendation']);
  JsonObject? get exchangeRate =>
      data['exchangeRate'] == null ? null : objectOf(data['exchangeRate']);
}

abstract interface class EvaluationRepository {
  Future<EvaluationScenario?> current(String requestId);
  Future<EvaluationScenario> get(String id);
  Future<EvaluationScenario> save(
    String requestId,
    List<JsonObject> criteria,
    EvaluationScenario? current,
  );
  Future<Simulation> simulate(String scenarioId);
  Future<Simulation> getSimulation(String id);
  Future<List<Simulation>> history(String requestId);
}
