import 'package:flutter/material.dart';

import 'services.dart';
import '../supply_requests/presentation/assignment_dialog.dart';
import '../supply_requests/presentation/clarifications_panel.dart';
import '../supply_requests/presentation/new_request_page.dart';
import '../shared/domain/api_contract.dart';
import '../shared/infrastructure/file_selection.dart';
import '../shared/presentation/operation_state.dart';
import '../shared/presentation/ui.dart';
import '../shared/presentation/form_dialog.dart';
import '../supply_requests/domain/purchase_request.dart';
import '../quotation_intake/presentation/quotations_panel.dart';
import '../evaluation_simulation/presentation/simulation_panel.dart';
import '../evaluation_simulation/presentation/distributed_purchase_panel.dart';
import '../purchase_ordering/presentation/order_panel.dart';
import '../evaluation_simulation/presentation/sensitivity_panel.dart';

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
  // US22: analyst names for display; only managers can read the directory.
  final analystNames = <String, String>{};
  int tab = 0;
  int clarificationRefresh = 0;
  bool working = false;
  bool pendingCriteria = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  String get currentUserId =>
      textOf(widget.services.auth.session!.user, 'userId');
  String analystName(String id) => id == currentUserId
      ? 'Tú'
      : analystNames[id] ?? 'Analista de compras (${shortId(id)})';

  Future<void> load() async {
    await perform(() async {
      request = await widget.services.requests.get(widget.requestId);
      history = await widget.services.requests.history(widget.requestId);
      if (widget.services.auth.session!.manager && analystNames.isEmpty) {
        try {
          for (final user in await widget.services.requests.activeAnalysts(
            page: 1,
            pageSize: 100,
          )) {
            analystNames[textOf(user, 'userId')] = textOf(user, 'displayName');
          }
        } on ApiFailure {
          // Names are optional; the role label is shown instead.
        }
      }
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

  Future<void> ask(JsonObject item, JsonObject requirement) async {
    final values = await dataDialog(
      context,
      'Aclarar ${textOf(requirement, 'name')}',
      [('question', 'Consulta al especialista solicitante', '')],
    );
    if (values == null) return;
    final ok = await perform(() async {
      await widget.services.workflows!.ask(widget.requestId, {
        'itemId': textOf(item, 'itemId'),
        'requirementId': textOf(requirement, 'requirementId'),
        'specialistId': textOf(request!.data, 'requesterId'),
        'question': values['question'],
        'expectedVersion': request!.version,
      });
      return true;
    });
    if (ok == true && mounted) {
      setState(() => clarificationRefresh++);
      notice('Consulta enviada al especialista que creó la solicitud.');
      await load();
    }
  }

  Future<void> submitDraft() async {
    if (!await confirmAction(
      context,
      'Enviar solicitud revisada',
      'Confirma que los ítems, requisitos y fecha requerida son correctos. El borrador se enviará a adquisiciones.',
    )) {
      return;
    }
    await perform(
      () => widget.services.workflows!.submitDraft(
        widget.requestId,
        request!.version,
      ),
    );
    await reloadPreservingError();
  }

  Future<void> changeAssignment(PurchaseRequest current) async {
    final selection = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => AssignmentDialog(
        repository: widget.services.requests,
        request: current,
      ),
    );
    if (selection == null || !mounted) return;
    final updated = await perform(
      () => widget.services.requests.assignAnalyst(
        current,
        selection.$1,
        reason: selection.$2,
      ),
    );
    if (!mounted) return;
    if (updated == null) {
      await reloadPreservingError();
      return;
    }
    setState(() => request = updated);
    notice('Analista responsable actualizado.');
  }

  Future<void> showAssignmentHistory() async {
    final entries = widget.services.requests.assignmentHistory(
      widget.requestId,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Historial de asignaciones'),
        content: FutureBuilder<List<JsonObject>>(
          future: entries,
          builder: (context, snapshot) {
            if (snapshot.hasError) return ErrorNotice(snapshot.error);
            final history = snapshot.data;
            if (history == null) return const LinearProgressIndicator();
            if (history.isEmpty) {
              return const Text('Sin asignaciones registradas.');
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in history.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${dateLabel(textOf(entry, 'assignedAt'), time: true)}\n'
                        'Anterior: ${entry['previousAnalystId'] == null ? 'Sin asignar' : analystName(textOf(entry, 'previousAnalystId'))}\n'
                        'Analista: ${analystName(textOf(entry, 'analystId'))}\n'
                        'Registrado por: ${actorLabel(textOf(entry, 'assignedBy'), currentUserId, 'Jefe de compras')}'
                        '${entry['reason'] == null ? '' : '\nMotivo: ${textOf(entry, 'reason')}'}',
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.services.auth.session!;
    // US19: only the purchase manager analyzes sensitivity.
    final sensitivityTab =
        session.manager && widget.services.sensitivity != null;
    final labels = [
      'Solicitud',
      if (session.purchasing) ...[
        'Cotizaciones',
        'Simulación',
        'Orden',
        'Compra distribuida',
      ],
      if (sensitivityTab) 'Sensibilidad',
      if (widget.services.workflows != null) 'Aclaraciones',
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
                      DistributedPurchasePanel(
                        services: widget.services,
                        request: request!,
                        active: tab == 4,
                        pendingCriteria: pendingCriteria,
                        onBusy: setWorking,
                        onChanged: load,
                      ),
                    ],
                    if (sensitivityTab)
                      SensitivityPanel(
                        services: widget.services,
                        request: request!,
                        active: tab == 5,
                        pendingCriteria: pendingCriteria,
                        onBusy: setWorking,
                        onChanged: load,
                      ),
                    if (widget.services.workflows != null)
                      ClarificationsPanel(
                        key: ValueKey(
                          'clarifications-${request!.version}-$clarificationRefresh',
                        ),
                        services: widget.services,
                        requestId: widget.requestId,
                        onChanged: load,
                      ),
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
    final current = request!;
    final data = current.data;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            title: 'Solicitud',
            children: [
              StatusChip(request!.status),
              if (request!.status == 'Draft' &&
                  production &&
                  widget.services.workflows != null) ...[
                const Text(
                  'Borrador recurrente: privado y pendiente de revisión. Guardar cambios no lo envía a adquisiciones.',
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<String>(
                              builder: (_) => NewRequestPage(
                                services: widget.services,
                                existing: request,
                              ),
                            ),
                          );
                          if (mounted) await load();
                        },
                  child: const Text('Editar borrador'),
                ),
                FilledButton(
                  onPressed: busy ? null : submitDraft,
                  child: const Text('Confirmar y enviar solicitud'),
                ),
              ],
              Text(
                'Fecha requerida: ${dateLabel(textOf(data, 'requiredDate'))}',
              ),
              Text(
                'Prioridad: ${priorityLabels[textOf(data, 'priority')] ?? textOf(data, 'priority')}',
              ),
              Text(
                'Área responsable: ${areaOf(textOf(data, 'nextResponsibleArea'))}',
              ),
              if (purchasing)
                SelectableText(
                  current.assignedAnalystId.isEmpty
                      ? 'Sin analista asignado'
                      : 'Analista responsable: ${analystName(current.assignedAnalystId)}',
                ),
              if (purchasing)
                TextButton(
                  onPressed: busy || working ? null : showAssignmentHistory,
                  child: const Text('Ver historial de asignaciones'),
                ),
              if (manager && current.canBeAssigned)
                OutlinedButton(
                  onPressed: busy || working
                      ? null
                      : () => changeAssignment(current),
                  child: Text(
                    current.assignedAnalystId.isEmpty
                        ? 'Asignar analista'
                        : 'Reasignar analista',
                  ),
                ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${textOf(r, 'name')}: ${operatorLabels[textOf(r, 'operator')] ?? textOf(r, 'operator')} ${textOf(r, 'expectedValue')} ${textOf(r, 'unitOfMeasure')} · ${r['isMandatory'] == true ? 'obligatorio' : 'opcional'}',
                        ),
                        if (widget.services.workflows != null &&
                            widget.services.auth.session!.has(
                              'PurchaseAnalyst',
                            ) &&
                            ![
                              'Draft',
                              'Ordered',
                              'Rejected',
                              'Cancelled',
                            ].contains(request!.status))
                          TextButton.icon(
                            onPressed: busy ? null : () => ask(item, r),
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Solicitar aclaración'),
                          ),
                      ],
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
                    '${historyStatusLabel(textOf(h, 'fromStatus'), fromSchedule: data['scheduleOccurrenceId'] != null)} → ${historyStatusLabel(textOf(h, 'toStatus'), fromSchedule: data['scheduleOccurrenceId'] != null)}',
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
