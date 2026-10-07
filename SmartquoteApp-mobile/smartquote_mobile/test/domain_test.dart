import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/shared/presentation/ui.dart';
import 'package:smartquote_mobile/identity_access/domain/session.dart';
import 'package:smartquote_mobile/supply_requests/application/request_draft.dart';
import 'package:smartquote_mobile/supply_requests/domain/purchase_request.dart';
import 'package:smartquote_mobile/quotation_intake/domain/quotation.dart';
import 'package:smartquote_mobile/evaluation_simulation/application/criteria_policy.dart';
import 'package:smartquote_mobile/purchase_ordering/domain/corporate_profile.dart';
import 'package:smartquote_mobile/purchase_ordering/domain/purchase_order.dart';
import 'package:smartquote_mobile/purchase_ordering/infrastructure/order_pdf.dart';
import 'package:smartquote_mobile/shared/infrastructure/api_client.dart';

import 'support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // TS02 E1: Roles come exclusively from the server session.
  test('TS02 E1 — Roles come exclusively from the server session', () {
    final production = Session.fromJson(sessionFixture('ProductionSpecialist'));
    expect(production.production, true);
    expect(production.purchasing, false);
    expect(production.manager, false);
    final analyst = Session.fromJson(sessionFixture('PurchaseAnalyst'));
    expect(analyst.purchasing, true);
    expect(analyst.manager, false);
    expect(Session.fromJson(sessionFixture('PurchaseManager')).manager, true);
  });
  // US09 E2: Registration validates complexity and rejects email-based password.
  test('US09 E2 — Registration validates complexity and rejects email-based password', () {
    expect(passwordError('short', 'person@example.com'), isNotNull);
    expect(passwordError('LongEnough123', 'person@example.com'), isNotNull);
    expect(passwordError('Person!Long1234', 'person@example.com'), isNotNull);
    expect(passwordError('Valid!Long1234', 'person@example.com'), isNull);
  });
  // US02 E1 E2: Request preserves decimal quantities, operators, optional requirements.
  test('US02 E1 E2 — Request preserves decimal quantities, operators, optional requirements', () {
    final draft = RequestDraft();
    draft.items.first
      ..description = 'Alimento'
      ..quantity = '1000,5'
      ..unit = 'kg';
    draft.items.first.requirements.first
      ..name = 'Proteína mínima'
      ..operator = 'GreaterThanOrEqual'
      ..expectedValue = '20'
      ..unit = '%';
    final humidity = RequirementDraft()
      ..name = 'Humedad máxima'
      ..operator = 'LessThanOrEqual'
      ..expectedValue = '12'
      ..unit = '%'
      ..mandatory = false;
    draft.items.first.requirements.add(humidity);
    expect(draft.validate(), isNull);
    final json = draft.toJson();
    final item = objectsOf(json['items']).first;
    expect(item['quantity'], 1000.5);
    expect(objectsOf(item['requirements']).last['isMandatory'], false);
    expect(json['requiredDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    draft.items.first.requirements.first.mandatory = false;
    expect(draft.validate(), contains('obligatorio'));
  });
  // US06 E1 E2: Criteria retain mandatory IDs and weights must sum to 100.
  test(
    'US06 E1 E2 — Criteria retain mandatory IDs and weights must sum to 100',
    () {
      final request = PurchaseRequest(requestFixture());
      final criteria = defaultCriteria(request);
      expect(criteria.first['targetField'], reqId);
      expect(criteriaError(criteria, request), isNull);
      criteria.last['weight'] = 50;
      expect(criteriaError(criteria, request), contains('100'));
      criteria.last['weight'] = 40;
      criteria.removeAt(0);
      expect(criteriaError(criteria, request), isNotNull);
    },
  );
  // US06 E1: Technical weight can coexist with price and delivery.
  test('US06 E1 — Technical weight can coexist with price and delivery', () {
    final request = PurchaseRequest(requestFixture());
    final criteria = defaultCriteria(request);
    criteria[1]['weight'] = 50;
    criteria[2]['weight'] = 30;
    criteria.add({...criteria.first, 'mode': 'Weighted', 'weight': 20});
    expect(criteriaError(criteria, request), isNull);
    expect(criteriaPayload(criteria).last['displayOrder'], 4);
    expect(criteriaPayload(criteria).first.containsKey('criterionId'), false);
  });
  // US05 E1 E3: Quotation correction supports supplier fields; unresolved values block confirmation.
  test('US05 E1 E3 — Quotation correction supports supplier fields; unresolved values block confirmation', () {
    expect(Quotation.editable('supplier.businessName'), true);
    expect(Quotation.editable('lines[0].unitPrice'), true);
    expect(Quotation.editable('lines[0].specifications[0].value'), true);
    expect(Quotation.editable('quotationId'), false);
    final json = quoteFixture(status: 'RequiresVerification');
    expect(Quotation(json).canConfirm, true);
    objectsOf(json['fields']).first; // Lists are mapped defensively.
    (json['fields'] as List).first['status'] = 'Unresolved';
    expect(Quotation(json).canConfirm, false);
  });
  // TS04 E2: URL normalization avoids doubled /api/v1 and rejects credentials or foreign paths.
  test('TS04 E2 — URL normalization avoids doubled /api/v1 and rejects credentials or foreign paths', () {
    expect(
      ApiClient.normalizeAddress('http://localhost:8080/api/v1/'),
      'http://localhost:8080',
    );
    expect(
      () => ApiClient.normalizeAddress('https://example.com/api/other'),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => ApiClient.normalizeAddress('https://user:secret@example.com'),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => ApiClient.normalizeAddress('https://example.com?token=x'),
      throwsA(isA<ApiFailure>()),
    );
  });
  // US14 E3: Null monetary values are not presented as zero.
  test('US14 E3 — Null monetary values are not presented as zero', () {
    expect(money(null, 'PEN'), 'No disponible');
    expect(friendlyExplanation('GreaterThanOrEqual'), 'mayor o igual que');
  });
  // US11 E1 E2: PDF requires corporate profile and issued approved snapshot.
  test(
    'US11 E1 E2 — PDF requires corporate profile and issued approved snapshot',
    () async {
      const profile = CorporateProfile(
        name: 'Empresa de prueba',
        taxId: '20123456789',
        address: 'Dirección de prueba',
      );
      final issued = PurchaseOrder(orderFixture());
      final bytes = await buildOrderPdf(issued, profile);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(1000));
      expect(
        () => assertExportable(PurchaseOrder(orderFixture(status: 'Pending'))),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () =>
            const CorporateProfile(name: '', taxId: '', address: '').validate(),
        throwsA(isA<ApiFailure>()),
      );
      final missing = orderFixture()..remove('approvedBy');
      expect(
        () => assertExportable(PurchaseOrder(missing)),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  // US11/E3: metadatos de origen y datos aprobados permanecen coherentes.
  test('US11 E3 — PDF retains order, request, simulation and fingerprint without mutating approved data', () async {
    final order = PurchaseOrder(orderFixture());
    final before = jsonEncode(order.data);
    const corporate = CorporateProfile(
      name: 'Empresa de prueba',
      taxId: '20123456789',
      address: 'Almacén',
    );
    final bytes = await buildOrderPdf(order, corporate);
    final document = String.fromCharCodes(bytes);
    for (final value in [
      order.id,
      requestId,
      runId,
      textOf(order.data, 'inputFingerprint'),
    ]) {
      expect(document, contains(value));
    }
    expect(jsonEncode(order.data), before);
    expect(order.lines.single['unitPrice'], 4.5);
  });
}
