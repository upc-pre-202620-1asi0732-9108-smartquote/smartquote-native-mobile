import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/request_workspace.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../../shared/presentation/form_dialog.dart';
import '../domain/purchase_request.dart';

/// US15: origin-linked conversation; a response and a specification revision are separate commands.
class ClarificationsPanel extends StatefulWidget {
  const ClarificationsPanel({
    super.key,
    required this.services,
    this.requestId,
    this.onChanged,
  });
  final Services services;
  final String? requestId;
  final Future<void> Function()? onChanged;
  @override
  State<ClarificationsPanel> createState() => _ClarificationsPanelState();
}

class _ClarificationsPanelState extends OperationState<ClarificationsPanel> {
  List<JsonObject> entries = [], revisions = [];
  // Requests of the listed clarifications, to show item and requirement names.
  final requests = <String, PurchaseRequest>{};
  String get currentUserId =>
      textOf(widget.services.auth.session!.user, 'userId');
  int page = 1;
  bool get production => widget.services.auth.session!.production;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await perform(() async {
      entries = await widget.services.workflows!.clarifications(
        requestId: widget.requestId,
        page: page,
      );
      if (widget.requestId != null) {
        revisions = await widget.services.workflows!.revisions(
          widget.requestId!,
        );
      }
      for (final id in entries.map((c) => textOf(c, 'requestId')).toSet()) {
        if (requests.containsKey(id)) continue;
        try {
          requests[id] = await widget.services.requests.get(id);
        } on ApiFailure {
          // Without access to the request the origin stays generic.
        }
      }
    });
  }

  Future<void> command(Future<void> Function() action) async {
    final ok = await perform(() async {
      await action();
      return true;
    });
    if (ok == true) {
      await load();
      await widget.onChanged?.call();
    }
    // On 409 the text entered is not retried automatically against an unseen version.
  }

  Future<void> answer(JsonObject c) async {
    final value = await dataDialog(context, 'Responder aclaración', [
      ('answer', 'Interpretación técnica', ''),
    ]);
    if (value == null) return;
    await command(() async {
      await widget.services.workflows!.respond(
        textOf(c, 'id'),
        value['answer']!,
        integerOf(c, 'version'),
      );
    });
  }

  Future<void> revise(JsonObject c) async {
    final request = await perform(
      () => widget.services.requests.get(textOf(c, 'requestId')),
    );
    if (request == null || !mounted) return;
    final requirements = request.items
        .where((i) => textOf(i, 'itemId') == textOf(c, 'itemId'))
        .expand((i) => objectsOf(i['requirements']))
        .where((r) => textOf(r, 'requirementId') == textOf(c, 'requirementId'))
        .toList();
    if (requirements.isEmpty) {
      setState(
        () => error = const ApiFailure(
          'El requisito de origen ya no está disponible. Actualiza la solicitud.',
        ),
      );
      return;
    }
    final r = requirements.single;
    var operator = textOf(r, 'operator');
    var mandatory = r['isMandatory'] == true;
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: textOf(r, 'name'));
    final expected = TextEditingController(text: textOf(r, 'expectedValue'));
    final unit = TextEditingController(text: textOf(r, 'unitOfMeasure'));
    final reason = TextEditingController();
    final payload = await showDialog<JsonObject>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Confirmar nueva especificación'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'La respuesta no cambia el requisito por sí sola. Confirmar conserva el historial e invalida las evaluaciones anteriores afectadas.',
                  ),
                  TextFormField(
                    controller: name,
                    decoration: fieldDecoration('Nombre'),
                    validator: requiredValue,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: operator,
                    isExpanded: true,
                    items: operatorLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => update(() => operator = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: expected,
                    decoration: fieldDecoration('Valor esperado'),
                    validator: (v) =>
                        requiredValue(v) ??
                        ([
                                  'GreaterThanOrEqual',
                                  'LessThanOrEqual',
                                ].contains(operator) &&
                                double.tryParse(
                                      (v ?? '').replaceAll(',', '.'),
                                    ) ==
                                    null
                            ? 'Ingresa un valor numérico.'
                            : null),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: unit,
                    decoration: fieldDecoration('Unidad'),
                  ),
                  CheckboxListTile(
                    title: const Text('Obligatorio'),
                    value: mandatory,
                    onChanged: r['isMandatory'] == true
                        ? null
                        : (v) => update(() => mandatory = v!),
                  ),
                  TextFormField(
                    controller: reason,
                    decoration: fieldDecoration('Justificación del cambio'),
                    validator: requiredValue,
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
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, <String, dynamic>{
                    'specification': {
                      'name': name.text.trim(),
                      'operator': operator,
                      'expectedValue': expected.text.trim(),
                      'unitOfMeasure': unit.text.trim(),
                      'isMandatory': mandatory,
                    },
                    'reason': reason.text.trim(),
                    'expectedClarificationVersion': integerOf(c, 'version'),
                    'expectedRequestVersion': request.version,
                  });
                }
              },
              child: const Text('Confirmar cambio'),
            ),
          ],
        ),
      ),
    );
    // Controllers belong to the dialog route and are released after its closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in [name, expected, unit, reason]) {
      controller.dispose();
    }
    if (payload != null && mounted) {
      await command(
        () => widget.services.workflows!.revise(textOf(c, 'id'), payload),
      );
    }
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
          label: const Text('Actualizar aclaraciones'),
        ),
        const Text(
          'Aclaraciones técnicas · responder no modifica automáticamente los requisitos.',
        ),
        if (!busy && entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay aclaraciones en esta página.'),
          ),
        for (final c in entries)
          InfoCard(
            title: 'SOL-${shortId(textOf(c, 'requestId'))}',
            children: [
              StatusChip(textOf(c, 'status')),
              Text(origin(c)),
              Text('Consulta: ${textOf(c, 'question')}'),
              Text(
                'Autor: ${actorLabel(textOf(c, 'authorId'), currentUserId, 'Analista de compras')} · ${dateLabel(textOf(c, 'createdAt'), time: true)}',
              ),
              if (c['answer'] != null) ...[
                Text('Respuesta: ${textOf(c, 'answer')}'),
                Text(
                  'Responde: ${actorLabel(textOf(c, 'answeredBy'), currentUserId, 'Especialista solicitante')} · ${dateLabel(textOf(c, 'answeredAt'), time: true)}',
                ),
              ],
              if (production &&
                  textOf(c, 'specialistId') ==
                      textOf(widget.services.auth.session!.user, 'userId'))
                Wrap(
                  spacing: 8,
                  children: [
                    if (c['noticeReadAt'] == null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => command(
                                () => widget.services.workflows!.read(
                                  textOf(c, 'id'),
                                ),
                              ),
                        child: const Text('Marcar leída'),
                      ),
                    if (textOf(c, 'status') == 'Pending')
                      FilledButton(
                        onPressed: busy ? null : () => answer(c),
                        child: const Text('Responder'),
                      ),
                    if (textOf(c, 'status') == 'Answered')
                      OutlinedButton(
                        onPressed: busy ? null : () => revise(c),
                        child: const Text('Revisar especificación'),
                      ),
                  ],
                ),
              if (widget.requestId == null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => RequestWorkspace(
                                services: widget.services,
                                requestId: textOf(c, 'requestId'),
                              ),
                            ),
                          );
                          if (mounted) await load();
                        },
                  child: const Text('Ver solicitud y requisito'),
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
              onPressed: busy || entries.length < 20
                  ? null
                  : () {
                      page++;
                      load();
                    },
              child: const Text('Siguiente'),
            ),
          ],
        ),
        if (widget.requestId != null)
          InfoCard(
            title: 'Historial de especificaciones',
            children: [
              if (revisions.isEmpty) const Text('Sin revisiones técnicas.'),
              for (final r in revisions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Antes: ${specificationLabel(objectOf(r['previous']))}\nDespués: ${specificationLabel(objectOf(r['current']))}\n${textOf(r, 'reason')}\nAutor: ${actorLabel(textOf(r, 'changedBy'), currentUserId, 'Especialista solicitante')} · ${dateLabel(textOf(r, 'changedAt'), time: true)}',
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

extension on _ClarificationsPanelState {
  /// Item and requirement that originated the clarification.
  String origin(JsonObject c) {
    final request = requests[textOf(c, 'requestId')];
    final item = request?.items
        .where((i) => i['itemId'] == c['itemId'])
        .firstOrNull;
    final requirement = item == null
        ? null
        : objectsOf(item['requirements'])
              .where((r) => r['requirementId'] == c['requirementId'])
              .firstOrNull;
    if (item == null || requirement == null) {
      return 'Ítem y requisito de la solicitud SOL-${shortId(textOf(c, 'requestId'))}';
    }
    return 'Ítem: ${textOf(item, 'description')}\nRequisito: ${specificationLabel(requirement)}';
  }
}

String specificationLabel(JsonObject r) =>
    '${textOf(r, 'name')}: ${operatorLabels[textOf(r, 'operator')] ?? textOf(r, 'operator')} ${textOf(r, 'expectedValue')} ${textOf(r, 'unitOfMeasure')} · ${r['isMandatory'] == true ? 'obligatorio' : 'opcional'}';
