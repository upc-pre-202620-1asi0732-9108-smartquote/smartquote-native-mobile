import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/notification_viewmodel.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationViewModel>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotificationViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => viewModel.fetchNotifications(),
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          )
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: viewModel.notifications.length,
              itemBuilder: (context, index) {
                final notif = viewModel.notifications[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(Icons.notifications_outlined, color: Colors.grey),
                    title: Text('Solicitud ${notif.purchaseRequestId.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildStatusChip(notif.newStatus ?? ''),
                        const SizedBox(height: 8),
                        Text(DateFormat('d MMM yyyy, h:mm a').format(notif.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    trailing: TextButton(
                      onPressed: () => viewModel.markAsRead(notif.notificationId),
                      child: const Text('Marcar como leída'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor = Colors.orange.shade100;
    Color textColor = Colors.orange.shade800;

    if (status.toLowerCase().contains('aprobada') || status.toLowerCase().contains('emitida')) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    }

    return Chip(
      label: Text(status, style: TextStyle(color: textColor, fontSize: 12)),
      backgroundColor: bgColor,
      side: BorderSide.none,
    );
  }
}