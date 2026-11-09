import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/app/services.dart';
import 'package:smartquote_mobile/identity_access/domain/session.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/supply_requests/infrastructure/http_request_workflow_repository.dart';
import 'package:smartquote_mobile/quotation_intake/infrastructure/http_expiry_alert_repository.dart';
import 'package:smartquote_mobile/supply_requests/application/request_draft.dart';
import 'package:smartquote_mobile/supply_requests/presentation/clarifications_panel.dart';
import 'package:smartquote_mobile/supply_requests/presentation/recurring_requests_page.dart';
import 'package:smartquote_mobile/supply_requests/presentation/new_request_page.dart';
import 'package:smartquote_mobile/supply_requests/domain/purchase_request.dart';
import 'package:smartquote_mobile/quotation_intake/presentation/expiry_alerts_page.dart';

import 'support/fixtures.dart';

Services workflowServices(TestApi api) {
  final s = testServices(api);
  return Services(
    auth: s.auth,
    requests: s.requests,
    quotations: s.quotations,
    evaluations: s.evaluations,
    orders: s.orders,
    orderExporter: s.orderExporter,
    workflows: HttpRequestWorkflowRepository(api),
    expiryAlerts: HttpExpiryAlertRepository(api),
  );
}

JsonObject clarificationFixture({String status = 'Pending'}) => {
  'id': fieldId,
  'requestId': requestId,
  'itemId': itemId,
  'requirementId': reqId,
  'authorId': lineId,
  'specialistId': userId,
  'question': '¿La proteína corresponde al porcentaje de proteína cruda?',
  'status': status,
  'version': 2,
  'createdAt': '2026-11-09T10:00:00Z',
  'answer': status == 'Answered' ? 'Sí, proteína cruda al 21%.' : null,
};

