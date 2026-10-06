import 'package:flutter/material.dart';
import '../../domain/repositories/smartquote_repository.dart';

class LoginViewModel extends ChangeNotifier {
  final SmartQuoteRepository repository;
  LoginViewModel({required this.repository});

  bool isLoading = false;
  String? errorMessage;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final success = await repository.login(email, password);
    
    if (!success) errorMessage = 'Credenciales incorrectas';
    
    isLoading = false;
    notifyListeners();
    return success;
  }
}