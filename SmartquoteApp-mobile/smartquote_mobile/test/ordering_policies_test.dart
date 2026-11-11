import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/app/services.dart';
import 'package:smartquote_mobile/evaluation_simulation/domain/sensitivity.dart';
import 'package:smartquote_mobile/evaluation_simulation/infrastructure/http_evaluation_repository.dart';
import 'package:smartquote_mobile/evaluation_simulation/infrastructure/http_sensitivity_repository.dart';
import 'package:smartquote_mobile/evaluation_simulation/presentation/sensitivity_panel.dart';
import 'package:smartquote_mobile/identity_access/application/session_controller.dart';
import 'package:smartquote_mobile/identity_access/domain/session.dart';
import 'package:smartquote_mobile/identity_access/infrastructure/http_identity_repository.dart';
import 'package:smartquote_mobile/purchase_ordering/domain/ordering_policies.dart';
import 'package:smartquote_mobile/purchase_ordering/infrastructure/http_order_repository.dart';
import 'package:smartquote_mobile/purchase_ordering/infrastructure/http_ordering_policy_repository.dart';
import 'package:smartquote_mobile/purchase_ordering/presentation/order_panel.dart';
import 'package:smartquote_mobile/purchase_ordering/presentation/supplier_eligibility_page.dart';
import 'package:smartquote_mobile/quotation_intake/infrastructure/http_quotation_repository.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/shared/presentation/ui.dart';
import 'package:smartquote_mobile/supply_requests/domain/purchase_request.dart';
import 'package:smartquote_mobile/supply_requests/infrastructure/http_request_repository.dart';

import 'support/fixtures.dart';

// Contract and widget tests with a test double of the API. They verify what the
// mobile client sends and shows; rules and persistence belong to the backend suites.
const supplierId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const priceId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const deliveryId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const analysisId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
const otherQuoteId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const budgetPath = '/purchase-requests/$requestId/budget';
const checkPath = '/simulations/$runId/budget-check';

Services policyServices(TestApi api) {
  final services = Services(
    auth: SessionController(HttpIdentityRepository(api), TestTransport()),
    requests: HttpRequestRepository(api),
    quotations: HttpQuotationRepository(api),
    evaluations: HttpEvaluationRepository(api),
    orders: HttpOrderRepository(api),
    orderExporter: TestExporter(),
    policies: HttpOrderingPolicyRepository(api),
    sensitivity: HttpSensitivityRepository(api),
  );
  services.auth.session = Session.fromJson(sessionFixture(api.role));
  return services;
}

JsonObject supplierFixture(String status, {int version = 1}) => {
  'id': supplierId,
  'taxIdentifier': '20123456789',
  'businessName': 'Proveedor de prueba',
  'status': status,
  'version': version,
  'createdAt': '2026-10-05T10:00:00Z',
  'history': [
    if (version > 1)
      {
        'id': fieldId,
        'previousStatus': 'Pending',
        'newStatus': status,
        'decidedBy': userId,
        'decidedAt': '2026-10-06T10:00:00Z',
        'reason': 'Identidad y condiciones revisadas.',
        'version': version,
      },
  ],
};

JsonObject budgetFixture({double? amount, int version = 1}) => amount == null
    ? {
        'requestId': requestId,
        'status': 'NotConfigured',
        'amountPen': null,
        'version': null,
        'revisions': [],
      }
    : {
        'requestId': requestId,
        'status': 'Configured',
        'amountPen': amount,
        'version': version,
        'revisions': [
          {
            'id': fieldId,
            'version': version,
            'amountPen': amount,
            'authorizedBy': userId,
            'authorizedAt': '2026-10-06T10:00:00Z',
            'reason': 'Límite autorizado',
          },
        ],
      };

