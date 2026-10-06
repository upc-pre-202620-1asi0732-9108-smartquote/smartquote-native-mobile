import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/main.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/supply_requests/presentation/new_request_page.dart';
import 'package:smartquote_mobile/supply_requests/domain/purchase_request.dart';
import 'package:smartquote_mobile/evaluation_simulation/presentation/simulation_panel.dart';
import 'package:smartquote_mobile/quotation_intake/presentation/quotation_review_page.dart';
import 'package:smartquote_mobile/purchase_ordering/presentation/order_panel.dart';
import 'package:smartquote_mobile/purchase_ordering/presentation/management_page.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets('US15 shows persisted history, order, author and observations', (
    tester,
  ) async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    api.responses['/suppliers/20123456789/performance'] =
        supplierPerformanceFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManagementPage(services: services, initialTaxId: '20123456789'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Evaluaciones registradas: 1'), findsOneWidget);
    expect(find.text('Promedio general: 4.50 / 5'), findsOneWidget);
    await tester.ensureVisible(find.byType(ExpansionTile));
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('Orden: $orderId'), findsOneWidget);
    expect(find.text('Autor: $userId'), findsOneWidget);
    expect(
      find.text('Observaciones: Entrega completa sin daños.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Field correction keeps evidence and the actual quotation version',
    (tester) async {
      final api = TestApi(role: 'PurchaseAnalyst');
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: QuotationReviewPage(
            services: services,
            request: PurchaseRequest(requestFixture()),
            quotationId: quoteId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Verificar / corregir con evidencia'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Verificar / corregir con evidencia'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verificar / corregir con evidencia'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor verificado'),
        '4.60',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Motivo y evidencia de la corrección',
        ),
        'El PDF indica 4.60 en la página 1.',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final update = api.calls.singleWhere(
        (c) => c.method == 'PUT' && c.path.contains('/fields/'),
      );
      expect(update.body, {
        'value': '4.60',
        'reason': 'El PDF indica 4.60 en la página 1.',
        'expectedVersion': 4,
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Manager approves the actual eligible offer with delivery terms',
    (tester) async {
      final api = TestApi(role: 'PurchaseManager')..status = 'Evaluation';
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      await services.auth.login('demo@smartquote.local', 'TestOnly!12345');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderPanel(
              services: services,
              request: PurchaseRequest(requestFixture(status: 'Evaluation')),
              active: true,
              onChanged: () async {},
              onBusy: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprobar y emitir orden'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Condiciones de entrega'),
        'Entrega completa en horario de recepción',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Destino / granja'),
        'Granja Los Olivos, almacén 2',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final approve = api.calls.singleWhere(
        (c) => c.method == 'POST' && c.path.endsWith('/purchase-orders'),
      );
      expect(
        approve.path,
        '/simulations/$runId/quotations/$quoteId/purchase-orders',
      );
      expect(
        (approve.body as Map)['deliveryDestination'],
        'Granja Los Olivos, almacén 2',
      );
      expect(find.text('OC-2026-TEST'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await services.auth.clear();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Unsubmitted criteria changes prevent manager approval', (
    tester,
  ) async {
    final api = TestApi(role: 'PurchaseManager');
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    await services.auth.login('demo@smartquote.local', 'TestOnly!12345');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderPanel(
            services: services,
            request: PurchaseRequest(requestFixture(status: 'Evaluation')),
            active: true,
            pendingCriteria: true,
            onChanged: () async {},
            onBusy: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Aprobar y emitir orden'),
    );
    expect(button.onPressed, null);
    expect(
      api.calls.any(
        (c) => c.method == 'POST' && c.path.endsWith('/purchase-orders'),
      ),
      false,
    );
    await services.auth.clear();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Login displays server errors then opens production workspace without tokens',
    (tester) async {
      final api = TestApi();
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      await tester.pumpWidget(SmartQuoteApp(services: services));
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Access token'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'demo@smartquote.local',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'TestOnly!12345',
      );
      api.failures['/iam/auth/login'] = const ApiFailure(
        'Cuenta pendiente de aprobación',
        status: 401,
      );
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta pendiente de aprobación'), findsOneWidget);
      api.failures.clear();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva solicitud'), findsOneWidget);
      expect(find.text('Alimento balanceado'), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Métricas'), findsNothing);
      expect(find.text('Cuentas'), findsNothing);
      await services.auth.clear();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Manager and analyst destinations use actual server roles', (
    tester,
  ) async {
    for (final role in ['PurchaseAnalyst', 'PurchaseManager']) {
      final api = TestApi(role: role);
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      await services.auth.login('demo@smartquote.local', 'TestOnly!12345');
      await tester.pumpWidget(SmartQuoteApp(services: services));
      await tester.pumpAndSettle();
      expect(find.text('Nueva solicitud'), findsNothing);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Proveedores'), findsOneWidget);
      expect(find.text('Notificaciones'), findsNothing);
      expect(
        find.text('Cuentas'),
        role == 'PurchaseManager' ? findsOneWidget : findsNothing,
      );
      await services.auth.clear();
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets(
    'Request form sends real operators, decimal quantity and optional requirement',
    (tester) async {
      final api = TestApi();
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      await tester.pumpWidget(
        MaterialApp(home: NewRequestPage(services: services)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Alimento balanceado',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cantidad'),
        '1000.5',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Unidad (kg, dosis, unidad…)'),
        'kg',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del requisito'),
        'Proteína mínima',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor esperado'),
        '20',
      );
      await tester.scrollUntilVisible(
        find.text('Registrar solicitud'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Registrar solicitud'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar solicitud'));
      await tester.pumpAndSettle();
      final create = api.calls.singleWhere(
        (c) => c.method == 'POST' && c.path == '/purchase-requests',
      );
      final item = objectsOf((create.body as Map)['items']).single;
      expect(item['quantity'], 1000.5);
      expect(item['unitOfMeasure'], 'kg');
      expect(objectsOf(item['requirements']).single['operator'], 'Equals');
      await services.auth.clear();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Criteria use sliders; mandatory filters are retained', (
    tester,
  ) async {
    final api = TestApi(role: 'PurchaseAnalyst');
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    await services.auth.login('demo@smartquote.local', 'TestOnly!12345');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SimulationPanel(
            services: services,
            request: PurchaseRequest(requestFixture(status: 'Evaluation')),
            active: true,
            onChanged: () async {},
            onBusy: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.textContaining('Proteína mínima'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Agregar ponderación técnica'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Agregar ponderación técnica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    // Lazy list children are built as they become visible.
    await tester.scrollUntilVisible(
      find.text('Total ponderado: 100 %'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Total ponderado: 100 %'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Guardar criterios / nueva versión'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar criterios / nueva versión'));
    await tester.pumpAndSettle();
    expect(api.savedCriteria.where((c) => c['mode'] == 'Mandatory').length, 1);
    expect(api.savedCriteria.where((c) => c['mode'] == 'Weighted').length, 3);
    await services.auth.clear();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Quotation confirmation is blocked until mappings are explicitly reviewed',
    (tester) async {
      final api = TestApi(role: 'PurchaseAnalyst');
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: QuotationReviewPage(
            services: services,
            request: PurchaseRequest(requestFixture()),
            quotationId: quoteId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Confirmar cotización verificada'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      var button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar cotización verificada'),
      );
      expect(button.onPressed, null);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar cotización verificada'),
      );
      expect(button.onPressed, isNotNull);
      await services.auth.clear();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
