import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/request_workspace.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import 'new_request_page.dart';

class RecurringRequestsPage extends StatefulWidget {
  const RecurringRequestsPage({super.key, required this.services});
  final Services services;
  @override
  State<RecurringRequestsPage> createState() => _RecurringRequestsPageState();
}

class _RecurringRequestsPageState
    extends OperationState<RecurringRequestsPage> {
  List<JsonObject> schedules = [];
  int page = 1;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await perform(() async {
      schedules = await widget.services.workflows!.schedules(page: page);
    });
  }

  Future<void> pause(JsonObject schedule) async {
    if (!await confirmAction(
      context,
      'Suspender programación',
      'Se detiene la generación futura. Se conservan las solicitudes y ocurrencias anteriores.',
    )) {
      return;
    }
    final ok = await perform(() async {
      await widget.services.workflows!.pause(
        textOf(schedule, 'id'),
        integerOf(schedule, 'version'),
      );
      return true;
    });
    if (ok == true) await load();
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
          label: const Text('Actualizar programaciones'),
        ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<String>(
                      builder: (_) => NewRequestPage(
                        services: widget.services,
                        recurring: true,
                      ),
                    ),
                  );
                  if (mounted) await load();
                },
          icon: const Icon(Icons.event_repeat),
          label: const Text('Nueva programación'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'El servidor genera cada borrador una sola vez. Actualizar consulta su estado; no vuelve a generar solicitudes ni las envía.',
          ),
        ),
        if (!busy && schedules.isEmpty)
          const Text('No hay programaciones en esta página.'),
        for (final s in schedules)
          InfoCard(
            title: objectsOf(s['items'])
                .map((i) => textOf(i, 'description'))
                .join(' · '),
            children: [
              Text(s['isActive'] == true ? 'Activa' : 'Suspendida'),
              Text(
                'Cada ${s['intervalDays']} días · Fecha requerida: ${s['requiredDateOffsetDays']} días después de generar',
              ),
              Text('Zona: ${textOf(s, 'timeZoneId')}'),
              Text('Responsable: ${widget.services.auth.session!.name}'),
              Text('Creada: ${dateLabel(textOf(s, 'createdAt'), time: true)}'),
              for (final item in objectsOf(s['items'])) ...[
                Text(
                  '${textOf(item, 'description')} · ${item['quantity']} ${textOf(item, 'unitOfMeasure')}',
                ),
                for (final r in objectsOf(item['requirements']))
                  Text(
                    '${textOf(r, 'name')}: ${operatorLabels[textOf(r, 'operator')] ?? textOf(r, 'operator')} ${textOf(r, 'expectedValue')} ${textOf(r, 'unitOfMeasure')} · ${r['isMandatory'] == true ? 'obligatorio' : 'opcional'}',
                  ),
              ],
              Text(
                '${s['isActive'] == true ? 'Próxima generación' : 'Siguiente fecha registrada (suspendida)'}: ${dateLabel(textOf(s, 'nextOccurrenceDate'))}',
              ),
              if (s['pausedAt'] != null)
                Text(
                  'Suspendida: ${dateLabel(textOf(s, 'pausedAt'), time: true)}',
                ),
              if (s['isActive'] == true)
                OutlinedButton(
                  onPressed: busy ? null : () => pause(s),
                  child: const Text('Suspender programación'),
                ),
              const Text('Ocurrencias y solicitudes generadas'),
              if (objectsOf(s['occurrences']).isEmpty)
                const Text(
                  'Aún no hay ocurrencias procesadas. La API debe permanecer en ejecución.',
                ),
              for (final o in objectsOf(s['occurrences']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(dateLabel(textOf(o, 'scheduledDate'))),
                  subtitle: Text(
                    o['requestId'] == null
                        ? 'Ocurrencia omitida: fecha requerida vencida.'
                        : 'SOL-${shortId(textOf(o, 'requestId'))} · Abrir para revisar su estado actual',
                  ),
                  trailing: o['requestId'] == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: busy || o['requestId'] == null
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => RequestWorkspace(
                                services: widget.services,
                                requestId: textOf(o, 'requestId'),
                              ),
                            ),
                          );
                          if (mounted) await load();
                        },
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
              onPressed: busy || schedules.length < 20
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
