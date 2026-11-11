import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/form_dialog.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../domain/ordering_policies.dart';

/// US18: the purchase manager enables, suspends or reactivates suppliers for
/// new purchases. Analysts can consult the catalogue and its history.
class SupplierEligibilityPage extends StatefulWidget {
  const SupplierEligibilityPage({super.key, required this.services});
  final Services services;
  @override
  State<SupplierEligibilityPage> createState() =>
      _SupplierEligibilityPageState();
}

class _SupplierEligibilityPageState
    extends OperationState<SupplierEligibilityPage> {
  static const filters = {
    null: 'Todos',
    'Pending': 'Pendientes',
    'Enabled': 'Habilitados',
    'Suspended': 'Suspendidos',
  };
  static const helps = {
    'enable': 'Solo los proveedores habilitados pueden recibir nuevas órdenes de compra.',
    'suspend': 'Las recomendaciones pendientes que incluyen a este proveedor requerirán una nueva evaluación. Las órdenes emitidas y los resultados históricos no se modifican.',
    'reactivate': 'La reactivación conserva el historial. No aprueba compras pendientes ni restablece evaluaciones anteriores: se debe simular nuevamente.',
  };
  String? status;
  List<SupplierAccount> suppliers = [];
  SupplierAccount? selected;

  OrderingPolicyRepository get policies => widget.services.policies!;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await perform(() async {
      suppliers = await policies.suppliers(status: status);
      if (selected != null) selected = await policies.supplier(selected!.id);
    });
  }

  Future<void> open(SupplierAccount supplier) async {
    await perform(() async => selected = await policies.supplier(supplier.id));
  }

  Future<void> decide(SupplierAccount supplier, String action) async {
    final label = SupplierAccount.actionLabels[action]!;
    final values = await dataDialog(context, '$label · ${supplier.name}', [
      ('reason', 'Motivo de la decisión', ''),
    ]);
    if (values == null) return;
    final done = await perform(() async {
      // The detail is read again so the decision carries the current version.
      final fresh = await policies.supplier(supplier.id);
      selected = await policies.decide(fresh, action, values['reason']!);
      suppliers = await policies.suppliers(status: status);
      return true;
    });
    if (done == true) {
      notice('Decisión registrada: ${labelOf(selected!.status)}.');
    } else if (mounted) {
      // A conflict means the supplier changed elsewhere: show its current state.
      final previous = error;
      await load();
      if (mounted && previous != null) setState(() => error = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.services.auth.session!.manager;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          ErrorNotice(error, onRetry: busy ? null : load),
          const Text(
            'Habilitación interna de proveedores para nuevas compras. No es una certificación externa ni una aprobación emitida por la IA.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in filters.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: status == entry.key,
                  onSelected: busy
                      ? null
                      : (_) {
                          setState(() {
                            status = entry.key;
                            selected = null;
                          });
                          load();
                        },
                ),
            ],
          ),
          if (suppliers.isEmpty && !busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No hay proveedores para este filtro.'),
            ),
          for (final supplier in suppliers)
            Card(
              child: ListTile(
                key: ValueKey('supplier-${supplier.id}'),
                selected: selected?.id == supplier.id,
                title: Text(supplier.name),
                subtitle: Text('RUC ${supplier.taxId}'),
                trailing: StatusChip(supplier.status),
                onTap: busy ? null : () => open(supplier),
              ),
            ),
          if (selected != null) detail(selected!, manager),
        ],
      ),
    );
  }

  Widget detail(SupplierAccount supplier, bool manager) {
    final action = supplier.nextAction;
    return InfoCard(
      title: supplier.name,
      children: [
        StatusChip(supplier.status),
        Text('RUC ${supplier.taxId} · versión ${supplier.version}'),
        Text(
          'Registrado: ${dateLabel(textOfData(supplier, 'createdAt'), time: true)}',
        ),
        if (action != null && manager) ...[
          const SizedBox(height: 8),
          Text(helps[action]!),
          FilledButton(
            onPressed: busy ? null : () => decide(supplier, action),
            child: Text(SupplierAccount.actionLabels[action]!),
          ),
        ],
        if (!manager)
          const Text(
            'Solo el jefe de compras puede cambiar la habilitación de proveedores.',
          ),
        const Divider(),
        const Text('Historial de decisiones'),
        if (supplier.history.isEmpty)
          const Text('Aún no se registran decisiones.'),
        for (final entry in supplier.history.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${labelOf('${entry['previousStatus']}')} → ${labelOf('${entry['newStatus']}')}',
            ),
            subtitle: Text(
              '${entry['reason']}\n${dateLabel('${entry['decidedAt']}', time: true)} · ${actorLabel('${entry['decidedBy']}', textOf(widget.services.auth.session!.user, 'userId'), 'Jefe de compras')} · versión ${entry['version']}',
            ),
          ),
      ],
    );
  }

  String textOfData(SupplierAccount supplier, String key) =>
      supplier.data[key]?.toString() ?? '';
}
