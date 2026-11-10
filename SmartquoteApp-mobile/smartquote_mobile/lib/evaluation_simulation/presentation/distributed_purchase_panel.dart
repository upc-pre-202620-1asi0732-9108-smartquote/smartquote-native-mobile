import 'package:flutter/material.dart' hide Simulation;

import '../../app/services.dart';
import '../../purchase_ordering/domain/purchase_order.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/form_dialog.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../../supply_requests/domain/purchase_request.dart';
import '../domain/evaluation.dart';

class DistributedPurchasePanel extends StatefulWidget {
  const DistributedPurchasePanel({
    super.key,
    required this.services,
    required this.request,
    required this.active,
    required this.pendingCriteria,
    required this.onBusy,
    required this.onChanged,
  });

  final Services services;
  final PurchaseRequest request;
  final bool active, pendingCriteria;
  final void Function(bool) onBusy;
  final Future<void> Function() onChanged;

  @override
  State<DistributedPurchasePanel> createState() =>
      _DistributedPurchasePanelState();
}

class _DistributedPurchasePanelState
    extends OperationState<DistributedPurchasePanel> {
  Simulation? run;
  PurchaseAward? award;
  JsonObject? budget, pendingApproval;
  bool get manager => widget.services.auth.session!.manager;
  bool get canSimulate =>
      widget.request.status == 'Evaluation' &&
      widget.request.items.length > 1 &&
      !widget.pendingCriteria &&
      award == null &&
      pendingApproval == null;

  @override
  void initState() {
    super.initState();
    if (widget.active) load();
  }

  @override
  void didUpdateWidget(DistributedPurchasePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) load();
  }

  Future<void> load() async {
    await perform(() async {
      award = await widget.services.orders.awardByRequest(widget.request.id);
      if (award != null) {
        pendingApproval = null;
        return;
      }
      // Keep the original payload and run available if the last response was lost.
      if (pendingApproval != null) return;
      final history = await widget.services.evaluations.history(
        widget.request.id,
      );
      final distributed = history.where((result) => result.distributed);
      final selected =
          distributed.where((result) => result.current).firstOrNull ??
          distributed.firstOrNull;
      run = selected == null
          ? null
          : await widget.services.evaluations.getSimulation(selected.id);
      await checkBudget();
    });
  }

  Future<void> checkBudget() async {
    budget = null;
    final current = run;
    if (manager &&
        current != null &&
        current.current &&
        current.distribution['canApprove'] == true) {
      budget = await widget.services.orders.distributedBudget(current.id);
    }
  }

  Future<void> simulate() async {
    widget.onBusy(true);
    await perform(() async {
      final repository = widget.services.evaluations;
      final scenario = await repository.current(widget.request.id);
      if (scenario == null) {
        throw const ApiFailure(
          'Guarda los criterios en la pestaña Simulación antes de continuar.',
        );
      }
      run = await repository.simulateDistributed(scenario.id);
      await checkBudget();
    });
    widget.onBusy(false);
  }

  Future<void> confirmApproval() async {
    final check = budget!;
    final assessment = objectOf(check['assessment']);
    final delivery = await dataDialog(context, 'Aprobar compra distribuida', [
      ('deliveryConditions', 'Condiciones de entrega', ''),
      ('deliveryDestination', 'Destino / granja', ''),
    ]);
    if (delivery == null || !mounted) return;
    await approve({
      ...delivery,
      'expectedBudgetVersion': integerOf(assessment, 'budgetVersion'),
      'expectedInputFingerprint': textOf(check, 'inputFingerprint'),
    });
  }

  Future<void> approve(JsonObject decision) async {
    widget.onBusy(true);
    final approved = await perform(() async {
      final orders = widget.services.orders;
      try {
        award = pendingApproval == null
            ? null
            : await orders.awardByRequest(widget.request.id);
        award ??= await orders.approveDistributed(run!.id, decision);
        pendingApproval = null;
        return true;
      } on ApiFailure catch (failure) {
        if (failure.status == 0 || failure.status >= 500) {
          pendingApproval = decision;
        } else {
          pendingApproval = null;
          budget = null;
        }
        rethrow;
      }
    });
    widget.onBusy(false);
    if (approved == true && mounted) await widget.onChanged();
  }

  String itemName(String id) {
    final item = widget.request.items
        .where((item) => item['itemId'] == id)
        .firstOrNull;
    return item == null ? id : textOf(item, 'description');
  }

  @override
  Widget build(BuildContext context) {
    final result = run?.distribution ?? <String, dynamic>{};
    final assessment = objectOf(budget?['assessment'] ?? {});
    final confirmed = award;
    final canApprove =
        manager &&
        canSimulate &&
        run?.current == true &&
        result['canApprove'] == true &&
        assessment['canApprove'] == true &&
        textOf(budget ?? {}, 'inputFingerprint').isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        ErrorNotice(error, onRetry: busy ? null : load),
        if (confirmed == null) ...[
          const Text(
            'La simulación asigna cada ítem completo a un proveedor. Usa los criterios guardados en Simulación.',
          ),
          FilledButton(
            onPressed: busy || !canSimulate ? null : simulate,
            child: const Text('Simular compra distribuida'),
          ),
          if (widget.pendingCriteria)
            const Text(
              'Guarda los cambios de criterios antes de simular o aprobar.',
            ),
          if (result.isNotEmpty)
            InfoCard(
              title: 'Distribución por ítem',
              children: [
                if (run?.current != true) const Text('Resultado histórico.'),
                for (final allocation in objectsOf(result['allocations']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      itemName(textOf(allocation, 'requestedItemId')),
                    ),
                    subtitle: Text(
                      '${textOf(allocation, 'supplierBusinessName')} · Cotización ${shortId(textOf(allocation, 'quotationId'))}\n'
                      '${textOf(allocation, 'quantity')} ${textOf(allocation, 'unitOfMeasure')} · ${money(allocation['amountPen'] as num?, 'PEN')} · '
                      '${(numberOf(allocation, 'score') * 100).toStringAsFixed(2)} puntos',
                    ),
                  ),
                for (final id in (result['uncoveredItemIds'] as List? ?? []))
                  Text('Sin cobertura: ${itemName(id.toString())}'),
                for (final candidate in objectsOf(
                  result['candidates'],
                ).where((candidate) => candidate['isEligible'] != true))
                  Text(
                    '${itemName(textOf(candidate, 'itemId'))} · Cotización ${shortId(textOf(candidate, 'quotationId'))} excluida\n'
                    '${(candidate['exclusions'] as List? ?? []).map((reason) => friendlyExplanation(reason.toString())).join('\n')}',
                  ),
                Text('Total: ${money(result['totalPen'] as num?, 'PEN')}'),
              ],
            ),
          if (assessment.isNotEmpty)
            InfoCard(
              title: 'Presupuesto global',
              children: [
                Text(
                  assessment['status'] == 'NotConfigured'
                      ? 'Sin presupuesto configurado'
                      : 'Límite: ${money(assessment['budgetAmountPen'] as num?, 'PEN')}',
                ),
                if (assessment['excessPen'] != null)
                  Text(
                    'Exceso: ${money(assessment['excessPen'] as num?, 'PEN')}',
                  ),
                if (assessment['marginPen'] != null)
                  Text(
                    'Margen: ${money(assessment['marginPen'] as num?, 'PEN')}',
                  ),
              ],
            ),
          if (manager && result.isNotEmpty)
            FilledButton(
              onPressed: busy || !canApprove ? null : confirmApproval,
              child: const Text('Aprobar y emitir órdenes'),
            ),
          if (manager && pendingApproval != null)
            OutlinedButton(
              onPressed: busy ? null : () => approve(pendingApproval!),
              child: const Text('Comprobar o reintentar la aprobación'),
            ),
        ] else if (confirmed.distributed)
          InfoCard(
            title: 'Órdenes de la adjudicación',
            children: [
              Text(
                'Total adjudicado: ${money(confirmed.summary['totalPen'] as num?, 'PEN')}',
              ),
              for (final order in confirmed.orders)
                ListTile(
                  title: Text(textOf(order.data, 'supplierBusinessName')),
                  subtitle: Text(
                    '${textOf(order.data, 'orderNumber')} · ${money(order.data['total'] as num?, textOf(order.data, 'currency'))}',
                  ),
                ),
            ],
          )
        else
          const Text(
            'Esta solicitud ya se adjudicó mediante una compra de proveedor único.',
          ),
      ],
    );
  }
}
