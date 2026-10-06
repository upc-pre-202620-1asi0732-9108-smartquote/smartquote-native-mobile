import 'dart:typed_data';

import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/identity_access/application/session_controller.dart';
import 'package:smartquote_mobile/identity_access/infrastructure/http_identity_repository.dart';
import 'package:smartquote_mobile/supply_requests/infrastructure/http_request_repository.dart';
import 'package:smartquote_mobile/quotation_intake/infrastructure/http_quotation_repository.dart';
import 'package:smartquote_mobile/evaluation_simulation/infrastructure/http_evaluation_repository.dart';
import 'package:smartquote_mobile/purchase_ordering/infrastructure/http_order_repository.dart';
import 'package:smartquote_mobile/purchase_ordering/domain/purchase_order.dart';
import 'package:smartquote_mobile/purchase_ordering/domain/corporate_profile.dart';
import 'package:smartquote_mobile/app/services.dart';

const requestId = '11111111-1111-4111-8111-111111111111';
const itemId = '22222222-2222-4222-8222-222222222222';
const reqId = '33333333-3333-4333-8333-333333333333';
const quoteId = '44444444-4444-4444-8444-444444444444';
const scenarioId = '55555555-5555-4555-8555-555555555555';
const runId = '66666666-6666-4666-8666-666666666666';
const orderId = '77777777-7777-4777-8777-777777777777';
const userId = '88888888-8888-4888-8888-888888888888';
const lineId = '99999999-9999-4999-8999-999999999999';
const fieldId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
JsonObject supplierPerformanceFixture() => {
  'supplierTaxIdentifier': '20123456789',
  'evaluationCount': 1,
  'averageOnTimeScore': 5,
  'averageQualityScore': 4,
  'overallScore': 4.5,
  'firstEvaluatedAt': '2026-10-05T12:00:00Z',
  'lastEvaluatedAt': '2026-10-05T12:00:00Z',
  'evaluations': [
    {
      'deliveryEvaluationId': fieldId,
      'purchaseOrderId': orderId,
      'supplierTaxIdentifier': '20123456789',
      'onTimeScore': 5,
      'qualityScore': 4,
      'observations': 'Entrega completa sin daños.',
      'evaluatedBy': userId,
      'evaluatedAt': '2026-10-05T12:00:00Z',
    },
  ],
};
JsonObject requestFixture({String status = 'Submitted'}) => {
  'requestId': requestId,
  'requesterId': userId,
  'requiredDate': '2026-12-25',
  'priority': 'Normal',
  'status': status,
  'version': 3,
  'nextResponsibleArea': 'Purchasing',
  'createdAt': '2026-10-05T10:00:00Z',
  'updatedAt': '2026-10-05T10:00:00Z',
  'items': [
    {
      'itemId': itemId,
      'lineNumber': 1,
      'description': 'Alimento balanceado',
      'quantity': 1000,
      'unitOfMeasure': 'kg',
      'requirements': [
        {
          'requirementId': reqId,
          'name': 'Proteína mínima',
          'operator': 'GreaterThanOrEqual',
          'expectedValue': '20',
          'unitOfMeasure': '%',
          'isMandatory': true,
        },
      ],
    },
  ],
  'attachments': [],
};
JsonObject quoteFixture({String id = quoteId, String status = 'Verified'}) => {
  'quotationId': id,
  'requestId': requestId,
  'supplierBusinessName': 'Proveedor de prueba',
  'supplierTaxIdentifier': '20123456789',
  'fileName': 'cotizacion.pdf',
  'status': status,
  'version': 4,
  'currency': 'PEN',
  'deliveryLeadTimeDays': 3,
  'validUntil': '2026-12-31',
  'lines': [
    {
      'lineId': lineId,
      'lineNumber': 1,
      'requestedItemId': itemId,
      'description': 'Alimento balanceado',
      'quantity': 1000,
      'unitOfMeasure': 'kg',
      'unitPrice': 4.5,
      'specifications': [
        {'name': 'Proteína mínima', 'value': '21', 'unitOfMeasure': '%'},
      ],
    },
  ],
  'fields': [
    {
      'fieldId': fieldId,
      'fieldPath': 'lines[0].unitPrice',
      'originalValue': '4.50',
      'currentValue': '4.50',
      'isRequired': true,
      'status': 'Resolved',
      'sourcePageNumber': 1,
      'sourceTextReference': 'Precio unitario 4.50',
      'confidence': .98,
      'corrections': [],
    },
  ],
};
JsonObject runFixture({bool current = true}) => {
  'simulationRunId': runId,
  'scenarioId': scenarioId,
  'criteriaVersion': 1,
  'inputFingerprint': 'fixture-fingerprint',
  'executedAt': '2026-10-05T12:00:00Z',
  'isCurrent': current,
  'recommendation': {
    'quotationId': quoteId,
    'score': .9,
    'explanation': 'Cumple los requisitos.',
  },
  'exchangeRate': {
    'sourceCurrency': 'USD',
    'targetCurrency': 'PEN',
    'rate': 3.4,
    'rateType': 'V',
    'publishedOn': '2026-10-05',
    'source': 'SUNAT',
    'retrievedAt': '2026-10-05T12:00:00Z',
  },
  'evaluations': [
    {
      'quotationId': quoteId,
      'isEligible': true,
      'rank': 1,
      'totalScore': .9,
      'originalTotal': 4500,
      'originalCurrency': 'PEN',
      'comparisonTotal': 4500,
      'comparisonCurrency': 'PEN',
      'conversionApplied': false,
      'criterionResults': [],
      'exclusionReasons': [],
    },
  ],
};
JsonObject orderFixture({String status = 'Issued'}) => {
  'purchaseOrderId': orderId,
  'orderNumber': 'OC-2026-TEST',
  'simulationRunId': runId,
  'purchaseRequestId': requestId,
  'quotationId': quoteId,
  'inputFingerprint': 'fixture-fingerprint',
  'supplierId': 'supplier-test',
  'supplierBusinessName': 'Proveedor de prueba',
  'supplierTaxIdentifier': '20123456789',
  'approvedBy': userId,
  'approvedAt': '2026-10-05T12:01:00Z',
  'status': status,
  'currency': 'PEN',
  'deliveryLeadTimeDays': 3,
  'deliveryConditions': 'Entrega completa',
  'deliveryDestination': 'Granja de prueba',
  'total': 4500,
  'createdAt': '2026-10-05T12:01:00Z',
  'lines': [
    {
      'lineId': lineId,
      'lineNumber': 1,
      'sourceQuotationLineId': lineId,
      'sourceRequestedItemId': itemId,
      'description': 'Alimento balanceado',
      'quantity': 1000,
      'unitOfMeasure': 'kg',
      'unitPrice': 4.5,
    },
  ],
};
JsonObject sessionFixture(String role) => {
  'accessToken': 'test-only-token',
  'expiresIn': 3600,
  'user': {
    'userId': userId,
    'email': 'demo@smartquote.local',
    'displayName': 'Usuario de prueba',
    'roles': [role],
  },
};

