import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../domain/session.dart';

class PendingPage extends StatefulWidget {
  const PendingPage({super.key, required this.services});
  final Services services;
  @override
  State<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends OperationState<PendingPage> {
  List<JsonObject> entries = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await perform(() async {
      entries = await widget.services.auth.repository.pending();
    });
  }

  Future<void> approve(JsonObject entry) async {
    var role = textOf(entry, 'requestedRole');
    if (!roles.containsKey(role)) role = 'ProductionSpecialist';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Aprobar a ${textOf(entry, 'displayName')}'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            isExpanded: true,
            items: roles.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (value) => update(() => role = value!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aprobar'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await perform(() async {
        await widget.services.auth.repository.approve(
          textOf(entry, 'userId'),
          role,
        );
        entries = await widget.services.auth.repository.pending();
      });
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        ErrorNotice(error, onRetry: load),
        const Text('Registros pendientes de aprobación'),
        if (!busy && entries.isEmpty && error == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No hay cuentas pendientes.'),
          ),
        for (final entry in entries)
          Card(
            child: ListTile(
              title: Text(textOf(entry, 'displayName')),
              subtitle: Text(
                '${textOf(entry, 'email')}\n${roles[textOf(entry, 'requestedRole')] ?? textOf(entry, 'requestedRole')}',
              ),
              trailing: TextButton(
                onPressed: busy ? null : () => approve(entry),
                child: const Text('Aprobar'),
              ),
            ),
          ),
      ],
    ),
  );
}
