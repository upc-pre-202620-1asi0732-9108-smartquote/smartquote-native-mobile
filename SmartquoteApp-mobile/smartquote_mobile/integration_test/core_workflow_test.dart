import 'package:integration_test/integration_test.dart';

import '../tool/core_api_test.dart' as core;

// Ejecuta los repositorios reales y la generación del PDF dentro del motor Android.
// No sustituye las pruebas de interacción de widgets ni afirma recorrer todas las vistas.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  core.main();
}
