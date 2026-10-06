import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';

class ManagementPage extends StatefulWidget {
  const ManagementPage({
    super.key,
    required this.services,
    this.metrics = false,
    this.initialTaxId = '',
  });
  final Services services;
  final bool metrics;
  final String initialTaxId;
  @override
  State<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends OperationState<ManagementPage> {
  late final TextEditingController tax;
  DateTime from = DateTime.now().subtract(const Duration(days: 30)),
      to = DateTime.now();
  JsonObject? result;
  @override
  void initState() {
    super.initState();
    tax = TextEditingController(text: widget.initialTaxId);
    if (widget.initialTaxId.isNotEmpty) load();
  }

  @override
  void dispose() {
    tax.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!widget.metrics && !RegExp(r'^\d{11}$').hasMatch(tax.text.trim())) {
      setState(() => error = const ApiFailure('Ingresa un RUC de 11 dígitos.'));
      return;
    }
    if (widget.metrics && to.isBefore(from)) {
      setState(
        () => error = const ApiFailure(
          'La fecha final debe ser posterior o igual a la inicial.',
        ),
      );
      return;
    }
    await perform(() async {
      result = null;
      result = widget.metrics
          ? await widget.services.orders.metrics(
              from.toIso8601String().substring(0, 10),
              to.toIso8601String().substring(0, 10),
            )
          : await widget.services.orders.performance(tax.text.trim());
    });
  }

  Future<void> pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? from : to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() {
        if (start) {
          from = selected;
        } else {
          to = selected;
        }
        result = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (busy) const LinearProgressIndicator(),
      ErrorNotice(error, onRetry: load),
      if (widget.metrics) ...[
        const Text(
          'Indicadores del proceso de compras; el período se consulta en UTC.',
        ),
        ListTile(
          title: const Text('Desde'),
          subtitle: Text(dateLabel(from.toIso8601String())),
          onTap: busy ? null : () => pick(true),
        ),
        ListTile(
          title: const Text('Hasta'),
          subtitle: Text(dateLabel(to.toIso8601String())),
          onTap: busy ? null : () => pick(false),
        ),
      ] else ...[
        const Text(
          'Consulta el desempeño acumulado de un proveedor por su RUC.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: tax,
          keyboardType: TextInputType.number,
          maxLength: 11,
          decoration: fieldDecoration('RUC del proveedor'),
          onChanged: (_) => setState(() => result = null),
        ),
      ],
      FilledButton(
        onPressed: busy ? null : load,
        child: Text(
          widget.metrics ? 'Consultar métricas' : 'Consultar proveedor',
        ),
      ),
      if (result != null)
        widget.metrics ? metricsCard(result!) : performanceCard(result!),
    ],
  );
  Widget performanceCard(JsonObject r) => InfoCard(
    title: 'Resumen histórico · ${r['supplierTaxIdentifier']}',
    children: [
      Text('Evaluaciones registradas: ${r['evaluationCount']}'),
      Text('Promedio de plazo: ${score(r['averageOnTimeScore'])}'),
      Text('Promedio de calidad: ${score(r['averageQualityScore'])}'),
      Text('Promedio general: ${score(r['overallScore'])}'),
      Text(
        'Período observado: ${dateLabel(textOf(r, 'firstEvaluatedAt'))} — ${dateLabel(textOf(r, 'lastEvaluatedAt'))}',
      ),
      if (r['evaluationCount'] == 0)
        const Text(
          'El proveedor aún no tiene evaluaciones. No se interpreta como una calificación de cero.',
        ),
      if (r['evaluationCount'] != 0) ...[
        const SizedBox(height: 16),
        const Text('Historial de evaluaciones de entrega'),
        if (r['evaluations'] is! List)
          const Text(
            'Actualiza el backend para consultar las evaluaciones individuales.',
          )
        else
          for (final evaluation in objectsOf(r['evaluations']))
            ExpansionTile(
              key: ValueKey(textOf(evaluation, 'deliveryEvaluationId')),
              title: Text(
                dateLabel(textOf(evaluation, 'evaluatedAt'), time: true),
              ),
              subtitle: Text(
                'Plazo: ${score(evaluation['onTimeScore'])} · Calidad: ${score(evaluation['qualityScore'])}',
              ),
              children: [
                SelectableText(
                  'Orden: ${textOf(evaluation, 'purchaseOrderId')}',
                ),
                SelectableText('Autor: ${textOf(evaluation, 'evaluatedBy')}'),
                Text(
                  'Observaciones: ${textOf(evaluation, 'observations').isEmpty ? 'Sin observaciones' : textOf(evaluation, 'observations')}',
                ),
              ],
            ),
      ],
    ],
  );
  String score(dynamic value) =>
      value is num ? '${value.toStringAsFixed(2)} / 5' : 'No disponible';
  Widget metricsCard(JsonObject r) => InfoCard(
    title:
        'Métricas ${dateLabel(textOf(r, 'from'))} — ${dateLabel(textOf(r, 'to'))}',
    children: [
      Text(
        'Órdenes incluidas: ${r['orderCount']} · Estado: ${labelOf(textOf(r, 'orderStatus'))} · Zona: ${r['timeZone']}',
      ),
      Text(
        'Tiempo promedio: ${r['averageProcessingHours'] == null ? 'No disponible' : '${r['averageProcessingHours']} horas'}',
      ),
      Text('Muestra de tiempos: ${r['timeSampleCount']} órdenes'),
      Text(
        'Ahorro comparativo estimado: ${money(r['comparativeSavings'] as num?, textOf(r, 'savingsCurrency'))}',
      ),
      Text('Muestra de ahorro: ${r['savingsSampleCount']} órdenes'),
      const Text(
        'Es una comparación de ofertas elegibles, no un ahorro financiero realizado. El servidor excluye órdenes sin datos comparables.',
      ),
      ExpansionTile(
        title: const Text('Definiciones del servidor'),
        children: [
          Text(textOf(r, 'timeDefinition')),
          Text(textOf(r, 'savingsDefinition')),
        ],
      ),
    ],
  );
}
