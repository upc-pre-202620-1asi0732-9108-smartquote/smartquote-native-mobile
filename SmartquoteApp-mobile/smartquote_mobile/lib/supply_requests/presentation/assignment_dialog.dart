import 'package:flutter/material.dart';

import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../domain/purchase_request.dart';

class AssignmentDialog extends StatefulWidget {
  const AssignmentDialog({
    super.key,
    required this.repository,
    required this.request,
  });

  final RequestRepository repository;
  final PurchaseRequest request;

  @override
  State<AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends OperationState<AssignmentDialog> {
  static const pageSize = 20;
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  List<JsonObject> analysts = [];
  String? selected;
  int page = 1;
  bool hasNext = false;
  bool get reassigning => widget.request.assignedAnalystId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    load(1);
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> load(int target) async {
    await perform(() async {
      final users = await widget.repository.activeAnalysts(
        page: target,
        pageSize: pageSize,
      );
      if (!mounted) return;
      setState(() {
        page = target;
        hasNext = users.length == pageSize;
        analysts = users
            .where(
              (user) =>
                  textOf(user, 'userId') != widget.request.assignedAnalystId,
            )
            .toList();
        selected = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(reassigning ? 'Reasignar solicitud' : 'Asignar solicitud'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) const LinearProgressIndicator(),
            ErrorNotice(error, onRetry: busy ? null : () => load(page)),
            if (!busy && error == null && analysts.isEmpty)
              const Text('No hay analistas disponibles en esta página.'),
            if (analysts.isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey(page),
                isExpanded: true,
                decoration: fieldDecoration('Analista activo'),
                items: [
                  for (final user in analysts)
                    DropdownMenuItem(
                      value: textOf(user, 'userId'),
                      child: Text(
                        '${textOf(user, 'displayName')} · ${textOf(user, 'email')}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => selected = value),
              ),
            if (page > 1 || hasNext)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Analistas anteriores',
                    onPressed: busy || page == 1 ? null : () => load(page - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Página $page'),
                  IconButton(
                    tooltip: 'Más analistas',
                    onPressed: busy || !hasNext ? null : () => load(page + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            if (reassigning)
              TextFormField(
                controller: reason,
                decoration: fieldDecoration('Motivo de la reasignación'),
                validator: requiredValue,
                maxLength: 2000,
                maxLines: 3,
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: busy || error != null || selected == null
            ? null
            : () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, (
                    selected!,
                    reassigning ? reason.text.trim() : null,
                  ));
                }
              },
        child: const Text('Confirmar'),
      ),
    ],
  );
}
