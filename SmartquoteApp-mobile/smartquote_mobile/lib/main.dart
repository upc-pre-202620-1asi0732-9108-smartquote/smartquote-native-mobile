import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories_impl/smartquote_repository_impl.dart';
import 'presentation/viewmodels/request_list_viewmodel.dart';
import 'presentation/screens/request_list_screen.dart';

void main() {
  runApp(const SmartQuoteApp());
}

class SmartQuoteApp extends StatelessWidget {
  const SmartQuoteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Aquí inyectamos las dependencias
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RequestListViewModel(
            repository: SmartQuoteRepositoryImpl(),
          ),
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