JsonObject checkFixture(String status, {int? version, double? limit}) => {
  'simulationRunId': runId,
  'quotationId': quoteId,
  'inputFingerprint': 'fixture-fingerprint',
  'exchangeRate': null,
  'assessment': {
    'status': status,
    'budgetVersion': version,
    'budgetAmountPen': limit,
    'totalPen': 4500,
    'marginPen': limit == null ? null : limit - 4500,
    'excessPen': limit == null || limit >= 4500 ? 0 : 4500 - limit,
    'canApprove': status != 'Exceeded',
  },
};

List<JsonObject> criteriaFixture() => [
  {
    'criterionId': reqId,
    'mode': 'Mandatory',
    'category': 'TechnicalCompliance',
    'weight': 0,
  },
  {
    'criterionId': priceId,
    'mode': 'Weighted',
    'category': 'Price',
    'weight': 60,
  },
  {
    'criterionId': deliveryId,
    'mode': 'Weighted',
    'category': 'DeliveryTime',
    'weight': 40,
  },
];

JsonObject configurationFixture(String id, double price, String winner) => {
  'id': id,
  'weights': [
    {'criterionId': priceId, 'weight': price},
    {'criterionId': deliveryId, 'weight': 100 - price},
  ],
  'results': [
    {'quotationId': quoteId, 'isEligible': true, 'score': .8, 'exclusions': []},
    {
      'quotationId': otherQuoteId,
      'isEligible': true,
      'score': .7,
      'exclusions': [],
    },
  ],
  'tiedWinnerIds': [winner],
  'recommendedQuotationId': winner,
};

JsonObject analysisFixture({bool current = true}) => {
  'isCurrent': current,
  'isStable': false,
  'scope': '',
  'analysis': {
    'id': analysisId,
    'scenarioId': scenarioId,
    'requestId': requestId,
    'criteriaVersion': 1,
    'createdAt': '2026-10-06T10:00:00Z',
    'inputs': {'baselineConfigurationId': 'baseline'},
    'configurations': [
      configurationFixture('variant-20', 20, otherQuoteId),
      configurationFixture('baseline', 60, quoteId),
      configurationFixture('variant-80', 80, quoteId),
    ],
  },
};

