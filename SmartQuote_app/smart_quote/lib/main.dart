import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';

void main() {
  // ProviderScope arranca el contenedor de dependencias de Riverpod
  runApp(const ProviderScope(child: SmartQuoteApp()));
}

class SmartQuoteApp extends ConsumerWidget {
  const SmartQuoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el proveedor de rutas
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SmartQuote Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}