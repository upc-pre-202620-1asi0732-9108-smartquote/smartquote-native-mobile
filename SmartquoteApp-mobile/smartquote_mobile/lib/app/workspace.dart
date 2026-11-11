import 'package:flutter/material.dart';

import 'services.dart';
import '../supply_requests/presentation/clarifications_panel.dart';
import '../supply_requests/presentation/recurring_requests_page.dart';
import '../quotation_intake/presentation/expiry_alerts_page.dart';
import '../identity_access/domain/session.dart';
import '../identity_access/presentation/pending_page.dart';
import '../supply_requests/presentation/request_list_page.dart';
import '../supply_requests/presentation/notifications_page.dart';
import '../purchase_ordering/presentation/management_page.dart';
import '../purchase_ordering/presentation/supplier_eligibility_page.dart';

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.services});
  final Services services;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final session = widget.services.auth.session!;
    final destinations = <(String, IconData, Widget)>[
      (
        'Solicitudes',
        Icons.inventory_2_outlined,
        RequestListPage(services: widget.services),
      ),
      if (session.production)
        (
          'Notificaciones',
          Icons.notifications_outlined,
          NotificationsPage(services: widget.services),
        ),
      if (session.production && widget.services.workflows != null) ...[
        (
          'Aclaraciones',
          Icons.question_answer_outlined,
          ClarificationsPanel(services: widget.services),
        ),
        (
          'Programaciones',
          Icons.event_repeat,
          RecurringRequestsPage(services: widget.services),
        ),
      ],
      if (session.has('PurchaseAnalyst') &&
          widget.services.expiryAlerts != null)
        (
          'Vencimientos',
          Icons.notification_important_outlined,
          ExpiryAlertsPage(services: widget.services),
        ),
      if (session.purchasing)
        (
          'Proveedores',
          Icons.local_shipping_outlined,
          ManagementPage(services: widget.services),
        ),
      if (session.purchasing && widget.services.policies != null)
        (
          'Habilitación',
          Icons.verified_outlined,
          SupplierEligibilityPage(services: widget.services),
        ),
      if (session.manager) ...[
        (
          'Métricas',
          Icons.analytics_outlined,
          ManagementPage(services: widget.services, metrics: true),
        ),
        (
          'Cuentas',
          Icons.manage_accounts_outlined,
          PendingPage(services: widget.services),
        ),
      ],
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('SmartQuote · ${destinations[selected].$1}'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              try {
                await widget.services.auth.logout();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sesión local cerrada. No se pudo confirmar la revocación en el servidor.',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.assignedRoles
                          .map((r) => roles[r] ?? r)
                          .join(', '),
                    ),
                    const SizedBox(height: 8),
                    Text(session.user['email']?.toString() ?? ''),
                  ],
                ),
              ),
              for (var i = 0; i < destinations.length; i++)
                ListTile(
                  selected: i == selected,
                  leading: Icon(destinations[i].$2),
                  title: Text(destinations[i].$1),
                  onTap: () {
                    setState(() => selected = i);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
      body: destinations[selected].$3,
    );
  }
}
