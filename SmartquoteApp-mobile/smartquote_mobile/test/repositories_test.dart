import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/evaluation_simulation/application/criteria_policy.dart';
import 'package:smartquote_mobile/supply_requests/domain/purchase_request.dart';

import 'support/fixtures.dart';

void main() {
  // TS03/E1-E3: el móvil conserva la conversión y la tasa entregadas por backend.
  // No consulta SUNAT directamente ni genera una tasa alternativa ante 503.
  test('TS03 E1 E2 E3 — USD comparison retains original amounts and rate trace across reload, rejects unavailable source', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    final expected = runFixture();
    expected['evaluations'] = [
      {
        'quotationId': quoteId,
        'originalCurrency': 'USD',
        'originalTotal': 1000,
        'comparisonCurrency': 'PEN',
        'comparisonTotal': 3400,
        'conversionApplied': true,
        'isEligible': true,
      },
    ];
    api.responses['/evaluation-scenarios/$scenarioId/simulations'] = expected;
    api.responses['/simulations/$runId'] = expected;
    final run = await services.evaluations.simulate(scenarioId);
    expect(run.evaluations.single['originalTotal'], 1000);
    expect(run.evaluations.single['originalCurrency'], 'USD');
    expect(run.evaluations.single['comparisonTotal'], 3400);
    expect(run.evaluations.single['comparisonCurrency'], 'PEN');
    expect(run.exchangeRate!['rate'], 3.4);
    expect(
      (await services.evaluations.getSimulation(run.id)).exchangeRate,
      run.exchangeRate,
    );
    api.failures['/evaluation-scenarios/$scenarioId/simulations'] =
        const ApiFailure('Official source unavailable', status: 503);
    await expectLater(
      services.evaluations.simulate(scenarioId),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 503)),
    );
    expect(api.calls.every((c) => c.path.startsWith('/')), true);
  });
  // US13 E3: preserves supplier history and summary from the same API response.
  test('US13 E3 — preserves supplier history and summary from the same API response', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    final expected = supplierPerformanceFixture();
    api.responses['/suppliers/20123456789/performance'] = expected;
    final result = await services.orders.performance('20123456789');
    expect(result, expected);
    final history = objectsOf(result['evaluations']);
    expect(history.single['purchaseOrderId'], orderId);
    expect(history.single['evaluatedBy'], userId);
    expect(history.single['observations'], 'Entrega completa sin daños.');
    expect(api.calls.single.path, '/suppliers/20123456789/performance');
  });

  // US13 E1 E2: accepts 500 characters and rejects longer notes or invalid scores before HTTP.
  test('US13 E1 E2 — accepts 500 characters and rejects longer notes or invalid scores before HTTP', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    for (final scores in [(0, 4), (4, 6)]) {
      await expectLater(
        services.orders.evaluate(orderId, scores.$1, scores.$2, ''),
        throwsA(isA<ApiFailure>()),
      );
    }
    await expectLater(
      services.orders.evaluate(orderId, 5, 4, 'x' * 501),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.calls, isEmpty);
    await services.orders.evaluate(orderId, 5, 4, 'x' * 500);
    expect((api.calls.single.body as Map)['observations'], 'x' * 500);
  });

  // US08 E2: Ordering rechecks a current simulation instead of approving a stale snapshot.
  test('US08 E2 — Ordering rechecks a current simulation instead of approving a stale snapshot', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    api.responses['/simulations/$runId'] = runFixture(current: false);
    await expectLater(
      services.ordering.approve(runId, quoteId, 'Entrega completa', 'Granja'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 409)),
    );
    expect(api.calls.any((c) => c.method == 'POST'), false);
  });
  // US09 E3: Concurrent renewals rotate the session only once.
  test('US09 E3 — Concurrent renewals rotate the session only once', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    await services.auth.login('demo@smartquote.local', 'TestOnly!12345');
    final results = await Future.wait([
      services.auth.renew(),
      services.auth.renew(),
    ]);
    expect(results, [true, true]);
    expect(api.calls.where((c) => c.path == '/iam/auth/refresh').length, 1);
    await services.auth.clear();
  });
  // US02 E3 US03 E1 E2 E3: Request REST contracts: pagination, decimal body, history, versions and attachments.
  test('US02 E3 US03 E1 E2 E3 — Request REST contracts: pagination, decimal body, history, versions and attachments', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    final request = await services.requests.get(requestId);
    expect(request.id, requestId);
    await services.requests.list(status: 'Submitted', page: 2);
    final query = api.calls.last.query!;
    expect(query['page'], 2);
    expect(query['pageSize'], 12);
    expect(query['status'], 'Submitted');
    await services.requests.create({
      'requiredDate': '2026-12-25',
      'priority': 'Normal',
      'items': [],
    });
    expect(api.calls.last.method, 'POST');
    await services.requests.history(requestId);
    await services.requests.changeStatus(request, 'UnderReview', 'Revisión');
    expect(api.calls.last.body, {
      'nextStatus': 'UnderReview',
      'reason': 'Revisión',
      'expectedVersion': 3,
    });
    await services.requests.attach(request, fileFixture());
    final upload = api.calls.last.body as MultipartPayload;
    expect(upload.fields['expectedVersion'], 3);
    expect(upload.files['file']!.single.name, 'cotizacion.pdf');
    final notifications = await services.requests.notifications(
      unreadOnly: true,
    );
    expect(notifications.first['purchaseRequestId'], requestId);
    await services.requests.readNotification(userId);
    expect(api.calls.last.path, '/notifications/$userId/read');
    expect(api.calls.last.method, 'PUT');
  });
  // US04 E1 US05 E1 E2: Quotation consumes real IDs, field versions and explicit line mappings.
  test('US04 E1 US05 E1 E2 — Quotation consumes real IDs, field versions and explicit line mappings', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    expect((await services.quotations.list(requestId)).length, 2);
    final quote = await services.quotations.upload(
      requestId,
      fileFixture(),
      {},
    );
    expect((api.calls.last.body as MultipartPayload).fields, isEmpty);
    await services.quotations.process(quote.id);
    final current = await services.quotations.get(quote.id);
    await services.quotations.correct(current, fieldId, '4.50', 'PDF página 1');
    expect(api.calls.last.path, '/quotations/$quoteId/fields/$fieldId');
    expect((api.calls.last.body as Map)['expectedVersion'], current.version);
    await services.quotations.addSpecification(current, lineId, {
      'name': 'Proteína mínima',
      'value': '21',
      'unitOfMeasure': '%',
      'sourcePageNumber': 1,
      'sourceTextReference': 'Proteína 21%',
      'reason': 'Evidencia',
    });
    expect(
      api.calls.last.path,
      '/quotations/$quoteId/lines/$lineId/specifications',
    );
    await expectLater(
      services.quotations.confirm(current, {}),
      throwsA(isA<ApiFailure>()),
    );
    await services.quotations.confirm(current, {lineId: itemId});
    expect((api.calls.last.body as Map)['lineMappings'], [
      {'lineId': lineId, 'requestedItemId': itemId},
    ]);
  });
  // US06 E3 US07 E1 TS03 E1 E2: Simulation versions, history, existing exchange-rate trace, no direct SUNAT call.
  test('US06 E3 US07 E1 TS03 E1 E2 — Simulation versions, history, existing exchange-rate trace, no direct SUNAT call', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    expect(await services.evaluations.current(requestId), null);
    final criteria = defaultCriteria(PurchaseRequest(requestFixture()));
    final scenario = await services.evaluations.save(requestId, criteria, null);
    expect((api.calls.last.body as Map)['requestId'], requestId);
    await services.evaluations.get(scenario.id);
    await services.evaluations.save(requestId, criteria, scenario);
    expect(api.calls.last.path, '/evaluation-scenarios/$scenarioId/versions');
    expect((api.calls.last.body as Map).containsKey('requestId'), false);
    final run = await services.evaluations.simulate(scenario.id);
    expect(run.exchangeRate!['source'], 'SUNAT');
    expect(run.exchangeRate!['rate'], 3.4);
    expect((await services.evaluations.history(requestId)).first.id, runId);
    await services.evaluations.getSimulation(runId);
    expect(api.calls.every((c) => c.path.startsWith('/')), true);
    api.failures['/evaluation-scenarios/$scenarioId/simulations'] =
        const ApiFailure(
          'SUNAT no disponible. No previous rate was substituted.',
          status: 503,
        );
    await expectLater(
      services.evaluations.simulate(scenarioId),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 503)),
    );
  });
  // US08 E1 E3 US12 E1 US13 E1 US14 E2: Order decision, idempotent resource, delivery, evaluation, audit and metrics.
  test('US08 E1 E3 US12 E1 US13 E1 US14 E2 — Order decision, idempotent resource, delivery, evaluation, audit and metrics', () async {
    final api = TestApi();
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    expect(await services.orders.byRequest(requestId), null);
    final order = await services.orders.approve(
      runId,
      quoteId,
      'Entrega completa',
      'Granja',
    );
    expect(
      api.calls.last.path,
      '/simulations/$runId/quotations/$quoteId/purchase-orders',
    );
    expect(api.calls.last.body, {
      'deliveryConditions': 'Entrega completa',
      'deliveryDestination': 'Granja',
    });
    expect((await services.orders.byRequest(requestId))!.id, order.id);
    expect((await services.orders.bySimulation(runId))!.id, order.id);
    expect((await services.orders.get(order.id)).id, order.id);
    expect((await services.orders.delivered(order.id)).status, 'Delivered');
    final evaluation = await services.orders.evaluate(
      order.id,
      5,
      4,
      ' Entrega completa ',
    );
    expect(evaluation['purchaseOrderId'], order.id);
    expect((api.calls.last.body as Map)['observations'], 'Entrega completa');
    final performance = await services.orders.performance('20123456789');
    expect(performance['overallScore'], null);
    await services.orders.audit('PurchaseOrder', order.id);
    expect(api.calls.last.path, '/audit/PurchaseOrder/$orderId');
    await services.orders.metrics('2026-10-01', '2026-10-05');
    expect(api.calls.last.query, {'from': '2026-10-01', 'to': '2026-10-05'});
  });
  // US09 E1 E3: IAM public login/refresh/register, pending approval, current-user and logout.
  test('US09 E1 E3 — IAM public login/refresh/register, pending approval, current-user and logout', () async {
    final api = TestApi(role: 'PurchaseManager');
    final services = testServices(api);
    addTearDown(services.auth.dispose);
    final identity = services.auth.repository;
    expect(await identity.initialSetup(), false);
    expect(api.calls.last.authenticated, false);
    await identity.register({
      'email': 'member@example.com',
      'displayName': 'Member',
      'password': 'TestOnly!12345',
      'role': 'ProductionSpecialist',
    });
    await services.auth.login('demo@smartquote.local', 'TestOnly!12345');
    expect(services.auth.session!.manager, true);
    await identity.me();
    expect(api.calls.last.authenticated, true);
    await identity.pending();
    await identity.approve(userId, 'PurchaseAnalyst');
    expect(api.calls.last.body, {'role': 'PurchaseAnalyst'});
    expect(await services.auth.renew(), true);
    await services.auth.logout();
    expect(services.auth.session, null);
  });
  // TS02 E3 TS04 E2: 403/409 are not swallowed as optional missing resources.
  test(
    'TS02 E3 TS04 E2 — 403/409 are not swallowed as optional missing resources',
    () async {
      final api = TestApi();
      final services = testServices(api);
      addTearDown(services.auth.dispose);
      api.failures['/purchase-requests/$requestId/purchase-order'] =
          const ApiFailure('Forbidden', status: 403);
      await expectLater(
        services.orders.byRequest(requestId),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 403)),
      );
      api.failures['/purchase-requests/$requestId/evaluation-scenario'] =
          const ApiFailure('Conflict', status: 409);
      await expectLater(
        services.evaluations.current(requestId),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 409)),
      );
    },
  );
}
