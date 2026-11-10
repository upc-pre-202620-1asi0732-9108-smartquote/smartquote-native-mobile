import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/evaluation_simulation/presentation/distributed_purchase_panel.dart';
import 'package:smartquote_mobile/identity_access/domain/session.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/supply_requests/domain/purchase_request.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets(
    'US21 — blocks incomplete coverage and excess budget, then emits the reviewed set',
    (tester) async {
      final api = TestApi(role: 'PurchaseManager');
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      services.auth.session = Session.fromJson(sessionFixture(api.role));
      final request = PurchaseRequest({
        ...requestFixture(status: 'Evaluation'),
        'items': [
          {'itemId': itemId, 'description': 'Alimento'},
          {'itemId': 'other-item', 'description': 'Vacunas'},
        ],
      });
      final requestPath = '/purchase-requests/$requestId';
      final runPath = '/simulations/$runId';
      final simulate =
          '/evaluation-scenarios/$scenarioId/distributed-simulations';
      final issue = '$runPath/purchase-awards';
      api.failures['$requestPath/purchase-award'] = const ApiFailure(
        'Ausente',
        status: 404,
      );
      api.responses['$requestPath/simulations'] = [];
      api.responses['$requestPath/evaluation-scenario'] = {
        'scenarioId': scenarioId,
      };
      JsonObject simulation(bool complete) => {
        'simulationRunId': runId,
        'mode': 'DistributedByItem',
        'isCurrent': true,
        'distribution': {
          'canApprove': complete,
          'uncoveredItemIds': complete ? [] : ['other-item'],
          'totalPen': 550,
        },
      };
      api.responses[simulate] = simulation(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DistributedPurchasePanel(
              services: services,
              request: request,
              active: true,
              pendingCriteria: false,
              onBusy: (_) {},
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final simulateButton = find.text('Simular compra distribuida');
      final issueButton = find.widgetWithText(
        FilledButton,
        'Aprobar y emitir órdenes',
      );
      await tester.tap(simulateButton);
      await tester.pumpAndSettle();
      expect(find.text('Sin cobertura: Vacunas'), findsOneWidget);
      expect(tester.widget<FilledButton>(issueButton).onPressed, isNull);
      expect(
        api.calls.where((call) => call.path.endsWith('budget-check')),
        isEmpty,
      );

      api.responses[simulate] = simulation(true);
      JsonObject budget(bool allowed) => {
        'inputFingerprint': 'confirmed-fingerprint',
        'assessment': {
          'budgetVersion': 4,
          'status': allowed ? 'WithinBudget' : 'Exceeded',
          'budgetAmountPen': allowed ? 600 : 500,
          'excessPen': allowed ? null : 50,
          'canApprove': allowed,
        },
      };
      api.responses['$runPath/purchase-award-budget-check'] = budget(false);
      await tester.tap(simulateButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Exceso:'), findsOneWidget);
      expect(tester.widget<FilledButton>(issueButton).onPressed, isNull);

      api.responses['$runPath/purchase-award-budget-check'] = budget(true);
      api.failures[issue] = const ApiFailure('Se perdió la respuesta.');
      await tester.tap(simulateButton);
      await tester.pumpAndSettle();
      await tester.tap(issueButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Condiciones de entrega'),
        'Mañana',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Destino / granja'),
        'Almacén',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(api.calls.where((call) => call.path == issue), hasLength(1));
      api.failures.remove(issue);
      api.responses[issue] = {
        'award': {'mode': 'DistributedByItem', 'totalPen': 550},
        'orders': [
          {
            'supplierBusinessName': 'Proveedor A',
            'orderNumber': 'OC-1',
            'total': 300,
            'currency': 'PEN',
          },
          {
            'supplierBusinessName': 'Proveedor B',
            'orderNumber': 'OC-2',
            'total': 250,
            'currency': 'PEN',
          },
        ],
      };
      await tester.tap(find.text('Comprobar o reintentar la aprobación'));
      await tester.pumpAndSettle();
      final attempts = api.calls.where((call) => call.path == issue).toList();
      expect(attempts.map((call) => call.idempotencyKey), [
        'mobile-distributed-$runId',
        'mobile-distributed-$runId',
      ]);
      expect(attempts.first.body, attempts.last.body);
      expect(attempts.last.body, {
        'deliveryConditions': 'Mañana',
        'deliveryDestination': 'Almacén',
        'expectedBudgetVersion': 4,
        'expectedInputFingerprint': 'confirmed-fingerprint',
      });
      expect(find.text('Proveedor A'), findsOneWidget);
      expect(find.text('Proveedor B'), findsOneWidget);
    },
  );
}
