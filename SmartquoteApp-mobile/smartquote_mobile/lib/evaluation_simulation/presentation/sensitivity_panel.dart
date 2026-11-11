import 'package:flutter/material.dart' hide Simulation;

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/form_dialog.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../../supply_requests/domain/purchase_request.dart';
import '../domain/evaluation.dart';
import '../domain/sensitivity.dart';

/// US19: how the recommended alternative changes when the commercial weights
/// vary. The analysis alone never issues an order.
class SensitivityPanel extends StatefulWidget {
  const SensitivityPanel({
    super.key,
    required this.services,
    required this.request,
    required this.active,
    required this.onChanged,
    required this.onBusy,
    this.pendingCriteria = false,
  });
  final Services services;
  final PurchaseRequest request;
  final bool active;
  final Future<void> Function() onChanged;
  final void Function(bool) onBusy;
  final bool pendingCriteria;
  @override
  State<SensitivityPanel> createState() => _SensitivityPanelState();
}

class _SensitivityPanelState extends OperationState<SensitivityPanel> {
  EvaluationScenario? scenario;
  List<SensitivityAnalysis> analyses = [];
  SensitivityAnalysis? selected;
  List<double>? priceWeights;
  final names = <String, String>{};

  /// Criteria of each analyzed scenario version: the weights of an analysis
  /// refer to that version, not to the current one.
  final analyzedCriteria = <String, List<JsonObject>>{};

  SensitivityRepository get sensitivity => widget.services.sensitivity!;

  @override
  void initState() {
    super.initState();
    if (widget.active) load();
  }

