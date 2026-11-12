import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/request_workspace.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import 'quotation_review_page.dart';

class ExpiryAlertsPage extends StatefulWidget {
  const ExpiryAlertsPage({super.key, required this.services});
  final Services services;
  @override
  State<ExpiryAlertsPage> createState() => _ExpiryAlertsPageState();
}

class _ExpiryAlertsPageState extends OperationState<ExpiryAlertsPage> {
  List<JsonObject> alerts = [];
  bool unread = false;
  int page = 1;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await perform(() async {
      alerts = await widget.services.expiryAlerts!.list(
        unreadOnly: unread,
        page: page,
      );
    });
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        ErrorNotice(error, onRetry: busy ? null : load),
        OutlinedButton.icon(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar alertas'),
        ),
        SwitchListTile(
          title: const Text('Solo no leídas'),
          value: unread,
          onChanged: busy
              ? null
              : (v) {
                  setState(() {
                    unread = v;
                    page = 1;
                  });
                  load();
                },
        ),
        const Text(
          'Alertas del servidor para tus solicitudes asignadas. El historial se conserva aunque la oferta venza o la solicitud termine; leer una alerta no prorroga la cotización.',
        ),
        if (!busy && alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay alertas para este filtro.'),
          ),
        for (final a in alerts)
          InfoCard(
            title: textOf(a, 'supplierName'),
            children: [
              Text(
                'SOL-${shortId(textOf(a, 'requestId'))} · Vence ${dateLabel(textOf(a, 'validUntil'))}',
              ),
              Text(
                'Anticipación: ${a['leadDays']} días · ${a['readAt'] == null ? 'No leída' : 'Leída'}',
              ),
              Text(
                'Registrada: ${dateLabel(textOf(a, 'createdAt'), time: true)}',
              ),
              if (a['readAt'] != null)
                Text('Leída: ${dateLabel(textOf(a, 'readAt'), time: true)}'),
              Wrap(
                spacing: 8,
                children: [
                  if (a['readAt'] == null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final ok = await perform(() async {
                                await widget.services.expiryAlerts!.read(
                                  textOf(a, 'id'),
                                );
                                return true;
                              });
                              if (ok == true) await load();
                            },
                      child: const Text('Marcar leída'),
                    ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => RequestWorkspace(
                                  services: widget.services,
                                  requestId: textOf(a, 'requestId'),
                                ),
                              ),
                            );
                            if (mounted) await load();
                          },
                    child: const Text('Ver solicitud'),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final request = await perform(
                              () => widget.services.requests.get(
                                textOf(a, 'requestId'),
                              ),
                            );
                            if (!context.mounted || request == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => QuotationReviewPage(
                                  services: widget.services,
                                  request: request,
                                  quotationId: textOf(a, 'quotationId'),
                                ),
                              ),
                            );
                            if (mounted) await load();
                          },
                    child: const Text('Ver vigencia actual'),
                  ),
                ],
              ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: busy || page == 1
                  ? null
                  : () {
                      page--;
                      load();
                    },
              child: const Text('Anterior'),
            ),
            Text('Página $page'),
            TextButton(
              onPressed: busy || alerts.length < 20
                  ? null
                  : () {
                      page++;
                      load();
                    },
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ],
    ),
  );
}
