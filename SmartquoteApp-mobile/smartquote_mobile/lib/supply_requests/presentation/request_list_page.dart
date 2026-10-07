import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/request_workspace.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../domain/purchase_request.dart';
import 'new_request_page.dart';

class RequestListPage extends StatefulWidget {
  const RequestListPage({super.key, required this.services});
  final Services services;
  @override
  State<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends OperationState<RequestListPage> {
  RequestPage? result;
  String filter = '';
  int page = 1;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await perform(() async {
      result = await widget.services.requests.list(status: filter, page: page);
    });
  }

  Future<void> detail(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RequestWorkspace(services: widget.services, requestId: id),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (widget.services.auth.session!.production)
          FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final id = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            NewRequestPage(services: widget.services),
                      ),
                    );
                    if (id != null && mounted) {
                      await detail(id);
                    } else if (mounted) {
                      await load();
                    }
                  },
            icon: const Icon(Icons.add),
            label: const Text('Nueva solicitud'),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: filter,
          isExpanded: true,
          decoration: fieldDecoration('Filtrar por estado'),
          items:
              [
                    '',
                    'Submitted',
                    'UnderReview',
                    'QuotationCollection',
                    'Evaluation',
                    'Approved',
                    'Ordered',
                    'Rejected',
                    'Cancelled',
                  ]
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.isEmpty ? 'Todos los estados' : labelOf(s)),
                    ),
                  )
                  .toList(),
          onChanged: busy
              ? null
              : (v) {
                  setState(() {
                    filter = v!;
                    page = 1;
                    result = null;
                  });
                  load();
                },
        ),
        ErrorNotice(error, onRetry: load),
        if (result != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('${result!.totalItems} solicitudes'),
          ),
          if (result!.items.isEmpty)
            const Text('No hay solicitudes en este estado.'),
          for (final request in result!.items)
            Card(
              child: ListTile(
                title: Text(
                  request.items
                      .map((i) => textOf(i, 'description'))
                      .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'SOL-${shortId(request.id)} · ${dateLabel(textOf(request.data, 'requiredDate'))}\n${labelOf(request.status)} · ${textOf(request.data, 'nextResponsibleArea')}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => detail(request.id),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Página anterior',
                onPressed: busy || page <= 1
                    ? null
                    : () {
                        page--;
                        load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Página $page de ${result!.totalPages == 0 ? 1 : result!.totalPages}',
              ),
              IconButton(
                tooltip: 'Página siguiente',
                onPressed: busy || page >= result!.totalPages
                    ? null
                    : () {
                        page++;
                        load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
