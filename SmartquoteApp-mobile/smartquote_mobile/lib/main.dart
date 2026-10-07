import 'package:flutter/material.dart';

import 'app/services.dart';
import 'app/workspace.dart';
import 'identity_access/application/session_controller.dart';
import 'identity_access/infrastructure/http_identity_repository.dart';
import 'identity_access/presentation/access_page.dart';
import 'supply_requests/infrastructure/http_request_repository.dart';
import 'quotation_intake/infrastructure/http_quotation_repository.dart';
import 'evaluation_simulation/infrastructure/http_evaluation_repository.dart';
import 'purchase_ordering/infrastructure/http_order_repository.dart';
import 'purchase_ordering/infrastructure/order_pdf.dart';
import 'shared/infrastructure/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
  );
  final auth = SessionController(HttpIdentityRepository(api), api);
  runApp(
    SmartQuoteApp(
      services: Services(
        auth: auth,
        requests: HttpRequestRepository(api),
        quotations: HttpQuotationRepository(api),
        evaluations: HttpEvaluationRepository(api),
        orders: HttpOrderRepository(api),
        orderExporter: PdfOrderExporter(),
      ),
    ),
  );
}

class SmartQuoteApp extends StatelessWidget {
  const SmartQuoteApp({super.key, required this.services});
  final Services services;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: services.auth,
    builder: (context, _) {
      final session = services.auth.session;
      return MaterialApp(
        key: ValueKey(session?.user['userId'] ?? 'guest'),
        title: 'SmartQuote',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: const Color(0xfff5f7fa),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff0f5b8c),
            primary: const Color(0xff0f5b8c),
            secondary: const Color(0xff093a5a),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            margin: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        home: session == null
            ? AccessPage(services: services)
            : Workspace(services: services),
      );
    },
  );
}
