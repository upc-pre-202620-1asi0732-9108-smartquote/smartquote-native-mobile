import 'package:flutter/material.dart';

import 'services.dart';
import '../shared/domain/api_contract.dart';
import '../shared/infrastructure/file_selection.dart';
import '../shared/presentation/operation_state.dart';
import '../shared/presentation/ui.dart';
import '../shared/presentation/form_dialog.dart';
import '../supply_requests/domain/purchase_request.dart';
import '../quotation_intake/presentation/quotations_panel.dart';
import '../evaluation_simulation/presentation/simulation_panel.dart';
import '../purchase_ordering/presentation/order_panel.dart';

class RequestWorkspace extends StatefulWidget {
  const RequestWorkspace({
    super.key,
    required this.services,
    required this.requestId,
  });
  final Services services;
  final String requestId;
  @override
  State<RequestWorkspace> createState() => _RequestWorkspaceState();
}

class _RequestWorkspaceState extends OperationState<RequestWorkspace> {
  PurchaseRequest? request;
  List<JsonObject> history = [], audit = [];
  int tab = 0;
  bool working = false;
  bool pendingCriteria = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await perform(() async {
      request = await widget.services.requests.get(widget.requestId);
      history = await widget.services.requests.history(widget.requestId);
      if (widget.services.auth.session!.manager) {
        audit = await widget.services.orders.audit(
          'PurchaseRequest',
          widget.requestId,
        );
      }
    });
  }

  Future<void> reloadPreservingError() async {
    final previous = error;
    await load();
    if (previous != null && mounted) setState(() => error = previous);
  }

  void setWorking(bool value) {
    if (mounted) setState(() => working = value);
  }

  Future<void> changeStatus(String next) async {
    final reason = await inputReason(context, 'Cambiar a ${labelOf(next)}');
    if (reason == null) return;
    await perform(() async {
      final fresh = await widget.services.requests.get(widget.requestId);
      await widget.services.requests.changeStatus(fresh, next, reason);
    });
    await reloadPreservingError();
  }

  Future<void> startCollection() async {
    if (!await confirmAction(
      context,
      'Iniciar recepción',
      'Se registra la revisión y se habilita la recepción de cotizaciones.',
    )) {
      return;
    }
    await perform(() async {
      var fresh = await widget.services.requests.get(widget.requestId);
      if (fresh.status == 'Submitted') {
        await widget.services.requests.changeStatus(
          fresh,
          'UnderReview',
          'Solicitud revisada para recepción de cotizaciones.',
        );
        fresh = await widget.services.requests.get(widget.requestId);
      }
      if (fresh.status == 'UnderReview') {
        await widget.services.requests.changeStatus(
          fresh,
          'QuotationCollection',
          'Inicio de recepción de cotizaciones.',
        );
      }
    });
    await reloadPreservingError();
    if (mounted && request?.status == 'QuotationCollection') {
      setState(() => tab = 1);
    }
  }

  Future<void> attach() async {
    await perform(() async {
      final files = await selectFiles();
      if (files.isEmpty) return;
      final fresh = await widget.services.requests.get(widget.requestId);
      await widget.services.requests.attach(fresh, files.first);
      notice('Sustento adjuntado.');
    });
    await reloadPreservingError();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.services.auth.session!;
    final labels = [
      'Solicitud',
      if (session.purchasing) ...['Cotizaciones', 'Simulación', 'Orden'],
    ];
    return PopScope(
      canPop: !working && !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text('SOL-${shortId(widget.requestId)}'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: busy || working ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            if (busy || working) const LinearProgressIndicator(),
            ErrorNotice(error, onRetry: busy || working ? null : load),
            if (request != null) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(labels[i]),
                          selected: tab == i,
                          onSelected: busy || working
                              ? null
                              : (_) => setState(() => tab = i),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: tab,
                  children: [
                    detail(
                      session.purchasing,
                      session.production,
                      session.manager,
                    ),
                    if (session.purchasing) ...[
                      QuotationsPanel(
                        services: widget.services,
                        request: request!,
                        active: tab == 1,
                        onChanged: load,
                        onBusy: setWorking,
                      ),
                      SimulationPanel(
                        services: widget.services,
                        request: request!,
                        active: tab == 2,
                        onChanged: load,
                        onBusy: setWorking,
                        onDirty: (value) {
                          if (mounted) setState(() => pendingCriteria = value);
                        },
                      ),
                      OrderPanel(
                        services: widget.services,
                        request: request!,
                        active: tab == 3,
                        onChanged: load,
                        onBusy: setWorking,
                        pendingCriteria: pendingCriteria,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget detail(bool purchasing, bool production, bool manager) {
    final data = request!.data;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            title: 'Solicitud',
            children: [
              StatusChip(request!.status),
              Text(
                'Fecha requerida: ${dateLabel(textOf(data, 'requiredDate'))}',
              ),
              Text(
                'Prioridad: ${priorityLabels[textOf(data, 'priority')] ?? textOf(data, 'priority')}',
              ),
              Text('Área responsable: ${textOf(data, 'nextResponsibleArea')}'),
              SelectableText('Identificador: ${request!.id}'),
              Text(
                'Creada: ${dateLabel(textOf(data, 'createdAt'), time: true)}',
              ),
              if (purchasing &&
                  ['Submitted', 'UnderReview'].contains(request!.status))
                FilledButton(
                  onPressed: busy ? null : startCollection,
                  child: const Text('Iniciar recepción de cotizaciones'),
                ),
              if (purchasing)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final next
                        in requestTransitions[request!.status] ?? <String>[])
                      OutlinedButton(
                        onPressed: busy ? null : () => changeStatus(next),
                        child: Text('Pasar a ${labelOf(next)}'),
                      ),
                  ],
                ),
            ],
          ),
          for (final item in request!.items)
            InfoCard(
              title: textOf(item, 'description'),
              children: [
                Text(
                  'Cantidad: ${item['quantity']} ${textOf(item, 'unitOfMeasure')}',
                ),
                for (final r in objectsOf(item['requirements']))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${textOf(r, 'name')}: ${operatorLabels[textOf(r, 'operator')] ?? textOf(r, 'operator')} ${textOf(r, 'expectedValue')} ${textOf(r, 'unitOfMeasure')} · ${r['isMandatory'] == true ? 'obligatorio' : 'opcional'}',
                    ),
                  ),
              ],
            ),
          InfoCard(
            title: 'Adjuntos de sustento',
            children: [
              if (request!.attachments.isEmpty) const Text('Sin adjuntos.'),
              for (final a in request!.attachments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(textOf(a, 'fileName')),
                  subtitle: Text(
                    dateLabel(textOf(a, 'uploadedAt'), time: true),
                  ),
                ),
              if (production &&
                  textOf(data, 'requesterId') ==
                      textOf(widget.services.auth.session!.user, 'userId'))
                OutlinedButton.icon(
                  onPressed: busy ? null : attach,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Adjuntar PDF o imagen (hasta 10 MB)'),
                ),
            ],
          ),
          InfoCard(
            title: 'Historial de estados',
            children: [
              for (final h in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${labelOf(textOf(h, 'fromStatus'))} → ${labelOf(textOf(h, 'toStatus'))}',
                  ),
                  subtitle: Text(
                    '${textOf(h, 'reason')}\n${dateLabel(textOf(h, 'changedAt'), time: true)} · ${textOf(h, 'changedBy')}',
                  ),
                ),
              if (history.isEmpty) const Text('Sin cambios de estado.'),
            ],
          ),
          if (manager)
            InfoCard(
              title: 'Auditoría de la solicitud',
              children: [
                for (final a in audit)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(textOf(a, 'action')),
                    subtitle: Text(
                      '${textOf(a, 'reason')}\n${dateLabel(textOf(a, 'occurredAt'), time: true)} · ${textOf(a, 'actorId')}',
                    ),
                  ),
                if (audit.isEmpty)
                  const Text('No se registran eventos adicionales.'),
              ],
            ),
        ],
      ),
    );
  }
}

Future<String?> inputReason(BuildContext context, String title) async =>
    (await dataDialog(context, title, [('reason', 'Motivo', '')]))?['reason'];