void main() {
  testWidgets(
    'US15 E3 — explicit specification confirmation retains mandatory rule and both versions',
    (tester) async {
      final api = TestApi();
      final s = workflowServices(api);
      addTearDown(s.auth.dispose);
      s.auth.session = Session.fromJson(sessionFixture(api.role));
      api.responses['/technical-clarifications'] = [
        clarificationFixture(status: 'Answered'),
      ];
      api.responses['/technical-clarifications/$fieldId/requirement-revisions'] =
          {};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClarificationsPanel(services: s)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Revisar especificación'));
      await tester.tap(find.text('Revisar especificación'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar nueva especificación'), findsOneWidget);
      expect(
        api.calls.where((c) => c.path.endsWith('/requirement-revisions')),
        isEmpty,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor esperado'),
        '21',
      );
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Justificación del cambio'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Justificación del cambio'),
        'Especificación confirmada por producción.',
      );
      await tester.tap(find.text('Confirmar cambio'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final body =
          api.calls
                  .where((c) => c.path.endsWith('/requirement-revisions'))
                  .single
                  .body
              as Map;
      expect(body['expectedClarificationVersion'], 2);
      expect(body['expectedRequestVersion'], 3);
      expect(body['specification']['expectedValue'], '21');
      expect(body['specification']['isMandatory'], true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'US16 E2 E3 — editing and saving a generated draft never automatically submits it',
    (tester) async {
      final api = TestApi();
      final s = workflowServices(api);
      addTearDown(s.auth.dispose);
      api.responses['/purchase-requests/$requestId/draft'] = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<String>(
                    builder: (_) => NewRequestPage(
                      services: s,
                      existing: PurchaseRequest(
                        requestFixture(status: 'Draft'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Abrir borrador'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir borrador'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Guardar borrador sin enviar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar borrador sin enviar'));
      await tester.pumpAndSettle();
      final body =
          api.calls.where((c) => c.path.endsWith('/draft')).single.body as Map;
      expect(body['expectedVersion'], 3);
      expect(body['items'], isNotEmpty);
      expect(api.calls.where((c) => c.path.endsWith('/submit')), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('US16 E1 — invalid recurrence is rejected before HTTP', (
    tester,
  ) async {
    final api = TestApi();
    final s = workflowServices(api);
    addTearDown(s.auth.dispose);
    await tester.pumpWidget(
      MaterialApp(home: NewRequestPage(services: s, recurring: true)),
    );
    await tester.pumpAndSettle();
    final interval = find.widgetWithText(TextFormField, 'Generar cada (días)');
    await tester.scrollUntilVisible(
      interval,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(interval, '0');
    await tester.scrollUntilVisible(
      find.text('Guardar programación'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar programación'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('La periodicidad debe ser'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('La periodicidad debe ser'), findsOneWidget);
    expect(
      api.calls.where((c) => c.path == '/recurring-request-schedules'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  // US15/E1-E3: only backend contracts modify a consultation or its linked specification.
  test('US15 E1 E2 E3 — sends exact origins and independent versioned response/revision commands', () async {
    final api = TestApi();
    final repo = HttpRequestWorkflowRepository(api);
    api.responses['/purchase-requests/$requestId/clarifications'] =
        clarificationFixture();
    await repo.ask(requestId, {
      'itemId': itemId,
      'requirementId': reqId,
      'specialistId': userId,
      'question': 'Consulta',
      'expectedVersion': 3,
    });
    expect((api.calls.last.body as Map)['requirementId'], reqId);
    expect((api.calls.last.body as Map)['specialistId'], userId);
    api.responses['/technical-clarifications/$fieldId/read'] = null;
    await repo.read(fieldId);
    expect(api.calls.last.method, 'PUT');
    api.responses['/technical-clarifications/$fieldId/response'] =
        clarificationFixture(status: 'Answered');
    await repo.respond(fieldId, ' Sí, 21%. ', 3);
    expect(api.calls.last.body, {'answer': 'Sí, 21%.', 'expectedVersion': 3});
    expect(
      api.calls.where((c) => c.path.endsWith('/requirement-revisions')),
      isEmpty,
    );
    api.responses['/technical-clarifications/$fieldId/requirement-revisions'] =
        {};
    await repo.revise(fieldId, {
      'specification': {
        'name': 'Proteína',
        'operator': 'GreaterThanOrEqual',
        'expectedValue': '21',
        'unitOfMeasure': '%',
        'isMandatory': true,
      },
      'reason': 'Confirmación',
      'expectedClarificationVersion': 4,
      'expectedRequestVersion': 3,
    });
    expect((api.calls.last.body as Map)['expectedClarificationVersion'], 4);
    expect((api.calls.last.body as Map)['expectedRequestVersion'], 3);
  });
  // US15/E2-E3 and US16/E2: rejects stale/forbidden operations without automatic resubmission.
  for (final status in [403, 409, 422]) {
    test(
      'US15 US16 — propagates $status without overwriting or retrying',
      () async {
        final api = TestApi();
        final repo = HttpRequestWorkflowRepository(api);
        api.failures['/technical-clarifications/$fieldId/response'] =
            ApiFailure('Rejected', status: status);
        await expectLater(
          repo.respond(fieldId, 'Respuesta', 2),
          throwsA(isA<ApiFailure>().having((e) => e.status, 'status', status)),
        );
        expect(api.calls.length, 1);
      },
    );
  }
  test('US16 E1 E2 — draft roundtrip preserves every item and requirement without publishing it', () {
    final source = requestFixture(status: 'Draft');
    final draft = RequestDraft.fromJson(source);
    expect(draft.validate(), isNull);
    expect(draft.toJson()['items'], isNotEmpty);
    final item = (draft.toJson()['items'] as List).single as Map;
    expect(item['quantity'], 1000);
    expect((item['requirements'] as List).single['isMandatory'], true);
    draft.items.single.quantity = '1500';
    expect((source['items'] as List).single['quantity'], 1000);
  });
  test('US16 E1 E2 E3 E4 — recurrence and draft commands preserve server identity and optimistic versions', () async {
    final api = TestApi();
    final repo = HttpRequestWorkflowRepository(api);
    api.responses['/recurring-request-schedules'] = {'id': fieldId};
    final payload = {
      ...RequestDraft.fromJson(requestFixture()).toJson(),
      'startDate': '2026-12-25',
      'intervalDays': 7,
      'requiredDateOffsetDays': 2,
      'timeZoneId': 'America/Lima',
    }..remove('requiredDate');
    await repo.createSchedule(payload);
    expect((api.calls.last.body as Map)['timeZoneId'], 'America/Lima');
    api.responses['/purchase-requests/$requestId/draft'] = {};
    await repo.saveDraft(requestId, {
      ...RequestDraft.fromJson(requestFixture()).toJson(),
      'expectedVersion': 3,
    });
    expect(api.calls.last.method, 'PUT');
    expect(api.calls.where((c) => c.path.endsWith('/submit')), isEmpty);
    api.responses['/purchase-requests/$requestId/submit'] = {};
    await repo.submitDraft(requestId, 4);
    expect(api.calls.last.body, {'expectedVersion': 4});
    api.responses['/recurring-request-schedules/$fieldId/pause'] = {
      'id': fieldId,
      'isActive': false,
    };
    await repo.pause(fieldId, 5);
    expect(api.calls.last.body, {'expectedVersion': 5});
    api.responses['/recurring-request-schedules'] = [];
    await repo.schedules(page: 2);
    await repo.schedules(page: 2);
    expect(api.calls.last.method, 'GET');
    expect(api.calls.last.query!['page'], 2);
    expect(api.calls.where((c) => c.path.contains('/generate')), isEmpty);
  });
  test('US17 E1 E2 E3 — reads server alert history and acknowledges without changing quotation validity', () async {
    final api = TestApi();
    final repo = HttpExpiryAlertRepository(api);
    api.responses['/quotation-expiry-alerts'] = [
      {
        'id': fieldId,
        'quotationId': quoteId,
        'requestId': requestId,
        'supplierName': 'NutriAves',
        'validUntil': '2026-11-10',
        'readAt': null,
      },
    ];
    final alerts = await repo.list(unreadOnly: true, page: 2);
    expect(alerts.single['quotationId'], quoteId);
    expect(api.calls.last.query!['unreadOnly'], true);
    api.responses['/quotation-expiry-alerts/$fieldId/read'] = null;
    await repo.read(fieldId);
    await repo.read(fieldId);
    expect(api.calls.last.method, 'PUT');
    expect(api.calls.where((c) => c.path.startsWith('/quotations/')), isEmpty);
  });
  testWidgets(
    'US15 E2 — specialist sees linked question and answers explicitly',
    (tester) async {
      final api = TestApi();
      final s = workflowServices(api);
      addTearDown(s.auth.dispose);
      s.auth.session = Session.fromJson(sessionFixture(api.role));
      api.responses['/technical-clarifications'] = [clarificationFixture()];
      api.responses['/technical-clarifications/$fieldId/response'] =
          clarificationFixture(status: 'Answered');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClarificationsPanel(services: s)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('¿La proteína'), findsOneWidget);
      await tester.ensureVisible(find.text('Responder'));
      await tester.tap(find.text('Responder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Sí, proteína cruda.');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.path.endsWith('/response')).single.body, {
        'answer': 'Sí, proteína cruda.',
        'expectedVersion': 2,
      });
      expect(
        api.calls.where((c) => c.path.endsWith('/requirement-revisions')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'US16 E3 E4 — shows persisted occurrence and pause retains its request reference',
    (tester) async {
      final api = TestApi();
      final s = workflowServices(api);
      addTearDown(s.auth.dispose);
      s.auth.session = Session.fromJson(sessionFixture(api.role));
      api.responses['/recurring-request-schedules'] = [
        {
          'id': fieldId,
          'version': 6,
          'isActive': true,
          'items': requestFixture()['items'],
          'intervalDays': 7,
          'requiredDateOffsetDays': 2,
          'timeZoneId': 'America/Lima',
          'nextOccurrenceDate': '2026-12-25',
          'occurrences': [
            {'requestId': requestId, 'scheduledDate': '2026-12-18'},
          ],
        },
      ];
      api.responses['/recurring-request-schedules/$fieldId/pause'] = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RecurringRequestsPage(services: s)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SOL-11111111'), findsOneWidget);
      await tester.ensureVisible(find.text('Suspender programación'));
      await tester.tap(find.text('Suspender programación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.path.endsWith('/pause')).single.body, {
        'expectedVersion': 6,
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'US17 E1 E2 — shows supplier and expiry and marks server alert as read',
    (tester) async {
      final api = TestApi(role: 'PurchaseAnalyst');
      final s = workflowServices(api);
      addTearDown(s.auth.dispose);
      s.auth.session = Session.fromJson(sessionFixture(api.role));
      api.responses['/quotation-expiry-alerts'] = [
        {
          'id': fieldId,
          'quotationId': quoteId,
          'requestId': requestId,
          'supplierName': 'NutriAves',
          'validUntil': '2026-11-10',
          'leadDays': 3,
          'readAt': null,
        },
      ];
      api.responses['/quotation-expiry-alerts/$fieldId/read'] = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExpiryAlertsPage(services: s)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NutriAves'), findsOneWidget);
      expect(find.textContaining('10/11/2026'), findsOneWidget);
      await tester.ensureVisible(find.text('Marcar leída'));
      await tester.tap(find.text('Marcar leída'));
      await tester.pumpAndSettle();
      expect(
        api.calls.where((c) => c.path.endsWith('/read')).single.method,
        'PUT',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
