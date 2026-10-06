import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/shared/infrastructure/api_client.dart';
import 'package:smartquote_mobile/identity_access/application/session_controller.dart';
import 'package:smartquote_mobile/identity_access/infrastructure/http_identity_repository.dart';
import 'package:smartquote_mobile/supply_requests/infrastructure/http_request_repository.dart';
import 'package:smartquote_mobile/quotation_intake/infrastructure/http_quotation_repository.dart';
import 'package:smartquote_mobile/evaluation_simulation/infrastructure/http_evaluation_repository.dart';
import 'package:smartquote_mobile/purchase_ordering/infrastructure/http_order_repository.dart';

class SmokeApi extends ApiClient {
  SmokeApi(super.address);
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
    try {
      return await super.request(
        path,
        method: method,
        body: body,
        query: query,
        authenticated: authenticated,
        timeout: timeout,
        onSendProgress: onSendProgress,
      );
    } on ApiFailure catch (error) {
      throw ApiFailure(
        '$method $path: ${error.message}',
        status: error.status,
        code: error.code,
        traceId: error.traceId,
      );
    }
  }
}

void main() {
  final apiUrl = Platform.environment['SMARTQUOTE_SMOKE_API'];
  final email = Platform.environment['SMARTQUOTE_SMOKE_EMAIL'];
  final password = Platform.environment['SMARTQUOTE_SMOKE_PASSWORD'];
  test(
    'Live backend: real session and read-only role-specific repositories',
    () async {
      final api = SmokeApi(apiUrl!);
      final identity = HttpIdentityRepository(api);
      final auth = SessionController(identity, api);
      addTearDown(() async {
        try {
          if (auth.session != null) await auth.logout();
        } finally {
          auth.dispose();
        }
      });
      await auth.login(email!, password!);
      final session = auth.session!;
      final me = await identity.me();
      expect(me['userId'], session.user['userId']);
      expect(session.assignedRoles, isNotEmpty);
      final requests = HttpRequestRepository(api);
      final page = await requests.list();
      expect(page.totalItems, greaterThanOrEqualTo(0));
      if (session.production) {
        await requests.notifications();
      }
      if (session.manager) {
        await identity.pending();
        await HttpOrderRepository(api).metrics(
          DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String()
              .substring(0, 10),
          DateTime.now().toIso8601String().substring(0, 10),
        );
      }
      if (page.items.isNotEmpty) {
        final request = await requests.get(page.items.first.id);
        expect(request.id, page.items.first.id);
        expect(request.version, greaterThan(0));
        await requests.history(request.id);
        if (session.purchasing) {
          final quotes = HttpQuotationRepository(api);
          final list = await quotes.list(request.id);
          if (list.isNotEmpty) {
            expect((await quotes.get(list.first.id)).id, list.first.id);
          }
          final simulations = HttpEvaluationRepository(api);
          await simulations.current(request.id);
          final runs = await simulations.history(request.id);
          if (runs.isNotEmpty) {
            expect(
              (await simulations.getSimulation(runs.first.id)).id,
              runs.first.id,
            );
          }
          final orders = HttpOrderRepository(api);
          final order = await orders.byRequest(request.id);
          if (order != null) {
            expect((await orders.get(order.id)).id, order.id);
            await orders.performance(
              order.data['supplierTaxIdentifier'] as String,
            );
            if (session.manager) await orders.audit('PurchaseOrder', order.id);
          }
          if (session.manager) {
            await orders.audit('PurchaseRequest', request.id);
          }
        }
      }
    },
    skip: apiUrl == null || email == null || password == null
        ? 'Opt-in: set SMARTQUOTE_SMOKE_API, SMARTQUOTE_SMOKE_EMAIL and SMARTQUOTE_SMOKE_PASSWORD.'
        : false,
  );
}
