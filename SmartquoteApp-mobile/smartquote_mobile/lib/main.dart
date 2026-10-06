import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Repositorio
import 'data/repositories_impl/smartquote_repository_impl.dart';

// ViewModels
import 'presentation/viewmodels/request_list_viewmodel.dart';
import 'presentation/viewmodels/new_request_viewmodel.dart';
import 'presentation/viewmodels/notification_viewmodel.dart';

// Pantalla Principal
import 'presentation/screens/request_list_screen.dart';

void main() {
  runApp(const SmartQuoteApp());
}

class SmartQuoteApp extends StatelessWidget {
  const SmartQuoteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RequestListViewModel(repository: SmartQuoteRepositoryImpl()),
        ),
        ChangeNotifierProvider(
          create: (_) => NewRequestViewModel(repository: SmartQuoteRepositoryImpl()),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationViewModel(repository: SmartQuoteRepositoryImpl()),
        ),
      ],
      child: MaterialApp(
        title: 'SmartQuote App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
        ),
        home: RequestListScreen(),
      ),
    );
  }
}