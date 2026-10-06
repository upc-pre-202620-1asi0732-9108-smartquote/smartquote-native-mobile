import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/request_workspace.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.services});
  final Services services;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends OperationState<NotificationsPage> {
  List<JsonObject> entries = [];
  bool unread = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await perform(() async {
      entries = await widget.services.requests.notifications(
        unreadOnly: unread,
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
        ErrorNotice(error, onRetry: load),
        SwitchListTile(
          title: const Text('Solo no leídas'),
          value: unread,
          onChanged: busy
              ? null
              : (v) {
                  unread = v;
                  load();
                },
        ),
        if (!busy && entries.isEmpty && error == null)
          const Text('No hay notificaciones.'),
        for (final entry in entries)
          Card(
            child: ListTile(
              leading: Icon(
                entry['readAt'] == null
                    ? Icons.mark_email_unread_outlined
                    : Icons.mark_email_read_outlined,
              ),
              title: Text(textOf(entry, 'message')),
              subtitle: Text(
                '${labelOf(textOf(entry, 'newStatus'))} · ${dateLabel(textOf(entry, 'createdAt'), time: true)}',
              ),
              onTap: busy
                  ? null
                  : () async {
                      final done = await perform(() async {
                        if (entry['readAt'] == null) {
                          await widget.services.requests.readNotification(
                            textOf(entry, 'notificationId'),
                          );
                        }
                        return true;
                      });
                      if (done == true && context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RequestWorkspace(
                              services: widget.services,
                              requestId: textOf(entry, 'purchaseRequestId'),
                            ),
                          ),
                        );
                        if (mounted) await load();
                      }
                    },
            ),
          ),
      ],
    ),
  );
}