class Call {
  Call(this.path, this.method, this.body, this.query, this.authenticated);
  final String path, method;
  final Object? body;
  final JsonObject? query;
  final bool authenticated;
}

class TestApi implements ApiGateway {
  TestApi({this.role = 'ProductionSpecialist'});
  String role;
  String status = 'Submitted';
  bool existingOrder = false;
  List<JsonObject> savedCriteria = [];
  final calls = <Call>[];
  final failures = <String, ApiFailure>{};
  final responses = <String, Object?>{};
  @override
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
    JsonObject? query,
    bool authenticated = true,
    Duration? timeout,
    void Function(int, int)? onSendProgress,
  }) async {
    calls.add(Call(path, method, body, query, authenticated));
    if (failures.containsKey(path)) throw failures[path]!;
    if (responses.containsKey(path)) return responses[path];
    if (path.endsWith('registration-status')) {
      return {'initialSetupRequired': false};
    }
    if (path.endsWith('/login') || path.endsWith('/refresh')) {
      return sessionFixture(role);
    }
    if (path.endsWith('/register')) {
      return {
        'status': 'Pending',
        'email': (body as Map)['email'],
        'initialSetup': false,
      };
    }
    if (path.endsWith('/logout') ||
        path.endsWith('/approve') ||
        path.endsWith('/read')) {
      return null;
    }
    if (path.endsWith('/me')) return sessionFixture(role)['user'];
    if (path == '/iam/registration-requests') return [];
    if (path == '/notifications') {
      return [
        {
          'notificationId': userId,
          'purchaseRequestId': requestId,
          'newStatus': status,
          'message': 'Estado actualizado',
          'createdAt': '2026-10-05T10:00:00Z',
          'readAt': null,
        },
      ];
    }
    if (path == '/purchase-requests' && method == 'POST') {
      return requestFixture();
    }
    if (path == '/purchase-requests') {
      return {
        'items': [requestFixture(status: status)],
        'page': 1,
        'pageSize': 12,
        'totalItems': 1,
        'totalPages': 1,
      };
    }
    if (path == '/purchase-requests/$requestId') {
      return requestFixture(status: status);
    }
    if (path.endsWith('/history')) {
      return {'requestId': requestId, 'entries': []};
    }
    if (path.endsWith('/status')) {
      status = (body as Map)['nextStatus'] as String;
      return null;
    }
    if (path.endsWith('/attachments') ||
        path.contains('/fields/') ||
        path.endsWith('/confirm') ||
        path.endsWith('/specifications')) {
      return null;
    }
    if (path.endsWith('/quotations') && method == 'GET') {
      return [
        quoteFixture(),
        quoteFixture(id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
      ];
    }
    if (path.endsWith('/quotations') && method == 'POST') {
      onSendProgress?.call(10, 10);
      return quoteFixture(status: 'Uploaded');
    }
    if (path == '/quotations/$quoteId' || path.endsWith('/process')) {
      return quoteFixture(status: 'RequiresVerification');
    }
    if (path.endsWith('/evaluation-scenario') ||
        path == '/evaluation-scenarios/$scenarioId') {
      if (savedCriteria.isEmpty) {
        throw const ApiFailure('No existe', status: 404);
      }
      return {
        'scenarioId': scenarioId,
        'version': 1,
        'criteria': savedCriteria,
      };
    }
    if (path == '/evaluation-scenarios' || path.endsWith('/versions')) {
      savedCriteria = objectsOf((body as Map)['criteria']);
      return {
        'scenarioId': scenarioId,
        'version': 1,
        'criteria': savedCriteria,
      };
    }
    if (path.endsWith('/simulations') && method == 'GET') return [runFixture()];
    if (path.endsWith('/simulations') && method == 'POST' ||
        path == '/simulations/$runId') {
      return runFixture();
    }
    if (path.endsWith('/purchase-orders') && method == 'POST') {
      existingOrder = true;
      status = 'Ordered';
      return orderFixture();
    }
    if (path.endsWith('/purchase-order')) {
      if (!existingOrder) throw const ApiFailure('No existe', status: 404);
      return orderFixture();
    }
    if (path == '/purchase-orders/$orderId') return orderFixture();
    if (path.endsWith('/delivery')) return orderFixture(status: 'Delivered');
    if (path.endsWith('/delivery-evaluation')) {
      return {
        'deliveryEvaluationId': reqId,
        'purchaseOrderId': orderId,
        'onTimeScore': 5,
        'qualityScore': 4,
        'evaluatedBy': userId,
        'evaluatedAt': '2026-10-05T12:01:00Z',
        'observations': 'Prueba',
      };
    }
    if (path.endsWith('/performance')) {
      return {
        'supplierTaxIdentifier': '20123456789',
        'evaluationCount': 0,
        'averageOnTimeScore': null,
        'averageQualityScore': null,
        'overallScore': null,
        'firstEvaluatedAt': null,
        'lastEvaluatedAt': null,
        'evaluations': [],
      };
    }
    if (path.startsWith('/audit/')) return [];
    if (path == '/purchasing-metrics') {
      return {
        'from': query!['from'],
        'to': query['to'],
        'timeZone': 'UTC',
        'orderStatus': 'Issued',
        'orderCount': 0,
        'timeSampleCount': 0,
        'averageProcessingHours': null,
        'savingsSampleCount': 0,
        'comparativeSavings': null,
        'savingsCurrency': 'PEN',
      };
    }
    throw StateError('No test contract for $method $path');
  }
}

class TestTransport implements SessionTransport {
  @override
  String get baseUrl => 'http://localhost:8080';
  @override
  String? accessToken;
  @override
  Future<bool> Function()? renewSession;
  @override
  Future<void> clearSession() async {
    accessToken = null;
  }
}

class TestExporter implements OrderExporter {
  int exports = 0;
  @override
  Future<void> export(PurchaseOrder order, CorporateProfile profile) async {
    assertExportable(order);
    profile.validate();
    exports++;
  }
}

Services testServices(TestApi api) => Services(
  auth: SessionController(HttpIdentityRepository(api), TestTransport()),
  requests: HttpRequestRepository(api),
  quotations: HttpQuotationRepository(api),
  evaluations: HttpEvaluationRepository(api),
  orders: HttpOrderRepository(api),
  orderExporter: TestExporter(),
);
UploadFile fileFixture([String name = 'cotizacion.pdf']) =>
    UploadFile(name, Uint8List.fromList([37, 80, 68, 70]), 'application/pdf');
