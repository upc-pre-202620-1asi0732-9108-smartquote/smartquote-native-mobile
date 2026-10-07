import 'package:flutter/material.dart' hide Simulation;

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../../supply_requests/domain/purchase_request.dart';
import '../../evaluation_simulation/domain/evaluation.dart';
import '../../shared/presentation/form_dialog.dart';
import '../domain/purchase_order.dart';
import '../domain/corporate_profile.dart';
import 'management_page.dart';

class OrderPanel extends StatefulWidget {
  const OrderPanel({
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
  State<OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends OperationState<OrderPanel> {
  PurchaseOrder? order;
  List<Simulation> runs = [];
  Simulation? run;
  String? choice;
  List<JsonObject> audit = [];
  JsonObject? deliveryEvaluation;
  final names = <String, String>{};
  CorporateProfile? corporate;
  @override
  void initState() {
    super.initState();
    if (widget.active) load();
  }

  @override
  void didUpdateWidget(OrderPanel old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) load();
  }

  Future<void> fetch() async {
    order = await widget.services.orders.byRequest(widget.request.id);
    runs = await widget.services.evaluations.history(widget.request.id);
    final selectedId = run?.id;
    run =
        runs.where((r) => r.id == selectedId).firstOrNull ??
        runs.where((r) => r.current).firstOrNull ??
        runs.firstOrNull;
    if (run != null) {
      run = await widget.services.evaluations.getSimulation(run!.id);
    }
    names.clear();
    for (final q in await widget.services.quotations.list(widget.request.id)) {
      names[q.id] = textOf(q.data, 'supplierBusinessName');
    }
    chooseDefault();
    if (order != null && widget.services.auth.session!.manager) {
      audit = await widget.services.orders.audit('PurchaseOrder', order!.id);
    }
  }

  void chooseDefault() {
    final eligible =
        run?.evaluations
            .where((e) => e['isEligible'] == true)
            .map((e) => textOf(e, 'quotationId'))
            .toList() ??
        [];
    if (!eligible.contains(choice)) {
      choice =
          eligible.contains(textOf(run?.recommendation ?? {}, 'quotationId'))
          ? textOf(run!.recommendation!, 'quotationId')
          : eligible.firstOrNull;
    }
  }

  Future<void> load() async {
    await perform(fetch);
  }

  Future<void> approval() async {
    if (run == null || choice == null) return;
    final result = await dataDialog(
      context,
      'Autorizar a ${names[choice] ?? choice}',
      [
        ('deliveryConditions', 'Condiciones de entrega', ''),
        ('deliveryDestination', 'Destino / granja', ''),
      ],
    );
    if (result == null) return;
    widget.onBusy(true);
    final done = await perform(() async {
      order = await widget.services.ordering.approve(
        run!.id,
        choice!,
        result['deliveryConditions']!,
        result['deliveryDestination']!,
      );
      await fetch();
      return true;
    });
    widget.onBusy(false);
    if (done == true) {
      notice(
        'Orden aprobada y emitida. No se genera otra al repetir la misma decisión.',
      );
      await widget.onChanged();
    }
  }

  Future<void> export() async {
    final result = await dataDialog(
      context,
      'Datos corporativos para la orden',
      [
        (
          'name',
          'Razón social de la empresa compradora',
          corporate?.name ?? const String.fromEnvironment('PURCHASER_NAME'),
        ),
        (
          'taxId',
          'RUC de la empresa compradora (11 dígitos)',
          corporate?.taxId ?? const String.fromEnvironment('PURCHASER_RUC'),
        ),
        (
          'address',
          'Dirección corporativa',
          corporate?.address ??
              const String.fromEnvironment('PURCHASER_ADDRESS'),
        ),
      ],
    );
    if (result == null) return;
    await perform(() async {
      corporate = CorporateProfile(
        name: result['name']!,
        taxId: result['taxId']!,
        address: result['address']!,
      );
      await widget.services.ordering.export(order!.id, corporate!);
    });
  }

  Future<void> delivered() async {
    if (!await confirmAction(
      context,
      'Registrar entrega concluida',
      'Confirma únicamente si el proveedor ya entregó los insumos de esta orden.',
    )) {
      return;
    }
    widget.onBusy(true);
    await perform(() async {
      order = await widget.services.orders.delivered(order!.id);
      await fetch();
    });
    widget.onBusy(false);
    await widget.onChanged();
  }

  Future<void> evaluate() async {
    var onTime = 5, quality = 5;
    var observations = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Evaluar entrega del proveedor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escala de 1 (deficiente) a 5 (excelente).'),
                DropdownButtonFormField<int>(
                  initialValue: onTime,
                  decoration: fieldDecoration('Cumplimiento del plazo'),
                  items: List.generate(
                    5,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                  ),
                  onChanged: (v) => update(() => onTime = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: quality,
                  decoration: fieldDecoration('Calidad de los insumos'),
                  items: List.generate(
                    5,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                  ),
                  onChanged: (v) => update(() => quality = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => observations = v,
                  maxLength: PurchaseOrder.maximumObservationsLength,
                  maxLines: 3,
                  decoration: fieldDecoration('Observaciones (opcional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Registrar evaluación'),
            ),
          ],
        ),
      ),
    );
    final notes = observations;
    if (accepted != true) return;
    await perform(() async {
      deliveryEvaluation = await widget.services.orders.evaluate(
        order!.id,
        onTime,
        quality,
        notes,
      );
      notice('Evaluación registrada y asociada con esta orden.');
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
          const Expanded(child: Text('Decisión y orden de compra')),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (order == null && run == null && !busy)
        const Text(
          'Primero ejecuta una simulación. La orden se recupera desde la solicitud, sin guardar enlaces manualmente.',
        ),
      if (run != null && order == null)
        InfoCard(
          title: 'Decisión de compra',
          children: [
            if (widget.pendingCriteria)
              const Text(
                'Hay criterios sin guardar. Regresa a Simulación, guarda y simula antes de aprobar.',
              ),
            DropdownButtonFormField<String>(
              key: ValueKey(run!.id),
              initialValue: run!.id,
              isExpanded: true,
              decoration: fieldDecoration('Simulación'),
              items: runs
                  .map(
                    (r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(
                        '${shortId(r.id)} · v${r.data['criteriaVersion']} · ${r.current ? 'Vigente' : 'Histórica'}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (id) async {
                      await perform(() async {
                        run = await widget.services.evaluations.getSimulation(
                          id!,
                        );
                        choice = null;
                        chooseDefault();
                      });
                    },
            ),
            const SizedBox(height: 12),
            if (run!.evaluations.any((e) => e['isEligible'] == true))
              DropdownButtonFormField<String>(
                key: ValueKey('choice-${run!.id}-$choice'),
                initialValue: choice,
                isExpanded: true,
                decoration: fieldDecoration('Oferta elegible seleccionada'),
                items: run!.evaluations
                    .where((e) => e['isEligible'] == true)
                    .map(
                      (e) => DropdownMenuItem(
                        value: textOf(e, 'quotationId'),
                        child: Text(
                          '${names[textOf(e, 'quotationId')] ?? shortId(textOf(e, 'quotationId'))} · ${money(e['comparisonTotal'] as num?, textOf(e, 'comparisonCurrency'))}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => choice = v),
              ),
            if (!run!.current)
              const Text(
                'Resultado histórico: debe ejecutarse una simulación vigente.',
              ),
            if (widget.services.auth.session!.manager)
              FilledButton(
                onPressed:
                    busy ||
                        widget.pendingCriteria ||
                        !run!.current ||
                        choice == null ||
                        widget.request.status != 'Evaluation'
                    ? null
                    : approval,
                child: const Text('Aprobar y emitir orden'),
              ),
            if (!widget.services.auth.session!.manager)
              const Text(
                'La aprobación y emisión corresponden al jefe de compras.',
              ),
          ],
        ),
      if (order != null) orderCard(order!),
      if (deliveryEvaluation != null)
        InfoCard(
          title: 'Evaluación registrada',
          children: [
            Text(
              'Plazo: ${deliveryEvaluation!['onTimeScore']} / 5 · Calidad: ${deliveryEvaluation!['qualityScore']} / 5',
            ),
            Text(textOf(deliveryEvaluation!, 'observations')),
            Text(
              'Autor: ${deliveryEvaluation!['evaluatedBy']} · ${dateLabel(textOf(deliveryEvaluation!, 'evaluatedAt'), time: true)}',
            ),
          ],
        ),
    ],
  );
  Widget orderCard(PurchaseOrder current) => InfoCard(
    title: textOf(current.data, 'orderNumber'),
    children: [
      StatusChip(current.status),
      Text(
        'Proveedor: ${current.data['supplierBusinessName']} · RUC ${current.data['supplierTaxIdentifier']}',
      ),
      Text(
        'Total original: ${money(current.data['total'] as num?, textOf(current.data, 'currency'))}',
      ),
      Text(
        'Entrega: ${current.data['deliveryLeadTimeDays']} días · Destino: ${current.data['deliveryDestination']}',
      ),
      Text('Condiciones: ${current.data['deliveryConditions']}'),
      Text(
        'Aprobada: ${dateLabel(textOf(current.data, 'approvedAt'), time: true)} · ${current.data['approvedBy']}',
      ),
      for (final line in current.lines)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(textOf(line, 'description')),
          subtitle: Text(
            '${line['quantity']} ${textOf(line, 'unitOfMeasure')} × ${money(line['unitPrice'] as num?, textOf(current.data, 'currency'))}',
          ),
        ),
      SelectableText(
        'Orden: ${current.id}\nSolicitud: ${current.data['purchaseRequestId']}\nSimulación: ${current.data['simulationRunId']}\nCotización: ${current.data['quotationId']}',
      ),
      if (widget.services.auth.session!.manager)
        OutlinedButton.icon(
          onPressed: busy ? null : export,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar PDF corporativo'),
        ),
      if (current.status == 'Issued')
        FilledButton(
          onPressed: busy ? null : delivered,
          child: const Text('Registrar entrega concluida'),
        ),
      if (current.status == 'Delivered')
        FilledButton(
          onPressed: busy || deliveryEvaluation != null ? null : evaluate,
          child: const Text('Calificar entrega del proveedor'),
        ),
      TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Desempeño del proveedor')),
              body: ManagementPage(
                services: widget.services,
                initialTaxId: textOf(current.data, 'supplierTaxIdentifier'),
              ),
            ),
          ),
        ),
        child: const Text('Consultar desempeño histórico del proveedor'),
      ),
      if (widget.services.auth.session!.manager)
        ExpansionTile(
          title: const Text('Auditoría de la orden'),
          children: [
            for (final a in audit)
              ListTile(
                title: Text(textOf(a, 'action')),
                subtitle: Text(
                  '${textOf(a, 'reason')}\n${dateLabel(textOf(a, 'occurredAt'), time: true)} · ${a['actorId']}',
                ),
              ),
          ],
        ),
    ],
  );
}
