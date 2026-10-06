import 'package:flutter/material.dart' hide Simulation;

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../../supply_requests/domain/purchase_request.dart';
import '../domain/evaluation.dart';
import '../application/criteria_policy.dart';
import '../../shared/presentation/form_dialog.dart';

class SimulationPanel extends StatefulWidget {
  const SimulationPanel({
    super.key,
    required this.services,
    required this.request,
    required this.active,
    required this.onChanged,
    required this.onBusy,
    this.onDirty,
  });
  final Services services;
  final PurchaseRequest request;
  final bool active;
  final Future<void> Function() onChanged;
  final void Function(bool) onBusy;
  final void Function(bool)? onDirty;
  @override
  State<SimulationPanel> createState() => _SimulationPanelState();
}

class _SimulationPanelState extends OperationState<SimulationPanel> {
  EvaluationScenario? scenario;
  List<JsonObject> criteria = [];
  List<Simulation> runs = [];
  Simulation? selected;
  bool dirty = false;
  final supplierNames = <String, String>{};
  @override
  void initState() {
    super.initState();
    criteria = defaultCriteria(widget.request);
    if (widget.active) load();
  }

  void markDirty(bool value) {
    dirty = value;
    widget.onDirty?.call(value);
  }

  @override
  void didUpdateWidget(SimulationPanel old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) load();
  }

  Future<void> fetch({bool reset = false}) async {
    scenario = await widget.services.evaluations.current(widget.request.id);
    runs = await widget.services.evaluations.history(widget.request.id);
    final quotes = await widget.services.quotations.list(widget.request.id);
    supplierNames.clear();
    for (final q in quotes) {
      supplierNames[q.id] = textOf(q.data, 'supplierBusinessName');
    }
    if (reset || !dirty) {
      criteria = scenario == null
          ? defaultCriteria(widget.request)
          : criteriaPayload(scenario!.criteria);
    }
    if (selected != null) {
      selected = await widget.services.evaluations.getSimulation(selected!.id);
    } else if (runs.isNotEmpty) {
      selected = runs.first;
    }
  }

  Future<void> load() async {
    await perform(fetch);
  }

  Future<void> save({bool simulate = false}) async {
    final invalid = criteriaError(criteria, widget.request);
    if (invalid != null) {
      setState(() => error = ApiFailure(invalid));
      return;
    }
    widget.onBusy(true);
    await perform(() async {
      final fresh = await widget.services.evaluations.current(
        widget.request.id,
      );
      if (fresh?.id != scenario?.id) {
        throw const ApiFailure(
          'Los criterios cambiaron en otra sesión. Actualiza antes de guardar.',
          status: 409,
        );
      }
      if (scenario == null || dirty) {
        scenario = await widget.services.evaluations.save(
          widget.request.id,
          criteriaPayload(criteria),
          scenario,
        );
        markDirty(false);
      }
      if (simulate) {
        selected = await widget.services.evaluations.simulate(scenario!.id);
      }
      await fetch(reset: true);
      notice(
        simulate
            ? 'Simulación registrada.'
            : 'Criterios guardados. Las simulaciones anteriores se conservan.',
      );
    });
    widget.onBusy(false);
  }

  void weight(JsonObject criterion, double value) {
    setState(() {
      criterion['weight'] = value.round();
      markDirty(true);
      final others = criteria
          .where((c) => c['mode'] == 'Weighted' && c != criterion)
          .toList();
      if (others.length == 1) others.first['weight'] = 100 - value.round();
    });
  }

  Future<void> addTechnical() async {
    JsonObject? requirement;
    final available = widget.request.requirements
        .where(
          (r) => !criteria.any(
            (c) =>
                c['mode'] == 'Weighted' &&
                c['targetField'] == r['requirementId'],
          ),
        )
        .toList();
    if (available.isEmpty) {
      notice('Todos los requisitos ya tienen una ponderación técnica.');
      return;
    }
    var target = textOf(available.first, 'requirementId');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ponderar cumplimiento técnico'),
        content: DropdownButtonFormField<String>(
          initialValue: target,
          isExpanded: true,
          items: available
              .map(
                (r) => DropdownMenuItem(
                  value: textOf(r, 'requirementId'),
                  child: Text(
                    textOf(r, 'name'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => target = v!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    requirement = available.firstWhere((r) => r['requirementId'] == target);
    setState(() {
      criteria.add({
        'name': 'Cumplimiento: ${textOf(requirement!, 'name')}',
        'targetField': target,
        'category': 'TechnicalCompliance',
        'mode': 'Weighted',
        'operator': requirement['operator'],
        'expectedValue': requirement['expectedValue'],
        'unitOfMeasure': requirement['unitOfMeasure'],
        'weight': 0,
        'displayOrder': criteria.length + 1,
      });
      markDirty(true);
    });
  }

  Future<void> threshold(JsonObject criterion) async {
    final result = await dataDialog(
      context,
      'Umbral de ${textOf(criterion, 'name')}',
      [
        (
          'expectedValue',
          'Valor máximo aceptado',
          textOf(criterion, 'expectedValue'),
        ),
      ],
    );
    if (result == null || !mounted) return;
    final value = double.tryParse(
      result['expectedValue']!.replaceAll(',', '.'),
    );
    if (value == null || !value.isFinite || value < 0) {
      setState(
        () => error = const ApiFailure(
          'Ingresa un número válido mayor o igual a cero.',
        ),
      );
      return;
    }
    setState(() {
      criterion['expectedValue'] = value.toString();
      markDirty(true);
    });
  }

  Future<void> selectRun(String id) async {
    await perform(() async {
      selected = await widget.services.evaluations.getSimulation(id);
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (busy) const LinearProgressIndicator(),
      ErrorNotice(error, onRetry: load),
      Row(
        children: [
          Expanded(
            child: Text(
              scenario == null
                  ? 'Configurar evaluación'
                  : 'Criterios · versión ${scenario!.data['version']}',
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const Text(
        'Los requisitos obligatorios excluyen ofertas no conformes; los pesos ordenan las alternativas elegibles.',
      ),
      for (final c in criteria)
        InfoCard(
          title: textOf(c, 'name'),
          children: [
            Text(
              '${c['mode'] == 'Mandatory' ? 'Obligatorio' : 'Ponderado'} · ${operatorLabels[textOf(c, 'operator')] ?? textOf(c, 'operator')} ${textOf(c, 'expectedValue')} ${textOf(c, 'unitOfMeasure')}',
            ),
            if (c['mode'] == 'Weighted') ...[
              Text('Peso: ${numberOf(c, 'weight').toStringAsFixed(0)} %'),
              Slider(
                value: numberOf(c, 'weight').clamp(0, 100),
                min: 0,
                max: 100,
                divisions: 100,
                label: '${numberOf(c, 'weight').round()} %',
                onChanged: busy ? null : (v) => weight(c, v),
              ),
              if (c['category'] == 'Price' || c['category'] == 'DeliveryTime')
                TextButton(
                  onPressed: busy ? null : () => threshold(c),
                  child: const Text('Cambiar umbral'),
                ),
              if (c['category'] == 'TechnicalCompliance')
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          criteria.remove(c);
                          markDirty(true);
                        }),
                  child: const Text(
                    'Quitar ponderación (no elimina el requisito obligatorio)',
                  ),
                ),
            ],
          ],
        ),
      Text(
        'Total ponderado: ${criteria.where((c) => c['mode'] == 'Weighted').fold<double>(0, (sum, c) => sum + numberOf(c, 'weight')).toStringAsFixed(0)} %',
      ),
      TextButton.icon(
        onPressed: busy ? null : addTechnical,
        icon: const Icon(Icons.add),
        label: const Text('Agregar ponderación técnica'),
      ),
      OutlinedButton(
        onPressed: busy ? null : () => save(),
        child: const Text('Guardar criterios / nueva versión'),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: busy || widget.request.status != 'Evaluation'
            ? null
            : () => save(simulate: true),
        child: const Text('Guardar y simular'),
      ),
      if (widget.request.status != 'Evaluation')
        const Text(
          'La solicitud debe estar en evaluación y contar con al menos dos cotizaciones verificadas.',
        ),
      if (runs.isNotEmpty)
        InfoCard(
          title: 'Historial persistido de simulaciones',
          children: [
            for (final run in runs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                selected: selected?.id == run.id,
                title: Text(
                  'Simulación ${shortId(run.id)} · versión ${run.data['criteriaVersion']}',
                ),
                subtitle: Text(
                  '${dateLabel(textOf(run.data, 'executedAt'), time: true)} · ${run.current ? 'Vigente' : 'Histórica'}',
                ),
                onTap: busy ? null : () => selectRun(run.id),
              ),
          ],
        ),
      if (selected != null) resultCard(selected!),
    ],
  );
  Widget resultCard(Simulation run) => InfoCard(
    title: 'Resultado · ${shortId(run.id)}',
    children: [
      Text(
        run.current
            ? 'Resultado vigente'
            : 'Resultado histórico; no sirve para una nueva aprobación.',
      ),
      if (dirty)
        const Text(
          'Hay cambios de criterios sin guardar. Guarda y simula nuevamente antes de decidir.',
        ),
      Text(
        'Versión: ${run.data['criteriaVersion']} · ${dateLabel(textOf(run.data, 'executedAt'), time: true)}',
      ),
      SelectableText('Identificador: ${run.id}'),
      if (run.recommendation != null)
        Text(
          'Recomendación: ${supplierNames[textOf(run.recommendation!, 'quotationId')] ?? shortId(textOf(run.recommendation!, 'quotationId'))}\n${friendlyExplanation(textOf(run.recommendation!, 'explanation'))}',
        ),
      for (final evaluation
          in [...run.evaluations]..sort(
            (a, b) => (integerOf(a, 'rank') == 0 ? 999 : integerOf(a, 'rank'))
                .compareTo(
                  integerOf(b, 'rank') == 0 ? 999 : integerOf(b, 'rank'),
                ),
          ))
        Card(
          color: evaluation['isEligible'] == true
              ? const Color(0xffeaf4ef)
              : const Color(0xfffbe9e9),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  supplierNames[textOf(evaluation, 'quotationId')] ??
                      textOf(evaluation, 'quotationId'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  evaluation['isEligible'] == true
                      ? 'Puesto ${evaluation['rank']} · ${(numberOf(evaluation, 'totalScore') * 100).toStringAsFixed(2)} puntos / 100'
                      : 'Excluida por incumplimiento',
                ),
                Text(
                  'Importe original: ${money(evaluation['originalTotal'] as num?, textOf(evaluation, 'originalCurrency'))}',
                ),
                Text(
                  'Importe comparado: ${money(evaluation['comparisonTotal'] as num?, textOf(evaluation, 'comparisonCurrency'))}',
                ),
                for (final reason in objectsOf(evaluation['exclusionReasons']))
                  Text(friendlyExplanation(textOf(reason, 'explanation'))),
                ExpansionTile(
                  title: const Text('Ver cálculo por criterio'),
                  children: [
                    for (final c in objectsOf(evaluation['criterionResults']))
                      ListTile(
                        title: Text(
                          friendlyExplanation(textOf(c, 'explanation')),
                        ),
                        subtitle: Text(
                          'Normalizado: ${numberOf(c, 'normalizedScore').toStringAsFixed(3)} · Aporte: ${(numberOf(c, 'weightedContribution') * 100).toStringAsFixed(2)} puntos',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (run.exchangeRate != null) ...[
        const Divider(),
        const Text('Tipo de cambio informado por el backend'),
        Text(
          '${run.exchangeRate!['sourceCurrency']} → ${run.exchangeRate!['targetCurrency']}: ${run.exchangeRate!['rate']} · ${run.exchangeRate!['rateType']}',
        ),
        Text(
          'Fuente: ${run.exchangeRate!['source']} · Publicado: ${dateLabel(textOf(run.exchangeRate!, 'publishedOn'))}',
        ),
        Text(
          'Consulta: ${dateLabel(textOf(run.exchangeRate!, 'retrievedAt'), time: true)}',
        ),
      ],
      const SizedBox(height: 12),
      const Text(
        'El jefe de compras puede autorizar la alternativa elegible desde la pestaña Orden. La aprobación se valida nuevamente en el servidor.',
      ),
    ],
  );
}
