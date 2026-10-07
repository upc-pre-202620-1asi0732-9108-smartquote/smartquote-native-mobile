import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/shared/infrastructure/api_client.dart';
import 'package:smartquote_mobile/identity_access/infrastructure/http_identity_repository.dart';
import 'package:smartquote_mobile/supply_requests/infrastructure/http_request_repository.dart';
import 'package:smartquote_mobile/quotation_intake/infrastructure/http_quotation_repository.dart';
import 'package:smartquote_mobile/evaluation_simulation/application/criteria_policy.dart';
import 'package:smartquote_mobile/evaluation_simulation/infrastructure/http_evaluation_repository.dart';
import 'package:smartquote_mobile/purchase_ordering/infrastructure/http_order_repository.dart';
import 'package:smartquote_mobile/purchase_ordering/domain/corporate_profile.dart';
import 'package:smartquote_mobile/purchase_ordering/infrastructure/order_pdf.dart';

// PDFs válidos de transporte. Sus hashes cumplen el contrato del Stub local.
// No constituyen evidencia de precisión de OpenAI ni un corpus para SP01.
final _pdfs = [
  UploadFile(
    'mobile-supplier-a.pdf',
    base64Decode(
      'JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCA2MTIgNzkyXSAvUmVzb3VyY2VzIDw8IC9Gb250IDw8IC9GMSA0IDAgUiA+PiA+PiAvQ29udGVudHMgNSAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL1R5cGUgL0ZvbnQgL1N1YnR5cGUgL1R5cGUxIC9CYXNlRm9udCAvSGVsdmV0aWNhID4+CmVuZG9iago1IDAgb2JqCjw8IC9MZW5ndGggMTE4ID4+CnN0cmVhbQpCVCAvRjEgMTQgVGYgNTAgNzUwIFRkIChTbWFydFF1b3RlIGludGVncmF0aW9uIGZpeHR1cmUgbW9iaWxlLXN1cHBsaWVyLWEgYTU5ZTVhMWEtODc3MS00ODkzLWJiMTItMGJkNTRmZWNiYzM1IDApIFRqIEVUCmVuZHN0cmVhbQplbmRvYmoKeHJlZgowIDYKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwNTggMDAwMDAgbiAKMDAwMDAwMDExNSAwMDAwMCBuIAowMDAwMDAwMjQxIDAwMDAwIG4gCjAwMDAwMDAzMTEgMDAwMDAgbiAKdHJhaWxlcgo8PCAvU2l6ZSA2IC9Sb290IDEgMCBSID4+CnN0YXJ0eHJlZgo0ODAKJSVFT0YK',
    ),
    'application/pdf',
  ),
  UploadFile(
    'mobile-supplier-b.pdf',
    base64Decode(
      'JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCA2MTIgNzkyXSAvUmVzb3VyY2VzIDw8IC9Gb250IDw8IC9GMSA0IDAgUiA+PiA+PiAvQ29udGVudHMgNSAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL1R5cGUgL0ZvbnQgL1N1YnR5cGUgL1R5cGUxIC9CYXNlRm9udCAvSGVsdmV0aWNhID4+CmVuZG9iago1IDAgb2JqCjw8IC9MZW5ndGggMTE4ID4+CnN0cmVhbQpCVCAvRjEgMTQgVGYgNTAgNzUwIFRkIChTbWFydFF1b3RlIGludGVncmF0aW9uIGZpeHR1cmUgbW9iaWxlLXN1cHBsaWVyLWIgYTU5ZTVhMWEtODc3MS00ODkzLWJiMTItMGJkNTRmZWNiYzM1IDApIFRqIEVUCmVuZHN0cmVhbQplbmRvYmoKeHJlZgowIDYKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwNTggMDAwMDAgbiAKMDAwMDAwMDExNSAwMDAwMCBuIAowMDAwMDAwMjQxIDAwMDAwIG4gCjAwMDAwMDAzMTEgMDAwMDAgbiAKdHJhaWxlcgo8PCAvU2l6ZSA2IC9Sb290IDEgMCBSID4+CnN0YXJ0eHJlZgo0ODAKJSVFT0YK',
    ),
    'application/pdf',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Solo esta prueba de integración usa red real. Los widgets mantienen sus dobles.
  HttpOverrides.global = null;
  final address =
      Platform.environment['SMARTQUOTE_API_URL'] ??
      const String.fromEnvironment('SMARTQUOTE_TEST_API_URL');
  final password =
      Platform.environment['SMARTQUOTE_BOOTSTRAP_PASSWORD'] ??
      const String.fromEnvironment('SMARTQUOTE_TEST_PASSWORD');
  if (address.isEmpty || password.isEmpty) {
    throw StateError(
      'Run tool/run-tests.ps1 -Level Integration. A temporary API and test password are required.',
    );
  }
  if (![
    'localhost',
    '127.0.0.1',
    '::1',
    '10.0.2.2',
  ].contains(Uri.parse(address).host)) {
    throw StateError(
      'Fixture-writing tests only run against a local isolated API.',
    );
  }
  // US02-US08/US09/US11-US14 + TS02/TS04: repositorios HTTP reales,
  // JWT de login real y PostgreSQL temporal; solo extracción usa Stub.
  test('US02 US03 US04 US05 US06 US07 US08 US09 US11 US12 US13 US14 TS02 TS04 — full mobile purchasing workflow through real HTTP', () async {
    final production = ApiClient(address);
    final analyst = ApiClient(address);
    final manager = ApiClient(address);
    for (final entry in [
      (production, 'production'),
      (analyst, 'analyst'),
      (manager, 'manager'),
    ]) {
      final session = await HttpIdentityRepository(entry.$1)
          .login('${entry.$2}@smartquote.local', password);
      entry.$1.accessToken = session.token;
      expect(session.assignedRoles, isNotEmpty);
      final me = await HttpIdentityRepository(entry.$1).me();
      expect(me['userId'], session.user['userId']);
      addTearDown(() async {
        await HttpIdentityRepository(entry.$1).logout();
        await entry.$1.clearSession();
      });
    }
    final requests = HttpRequestRepository(production);
    final purchasing = HttpRequestRepository(analyst);
    final quotations = HttpQuotationRepository(analyst);
    final evaluations = HttpEvaluationRepository(analyst);
    final orders = HttpOrderRepository(manager);
    final delivery = HttpOrderRepository(analyst);
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    // US02/E1-E3: datos, validación obligatoria y metadatos de sustento.
    final payload = <String, dynamic>{
      'requiredDate': DateTime.now()
          .toUtc()
          .add(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10),
      'priority': 'High',
      'items': [
        {
          'description': 'Mobile API integration supply',
          'quantity': 1,
          'unitOfMeasure': 'unit',
          'requirements': [
            {
              'name': 'documentReference',
              'operator': 'Contains',
              'expectedValue': 'a',
              'unitOfMeasure': '',
              'isMandatory': true,
            },
          ],
        },
      ],
    };
    await expectLater(
      HttpRequestRepository(manager).create(payload),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 403)),
    );
    var request = await requests.create(payload);
    expect(request.status, 'Submitted');
    await requests.attach(request, _pdfs.first);
    request = await requests.get(request.id);
    expect(request.attachments.single['fileName'], _pdfs.first.name);
    expect(request.attachments.single['contentType'], 'application/pdf');
    expect(
      request.attachments.single['uploadedBy'],
      request.data['requesterId'],
    );
    expect(request.attachments.single['uploadedAt'], isNotNull);
    for (final status in ['UnderReview', 'QuotationCollection']) {
      await purchasing.changeStatus(request, status, 'Mobile API integration');
      request = await requests.get(request.id);
      expect(request.status, status);
    }
    // US04-US05: duplicado, procesamiento, corrección, IDs y verificación.
    final quotes = <String>[];
    for (final file in _pdfs) {
      final uploaded = await quotations.upload(request.id, file, {});
      final duplicate = await quotations.upload(request.id, file, {});
      expect(duplicate.id, uploaded.id);
      var quote = await quotations.process(uploaded.id);
      expect(quote.status, 'RequiresVerification');
      expect(quote.fields.every((f) => f['sourceTextReference'] != null), true);
      if (quotes.isNotEmpty) {
        final price = quote.fields.firstWhere(
          (f) => f['fieldPath'] == 'lines[0].unitPrice',
        );
        await quotations.correct(
          quote,
          textOf(price, 'fieldId'),
          '120',
          'Mobile API evidence correction',
        );
        final oldVersion = quote.version;
        quote = await quotations.get(quote.id);
        expect(quote.version, greaterThan(oldVersion));
        final changed = quote.fields.firstWhere(
          (f) => f['fieldId'] == price['fieldId'],
        );
        expect(changed['originalValue'], '100');
        expect(changed['currentValue'], '120');
        expect(
          objectsOf(changed['corrections']).single['reason'],
          'Mobile API evidence correction',
        );
      }
      await quotations.confirm(quote, {
        for (final line in quote.lines)
          textOf(line, 'lineId'): textOf(request.items.first, 'itemId'),
      });
      expect((await quotations.get(quote.id)).verified, true);
      quotes.add(quote.id);
    }
    // US06-US07: escenario real, exclusión de vigencia y versión nueva.
    final criteria = defaultCriteria(request);
    var scenario = await evaluations.save(
      request.id,
      criteriaPayload(criteria),
      null,
    );
    await purchasing.changeStatus(request, 'Evaluation', 'Quotes ready');
    var run = await evaluations.simulate(scenario.id);
    expect(run.current, true);
    expect(run.evaluations.length, 2);
    expect(run.recommendation!['quotationId'], quotes.first);
    final oldRun = run;
    criteria[1]['weight'] = 70;
    criteria[2]['weight'] = 30;
    scenario = await evaluations.save(
      request.id,
      criteriaPayload(criteria),
      scenario,
    );
    expect((await evaluations.getSimulation(oldRun.id)).current, false);
    await expectLater(
      orders.approve(
        oldRun.id,
        quotes.first,
        'Receiving 8-16',
        'Test warehouse',
      ),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 422)),
    );
    run = await evaluations.simulate(scenario.id);
    expect(
      (await evaluations.history(request.id)).any((r) => r.id == run.id),
      true,
    );
    // US08/TS04: aprobación, reintento idempotente y detalle normalizado.
    final order = await orders.approve(
      run.id,
      quotes.first,
      'Receiving 8-16',
      'Test warehouse',
    );
    final retry = await orders.approve(
      run.id,
      quotes.first,
      'Receiving 8-16',
      'Test warehouse',
    );
    expect(retry.id, order.id);
    expect(order.data['total'], 100);
    expect((await orders.byRequest(request.id))!.id, order.id);
    final storedOrder = (await orders.get(order.id)).data;
    // PostgreSQL conserva microsegundos; comparar instantes, no strings de .NET.
    for (final field in ['createdAt', 'approvedAt']) {
      expect(
        DateTime.parse(textOf(storedOrder, field)),
        DateTime.parse(textOf(order.data, field)),
      );
    }
    expect(
      {...storedOrder}
        ..remove('createdAt')
        ..remove('approvedAt'),
      {...order.data}
        ..remove('createdAt')
        ..remove('approvedAt'),
    );
    expect((await orders.bySimulation(run.id))!.id, order.id);
    // US11/E1-E3: PDF real generado desde la orden persistida, sin mutar sus importes.
    final approvedData = jsonEncode(order.data);
    final pdf = await buildOrderPdf(
      order,
      const CorporateProfile(
        name: 'Test Company',
        taxId: '20123456789',
        address: 'Test warehouse',
      ),
    );
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    expect(pdf.length, greaterThan(1000));
    expect(
      String.fromCharCodes(pdf),
      contains(textOf(order.data, 'inputFingerprint')),
    );
    expect(jsonEncode(order.data), approvedData);
    // US12: lectura de eventos reales; un analista no puede leer la bitácora.
    final audit = await orders.audit('PurchaseOrder', order.id);
    expect(
      audit.any(
        (event) => event['actorId'] != null && event['occurredAt'] != null,
      ),
      true,
    );
    await expectLater(
      delivery.audit('PurchaseOrder', order.id),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 403)),
    );
    // US14: consultas por período y resultado vacío explícito.
    final metrics = await orders.metrics(today, today);
    expect(metrics['orderCount'], greaterThanOrEqualTo(1));
    expect(metrics['timeSampleCount'], greaterThanOrEqualTo(1));
    final empty = await orders.metrics('2099-01-01', '2099-01-31');
    expect(empty['orderCount'], 0);
    expect(empty['averageProcessingHours'], null);
    expect(empty['comparativeSavings'], null);
    // US13: antes de entrega rechaza; después registra y permite consulta.
    await expectLater(
      delivery.evaluate(order.id, 5, 4, 'Mobile delivery evidence'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 422)),
    );
    await delivery.delivered(order.id);
    final evaluation = await delivery.evaluate(
      order.id,
      5,
      4,
      'Mobile delivery evidence',
    );
    expect(evaluation['purchaseOrderId'], order.id);
    expect(evaluation['evaluatedBy'], isNotNull);
    final performance = await delivery.performance(
      textOf(order.data, 'supplierTaxIdentifier'),
    );
    expect(
      objectsOf(performance['evaluations'])
          .any((e) => e['purchaseOrderId'] == order.id),
      true,
    );
    await expectLater(
      delivery.evaluate(order.id, 5, 4, 'Duplicate'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 409)),
    );
    // US03: final de flujo y notificaciones desde producción.
    expect((await requests.get(request.id)).status, 'Ordered');
    expect(
      (await requests.history(request.id))
          .any((e) => e['toStatus'] == 'Ordered'),
      true,
    );
    final notices = await requests.notifications();
    final notice = notices.firstWhere(
      (n) => n['purchaseRequestId'] == request.id,
    );
    await requests.readNotification(textOf(notice, 'notificationId'));
    expect(
      (await requests.notifications()).firstWhere(
        (n) => n['notificationId'] == notice['notificationId'],
      )['readAt'],
      isNotNull,
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
