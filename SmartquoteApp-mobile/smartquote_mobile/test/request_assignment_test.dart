import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/app/request_workspace.dart';
import 'package:smartquote_mobile/identity_access/domain/session.dart';
import 'package:smartquote_mobile/supply_requests/presentation/request_list_page.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets(
    'US22 — reassignment requires a reason and sends the viewed version',
    (tester) async {
      final api = TestApi(role: 'PurchaseManager');
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      services.auth.session = Session.fromJson(sessionFixture(api.role));
      const currentAnalyst = 'analyst-current';
      const nextAnalyst = 'analyst-next';
      final requestPath = '/purchase-requests/$requestId';
      api.responses[requestPath] = {
        ...requestFixture(),
        'assignedAnalystId': currentAnalyst,
        'version': 7,
      };
      api.responses['/iam/users'] = [
        {
          'userId': currentAnalyst,
          'displayName': 'Analista actual',
          'email': 'actual@example.test',
        },
        {
          'userId': nextAnalyst,
          'displayName': 'Analista de destino',
          'email': 'destino@example.test',
        },
      ];
      api.responses['$requestPath/assignment'] = {
        ...requestFixture(),
        'assignedAnalystId': nextAnalyst,
        'version': 8,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: RequestWorkspace(services: services, requestId: requestId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reasignar analista'));
      await tester.tap(find.text('Reasignar analista'));
      await tester.pumpAndSettle();
      expect(api.calls.last.query, {
        'role': 'PurchaseAnalyst',
        'status': 'Active',
        'page': 1,
        'pageSize': 20,
      });

      await tester.tap(find.text('Analista activo'));
      await tester.pumpAndSettle();
      // The current analyst is not offered as a destination in the dialog;
      // the request detail behind it may show their name.
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Analista actual'),
        ),
        findsNothing,
      );
      await tester.tap(find.textContaining('Analista de destino').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('Completa este campo.'), findsOneWidget);
      expect(api.calls.where((call) => call.method == 'PUT'), isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo de la reasignación'),
        ' Redistribución de carga ',
      );
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      final change = api.calls.singleWhere((call) => call.method == 'PUT');
      expect(change.path, '$requestPath/assignment');
      expect(change.body, {
        'analystId': nextAnalyst,
        'reason': 'Redistribución de carga',
        'expectedVersion': 7,
      });
      expect(find.text('Analista responsable: Analista de destino'), findsOneWidget);
    },
  );

  testWidgets(
    'US22 — analyst queue uses the API and refreshes after reassignment',
    (tester) async {
      final api = TestApi(role: 'PurchaseAnalyst');
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      services.auth.session = Session.fromJson(sessionFixture(api.role));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RequestListPage(services: services)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solo mis solicitudes asignadas'));
      await tester.pumpAndSettle();
      expect(api.calls.last.query?['assignedToMe'], true);
      expect(find.textContaining('SOL-'), findsOneWidget);

      await tester.tap(find.textContaining('SOL-'));
      await tester.pumpAndSettle();
      expect(find.text('Asignar analista'), findsNothing);
      expect(find.text('Reasignar analista'), findsNothing);
      api.responses['/purchase-requests'] = {
        'items': [],
        'page': 1,
        'totalItems': 0,
        'totalPages': 0,
      };
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(api.calls.last.query?['assignedToMe'], true);
      expect(
        find.text('No tienes solicitudes asignadas con este filtro.'),
        findsOneWidget,
      );
    },
  );
}