  @override
  void didUpdateWidget(SensitivityPanel old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) load();
  }

  JsonObject? criterion(String category) => scenario?.criteria
      .where((c) => c['mode'] == 'Weighted' && c['category'] == category)
      .firstOrNull;
  double get commercial => commercialWeight(scenario?.criteria ?? []);
  double get currentPrice =>
      criterion('Price') == null ? 0 : numberOf(criterion('Price')!, 'weight');

  Future<void> fetch() async {
    scenario = await widget.services.evaluations.current(widget.request.id);
    analyses = await sensitivity.history(widget.request.id);
    selected =
        analyses.where((a) => a.id == selected?.id).firstOrNull ??
        analyses.firstOrNull;
    await loadAnalyzedCriteria(selected);
    names.clear();
    for (final q in await widget.services.quotations.list(widget.request.id)) {
      names[q.id] = textOf(q.data, 'supplierBusinessName');
    }
    // Suggested variations around the current price weight.
    priceWeights ??= [
      for (final w in <double>[20, 40, 50, 60, 80])
        if (w != currentPrice && w <= commercial) w,
    ];
  }

  Future<void> loadAnalyzedCriteria(SensitivityAnalysis? analysis) async {
    final id = analysis == null ? '' : textOf(analysis.data, 'scenarioId');
    if (id.isEmpty || analyzedCriteria.containsKey(id)) return;
    analyzedCriteria[id] = id == scenario?.id
        ? scenario!.criteria
        : (await widget.services.evaluations.get(id)).criteria;
  }

  Future<void> select(SensitivityAnalysis analysis) async {
    await perform(() async {
      await loadAnalyzedCriteria(analysis);
      selected = analysis;
    });
  }

  Future<void> load() async {
    await perform(fetch);
  }

  Future<void> addVariant() async {
    final values = await dataDialog(context, 'Agregar variación', [
      (
        'weight',
        'Peso del precio (0 a ${commercial.toStringAsFixed(0)} %)',
        '',
      ),
    ]);
    if (values == null || !mounted) return;
    final value = double.tryParse(values['weight']!.replaceAll(',', '.'));
    final weights = priceWeights ?? [];
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        value > commercial ||
        value == currentPrice ||
        weights.contains(value) ||
        weights.length >= maximumSensitivityVariants) {
      setState(
        () => error = ApiFailure(
          'Ingresa un peso distinto del vigente y de los ya agregados, entre 0 y ${commercial.toStringAsFixed(0)} %.',
        ),
      );
      return;
    }
    setState(() {
      error = null;
      priceWeights = [...weights, value]..sort();
    });
  }

  Future<void> analyze() async {
    widget.onBusy(true);
    final done = await perform(() async {
      final fresh = await widget.services.evaluations.current(
        widget.request.id,
      );
      if (fresh == null || fresh.id != scenario?.id) {
        throw const ApiFailure(
          'Los criterios cambiaron en otra sesión. Actualiza antes de analizar.',
          status: 409,
        );
      }
      selected = await sensitivity.analyze(
        fresh.id,
        sensitivityVariants(fresh.criteria, priceWeights ?? []),
      );
      analyses = [selected!, ...analyses];
      await loadAnalyzedCriteria(selected);
      return true;
    });
    widget.onBusy(false);
    if (done == true) {
      notice('Análisis de sensibilidad registrado. No modifica los criterios.');
    }
  }

  /// Scenario 4: a configuration of interest becomes official criteria and an
  /// official simulation; the purchase still needs the regular approval.
  Future<void> promote(JsonObject configuration) async {
    if (!await confirmAction(
      context,
      'Usar esta configuración',
      'Se crea una nueva versión de criterios y una simulación oficial con estos pesos. No se emite ninguna orden: la aprobación sigue en la pestaña Orden.',
    )) {
      return;
    }
    widget.onBusy(true);
    final done = await perform(() async {
      await sensitivity.promote(selected!, textOf(configuration, 'id'));
      await fetch();
      return true;
    });
    widget.onBusy(false);
    if (done == true) {
      notice(
        'Simulación oficial creada. Revísala en Simulación y aprueba desde Orden.',
      );
      await widget.onChanged();
    } else if (mounted) {
      final previous = error;
      await load();
      if (mounted && previous != null) setState(() => error = previous);
    }
  }

  String supplier(Object? quotationId) => quotationId == null
      ? 'Sin recomendación'
      : names['$quotationId'] ?? shortId('$quotationId');
  String weightOf(JsonObject configuration, String category) {
    final analyzed =
        analyzedCriteria[textOf(selected?.data ?? {}, 'scenarioId')] ?? [];
    final ids = analyzed
        .where((c) => c['mode'] == 'Weighted' && c['category'] == category)
        .map((c) => c['criterionId'])
        .toSet();
    final weight = objectsOf(configuration['weights'])
        .where((w) => ids.contains(w['criterionId']))
        .firstOrNull;
    return weight == null
        ? '—'
        : '${numberOf(weight, 'weight').toStringAsFixed(0)} %';
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        criterion('Price') != null && criterion('DeliveryTime') != null;
    final weights = priceWeights ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        ErrorNotice(error, onRetry: busy ? null : load),
        Row(
          children: [
            const Expanded(child: Text('Análisis de sensibilidad')),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Comprueba si el proveedor recomendado cambia al variar las ponderaciones comerciales. Las ofertas, los requisitos obligatorios y el tipo de cambio se mantienen; los criterios vigentes no se modifican.',
        ),
        if (!ready && !busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Primero guarda criterios con pesos de precio y plazo de entrega en la pestaña Simulación.',
            ),
          ),
        if (ready)
          InfoCard(
            title: 'Variaciones por evaluar',
            children: [
              Text(
                'Pesos vigentes · Precio ${currentPrice.toStringAsFixed(0)} % · Plazo ${(commercial - currentPrice).toStringAsFixed(0)} % (versión ${scenario!.data['version']})',
              ),
              if (widget.pendingCriteria)
                const Text(
                  'Hay criterios sin guardar. El análisis utiliza la versión guardada.',
                ),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in weights)
                    InputChip(
                      label: Text(
                        'Precio ${value.toStringAsFixed(0)} % · Plazo ${(commercial - value).toStringAsFixed(0)} %',
                      ),
                      onDeleted: busy
                          ? null
                          : () => setState(
                              () => priceWeights = [
                                for (final w in weights)
                                  if (w != value) w,
                              ],
                            ),
                    ),
                ],
              ),
              TextButton.icon(
                onPressed: busy || weights.length >= maximumSensitivityVariants
                    ? null
                    : addVariant,
                icon: const Icon(Icons.add),
                label: const Text('Agregar variación'),
              ),
              FilledButton(
                onPressed:
                    busy ||
                        weights.isEmpty ||
                        widget.request.status != 'Evaluation'
                    ? null
                    : analyze,
                child: const Text('Analizar sensibilidad'),
              ),
              if (widget.request.status != 'Evaluation')
                const Text(
                  'La solicitud debe estar en evaluación y contar con al menos dos cotizaciones elegibles.',
                ),
            ],
          ),
        if (analyses.length > 1)
          InfoCard(
            title: 'Análisis registrados',
            children: [
              for (final analysis in analyses)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: analysis.id == selected?.id,
                  title: Text(
                    'Análisis ${shortId(analysis.id)} · versión ${analysis.criteriaVersion}',
                  ),
                  subtitle: Text(
                    '${dateLabel(textOf(analysis.data, 'createdAt'), time: true)} · ${analysis.current ? 'Vigente' : 'Desactualizado'}',
                  ),
                  onTap: busy ? null : () => select(analysis),
                ),
            ],
          ),
        if (selected != null) result(selected!),
      ],
    );
  }

  Widget result(SensitivityAnalysis analysis) => InfoCard(
    title: 'Resultado · ${shortId(analysis.id)}',
    children: [
      Text(
        analysis.stable
            ? 'El proveedor recomendado se mantiene en todas las configuraciones evaluadas.'
            : 'El proveedor recomendado cambia en ${analysis.changedCount} configuración(es).',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text(
        'La conclusión se limita a las configuraciones efectivamente evaluadas.',
      ),
      if (!analysis.current)
        const Text(
          'Los datos cambiaron después de este análisis. Repítelo antes de usar una configuración.',
        ),
      for (final configuration in analysis.ordered)
        Card(
          key: ValueKey('configuration-${configuration['id']}'),
          color: analysis.isBaseline(configuration)
              ? null
              : analysis.changesRecommendation(configuration)
              ? const Color(0xfffff4e5)
              : const Color(0xffeaf4ef),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${analysis.isBaseline(configuration) ? 'Vigente' : 'Variación'} · Precio ${weightOf(configuration, 'Price')} · Plazo ${weightOf(configuration, 'DeliveryTime')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Recomendado: ${supplier(configuration['recommendedQuotationId'])}',
                ),
                if (!analysis.isBaseline(configuration))
                  Text(
                    analysis.changesRecommendation(configuration)
                        ? 'Cambia la recomendación frente a la vigente.'
                        : 'Mantiene la recomendación vigente.',
                  ),
                if ((configuration['tiedWinnerIds'] as List? ?? []).length > 1)
                  const Text(
                    'Empate resuelto por identificador de cotización.',
                  ),
                for (final score in objectsOf(configuration['results']))
                  Text(
                    score['isEligible'] == true
                        ? '${supplier(score['quotationId'])}: ${(numberOf(score, 'score') * 100).toStringAsFixed(2)} puntos / 100'
                        : '${supplier(score['quotationId'])}: excluida · ${(score['exclusions'] as List? ?? []).map((e) => friendlyExplanation('$e')).join(' ')}',
                  ),
                if (!analysis.isBaseline(configuration))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: busy || !analysis.current
                          ? null
                          : () => promote(configuration),
                      child: const Text('Usar en simulación oficial'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      const Text(
        'El análisis por sí solo no emite una orden ni sustituye la autorización del jefe de compras.',
      ),
    ],
  );
}