Future<void> pumpTall(WidgetTester tester, Widget body) async {
  // Tall surface so lazily built list items are present for the finders.
  tester.view.physicalSize = const Size(1000, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.pumpAndSettle();
}

void main() {
  test('US18 E1 E2 E4 — each status allows one decision, sent with reason and current version', () async {
    final api = TestApi(role: 'PurchaseManager');
    final policies = HttpOrderingPolicyRepository(api);
    SupplierAccount supplier(String status) =>
        SupplierAccount(supplierFixture(status, version: 3));
    expect(supplier('Pending').nextAction, 'enable');
    expect(supplier('Enabled').nextAction, 'suspend');
    expect(supplier('Suspended').nextAction, 'reactivate');
    await expectLater(
      policies.decide(supplier('Pending'), 'suspend', 'Motivo'),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      policies.decide(supplier('Suspended'), 'enable', 'Motivo'),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      policies.decide(supplier('Enabled'), 'suspend', '   '),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.calls, isEmpty);
    api.responses['/suppliers/$supplierId/reactivate'] = supplierFixture(
      'Enabled',
      version: 4,
    );
    final updated = await policies.decide(
      supplier('Suspended'),
      'reactivate',
      ' Condiciones regularizadas ',
    );
    expect(api.calls.single.method, 'POST');
    expect(api.calls.single.body, {
      'reason': 'Condiciones regularizadas',
      'expectedVersion': 3,
    });
    expect(updated.enabled, isTrue);
    // The history returned by the server is preserved, not rebuilt locally.
    expect(updated.history.single['previousStatus'], 'Pending');
  });

  test('US18 E3 — catalogue is filtered by server status and only Enabled counts as available', () async {
    final api = TestApi(role: 'PurchaseAnalyst');
    final policies = HttpOrderingPolicyRepository(api);
    api.responses['/suppliers'] = [supplierFixture('Suspended', version: 2)];
    final suppliers = await policies.suppliers(status: 'Suspended');
    expect(api.calls.single.query, {
      'status': 'Suspended',
      'page': 1,
      'pageSize': 100,
    });
    expect(suppliers.single.enabled, isFalse);
    expect(SupplierAccount(supplierFixture('Pending')).enabled, isFalse);
    await expectLater(
      policies.suppliers(status: 'Approved'),
      throwsA(isA<ApiFailure>()),
    );
    await policies.suppliers();
    expect(api.calls.last.query, {'page': 1, 'pageSize': 100});
  });

  testWidgets(
    'US18 E1 — manager enables a pending supplier with a reason and sees its history',
    (tester) async {
      final api = TestApi(role: 'PurchaseManager');
      final services = policyServices(api);
      addTearDown(services.auth.dispose);
      api.responses['/suppliers'] = [supplierFixture('Pending')];
      api.responses['/suppliers/$supplierId'] = supplierFixture('Pending');
      api.responses['/suppliers/$supplierId/enable'] = supplierFixture(
        'Enabled',
        version: 2,
      );
      await pumpTall(tester, SupplierEligibilityPage(services: services));
      await tester.tap(find.byKey(const ValueKey('supplier-$supplierId')));
      await tester.pumpAndSettle();
      expect(find.text('Aún no se registran decisiones.'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Habilitar proveedor'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo de la decisión'),
        'Identidad y condiciones revisadas.',
      );
      api.responses['/suppliers'] = [supplierFixture('Enabled', version: 2)];
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final decision = api.calls.singleWhere((c) => c.method == 'POST');
      expect(decision.path, '/suppliers/$supplierId/enable');
      expect(decision.body, {
        'reason': 'Identidad y condiciones revisadas.',
        'expectedVersion': 1,
      });
      expect(find.text('Pendiente → Habilitado'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Suspender proveedor'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'US18 E1 — analyst consults the catalogue without decision controls',
    (tester) async {
      final api = TestApi(role: 'PurchaseAnalyst');
      final services = policyServices(api);
      addTearDown(services.auth.dispose);
      api.responses['/suppliers'] = [supplierFixture('Pending')];
      api.responses['/suppliers/$supplierId'] = supplierFixture('Pending');
      await pumpTall(tester, SupplierEligibilityPage(services: services));
      await tester.tap(find.byKey(const ValueKey('supplier-$supplierId')));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Habilitar proveedor'),
        findsNothing,
      );
      expect(
        find.text(
          'Solo el jefe de compras puede cambiar la habilitación de proveedores.',
        ),
        findsOneWidget,
      );
    },
  );

  test('US19 E1 — variations move price against delivery time and always total 100', () {
    final criteria = [
      ...criteriaFixture(),
      {
        'criterionId': fieldId,
        'mode': 'Weighted',
        'category': 'TechnicalCompliance',
        'weight': 0,
      },
    ];
    final variants = sensitivityVariants(criteria, [20, 80]);
    expect(variants.first['weights'], [
      {'criterionId': priceId, 'weight': 20.0},
      {'criterionId': deliveryId, 'weight': 80.0},
      {'criterionId': fieldId, 'weight': 0.0},
    ]);
    for (final variant in variants) {
      final weights = objectsOf(variant['weights']);
      expect(weights.fold<double>(0, (s, w) => s + numberOf(w, 'weight')), 100);
      // Mandatory rules are never part of a variation.
      expect(weights.any((w) => w['criterionId'] == reqId), isFalse);
    }
  });

  test('US19 E2 — comparison marks where the recommendation changes against the baseline', () {
    final analysis = SensitivityAnalysis(analysisFixture());
    expect(analysis.baseline!['id'], 'baseline');
    expect(
      analysis.configurations.map(analysis.changesRecommendation).toList(),
      [true, false, false],
    );
    expect(analysis.changedCount, 1);
    expect(analysis.ordered.map((c) => c['id']).toList(), [
      'baseline',
      'variant-20',
      'variant-80',
    ]);
    expect(analysis.stable, isFalse);
  });

  test('US19 E3 — invalid weights or unsaved criteria are rejected before calling the API', () {
    final criteria = criteriaFixture();
    for (final weights in <List<double>>[
      [],
      [60],
      [20, 20],
      [101],
      [-5],
      List.generate(21, (i) => i.toDouble()),
    ]) {
      expect(
        () => sensitivityVariants(criteria, weights),
        throwsA(isA<ApiFailure>()),
      );
    }
    final unsaved = [
      for (final c in criteria) {...c}..remove('criterionId'),
    ];
    expect(
      () => sensitivityVariants(unsaved, [20]),
      throwsA(isA<ApiFailure>()),
    );
    expect(commercialWeight(criteria), 100);
  });

  test('US19 E4 — promotion sends the criteria version and is refused for an outdated analysis', () async {
    final api = TestApi(role: 'PurchaseManager');
    final repository = HttpSensitivityRepository(api);
    await expectLater(
      repository.promote(
        SensitivityAnalysis(analysisFixture(current: false)),
        'variant-20',
      ),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      repository.promote(SensitivityAnalysis(analysisFixture()), 'unknown'),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.calls, isEmpty);
    final path =
        '/sensitivity-analyses/$analysisId/configurations/variant-20/official-simulation';
    api.responses[path] = {'scenarioId': scenarioId, 'simulationRunId': runId};
    final promoted = await repository.promote(
      SensitivityAnalysis(analysisFixture()),
      'variant-20',
    );
    expect(api.calls.single.path, path);
    expect(api.calls.single.body, {'expectedCriteriaVersion': 1});
    expect(promoted['simulationRunId'], runId);
  });

  testWidgets(
    'US19 E1 E2 E4 — manager analyzes variations, sees changes and promotes one configuration',
    (tester) async {
      final api = TestApi(role: 'PurchaseManager')
        ..status = 'Evaluation'
        ..savedCriteria = criteriaFixture();
      final services = policyServices(api);
      addTearDown(services.auth.dispose);
      final listPath = '/purchase-requests/$requestId/sensitivity-analyses';
      final createPath =
          '/evaluation-scenarios/$scenarioId/sensitivity-analyses';
      final promotePath =
          '/sensitivity-analyses/$analysisId/configurations/variant-20/official-simulation';
      api.responses[listPath] = [];
      api.responses[createPath] = analysisFixture();
      api.responses[promotePath] = {
        'scenarioId': scenarioId,
        'simulationRunId': runId,
      };
      var changed = 0;
      await pumpTall(
        tester,
        SensitivityPanel(
          services: services,
          request: PurchaseRequest(requestFixture(status: 'Evaluation')),
          active: true,
          onBusy: (_) {},
          onChanged: () async => changed++,
        ),
      );
      expect(find.textContaining('Precio 60 % · Plazo 40 %'), findsOneWidget);
      expect(find.text('Precio 20 % · Plazo 80 %'), findsOneWidget);
      await tester.tap(find.text('Analizar sensibilidad'));
      await tester.pumpAndSettle();
      final create = api.calls.singleWhere((c) => c.path == createPath);
      final sent = objectsOf((create.body as Map)['configurations']);
      // Suggested variations exclude the current weight (60).
      expect(
        sent.map((c) => objectsOf(c['weights']).first['weight']).toList(),
        [20.0, 40.0, 50.0, 80.0],
      );
      expect(
        find.text('El proveedor recomendado cambia en 1 configuración(es).'),
        findsOneWidget,
      );
      expect(
        find.text('Cambia la recomendación frente a la vigente.'),
        findsOneWidget,
      );
      // The baseline cannot be promoted; each variation can.
      expect(find.text('Usar en simulación oficial'), findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('configuration-variant-20')),
          matching: find.text('Usar en simulación oficial'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      final promote = api.calls.singleWhere((c) => c.path == promotePath);
      expect(promote.body, {'expectedCriteriaVersion': 1});
      // The analysis itself never issues an order.
      expect(
        api.calls.any((c) => c.path.endsWith('/purchase-orders')),
        isFalse,
      );
      expect(changed, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test('US20 E1 — budget needs a positive PEN amount with up to four decimals and a reason', () async {
    final api = TestApi(role: 'PurchaseManager');
    final policies = HttpOrderingPolicyRepository(api);
    for (final invalid in ['', '0', '-10', 'abc', '1.23456', '5000 soles']) {
      expect(
        () => PurchaseBudget.parseAmount(invalid),
        throwsA(isA<ApiFailure>()),
      );
    }
    expect(PurchaseBudget.parseAmount(' 5000,1234 '), 5000.1234);
    // An absent budget is never interpreted as a budget of zero.
    final none = PurchaseBudget(budgetFixture());
    expect(none.configured, isFalse);
    expect(none.amountPen, isNull);
    expect(none.version, 0);
    await expectLater(
      policies.authorizeBudget(requestId, 5000, '  ', 0),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      policies.authorizeBudget(requestId, 0, 'Límite', 0),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.calls, isEmpty);
    api.responses[budgetPath] = budgetFixture(amount: 5000);
    final saved = await policies.authorizeBudget(
      requestId,
      5000,
      ' Límite autorizado ',
      none.version,
    );
    expect(api.calls.single.method, 'PUT');
    expect(api.calls.single.body, {
      'amount': 5000.0,
      'currency': 'PEN',
      'reason': 'Límite autorizado',
      'expectedVersion': 0,
    });
    expect(saved.configured, isTrue);
    expect(saved.revisions.single['reason'], 'Límite autorizado');
  });

  test('US20 E2 E3 E4 — approval carries the contrasted budget version and an excess blocks it', () async {
    final api = TestApi(role: 'PurchaseManager')..status = 'Evaluation';
    final services = policyServices(api);
    addTearDown(services.auth.dispose);
    final within = BudgetCheck(
      checkFixture('WithinBudget', version: 2, limit: 5000),
    );
    // Equal to the limit is still within budget.
    expect(
      BudgetCheck(checkFixture('WithinBudget', version: 2, limit: 4500))
          .canApprove,
      isTrue,
    );
    await services.ordering.approve(
      runId,
      quoteId,
      'Entrega completa',
      'Granja',
      check: within,
    );
    expect((api.calls.last.body as Map)['expectedBudgetVersion'], 2);
    // Without a configured budget the contrasted version is 0.
    api.existingOrder = false;
    await services.ordering.approve(
      runId,
      quoteId,
      'Entrega completa',
      'Granja',
      check: BudgetCheck(checkFixture('NotConfigured')),
    );
    expect((api.calls.last.body as Map)['expectedBudgetVersion'], 0);
    // Callers that did not contrast the budget omit the field.
    await services.ordering.approve(runId, quoteId, 'Entrega', 'Granja');
    expect(
      (api.calls.last.body as Map).containsKey('expectedBudgetVersion'),
      isFalse,
    );
    final orders = api.calls
        .where((c) => c.path.endsWith('/purchase-orders'))
        .length;
    await expectLater(
      services.ordering.approve(
        runId,
        quoteId,
        'Entrega',
        'Granja',
        check: BudgetCheck(checkFixture('Exceeded', version: 2, limit: 4000)),
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      api.calls.where((c) => c.path.endsWith('/purchase-orders')).length,
      orders,
    );
  });

  testWidgets(
    'US20 E1 E2 — manager authorizes a budget and approves within the limit',
    (tester) async {
      final api = TestApi(role: 'PurchaseManager')..status = 'Evaluation';
      final services = policyServices(api);
      addTearDown(services.auth.dispose);
      api.responses[budgetPath] = budgetFixture();
      api.responses[checkPath] = checkFixture('NotConfigured');
      await pumpTall(
        tester,
        OrderPanel(
          services: services,
          request: PurchaseRequest(requestFixture(status: 'Evaluation')),
          active: true,
          onChanged: () async {},
          onBusy: (_) {},
        ),
      );
      expect(
        find.textContaining('No equivale a un presupuesto de cero'),
        findsOneWidget,
      );
      expect(find.text('Sin presupuesto configurado'), findsOneWidget);
      await tester.tap(find.text('Autorizar presupuesto'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe máximo en PEN'),
        '5000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Justificación'),
        'Límite autorizado',
      );
      // From now on the server reports the saved budget and its contrast.
      api.responses[checkPath] = checkFixture(
        'WithinBudget',
        version: 1,
        limit: 5000,
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final put = api.calls.singleWhere((c) => c.method == 'PUT');
      expect(put.path, budgetPath);
      expect((put.body as Map)['expectedVersion'], 0);
      expect((put.body as Map)['amount'], 5000.0);
      api.responses[budgetPath] = budgetFixture(amount: 5000);
      expect(find.text('Dentro del presupuesto'), findsOneWidget);
      expect(
        find.textContaining('Margen disponible: ${money(500, 'PEN')}'),
        findsOneWidget,
      );
      await tester.tap(find.text('Aprobar y emitir orden'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Condiciones de entrega'),
        'Entrega completa',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Destino / granja'),
        'Granja',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final approve = api.calls.singleWhere(
        (c) => c.method == 'POST' && c.path.endsWith('/purchase-orders'),
      );
      expect((approve.body as Map)['expectedBudgetVersion'], 1);
      expect(find.text('OC-2026-TEST'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'US20 E3 — exceeded budget or unavailable conversion blocks the approval',
    (tester) async {
      final api = TestApi(role: 'PurchaseManager')..status = 'Evaluation';
      final services = policyServices(api);
      addTearDown(services.auth.dispose);
      api.responses[budgetPath] = budgetFixture(amount: 4000);
      api.responses[checkPath] = checkFixture(
        'Exceeded',
        version: 1,
        limit: 4000,
      );
      await pumpTall(
        tester,
        OrderPanel(
          services: services,
          request: PurchaseRequest(requestFixture(status: 'Evaluation')),
          active: true,
          onChanged: () async {},
          onBusy: (_) {},
        ),
      );
      FilledButton approve() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprobar y emitir orden'),
      );
      expect(find.text('Presupuesto excedido'), findsOneWidget);
      expect(
        find.textContaining('Exceso: ${money(500, 'PEN')}'),
        findsOneWidget,
      );
      expect(approve().onPressed, isNull);
      // Missing preserved exchange rate: the server refuses the contrast.
      api.responses.remove(checkPath);
      api.failures[checkPath] = const ApiFailure(
        'Se requiere una tasa de cambio válida conservada por la simulación.',
        status: 422,
      );
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudo contrastar el presupuesto'),
        findsOneWidget,
      );
      expect(approve().onPressed, isNull);
      expect(
        api.calls.any(
          (c) => c.method == 'POST' && c.path.endsWith('/purchase-orders'),
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'US20 E1 — analyst sees the budget without authorization controls',
    (tester) async {
      final api = TestApi(role: 'PurchaseAnalyst')..status = 'Evaluation';
      final services = policyServices(api);
      addTearDown(services.auth.dispose);
      api.responses[budgetPath] = budgetFixture(amount: 5000);
      api.responses[checkPath] = checkFixture(
        'WithinBudget',
        version: 1,
        limit: 5000,
      );
      await pumpTall(
        tester,
        OrderPanel(
          services: services,
          request: PurchaseRequest(requestFixture(status: 'Evaluation')),
          active: true,
          onChanged: () async {},
          onBusy: (_) {},
        ),
      );
      expect(
        find.textContaining(
          'Límite autorizado: ${money(5000, 'PEN')} · versión 1',
        ),
        findsOneWidget,
      );
      expect(find.text('Registrar nuevo límite'), findsNothing);
      expect(find.text('Aprobar y emitir orden'), findsNothing);
    },
  );
}
